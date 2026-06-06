# Chapter 3 Labs: Workloads & Controllers

## Lab 3.1: Create and Scale a Deployment

### Objective
Practice deployment creation and scaling.

### Exercise
```bash
# 1. Create deployment imperatively
kubectl create deployment web --image=nginx:alpine --replicas=3

# 2. Verify
kubectl get deployment web
kubectl get pods -l app=web

# 3. Scale up
kubectl scale deployment web --replicas=10

# 4. Watch scaling in action
kubectl get pods -l app=web -w
# Press Ctrl+C after seeing 10 pods

# 5. Scale down
kubectl scale deployment web --replicas=2
kubectl get pods -l app=web

# 6. Get deployment details
kubectl describe deployment web

# 7. Clean up
kubectl delete deployment web
```

### Solution Verification
```bash
# Check all replicas are running
echo "Checking replicas..."
REPLICAS=$(kubectl get deployment web -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [ "$REPLICAS" = "2" ]; then
  echo "✓ Deployment has 2 replicas"
else
  echo "✗ Expected 2 replicas, got $REPLICAS"
fi
```

---

## Lab 3.2: Rolling Update and Rollback

### Objective
Perform zero-downtime deployment and rollback.

### Exercise
```bash
# 1. Create initial deployment
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rolling-demo
spec:
  replicas: 5
  selector:
    matchLabels:
      app: rolling
  template:
    metadata:
      labels:
        app: rolling
        version: v1
    spec:
      containers:
      - name: nginx
        image: nginx:1.24-alpine
        ports:
        - containerPort: 80
EOF

# 2. Verify initial deployment
kubectl get deployment rolling-demo
kubectl get pods -l app=rolling

# 3. Trigger rolling update (change version)
kubectl set image deployment/rolling-demo nginx=nginx:1.25-alpine --record

# 4. Watch rollout progress
kubectl rollout status deployment/rolling-demo

# 5. Check rollout history
kubectl rollout history deployment/rolling-demo

# 6. Verify new version
kubectl get pods -l app=rolling -o jsonpath='{.items[0].spec.containers[0].image}'

# 7. Rollback to previous version
kubectl rollout undo deployment/rolling-demo

# 8. Verify rollback
kubectl rollout status deployment/rolling-demo
kubectl get pods -l app=rolling -o jsonpath='{.items[0].spec.containers[0].image}'

# 9. Check revision history
kubectl rollout history deployment/rolling-demo

# 10. Rollback to specific revision
kubectl rollout undo deployment/rolling-demo --to-revision=2

# 11. Clean up
kubectl delete deployment rolling-demo
```

### Expected Behavior
- Update: Pods replaced one by one, never below 4 available
- Image changes from 1.24 to 1.25
- Rollback: Returns to previous image

---

## Lab 3.3: Deployment Strategy Comparison

### Objective
Compare Recreate vs RollingUpdate strategies.

### Exercise

**RollingUpdate (default):**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rolling-strategy
spec:
  replicas: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  selector:
    matchLabels:
      app: rolling
  template:
    metadata:
      labels:
        app: rolling
    spec:
      containers:
      - name: app
        image: nginx:1.24-alpine
        ports:
        - containerPort: 80
```

```bash
kubectl apply -f rolling-deployment.yaml
kubectl set image deployment/rolling-strategy app=nginx:1.25-alpine
kubectl get pods -w
# Shows pods being replaced gradually
kubectl delete deployment rolling-strategy
```

**Recreate:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: recreate-strategy
spec:
  replicas: 5
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: recreate
  template:
    metadata:
      labels:
        app: recreate
    spec:
      containers:
      - name: app
        image: nginx:1.24-alpine
        ports:
        - containerPort: 80
```

```bash
kubectl apply -f recreate-deployment.yaml
kubectl set image deployment/recreate-strategy app=nginx:1.25-alpine
kubectl get pods -w
# Shows all pods terminating, then all new pods starting
kubectl delete deployment recreate-strategy
```

### Solution Key Differences
| Strategy | Behavior | Downtime |
|----------|----------|----------|
| RollingUpdate | Replace gradually | Zero |
| Recreate | Kill all, then create | Yes |

---

## Lab 3.4: Canary Deployment

### Objective
Implement canary deployment pattern.

### Exercise
```bash
# 1. Deploy stable version (90% traffic)
kubectl create deployment web-stable --image=nginx:1.24 --replicas=9

# 2. Deploy canary version (10% traffic)
kubectl create deployment web-canary --image=nginx:1.25 --replicas=1

# 3. Create service that routes to both (via common label)
# Add common label to stable
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  selector:
    app: web
  ports:
  - port: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-stable
spec:
  replicas: 9
  selector:
    matchLabels:
      app: web
      version: stable
  template:
    metadata:
      labels:
        app: web
        version: stable
    spec:
      containers:
      - name: nginx
        image: nginx:1.24
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-canary
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
      version: canary
  template:
    metadata:
      labels:
        app: web
        version: canary
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
EOF

# 4. Test accessing the service
kubectl run test --rm -i --restart=Never --image=busybox -- wget -qO- http://web

# 5. Increase canary traffic to 50%
kubectl scale deployment web-stable --replicas=5
kubectl scale deployment web-canary --replicas=5

# 6. Monitor - test multiple times
for i in {1..10}; do
  kubectl run test$i --rm -i --restart=Never --image=busybox -- wget -qO- http://web 2>/dev/null | head -1
done

# 7. Full rollout (100% on canary)
kubectl scale deployment web-stable --replicas=0
kubectl scale deployment web-canary --replicas=10

# 8. Clean up
kubectl delete deployment web-stable web-canary
kubectl delete service web
```

### Solution
Canary deployment gradually shifts traffic to new version:
- 90/10 → 50/50 → 0/100
- Can rollback if issues detected at any stage

---

## Lab 3.5: DaemonSet Lab

### Objective
Deploy a pod on every node.

### Exercise
```bash
# 1. Create DaemonSet
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-logger
spec:
  selector:
    matchLabels:
      app: logger
  template:
    metadata:
      labels:
        app: logger
    spec:
      containers:
      - name: logger
        image: busybox
        command: ['sh', '-c', 'while true; do date; sleep 10; done']
        resources:
          requests:
            memory: "16Mi"
            cpu: "10m"
EOF

# 2. Verify - one pod per node
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
POD_COUNT=$(kubectl get pods -l app=logger --no-headers | wc -l)
echo "Nodes: $NODE_COUNT, Pods: $POD_COUNT"

# 3. Check pod distribution
kubectl get pods -l app=logger -o wide

# 4. Add taints to control-plane, add toleration if needed
kubectl describe ds node-logger | grep -A20 "Node-Selectors"

# 5. Clean up
kubectl delete daemonset node-logger
```

### Solution
- DaemonSet creates exactly 1 pod per node
- Automatically adds new pods when nodes join
- Removes pods when nodes leave

---

## Lab 3.6: Jobs and CronJobs

### Objective
Run batch jobs and scheduled tasks.

### Exercise

**One-time Job:**
```bash
# Create job
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: data-process
spec:
  template:
    spec:
      containers:
      - name: processor
        image: busybox
        command: ['sh', '-c', 'echo Processing...; sleep 10; echo Done!']
      restartPolicy: OnFailure
EOF

# Watch completion
kubectl get jobs -w
kubectl logs job/data-process

# Check status
kubectl get job data-process -o jsonpath='{.status.succeeded}'

# Clean up
kubectl delete job data-process
```

**Parallel Job:**
```bash
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: parallel-batch
spec:
  completions: 10
  parallelism: 3
  template:
    spec:
      containers:
      - name: worker
        image: busybox
        command: ['sh', '-c', 'echo Worker $(hostname) started; sleep 5; echo Done']
      restartPolicy: OnFailure
EOF

# Watch parallel execution
kubectl get pods -l job-name=parallel-batch -w

# Verify all completed
kubectl get job parallel-batch
kubectl logs -l job-name=parallel-batch

kubectl delete job parallel-batch
```

**CronJob:**
```bash
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: hello-cron
spec:
  schedule: "*/1 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: hello
            image: busybox
            command: ['sh', '-c', 'echo Hello from CronJob at $(date)']
          restartPolicy: OnFailure
EOF

# Watch cronjob create jobs
sleep 65
kubectl get jobs
kubectl logs -l job-name=hello-cron

# View cronjob
kubectl get cronjobs
kubectl delete cronjob hello-cron
```

---

## Lab 3.7: StatefulSet Lab

### Objective
Deploy stateful application with persistent storage.

### Exercise
```bash
# 1. Create headless service
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: postgres-headless
spec:
  clusterIP: None
  selector:
    app: postgres
  ports:
  - port: 5432
EOF

# 2. Create StatefulSet
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres-headless
  replicas: 2
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
          value: password123
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
EOF

# 3. Watch ordered pod creation (postgres-0 before postgres-1)
kubectl get pods -l app=postgres -w

# 4. Verify PVCs created for each pod
kubectl get pvc
# Shows: data-postgres-0, data-postgres-1

# 5. Test pod identity
echo "Pod hostnames:"
kubectl exec postgres-0 -- hostname
kubectl exec postgres-1 -- hostname

# 6. Each pod has stable network identity
# postgres-0.postgres-headless.default.svc.cluster.local

# 7. Delete pod and verify it comes back with same identity
kubectl delete pod postgres-0
kubectl get pods -l app=postgres -w
# pod-0 comes back, reattaches to same PVC

# 8. Scale up (ordered creation)
kubectl scale sts postgres --replicas=3
kubectl get pods -l app=postgres -w
# postgres-2 starts only after postgres-0 and postgres-1 are ready

# 9. Clean up (reverse order deletion)
kubectl delete sts postgres
kubectl delete service postgres-headless
kubectl delete pvc data-postgres-0 data-postgres-1 data-postgres-2
```

### Solution Key Points
- Ordered pod creation: pod-0, then pod-1, then pod-2
- Each pod has unique PVC and identity
- Stable network identity with headless service
- Ordered deletion: pod-2, then pod-1, then pod-0

---

## Completion Checklist for Chapter 3

| Lab | Description | Status |
|-----|-------------|--------|
| 3.1 | Create and scale deployment | [ ] |
| 3.2 | Rolling update and rollback | [ ] |
| 3.3 | Deployment strategies | [ ] |
| 3.4 | Canary deployment | [ ] |
| 3.5 | DaemonSet | [ ] |
| 3.6 | Jobs and CronJobs | [ ] |
| 3.7 | StatefulSet | [ ] |
