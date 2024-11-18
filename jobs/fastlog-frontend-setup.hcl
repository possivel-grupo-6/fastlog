job "frontend" {
  datacenters = ["dc1"]
  type = "service"

  group "frontend-group" {
    count = 1

    task "frontend" {
      driver = "docker"
      
      config {
        image = "seu-usuario-dockerhub/seu-app-frontend:latest"
        port_map {
          http = 80
        }
      }

      resources {
        network {
          port "http" {
            static = 8081
          }
        }
      }

      service {
        name = "frontend-service"
        port = "http"
        
        check {
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
