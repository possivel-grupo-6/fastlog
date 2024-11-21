job "frontend" {
  datacenters = ["dc1"]
  type = "service"

  group "frontend-group" {
    count = 1

    network {
      port "http" {
        static = 8080  # A porta do host onde o serviço será exposto
      }
    }

    task "frontend" {
      driver = "docker"

      config {
        image = "joaomiziaraspt/fastlog-frontend:latest"
        ports = ["http"]  
      }

      resources {
        cpu    = 500    # 500 MHz
        memory = 256    # 256 MB
      }
    }
  }
}
