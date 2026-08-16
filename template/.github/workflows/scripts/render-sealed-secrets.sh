#!/usr/bin/env bash
set -euo pipefail

# Render SealedSecret manifests without cluster credentials.
#
# Requirements:
# - kubeseal on PATH
# - SEALED_SECRETS_CERT set to a cert file path (or URL accepted by kubeseal)
# - K8S_NAMESPACE set
# - APP_ENV_KEYS and/or APP_ENV_PREFIX set
#
# Optional:
# - APP_ENV_SECRET_NAME (default: app-env)
# - PULL_SECRET_NAME (default: ghcr-secret)
# - APP_ENV_SECRETS_JSON JSON object used when app env values come from a
#   GitHub Actions secrets context
# - GHCR_USER + GHCR_TOKEN to emit pull-secret SealedSecret
# - OUTPUT_DIR (default: deployment/k8s)

if ! command -v kubeseal >/dev/null 2>&1; then
  echo "kubeseal is required" >&2
  exit 1
fi

SEALED_SECRETS_CERT="${SEALED_SECRETS_CERT:-}"
K8S_NAMESPACE="${K8S_NAMESPACE:-}"
APP_ENV_KEYS="${APP_ENV_KEYS:-}"
APP_ENV_PREFIX="${APP_ENV_PREFIX:-}"

if [[ -z "${SEALED_SECRETS_CERT}" ]]; then
  echo "SEALED_SECRETS_CERT is required" >&2
  exit 1
fi
if [[ -z "${K8S_NAMESPACE}" ]]; then
  echo "K8S_NAMESPACE is required" >&2
  exit 1
fi
if [[ -z "${APP_ENV_KEYS}" && -z "${APP_ENV_PREFIX}" ]]; then
  echo "Set APP_ENV_KEYS and/or APP_ENV_PREFIX" >&2
  exit 1
fi

APP_ENV_SECRET_NAME="${APP_ENV_SECRET_NAME:-app-env}"
PULL_SECRET_NAME="${PULL_SECRET_NAME:-ghcr-secret}"
OUTPUT_DIR="${OUTPUT_DIR:-deployment/k8s}"

mkdir -p "${OUTPUT_DIR}"

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "${tmpdir}"
}
trap cleanup EXIT

python3 - "${tmpdir}/app-env.secret.json" <<'PY'
import json
import os
import re
import sys

out_path = sys.argv[1]
namespace = os.environ["K8S_NAMESPACE"]
name = os.environ.get("APP_ENV_SECRET_NAME", "app-env")
keys_raw = os.environ.get("APP_ENV_KEYS", "")
prefix = os.environ.get("APP_ENV_PREFIX", "")
secrets_json = os.environ.get("APP_ENV_SECRETS_JSON", "")

app_env = {}
secret_values = {}
if secrets_json:
  try:
    secret_values = json.loads(secrets_json)
  except json.JSONDecodeError as error:
    raise SystemExit(f"Invalid APP_ENV_SECRETS_JSON: {error}")
  if not isinstance(secret_values, dict):
    raise SystemExit("APP_ENV_SECRETS_JSON must contain a JSON object")

if keys_raw:
  for key in [k for k in re.split(r"[\s,]+", keys_raw.strip()) if k]:
    app_env[key] = secret_values.get(key, os.environ.get(key, ""))

if prefix:
    for key, value in os.environ.items():
        if key.startswith(prefix):
            out_key = key[len(prefix) :]
            if out_key:
                app_env[out_key] = value

if not app_env:
  raise SystemExit("No app-env keys resolved")

obj = {
    "apiVersion": "v1",
    "kind": "Secret",
    "metadata": {"name": name, "namespace": namespace},
    "type": "Opaque",
    "stringData": app_env,
}
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(obj, f)
PY

kubeseal \
  --format yaml \
  --cert "${SEALED_SECRETS_CERT}" \
  --namespace "${K8S_NAMESPACE}" \
  --name "${APP_ENV_SECRET_NAME}" \
  < "${tmpdir}/app-env.secret.json" \
  > "${OUTPUT_DIR}/${APP_ENV_SECRET_NAME}.sealedsecret.yaml"

if [[ -n "${GHCR_USER:-}" && -n "${GHCR_TOKEN:-}" ]]; then
  auth_b64="$(printf '%s' "${GHCR_USER}:${GHCR_TOKEN}" | base64 | tr -d '\n')"
  dockerconfig_json="$(printf '{"auths":{"ghcr.io":{"username":"%s","password":"%s","auth":"%s"}}}' "${GHCR_USER}" "${GHCR_TOKEN}" "${auth_b64}")"
  dockerconfig_b64="$(printf '%s' "${dockerconfig_json}" | base64 | tr -d '\n')"

  cat > "${tmpdir}/ghcr.secret.yaml" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${PULL_SECRET_NAME}
  namespace: ${K8S_NAMESPACE}
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: ${dockerconfig_b64}
EOF

  kubeseal \
    --format yaml \
    --cert "${SEALED_SECRETS_CERT}" \
    --namespace "${K8S_NAMESPACE}" \
    --name "${PULL_SECRET_NAME}" \
    < "${tmpdir}/ghcr.secret.yaml" \
    > "${OUTPUT_DIR}/${PULL_SECRET_NAME}.sealedsecret.yaml"
fi

echo "Rendered SealedSecrets into ${OUTPUT_DIR}"
