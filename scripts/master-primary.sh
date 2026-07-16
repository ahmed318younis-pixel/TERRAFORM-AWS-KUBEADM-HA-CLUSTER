echo "Initializing the first control-plane node"

PRIVATE_IP="$(ip -4 route get 1.1.1.1 | awk '{print $7; exit}')"
KUBERNETES_VERSION="$(kubeadm version -o short)"

until getent hosts "${CONTROL_PLANE_ENDPOINT%%:*}" >/dev/null 2>&1; do
  echo "Waiting for private API DNS to resolve"
  sleep 5
done

cat >/root/kubeadm-config.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: ${PRIVATE_IP}
  bindPort: 6443
nodeRegistration:
  name: ${NODE_NAME}
  criSocket: unix:///run/containerd/containerd.sock
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
kubernetesVersion: ${KUBERNETES_VERSION}
controlPlaneEndpoint: ${CONTROL_PLANE_ENDPOINT}
networking:
  podSubnet: ${POD_CIDR}
  serviceSubnet: ${SERVICE_CIDR}
apiServer:
  certSANs:
    - ${CONTROL_PLANE_ENDPOINT%%:*}
    - ${HAPROXY_IP}
    - ${PRIVATE_IP}
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
EOF

kubeadm config validate --config /root/kubeadm-config.yaml
kubeadm init --config /root/kubeadm-config.yaml --upload-certs

mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config
chmod 0600 /root/.kube/config

mkdir -p /home/ubuntu/.kube
cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown -R ubuntu:ubuntu /home/ubuntu/.kube
chmod 0600 /home/ubuntu/.kube/config

export KUBECONFIG=/etc/kubernetes/admin.conf

IMDS_TOKEN="$(curl -fsS -X PUT \
  -H 'X-aws-ec2-metadata-token-ttl-seconds: 21600' \
  http://169.254.169.254/latest/api/token)"
INSTANCE_ID="$(curl -fsS \
  -H "X-aws-ec2-metadata-token: ${IMDS_TOKEN}" \
  http://169.254.169.254/latest/meta-data/instance-id)"
WORKER_JOIN_PARAMETER="${BOOTSTRAP_PARAMETER_PREFIX}/${INSTANCE_ID}/worker-join"
CONTROL_JOIN_PARAMETER="${BOOTSTRAP_PARAMETER_PREFIX}/${INSTANCE_ID}/control-plane-join"

BASE_JOIN="$(kubeadm token create --ttl 2h --print-join-command)"
CERTIFICATE_KEY="$(kubeadm init phase upload-certs --upload-certs 2>/dev/null | grep -E '^[a-f0-9]{64}$' | tail -n 1)"
if [[ -z "${CERTIFICATE_KEY}" ]]; then
  echo "Unable to determine the kubeadm certificate key"
  exit 1
fi
WORKER_JOIN="${BASE_JOIN} --cri-socket unix:///run/containerd/containerd.sock"
CONTROL_JOIN="${BASE_JOIN} --control-plane --certificate-key ${CERTIFICATE_KEY} --cri-socket unix:///run/containerd/containerd.sock"

aws ssm put-parameter \
  --region "${AWS_REGION}" \
  --name "${WORKER_JOIN_PARAMETER}" \
  --type SecureString \
  --value "${WORKER_JOIN}" \
  --overwrite

aws ssm put-parameter \
  --region "${AWS_REGION}" \
  --name "${CONTROL_JOIN_PARAMETER}" \
  --type SecureString \
  --value "${CONTROL_JOIN}" \
  --overwrite

echo "Published time-limited join commands to SSM Parameter Store"

kubectl create -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml"

until kubectl get crd installations.operator.tigera.io >/dev/null 2>&1; do
  echo "Waiting for the Calico operator CRDs"
  sleep 5
done

cat >/root/calico-custom-resources.yaml <<EOF
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    bgp: Disabled
    clusterRoutingMode: Felix
    ipPools:
      - blockSize: 26
        cidr: ${POD_CIDR}
        encapsulation: VXLAN
        natOutgoing: Enabled
        nodeSelector: all()
---
apiVersion: operator.tigera.io/v1
kind: APIServer
metadata:
  name: default
spec: {}
EOF

kubectl apply -f /root/calico-custom-resources.yaml

echo "Calico ${CALICO_VERSION} installation requested"

if [[ "${DEPLOY_DEMO_APP}" == "true" ]]; then
  cat >/root/demo-app.yaml <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: demo
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              app: web
      containers:
        - name: nginx
          image: nginx:alpine
          ports:
            - name: http
              containerPort: 80
          readinessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 5
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 15
            periodSeconds: 10
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 250m
              memory: 256Mi
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web
  namespace: demo
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: web
---
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: demo
spec:
  type: NodePort
  externalTrafficPolicy: Cluster
  selector:
    app: web
  ports:
    - name: http
      port: 80
      targetPort: http
      nodePort: ${ALB_NODE_PORT}
EOF

  kubectl apply -f /root/demo-app.yaml
  echo "Demo application created on NodePort ${ALB_NODE_PORT}"
fi

cat >/usr/local/bin/cluster-status <<'EOF'
#!/usr/bin/env bash
set -e
export KUBECONFIG=/etc/kubernetes/admin.conf

kubectl get nodes -o wide
kubectl get pods -A
EOF
chmod 0755 /usr/local/bin/cluster-status

echo "Primary control-plane bootstrap completed"
