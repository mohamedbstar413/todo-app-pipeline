# IAM Policy for my kube autoscaler
resource "aws_iam_policy" "auto_scaler_policy" {
  name        = "AmazonEKS_AutoScaling_Policy"
  description = "Policy for cluster auto scaler"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:*",
          "ec2:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Role with OIDC trust policy
resource "aws_iam_role" "auto_scaler_role" {
  name       = "AWS_EKS_Cluster_Auto_Scaler_Role"
  depends_on = [aws_eks_cluster.todo_cluster]
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.oidc_provider.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "auto_scaler_attachment" {
  role       = aws_iam_role.auto_scaler_role.name
  policy_arn = aws_iam_policy.auto_scaler_policy.arn
}


