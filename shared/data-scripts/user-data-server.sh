#!/bin/bash

set -e

# Redirecionar logs para user-data.log
exec > >(sudo tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

# Variáveis principais
ACL_DIRECTORY="/ops/shared/config"
NOMAD_BOOTSTRAP_TOKEN="/tmp/nomad_bootstrap"
NOMAD_USER_TOKEN="/tmp/nomad_user_token"
CONFIGDIR="/ops/shared/config"
NOMAD_VERSION=${nomad_version}
NOMAD_DOWNLOAD="https://releases.hashicorp.com/nomad/$${NOMAD_VERSION}/nomad_$${NOMAD_VERSION}_linux_amd64.zip"
NOMAD_CONFIG_DIR="/etc/nomad.d"
NOMAD_DIR="/opt/nomad"
CONSUL_VERSION="1.16.1"
CONSUL_DOWNLOAD="https://releases.hashicorp.com/consul/$${CONSUL_VERSION}/consul_$${CONSUL_VERSION}_linux_amd64.zip"
CONSUL_CONFIG_DIR="/etc/consul.d"
CONSUL_DIR="/opt/consul"
HOME_DIR="ubuntu"
CLOUD_ENV=${cloud_env}

SERVER_COUNT=${server_count}
RETRY_JOIN="${retry_join}"
CONSUL_TOKEN=${nomad_consul_token_id}
NOMAD_TOKEN=${nomad_consul_token_secret}

# Capturar o endereço IP local
TOKEN=$(curl -X PUT "http://instance-data/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
IP_ADDRESS=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/local-ipv4)

# Instalar dependências
sudo apt-get update
sudo apt-get install -y unzip tree redis-tools jq curl tmux apt-transport-https ca-certificates gnupg2 software-properties-common
sudo apt-get clean
sudo ufw disable || echo "ufw não instalado"

# Baixar e instalar Nomad
curl -L "$NOMAD_DOWNLOAD" > nomad.zip
sudo unzip nomad.zip -d /usr/local/bin
sudo chmod 0755 /usr/local/bin/nomad
sudo mkdir -p "$NOMAD_CONFIG_DIR" "$NOMAD_DIR"
sudo chmod 755 "$NOMAD_CONFIG_DIR" "$NOMAD_DIR"

# Baixar e instalar Consul
curl -L "$CONSUL_DOWNLOAD" > consul.zip
sudo unzip consul.zip -d /usr/local/bin
sudo chmod 0755 /usr/local/bin/consul
sudo mkdir -p "$CONSUL_CONFIG_DIR" "$CONSUL_DIR"
sudo chmod 755 "$CONSUL_CONFIG_DIR" "$CONSUL_DIR"

# Instalar Docker
distro=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/$distro $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y docker-ce
sudo systemctl enable docker
sudo systemctl start docker

# Instalar Java
sudo add-apt-repository -y ppa:openjdk-r/ppa
sudo apt-get update
sudo apt-get install -y openjdk-8-jdk
JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:bin/java::")

# Configurar Nomad
sed -i "s/CONSUL_TOKEN/$NOMAD_TOKEN/g" "$CONFIGDIR/nomad.hcl"
sed -i "s/SERVER_COUNT/$SERVER_COUNT/g" "$CONFIGDIR/nomad.hcl"
sed -i "s/RETRY_JOIN/$RETRY_JOIN/g" "$CONFIGDIR/nomad.hcl"
sed -i "s/IP_ADDRESS/$IP_ADDRESS/g" "$CONFIGDIR/nomad.hcl"
sudo cp "$CONFIGDIR/nomad.hcl" "$NOMAD_CONFIG_DIR"
sudo cp "$CONFIGDIR/nomad.service" /etc/systemd/system/nomad.service

sudo systemctl enable nomad.service
sudo systemctl start nomad.service

# Configurar Consul
sed -i "s/CONSUL_TOKEN/$CONSUL_TOKEN/g" "$CONFIGDIR/consul.hcl"
sed -i "s/SERVER_COUNT/$SERVER_COUNT/g" "$CONFIGDIR/consul.hcl"
sed -i "s/RETRY_JOIN/$RETRY_JOIN/g" "$CONFIGDIR/consul.hcl"
sed -i "s/IP_ADDRESS/$IP_ADDRESS/g" "$CONFIGDIR/consul.hcl"
sudo cp "$CONFIGDIR/consul.hcl" "$CONSUL_CONFIG_DIR"
sudo cp "$CONFIGDIR/consul.service" /etc/systemd/system/consul.service

sudo systemctl enable consul.service
sudo systemctl start consul.service

# Criar política e token para integração Nomad + Consul
cat > nomad-policy.hcl <<EOL
node_prefix "" {
  policy = "write"
}

service_prefix "" {
  policy = "read"
}

agent_prefix "" {
  policy = "read"
}

session_prefix "" {
  policy = "write"
}
EOL

# Aplicar política no Consul
consul acl policy create -name "nomad-policy" -rules @nomad-policy.hcl -token "$CONSUL_TOKEN"

# Criar token específico para Nomad
consul acl token create -description "Nomad Integration Token" -policy-name "nomad-policy" -token "$CONSUL_TOKEN" > /dev/null
sudo systemctl restart consul

# Adicionar IP ao /etc/hosts
echo "127.0.0.1 $(hostname)" | sudo tee --append /etc/hosts

# Configurar variáveis de ambiente
echo "export NOMAD_ADDR=http://$IP_ADDRESS:4646" | sudo tee --append "/home/$HOME_DIR/.bashrc"
echo "export CONSUL_ADDR=http://$IP_ADDRESS:8500" | sudo tee --append "/home/$HOME_DIR/.bashrc"
echo "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/jre" | sudo tee --append "/home/$HOME_DIR/.bashrc"

# Verificar status dos serviços
for service in nomad consul; do
  sudo systemctl status $service || echo "Erro ao iniciar $service"
done

echo "Configuração completa."
