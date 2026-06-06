# Chapter 1 Labs: Kubernetes Architecture

## Lab 1.1: High Availability Control Plane Setup

### Objective
Deploy a highly available control plane configuration.

### Production YAML
```yaml
# etcd-backup-cronjob.yaml
# Production-grade automated etcd backups
apiVersion: batch/v1
kind: CronJob
metadata:
  name: etcd-backup
  namespace: kube-system
spec:
  schedule: "0 */6 * * *"  # Every 6 hours
  timeZone: "UTC"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      template:
        metadata:
          annotations:
            backup-type: etcd-snapshot
        spec:
          hostNetwork: true
          nodeSelector:
            node-role.kubernetes.io/control-plane: ""
          tolerations:
          - key: node-role.kubernetes.io/control-plane
            operator: Exists
            effect: NoSchedule
          containers:
          - name: etcd-backup
            image: bitnami/etcd:3.5
            env:
            - name: ETCDCTL_API
              value: "3"
            command:
            - /bin/sh
            - -c
            - |
              TIMESTAMP=$(date +%Y%m%d-%H%M%S)
              BACKUP_FILE="/backup/etcd-snapshot-${TIMESTAMP}.db"
              
              echo "Starting etcd backup at $(date)"
              etcdctl snapshot save "${BACKUP_FILE}" \
                --endpoints=https://127.0.0.1:2379 \
                --cacert=/etc/kubernetes/pki/etcd/ca.crt \
                --cert=/etc/kubernetes/pki/etcd/server.crt \
                --key=/etc/kubernetes/pki/etcd/server.key
              
              if [ $? -eq 0 ]; then
                echo "Backup successful: ${BACKUP_FILE}"
                ls -lh "${BACKUP_FILE}"
                
                # Keep only last 10 backups
                cd /backup && ls -t etcd-snapshot-*.db | tail -n +11 | xargs -r rm
              else
                echo "Backup failed!"
                exit 1
              fi
            volumeMounts:
            - name: etcd-certs
              mountPath: /etc/kubernetes/pki/etcd
              readOnly: true
            - name: backup-storage
              mountPath: /backup
            resources:
              requests:
                memory: "256Mi"
                cpu: "100m"
              limits:
                memory: "512Mi"
                cpu: "500m"
            securityContext:
              runAsNonRoot: true
              runAsUser: 1000
              readOnlyRootFilesystem: true
          volumes:
          - name: etcd-certs
            hostPath:
              path: /etc/kubernetes/pki/etcd
              type: Directory
          - name: backup-storage
            persistentVolumeClaim:
              claimName: etcd-backup-pvc
          restartPolicy: OnFailure
          serviceAccountName: etcd-backup-sa
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: etcd-backup-pvc
  namespace: kube-system
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: fast-ssd  # Use fast storage for backups
  resources:
    requests:
      storage: 50Gi
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: etcd-backup-sa
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: etcd-backup-role
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: etcd-backup-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: etcd-backup-role
subjects:
- kind: ServiceAccount
  name: etcd-backup-sa
  namespace: kube-system
```

### Apply and Verify
```bash
# Apply all resources
kubectl apply -f etcd-backup-cronjob.yaml

# Verify CronJob created
kubectl get cronjob etcd-backup -n kube-system

# Trigger manual backup for testing
kubectl create job --from=cronjob/etcd-backup manual-backup -n kube-system

# Watch job completion
kubectl get jobs -n kube-system -w

# Check backup job logs
kubectl logs -n kube-system job/manual-backup

# Verify backup files exist
kubectl exec -n kube-system deploy/etcd-backup -- ls -la /backup/

# Clean up test job
kubectl delete job manual-backup -n kube-system
```

---

## Lab 1.2: API Server Monitoring

### Objective
Monitor API Server availability and performance.

### Production YAML
```yaml
# api-server-monitor.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: apiserver-monitor
  namespace: monitoring
  labels:
    app: apiserver-monitor
spec:
  replicas: 1
  selector:
    matchLabels:
      app: apiserver-monitor
  template:
    metadata:
      labels:
        app: apiserver-monitor
    spec:
      serviceAccountName: monitor-sa
      containers:
      - name: monitor
        image: bitnami/kubectl:latest
        command:
        - /bin/sh
        - -c
        - |
          while true; do
            START=$(date +%s%N)
            if kubectl get --raw /healthz > /dev/null 2>&1; then
              END=$(date +%s%N)
              LATENCY=$(( (END - START) / 1000000 ))
              echo "$(date '+%Y-%m-%d %H:%M:%S') API Server: HEALTHY (Latency: ${LATENCY}ms)"
            else
              echo "$(date '+%Y-%m-%d %H:%M:%S') API Server: UNHEALTHY"
            fi
            sleep 10
          done
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: monitor-sa
  namespace: monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: apiserver-monitor-role
rules:
- apiGroups: [""]
  resources: ["*"]
  verbs: ["get"]
- nonResourceURLs: ["/healthz", "/livez", "/readyz"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: apiserver-monitor-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: apiserver-monitor-role
subjects:
- kind: ServiceAccount
  name: monitor-sa
  namespace: monitoring
```

### Verification
```bash
kubectl apply -f api-server-monitor.yaml
kubectl logs -n monitoring deployment/apiserver-monitor -f
```

---

## Lab 1.3: Controller Manager Health Check

### Objective
Verify controller manager is functioning correctly.

### Production YAML
```yaml
# controller-health-check.yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: controller-test
  labels:
    test: controller-functionality
spec:
  replicas: 3
  selector:
    matchLabels:
      test: controller-test
  template:
    metadata:
      labels:
        test: controller-test
    spec:
      containers:
      - name: app
        image: nginx:alpine
        resources:
          requests:
            memory: "32Mi"
            cpu: "50m"
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 3
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: controller-test-svc
spec:
  selector:
    test: controller-test
  ports:
  - port: 80
```

### Verification Steps
```bash
# Apply the ReplicaSet
kubectl apply -f controller-health-check.yaml

# Verify 3 pods created by controller
kubectl get pods -l test=controller-test

# Delete one pod and verify controller recreates it
kubectl delete pod $(kubectl get pods -l test=controller-test -o jsonpath='{.items[0].metadata.name}')
kubectl get pods -l test=controller-test -w  # Watch recreation

# Scale up and verify controller responds
kubectl scale rs controller-test --replicas=5
kubectl get pods -l test=controller-test  # Should show 5 pods

# Verify endpoints populated by endpoint controller
kubectl get endpoints controller-test-svc

# Clean up
kubectl delete -f controller-health-check.yaml
```

---

## Lab 1.4: Scheduler Node Selection

### Objective
Understand scheduler node selection with production constraints.

### Production YAML
```yaml
# scheduler-test-pods.yaml
apiVersion: v1
kind: Pod
metadata:
  name: guaranteed-qos
  labels:
    qos: guaranteed
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
      limits:
        memory: "128Mi"
        cpu: "100m"
    livenessProbe:
      httpGet:
        path: /
        port: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: burstable-qos
  labels:
    qos: burstable
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    resources:
      requests:
        memory: "64Mi"
        cpu: "50m"
      limits:
        memory: "128Mi"
        cpu: "100m"
---
apiVersion: v1
kind: Pod
metadata:
  name: besteffort-qos
  labels:
    qos: besteffort
spec:
  containers:
  - name: nginx
    image: nginx:alpine
```

### Verification
```bash
kubectl apply -f scheduler-test-pods.yaml

# Check QoS assigned by scheduler
kubectl get pod guaranteed-qos -o jsonpath='{.status.qosClass}'  # Guaranteed
kubectl get pod burstable-qos -o jsonpath='{.status.qosClass}'    # Burstable
kubectl get pod besteffort-qos -o jsonpath='{.status.qosClass}'   # BestEffort

# Check which node each was scheduled on
kubectl get pods -o wide

# Describe to see scheduling events
kubectl describe pod guaranteed-qos | grep -A5 "Node-Selectors\|Node:\|QoS"
```

---

## Completion Checklist

| Lab | Description | Status |
|-----|-------------|--------|
| 1.1 | etcd Backup CronJob | [ ] |
| 1.2 | API Server Monitoring | [ ] |
| 1.3 | Controller Health Check | [ ] |
| 1.4 | Scheduler Node Selection | [ ] |
