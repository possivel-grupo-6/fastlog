#!/bin/bash
set -e
exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
ACL_DIRECTORY="/ops/shared/config"
NOMAD_BOOTSTRAP_TOKEN="/tmp/nomad_bootstrap"
NOMAD_USER_TOKEN="/tmp/nomad_user_token"
CONFIGDIR="/ops/shared/config"
NOMADVERSION=${nomad_version}
NOMADDOWNLOAD=https://releases.hashicorp.com/nomad/$${NOMADVERSION}/nomad_$${NOMADVERSION}_linux_amd64.zip
CONSULVERSION="1.15.0"
CONSULDOWNLOAD=https://releases.hashicorp.com/consul/$CONSULVERSION/consul_$CONSULVERSION_linux_amd64.zip
NOMADCONFIGDIR="/etc/nomad.d"
NOMADDIR="/opt/nomad"
CONSULCONFIGDIR="/etc/consul.d"
CONSULDIR="/opt/consul"
HOME_DIR="ubuntu"
CLOUD_ENV=${cloud_env}
# Install dependencies
case $CLOUD_ENV in
  aws)
    echo "CLOUD_ENV: aws"
    sudo apt-get update && sudo apt-get install -y software-properties-common
    TOKEN=$(curl -X PUT "http://instance-data/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

    IP_ADDRESS=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/local-ipv4)
    PUBLIC_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/public-ipv4)
    ;;
  gce)
    echo "CLOUD_ENV: gce"
    sudo apt-get update && sudo apt-get install -y software-properties-common
    IP_ADDRESS=$(curl -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/network-interfaces/0/ip)
    ;;
  azure)
    echo "CLOUD_ENV: azure"
    sudo apt-get update && sudo apt-get install -y software-properties-common jq
    IP_ADDRESS=$(curl -s -H Metadata:true --noproxy "*" http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0?api-version=2021-12-13 | jq -r '.["privateIpAddress"]')
    ;;
  *)
    exit "CLOUD_ENV not set to one of aws, gce, or azure - exiting."
    ;;
esac
sudo apt-get update
sudo apt-get install -y unzip tree redis-tools jq curl tmux
sudo apt-get clean
# Disable the firewall
sudo ufw disable || echo "ufw not installed"
# Download and install Nomad
curl -L $NOMADDOWNLOAD > nomad.zip
sudo unzip nomad.zip -d /usr/local/bin
sudo chmod 0755 /usr/local/bin/nomad
sudo chown root:root /usr/local/bin/nomad
sudo mkdir -p $NOMADCONFIGDIR
sudo chmod 755 $NOMADCONFIGDIR
sudo mkdir -p $NOMADDIR
sudo chmod 755 $NOMADDIR
# Download and install Consul
curl -L $CONSULDOWNLOAD > consul.zip
sudo unzip consul.zip -d /usr/local/bin
sudo chmod 0755 /usr/local/bin/consul
sudo chown root:root /usr/local/bin/consul
sudo mkdir -p $CONSULCONFIGDIR
sudo chmod 755 $CONSULCONFIGDIR
sudo mkdir -p $CONSULDIR
sudo chmod 755 $CONSULDIR
# Docker
distro=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
sudo apt-get install -y apt-transport-https ca-certificates gnupg2 
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/$${distro} $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y docker-ce
# Configure and start Consul
cat <<-EOF | sudo tee $CONSULCONFIGDIR/consul.hcl
server = true
bootstrap_expect = 1
data_dir = "/opt/consul"
bind_addr = "$IP_ADDRESS"
client_addr = "0.0.0.0"
ui = true
retry_join = ["${retry_join}"]
EOF
cat <<-EOF | sudo tee /etc/systemd/system/consul.service
[Unit]
Description=Consul Agent
Requires=network-online.target
After=network-online.target

[Service]
User=root
ExecStart=/usr/local/bin/consul agent -config-dir=$CONSULCONFIGDIR
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable consul.service
sudo systemctl start consul.service
# Finalizar configuração do Nomad
SERVER_COUNT=${server_count}
RETRY_JOIN="${retry_join}"
sed -i "s/SERVER_COUNT/$SERVER_COUNT/g" $CONFIGDIR/nomad.hcl
sed -i "s/RETRY_JOIN/$RETRY_JOIN/g" $CONFIGDIR/nomad.hcl
sed -i "s/IP_ADDRESS/$IP_ADDRESS/g" $CONFIGDIR/nomad.hcl
sudo cp $CONFIGDIR/nomad.hcl $NOMADCONFIGDIR
sudo cp $CONFIGDIR/nomad.service /etc/systemd/system/nomad.service
sudo systemctl enable nomad.service
sudo systemctl start nomad.service
echo "Nomad and Consul setup complete"