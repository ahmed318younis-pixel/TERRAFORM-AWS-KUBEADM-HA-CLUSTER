# Highly Available Kubernetes Cluster on AWS using kubeadm & Terraform

> Production-inspired Kubernetes infrastructure deployed on AWS using **Terraform**, **kubeadm**, **containerd**, and **Calico**, featuring a multi-AZ control plane, private networking, HAProxy API endpoint, and an Application Load Balancer for application traffic.

![Architecture](docs/ChatGPT%20Image%20Jul%2016,%202026,%2004_11_26%20PM.png)

---

# Overview

This project provisions a highly available Kubernetes cluster on AWS using Infrastructure as Code (Terraform).

The infrastructure follows AWS and Kubernetes best practices by distributing the control plane across multiple Availability Zones, isolating workloads inside private subnets, using AWS Systems Manager Session Manager instead of SSH, and exposing applications through an internet-facing Application Load Balancer.

The entire cluster bootstrap process is fully automated using cloud-init and kubeadm.

---

# Features

## Kubernetes

- Highly Available kubeadm control plane
- Three stacked-etcd control plane nodes
- Two worker nodes
- containerd runtime
- Calico CNI (VXLAN)
- Automated cluster bootstrap
- Automated node joining
- Runtime-generated kubeadm join commands
- Automatic Kubernetes package version locking

## AWS Infrastructure

- Multi-AZ VPC
- Three public subnets
- Three private subnets
- Three NAT Gateways
- Internet Gateway
- Route Tables
- Security Groups
- IAM Roles & Instance Profiles
- Route53 Private Hosted Zone
- AWS Systems Manager Session Manager
- CloudWatch support

## High Availability

- Control plane distributed across three Availability Zones
- Multi-AZ networking
- HAProxy private Kubernetes API endpoint
- Internet-facing Application Load Balancer
- Rolling Updates
- Health checks
- Automatic EC2 recovery

## Security

- No inbound SSH
- No public IP addresses on EC2
- Session Manager administration
- IMDSv2 enforced
- Encrypted EBS volumes
- Security groups separated by role
- Principle of Least Privilege IAM
- Runtime-generated join commands stored temporarily in SSM Parameter Store

---

# Architecture

The infrastructure consists of **six EC2 instances**:

| Component | Count |
|-----------|------:|
| Control Plane | 3 |
| Worker Nodes | 2 |
| HAProxy | 1 |

Networking:

- 3 Public Subnets
- 3 Private Subnets
- 3 NAT Gateways
- Internet Gateway
- Public Application Load Balancer

### Application Traffic

```text
Internet
    │
    ▼
Application Load Balancer
    │
    ▼
Worker Nodes
    │
    ▼
Kubernetes Services
    │
    ▼
Pods
```

### Kubernetes API Traffic

```text
kubectl
    │
    ▼
HAProxy
    │
    ▼
Control Plane Nodes
```

---

# Technology Stack

| Category | Technology |
|----------|------------|
| Infrastructure | Terraform |
| Cloud | AWS |
| Container Orchestration | Kubernetes (kubeadm) |
| Container Runtime | containerd |
| Networking | Calico |
| API Load Balancer | HAProxy |
| Application Load Balancer | AWS ALB |
| Administration | AWS Systems Manager |
| Operating System | Ubuntu Linux |

---

# Repository Structure

```text
.
├── compute.tf
├── networking.tf
├── security_groups.tf
├── load_balancer.tf
├── iam.tf
├── monitoring.tf
├── dns.tf
├── providers.tf
├── versions.tf
├── variables.tf
├── outputs.tf
├── locals.tf
├── data.tf
├── scripts/
├── examples/
└── docs/
```

---

# Deployment Workflow

Terraform provisions:

- VPC
- Networking
- Security Groups
- IAM
- EC2 Instances
- Route53
- ALB
- NAT Gateways

Cloud-init automatically:

- Installs containerd
- Installs Kubernetes packages
- Initializes the primary control plane
- Generates kubeadm join tokens
- Stores join commands in AWS SSM Parameter Store
- Joins additional control plane nodes
- Joins worker nodes
- Installs Calico

---

# Prerequisites

- Terraform 1.10+
- AWS CLI
- AWS Account
- Session Manager Plugin

---

# Deploy

```bash
cp terraform.tfvars.example terraform.tfvars

terraform init
terraform fmt -recursive
terraform validate
terraform plan -out cluster.tfplan
terraform apply cluster.tfplan
```

---

# Verify the Cluster

Connect to the first control-plane node:

```bash
$(terraform output -raw ssm_connect_master_1)
```

Verify the cluster:

```bash
sudo cloud-init status --wait
sudo cluster-status

sudo kubectl --kubeconfig /etc/kubernetes/admin.conf get nodes -o wide
sudo kubectl --kubeconfig /etc/kubernetes/admin.conf get pods -A
```

---

# Deploy the Demo Application if you want to test 

Enable:

```hcl
deploy_demo_app = true
```

Retrieve the application URL:

```bash
terraform output -raw application_url
```

---

# Deploy the vprofile Application


# Final results 

![Architecture](docs/Screenshot%202026-07-13%20001219.png)
![Architecture](docs/Screenshot%202026-07-13%20194249.png)

# Security Highlights

- No inbound SSH access
- Session Manager only
- Private EC2 instances
- Encrypted EBS volumes
- IMDSv2 required
- Principle of Least Privilege IAM
- Dedicated security groups
- Runtime-generated SecureString join commands
- ACM support for HTTPS

---

# High Availability Considerations

Implemented:

- Multi-AZ control plane
- Multi-AZ networking
- Rolling Updates
- Multiple NAT Gateways
- Application Load Balancer

Current limitation:

A single HAProxy instance provides the Kubernetes API endpoint, creating a single point of failure during an Availability Zone outage.

Recommended production improvements:

- Dual HAProxy instances behind an internal Network Load Balancer
- Three or more worker nodes
- AWS EBS CSI Driver
- Prometheus & Grafana
- Centralized logging
- Velero backups
- External Secrets
- Private container registry
- Remote Terraform backend

---

# Troubleshooting

## Worker failed to join

```bash
sudo journalctl -u kubelet
sudo tail -300 /var/log/kubeadm-bootstrap.log
```

## HAProxy

```bash
sudo systemctl status haproxy
sudo haproxy -c -f /etc/haproxy/haproxy.cfg
```

## Cluster

```bash
sudo cluster-status
```

---

# Destroy

```bash
terraform destroy
```

---

# References

- Kubernetes Documentation
- kubeadm High Availability Guide
- Calico Documentation
- Terraform AWS Provide
