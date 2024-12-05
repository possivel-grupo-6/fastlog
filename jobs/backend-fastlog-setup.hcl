job "fastlog-backend" {
  datacenters = ["dc1"]
  type = "service"
  meta {
    version = "v2.0.0"
  }
  group "backend-group" {
    count = 1  

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

      template {
        data = <<EOF
{{- with service "fastlog-mysql" }}
DB_HOST={{ (index . 0).Address }}
DB_PORT={{ (index . 0).Port }}
{{ else }}
DB_HOST=localhost
DB_PORT=3306
{{ end }}
EOF
        destination = "local/env"  
        env         = true      
      }

      env = {
        DB_USER     = "fastlog-user",      
        DB_PASSWORD = "fastlog-passwd",  
        DB_NAME     = "fastlog"       
      }

      resources {
        cpu    = 500  
        memory = 512 
      }

      service {
        name = "fastlog-backend"  
        port = "http"             
        tags = ["backend", "api"] 
        provider = "consul"      


        check {
          name     = "HTTP Health Check"
          type     = "http"
          path     = "/health" 
          interval = "10s"     
          timeout  = "2s"       
        }
      }
    }
  }
}
