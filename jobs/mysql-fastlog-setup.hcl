job "mysql" {
  datacenters = ["dc1"]
  type = "service"

  group "mysql-group" {
    network {
      port "db" {
        static = 3306  
      }
    }

    task "mysql-task" {
      driver = "docker"

      config {
        image = "mysql:8.0"  
        ports = ["db"]      
      }
        env = {
          MYSQL_ROOT_PASSWORD = "urubu100"  
          MYSQL_DATABASE = "fastlog"        
          MYSQL_USER = "fastlog-user"                
          MYSQL_PASSWORD = "fastlog-passwd"        
        }

      resources {
        cpu    = 500  
        memory = 512 
      }

      service {
        name = "mysql-service"
        port = "db"
        provider = "nomad"
      }
    }
  }
}
