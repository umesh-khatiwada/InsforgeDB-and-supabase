#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$ROOT_DIR/manifests"

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
helm upgrade --install supabase-postgres bitnami/postgresql -n supabase -f "$MANIFESTS_DIR/postgres-values.yaml" \
  --set postgresql.postgresqlPassword="${POSTGRES_PASSWORD}" --wait

echo "Installing MinIO..."
helm upgrade --install supabase-minio minio/minio -n supabase -f "$MANIFESTS_DIR/minio-values.yaml" \
  --set accessKey="${MINIO_ACCESS_KEY}",secretKey="${MINIO_SECRET_KEY}" --wait

echo "Installing Kong (gateway)..."
helm upgrade --install supabase-kong kong/kong -n supabase -f "$MANIFESTS_DIR/kong-values.yaml" --wait

echo "Deploying Supabase services and ClusterIP services..."
kubectl apply -k "$MANIFESTS_DIR/"

echo "Waiting for deployments to become ready..."
kubectl -n supabase rollout status deployment/postgrest --timeout=120s || true
kubectl -n supabase rollout status deployment/gotrue --timeout=120s || true
kubectl -n supabase rollout status deployment/realtime --timeout=120s || true
kubectl -n supabase rollout status deployment/storage --timeout=120s || true

echo "Applying Ingress..."
kubectl apply -f "$MANIFESTS_DIR/ingress.yaml"

echo "All done. To access the stack locally, map 'supabase.local' to your cluster IP (e.g. minikube ip) in /etc/hosts."

echo "Example:"
if command -v minikube >/dev/null 2>&1; then
  echo "  sudo -- sh -c \"echo \"$(minikube ip) supabase.local\" >> /etc/hosts\""
fi

echo "Deployed."
