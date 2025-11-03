resource "helm_release" "secrets_store_csi_driver" {
  name       = "secrets-store-csi-driver"
  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"
  namespace  = "kube-system"

  set {
    name  = "syncSecret.enabled" #to create a kubernetes secret after mounting into volume
    value = "true"
  }

  set {
    name  = "enableSecretRotation"
    value = "false"
  }
}


#a service account for the secrets_store_csi_driver_provider_aws
resource "kubernetes_service_account" "secrets_store_csi_driver_aws_sa" {
  metadata {
    name =    "secrets-store-csi-driver-aws"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${aws_iam_role.secrets_store_csi_driver_aws_sa_role.name}"
    }
  }
}

# aws role for the secrets_store_csi_driver_aws_sa
resource "aws_iam_role" "secrets_store_csi_driver_aws_sa_role" {
  name =      "secrets-store-csi-driver-aws-sa-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn #aws_iam_openid_connect_provider.oidc.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
      }
    ]

  })
}

resource "aws_iam_policy" "secrets_store_csi_driver_aws_sa_policy" {
  name =          "secrets-store-csi-driver-aws-sa-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:*"
        ]
        Resource = "*"
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "secret_store_csi_driver_role_policy_attachment" {
  policy_arn = aws_iam_policy.secrets_store_csi_driver_aws_sa_policy.arn
  role = aws_iam_role.secrets_store_csi_driver_aws_sa_role.name
}

resource "helm_release" "secrets_store_csi_driver_provider_aws" {
  name       = "secrets-store-csi-driver-provider-aws"
  repository = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  chart      = "secrets-store-csi-driver-provider-aws"
  namespace  = "kube-system"

  set {
    name = "secrets-store-csi-driver.install"
    value = "false"
  }
  /*set {
    name = "serviceAccount.name"
    value  = "secrets-store-csi-driver"
  }*/
  

  depends_on = [
    kubernetes_service_account.secrets_store_csi_driver_aws_sa
  ]
}
# a service account to attach to the csi driver
resource "kubernetes_service_account" "db_secret_sa" {
  metadata {
    name      = "db-secret-sa"
    namespace = "db-ns"
    annotations = {
      "eks.amazonaws.com/role-arn" = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${aws_iam_role.db_secret_role.name}"
    }
  }
} 