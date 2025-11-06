resource "kubernetes_namespace" "jenkins" {
  metadata {
    name = "jenkins"
  }
}

resource "kubernetes_service_account" "jenkins" {
  metadata {
    name      = "jenkins"
    namespace = kubernetes_namespace.jenkins.metadata[0].name
  }
}

resource "kubernetes_cluster_role" "jenkins_sa_role" {
  metadata {
    name = "jenkins-sa-role"
  }
  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["*"]
  }
}

resource "kubernetes_cluster_role_binding" "jenkins_sa_role_binding" {
  metadata {
    name = "jenkins-sa-role-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.jenkins_sa_role.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.jenkins.metadata[0].name
    namespace = kubernetes_namespace.jenkins.metadata[0].name
    # Remove api_group for ServiceAccount - it should be empty
  }
}


# Create a privileged service account for the fix-permissions job
resource "kubernetes_service_account" "jenkins_pvc_fixer" {
    metadata {
      name      = "jenkins-pvc-fixer"
      namespace = kubernetes_namespace.jenkins.metadata[0].name
    }
 }

# Create a role that allows privileged containers (if needed)
resource "kubernetes_role" "jenkins_pvc_fixer" {
    metadata {
      name      = "jenkins-pvc-fixer"
      namespace = kubernetes_namespace.jenkins.metadata[0].name
    }

    rule {
      api_groups = [""]
      resources  = ["pods"]
      verbs      = ["get", "list"]
    }
}

resource "kubernetes_role_binding" "jenkins_pvc_fixer" {
    metadata {
      name      = "jenkins-pvc-fixer"
      namespace = kubernetes_namespace.jenkins.metadata[0].name
    }

    role_ref {
      api_group = "rbac.authorization.k8s.io"
      kind      = "Role"
      name      = kubernetes_role.jenkins_pvc_fixer.metadata[0].name
    }

    subject {
      kind      = "ServiceAccount"
      name      = kubernetes_service_account.jenkins_pvc_fixer.metadata[0].name
      namespace = kubernetes_namespace.jenkins.metadata[0].name
    }
}

# Job to fix PVC permissions
resource "kubernetes_job" "fix_jenkins_pvc_permissions" {
    metadata {
      name      = "fix-jenkins-pvc-permissions"
      namespace = kubernetes_namespace.jenkins.metadata[0].name
    }

    spec {
      template {
        metadata {
          labels = {
            app = "fix-jenkins-pvc"
          }
        }

        spec {
          service_account_name = kubernetes_service_account.jenkins_pvc_fixer.metadata[0].name
          restart_policy       = "Never"

          container {
            name    = "fix-permissions"
            image   = "busybox:latest"
            command = ["sh", "-c", "chmod -R 777 /var/jenkins_home && chown 1000:1000 /var/jenkins_home && echo 'Permissions fixed'"]

            volume_mount {
              name       = "jenkins-home"
              mount_path = "/var/jenkins_home"
            }

            security_context {
              run_as_user = 0
            }
          }

          volume {
            name = "jenkins-home"
            persistent_volume_claim {
              claim_name = "jenkins-pvc"
            }
          }
        }
      }

      backoff_limit = 4
    }

    wait_for_completion = true

    timeouts {
      create = "2m"
      update = "2m"
    }

    depends_on = [kubernetes_namespace.jenkins]
}



resource "helm_release" "jenkins" {
  name       = "jenkins"
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  namespace  = kubernetes_namespace.jenkins.metadata[0].name

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.jenkins.metadata[0].name
  }

  set {
    name  = "controller.serviceType"
    value = "ClusterIP"
  }

  set {
    name  = "controller.jenkinsUrl"
    value = "http://jenkins.jenkins.svc.cluster.local:8080"
  }

  set {
    name  = "persistence.existingClaim"
    value = "jenkins-pvc"
}

  set {
    name  = "controller.runAsUser"
    value = "1000"
  }

  set {
    name  = "controller.fsGroup"
    value = "1000"
  }

  depends_on = [
    kubernetes_namespace.jenkins,
    kubernetes_service_account.jenkins,
    kubernetes_cluster_role_binding.jenkins_sa_role_binding,
    kubernetes_job.fix_jenkins_pvc_permissions  # Wait for permissions to be fixed
  ]
}
