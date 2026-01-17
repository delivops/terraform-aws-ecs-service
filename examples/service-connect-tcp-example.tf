module "ecs_service_tcp" {
  source = "../"

  ecs_cluster_name   = "my-cluster"
  ecs_service_name   = "tcp-service"
  vpc_id             = "vpc-12345678"
  security_group_ids = ["sg-12345678"]
  subnet_ids         = ["subnet-12345678", "subnet-87654321"]

  container_name  = "tcp-app"
  container_image = "my-tcp-app:latest"

  service_connect = {
    enabled     = true
    type        = "client-server"
    port        = 8080
    name        = "tcp-service"
    appProtocol = "tcp" # This will omit appProtocol from portMappings
    additional_ports = [
      {
        name        = "admin"
        port        = 9090
        appProtocol = "http" # This will include appProtocol = "http"
      },
      {
        name        = "metrics"
        port        = 9091
        appProtocol = "tcp" # This will omit appProtocol from portMappings
      }
    ]
  }

  tags = {
    Environment = "production"
    Service     = "tcp-service"
  }
}
