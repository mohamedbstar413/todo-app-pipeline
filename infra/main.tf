provider "aws" {
  region = "us-east-1"
}

module "network" {
  source = "./network"
  vpc_cidr = "10.0.0.0/16"
  pub_subnet_1_cidr = "10.0.0.0/24"
  pub_subnet_2_cidr = "10.0.1.0/24"
  az_1 = "us-east-1a"
  az_2 = "us-east-1b"
  cluster_name = "todo-app-cluster"
}

module "cluster" {
  source = "./cluster"
  subnet_1_id = module.network.subnet_1_id
  subnet_2_id = module.network.subnet_2_id
  cluster_name = "todo-app-cluster"
  vpc_id = module.network.vpc_id
}