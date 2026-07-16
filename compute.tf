resource "aws_instance" "haproxy" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.haproxy_instance_type
  subnet_id                   = aws_subnet.private[local.haproxy.subnet_key].id
  private_ip                  = local.haproxy.private_ip
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.haproxy.id]
  iam_instance_profile        = aws_iam_instance_profile.base.name
  monitoring                  = true
  volume_tags = {
    Name = "${var.project_name}-${local.haproxy.name}-root"
  }

  user_data_base64 = base64encode(join("\n", [
    "#!/usr/bin/env bash",
    "export NODE_NAME='${local.haproxy.name}'",
    "export MASTER_1_IP='${local.master_primary.private_ip}'",
    "export MASTER_2_IP='${local.master_2_ip}'",
    "export MASTER_3_IP='${local.master_3_ip}'",
    file("${path.module}/scripts/haproxy.sh")
  ]))

  user_data_replace_on_change = true

  root_block_device {
    delete_on_termination = true
    encrypted             = true
    volume_type           = "gp3"
    volume_size           = var.haproxy_root_volume_size
    iops                  = 3000
    throughput            = 125
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  depends_on = [aws_route_table_association.private]

  tags = {
    Name = "${var.project_name}-${local.haproxy.name}"
    Role = "haproxy"
    AZ   = local.haproxy.az
  }
}

resource "aws_instance" "master_primary" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.master_instance_type
  subnet_id                   = aws_subnet.private[local.master_primary.subnet_key].id
  private_ip                  = local.master_primary.private_ip
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.masters.id]
  iam_instance_profile        = aws_iam_instance_profile.bootstrap_writer.name
  monitoring                  = true
  volume_tags = {
    Name = "${var.project_name}-${local.master_primary.name}-root"
  }

  user_data_base64 = base64encode(join("\n", [
    "#!/usr/bin/env bash",
    "export NODE_NAME='${local.master_primary.name}'",
    "export AWS_REGION='${var.aws_region}'",
    "export KUBERNETES_MINOR='${var.kubernetes_minor}'",
    "export KUBERNETES_PACKAGE_VERSION='${var.kubernetes_package_version}'",
    "export CONTROL_PLANE_ENDPOINT='${local.api_fqdn}:6443'",
    "export HAPROXY_IP='${local.haproxy.private_ip}'",
    "export POD_CIDR='${var.pod_cidr}'",
    "export SERVICE_CIDR='${var.service_cidr}'",
    "export CALICO_VERSION='${var.calico_version}'",
    "export BOOTSTRAP_PARAMETER_PREFIX='${local.bootstrap_parameter_prefix}'",
    "export DEPLOY_DEMO_APP='${var.deploy_demo_app}'",
    "export ALB_NODE_PORT='${var.alb_node_port}'",
    file("${path.module}/scripts/common.sh"),
    file("${path.module}/scripts/master-primary.sh")
  ]))

  user_data_replace_on_change = true

  root_block_device {
    delete_on_termination = true
    encrypted             = true
    volume_type           = "gp3"
    volume_size           = var.master_root_volume_size
    iops                  = 3000
    throughput            = 125
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  depends_on = [
    aws_instance.haproxy,
    aws_route53_record.api,
    aws_route_table_association.private
  ]

  tags = {
    Name = "${var.project_name}-${local.master_primary.name}"
    Role = "control-plane"
    AZ   = local.master_primary.az
  }
}

resource "aws_instance" "master_secondary" {
  for_each = local.master_secondary

  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.master_instance_type
  subnet_id                   = aws_subnet.private[each.value.subnet_key].id
  private_ip                  = each.value.private_ip
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.masters.id]
  iam_instance_profile        = aws_iam_instance_profile.bootstrap_reader.name
  monitoring                  = true
  volume_tags = {
    Name = "${var.project_name}-${each.key}-root"
  }

  user_data_base64 = base64encode(join("\n", [
    "#!/usr/bin/env bash",
    "export NODE_NAME='${each.key}'",
    "export AWS_REGION='${var.aws_region}'",
    "export KUBERNETES_MINOR='${var.kubernetes_minor}'",
    "export KUBERNETES_PACKAGE_VERSION='${var.kubernetes_package_version}'",
    "export CONTROL_JOIN_PARAMETER='${local.bootstrap_parameter_prefix}/${aws_instance.master_primary.id}/control-plane-join'",
    file("${path.module}/scripts/common.sh"),
    file("${path.module}/scripts/master-secondary.sh")
  ]))

  user_data_replace_on_change = true

  root_block_device {
    delete_on_termination = true
    encrypted             = true
    volume_type           = "gp3"
    volume_size           = var.master_root_volume_size
    iops                  = 3000
    throughput            = 125
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  depends_on = [
    aws_instance.master_primary,
    aws_route_table_association.private
  ]

  tags = {
    Name = "${var.project_name}-${each.key}"
    Role = "control-plane"
    AZ   = each.value.az
  }
}

resource "aws_instance" "worker" {
  for_each = local.workers

  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.worker_instance_type
  subnet_id                   = aws_subnet.private[each.value.subnet_key].id
  private_ip                  = each.value.private_ip
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.workers.id]
  iam_instance_profile        = aws_iam_instance_profile.bootstrap_reader.name
  monitoring                  = true
  volume_tags = {
    Name = "${var.project_name}-${each.key}-root"
  }

  user_data_base64 = base64encode(join("\n", [
    "#!/usr/bin/env bash",
    "export NODE_NAME='${each.key}'",
    "export AWS_REGION='${var.aws_region}'",
    "export KUBERNETES_MINOR='${var.kubernetes_minor}'",
    "export KUBERNETES_PACKAGE_VERSION='${var.kubernetes_package_version}'",
    "export WORKER_JOIN_PARAMETER='${local.bootstrap_parameter_prefix}/${aws_instance.master_primary.id}/worker-join'",
    file("${path.module}/scripts/common.sh"),
    file("${path.module}/scripts/worker.sh")
  ]))

  user_data_replace_on_change = true

  root_block_device {
    delete_on_termination = true
    encrypted             = true
    volume_type           = "gp3"
    volume_size           = var.worker_root_volume_size
    iops                  = 3000
    throughput            = 125
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  depends_on = [
    aws_instance.master_primary,
    aws_route_table_association.private
  ]

  tags = {
    Name = "${var.project_name}-${each.key}"
    Role = "worker"
    AZ   = each.value.az
  }
}
