job "fastlog-backend" {
  datacenters = ["dc1"]
  type = "service"

  group "backend-group" {
    count = 1  # Número de instâncias do backend

    network {
      port "http" {
        static = 8000  # Porta exposta pelo backend
      }
    }

    task "backend-task" {
      driver = "docker"

      config {
        image = "joaomiziaraspt/fastlog-backend:latest"  # Imagem Docker do backend
        ports = ["http"]  # Mapeamento para a porta HTTP
      }

      template {
        # Template para criar um arquivo de variáveis de ambiente baseado no Consul
        data = <<EOF
{{- with service "fastlog-mysql" }}
DB_HOST={{ (index . 0).Address }}
DB_PORT={{ (index . 0).Port }}
{{ else }}
DB_HOST=localhost
DB_PORT=3306
{{ end }}
EOF
        destination = "local/env"  # Caminho dentro do container
        env         = true         # Exporta as variáveis no ambiente
      }

      env = {
        DB_USER     = "fastlog-user",        # Usuário do banco de dados
        DB_PASSWORD = "fastlog-passwd",     # Senha do banco de dados
        DB_NAME     = "fastlog"             # Nome do banco de dados
      }

      resources {
        cpu    = 500   # Recursos de CPU
        memory = 512   # Recursos de memória
      }

      service {
        name = "fastlog-backend"  # Nome do serviço registrado no Consul
        port = "http"             # Porta associada ao serviço
        tags = ["backend", "api"] # Tags para identificação

        check {
          name     = "HTTP Health Check"
          type     = "http"
          path     = "/health"  # Endpoint de saúde
          interval = "10s"      # Intervalo da verificação
          timeout  = "2s"       # Tempo limite da verificação
        }
      }
    }
  }
}
