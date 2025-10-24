#NGINX Ingress Controller
# NGINX Ingress Controller
resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  version          = "4.8.3"

  # Expose via AWS Load Balancer
  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  # Use AWS Network Load Balancer (NLB)
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = "nlb"
  }
  # Make it INTERNET-FACING
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
    value = "internet-facing"
  }

  #cross-zone balancing
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-cross-zone-load-balancing-enabled"
    value = "true"
  }
  # Specify the service account with IAM role
  set {
    name  = "controller.serviceAccount.create"
    value = "true"
  }
  set {
    name  = "controller.serviceAccount.name"
    value = "ingress-nginx"
  }
  set {
    name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.lb_role_arn
  }
  depends_on = [
    var.todo_cluster, # Ensure cluster is active

    var.todo_front_nginx_config_s3 # Ensure S3 bucket exists for user_data
  ]
}

resource "helm_release" "aws_ebs_csi_driver" {
  name       = "aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  namespace  = "kube-system"
  version    = "2.26.0"

  set {
    name  = "controller.serviceAccount.create"
    value = "true"
  }

  set {
    name  = "controller.serviceAccount.name"
    value = "ebs-csi-controller-sa"
  }

  #IAM Roles for ebs-csi-controller-sa Service Account
  set {
    name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.ebs_driver_role.arn
  }
  depends_on = [
    var.todo_cluster,              # Ensure cluster is active
    var.todo_front_nginx_config_s3 # Ensure S3 bucket exists for user_data
  ]

}

#Metrics Server
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.11.0"

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }
  depends_on = [
    var.todo_cluster,              # Ensure cluster is active
    var.todo_front_nginx_config_s3 # Ensure S3 bucket exists for user_data
  ]
}

#Prometheus & Grafana Stack
resource "helm_release" "prometheus" {
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  version          = "55.0.0"

  set {
    name  = "grafana.enabled"
    value = "true"
  }

  set {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }
  depends_on = [
    var.todo_cluster,              # Ensure cluster is active
    var.todo_front_nginx_config_s3 # Ensure S3 bucket exists for user_data
  ]
}


#ArgoCD (GitOps)
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "5.51.6"

  values = [
    yamlencode({
      server = {
        service = {
          type = "LoadBalancer"
        }
      }
    })
  ]
  depends_on = [
    var.todo_cluster,              # Ensure cluster is active
    var.todo_front_nginx_config_s3 # Ensure S3 bucket exists for user_data
  ]
}

#External DNS (for automatic DNS management)
resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = "kube-system"
  version    = "1.14.0"

  set {
    name  = "provider"
    value = "aws"
  }

  set {
    name  = "aws.region"
    value = "us-east-1"
  }

  set {
    name  = "txtOwnerId"
    value = var.cluster_name
  }

  set {
    name  = "policy"
    value = "sync"
  }
  depends_on = [
    var.todo_cluster,              # Ensure cluster is active
    var.todo_front_nginx_config_s3 # Ensure S3 bucket exists for user_data
  ]
}

#Cluster Autoscaler
resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  version    = "9.29.3"

  set {
    name  = "autoDiscovery.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "awsRegion"
    value = var.aws_region
  }

  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.autoscaler_role_arn
  }
  depends_on = [
    var.todo_cluster,              # Ensure cluster is active
    var.todo_front_nginx_config_s3 # Ensure S3 bucket exists for user_data
  ]
}

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "vault_key" {
  description             = "An example symmetric encryption KMS key"
  enable_key_rotation     = true
  deletion_window_in_days = 20
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "key-default-1"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.my_account.account_id}:root"
        },
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}

resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  namespace  = kubernetes_namespace.vault_namespace.metadata[0].name
  version    = "0.28.0"

  set {
    name  = "server.ha.enabled"
    value = "false"
  }

  set {
    name  = "server.ha.raft.enabled"
    value = "false"
  }

  set {
    name  = "injector.enabled"
    value = "true"
  }

  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }

  set {
    name  = "server.dataStorage.enabled"
    value = "true"
  }

  set {
    name  = "server.dataStorage.storageClass"
    value = "ebs-sc"
  }

  set {
    name  = "server.dataStorage.size"
    value = "10Gi"
  }

  set {
    name  = "server.serviceAccount.create"
    value = "false"
  }

  set {
    name  = "server.serviceAccount.name"
    value = "vault-sa"
  }

  set {
    name = "server.standalone.config"
    value = format(<<EOF
      seal "awskms" {
        region     = "us-east-1"
        kms_key_id = "%s"
      }

      storage "raft" {
        path    = "/vault/data"
        node_id = "vault-0"
      }

      listener "tcp" {
        address         = "[::]:8200"
        cluster_address = "[::]:8201"
        tls_disable     = "true"
      }

      api_addr     = "http://vault.vault-ns.svc.cluster.local:8200"
      cluster_addr = "http://vault-0.vault-internal:8201"
      disable_mlock = true
  EOF
      ,
      aws_kms_key.vault_key.id
    )
  }

  # Depend on the namespace creation
  depends_on = [kubernetes_namespace.vault_namespace,
    kubernetes_storage_class.ebs_sc,
    aws_kms_key.vault_key,
    kubernetes_service_account.vault_sa
  ]
}

#service account to allow vault pod to cotact aws for the unseal key
resource "kubernetes_service_account" "vault_sa" {
  metadata {
    name      = "vault-sa"
    namespace = kubernetes_namespace.vault_namespace.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.kms_role.arn
    }
  }
}

resource "kubernetes_storage_class" "ebs_sc" {
  metadata {
    name = "ebs-sc"
  }

  storage_provisioner = "ebs.csi.aws.com"

  parameters = {
    type = "gp3" # or gp2
  }

  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
}



#Create all namespaces
resource "kubernetes_namespace" "db_namespace" {
  metadata {
    name = "db-ns"
  }
}
resource "kubernetes_namespace" "back_namespace" {
  metadata {
    name = "back-ns"
  }
}
resource "kubernetes_namespace" "front_namespace" {
  metadata {
    name = "front-ns"
  }
}

resource "kubernetes_namespace" "vault_namespace" {
  metadata {
    name = "vault-ns"
  }
}


