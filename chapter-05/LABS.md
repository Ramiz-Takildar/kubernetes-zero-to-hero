# Chapter 5 Labs: Storage

## Lab 5.1: Static vs Dynamic Provisioning

### Objective
Understand PV/PVC binding and storage classes.

### Exercise
```bash
# 1. Check available storage classes
kubectl get storageclass

# 2. Check if there's a default SC
kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}'

# 3. Create PVC (dynamic provisioning)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dynamic-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

# 4. Watch PVC bind
kubectl get pvc dynamic-pvc -w
# Should show: Pending -> Bound

# 5. Check PV was created dynamically
kubectl get pv | grep dynamic-pvc

# 6. Create pod using PVC
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: pvc-test
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'date > /data/timestamp.txt; cat /data/timestamp.txt; sleep 3600']
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: dynamic-pvc
EOF

# 7. Verify data written
kubectl logs pvc-test

# 8. Delete pod and recreate - verify persistence
kubectl delete pod pvc-test
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: pvc-reader
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'cat /data/timestamp.txt; sleep 3600']
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: dynamic-pvc
EOF

# 9. Verify data persisted
kubectl logs pvc-reader

# 10. Clean up
kubectl delete pod pvc-reader
kubectl delete pvc dynamic-pvc
```

---

## Lab 5.2: StatefulSet with Persistent Storage

### Objective
Deploy database with per-pod storage.

### Exercise
```bash
# 1. Create headless service
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: postgres
  labels:
    app: postgres
spec:
  ports:
  - port: 5432
    name: postgres
  clusterIP: None
  selector:
    app: postgres
EOF

# 2. Create StatefulSet with PVC template
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres
  replicas: 3
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        env:
        - name: POSTGRES_PASSWORD
          value: password
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: pgdata
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: pgdata
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 500Mi
EOF

# 3. Watch ordered pod creation with PVCs
kubectl get pods -l app=postgres -w

# 4. Verify PVCs created
kubectl get pvc
# Shows: pgdata-postgres-0, pgdata-postgres-1, pgdata-postgres-2

# 5. Write data to postgres-0
kubectl exec postgres-0 -- psql -U postgres -c "CREATE TABLE test (id int); INSERT INTO test VALUES (1);"

# 6. Delete postgres-0 and verify data persists
kubectl delete pod postgres-0
kubectl get pods -l app=postgres -w
kubectl exec postgres-0 -- psql -U postgres -c "SELECT * FROM test;"

# 7. Scale down and up - verify ordered behavior
kubectl scale sts postgres --replicas=2
kubectl get pods -l app=postgres -w
# postgres-2 deleted first

kubectl scale sts postgres --replicas=3
kubectl get pods -l app=postgres -w
# postgres-2 created last

# 8. Clean up
kubectl delete sts postgres
kubectl delete svc postgres
kubectl delete pvc pgdata-postgres-0 pgdata-postgres-1 pgdata-postgres-2
```

---

## Lab 5.3: Volume Types Comparison

### Objective
Compare emptyDir, hostPath, and PVC volumes.

### Exercise

**emptyDir:**
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: emptydir-test
spec:
  containers:
  - name: writer
    image: busybox
    command: ['sh', '-c', 'echo Data > /cache/file.txt; sleep 3600']
    volumeMounts:
    - name: cache
      mountPath: /cache
  - name: reader
    image: busybox
    command: ['sh', '-c', 'cat /cache/file.txt; sleep 3600']
    volumeMounts:
    - name: cache
      mountPath: /cache
  volumes:
  - name: cache
    emptyDir: {}
EOF

kubectl exec emptydir-test -c reader -- cat /cache/file.txt
kubectl delete pod emptydir-test
# Data lost after pod deletion
```

**hostPath:**
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: hostpath-test
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'echo NodeData > /host/data.txt; cat /host/data.txt; sleep 3600']
    volumeMounts:
    - name: nodedata
      mountPath: /host
  volumes:
  - name: nodedata
    hostPath:
      path: /tmp/k8s-data
      type: DirectoryOrCreate
  nodeSelector:
    kubernetes.io/os: linux
EOF

kubectl logs hostpath-test
kubectl delete pod hostpath-test
# Data persists on node at /tmp/k8s-data
# But pod will only schedule on same node
kubectl delete pod hostpath-test --force
```

**Summary:**
| Volume | Persistence | Use Case |
|--------|-------------|----------|
| emptyDir | Pod lifetime | Shared cache, temp files |
| hostPath | Node lifetime | Access node files/logs |
| PVC | Persistent | Databases, user data |

---

## Lab 5.4: Storage Class Parameters

### Objective
Understand storage class configuration.

### Exercise
```bash
# 1. View existing storage classes
kubectl get storageclass -o yaml

# 2. Create custom storage class
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-storage
provisioner: kubernetes.io/aws-ebs  # Adjust for your provider
parameters:
  type: gp3
  encrypted: "true"
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF

# 3. Create PVC with specific storage class
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: fast-pvc
spec:
  storageClassName: fast-storage
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
EOF

# 4. Check reclaim policy
kubectl get pvc fast-pvc -o jsonpath='{.spec.storageClassName}'

# 5. Clean up
kubectl delete pvc fast-pvc
kubectl delete storageclass fast-storage
```

---

## Completion Checklist for Chapter 5

| Lab | Description | Status |
|-----|-------------|--------|
| 5.1 | Dynamic PVC provisioning | [ ] |
| 5.2 | StatefulSet with storage | [ ] |
| 5.3 | Volume types comparison | [ ] |
| 5.4 | Storage class parameters | [ ] |
