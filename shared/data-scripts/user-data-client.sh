#!/bin/bash
set -e
# Configuração para saída de logs do user-data
exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
# Variáveis de Configuração
NOMAD_VERSION=${nomad_version}
CONSUL_VERSION=${consul_version}
NOMAD_DOWNLOAD="https://releases.hashicorp.com/nomad/$${NOMAD_VERSION}/nomad_$${NOMAD_VERSION}_linux_amd64.zip"
CONSUL_DOWNLOAD="https://releases.hashicorp.com/consul/$${CONSUL_VERSION}/consul_$${CONSUL_VERSION}_linux_amd64.zip"
NOMAD_CONFIG_DIR="/etc/nomad.d"
CONSUL_CONFIG_DIR="/etc/consul.d"
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
# Baixa e instala o Consul
curl -L $CONSUL_DOWNLOAD > consul.zip
sudo unzip consul.zip -d /usr/local/bin
sudo chmod 0755 /usr/local/bin/consul
sudo chown root:root /usr/local/bin/consul
# Cria diretórios de configuração para Nomad e Consul
sudo mkdir -p $NOMAD_CONFIG_DIR $CONSUL_CONFIG_DIR
sudo chmod 755 $NOMAD_CONFIG_DIR $CONSUL_CONFIG_DIR
# Configuração do retry_join com a tag AWS para descoberta automática no cluster
RETRY_JOIN="provider=aws tag_key=NomadJoinTag tag_value=auto-join"
# Configura o arquivo Consul para rodar como client
sed -i "s/IP_ADDRESS/$IP_ADDRESS/g" $CONFIG_DIR/consul_client.hcl
sed -i "s/RETRY_JOIN/$RETRY_JOIN/g" $CONFIG_DIR/consul_client.hcl
sudo cp $CONFIG_DIR/consul_client.hcl $CONSUL_CONFIG_DIR/consul.hcl
# Configura o arquivo Nomad para rodar como client
sed -i "s/IP_ADDRESS/$IP_ADDRESS/g" $CONFIG_DIR/nomad_client.hcl
sed -i "s/RETRY_JOIN/$RETRY_JOIN/g" $CONFIG_DIR/nomad_client.hcl
sudo cp $CONFIG_DIR/nomad_client.hcl $NOMAD_CONFIG_DIR/nomad.hcl
# Copia e ativa os serviços para Consul e Nomad
sudo cp $CONFIG_DIR/consul.service /etc/systemd/system/consul.service
sudo cp $CONFIG_DIR/nomad.service /etc/systemd/system/nomad.service
sudo systemctl enable consul.service
sudo systemctl start consul.service
sudo systemctl enable nomad.service
sudo systemctl start nomad.service
# Espera o Nomad se conectar ao cluster
for i in {1..9}; do
    sleep 2
    NOMAD_STATUS=$(nomad node status || true)
    if [[ $NOMAD_STATUS == *"ready"* ]]; then
        echo "Nomad client conectado ao cluster!"
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
# Configura as variáveis de ambiente
echo "export NOMAD_ADDR=http://$IP_ADDRESS:4646" | sudo tee --append /home/ubuntu/.bashrc
echo "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64" | sudo tee --append /home/ubuntu/.bashrc
# Configuração final do client
echo "Configuração completa! Nomad Client e Consul configurados com sucesso."