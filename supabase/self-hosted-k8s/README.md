# Supabase — Self-hosted on Kubernetes

This folder contains scaffolding and templates to run a self-hosted Supabase stack on Kubernetes.

Prerequisites

- A Kubernetes cluster (v1.24+ recommended)
- `kubectl` configured for the cluster
- `helm` 3.x
- `cert-manager` (optional, recommended for TLS)
- A storage class in your cluster for persistent volumes

What’s included

- `manifests/namespace.yaml` — a namespace for the stack
- `manifests/kustomization.yaml` — kustomize overlay
- Helm values templates for PostgreSQL, MinIO, and Kong (reverse proxy)
- Example Kubernetes Deployment templates for Supabase services (placeholders)

Important notes

- These templates are opinionated examples, not a production turnkey install. Refer to https://supabase.com/docs/guides/self-hosting for official guidance and updates.
- Replace placeholders (`<...>`) with real secrets and image tags before deploying.

Quick deploy (example flow)

1. Create namespace and cert-manager (if not installed):

```bash
kubectl apply -f manifests/namespace.yaml
# install cert-manager if needed
# helm repo add jetstack https://charts.jetstack.io && helm repo update
# helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set installCRDs=true
```

2. Install PostgreSQL (example using Bitnami Helm chart):

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install supabase-postgres bitnami/postgresql -n supabase -f manifests/postgres-values.yaml
```

3. Install MinIO for Storage:

```bash
helm repo add minio https://charts.min.io/
helm repo update
helm install supabase-minio minio/minio -n supabase -f manifests/minio-values.yaml
```

4. Install Kong (or other ingress/proxy) and configure routes as needed.

5. Deploy Supabase service Deployments from `manifests/supabase-services/` and set environment vars to point at Postgres, MinIO, and Kong.

Files in this folder are templates — after you review them I can:

- Fill in production-ready values (secrets, TLS) and generate Kubernetes Secrets
- Convert templates to HelmRelease manifests for Flux/ArgoCD
- Add example Postgres initialization and migrations

## Quick automated deploy

There is a `deploy.sh` script that automates creating the namespace, installing cert-manager (if missing), installing PostgreSQL, MinIO and Kong via Helm, and applying the example Supabase service manifests and Ingress.

Run:

```bash
chmod +x deploy.sh
./deploy.sh
```

Notes:

- The script uses a self-signed Issuer via `cert-manager` to generate a TLS secret for `supabase.local`.
- For local access, add an `/etc/hosts` entry pointing `supabase.local` to your cluster IP (e.g. `minikube ip`).
- These templates are for quick staging/demo use; review secrets, storage settings, and resource limits before production.

Secrets note:

- The repository contains `manifests/secrets.yaml` as an example only. The `deploy.sh` script will generate strong random secrets at runtime and create the `supabase-secrets` Secret in the `supabase` namespace. `secrets.yaml` is not applied by the kustomize overlay to avoid overwriting generated secrets.
