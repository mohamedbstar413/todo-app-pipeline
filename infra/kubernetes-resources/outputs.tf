output "nginx_ingress_loadbalancer" {
  description = "Load balancer hostname for NGINX Ingress"
  value       = helm_release.nginx_ingress.status
}
output "ingress_nginx_dns_name" {
  value       = data.kubernetes_service.nginx_ingress.status[0].load_balancer[0].ingress[0].hostname
  description = "The DNS name of the ingress-nginx controller's AWS Network Load Balancer"
}
