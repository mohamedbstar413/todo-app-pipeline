data "aws_iam_role" "cluster_role" {
  name =                "AmazonEKSAutoClusterRole"
}

data "aws_iam_policy" "eks_ec2_container_policy" {
  name = "AmazonEC2ContainerRegistryReadOnly"
}

data "aws_iam_policy" "eks_cni_policy" {
  name = "AmazonEKS_CNI_Policy"
}

data "aws_iam_policy" "eks_worker_node_policy" {
  name = "AmazonEKSWorkerNodePolicy"
}
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical’s official AWS account ID
}

data "aws_caller_identity" "current" {}

# Data source to get the EKS cluster OIDC issuer URL
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
  depends_on = [ aws_eks_cluster.todo_cluster ]
}

# Data source to get the OIDC provider ARN
data "aws_iam_openid_connect_provider" "oidc_provider" {
  url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
  depends_on = [ aws_eks_cluster.todo_cluster , aws_iam_openid_connect_provider.oidc_provider]
}