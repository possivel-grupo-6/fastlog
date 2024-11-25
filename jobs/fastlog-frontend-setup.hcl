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

    service {
      name     = "frontend-service"
      port     = "http"
      provider = "nomad"
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
  }
}
