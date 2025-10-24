# IAM Policy for my EBS CSI Driver
resource "aws_iam_policy" "kms_policy" {
  name        = "AmazonEKS_KMS_Policy"
  description = "Policy for AWS KMS"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Role with OIDC trust policy
resource "aws_iam_role" "kms_role" {
  name = "AWS_EKS_KMS_Role"
  depends_on = [ helm_release.aws_ebs_csi_driver ] #just to make sure the cluster is created
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "kms_attachment" {
  role       = aws_iam_role.kms_role.name
  policy_arn = aws_iam_policy.kms_policy.arn
}

