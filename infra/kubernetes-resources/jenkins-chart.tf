resource "kubernetes_namespace" "jenkins" {
  metadata {
    name = "jenkins"
  }
}

resource "kubernetes_cluster_role" "jenkins_sa_role" {
  metadata {
    name = "jenkins-sa-role"
  }
  rule {
    api_groups = [ "*" ]
    resources = [ "*" ]
    verbs = [ "*" ]

  }
}
resource "kubernetes_service_account" "jenkins" {
  metadata {
    name = "jenkins"
    namespace = kubernetes_namespace.jenkins.name
  }
}
resource "kubernetes_cluster_role_binding" "jenkins_sa_role_binding" {
    metadata {
      name = "jenkins-sa-role-binding"
    }
    role_ref {
        api_group = "rbac.authorization.k8s.io"
        kind      = "ClusterRole"
        name      = kubernetes_cluster_role.jenkins_sa_role.name
    }
    subject {
        kind      = "User"
        name      = kubernetes_service_account.jenkins.name
        api_group = "rbac.authorization.k8s.io"
    }
}
resource "helm_release" "jenkins" {
  name = "jenkins"
  repository = "https://charts.jenkins.io"
  chart = "jenkins"
  namespace = "jenkins"

  set {
    name = "serviceAccount.create"
    value = "false"
  }
  set{
    name = "serviceAccount.name"
    value = kubernetes_service_account.jenkins.name
  }

  depends_on = [ kubernetes_namespace.jenkins, kubernetes_service_account.jenkins]
}