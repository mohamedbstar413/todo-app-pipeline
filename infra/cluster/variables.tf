variable "subnet_1_id" {
  type = string
}

variable "subnet_2_id" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "namespace" {
  description = "Kubernetes namespace for the ServiceAccount"
  type        = string
  default     = "kube-system"
}

variable "service_account_name" {
  description = "Kubernetes ServiceAccount name"
  type        = string
  default     = "ebs-csi-controller-sa"
}


variable "vpc_id" {
  type = string
}

/*
Load Balancer Variables
*/

variable "lb_iam_policy_url" {
  type    = string
  default = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.14.0/docs/install/iam_policy.json"
  description = "URL to the official iam_policy.json."
}

variable "lb_iam_policy_name" {
  type    = string
  default = "AWSLoadBalancerControllerIAMPolicy"
}

variable "lb_iam_role_name" {
  type    = string
  default = "AWS_EKS_ALB_Controller_Role"
}

variable "lb_controller_sa_namespace" {
  type    = string
  default = "kube-system"
}

variable "lb_controller_sa_name" {
  type    = string
  default = "aws-load-balancer-controller"
}
