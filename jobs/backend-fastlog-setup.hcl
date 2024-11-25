job "fastlog-backend" {
  datacenters = ["dc1"]
  type = "service"

  group "backend-group" {
    network {
      port "http" {
        static = 8000  # Porta da API
      }

      port "db" {
        static = 3306  # Porta do MySQL
      }
    }

    task "backend-task" {
      driver = "docker"

      config {
        image = "joaomiziaraspt/fastlog-backend:latest"
        ports = ["http", "db"]  # Certifique-se de que a task conhece as portas
      }

      env = {
        DB_USER     = "fastlog-user"
        DB_PASSWORD = "fastlog-passwd"
        DB_HOST     = "23.20.132.252"  # IP da task com a porta db
        DB_PORT     = "3306"  # Porta para acessar o MySQL
        DB_NAME     = "fastlog"
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
