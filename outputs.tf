output "application_url" {
  description = "Public URL of the application ALB."
  value       = var.acm_certificate_arn == null ? "http://${aws_lb.application.dns_name}" : "https://${aws_lb.application.dns_name}"
}

output "alb_dns_name" {
  description = "DNS name of the application ALB."
  value       = aws_lb.application.dns_name
}

output "kubernetes_api_endpoint" {
  description = "Private Kubernetes API endpoint used by kubeadm."
  value       = "https://${local.api_fqdn}:6443"
}

output "master_1_instance_id" {
  description = "Instance ID of the first control-plane node."
  value       = aws_instance.master_primary.id
}

output "haproxy_instance_id" {
  description = "Instance ID of the HAProxy node."
  value       = aws_instance.haproxy.id
}

output "node_instance_ids" {
  description = "All Kubernetes and HAProxy instance IDs."
  value = merge(
    {
      haproxy    = aws_instance.haproxy.id
      "master-1" = aws_instance.master_primary.id
    },
    { for name, instance in aws_instance.master_secondary : name => instance.id },
    { for name, instance in aws_instance.worker : name => instance.id }
  )
}

output "node_private_ips" {
  description = "Static private IP addresses used by the cluster."
  value = merge(
    {
      haproxy    = local.haproxy.private_ip
      "master-1" = local.master_primary.private_ip
    },
    { for name, node in local.master_secondary : name => node.private_ip },
    { for name, node in local.workers : name => node.private_ip }
  )
}

output "ssm_connect_master_1" {
  description = "AWS CLI command for opening an SSM shell on master-1."
  value       = "aws ssm start-session --region ${var.aws_region} --target ${aws_instance.master_primary.id}"
}


output "bootstrap_parameter_prefix" {
  description = "Instance-specific SSM path containing the current time-limited join commands."
  value       = "${local.bootstrap_parameter_prefix}/${aws_instance.master_primary.id}"
}

output "bootstrap_log_command" {
  description = "Run this after opening an SSM session on a node."
  value       = "sudo tail -f /var/log/kubeadm-bootstrap.log"
}

output "nat_gateway_public_ips" {
  description = "Elastic IPs used by the three NAT gateways."
  value       = { for key, eip in aws_eip.nat : key => eip.public_ip }
}
