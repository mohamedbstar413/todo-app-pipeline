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