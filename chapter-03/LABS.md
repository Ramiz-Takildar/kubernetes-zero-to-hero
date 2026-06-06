# Chapter 3 Labs: Workloads & Controllers

## Overview

These labs cover Deployments, StatefulSets, DaemonSets, Jobs, and CronJobs. You'll learn production patterns like rolling updates, blue-green deployments, and automated backups.

**Prerequisites:** kubectl configured, understanding of Pods from Chapter 2

---

## Lab 3.1: Production Deployment with Rolling Update

### Learning Objectives
- Create a production-ready Deployment
- Perform rolling updates with zero downtime
- Configure health probes for update safety

### Theory

**Rolling Update Strategy:**
- Gradually replaces old pods with new ones
- Configurable maxUnavailable and maxSurge
- Maintains application availability during updates

**Why health probes matter:**
- Readiness probe ensures pod is ready before receiving traffic
- Liveness probe ensures pod is restarted if unhealthy
- Without probes, Deployment might mark unhealthy pods as "available"

### Part A: Create the Deployment

Create `production-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  labels:
    app: web
    version: "1.0"
spec:
  replicas: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1    # Only 1 pod down during update
      maxSurge: 1         # Only 1 extra pod during update
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:1.24-alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
```

Apply it:
```bash
kubectl apply -f production-deployment.yaml
```

### Part B: Verify Deployment

```bash
# Check deployment status
kubectl get deployment web-app

# Check all pods are running
kubectl get pods -l app=web

# Check replica sets
kubectl get rs -l app=web

# Describe for details
kubectl describe deployment web-app
```

### Part C: Perform Rolling Update

```bash
# Trigger update to new version
kubectl set image deployment/web-app nginx=nginx:1.25-alpine

# Watch the rolling update
kubectl rollout status deployment/web-app

# Or watch pods being replaced
kubectl get pods -l app=web -w
```

**Observe:**
- New pods created gradually
- Old pods terminated gradually
- Always at least 4 pods available (5 replicas - 1 maxUnavailable)
- Never more than 6 pods (5 replicas + 1 maxSurge)

### Part D: Check Rollout History

```bash
# View revision history
kubectl rollout history deployment/web-app

# View details of specific revision
kubectl rollout history deployment/web-app --revision=1
kubectl rollout history deployment/web-app --revision=2
```

### Part E: Rollback

```bash
# Rollback to previous version
kubectl rollout undo deployment/web-app

# Verify rollback
kubectl rollout status deployment/web-app
kubectl get pods -l app=web

# Rollback to specific revision
kubectl rollout undo deployment/web-app --to-revision=1
```

### Verification Checklist

- [ ] Deployment created with 5 replicas
- [ ] All pods pass readiness probes
- [ ] Rolling update completed successfully
- [ ] Rollback works correctly

### Cleanup

```bash
kubectl delete -f production-deployment.yaml
rm -f production-deployment.yaml
```

---

## Lab 3.2: Blue-Green Deployment

### Learning Objectives
- Implement blue-green deployment pattern
- Switch traffic instantly between versions
- Practice instant rollback

### Theory

**Blue-Green Pattern:**
```
Initially:
  Service ──► Blue (v1.0) [Active]
              Green (v2.0) [Idle]

Switch:
  Service ──► Green (v2.0) [Active]
              Blue (v1.0) [Idle/Rollback-ready]
```

**Benefits:**
- Instant switch (zero downtime)
- Instant rollback (switch back to Blue)
- Full testing of Green before switch

### Part A: Create Blue Deployment

Create `blue-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-blue
  labels:
    app: web
    version: blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
      version: blue
  template:
    metadata:
      labels:
        app: web
        version: blue
    spec:
      containers:
      - name: nginx
        image: nginx:1.24-alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
```

```bash
kubectl apply -f blue-deployment.yaml
```

### Part B: Create Service Pointing to Blue

Create `blue-green-service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  selector:
    app: web
    version: blue  # Currently pointing to blue
  ports:
  - port: 80
    targetPort: 80
```

```bash
kubectl apply -f blue-green-service.yaml
```

### Part C: Test Blue

```bash
kubectl run test --rm -i --restart=Never --image=busybox -- \
  wget -qO- http://web | head
```

You should see nginx 1.24 welcome page.

### Part D: Create Green Deployment

Create `green-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-green
  labels:
    app: web
    version: green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
      version: green
  template:
    metadata:
      labels:
        app: web
        version: green
    spec:
      containers:
      - name: nginx
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
```

```bash
kubectl apply -f green-deployment.yaml
```

### Part E: Test Green (Direct Access)

```bash
# Create temporary service for green
kubectl expose deployment app-green --name=green-preview --port=80

# Test green
kubectl run test --rm -i --restart=Never --image=busybox -- \
  wget -qO- http://green-preview | head

kubectl delete service green-preview
```

### Part F: Switch Traffic to Green

```bash
# Patch service to point to green
kubectl patch service web -p '{"spec":{"selector":{"version":"green"}}}'

# Verify
kubectl run test --rm -i --restart=Never --image=busybox -- \
  wget -qO- http://web | head
```

Now you should see nginx 1.25 content.

### Part G: Instant Rollback

```bash
# Switch back to blue
kubectl patch service web -p '{"spec":{"selector":{"version":"blue"}}}'

# Verify rollback
kubectl run test --rm -i --restart=Never --image=busybox -- \
  wget -qO- http://web | head
```

### Verification Checklist

- [ ] Blue deployment running v1.24
- [ ] Service points to blue initially
- [ ] Green deployment running v1.25
- [ ] Traffic switch works instantly
- [ ] Rollback to blue works instantly

### Cleanup

```bash
kubectl delete -f blue-deployment.yaml
kubectl delete -f green-deployment.yaml
kubectl delete -f blue-green-service.yaml
rm -f blue-deployment.yaml green-deployment.yaml blue-green-service.yaml
```

---

## Lab 3.3: StatefulSet with Persistent Storage

### Learning Objectives
- Deploy a StatefulSet with ordered pod creation
- Observe PVC generation per pod
- Test data persistence across pod deletion

### Theory

**StatefulSet characteristics:**
- Stable, unique network identifiers (pod-0, pod-1, pod-2)
- Stable persistent storage (separate PVC per pod)
- Ordered deployment and scaling
- Ordered automated rolling updates

**Use cases:** Databases, message queues, distributed systems

### Part A: Create Headless Service

Create `redis-headless-service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: redis
  labels:
    app: redis
spec:
  ports:
  - port: 6379
    name: redis
  clusterIP: None  # Headless service
  selector:
    app: redis
```

### Part B: Create StatefulSet

Create `redis-statefulset.yaml`:

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
spec:
  serviceName: redis
  replicas: 3
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
        volumeMounts:
        - name: data
          mountPath: /data
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
```

Apply both:
```bash
kubectl apply -f redis-headless-service.yaml
kubectl apply -f redis-statefulset.yaml
```

### Part C: Observe Ordered Creation

```bash
# Watch pods being created in order
kubectl get pods -l app=redis -w
```

**Expected sequence:**
1. `redis-0` created and running
2. `redis-1` created and running
3. `redis-2` created and running

StatefulSets create pods sequentially and wait for each to be ready.

### Part D: Verify PVCs Created

```bash
kubectl get pvc
```

**Expected output:**
```
NAME             STATUS   VOLUME
data-redis-0     Bound    pvc-xxxx
data-redis-1     Bound    pvc-yyyy
data-redis-2     Bound    pvc-zzzz
```

Each pod gets its own PVC.

### Part E: Write Data to redis-0

```bash
# Write data
kubectl exec redis-0 -- redis-cli SET mykey "hello-world"

# Verify
kubectl exec redis-0 -- redis-cli GET mykey
```

### Part F: Delete Pod and Verify Persistence

```bash
# Delete redis-0
kubectl delete pod redis-0

# Watch recreation
kubectl get pods -l app=redis -w
```

**Observe:** Pod recreated with same name, same PVC attached.

```bash
# Verify data persisted
kubectl exec redis-0 -- redis-cli GET mykey
# Should return: "hello-world"
```

### Part G: Test Ordered Termination

```bash
# Scale down
kubectl scale statefulset redis --replicas=2

# Watch termination order (reverse)
kubectl get pods -l app=redis -w
```

**Expected:** redis-2 terminated first, then redis-1 (reverse order of creation).

### Verification Checklist

- [ ] Pods created in order: redis-0, redis-1, redis-2
- [ ] 3 PVCs created: data-redis-0, data-redis-1, data-redis-2
- [ ] Data written to redis-0
- [ ] After deletion, data persisted in recreated pod
- [ ] Scale-down followed reverse order

### Cleanup

```bash
kubectl delete statefulset redis
kubectl delete service redis
kubectl delete pvc data-redis-0 data-redis-1 data-redis-2
rm -f redis-headless-service.yaml redis-statefulset.yaml
```

---

## Lab 3.4: CronJob for Automated Backups

### Learning Objectives
- Create a CronJob for scheduled tasks
- Configure concurrency policy
- View job history

### Theory

**CronJob:** Runs Jobs on a schedule (like Linux cron).

**Use cases:** Backups, cleanup tasks, reporting, batch processing.

**Key settings:**
- `schedule`: Cron expression
- `concurrencyPolicy`: Allow/Forbid/Replace
- `successfulJobsHistoryLimit`: How many successful jobs to keep
- `failedJobsHistoryLimit`: How many failed jobs to keep

### Part A: Create Backup CronJob

Create `backup-cronjob.yaml`:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: database-backup
spec:
  schedule: "*/5 * * * *"  # Every 5 minutes (for testing)
  concurrencyPolicy: Forbid  # Don't start if previous still running
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      ttlSecondsAfterFinished: 3600  # Clean up after 1 hour
      template:
        metadata:
          labels:
            job-type: backup
        spec:
          restartPolicy: OnFailure
          containers:
          - name: backup
            image: busybox
            command:
            - /bin/sh
            - -c
            - |
              echo "Starting backup at $(date)"
              echo "Backup process would run here..."
              echo "Creating backup file..."
              sleep 10
              echo "Backup completed at $(date)"
            resources:
              requests:
                memory: "64Mi"
                cpu: "50m"
```

```bash
kubectl apply -f backup-cronjob.yaml
```

### Part B: Verify CronJob Created

```bash
kubectl get cronjob database-backup

# Output:
# NAME              SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE
# database-backup   */5 * * * *   False     0        <none>
```

### Part C: Wait and Check Jobs

```bash
# Wait 5 minutes, then check
kubectl get jobs -l job-type=backup

# View job details
kubectl describe job <job-name>

# View logs
kubectl logs -l job-type=backup
```

### Part D: Manual Trigger

```bash
# Create job from cronjob manually
kubectl create job --from=cronjob/database-backup manual-backup

# Check
kubectl get jobs
kubectl logs job/manual-backup
```

### Part E: View CronJob History

```bash
# List jobs created by cronjob
kubectl get jobs -l job-type=backup --sort-by=.metadata.creationTimestamp

# Describe cronjob for events
kubectl describe cronjob database-backup
```

### Verification Checklist

- [ ] CronJob created with schedule
- [ ] Job created automatically after schedule time
- [ ] Manual trigger works
- [ ] Logs show backup process
- [ ] Old jobs cleaned up based on history limits

### Cleanup

```bash
kubectl delete cronjob database-backup
kubectl delete jobs -l job-type=backup
rm -f backup-cronjob.yaml
```

---

## Completion Checklist

| Lab | Description | Status |
|-----|-------------|--------|
| 3.1 | Production Deployment with Rolling Update | [ ] |
| 3.2 | Blue-Green Deployment | [ ] |
| 3.3 | StatefulSet with Storage | [ ] |
| 3.4 | CronJob for Backups | [ ] |

**Mark complete in [CHECKLIST.md](../CHECKLIST.md)**
