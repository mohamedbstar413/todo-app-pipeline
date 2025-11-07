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

  set{
    name = "server.service.type"
    value = "LoadBalancer"
  }
  depends_on = [
    var.todo_cluster,              # Ensure cluster is active
    var.todo_front_nginx_config_s3 # Ensure S3 bucket exists for user_data
  ]
}

resource "null_resource" "argocd_login" {
  depends_on = [helm_release.argocd]

  provisioner "local-exec" {
    command = <<-EOT
      set -e

      kubectl -n argocd wait --for=condition=available deployment/argocd-server --timeout=180s

      ARGOCD_HOST=$(kubectl -n argocd get svc argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
      if [ -z "$ARGOCD_HOST" ]; then
        ARGOCD_HOST=$(kubectl -n argocd get svc argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
      fi

      echo "ArgoCD Host: https://$ARGOCD_HOST"

      #get admin password
      ADMIN_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
        -o jsonpath='{.data.password}' | base64 --decode)

      #login
      argocd login $ARGOCD_HOST --username admin --password "$ADMIN_PASS" --insecure --grpc-web

      #generate ArgoCD token
      argocd account generate-token --account admin > argocd-token.txt
      echo "Token saved to argocd-token.txt"
    EOT
  }
}

resource "null_resource" "argocd_db_app" {
  depends_on = [null_resource.argocd_login]

  provisioner "local-exec" {
    command = <<EOT
      set -e
      ARGOCD_HOST=$(kubectl -n argocd get svc argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
      TOKEN=$(cat argocd-token.txt)

      argocd app create todo-app-db \
        --repo https://github.com/mohamedbstar413/todo-app-pipeline.git \
        --path kubernetes-resources/db \
        --dest-server https://kubernetes.default.svc \
        --dest-namespace db-ns \
        --sync-policy automated \
        --self-heal \
        --grpc-web \
        --auth-token $TOKEN \
        --insecure \

      echo "ArgoCD Application 'todo-app-db' created."
    EOT
  }
}

resource "null_resource" "argocd_back_app" {
  depends_on = [null_resource.argocd_db_app]

  provisioner "local-exec" {
    command = <<EOT
      set -e
      ARGOCD_HOST=$(kubectl -n argocd get svc argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
      TOKEN=$(cat argocd-token.txt)

      argocd app create todo-app-backend \
        --repo https://github.com/mohamedbstar413/todo-app-pipeline.git \
        --path kubernetes-resources/backend \
        --dest-server https://kubernetes.default.svc \
        --dest-namespace back-ns \
        --sync-policy automated \
        --self-heal \
        --grpc-web \
        --auth-token $TOKEN \
        --insecure \

      echo "ArgoCD Application 'todo-app-back' created."
    EOT
  }
}

resource "null_resource" "argocd_front_app" {
  depends_on = [null_resource.argocd_back_app]

  provisioner "local-exec" {
    command = <<EOT
      set -e
      ARGOCD_HOST=$(kubectl -n argocd get svc argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
      TOKEN=$(cat argocd-token.txt)

      argocd app create todo-app-front \
        --repo https://github.com/mohamedbstar413/todo-app-pipeline.git \
        --path kubernetes-resources/frontend \
        --dest-server https://kubernetes.default.svc \
        --dest-namespace front-ns \
        --sync-policy automated \
        --self-heal \
        --grpc-web \
        --auth-token $TOKEN \
        --insecure \

      echo "ArgoCD Application 'todo-app-front' created."
    EOT
  }
}

resource "null_resource" "argocd_jenkins_app" {
  depends_on = [null_resource.argocd_login]

  provisioner "local-exec" {
    command = <<EOT
      set -e
      ARGOCD_HOST=$(kubectl -n argocd get svc argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
      TOKEN=$(cat argocd-token.txt)

      argocd app create todo-app-jenkins \
        --repo https://github.com/mohamedbstar413/todo-app-pipeline.git \
        --path kubernetes-resources/jenkins-manifests \
        --dest-server https://kubernetes.default.svc \
        --dest-namespace jenkins \
        --sync-policy automated \
        --self-heal \
        --grpc-web \
        --auth-token $TOKEN \
        --insecure \

      echo "ArgoCD Application 'todo-app-jenkins' created."
    EOT
  }
}

#external dns (for automatic dns management)
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
  description             = "symmetric encryption KMS key"
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

/*resource "helm_release" "vault" {
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
}*/

/*resource "null_resource" "vault_operator_initializer" {
  depends_on = [ helm_release.vault ]
  provisioner "local-exec" {
    command = <<EOF
      #connect to the cluster
      aws eks update-kubeconfig --name todo-app-cluster --region us-east-1
      
      #wait for the vault-0 pod to be ready
      kubectl wait --for=condition=Ready pod/vault-0 -n vault-ns --timeout=180s

      until kubectl exec vault-0 -- vault status >/dev/null 2>&1; do
        echo "Waiting for Vault..."
        sleep 5
      done
      echo "Vault API ready"
      #apk update
      #apk add --no-cache curl
      
      #echo "⏳ Waiting for Vault API to respond..."
      #for i in $(seq 1 30); do
      #  if kubectl exec -n vault-ns vault-0 -- curl -s http://127.0.0.1:8200/v1/sys/health | grep -q 'sealed'; then
      #   echo "Vault API is ready."
      #    break
      #  fi
      #  echo "Waiting for Vault API... ($i/30)"
      #  sleep 5
      #done

      if kubectl exec -n vault-ns vault-0 -- vault status | grep 'Initialized.*true'; then
        echo "✅ Vault already initialized. Skipping init."
      else
        echo "🚀 Initializing Vault..."
        kubectl exec -n vault-ns vault-0 -- vault operator init -key-shares=1 -key-threshold=1 -format=json > vault-init.json
        echo "💾 Vault initialized. Keys written to vault-init.json"
      fi

    EOF
  }
  triggers = {
    vault_release = helm_release.vault.metadata[0].name
  }
}
*/
/*resource "null_resource" "vault_operator_initializer" {
  depends_on = [helm_release.vault]

  # Re-run only when the Helm release changes (or you bump the version below)
  triggers = {
    helm_chart   = helm_release.vault.metadata[0].name
    helm_version = helm_release.vault.metadata[0].version
    run_id       = "v4"   # <-- bump this to force a new run
  }

  provisioner "local-exec" {
    command = <<-EOT
      # -------------------------------------------------
      # 1. Connect to the cluster
      # -------------------------------------------------
      aws eks update-kubeconfig --name todo-app-cluster --region us-east-1

      # -------------------------------------------------
      # 2. Wait for the pod to be Running + Ready
      # -------------------------------------------------
      echo "Waiting for vault-0 pod to be Ready (max 3 min)..."
      if ! kubectl wait --for=condition=Ready pod/vault-0 -n vault-ns --timeout=180s; then
        echo "Pod never became Ready – check logs:"
        kubectl logs vault-0 -n vault-ns --tail=50
        exit 1
      fi

      # -------------------------------------------------
      # 3. Wait for Vault API to be reachable (max 60 s)
      # -------------------------------------------------
      echo "Probing Vault API (vault status)..."
      for i in $(seq 1 12); do
        if kubectl exec vault-0 -n vault-ns -- vault status >/dev/null 2>&1; then
          break
        fi
        echo "Attempt $i/12 – Vault not responding yet"
        sleep 5
      done

      # If still not reachable → abort with logs
      if ! kubectl exec vault-0 -n vault-ns -- vault status >/dev/null 2>&1; then
        echo "Vault API never came up. Dumping logs..."
        kubectl logs vault-0 -n vault-ns --tail=100
        exit 1
      fi

      # -------------------------------------------------
      # 4. Parse vault status (sealed / initialized)
      # -------------------------------------------------
      STATUS=$(kubectl exec vault-0 -n vault-ns -- vault status -format=json)
      SEALED=$(echo "$STATUS" | jq -r .sealed)
      INITED=$(echo "$STATUS" | jq -r .initialized)

      echo "Vault status – Sealed: $SEALED  Initialized: $INITED"

      if [ "$INITED" = "true" ]; then
        echo "Vault already initialized – nothing to do."
        exit 0
      fi

      # -------------------------------------------------
      # 5. Initialize (only if not initialized)
      # -------------------------------------------------
      echo "Initializing Vault (single-share, threshold 1)..."
      kubectl exec vault-0 -n vault-ns -- vault operator init \
        -key-shares=1 -key-threshold=1 -format=json > vault-init.json

      echo "Vault initialized – root token & unseal key saved to vault-init.json"
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
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
}*/





resource "kubernetes_storage_class" "ebs_sc" {
  metadata {
    name = "ebs-sc"
  }

  storage_provisioner = "ebs.csi.aws.com"

  parameters = {
    type = "gp3"
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
    labels = {
      app = "backend"
    }

  }
}
resource "kubernetes_namespace" "front_namespace" {
  metadata {
    name = "front-ns"
    labels = {
      app = "frontend"
    }

  }
}

/*resource "kubernetes_namespace" "vault_namespace" {
  metadata {
    name = "vault-ns"
  }
}*/


