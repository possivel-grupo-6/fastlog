job "fastlog-frontend" {
  type = "service"
  meta {
    version = "v1.0.0"
  }
  group "frontend-group" {
    count = 1

    network {
      port "http" {
        static = 3000  # Porta exposta para o frontend
      }
    }

    task "frontend-task" {
      driver = "docker"

      config {
        image = "joaomiziaraspt/fastlog-frontend:latest"  # Substitua pela sua imagem
        ports = ["http"]
      }

      env = {
        NEXT_PUBLIC_API_URL="http://54.167.113.239:8000"
        NODE_ENV="production"
      }

      resources {
        cpu    = 500  # Altere conforme necessário
        memory = 256  # Altere conforme necessário
      }
  }
  
  service {
    name = "fastlog-frontend"   # Nome do serviço no Consul
    port = "http"              # Porta que será registrada no Consul
    tags = ["frontend"]  # Tags para identificação no Consul

    check {
      name     = "HTTP Health Check"
      type     = "http"
      path     = "/"     # Endpoint de health check do backend
      interval = "10s"         # Frequência das verificações
      timeout  = "2s"          # Tempo de timeout da verificação
    }
  }
  }
}
