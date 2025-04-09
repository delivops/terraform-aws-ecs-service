module "client_server_ecs_service" {
  source = "../"

  ecs_cluster_name   = var.cluster_name
  ecs_service_name   = "client-server"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  service_connect = {
    enabled = true
    type    = "client-server"
  }

}
//if not found namespace, can't create the module
//expected: port mapping in the default port (80), or the port filed in service_connect
// create 3 resources











