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
