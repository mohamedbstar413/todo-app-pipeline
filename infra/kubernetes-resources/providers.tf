terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

provider "kubernetes" {
  host                   = var.todo_cluster_endpoint
  cluster_ca_certificate = base64decode(var.todo_cluster_ca)
  token                  = var.todo_cluster_token
}

provider "helm" {
  kubernetes {
    host                   = var.todo_cluster_endpoint
    cluster_ca_certificate = base64decode(var.todo_cluster_ca)
    token                  = var.todo_cluster_token
  }
}
