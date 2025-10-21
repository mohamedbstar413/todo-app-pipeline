# IAM Policy for my EBS CSI Driver
resource "aws_iam_policy" "lb_policy" {
  name        = "AmazonEKS_LB_Policy"
  description = "Policy for ingress-nginx controller"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:*",
          "ec2:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Role with OIDC trust policy
resource "aws_iam_role" "lb_role" {
  name       = "AWS_EKS_INGRESS_NGINX_Driver_Role"
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
resource "aws_iam_role_policy_attachment" "lb_attachment" {
  role       = aws_iam_role.lb_role.name
  policy_arn = aws_iam_policy.lb_policy.arn
}


