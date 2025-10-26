resource "aws_iam_role" "db_secret_role" {
  name = "db_secret_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.oidc.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
      }
    ]

  })
}

resource "aws_iam_policy" "db_secret_policy" {
  name = "db_secret_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadDBSecret"
        Effect = "Allow"
        Action = [
          "secretsmanager:*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "db_secret_role_policy_attachment" {
  policy_arn = aws_iam_policy.db_secret_policy.arn
  role = aws_iam_role.db_secret_role.name
}