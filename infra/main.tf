provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket = "todo-s3-remote-backend-14120"
    region = "us-east-1"
    key = "terraform.tfstate"
    use_lockfile = true
  }
}

module "network" {
  source            = "./network"
  vpc_cidr          = "10.0.0.0/16"
  pub_subnet_1_cidr = "10.0.0.0/24"
  pub_subnet_2_cidr = "10.0.1.0/24"
  az_1              = "us-east-1a"
  az_2              = "us-east-1b"
  cluster_name      = "todo-app-cluster"
}

module "cluster" {
  source       = "./cluster"
  subnet_1_id  = module.network.subnet_1_id
  subnet_2_id  = module.network.subnet_2_id
  cluster_name = "todo-app-cluster"
  vpc_id       = module.network.vpc_id
}
module "kubernetes_resources" {
  source                = "./kubernetes-resources"
  todo_cluster_ca       = module.cluster.todo_cluster_ca
  todo_cluster_endpoint = module.cluster.todo_cluster_endpoint
  todo_cluster_token    = module.cluster.todo_cluster_token
  ebs_driver_role       = module.cluster.ebs_driver_role
  lb_role_arn           = module.cluster.lb_role_arn
  autoscaler_role_arn   = module.cluster.autoscaler_role_arn
  cluster_name          = "todo-app-cluster"
  aws_region            = "us-east-1"
  grafana_admin_password = "admin123"
  todo_cluster = module.cluster.todo_cluster
  todo_front_nginx_config_s3  = module.cluster.todo_front_nginx_config_s3
  oidc_provider_arn = module.cluster.oidc_provider_arn
  db_password = var.db_password
}
