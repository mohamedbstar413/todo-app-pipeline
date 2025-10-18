# IAM Policy for my EBS CSI Driver
resource "aws_iam_policy" "ebs_csi_policy" {
  name        = "AmazonEKS_EBS_CSI_Driver_Policy"
  description = "Policy for AWS EBS CSI Driver"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Role with OIDC trust policy
resource "aws_iam_role" "ebs_csi_role" {
  name = "AWS_EKS_EBS_CSI_Driver_Role"
  depends_on = [ aws_eks_cluster.todo_cluster ]
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
resource "aws_iam_role_policy_attachment" "ebs_csi_attachment" {
  role       = aws_iam_role.ebs_csi_role.name
  policy_arn = aws_iam_policy.ebs_csi_policy.arn
}

#role ARN
output "ebs_csi_role_arn" {
  description = "ARN of the IAM role for EBS CSI driver"
  value       = aws_iam_role.ebs_csi_role.arn
}