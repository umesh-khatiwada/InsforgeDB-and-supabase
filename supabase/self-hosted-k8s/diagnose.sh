#!/usr/bin/env bash
# Diagnostic script for Supabase self-hosted K8s installation

set -u

echo "🔍 Supabase K8s Installation Diagnostic Report"
echo "=============================================="
echo ""

# Check kubectl
echo "1️⃣  Checking kubectl..."
if ! command -v kubectl &> /dev/null; then
  echo "  ❌ kubectl not found. Install kubectl first."
  exit 1
else
  echo "  ✅ kubectl found: $(kubectl version --client --short 2>/dev/null || echo 'version check failed')"
fi

# Check cluster
echo ""
echo "2️⃣  Checking Kubernetes cluster..."
if ! kubectl cluster-info &> /dev/null; then
  echo "  ❌ Cannot connect to cluster. Check kubeconfig."
  exit 1
else
  echo "  ✅ Cluster accessible"
  kubectl cluster-info | grep -E "Kubernetes master|control plane"
fi

# Check namespace
echo ""
echo "3️⃣  Checking supabase namespace..."
if ! kubectl get namespace supabase &> /dev/null; then
  echo "  ❌ Namespace 'supabase' does not exist"
  echo "  Run: ./deploy.sh install"
  exit 1
else
  echo "  ✅ Namespace exists"
fi

# Check Helm releases
echo ""
echo "4️⃣  Checking Helm releases..."
HELM_RELEASES=$(helm list -n supabase 2>/dev/null | tail -n +2 | wc -l)
echo "  Releases found: $HELM_RELEASES"
helm list -n supabase

# Check pods
echo ""
echo "5️⃣  Checking pods..."
echo "Pod status:"
kubectl get pods -n supabase -o wide

echo ""
echo "Pod details (events):"
kubectl describe pods -n supabase 2>/dev/null | grep -E "Name:|State:|Reason:|Message:" | head -20

# Check specific service logs
echo ""
echo "6️⃣  Checking service logs..."

echo ""
echo "🔹 PostgreSQL (Bitnami):"
if kubectl get deployment supabase-postgres -n supabase &> /dev/null; then
  echo "  ✅ Deployment exists"
  kubectl logs -n supabase deployment/supabase-postgres --tail=3 2>/dev/null || echo "  ⚠️  No logs yet"
else
  echo "  ❌ Deployment not found"
fi

echo ""
echo "🔹 PostgREST:"
if kubectl get deployment postgrest -n supabase &> /dev/null; then
  echo "  ✅ Deployment exists"
  kubectl logs -n supabase deployment/postgrest --tail=3 2>/dev/null || echo "  ⚠️  No logs yet"
else
  echo "  ❌ Deployment not found"
fi

echo ""
echo "🔹 GoTrue (Auth):"
if kubectl get deployment gotrue -n supabase &> /dev/null; then
  echo "  ✅ Deployment exists"
  kubectl logs -n supabase deployment/gotrue --tail=3 2>/dev/null || echo "  ⚠️  No logs yet"
else
  echo "  ❌ Deployment not found"
fi

echo ""
echo "🔹 Realtime:"
if kubectl get deployment realtime -n supabase &> /dev/null; then
  echo "  ✅ Deployment exists"
  kubectl logs -n supabase deployment/realtime --tail=3 2>/dev/null || echo "  ⚠️  No logs yet"
else
  echo "  ❌ Deployment not found"
fi

echo ""
echo "🔹 Storage:"
if kubectl get deployment storage -n supabase &> /dev/null; then
  echo "  ✅ Deployment exists"
  kubectl logs -n supabase deployment/storage --tail=3 2>/dev/null || echo "  ⚠️  No logs yet"
else
  echo "  ❌ Deployment not found"
fi

# Check services
echo ""
echo "7️⃣  Checking services..."
kubectl get svc -n supabase -o wide

# Check ingress
echo ""
echo "8️⃣  Checking ingress..."
kubectl get ingress -n supabase -o wide

# Check secrets
echo ""
echo "9️⃣  Checking secrets..."
kubectl get secrets -n supabase

# Check PVCs
echo ""
echo "🔟 Checking persistent volumes..."
kubectl get pvc -n supabase

# Check events
echo ""
echo "1️⃣1️⃣  Recent events..."
kubectl get events -n supabase --sort-by='.lastTimestamp' | tail -10

echo ""
echo "=============================================="
echo "✅ Diagnostic complete."
echo ""
echo "Common issues and fixes:"
echo "  • Pod Pending: Check node resources (kubectl top nodes)"
echo "  • Pod CrashLoopBackOff: Check logs (kubectl logs -n supabase <pod-name>)"
echo "  • Image pull errors: Check image availability and registry access"
echo "  • Connection refused: Check service DNS and ports"
echo ""
echo "For more details:"
echo "  kubectl describe pod <pod-name> -n supabase"
echo "  kubectl logs <pod-name> -n supabase -f"
