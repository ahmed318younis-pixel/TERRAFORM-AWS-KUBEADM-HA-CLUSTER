set -Eeuo pipefail

exec > >(tee -a /var/log/haproxy-bootstrap.log | logger -t haproxy-bootstrap -s 2>/dev/console) 2>&1
trap 'echo "ERROR: HAProxy bootstrap failed at line ${LINENO}"' ERR

export DEBIAN_FRONTEND=noninteractive
hostnamectl set-hostname "${NODE_NAME}"

apt-get update
apt-get install -y ca-certificates curl haproxy iproute2

if systemctl list-unit-files | grep -q '^amazon-ssm-agent'; then
  systemctl enable --now amazon-ssm-agent
elif command -v snap >/dev/null 2>&1; then
  snap install amazon-ssm-agent --classic || true
  systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent.service || true
fi

cat >/etc/haproxy/haproxy.cfg <<EOF_CONFIG
global
  log /dev/log local0
  log /dev/log local1 notice
  chroot /var/lib/haproxy
  stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
  stats timeout 30s
  user haproxy
  group haproxy
  daemon

defaults
  log global
  mode tcp
  option tcplog
  option dontlognull
  timeout connect 10s
  timeout client  60s
  timeout server  60s

frontend kubernetes-api
  bind 0.0.0.0:6443
  default_backend kubernetes-control-plane

backend kubernetes-control-plane
  balance leastconn
  option tcp-check
  tcp-check connect port 6443
  server master-1 ${MASTER_1_IP}:6443 check inter 2s fall 3 rise 2
  server master-2 ${MASTER_2_IP}:6443 check inter 2s fall 3 rise 2
  server master-3 ${MASTER_3_IP}:6443 check inter 2s fall 3 rise 2

listen local-stats
  bind 127.0.0.1:8404
  mode http
  stats enable
  stats uri /stats
  stats refresh 10s
EOF_CONFIG

haproxy -c -f /etc/haproxy/haproxy.cfg
systemctl enable haproxy
systemctl restart haproxy

if ! ss -lntp | grep -q ':6443'; then
  systemctl status haproxy --no-pager || true
  journalctl -u haproxy -n 100 --no-pager || true
  echo "HAProxy did not open TCP port 6443"
  exit 1
fi

echo "HAProxy is listening on 6443 and forwarding to the three control-plane nodes"
