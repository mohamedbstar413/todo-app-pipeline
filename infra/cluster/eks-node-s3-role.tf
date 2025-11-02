# IAM Policy for my EBS CSI Driver
resource "aws_iam_policy" "s3_policy" {
  name        = "AmazonEKS_S3_Policy"
  description = "Policy for node to get s3 contents"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:*"
        ]

        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.todo_front_nginx_config_s3.bucket}/*",  # Objects in the bucket
          "arn:aws:s3:::${aws_s3_bucket.todo_front_nginx_config_s3.bucket}"     # Bucket itself
        ]
      }
    ]
  })
}

# IAM Role with OIDC trust policy
resource "aws_iam_role" "s3_role" {
  name       = "AWS_EKS_NODE_S3_Role"
  depends_on = [aws_eks_cluster.todo_cluster]
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "s3_attachment" {
  role       = aws_iam_role.s3_role.name
  policy_arn = aws_iam_policy.s3_policy.arn
}