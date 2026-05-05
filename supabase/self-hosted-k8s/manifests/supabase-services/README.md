# Supabase Services Templates

These are minimal example Deployments for core Supabase services. They are intentionally lightweight and use placeholders for secrets and hostnames.

Replace placeholders and adapt replicas, resource requests/limits, probes, and PVCs before using in production.

Services included:

- `postgrest` — PostgREST for Postgres HTTP API
- `gotrue` — Authentication provider
- `realtime` — Realtime engine
- `storage` — Storage service (talks to MinIO)

Next steps:

- Add Services and Ingress objects for each Deployment
- Create Kubernetes Secrets for DB credentials, JWT secrets, and MinIO credentials
- Add liveness/readiness probes and resource limits
- Optionally convert these to Helm charts or `HelmRelease` manifests for GitOps
