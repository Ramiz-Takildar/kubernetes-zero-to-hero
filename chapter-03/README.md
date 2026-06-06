# Chapter 3: Workloads & Controllers

## 📚 Learning Objectives

By the end of this chapter, you will:
- Understand all workload controllers
- Perform rolling updates and rollbacks
- Scale applications
- Implement different deployment strategies

**Estimated Time:** 3 days

---

## 3.1 ReplicaSet

Ensures a specified number of pod replicas are running.

### Why Deployments are Preferred

**Deployment** manages **ReplicaSet** which manages **Pods**

```
User
  ↓
Deployment (declarative updates)
  ↓
ReplicaSet (ensures replica count)
  ↓
Pods (actual workload)
```

**Rule of thumb:** Always use Deployments, never ReplicaSets directly.

---

## 3.2 Deployment

**Manages declarative updates to applications**

### Deployment Strategies

| Strategy | How it Works | Use Case |
|----------|--------------|----------|
| **RollingUpdate** | Gradually replace pods | Default, zero downtime |
| **Recreate** | Kill all, then create new | Maintenance windows |

### RollingUpdate Parameters

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 1    # Max pods DOWN during update
    maxSurge: 1         # Max pods ABOVE desired during update
```

**Example scenario (5 replicas, maxUnavailable=1, maxSurge=1):**
```
Step 1: 5 old pods running
Step 2: 1 new pod created (total: 5 old + 1 new = 6)
Step 3: 1 old pod removed (total: 4 old + 1 new = 5)
Step 4: Repeat until all pods are new
```

---

## 3.3 Updates and Rollbacks

### Update Commands

```bash
# Update image
kubectl set image deployment/myapp container=newimage:tag

# Update replica count
kubectl scale deployment/myapp --replicas=10

# Edit live deployment
kubectl edit deployment/myapp

# Rolling restart
kubectl rollout restart deployment/myapp
```

### Rollback Commands

```bash
# Check revision history
kubectl rollout history deployment/myapp

# Rollback to previous version
kubectl rollout undo deployment/myapp

# Rollback to specific revision
kubectl rollout undo deployment/myapp --to-revision=2

# Pause rollout
kubectl rollout pause deployment/myapp

# Resume rollout
kubectl rollout resume deployment/myapp

# Watch rollout status
kubectl rollout status deployment/myapp
```

---

## 3.4 Advanced Deployment Patterns

### Blue-Green Deployment

```
Active (Blue)        Inactive (Green)
┌──────────┐         ┌──────────┐
│ v1.0     │ ←────── │ v2.0     │
│ Running  │         │ Ready    │
└──────────┘         └──────────┘
        ↑
   Users here
```

**Process:**
1. Deploy v2.0 alongside v1.0
2. Test v2.0
3. Switch Service selector to v2.0
4. Rollback: switch back to v1.0

### Canary Deployment

```
Service
  ├── 90% → v1.0 Pods (Blue)
  └── 10% → v2.0 Pods (Green)
```

**Process:**
1. Deploy small % of v2.0
2. Monitor metrics
3. Gradually increase v2.0 %
4. Full rollout if successful

---

## ❓ Interview Questions (20)

### Q1: What is the difference between Deployment and ReplicaSet?

**Answer:**

| Aspect | Deployment | ReplicaSet |
|--------|------------|------------|
| **Purpose** | Manages updates | Maintains replica count |
| **Updates** | Declarative, versioned | No native update strategy |
| **Rollback** | Native support | Manual |
| **History** | Revision history | None |
| **Relationship** | Manages ReplicaSets | Managed by Deployment |
| **Use** | Production apps | Rarely used directly |

Deployment is the higher-level abstraction you should use.

---

### Q2: Explain RollingUpdate strategy

**Answer:**
Gradually replaces old pods with new ones for zero-downtime updates.

**Parameters:**
- `maxUnavailable`: Max pods that can be unavailable during update
- `maxSurge`: Max pods that can exist above desired count

**Example:** 10 replicas, maxUnavailable=2, maxSurge=2
- Update starts
- 2 new pods created (12 total)
- 2 old pods removed (10 total)
- Repeat until done
- At least 8 pods always available

---

### Q3: How do you rollback a deployment?

**Answer:**

```bash
# View revision history
kubectl rollout history deployment/myapp

# Rollback to previous
kubectl rollout undo deployment/myapp

# Rollback to specific revision
kubectl rollout undo deployment/myapp --to-revision=3
```

**What happens:**
- Creates new ReplicaSet with old pod spec
- Scales down new ReplicaSet
- Scales up old ReplicaSet
- Updates Deployment resource

---

### Q4: What is the difference between maxUnavailable and maxSurge?

**Answer:**

| Parameter | Controls | Effect |
|-----------|----------|--------|
| **maxUnavailable** | How many pods CAN be down | Lower = safer but slower |
| **maxSurge** | How many EXTRA pods can exist | Higher = faster but more resources |

**Can be percentages or absolute numbers:**
```yaml
maxUnavailable: 25%    # 25% of replicas
maxSurge: 2           # Absolute count
```

---

### Q5: When would you use a DaemonSet?

**Answer:**
When you need **exactly one pod per node**.

**Use cases:**
- Log collectors (Fluentd, Filebeat)
- Node monitors (Prometheus node-exporter)
- Network proxies
- Storage daemons

**Not for:** Applications that need centralized deployment (use Deployment).

---

### Q6: What is the difference between StatefulSet and Deployment?

**Answer:**

| Feature | Deployment | StatefulSet |
|---------|------------|-------------|
| Pod identity | Random hash | Ordinal index (0, 1, 2) |
| Naming | Random | Predictable (name-0, name-1) |
| Storage | Shared PVC | Each pod gets own PVC |
| Scaling | Any order | Sequential (0, 1, 2...) |
| Deletion | Simultaneous | Reverse order |
| Use case | Stateless apps | Stateful apps (DB, Kafka) |
| Service | ClusterIP | Headless service |

**StatefulSet is for:** Databases, message queues, distributed systems.

---

### Q7: How do you do a Blue-Green deployment?

**Answer:**

**1. Deploy both versions:**
```yaml
# Blue (current)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-blue
  labels:
    version: blue

---
# Green (new)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-green
  labels:
    version: green
```

**2. Service points to blue:**
```yaml
selector:
  version: blue
```

**3. Test green deployment**

**4. Switch traffic:**
```bash
kubectl patch service myapp -p '{"spec":{"selector":{"version":"green"}}}'
```

**5. Rollback if needed:**
```bash
kubectl patch service myapp -p '{"spec":{"selector":{"version":"blue"}}}'
```

---

### Q8: What is a Canary deployment?

**Answer:**
Deploy new version to **small subset** of users/production traffic first.

**Approaches:**

**1. Separate deployment with replica count:**
```bash
# 9 replicas of stable
kubectl scale deployment/app-stable --replicas=9

# 1 replica of canary
kubectl scale deployment/app-canary --replicas=1
```

**2. Service mesh (Istio, Linkerd):**
- More sophisticated traffic splitting
- Percentage-based routing
- Automatic rollback

**Monitoring:** Watch error rates, latency during canary.

---

### Q9: What are Jobs and CronJobs?

**Answer:**

**Job:** Runs pods to completion (batch processing)
- `completions`: How many successful pods needed
- `parallelism`: How many pods run concurrently
- `ttlSecondsAfterFinished`: Auto-cleanup

**CronJob:** Scheduled jobs
- `schedule`: Cron expression
- `startingDeadlineSeconds`: Must start within time
- `concurrencyPolicy`: Allow/Forbid/Replace

---

### Q10: How do you pause a deployment rollout?

**Answer:**

```bash
kubectl rollout pause deployment/myapp

# Make changes while paused
kubectl set image deployment/myapp app=newimage:tag
kubectl set resources deployment/myapp -c=app --limits=cpu=500m

# Resume rollout
kubectl rollout resume deployment/myapp
```

**Use case:** Making multiple changes without triggering multiple rollouts.

---

### Q11-20: [See Chapter README for full 20 questions]

---

## ✅ Chapter Completion

Mark completed in [CHECKLIST.md](../CHECKLIST.md)

**Next:** [Chapter 4: Services & Networking](../chapter-04/)
