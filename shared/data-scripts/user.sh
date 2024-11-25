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

# Configurar arquivos de Nomad e Consul
SERVER_COUNT=${server_count}
RETRY_JOIN="${retry_join}"
CONSUL_TOKEN=${nomad_consul_token_id}
NOMAD_TOKEN=${nomad_consul_token_secret}

# Capturar o endereço IP local
TOKEN=$(curl -X PUT "http://instance-data/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
IP_ADDRESS=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/local-ipv4)

# Instalar dependências
sudo apt-get update
sudo apt-get install -y unzip jq curl apt-transport-https ca-certificates gnupg2 software-properties-common
sudo apt-get clean
sudo ufw disable || echo "ufw não instalado"

# Baixar e instalar Consul
curl -L "https://releases.hashicorp.com/consul/$CONSUL_VERSION/consul_${CONSUL_VERSION}_linux_amd64.zip" > consul.zip
sudo unzip consul.zip -d /usr/local/bin
sudo chmod 0755 /usr/local/bin/consul
sudo mkdir -p "$CONSUL_CONFIG_DIR" "$CONSUL_DIR"
sudo chmod 755 "$CONSUL_CONFIG_DIR" "$CONSUL_DIR"

# Configurar Consul
sudo bash -c "cat > $CONSUL_CONFIG_DIR/consul.hcl" <<EOL
data_dir = "/opt/consul/data"
bind_addr = "0.0.0.0"
client_addr = "0.0.0.0"
advertise_addr = "$IP_ADDRESS"

bootstrap_expect = $SERVER_COUNT

acl {
    enabled = true
    default_policy = "deny"
    down_policy = "extend-cache"
    tokens {
      master = "$CONSUL_TOKEN"
    }
}

log_level = "INFO"
server = true
ui = true
retry_join = $RETRY_JOIN

connect {
  enabled = true
}

ports {
  grpc = 8502
}
EOL

# Criar serviço do Consul
sudo bash -c "cat > /etc/systemd/system/consul.service" <<EOL
[Unit]
Description=Consul
After=network.target
ConditionFileNotEmpty=$CONSUL_CONFIG_DIR/consul.hcl

[Service]
User=root
ExecStart=/usr/local/bin/consul agent -config-dir=$CONSUL_CONFIG_DIR
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOL

# Iniciar Consul
sudo systemctl daemon-reload
sudo systemctl enable consul.service
sudo systemctl start consul.service

# Configurar ACL no Consul
echo "Esperando Consul iniciar para configurar ACLs..."
sleep 10

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

# Configurar Nomad
sudo bash -c "cat > $NOMAD_CONFIG_DIR/nomad.hcl" <<EOL
data_dir  = "/opt/nomad/data"
bind_addr = "0.0.0.0"

advertise {
  http = "$IP_ADDRESS:4646"
  rpc  = "$IP_ADDRESS:4647"
  serf = "$IP_ADDRESS:4648"
}

server {
  enabled          = true
  bootstrap_expect = $SERVER_COUNT
}

client {
  enabled = true
  network_interface = "eth0"
}

consul {
  address = "127.0.0.1:8500"
  token   = "$NOMAD_TOKEN"
}
EOL

# Criar serviço do Nomad
sudo bash -c "cat > /etc/systemd/system/nomad.service" <<EOL
[Unit]
Description=Nomad
After=network.target
ConditionFileNotEmpty=$NOMAD_CONFIG_DIR/nomad.hcl

[Service]
User=root
ExecStart=/usr/local/bin/nomad agent -config=$NOMAD_CONFIG_DIR/nomad.hcl
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOL

# Iniciar Nomad
sudo systemctl daemon-reload
sudo systemctl enable nomad.service
sudo systemctl start nomad.service

# Status dos serviços
for service in consul nomad; do
  sudo systemctl status $service || echo "Erro ao iniciar $service"
done

echo "Consul e Nomad configurados com sucesso."
echo "Token Consul Master: $CONSUL_TOKEN"
echo "Token Nomad-Consul: $NOMAD_TOKEN"
