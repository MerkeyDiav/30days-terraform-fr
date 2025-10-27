# jour2/modules/ec2/scripts/cloud-init.sh
#!/bin/bash
apt-get update
apt-get install -y htop nginx
systemctl enable nginx
systemctl start nginx