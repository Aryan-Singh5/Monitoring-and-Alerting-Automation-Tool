#!/bin/bash

# Combined System Monitoring and Alert Script
# Monitors system performance, storage, processes, network, security, services, and system health
# Sends notifications (email or Telegram) for high CPU and disk usage
# Creates a new log file for each run and maintains up to 10 log files, deleting the oldest if exceeded
# Run as root for full access to system metrics


LOG_DIR="/var/log/monitor"
LOG_FILE="$LOG_DIR/system_monitor_alert_$(date '+%Y%m%d_%H%M%S').log"
LOCK_FILE="/tmp/system_monitor_alert.lock"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
THRESHOLD_CPU=80   # CPU usage threshold (%)
THRESHOLD_DISK=90  # Disk usage threshold (%)
THRESHOLD_MEM=80   # Memory usage threshold (%)
EMAIL_TO="youremail@gmail.com"  # Replace with your email
TELEGRAM_TOKEN="Telegram_Bot_Token"  # Replace with your Telegram bot token
TELEGRAM_CHAT_ID="Bot_Chat_Id"  # Replace with your Telegram chat ID
SERVICES=("ssh" "apache2" "nginx" "mysql")  # Services to check
MAX_LOG_FILES=10  # Maximum number of log files to keep

# Check for lock file to prevent concurrent runs
if [ -f "$LOCK_FILE" ]; then
    echo "Script is already running. Exiting. ($TIMESTAMP)" >> "$LOG_FILE"
    exit 1
fi
touch "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"; exit' EXIT INT TERM

# Ensure log directory exists
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
    if [ $? -ne 0 ]; then
        echo "Error: Cannot create $LOG_DIR ($TIMESTAMP)" >> "$LOG_FILE"
        exit 1
    fi
    chmod 755 "$LOG_DIR"
fi

# Ensure log file exists and is writable
touch "$LOG_FILE"
if [ ! -w "$LOG_FILE" ]; then
    echo "Error: Cannot write to $LOG_FILE ($TIMESTAMP)" >> "$LOG_FILE"
    exit 1
fi

# Manage log file count (keep only the latest 10)
LOG_COUNT=$(ls -1 "$LOG_DIR"/system_monitor_alert_*.log 2>/dev/null | wc -l)
if [ "$LOG_COUNT" -ge "$MAX_LOG_FILES" ]; then
    ls -1t "$LOG_DIR"/system_monitor_alert_*.log | tail -n +"$MAX_LOG_FILES" | xargs -I {} rm -f {}
fi

echo "===== System Monitoring and Alert Report ($TIMESTAMP) =====" >> "$LOG_FILE"

# Function to send notifications
send_notification() {
    local ALERT_MSG="$1"
    echo "$ALERT_MSG ($TIMESTAMP)" >> "$LOG_FILE"
    
    # Send Email Notification
    if command -v mail >/dev/null 2>&1; then
        echo "$ALERT_MSG" | mail -s "System Alert" "$EMAIL_TO" 2>> "$LOG_FILE"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to send email ($TIMESTAMP)" >> "$LOG_FILE"
        fi
    else
        echo "mail command not found, skipping email notification ($TIMESTAMP)" >> "$LOG_FILE"
    fi
    
    # Send Telegram Notification
    if [ -n "$TELEGRAM_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ] && command -v curl >/dev/null 2>&1; then
        sleep 10  # Avoid Telegram rate limiting
        CURL_RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
            -d chat_id="$TELEGRAM_CHAT_ID" \
            -d text="$ALERT_MSG" 2>&1)
        if ! echo "$CURL_RESPONSE" | grep -q '"ok":true'; then
            echo "Error: Failed to send Telegram notification ($TIMESTAMP)" >> "$LOG_FILE"
        fi
    else
        echo "Telegram not configured or curl not installed, skipping Telegram notification ($TIMESTAMP)" >> "$LOG_FILE"
    fi
}

# 1. System Performance (CPU and Memory)
echo "=== System Performance ===" >> "$LOG_FILE"
# CPU Usage (prefer mpstat, fallback to top)
if command -v mpstat >/dev/null 2>&1; then
    CPU_USAGE=$(mpstat 1 3 | grep -A 1 '%usr' | tail -n 1 | awk '{print 100 - $NF}' | awk '{sum += $1; count++} END {print sum/count}')
    echo "CPU Usage (mpstat, 3s average): $CPU_USAGE%" >> "$LOG_FILE"
else
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    echo "CPU Usage (top): $CPU_USAGE%" >> "$LOG_FILE"
fi
if (( $(echo "$CPU_USAGE > $THRESHOLD_CPU" | bc -l) )); then
    send_notification "ALERT: High CPU Usage: $CPU_USAGE% (Threshold: $THRESHOLD_CPU%)"
fi

# Memory Usage
MEM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
MEM_USED=$(free -m | awk '/Mem:/ {print $3}')
MEM_PERCENT=$(echo "scale=2; ($MEM_USED / $MEM_TOTAL) * 100" | bc)
echo "Memory Usage: $MEM_USED/$MEM_TOTAL MB ($MEM_PERCENT%)" >> "$LOG_FILE"
if (( $(echo "$MEM_PERCENT > $THRESHOLD_MEM" | bc -l) )); then
    send_notification "ALERT: High Memory Usage: $MEM_PERCENT% (Threshold: $THRESHOLD_MEM%)"
fi

# 2. Storage
echo -e "\n=== Storage ===" >> "$LOG_FILE"
df -h | grep -vE '^Filesystem|tmpfs|cdrom' | while read -r line; do
    DISK_USAGE=$(echo "$line" | awk '{print $5}' | cut -d'%' -f1)
    MOUNT_POINT=$(echo "$line" | awk '{print $6}')
    echo "Disk Usage on $MOUNT_POINT: $DISK_USAGE%" >> "$LOG_FILE"
    if [ "$DISK_USAGE" -gt "$THRESHOLD_DISK" ]; then
        send_notification "ALERT: High Disk Usage on $MOUNT_POINT: $DISK_USAGE% (Threshold: $THRESHOLD_DISK%)"
    fi
done

# 3. Processes
echo -e "\n=== Processes ===" >> "$LOG_FILE"
# Top 5 CPU-consuming processes
ps -eo pid,ppid,cmd,%cpu --sort=-%cpu | head -n 6 >> "$LOG_FILE"


# 4. Network
echo -e "\n=== Network ===" >> "$LOG_FILE"
# Network Interfaces and Traffic
if command -v ss >/dev/null 2>&1; then
    ss -tuln >> "$LOG_FILE"
else
    netstat -tuln 2>/dev/null >> "$LOG_FILE"
fi
# Network Traffic (if vnstat is installed)
if command -v vnstat >/dev/null 2>&1; then
    vnstat -s >> "$LOG_FILE"
else
    echo "vnstat not installed, skipping network traffic stats" >> "$LOG_FILE"
fi

# 5. Security
echo -e "\n=== Security ===" >> "$LOG_FILE"
# Failed Login Attempts
if [ -f /var/log/auth.log ]; then
    FAILED_LOGINS=$(grep 'Failed password' /var/log/auth.log | tail -n 5)
    if [ -n "$FAILED_LOGINS" ]; then
        echo "Recent Failed Login Attempts:" >> "$LOG_FILE"
        echo "$FAILED_LOGINS" >> "$LOG_FILE"
        send_notification "ALERT: Recent failed login attempts detected"
    else
        echo "No recent failed login attempts" >> "$LOG_FILE"
    fi
else
    echo "auth.log not found" >> "$LOG_FILE"
fi
# Last 5 Successful Logins
last -n 5 | grep -v "reboot" >> "$LOG_FILE"

# 6. Services
echo -e "\n=== Services ===" >> "$LOG_FILE"
for service in "${SERVICES[@]}"; do
    if systemctl is-active --quiet "$service"; then
        echo "$service: Running" >> "$LOG_FILE"
    else
        echo "$service: Not running or not installed" >> "$LOG_FILE"
        send_notification "ALERT: Service $service is not running or not installed"
    fi
done

# 7. System Health
echo -e "\n=== System Health ===" >> "$LOG_FILE"
# Uptime and Load Average
uptime >> "$LOG_FILE"
# CPU Temperature (if lm-sensors is installed)
if command -v sensors >/dev/null 2>&1; then
    sensors | grep -E 'Core|temp' >> "$LOG_FILE"
else
    echo "lm-sensors not installed, skipping temperature" >> "$LOG_FILE"
fi
# Disk Health (if smartctl is installed)
if command -v smartctl >/dev/null 2>&1; then
    for disk in /dev/sd[a-z]; do
        if [ -b "$disk" ]; then
            smartctl -H "$disk" | grep -E 'result|Serial' >> "$LOG_FILE"
        fi
    done
else
    echo "smartmontools not installed, skipping disk health" >> "$LOG_FILE"
fi

echo -e "===== End of Report ($TIMESTAMP) =====\n" >> "$LOG_FILE"
