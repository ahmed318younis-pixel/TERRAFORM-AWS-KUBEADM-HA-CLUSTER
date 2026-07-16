resource "aws_route53_zone" "private" {
  name = local.private_zone_fqdn

  vpc {
    vpc_id = aws_vpc.main.id
  }

  tags = {
    Name = "${var.project_name}-private-zone"
  }
}

resource "aws_route53_record" "api" {
  zone_id = aws_route53_zone.private.zone_id
  name    = local.api_fqdn
  type    = "A"
  ttl     = 60
  records = [local.haproxy.private_ip]
}
