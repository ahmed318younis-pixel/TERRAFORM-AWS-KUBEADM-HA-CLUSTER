echo "Waiting for the control-plane join command"

PRIVATE_IP="$(ip -4 route get 1.1.1.1 | awk '{print $7; exit}')"
JOIN_COMMAND=""

for attempt in $(seq 1 180); do
  JOIN_COMMAND="$(aws ssm get-parameter \
    --region "${AWS_REGION}" \
    --name "${CONTROL_JOIN_PARAMETER}" \
    --with-decryption \
    --query 'Parameter.Value' \
    --output text 2>/dev/null || true)"

  if [[ -n "${JOIN_COMMAND}" && "${JOIN_COMMAND}" != "None" ]]; then
    break
  fi

  echo "Join command is not available yet; attempt ${attempt}/180"
  sleep 10
done

if [[ -z "${JOIN_COMMAND}" || "${JOIN_COMMAND}" == "None" ]]; then
  echo "Timed out waiting for the control-plane join command"
  exit 1
fi

bash -c "${JOIN_COMMAND} --apiserver-advertise-address ${PRIVATE_IP} --node-name ${NODE_NAME}"

mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config
chmod 0600 /root/.kube/config

mkdir -p /home/ubuntu/.kube
cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown -R ubuntu:ubuntu /home/ubuntu/.kube
chmod 0600 /home/ubuntu/.kube/config

echo "Secondary control-plane node joined successfully"
