locals {
  azs = length(var.availability_zones) == 3 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 3)

  private_zone_fqdn = "${var.project_name}.${trimsuffix(var.private_zone_name, ".")}"
  api_fqdn          = "api.${local.private_zone_fqdn}"

  bootstrap_parameter_prefix = "/${var.project_name}/bootstrap"

  master_primary = {
    name       = "master-1"
    subnet_key = "0"
    private_ip = cidrhost(var.private_subnet_cidrs[0], 10)
    az         = local.azs[0]
  }

  master_secondary = {
    "master-2" = {
      subnet_key = "1"
      private_ip = cidrhost(var.private_subnet_cidrs[1], 10)
      az         = local.azs[1]
    }
    "master-3" = {
      subnet_key = "2"
      private_ip = cidrhost(var.private_subnet_cidrs[2], 10)
      az         = local.azs[2]
    }
  }

  workers = {
    "worker-1" = {
      subnet_key = "0"
      private_ip = cidrhost(var.private_subnet_cidrs[0], 20)
      az         = local.azs[0]
    }
    "worker-2" = {
      subnet_key = "1"
      private_ip = cidrhost(var.private_subnet_cidrs[1], 20)
      az         = local.azs[1]
    }
  }

  master_2_ip = local.master_secondary["master-2"].private_ip
  master_3_ip = local.master_secondary["master-3"].private_ip

  haproxy = {
    name       = "haproxy"
    subnet_key = "2"
    private_ip = cidrhost(var.private_subnet_cidrs[2], 20)
    az         = local.azs[2]
  }

  ssm_parameter_arn = "arn:${data.aws_partition.current.partition}:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${trimprefix(local.bootstrap_parameter_prefix, "/")}/*"

  alb_name = substr("${var.project_name}-app-alb", 0, 32)
  tg_name  = substr("${var.project_name}-workers", 0, 32)
}
