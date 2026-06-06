# Chapter 5 Labs: Storage

## Overview
Learn PV/PVC lifecycle, storage classes, volume snapshots.

---

## Lab 5.1: Dynamic PVC Provisioning

### Create PVC

Create `dynamic-pvc.yaml`:

```yaml
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
```

### Create Pod Using PVC

Create `pvc-pod.yaml`:

```yaml
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
```

### Verification

- [ ] PVC created and bound
- [ ] PV created automatically
- [ ] Pod writes data
- [ ] After delete and recreate, data persists

---

## Lab 5.2: StatefulSet with Storage

### Create StatefulSet

Create `postgres-statefulset.yaml`:

```yaml
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
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 500Mi
```

### Verification

- [ ] Pods created in order (postgres-0, postgres-1, postgres-2)
- [ ] PVCs created for each pod
- [ ] Data persists after pod deletion

---

## Lab 5.3: Volume Snapshots

Create volume snapshot for backup.

Create `snapshot.yaml`:

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: db-snapshot
spec:
  volumeSnapshotClassName: csi-snapclass
  source:
    persistentVolumeClaimName: postgres-pvc
```

---

## Lab 5.4: StorageClass Configuration

Create custom storage class.

Create `storage-class.yaml`:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3
  encrypted: "true"
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

---

## Completion Checklist

| Lab | Description | Status |
|-----|-------------|--------|
| 5.1 | Dynamic PVC | [ ] |
| 5.2 | StatefulSet Storage | [ ] |
| 5.3 | Volume Snapshots | [ ] |
| 5.4 | StorageClass | [ ] |
