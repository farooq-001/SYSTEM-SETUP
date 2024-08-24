#!/bin/bash

# Configuration
APP_PATH=/opt/snb-tech
LOG_PATH=/var/log
LOG_FILE=snb-tech-sysprep.log

SE_CONFIG=/etc/selinux/config
SUDOERS=/etc/sudoers

SNB_USER=snb-tech
SNB_PASSWD='Sanem25-AUG1999'

# Determine the package manager and distribution
if command -v yum &>/dev/null; then
    PACKAGE_MANAGER="yum"
    DISTRO=$(awk -F= '/^ID=/ {print $2}' /etc/os-release)
elif command -v dnf &>/dev/null; then
    PACKAGE_MANAGER="dnf"
    DISTRO=$(awk -F= '/^ID=/ {print $2}' /etc/os-release)
elif command -v apt &>/dev/null; then
    PACKAGE_MANAGER="apt"
    DISTRO=$(lsb_release -si)
else
    echo "Unsupported package manager. Terminating script."
    exit 1
fi

# Ensure logging path exists
mkdir -p $LOG_PATH

# Redirect stdout and stderr to log file
exec > >(tee -i $LOG_PATH/$LOG_FILE)
exec 2>&1

prompt_confirm() {
  while true; do
    read -r -n 1 -p "${1:-Continue?} [y/n]: " REPLY
    case $REPLY in
      [yY]) echo ; return 0 ;;
      [nN]) echo ; return 1 ;;
      *) echo -e "\033[31mInvalid input\033[0m" ;;
    esac 
  done  
}

if [ "$EUID" -ne 0 ]; then
    echo ""
    echo 'Invalid User!!! Please login as root and rerun the script.'
    echo ""
    exit 1
fi

echo -n "Checking for Internet access..."
IP=$(curl -s ipinfo.io/ip 2>/dev/null)
if [ $? -eq 0 ]; then
    echo " Online."
else
    echo " Offline."
    echo ""
    echo "Check internet access and rerun script. Terminating Script!"
    exit 1
fi

# Modify SELinux configuration if SELinux is present
if [ "$PACKAGE_MANAGER" = "yum" ] || [ "$PACKAGE_MANAGER" = "dnf" ]; then
    if [ -f "$SE_CONFIG" ] && grep -q "SELINUX=enforcing" "$SE_CONFIG"; then
        sed -i "s/^SELINUX=enforcing.*$/SELINUX=permissive/" "$SE_CONFIG"
        echo "SELinux in enforcing mode, changed to permissive."
    fi
fi

# Update SSH configuration
if [ -f /etc/ssh/sshd_config ]; then
    if grep -q "^PermitRootLogin" /etc/ssh/sshd_config; then
        sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    else
        echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
    fi

    if grep -q "^PasswordAuthentication" /etc/ssh/sshd_config; then
        sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    else
        echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
    fi

    systemctl restart sshd
fi

# Create user if it doesn't exist
if ! id -u "$SNB_USER" &>/dev/null; then
    echo "Adding user $SNB_USER."
    if [ "$PACKAGE_MANAGER" = "yum" ] || [ "$PACKAGE_MANAGER" = "dnf" ]; then
        useradd "$SNB_USER"
    else
        adduser --disabled-password --gecos "" "$SNB_USER"
    fi
    echo "$SNB_USER:$SNB_PASSWD" | chpasswd
    usermod -aG sudo "$SNB_USER"
fi

# Update sudoers file
if ! grep -q "$SNB_USER" "$SUDOERS"; then
    echo "$SNB_USER ALL=(ALL) NOPASSWD: ALL" >> "$SUDOERS"
fi

# Set timezone and locale
echo "Changing timezone to UTC.."
timedatectl set-timezone UTC
localectl set-locale LANG=en_US.UTF-8

# Update and install packages
if [ "$PACKAGE_MANAGER" = "apt" ]; then
    apt update
    if [ $? -ne 0 ]; then
        echo "apt update failed. Terminating script."
        exit 1
    fi

    apt -y install software-properties-common
    if [ $? -ne 0 ]; then
        echo "Failed to install software-properties-common. Terminating script."
        exit 1
    fi

    add-apt-repository universe
    if [ $? -ne 0 ]; then
        echo "Failed to add universe repository. Terminating script."
        exit 1
    fi

    apt update
    if [ $? -ne 0 ]; then
        echo "apt update failed after adding universe repository. Terminating script."
        exit 1
    fi

    apt -y install htop vim nano net-tools wget tar tcpdump netcat-openbsd dnsutils figlet lolcat
    if [ $? -ne 0 ]; then
        echo "Failed to install packages. Terminating script."
        exit 1
    fi

    # Install firewalld only if available
    if apt-cache show firewalld &> /dev/null; then
        apt -y install firewalld
        if [ $? -ne 0 ]; then
            echo "Failed to install firewalld. Terminating script."
            exit 1
        fi
        systemctl enable firewalld
        systemctl start firewalld
    else
        echo "firewalld is not available in the repositories."
    fi
else
    # For yum/dnf
    $PACKAGE_MANAGER -y install epel-release
    if [ $? -ne 0 ]; then
        echo "Failed to install epel-release. Terminating script."
        exit 1
    fi

    $PACKAGE_MANAGER -y install htop vim nano net-tools wget tar tcpdump nc dnsutils figlet lolcat
    if [ $? -ne 0 ]; then
        echo "Failed to install packages. Terminating script."
        exit 1
    fi

    # Install firewalld
    if $PACKAGE_MANAGER list available firewalld &>/dev/null; then
        $PACKAGE_MANAGER -y install firewalld
        if [ $? -ne 0 ]; then
            echo "Failed to install firewalld. Terminating script."
            exit 1
        fi
        systemctl enable firewalld
        systemctl start firewalld
    else
        echo "firewalld is not available in the repositories."
    fi
fi

# Set history settings
echo 'export HISTTIMEFORMAT="%y/%m/%d %T "' >> /etc/profile.d/snb-tech-profile.sh
echo 'export HISTSIZE=100000' >> /etc/profile.d/snb-tech-profile.sh
echo 'export HISTFILESIZE=100000' >> /etc/profile.d/snb-tech-profile.sh
chmod +x /etc/profile.d/snb-tech-profile.sh

# Create sysprep marker file
mkdir -p /opt/snb-tech
touch /opt/snb-tech/.sysprep
echo "Sysprep completed."

# Add welcome messages to .bashrc
echo 'figlet -f slant -c "SNB_TECH CYBER SOLUTIONS" | lolcat' >> /home/snb-tech/.bashrc
echo 'figlet -f digital -c "Well come to cyberworld" | lolcat' >> /home/snb-tech/.bashrc

# Ensure /home/snb-tech is the default directory on login
echo 'cd /home/snb-tech' >> /home/snb-tech/.bashrc

echo "Welcome to SNB-TECH cyber solutions"
