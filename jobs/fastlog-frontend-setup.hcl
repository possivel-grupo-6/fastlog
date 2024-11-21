job "fastlog-web" {
  type = "service"

  group "ptc-web" {
    count = 1
    network {
      port "web" {
        static = 8080
      }
    }
    service {
      name     = "ptc-web-svc"
      port     = "web"
      provider = "nomad"
    }

    task "frontend" {
      driver = "docker"

      config {
        image = "joaomiziaraspt/fastlog-frontend:latest"
        ports = ["web"]  
      }
    }
  }
}
