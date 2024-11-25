job "grafana" {
  datacenters = ["dc1"]
  meta {
        version = "v1.0.0"
    }
  group "grafana" {
    count = 1

    task "grafana" {
      driver = "docker"

      config {
        image = "grafana/grafana:latest"
        ports = ["http"]
      }

      resources {
        cpu    = 500
        memory = 256
      }

      env {
        GF_SECURITY_ADMIN_USER = "admin"
        GF_SECURITY_ADMIN_PASSWORD = "password"
      }


    }

    network {
      port "http" {
        static = 80
      }
    }
  }
}