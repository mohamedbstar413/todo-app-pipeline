output "todo_cluster_endpoint" {
  value = aws_eks_cluster.todo_cluster.endpoint
}

output "todo_cluster_ca" {
  value = aws_eks_cluster.todo_cluster.certificate_authority[0].data
}

output "todo_cluster_token" {
  value = data.aws_eks_cluster_auth.todo_cluster.token
}
output "ebs_driver_role" {
  value = aws_iam_role.ebs_csi_role
}
#lb role ARN
output "lb_role_arn" {
  description = "ARN of the IAM role for ingress-nginx controller"
  value       = aws_iam_role.lb_role.arn
}
#ebs csi driver role ARN
output "ebs_csi_role_arn" {
  description = "ARN of the IAM role for EBS CSI driver"
  value       = aws_iam_role.ebs_csi_role.arn
}

#autoscaler role arn
output "autoscaler_role_arn" {
  value = aws_iam_role.auto_scaler_role.arn
}

output "todo_cluster" {
  value = aws_eks_cluster.todo_cluster
}
output "todo_front_nginx_config_s3" {
  value = aws_s3_bucket.todo_front_nginx_config_s3
}

output "oidc_provider_arn" {
  value = data.aws_iam_openid_connect_provider.oidc_provider.arn
}