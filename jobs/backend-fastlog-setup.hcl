job "fastlog-backend" {
  datacenters = ["dc1"]
  type = "service"

  group "backend-group" {
    network {
      port "http" {
        static = 8000  
      }
    }

    task "backend-task" {
      driver = "docker"

      config {
        image = "joaomiziaraspt/fastlog-backend:latest"
        ports = ["http"]  

      }
      env {
        DB_USER     = "fastlog-user"
        DB_PASSWORD = "fastlog-passwd"
        DB_HOST     = "${NOMAD_IP_db}"  # IP da porta "db"
        DB_PORT     = "${NOMAD_PORT_db}"  # Porta "db"
        DB_NAME     = "fastlog"
      }


      resources {
        cpu    = 500  
        memory = 512  
      }

      env {
        PYTHONUNBUFFERED = "1"
      }

      service {
        name = "fastlog-service"
        port = "http"
        provider = "nomad"
      }
    }
  }
}
