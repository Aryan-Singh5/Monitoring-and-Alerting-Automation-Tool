# System Monitoring and Alerting Tool

This project provides a Bash-based system monitoring script with Ansible playbooks for automated deployment on Debian-based Linux servers (e.g., Ubuntu). It monitors CPU, memory, disk, processes, network, security, services, and overall system health, with automatic log file backups for audit and troubleshooting. Alerts are sent via email (Gmail) or Telegram for issues like high resource usage, failed services, or suspicious activity.

## Features
- Real-time monitoring of key system metrics
- Threshold-based alerts (e.g., CPU >80%, Disk >90%)
- Log rotation (keeps up to 10 logs in `/var/log/monitor`)
- Email and Telegram notifications
- Dependency installation via a dedicated script
- Ansible playbooks for automated deployment

## Prerequisites
- Debian-based OS (e.g., Ubuntu 20.04+)
- Ansible installed on the control machine
- Root/sudo access on target servers
- Gmail account for email alerts (with app password for `ssmtp`)
- Telegram bot token and chat ID for notifications
- Inventory file with hosts in group `project` (e.g., `ansible_hosts.ini`)

## Installation and Setup

### 1. Set Up Ansible
Install Ansible on the control machine:
```bash
sudo apt update
sudo apt install ansible -y
```

Set up SSH key-based authentication:
```bash
sudo apt install ssh -y
cd /etc/ssh/sshd_config.d
ls
```
Edit the SSH configuration file (e.g., `20-systemd-ssh-proxy.conf`):
```bash
nano 20-systemd-ssh-proxy.conf
```
Change `No` to `Yes` and save.

Generate SSH key pair:
```bash
ssh-keygen -t rsa -b 4096
ssh-copy-id user@remote_host
```
Copy the key to each controlled node and test the connection:
```bash
ssh user@remote_host
```

Configure Ansible:
```bash
cd /etc
mkdir ansible
touch /etc/ansible/hosts
touch /etc/ansible/ansible.cfg
```

Edit the hosts file:
```bash
nano /etc/ansible/hosts
```
Add:
```ini
[project]
192.168.0.0  # Controlled node IP
192.168.0.0  # Add more IPs as needed
[project:vars]
ansible_user=ubuntu  # Change to your system user
ansible_ssh_private_key_file=~/.ssh/id_rsa
```

Edit the Ansible configuration:
```bash
nano /etc/ansible/ansible.cfg
```
Add:
```ini
[defaults]
inventory = /etc/ansible/hosts
remote_user = ubuntu
```

Test the Ansible connection:
```bash
ansible project -m ping
```

### 2. Clone the Repository
Clone the project repository:
```bash
git clone https://github.com/Aryan-Singh5/Monitoring-and-Alerting-Automation-Tool.git
cd Monitoring-and-Alerting-Automation-Tool
```

Run the Ansible playbook to install dependencies:
```bash
ansible-playbook -i project playbook_for_package.yml
```
Or, if the inventory is configured globally:
```bash
ansible-playbook playbook_for_package.yml
```

### 3. Configure the Monitoring Script
Edit the monitoring script:
```bash
nano system_monitor_alert.sh
```
Update the following:
```bash
EMAIL_TO="youremail@gmail.com"  # Replace with your email
TELEGRAM_TOKEN="Telegram_Bot_Token"  # Replace with your Telegram bot token
TELEGRAM_CHAT_ID="Bot_Chat_Id"  # Replace with your Telegram bot chat ID
```

#### Getting Telegram Bot Token and Chat ID
1. Open Telegram and search for `@BotFather`.
2. Create a new bot using `/newbot` and follow the prompts.
3. Copy the bot token (e.g., `8123456789:ADG57ULzD_420CtHdliOiF_nP3MQ2m99Tf0`) and paste it into `TELEGRAM_TOKEN`.
4. Search for `@RawDataBot` on Telegram to get the chat ID.
5. Copy the `id` from the JSON output (e.g., `123456789`) and paste it into `TELEGRAM_CHAT_ID`.
6. Save the file.

### 4. Configure Email Notifications
Edit the Ansible playbook for deployment:
```bash
nano deploy_system_monitor.yml
```
Update the `ssmtp` configuration:
```yaml
- name: Configure ssmtp
  copy:
    content: |
      root=youremail@gmail.com  # Replace with your email
      mailhub=smtp.gmail.com:587
      AuthUser=youremail@gmail.com
      AuthPass=sxyrjdwyshfyhjnkg  # Replace with your Gmail App Password
    dest: /etc/ssmtp/ssmtp.conf
    mode: '0600'

- name: Configure ssmtp revaliases
  copy:
    content: |
      root:youremail@gmail.com:smtp.gmail.com:587  # Replace with your email
    dest: /etc/ssmtp/revaliases
    mode: '0600'
```

#### Getting Gmail App Password
1. Enable 2-Step Verification in your Google Account (`Security` settings).
2. Go to `Google Account → Security → App Passwords`.
3. Generate a 16-character app password and paste it into `AuthPass` (without spaces).

Save the file.

### 5. Deploy the Monitoring Tool
Run the Ansible playbook to deploy the monitoring tool:
```bash
ansible-playbook -i project deploy_system_monitor.yml
```
Or, if the inventory is configured globally:
```bash
ansible-playbook deploy_system_monitor.yml
```

### 6. Schedule Regular Monitoring (Optional)
Schedule the monitoring script to run hourly using `crontab`:
```bash
sudo crontab -e
```
Add the following line:
```bash
0 * * * * /usr/local/bin/system_monitor_alert.sh
```

### 7. Test the Script
Before automating, manually run the script on the host node to verify functionality:
```bash
bash /usr/local/bin/system_monitor_alert.sh
```

## Notes
- Ensure all scripts and configurations are tested manually on the host node before deployment.
- Verify SSH connectivity and Ansible setup before running playbooks.
- Check Gmail and Telegram configurations to ensure notifications are sent correctly.