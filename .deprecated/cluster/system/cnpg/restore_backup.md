# PostgreSQL CNPG Cluster Restoration Guide (Longhorn + Option A)

## Prerequisites
- Longhorn backup of the PostgreSQL PVC exists
- Secrets are backed up (see step 1 below)

## Restoration Steps

### 1. Backup Secrets (Do this NOW, before disaster strikes)
```bash
# Export critical secrets
kubectl get secret -n umami postgres-superuser -o yaml > postgres-superuser-backup.yaml
kubectl get secret -n umami postgres-app -o yaml > postgres-app-backup.yaml
```

**Store these files securely** (encrypted git repo, password manager, etc.)

### 2. When Disaster Strikes - Save Current Secrets
```bash
# If cluster still exists, export current secrets
kubectl get secret -n umami postgres-superuser -o yaml > /tmp/postgres-superuser.yaml
kubectl get secret -n umami postgres-app -o yaml > /tmp/postgres-app.yaml
```

### 3. Delete the CNPG Cluster (Keeps PVC)
```bash
kubectl delete cluster postgres -n umami
```

**Verify PVC still exists:**
```bash
kubectl get pvc -n umami
```

### 4. Restore Longhorn Backup to Original PVC

Using Longhorn UI:
1. Navigate to **Backup** section
2. Find your PostgreSQL backup
3. Click **Restore**
4. Set PVC name to: `postgres-1`
5. Set namespace to: `umami`
6. Click **OK**

Or using kubectl (if using VolumeSnapshot):
```bash
# Delete the old PVC first
kubectl delete pvc postgres-1 -n umami

# Create PVC from snapshot
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-1
  namespace: umami
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn-pg
  dataSource:
    name: <your-snapshot-name>
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  resources:
    requests:
      storage: 2Gi
EOF
```

### 5. Restore Secrets BEFORE Recreating Cluster
```bash
kubectl apply -f /tmp/postgres-superuser.yaml
kubectl apply -f /tmp/postgres-app.yaml
```

Or from your backed-up files:
```bash
kubectl apply -f postgres-superuser-backup.yaml
kubectl apply -f postgres-app-backup.yaml
```

### 6. Recreate the CNPG Cluster
```bash
kubectl apply -f postgres-cluster.yaml
```

The cluster will:
- Reuse the existing `postgres-1` PVC with restored data
- Reuse the existing secrets with correct credentials
- Start PostgreSQL with recovered data

### 7. Verify Restoration
```bash
# Check cluster status
kubectl get cluster -n umami

# Check pod is running
kubectl get pods -n umami

# Verify database connectivity
kubectl exec -it postgres-1 -n umami -- psql -U postgres -d umami -c "SELECT version();"

# Check your data exists
kubectl exec -it postgres-1 -n umami -- psql -U umami -d umami -c "SELECT COUNT(*) FROM <your-table>;"
```

## Recovery Without Secret Backups (Emergency Option)

If you lost the secret backups, you'll need to update PostgreSQL passwords manually:

1. Complete steps 3-4 above
2. Skip step 5 (let CNPG generate new secrets)
3. Recreate cluster (step 6)
4. Update passwords in PostgreSQL to match new secrets:
```bash
# Get new passwords from generated secrets
NEW_SUPERUSER_PASS=$(kubectl get secret postgres-superuser -n umami -o jsonpath='{.data.password}' | base64 -d)
NEW_APP_PASS=$(kubectl get secret postgres-app -n umami -o jsonpath='{.data.password}' | base64 -d)

# Update PostgreSQL passwords
kubectl exec -it postgres-1 -n umami -- psql -U postgres -c "ALTER USER postgres PASSWORD '$NEW_SUPERUSER_PASS';"
kubectl exec -it postgres-1 -n umami -- psql -U postgres -c "ALTER USER umami PASSWORD '$NEW_APP_PASS';"
```

## Notes

- Longhorn backups are crash-consistent; PostgreSQL will recover using WAL files
- The cluster name must match for PVC binding (`postgres` in this case)
