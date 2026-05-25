#!/bin/bash
# Script to deploy Genkart app to local Minikube using Helm
# Usage: ./scripts/deploy-local.sh

set -e

# Add Helm installation path on Windows to PATH (unconditional export for all shell types)
export PATH=$PATH:/c/helm:/C/helm:"C:\helm":"C:/helm":/mnt/c/helm

# Translate Windows kubeconfig paths to WSL paths if running in WSL
if grep -qEi "(Microsoft|WSL)" /proc/version 2>/dev/null; then
  if [ -f "/mnt/c/Users/hp/.kube/config" ]; then
    echo "[WSL Detected] Copying and translating Windows Kubeconfig for WSL..."
    mkdir -p ~/.kube
    cp /mnt/c/Users/hp/.kube/config ~/.kube/config_wsl
    sed -i 's|C:\\Users\\hp|/mnt/c/Users/hp|g' ~/.kube/config_wsl
    sed -i 's|\\|/|g' ~/.kube/config_wsl
    export KUBECONFIG=~/.kube/config_wsl
  fi
fi

# Check for required tools
for tool in kubectl; do
  if ! command -v $tool >/dev/null 2>&1; then
    echo "[ERROR] $tool is not installed. Please install it before running this script."
    exit 1
  fi
  echo "[CHECK] $tool is installed."
done

# Check for helm or helm.exe (crucial for WSL/Windows bash environment)
if command -v helm >/dev/null 2>&1; then
  HELM_CMD="helm"
elif command -v helm.exe >/dev/null 2>&1; then
  HELM_CMD="helm.exe"
else
  echo "[ERROR] helm is not installed. Please install it before running this script."
  exit 1
fi
echo "[CHECK] helm is installed."

# Helper to get env var from file
get_env() {
  VAR=$1
  FILE=$2
  grep -E "^$VAR=" "$FILE" | head -n1 | cut -d'=' -f2- | tr -d "'\"\r"
}

# Read client env vars from client/.env
CLIENT_ENV="client/.env"
if [ ! -f "$CLIENT_ENV" ]; then
  echo "[ERROR] $CLIENT_ENV not found!"
  exit 2
fi
NEXT_PUBLIC_API=$(get_env NEXT_PUBLIC_API $CLIENT_ENV)
NEXT_PUBLIC_CLIENT_URL=$(get_env NEXT_PUBLIC_CLIENT_URL $CLIENT_ENV)
NEXT_PUBLIC_JWT_SECRET=$(get_env NEXT_PUBLIC_JWT_SECRET $CLIENT_ENV)
NEXT_PUBLIC_JWT_USER_SECRET=$(get_env NEXT_PUBLIC_JWT_USER_SECRET $CLIENT_ENV)
NEXT_PUBLIC_NODE_ENV=$(get_env NEXT_PUBLIC_NODE_ENV $CLIENT_ENV)

# Read server env vars from server/.env
SERVER_ENV="server/.env"
if [ ! -f "$SERVER_ENV" ]; then
  echo "[ERROR] $SERVER_ENV not found!"
  exit 2
fi
MONGO_URI=$(get_env MONGO_URI $SERVER_ENV)
EMAIL_USER=$(get_env EMAIL_USER $SERVER_ENV)
EMAIL_PASS=$(get_env EMAIL_PASS $SERVER_ENV)
CLIENT_URL=$(get_env CLIENT_URL $SERVER_ENV)
NODE_ENV=$(get_env NODE_ENV $SERVER_ENV)
CLOUDINARY_CLOUD_NAME=$(get_env CLOUDINARY_CLOUD_NAME $SERVER_ENV)
CLOUDINARY_API_KEY=$(get_env CLOUDINARY_API_KEY $SERVER_ENV)
CLOUDINARY_API_SECRET=$(get_env CLOUDINARY_API_SECRET $SERVER_ENV)
CLOUDINARY_FOLDER_NAME=$(get_env CLOUDINARY_FOLDER_NAME $SERVER_ENV)
JWT_SECRET=$(get_env JWT_SECRET $SERVER_ENV)
JWT_USER_SECRET=$(get_env JWT_USER_SECRET $SERVER_ENV)
JWT_EXPIRES_IN=$(get_env JWT_EXPIRES_IN $SERVER_ENV)

# Encode values to base64 (no newlines)
function b64() {
  # Handle cross-platform base64 encoding
  if echo -n "$1" | base64 -w 0 >/dev/null 2>&1; then
    echo -n "$1" | base64 -w 0
  else
    echo -n "$1" | base64 | tr -d '\n'
  fi
}

echo "Generating Secrets for Helm templates..."

cat > helm/templates/client-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: genkart-client-secrets
  labels:
    app: genkart-client
    app.kubernetes.io/managed-by: "Helm"
type: Opaque
data:
  NEXT_PUBLIC_API: $(b64 "$NEXT_PUBLIC_API")
  NEXT_PUBLIC_CLIENT_URL: $(b64 "$NEXT_PUBLIC_CLIENT_URL")
  NEXT_PUBLIC_JWT_SECRET: $(b64 "$NEXT_PUBLIC_JWT_SECRET")
  NEXT_PUBLIC_JWT_USER_SECRET: $(b64 "$NEXT_PUBLIC_JWT_USER_SECRET")
  NEXT_PUBLIC_NODE_ENV: $(b64 "$NEXT_PUBLIC_NODE_ENV")
EOF

cat > helm/templates/server-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: genkart-server-secrets
  labels:
    app: genkart-server
    app.kubernetes.io/managed-by: "Helm"
type: Opaque
data:
  MONGO_URI: $(b64 "$MONGO_URI")
  EMAIL_USER: $(b64 "$EMAIL_USER")
  EMAIL_PASS: $(b64 "$EMAIL_PASS")
  CLIENT_URL: $(b64 "$CLIENT_URL")
  NODE_ENV: $(b64 "$NODE_ENV")
  CLOUDINARY_CLOUD_NAME: $(b64 "$CLOUDINARY_CLOUD_NAME")
  CLOUDINARY_API_KEY: $(b64 "$CLOUDINARY_API_KEY")
  CLOUDINARY_API_SECRET: $(b64 "$CLOUDINARY_API_SECRET")
  CLOUDINARY_FOLDER_NAME: $(b64 "$CLOUDINARY_FOLDER_NAME")
  JWT_SECRET: $(b64 "$JWT_SECRET")
  JWT_USER_SECRET: $(b64 "$JWT_USER_SECRET")
  JWT_EXPIRES_IN: $(b64 "$JWT_EXPIRES_IN")
EOF

echo "Ensuring 'default' namespace exists..."
kubectl get ns default >/dev/null 2>&1 || kubectl create namespace default

echo "Checking and cleaning up pre-existing secrets that block Helm install..."
for secret in genkart-client-secrets genkart-server-secrets; do
  if kubectl get secret $secret -n default >/dev/null 2>&1; then
    MANAGED_BY=$(kubectl get secret $secret -n default -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}' 2>/dev/null)
    if [ "$MANAGED_BY" != "Helm" ]; then
      echo "[WARN] Secret '$secret' exists in 'default' namespace and is not managed by Helm. Deleting it so Helm can manage it."
      kubectl delete secret $secret -n default
    fi
  fi
done

echo "Deploying Genkart app to Minikube using Helm..."
# Overriding repository values for local registry or minikube local image access
# If using minikube docker-env, it accesses the images built locally.
# We set pullPolicy to IfNotPresent so it uses locally built images.
$HELM_CMD upgrade --install genkart ./helm \
  -f helm/values.yaml \
  --set image.client.pullPolicy=IfNotPresent \
  --set image.server.pullPolicy=IfNotPresent \
  --namespace default --create-namespace

echo "Waiting briefly for deployment..."
kubectl rollout status deployment/genkart-client -n default --timeout=60s || echo "[WARN] Timeout waiting for client rollout"
kubectl rollout status deployment/genkart-server -n default --timeout=60s || echo "[WARN] Timeout waiting for server rollout"

echo ""
echo "=== Local Deployment Complete! ==="
echo "Note: If using Minikube, run 'minikube tunnel' in another terminal to allocate External IPs for LoadBalancer services."
echo "Alternatively, you can access the frontend via port-forwarding:"
echo "  kubectl port-forward svc/genkart-client 3005:3005"
echo ""
