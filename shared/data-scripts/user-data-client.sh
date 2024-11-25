#!/bin/bash

set -e

# Configuração para saída de logs do user-data
exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Variáveis de Configuração
NOMAD_VERSION=${nomad_version}
NOMAD_DOWNLOAD="https://releases.hashicorp.com/nomad/$${NOMAD_VERSION}/nomad_$${NOMAD_VERSION}_linux_amd64.zip"
NOMAD_CONFIG_DIR="/etc/nomad.d"
CONSULVERSION="1.16.0"
CONSUL_DOWNLOAD="https://releases.hashicorp.com/consul/$${CONSULVERSION}/consul_$${CONSULVERSION}_linux_amd64.zip"
CONFIG_DIR="/ops/shared/config"

# Instala dependências iniciais
sudo apt-get update
sudo apt-get install -y unzip jq curl software-properties-common apt-transport-https ca-certificates gnupg2

# Obtém IP da instância EC2
TOKEN=$(curl -X PUT "http://instance-data/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
IP_ADDRESS=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/local-ipv4)

# Baixa e instala o Nomad
curl -L $NOMAD_DOWNLOAD > nomad.zip
sudo unzip nomad.zip -d /usr/local/bin
sudo chmod 0755 /usr/local/bin/nomad
sudo chown root:root /usr/local/bin/nomad
sudo mkdir -p $NOMAD_CONFIG_DIR
sudo chmod 755 $NOMAD_CONFIG_DIR

# Baixa e instala o Consul
curl -L $CONSUL_DOWNLOAD > consul.zip
sudo unzip consul.zip -d /usr/local/bin
sudo chmod 0755 /usr/local/bin/consul
sudo chown root:root /usr/local/bin/consul
sudo mkdir -p /etc/consul.d
sudo chmod 755 /etc/consul.d

# Configuração do retry_join com a tag AWS para descoberta automática de peers no cluster
RETRY_JOIN="provider=aws tag_key=NomadJoinTag tag_value=auto-join"

# Substitui as variáveis no arquivo de configuração do Nomad
sed -i "s/CONSUL_TOKEN/${nomad_consul_token_secret}/g" $CONFIG_DIR/nomad_client.hcl
sed -i "s/CONSUL_TOKEN/${nomad_consul_token_id}/g" $CONFIG_DIR/consul_client.hcl
sed -i "s/IP_ADDRESS/$IP_ADDRESS/g" $CONFIG_DIR/nomad_client.hcl
sed -i "s/RETRY_JOIN/$RETRY_JOIN/g" $CONFIG_DIR/nomad_client.hcl
sed -i "s/IP_ADDRESS/$IP_ADDRESS/g" $CONFIG_DIR/consul_client.hcl
sed -i "s/CONSUL_RETRY_JOIN/$CONSUL_RETRY_JOIN/g" $CONFIG_DIR/consul_client.hcl
sudo cp $CONFIG_DIR/consul_client.hcl /etc/consul.d/consul.hcl
sudo mkdir -p /opt/nomad/data
sudo chmod 755 /opt/nomad/data

# Copia o arquivo de configuração para o diretório correto
sudo cp $CONFIG_DIR/nomad_client.hcl $NOMAD_CONFIG_DIR/nomad.hcl

# Copia e ativa o serviço do Nomad
sudo cp $CONFIG_DIR/nomad.service /etc/systemd/system/nomad.service
sudo systemctl enable nomad.service
sudo systemctl start nomad.service

# Copia e ativa o serviço do Consul
sudo cp $CONFIG_DIR/consul.service /etc/systemd/system/consul.service
sudo systemctl enable consul.service
sudo systemctl start consul.service

# Espera o Nomad estabelecer a conexão com o cluster
for i in {1..9}; do
    sleep 2
    LEADER=$(nomad operator raft list-peers | grep leader || true)
    if [ -n "$LEADER" ]; then
        echo "Cluster leader encontrado: $LEADER"
        break
    fi
done

# Instalar o Docker
distro=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/$distro $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y docker-ce

# Habilitar e iniciar o Docker
sudo systemctl enable docker
sudo systemctl start docker

# Instalar Java (OpenJDK 8)
sudo add-apt-repository -y ppa:openjdk-r/ppa
sudo apt-get update
sudo apt-get install -y openjdk-8-jdk
JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:bin/java::")

# Configura a variável de ambiente para o Nomad
echo "export NOMAD_ADDR=http://$IP_ADDRESS:4646" | sudo tee --append /home/ubuntu/.bashrc
echo "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64" | sudo tee --append /home/ubuntu/.bashrc 

# Configuração final do servidor
echo "Configuração completa! Nomad, Docker e Java foram instalados com sucesso."
