#!/bin/bash
# Targets Debian-based systems (e.g., Ubuntu)
PACKAGES=("procps" "bc" "mailutils" "curl" "ssmtp" "sysstat" "vnstat" "lm-sensors" "smartmontools" "iproute2")


# Install all packages
for package in "${PACKAGES[@]}"; do
    if dpkg -l | grep -qw "$package"; then
        echo "$package is already installed"
    else
        echo "Installing $package..."
        apt-get install -y "$package"
        if [ $? -eq 0 ]; then
            echo "$package installed successfully"
        else
            echo "Error: Failed to install $package"
            exit 1
        fi
    fi
done
