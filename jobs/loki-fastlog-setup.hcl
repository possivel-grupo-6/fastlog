job "loki" {
  datacenters = ["dc1"]

  group "loki" {
    count = 1

    task "loki" {
      driver = "docker"

      config {
        image = "grafana/loki:latest"
        ports = ["http", "grpc"]
      }

      resources {
        cpu    = 500
        memory = 256
      }

      env {
        LOKI_CONFIG_FILE = "/etc/loki/config.yaml"
      }

      template {
        data = <<EOF
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
  chunk_idle_period: 5m
  chunk_retain_period: 30s

EOF
        destination = "local/etc/loki/config.yaml"
      }
    }

    network {
      port "http" {
        static = 3100
      }

      port "grpc" {
        static = 9095
      }
    }
  }
}
