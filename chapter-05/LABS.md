# Chapter 5 Labs: Storage

## Lab 5.1: Production Database Storage

### Objective
Deploy production-grade database with backup and restore.

### Production YAML
```yaml
# production-database-storage.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-primary-pvc
  namespace: production
spec:
  storageClassName: fast-ssd
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
  volumeMode: Filesystem
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-wal-pvc
  namespace: production
spec:
  storageClassName: ultra-fast-ssd
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres-primary
  namespace: production
spec:
  serviceName: postgres-primary
  replicas: 1
  selector:
    matchLabels:
      app: postgres-primary
  template:
    metadata:
      labels:
        app: postgres-primary
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        - name: POSTGRES_INITDB_ARGS
          value: "--auth-host=scram-sha-256"
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
        - name: wal
          mountPath: /var/lib/postgresql/wal
        - name: backups
          mountPath: /backups
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
          limits:
            memory: "4Gi"
            cpu: "2000m"
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - postgres
          initialDelaySeconds: 30
          periodSeconds: 10
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: postgres-primary-pvc
      - name: wal
        persistentVolumeClaim:
          claimName: postgres-wal-pvc
      - name: backups
        persistentVolumeClaim:
          claimName: postgres-backup-pvc
```

---

## Lab 5.2: Shared Storage with RWX

### Objective
Configure ReadWriteMany storage for shared data.

### Production YAML
```yaml
# shared-storage-nfs.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-content
  namespace: production
spec:
  storageClassName: nfs-client
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 500Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: content-publisher
  namespace: production
spec:
  replicas: 1
  selector:
    matchLabels:
      app: publisher
  template:
    metadata:
      labels:
        app: publisher
    spec:
      containers:
      - name: publisher
        image: nginx:alpine
        volumeMounts:
        - name: shared
          mountPath: /usr/share/nginx/html
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
      volumes:
      - name: shared
        persistentVolumeClaim:
          claimName: shared-content
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: content-consumers
  namespace: production
spec:
  replicas: 5
  selector:
    matchLabels:
      app: consumer
  template:
    metadata:
      labels:
        app: consumer
    spec:
      containers:
      - name: consumer
        image: nginx:alpine
        volumeMounts:
        - name: shared
          mountPath: /usr/share/nginx/html
          readOnly: true
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
      volumes:
      - name: shared
        persistentVolumeClaim:
          claimName: shared-content
          readOnly: true
```

---

## Lab 5.3: Volume Snapshots

### Objective
Create and restore volume snapshots.

### Production YAML
```yaml
# volume-snapshot.yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: csi-snapclass
driver: csi-driver
deletionPolicy: Retain
---
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: postgres-snapshot
  namespace: production
spec:
  volumeSnapshotClassName: csi-snapclass
  source:
    persistentVolumeClaimName: postgres-primary-pvc
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-restore
  namespace: production
spec:
  storageClassName: fast-ssd
  dataSource:
    name: postgres-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
```

---

## Completion Checklist

| Lab | Description | Status |
|-----|-------------|--------|
| 5.1 | Production Database Storage | [ ] |
| 5.2 | Shared RWX Storage | [ ] |
| 5.3 | Volume Snapshots | [ ] |
