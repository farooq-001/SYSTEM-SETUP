sudo timedatectl set-timezone Asia/Kolkata


##### curl -sSL https://raw.githubusercontent.com/farooq-001/SYSTEM-SETUP/master/ec2-sysprep.sh | bash
##### curl -sSL https://raw.githubusercontent.com/farooq-001/SYSTEM-SETUP/master/sysprep.sh | bash

##### curl -sSL https://github.com/farooq-001/Docker-Install/blob/master/Install-docker-compose.sh | bash


# SYSTEM-SETUP 

# AWS-instance ssh

cp snb-tech-key.pub   /home/snb-tech/.ssh/authorized_keys

chmod 755 /home/snb-tech

chmod 700 /home/snb-tech/.ssh

chmod 600 /home/snb-tech/.ssh/authorized_keys

chown -R snb-tech:snb-tech /home/snb-tech/.ssh

chown snb-tech:snb-tech /home/snb-tech


sudo nano /etc/ssh/sshd_config

PubkeyAuthentication yes

PasswordAuthentication yes

sudo systemctl restart sshd
