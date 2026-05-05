# Supabase for Kubernetes with Helm

This directory contains configurations and scripts to deploy a [Supabase](https://github.com/supabase/supabase) instance in a Kubernetes cluster using Helm 3.

Supabase is an open-source Firebase alternative that provides:
- PostgreSQL database
- Real-time subscriptions
- Authentication & authorization
- RESTful APIs
- File storage
- And more

For detailed Supabase documentation, refer to the [official docs](https://supabase.io/docs).

## Quick Start

### 1. Add the Supabase Helm Repository

```bash
helm repo add supabase https://supabase-community.github.io/supabase-kubernetes
helm repo update
```

### 2. Install Supabase

```bash
helm install my-supabase supabase/supabase --version 0.5.6
```

To install in a specific namespace:

```bash
helm install my-supabase supabase/supabase --namespace supabase --create-namespace
```

### 3. Verify Deployment

```bash
kubectl get pods -l app.kubernetes.io/instance=my-supabase
```

### 4. Access Supabase Studio

Get the ingress address:

```bash
kubectl get ingress
```

Default credentials (development only):
- **Username:** `supabase`
- **Password:** `this_password_is_insecure_and_should_be_updated`

## Configuration

### Create a Values File

Create a `values.yaml` file to customize your deployment:

```yaml
# Database configuration
secret:
  db:
    password: your-secure-db-password
    database: supabase

  # JWT configuration
  jwt:
    anonKey: eyJhbGc...
    serviceKey: eyJhbGc...
    secret: your-jwt-secret-32-chars

  # Dashboard credentials
  dashboard:
    username: supabase
    password: your-secure-password

  # Analytics (Logflare)
  analytics:
    publicAccessToken: your-public-token
    privateAccessToken: your-private-token

  # SMTP configuration (optional)
  smtp:
    username: your-smtp-user
    password: your-smtp-password

# Storage backend (S3)
storage:
  environment:
    STORAGE_BACKEND: s3
    GLOBAL_S3_ENDPOINT: http://minio:9000
    GLOBAL_S3_PROTOCOL: http
    GLOBAL_S3_FORCE_PATH_STYLE: true
    AWS_DEFAULT_REGION: us-east-1
```

### Generate JWT Secrets

Generate a 32-character secret:

```bash
openssl rand -base64 32
```

Use the [JWT Tool](https://supabase.com/docs/guides/self-hosting/docker#generate-and-configure-api-keys) to generate `anonKey` and `serviceKey`.

### Database Configuration

By default, the chart uses a PostgreSQL StatefulSet. For production, consider:

- **StackGres**: A Kubernetes Postgres operator
- **Postgres Operator**: Zalando's Postgres operator
- **Managed Services**: AWS RDS, Azure Database for PostgreSQL, etc.

Configure external database in `values.yaml`:

```yaml
secret:
  db:
    host: your-db-host
    port: 5432
    password: your-db-password
    database: supabase
```

### S3 Storage Configuration

To use S3 for file storage:

```yaml
secret:
  s3:
    keyId: your-s3-key-id
    accessKey: your-s3-access-key

storage:
  environment:
    STORAGE_BACKEND: s3
    GLOBAL_S3_ENDPOINT: https://s3.amazonaws.com
    GLOBAL_S3_PROTOCOL: https
    AWS_DEFAULT_REGION: us-east-1
```

### BigQuery Analytics

To use BigQuery as the analytics backend:

```yaml
bigQuery:
  enabled: true

secret:
  bigquery:
    gcloudJson: '{"type":"service_account", ...}'
```

Or reference an existing Kubernetes Secret:

```yaml
secret:
  bigquery:
    secretRef: my-bigquery-secret
    secretRefKey:
      gcloudJson: gcloud.json
```

## Database Migrations

To apply SQL migrations during initialization:

```yaml
db:
  config:
    20230101000000_profiles.sql: |
      CREATE TABLE profiles (
        id UUID REFERENCES auth.users NOT NULL,
        updated_at TIMESTAMP WITH TIME ZONE,
        username TEXT UNIQUE,
        avatar_url TEXT,
        website TEXT,
        PRIMARY KEY (id),
        UNIQUE(username),
        CONSTRAINT username_length CHECK (char_length(username) >= 3)
      );
```

## Production Deployment

For production environments, ensure:

1. **Database Replication**: Use replicated PostgreSQL with high availability
2. **SSL/TLS**: Enable SSL for PostgreSQL and ingress endpoints
3. **Ingress Security**: Use cert-manager or LoadBalancer for SSL certificates
4. **Custom Domain**: Update ingress endpoints with your domain
5. **Secure JWT Secrets**: Generate new, strong JWT secrets
6. **Backup Strategy**: Implement regular database backups
7. **Resource Limits**: Set appropriate CPU and memory limits
8. **Monitoring**: Deploy monitoring and logging solutions

## Troubleshooting

### Ingress Controller

For different Kubernetes versions, you may need to use `className` instead of annotations:

```yaml
kong:
  ingress:
    enabled: true
    className: "nginx"
    annotations:
      nginx.ingress.kubernetes.io/rewrite-target: /
```

### Pod Status

Check pod logs for errors:

```bash
kubectl logs <pod-name>
```

Describe a pod for events:

```bash
kubectl describe pod <pod-name>
```

### Testing the Chart

Run chart testing locally:

```bash
docker run -it \
  --workdir=/data \
  --volume $(pwd)/charts/supabase:/data \
  quay.io/helmpack/chart-testing:v3.7.1 \
  ct lint --validate-maintainers=false --chart-dirs . --charts .
```

## Disclaimer

- This project is community-maintained and not officially supported by Supabase
- The chart uses `supabase/postgres` with extensions like `pgjwt` and `wal2json`
- For production, consider using custom PostgreSQL images or managed services
- Single-node database configurations are for development only

## Upgrade Guide

### 0.0.x to 0.1.x

- PostgreSQL upgraded from 14.1 to 15.1 (backup data before upgrading)
- Database initialization scripts have been updated
- Migration scripts exposed at `db.config`
- Ingress limited to `kong` and `db` services for security

## References

- [Supabase Kubernetes Repository](https://github.com/supabase-community/supabase-kubernetes)
- [Supabase Documentation](https://supabase.io/docs)
- [Helm Documentation](https://helm.sh/docs/)

## Support

For issues:
- Open an issue on the [supabase-kubernetes repository](https://github.com/supabase-community/supabase-kubernetes/issues)
- Do NOT create issues on the official Supabase repository for Kubernetes-specific problems

## License

This project is licensed under the [Apache 2.0 License](https://github.com/supabase-community/supabase-kubernetes/blob/main/LICENSE).