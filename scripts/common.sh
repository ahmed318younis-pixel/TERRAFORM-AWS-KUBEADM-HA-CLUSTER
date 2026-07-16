set -Eeuo pipefail

exec > >(tee -a /var/log/kubeadm-bootstrap.log | logger -t kubeadm-bootstrap -s 2>/dev/console) 2>&1
trap 'echo "ERROR: bootstrap failed on ${NODE_NAME} at line ${LINENO}"' ERR

export DEBIAN_FRONTEND=noninteractive

hostnamectl set-hostname "${NODE_NAME}"

PRIVATE_IP="$(ip -4 route get 1.1.1.1 | awk '{print $7; exit}')"
echo "Using node IP ${PRIVATE_IP}"

swapoff -a
sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab

cat >/etc/modules-load.d/kubernetes.conf <<'EOF'
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat >/etc/sysctl.d/99-kubernetes-cri.conf <<'EOF'
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

apt-get update
apt-get install -y \
  apt-transport-https \
  ca-certificates \
  conntrack \
  curl \
  ebtables \
  ethtool \
  gpg \
  ipset \
  jq \
  socat \
  unzip \
  containerd

if ! command -v aws >/dev/null 2>&1; then
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
  rm -rf /tmp/aws
  unzip -q /tmp/awscliv2.zip -d /tmp
  /tmp/aws/install --update
fi

if systemctl list-unit-files | grep -q '^amazon-ssm-agent'; then
  systemctl enable --now amazon-ssm-agent
elif command -v snap >/dev/null 2>&1; then
  snap install amazon-ssm-agent --classic || true
  systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent.service || true
fi

mkdir -p /etc/containerd
containerd config default >/etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl enable --now containerd

mkdir -p -m 0755 /etc/apt/keyrings
curl -fsSL "https://pkgs.k8s.io/core:/stable:/${KUBERNETES_MINOR}/deb/Release.key" \
  | gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
chmod 0644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${KUBERNETES_MINOR}/deb/ /" \
  >/etc/apt/sources.list.d/kubernetes.list

apt-get update
if [[ -n "${KUBERNETES_PACKAGE_VERSION}" ]]; then
  apt-get install -y \
    kubelet="${KUBERNETES_PACKAGE_VERSION}" \
    kubeadm="${KUBERNETES_PACKAGE_VERSION}" \
    kubectl="${KUBERNETES_PACKAGE_VERSION}"
else
  apt-get install -y kubelet kubeadm kubectl
fi
apt-mark hold kubelet kubeadm kubectl

PAUSE_IMAGE="$(kubeadm config images list | awk '/pause/ {print; exit}')"
if [[ -n "${PAUSE_IMAGE}" ]]; then
  sed -ri "s#sandbox_image = \"[^\"]+\"#sandbox_image = \"${PAUSE_IMAGE}\"#" /etc/containerd/config.toml
fi
systemctl restart containerd

cat >/etc/default/kubelet <<EOF
KUBELET_EXTRA_ARGS=--node-ip=${PRIVATE_IP}
EOF

systemctl daemon-reload
systemctl enable --now kubelet

echo "Installed $(kubeadm version -o short), $(kubelet --version), and containerd $(containerd --version | awk '{print $3}')"
