job "meu-front-end" {
  type = "service"

  group "frontend-group" {
    count = 1

    network {
      port "http" {
        static = 8080  # Porta exposta para o frontend
      }
    }

    service {
      name     = "frontend-service"
      port     = "http"
      provider = "nomad"
    }

    task "frontend-task" {
      template {
        data        = <<EOH
API_URL=http://api-backend-endpoint:4000
NODE_ENV=production
EOH
        destination = "local/env.txt"
        env         = true
      }

      driver = "docker"

      config {
        image = "joaomiziaraspt/fastlog-frontend:latest"  # Substitua pela sua imagem
        ports = ["http"]
      }

      resources {
        cpu    = 500  # Altere conforme necessário
        memory = 256  # Altere conforme necessário
      }
    }
  }
}

