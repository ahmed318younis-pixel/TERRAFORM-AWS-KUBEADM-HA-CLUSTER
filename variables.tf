variable "aws_region" {
  description = "AWS Region in which the cluster is deployed."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Lowercase project name used in resource names and the private DNS zone."
  type        = string
  default     = "kubeadm-ha"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,20}[a-z0-9]$", var.project_name))
    error_message = "project_name must be 3-22 characters, lowercase, and contain only letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment tag."
  type        = string
  default     = "lab"
}

variable "availability_zones" {
  description = "Optional list of exactly three Availability Zones. Leave empty to use the first three available AZs."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.availability_zones) == 0 || length(var.availability_zones) == 3
    error_message = "availability_zones must be empty or contain exactly three Availability Zones."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Three public subnet CIDRs, one per Availability Zone."
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) == 3
    error_message = "public_subnet_cidrs must contain exactly three CIDRs."
  }
}

variable "private_subnet_cidrs" {
  description = "Three private subnet CIDRs, one per Availability Zone."
  type        = list(string)
  default     = ["10.0.16.0/20", "10.0.32.0/20", "10.0.48.0/20"]

  validation {
    condition     = length(var.private_subnet_cidrs) == 3
    error_message = "private_subnet_cidrs must contain exactly three CIDRs."
  }
}

variable "private_zone_name" {
  description = "Suffix used for the Route 53 private hosted zone."
  type        = string
  default     = "k8s.internal"
}

variable "master_instance_type" {
  description = "EC2 instance type for each control-plane node."
  type        = string
  default     = "t3.large"
}

variable "worker_instance_type" {
  description = "EC2 instance type for each worker node."
  type        = string
  default     = "t3.large"
}

variable "haproxy_instance_type" {
  description = "EC2 instance type for the HAProxy API load balancer."
  type        = string
  default     = "t3.small"
}

variable "master_root_volume_size" {
  description = "Root EBS volume size in GiB for control-plane nodes."
  type        = number
  default     = 60
}

variable "worker_root_volume_size" {
  description = "Root EBS volume size in GiB for worker nodes."
  type        = number
  default     = 80
}

variable "haproxy_root_volume_size" {
  description = "Root EBS volume size in GiB for HAProxy."
  type        = number
  default     = 20
}

variable "kubernetes_minor" {
  description = "Kubernetes minor repository used by pkgs.k8s.io. The newest patch in this minor is installed unless kubernetes_package_version is set."
  type        = string
  default     = "v1.36"

  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+$", var.kubernetes_minor))
    error_message = "kubernetes_minor must look like v1.36."
  }
}

variable "kubernetes_package_version" {
  description = "Optional exact Debian package version for kubeadm, kubelet, and kubectl, for example 1.36.2-1.1. Empty means newest patch in kubernetes_minor."
  type        = string
  default     = ""
}

variable "calico_version" {
  description = "Pinned Calico release tag."
  type        = string
  default     = "v3.32.0"
}

variable "pod_cidr" {
  description = "Pod CIDR used by kubeadm and Calico. Must not overlap the VPC or service CIDR."
  type        = string
  default     = "192.168.0.0/16"
}

variable "service_cidr" {
  description = "Kubernetes service CIDR."
  type        = string
  default     = "10.96.0.0/12"
}

variable "alb_node_port" {
  description = "NodePort on the worker nodes targeted by the Application Load Balancer."
  type        = number
  default     = 30080

  validation {
    condition     = var.alb_node_port >= 30000 && var.alb_node_port <= 32767
    error_message = "alb_node_port must be inside the Kubernetes NodePort range 30000-32767."
  }
}

variable "alb_ingress_cidrs" {
  description = "CIDRs allowed to access the public application ALB."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "admin_api_cidrs" {
  description = "Optional CIDRs allowed to reach HAProxy port 6443. This only works when those networks can route to the private VPC."
  type        = list(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = "Optional ACM certificate ARN. When set, HTTP redirects to HTTPS and the ALB serves HTTPS."
  type        = string
  default     = null
  nullable    = true
}

variable "deploy_demo_app" {
  description = "Deploy a two-replica NGINX demo service on alb_node_port so the ALB can be tested immediately."
  type        = bool
  default     = true
}

variable "enable_alb_deletion_protection" {
  description = "Enable deletion protection on the application ALB."
  type        = bool
  default     = false
}

variable "enable_haproxy_auto_recovery" {
  description = "Create an EC2 system-status auto-recovery alarm for the single HAProxy instance."
  type        = bool
  default     = true
}

variable "additional_tags" {
  description = "Additional tags applied to all resources through provider default tags."
  type        = map(string)
  default     = {}
}
