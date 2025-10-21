
variable "todo_cluster_endpoint" {
  type = string
}
variable "todo_cluster_ca" {
  type = string
}
variable "todo_cluster_token" {
  type = string
}
variable "ebs_driver_role" {
  type = object({
    name = string
    arn = string
  })
}

variable "lb_role_arn" {
  type = string
}
variable "autoscaler_role_arn" {
  type = string
}
variable "cluster_name" {
  type = string
}
variable "aws_region" {
  type = string
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}