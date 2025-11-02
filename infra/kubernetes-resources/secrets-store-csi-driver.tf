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