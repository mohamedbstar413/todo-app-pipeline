resource "aws_eks_node_group" "todo_app_node_group" {
  node_group_name =             "todo_app_node_group"
  cluster_name =                aws_eks_cluster.todo_cluster.name
  node_role_arn =               aws_iam_role.todo_iam_role.arn
  subnet_ids =                  [var.subnet_1_id, var.subnet_2_id]
   scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }
  update_config {
    max_unavailable = 1
  }

  remote_access {
    ec2_ssh_key =                "new-key" #to allow ssh into nodes
  }

  instance_types =              [ "t3.micro" ]
}

resource "aws_iam_role" "todo_iam_role" {
  name = "todo_iam_role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "todo_role_container_policy_attach" {
  policy_arn = data.aws_iam_policy.eks_ec2_container_policy.arn
  role       = aws_iam_role.todo_iam_role.name
}

resource "aws_iam_role_policy_attachment" "todo_role_eks_cni_policy_attach" {
  policy_arn = data.aws_iam_policy.eks_cni_policy.arn
  role       = aws_iam_role.todo_iam_role.name
}

resource "aws_iam_role_policy_attachment" "todo_role_eks_worker_node_policy_attach" {
  policy_arn = data.aws_iam_policy.eks_worker_node_policy.arn
  role       = aws_iam_role.todo_iam_role.name
}