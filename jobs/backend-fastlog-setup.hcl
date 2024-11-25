job "fastlog-backendv2" {
  datacenters = ["dc1"]
  type = "service"
  meta {
    version = "v10.0.0"
  }
  group "backend-group" {
    network {
      port "http" {
        static = 8000  # Porta da API
      }
    }

    task "backend-task" {
      driver = "docker"

      config {
        image = "joaomiziaraspt/fastlog-backend:latest"
        ports = ["http"]  # Certifique-se de que a task conhece as portas
      }

      env = {
        DB_USER="fastlog-user"
        DB_PASSWORD="fastlog-passwd"
        DB_HOST="3.88.24.129" 
        DB_PORT="3306"
        DB_NAME="fastlog"
      }

      resources {
        cpu    = 500
        memory = 512
      }

      service {
        name = "fastlog-service"
        port = "http"
        provider = "nomad"
      }
    }
  }
}
