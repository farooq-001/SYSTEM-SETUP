#!/bin/bash

# Configuration
APP_PATH=/opt/snb-tech
LOG_PATH=/var/log
LOG_FILE=snb-tech-sysprep.log
SE_CONFIG=/etc/selinux/config
SUDOERS=/etc/sudoers

# User info
SNB_USER=snb-tech
SNB_PASSWD='Sanem25-AUG1999'

# Define SSH variables
USER="$SNB_USER"
SSH_DIR="/home/$USER/.ssh"
PUB_KEY_FILE="snb-tech-key.pub"
AUTH_KEYS_FILE="authorized_keys"
SSHD_CONFIG="/etc/ssh/sshd_config"

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
mkdir -p "$LOG_PATH"

# Redirect stdout and stderr to log file
exec > >(tee -i "$LOG_PATH/$LOG_FILE")
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
if [ -f "$SSHD_CONFIG" ]; then
    if grep -q "^PermitRootLogin" "$SSHD_CONFIG"; then
        sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' "$SSHD_CONFIG"
    else
        echo "PermitRootLogin yes" >> "$SSHD_CONFIG"
    fi

    if grep -q "^PasswordAuthentication" "$SSHD_CONFIG"; then
        sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD_CONFIG"
    else
        echo "PasswordAuthentication yes" >> "$SSHD_CONFIG"
    fi

    systemctl restart sshd
fi

# Create user if it doesn't exist
if ! id -u "$SNB_USER" &>/dev/null; then
    echo "Adding user $SNB_USER."
    useradd "$SNB_USER"
    echo "$SNB_USER:$SNB_PASSWD" | chpasswd
    usermod -aG wheel "$SNB_USER"  # Use wheel group for sudo access
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
if [ "$PACKAGE_MANAGER" = "yum" ]; then
    yum -y install htop vim nano net-tools wget tar tcpdump nc bind-utils figlet lolcat
else
    echo "Unsupported package manager for package installation."
    exit 1
fi

# Set history settings
echo 'export HISTTIMEFORMAT="%y/%m/%d %T "' >> /etc/profile.d/snb-tech-profile.sh
echo 'export HISTSIZE=100000' >> /etc/profile.d/snb-tech-profile.sh
echo 'export HISTFILESIZE=100000' >> /etc/profile.d/snb-tech-profile.sh
chmod +x /etc/profile.d/snb-tech-profile.sh

# Create sysprep marker file
mkdir -p "$APP_PATH"
touch "$APP_PATH/.sysprep"
echo "Sysprep completed."

# Install Python and related tools
yum install -y python3 python3-pip
pip3 install pyfiglet
yum groupinstall "Development Tools" -y
yum install ruby -y
sudo gem install lolcat


# Add welcome messages to .bashrc
# Add welcome messages to .bashrc
echo 'python3 -c "import pyfiglet; print(pyfiglet.figlet_format(\"SNB-TECH CYBER SOLUTIONS\", font=\"slant\"))" | lolcat' >> "/home/$SNB_USER/.bashrc"
echo 'python3 -c "import pyfiglet; print(pyfiglet.figlet_format(\"Welcome to Cyberworld\", font=\"digital\"))" | lolcat' >> "/home/$SNB_USER/.bashrc"

echo 'python3 -c "import pyfiglet; print(pyfiglet.figlet_format(\"## root ##\", font=\"slant\"))" | lolcat' >> /root/.bashrc
echo 'python3 -c "import pyfiglet; print(pyfiglet.figlet_format(\"Welcome to Cyberworld\", font=\"digital\"))" | lolcat' >> /root/.bashrc



# Ensure /home/snb-tech is the default directory on login
echo 'cd /home/snb-tech' >> "/home/$SNB_USER/.bashrc"

#### SSH Setup ###

# Create the .ssh directory
mkdir -p "$SSH_DIR"

# Move the public key and authorized_keys file
mv "$PUB_KEY_FILE" "$SSH_DIR/$PUB_KEY_FILE"
mv "$AUTH_KEYS_FILE" "$SSH_DIR/$AUTH_KEYS_FILE"

# Set permissions
chmod 755 "/home/$USER"
chmod 700 "$SSH_DIR"
chmod 600 "$SSH_DIR/$AUTH_KEYS_FILE"

# Change ownership
chown -R "$USER:$USER" "$SSH_DIR"
chown "$USER:$USER" "/home/$USER"

# Check and update PubkeyAuthentication
if ! grep -q "^PubkeyAuthentication yes" "$SSHD_CONFIG"; then
    echo "PubkeyAuthentication yes" | sudo tee -a "$SSHD_CONFIG"
    echo "Added 'PubkeyAuthentication yes' to $SSHD_CONFIG"
else
    echo "'PubkeyAuthentication' is already set to 'yes'."
fi

# Restart the sshd service
if systemctl restart sshd; then
    echo "sshd service restarted successfully."
else
    echo "Failed to restart sshd service."
fi

echo "SSH setup completed successfully."
python3 ip.py

echo "Welcome to SNB-TECH cyber solutions."
