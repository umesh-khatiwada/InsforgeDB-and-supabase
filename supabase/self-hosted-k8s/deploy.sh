#!/usr/bin/env bash
set -uo pipefail  # Don't exit on error immediately; allow cleanup

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$ROOT_DIR/manifests"

# Usage
usage() {
  cat <<EOF
Usage: $0 [COMMAND]

Commands:
  install    Install Supabase stack (default)
  uninstall  Remove all Supabase services and namespace
  status     Check status of all services

Examples:
  $0 install
  $0 uninstall
  $0 status
EOF
  exit 0
}

# Default command
COMMAND="${1:-install}"

case "$COMMAND" in
  install|uninstall|status)
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    echo "Unknown command: $COMMAND"
    usage
    ;;
esac

# Trap errors and exit cleanly
trap 'echo "\nOperation interrupted or failed. State may be inconsistent." >&2' EXIT

if [ "$COMMAND" = "uninstall" ]; then
  echo "🗑️  Uninstalling Supabase stack..."
  echo "Removing Helm releases..."
  helm uninstall supabase-postgres supabase-minio supabase-kong -n supabase 2>/dev/null || echo "  (some releases may not exist)"
  
  echo "Removing Kubernetes manifests and secrets..."
  kubectl delete -k "$MANIFESTS_DIR" -n supabase 2>/dev/null || true
  
  echo "Removing namespace..."
  kubectl delete namespace supabase 2>/dev/null || echo "  (namespace may not exist)"
  
  echo "✅ Uninstall complete."
  exit 0
fi

if [ "$COMMAND" = "status" ]; then
  echo "📊 Supabase stack status:"
  echo ""
  echo "Helm releases:"
  helm list -n supabase 2>/dev/null || echo "  (no releases found)"
  echo ""
  echo "Pods:"
  kubectl get pods -n supabase 2>/dev/null || echo "  (namespace may not exist)"
  echo ""
  echo "Services:"
  kubectl get svc -n supabase 2>/dev/null || echo "  (no services found)"
  exit 0
fi

echo "Generating secrets and creating namespace..."
echo "Generating strong random secrets and creating Kubernetes Secret..."
# Generate secrets (openssl available on macOS/linux)
POSTGRES_PASSWORD=$(openssl rand -hex 16)
MINIO_ACCESS_KEY=$(openssl rand -hex 12)
MINIO_SECRET_KEY=$(openssl rand -hex 24)
GOTRUE_JWT_SECRET=$(openssl rand -hex 32)
POSTGREST_JWT_SECRET=$(openssl rand -hex 32)
ANON_KEY="anon_$(openssl rand -hex 16)"
SERVICE_ROLE_KEY="svc_$(openssl rand -hex 32)"

POSTGRES_URI="postgres://supabase:${POSTGRES_PASSWORD}@supabase-postgres:5432/supabase"

kubectl create namespace supabase --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic supabase-secrets -n supabase \
  --from-literal=POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
  --from-literal=POSTGRES_URI="${POSTGRES_URI}" \
  --from-literal=MINIO_ACCESS_KEY="${MINIO_ACCESS_KEY}" \
  --from-literal=MINIO_SECRET_KEY="${MINIO_SECRET_KEY}" \
  --from-literal=GOTRUE_JWT_SECRET="${GOTRUE_JWT_SECRET}" \
  --from-literal=POSTGREST_JWT_SECRET="${POSTGREST_JWT_SECRET}" \
  --from-literal=ANON_KEY="${ANON_KEY}" \
  --from-literal=SERVICE_ROLE_KEY="${SERVICE_ROLE_KEY}" \
  --from-literal=GOTRUE_SITE_URL="http://supabase.local" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Installing cert-manager (if not present)..."
helm repo add jetstack https://charts.jetstack.io || true
helm repo update
if ! kubectl get crd certificates.cert-manager.io >/dev/null 2>&1; then
  echo "Installing cert-manager..."
  helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set installCRDs=true --wait
else
  echo "cert-manager detected"
fi

echo "Applying cert issuer..."
kubectl apply -f "$MANIFESTS_DIR/cert-issuer.yaml"

echo "Adding helm repos..."
helm repo add bitnami https://charts.bitnami.com/bitnami || true
helm repo add minio https://charts.min.io/ || true
helm repo add kong https://charts.konghq.com || true
helm repo update

echo "Installing PostgreSQL (Bitnami)..."
if helm list -n supabase | grep -q supabase-postgres; then
  echo "  PostgreSQL release exists, upgrading..."
else
  echo "  Creating new PostgreSQL release..."
fi
helm upgrade --install supabase-postgres bitnami/postgresql -n supabase -f "$MANIFESTS_DIR/postgres-values.yaml" \
  --set postgresql.postgresqlPassword="${POSTGRES_PASSWORD}" --wait --timeout=5m || { echo "PostgreSQL install failed. Check logs: kubectl logs -n supabase deploy/supabase-postgres"; exit 1; }

echo "Installing MinIO..."
if helm list -n supabase | grep -q supabase-minio; then
  echo "  MinIO release exists, upgrading..."
else
  echo "  Creating new MinIO release..."
fi
helm upgrade --install supabase-minio minio/minio -n supabase -f "$MANIFESTS_DIR/minio-values.yaml" \
  --set accessKey="${MINIO_ACCESS_KEY}",secretKey="${MINIO_SECRET_KEY}" --wait --timeout=10m || { echo "MinIO install failed. Check logs: kubectl logs -n supabase job/supabase-minio-post-job"; exit 1; }

echo "Installing Kong (gateway)..."
if helm list -n supabase | grep -q supabase-kong; then
  echo "  Kong release exists, upgrading..."
else
  echo "  Creating new Kong release..."
fi
helm upgrade --install supabase-kong kong/kong -n supabase -f "$MANIFESTS_DIR/kong-values.yaml" --wait --timeout=5m || { echo "Kong install failed. Check logs: kubectl logs -n supabase deploy/supabase-kong"; exit 1; }

echo "Deploying Supabase services and ClusterIP services..."
kubectl apply -k "$MANIFESTS_DIR/"

echo "Waiting for deployments to become ready..."
kubectl -n supabase rollout status deployment/postgrest --timeout=120s || true
kubectl -n supabase rollout status deployment/gotrue --timeout=120s || true
kubectl -n supabase rollout status deployment/realtime --timeout=120s || true
kubectl -n supabase rollout status deployment/storage --timeout=120s || true

echo "Applying Ingress..."
kubectl apply -f "$MANIFESTS_DIR/ingress.yaml"

echo "Deployed. ✅"
echo ""
echo "Next steps:"
echo "  1. Check status: $0 status"
echo "  2. Map 'supabase.local' to your cluster IP in /etc/hosts"
echo "     Example (minikube): sudo sh -c \"echo '$(minikube ip) supabase.local' >> /etc/hosts\""
echo "  3. Access services:"
echo "     - PostgREST: http://supabase.local/rest"
echo "     - GoTrue Auth: http://supabase.local/auth"
echo "     - Realtime: ws://supabase.local/realtime"
echo "     - Storage: http://supabase.local/storage"
echo ""
echo "To uninstall: $0 uninstall"
