data "aws_iam_role" "ebs_csi_driver_role" {
    depends_on = [ var.ebs_driver_role ]
  name = "AWS_EKS_EBS_CSI_Driver_Role"
}
# Data source to fetch the ingress-nginx service
data "kubernetes_service" "nginx_ingress" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = "ingress-nginx"
  }

  # Ensure this runs after the Helm release is applied
  depends_on = [helm_release.nginx_ingress]
}

data "aws_caller_identity" "my_account" {}