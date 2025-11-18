# CloudNativePG Database Recovery from Longhorn Backup

This guide covers restoring a CloudNativePG PostgreSQL cluster from Longhorn volume backups.

## Prerequisites

- Longhorn backup of your PostgreSQL volume
- Backed up secrets (username/password credentials)
- Original cluster YAML configuration

## Recovery Steps

### Step 1: Restore the Longhorn Volume

**Via Longhorn UI:**
1. Navigate to **Backup** section in Longhorn UI
2. Find your database volume backup (e.g., `postgres-1`)
3. Click **Restore**
4. Name the restored volume (typically same as original, e.g., `postgres-1`)
5. Wait for restoration to complete

### Step 2: Create PVC for the Restored Volume

Once the Longhorn volume is restored, create a PersistentVolumeClaim to make it available:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: <cluster-name>-1  # Must match CloudNativePG naming: <cluster-name>-<instance-number>
  namespace: <namespace>
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn-pg
  resources:
    requests:
      storage: <size>  # Must match volume size
```

Apply the PVC:
```bash
kubectl apply -f pvc.yaml
```

Verify the PVC is bound:
```bash
kubectl get pvc -n <namespace>
```

### Step 3: Restore Secrets

CloudNativePG requires two main secrets to manage and access the database:

#### Superuser Secret (Required)

This secret contains the PostgreSQL superuser credentials that CloudNativePG uses to manage the cluster.
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: <cluster-name>  # Typically same as cluster name
  namespace: <namespace>
type: kubernetes.io/basic-auth
stringData:
  username: postgres
  password: "<backed-up-postgres-password>"
```

#### Application User Secret (For Applications)

This secret contains credentials for your application database user.
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: <cluster-name>-app
  namespace: <namespace>
type: kubernetes.io/basic-auth
stringData:
  username: <app-user>
  password: "<backed-up-app-password>"
  dbname: <database-name>
  host: <cluster-name>-rw.<namespace>.svc.cluster.local
  port: "5432"
  uri: "postgresql://<app-user>:<backed-up-app-password>@<cluster-name>-rw.<namespace>.svc.cluster.local:5432/<database-name>"
```

Apply the secrets:
```bash
kubectl apply -f superuser-secret.yaml
kubectl apply -f app-secret.yaml
```

### Step 4: Recreate the CloudNativePG Cluster

Apply your original cluster configuration:
```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: <cluster-name>
  namespace: <namespace>
spec:
  instances: 1
  imageName: ghcr.io/cloudnative-pg/postgresql:<version>
  
  storage:
    storageClass: <your-storage-class>
    size: <size>
  
  bootstrap:
    initdb:
      database: <database-name>
      owner: <app-user>
      secret:
        name: <cluster-name>
  
  # Your other configurations...
  postgresql:
    parameters:
      max_connections: "100"
      shared_buffers: "256MB"
```

Apply the cluster:
```bash
kubectl apply -f cluster.yaml
```

**Important:** CloudNativePG will detect existing data in the volume and use it instead of initializing a new database.

### Step 5: Verify Recovery

Check cluster status:
```bash
kubectl get cluster -n <namespace>
```

Check if pods are running:
```bash
kubectl get pods -n <namespace>
```

Verify data integrity:
```bash
kubectl exec -it <cluster-name>-1 -n <namespace> -- psql -U <app-user> -d <database-name> -c "\dt"
```

Connect and verify your data:
```bash
kubectl exec -it <cluster-name>-1 -n <namespace> -- psql -U <app-user> -d <database-name> -c "SELECT count(*) FROM <your-table>;"
```

## Important Notes

1. **PVC Naming Convention:** The PVC must be named `<cluster-name>-<instance-number>` (e.g., `postgres-1`) for CloudNativePG to recognize it.

2. **Password Consistency:** The passwords in the secrets must match the passwords stored in the restored PostgreSQL database.

3. **Secret Names:** 
   - Superuser secret is typically named same as the cluster
   - App secret is typically named `<cluster-name>-app`

4. **Node Affinity:** If using `dataLocality: "strict-local"` in your StorageClass, ensure the PVC can bind to the correct node where the data resides.

5. **Timing:** Create resources in this order:
   - Longhorn volume restoration
   - PVC creation and binding
   - Secrets
   - CloudNativePG cluster

## Backup Best Practices

### Regular Secret Backups

Export secrets regularly and store them securely:
```bash
# Backup all secrets in namespace
kubectl get secrets -n <namespace> <cluster-name> <cluster-name>-app -o yaml > db-secrets-$(date +%Y%m%d).yaml

# Clean up dynamic metadata
sed -i '/resourceVersion:/d' db-secrets-$(date +%Y%m%d).yaml
sed -i '/uid:/d' db-secrets-$(date +%Y%m%d).yaml
sed -i '/creationTimestamp:/d' db-secrets-$(date +%Y%m%d).yaml
```

### What to Back Up

For each database cluster, ensure you have:
- ✅ Longhorn volume backups (automated via recurring jobs)
- ✅ Secrets YAML (or at minimum: usernames and passwords)
- ✅ Cluster YAML configuration file
- ✅ Any custom ConfigMaps or additional resources

### Testing Recovery

Periodically test your recovery procedure in a non-production namespace to ensure:
- Backups are valid and restorable
- Secrets are correctly formatted
- Recovery documentation is up to date
- Recovery time objectives (RTO) are met

## Troubleshooting

### PVC Not Binding

If the PVC remains in `Pending` state:
```bash
kubectl describe pvc <pvc-name> -n <namespace>
```

Common issues:
- StorageClass doesn't match
- Volume size doesn't match
- Node affinity constraints preventing binding
- Restored Longhorn volume not available

### Pod Not Starting

If the CloudNativePG pod won't start:
```bash
kubectl describe pod <cluster-name>-1 -n <namespace>
kubectl logs <cluster-name>-1 -n <namespace>
```

Common issues:
- Secrets missing or incorrectly formatted
- PVC not bound
- Password mismatch between secret and database
- Insufficient resources

### Database Connection Issues

If you can connect to PostgreSQL but authentication fails:
- Verify the passwords in secrets match the database
- Check that the superuser secret is correctly named
- Ensure the app user exists in the restored database

### Data Missing After Recovery

If the pod starts but data is missing:
- Verify you restored the correct Longhorn backup
- Check that the PVC is bound to the correct restored volume
- Ensure the volume restoration completed successfully
