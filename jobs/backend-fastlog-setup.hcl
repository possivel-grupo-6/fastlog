job "fastlog-backend" {
  datacenters = ["dc1"]
  type = "service"

  group "fastlog-backend-group" {
    network {
      port "http" {
        static = 8000  # Porta exposta pelo container
      }
    }

    task "fastlog-backend-task" {
      driver = "docker"

      config {
        image = "joaomiziaraspt/fastlog-backend:latest"
        port_map {
          http = 8000
        }
      }

      resources {
        cpu    = 500  # Quantidade de CPU (em MHz)
        memory = 512  # Quantidade de memória (em MB)
      }

      env {
        PYTHONUNBUFFERED = "1"
      }

      service {
        name = "fastlog-backend-service"
        tags = ["http"]
        port = "http"
        check {
          name     = "HTTP Check"
          type     = "http"
          port     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}