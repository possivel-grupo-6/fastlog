job "fastlog-frontend" {
  type = "service"
  meta {
    version = "v1.0.0"
  }
  group "frontend-group" {
    count = 1

    network {
      port "http" {
        static = 3000  
      }
    }

    task "frontend-task" {
      driver = "docker"

      config {
        image = "joaomiziaraspt/fastlog-frontend:latest"  
        ports = ["http"]
      }
      template {
        data = <<EOF
{{- with service "fastlog-backend" }}
NEXT_PUBLIC_API_URL={{ (index . 0).Address }}
EOF
        destination = "local/env"  
        env         = true         
      }
      resources {
        cpu    = 500  
        memory = 256  
      }
  }
  
  service {
    name = "fastlog-frontend"  
    port = "http"             
    tags = ["frontend"] 

    check {
      name     = "HTTP Health Check"
      type     = "http"
      path     = "/"    
      interval = "10s"         
      timeout  = "2s"        
    }
  }
  }
}
