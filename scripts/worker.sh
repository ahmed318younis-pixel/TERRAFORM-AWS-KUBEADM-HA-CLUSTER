echo "Waiting for the worker join command"

JOIN_COMMAND=""

for attempt in $(seq 1 180); do
  JOIN_COMMAND="$(aws ssm get-parameter \
    --region "${AWS_REGION}" \
    --name "${WORKER_JOIN_PARAMETER}" \
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
  echo "Timed out waiting for the worker join command"
  exit 1
fi

bash -c "${JOIN_COMMAND} --node-name ${NODE_NAME}"

echo "Worker node joined successfully"
