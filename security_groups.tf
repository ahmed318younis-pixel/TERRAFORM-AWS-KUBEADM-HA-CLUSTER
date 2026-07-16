resource "aws_security_group" "alb" {
  name_prefix            = "${var.project_name}-alb-"
  description            = "Public application ALB"
  vpc_id                 = aws_vpc.main.id
  revoke_rules_on_delete = true

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

resource "aws_security_group" "haproxy" {
  name_prefix            = "${var.project_name}-haproxy-"
  description            = "HAProxy control-plane endpoint"
  vpc_id                 = aws_vpc.main.id
  revoke_rules_on_delete = true

  tags = {
    Name = "${var.project_name}-haproxy-sg"
  }
}

resource "aws_security_group" "masters" {
  name_prefix            = "${var.project_name}-masters-"
  description            = "Kubernetes control-plane nodes"
  vpc_id                 = aws_vpc.main.id
  revoke_rules_on_delete = true

  tags = {
    Name = "${var.project_name}-masters-sg"
  }
}

resource "aws_security_group" "workers" {
  name_prefix            = "${var.project_name}-workers-"
  description            = "Kubernetes worker nodes"
  vpc_id                 = aws_vpc.main.id
  revoke_rules_on_delete = true

  tags = {
    Name = "${var.project_name}-workers-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  for_each = toset(var.alb_ingress_cidrs)

  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = each.value
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "Public HTTP"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  for_each = var.acm_certificate_arn == null ? toset([]) : toset(var.alb_ingress_cidrs)

  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = each.value
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "Public HTTPS"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_workers" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.workers.id
  from_port                    = var.alb_node_port
  to_port                      = var.alb_node_port
  ip_protocol                  = "tcp"
  description                  = "ALB to Kubernetes NodePort"
}

resource "aws_vpc_security_group_ingress_rule" "haproxy_from_masters" {
  security_group_id            = aws_security_group.haproxy.id
  referenced_security_group_id = aws_security_group.masters.id
  from_port                    = 6443
  to_port                      = 6443
  ip_protocol                  = "tcp"
  description                  = "Control-plane nodes to API endpoint"
}

resource "aws_vpc_security_group_ingress_rule" "haproxy_from_workers" {
  security_group_id            = aws_security_group.haproxy.id
  referenced_security_group_id = aws_security_group.workers.id
  from_port                    = 6443
  to_port                      = 6443
  ip_protocol                  = "tcp"
  description                  = "Worker nodes to API endpoint"
}

resource "aws_vpc_security_group_ingress_rule" "haproxy_from_admin" {
  for_each = toset(var.admin_api_cidrs)

  security_group_id = aws_security_group.haproxy.id
  cidr_ipv4         = each.value
  from_port         = 6443
  to_port           = 6443
  ip_protocol       = "tcp"
  description       = "Routed administrator network to Kubernetes API"
}

resource "aws_vpc_security_group_egress_rule" "haproxy_all" {
  security_group_id = aws_security_group.haproxy.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Bootstrap, SSM, and control-plane health checks"
}

resource "aws_vpc_security_group_ingress_rule" "masters_api_from_haproxy" {
  security_group_id            = aws_security_group.masters.id
  referenced_security_group_id = aws_security_group.haproxy.id
  from_port                    = 6443
  to_port                      = 6443
  ip_protocol                  = "tcp"
  description                  = "HAProxy to kube-apiserver"
}

resource "aws_vpc_security_group_ingress_rule" "masters_api_from_masters" {
  security_group_id            = aws_security_group.masters.id
  referenced_security_group_id = aws_security_group.masters.id
  from_port                    = 6443
  to_port                      = 6443
  ip_protocol                  = "tcp"
  description                  = "Control-plane nodes to kube-apiserver service endpoints"
}

resource "aws_vpc_security_group_ingress_rule" "masters_api_from_workers" {
  security_group_id            = aws_security_group.masters.id
  referenced_security_group_id = aws_security_group.workers.id
  from_port                    = 6443
  to_port                      = 6443
  ip_protocol                  = "tcp"
  description                  = "Worker nodes to kube-apiserver service endpoints"
}

resource "aws_vpc_security_group_ingress_rule" "masters_etcd" {
  security_group_id            = aws_security_group.masters.id
  referenced_security_group_id = aws_security_group.masters.id
  from_port                    = 2379
  to_port                      = 2380
  ip_protocol                  = "tcp"
  description                  = "Stacked etcd peer and client traffic"
}

resource "aws_vpc_security_group_ingress_rule" "masters_kubelet" {
  security_group_id            = aws_security_group.masters.id
  referenced_security_group_id = aws_security_group.masters.id
  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
  description                  = "Control plane to control-plane kubelet"
}

resource "aws_vpc_security_group_ingress_rule" "masters_vxlan_from_masters" {
  security_group_id            = aws_security_group.masters.id
  referenced_security_group_id = aws_security_group.masters.id
  from_port                    = 4789
  to_port                      = 4789
  ip_protocol                  = "udp"
  description                  = "Calico VXLAN between control-plane nodes"
}

resource "aws_vpc_security_group_ingress_rule" "masters_vxlan_from_workers" {
  security_group_id            = aws_security_group.masters.id
  referenced_security_group_id = aws_security_group.workers.id
  from_port                    = 4789
  to_port                      = 4789
  ip_protocol                  = "udp"
  description                  = "Calico VXLAN from workers"
}

resource "aws_vpc_security_group_ingress_rule" "masters_typha_from_masters" {
  security_group_id            = aws_security_group.masters.id
  referenced_security_group_id = aws_security_group.masters.id
  from_port                    = 5473
  to_port                      = 5473
  ip_protocol                  = "tcp"
  description                  = "Calico nodes to Typha on control-plane nodes"
}

resource "aws_vpc_security_group_ingress_rule" "masters_typha_from_workers" {
  security_group_id            = aws_security_group.masters.id
  referenced_security_group_id = aws_security_group.workers.id
  from_port                    = 5473
  to_port                      = 5473
  ip_protocol                  = "tcp"
  description                  = "Worker Calico nodes to Typha on control-plane nodes"
}

resource "aws_vpc_security_group_egress_rule" "masters_all" {
  security_group_id = aws_security_group.masters.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Kubernetes bootstrap, image pulls, and workload egress"
}

resource "aws_vpc_security_group_ingress_rule" "workers_kubelet_from_masters" {
  security_group_id            = aws_security_group.workers.id
  referenced_security_group_id = aws_security_group.masters.id
  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
  description                  = "Kube-apiserver to worker kubelet"
}

resource "aws_vpc_security_group_ingress_rule" "workers_nodeport_from_alb" {
  security_group_id            = aws_security_group.workers.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.alb_node_port
  to_port                      = var.alb_node_port
  ip_protocol                  = "tcp"
  description                  = "Application ALB to NodePort"
}

resource "aws_vpc_security_group_ingress_rule" "workers_vxlan_from_masters" {
  security_group_id            = aws_security_group.workers.id
  referenced_security_group_id = aws_security_group.masters.id
  from_port                    = 4789
  to_port                      = 4789
  ip_protocol                  = "udp"
  description                  = "Calico VXLAN from control-plane nodes"
}

resource "aws_vpc_security_group_ingress_rule" "workers_vxlan_from_workers" {
  security_group_id            = aws_security_group.workers.id
  referenced_security_group_id = aws_security_group.workers.id
  from_port                    = 4789
  to_port                      = 4789
  ip_protocol                  = "udp"
  description                  = "Calico VXLAN between workers"
}

resource "aws_vpc_security_group_ingress_rule" "workers_typha_from_masters" {
  security_group_id            = aws_security_group.workers.id
  referenced_security_group_id = aws_security_group.masters.id
  from_port                    = 5473
  to_port                      = 5473
  ip_protocol                  = "tcp"
  description                  = "Control-plane Calico nodes to Typha on workers"
}

resource "aws_vpc_security_group_ingress_rule" "workers_typha_from_workers" {
  security_group_id            = aws_security_group.workers.id
  referenced_security_group_id = aws_security_group.workers.id
  from_port                    = 5473
  to_port                      = 5473
  ip_protocol                  = "tcp"
  description                  = "Worker Calico nodes to Typha on workers"
}

resource "aws_vpc_security_group_egress_rule" "workers_all" {
  security_group_id = aws_security_group.workers.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Kubernetes bootstrap, image pulls, and workload egress"
}
