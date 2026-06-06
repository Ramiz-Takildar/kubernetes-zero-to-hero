# Chapter 3: Workloads & Controllers

## 📚 Learning Objectives

By the end of this chapter, you will:
- Master Deployments and their update strategies
- Implement zero-downtime deployments (blue-green, canary)
- Use StatefulSets for stateful applications
- Schedule batch jobs and cron jobs
- Configure DaemonSets for node-level services
- Perform rollbacks and manage revision history

**Estimated Time:** 3 days  
**Labs:** 4 hands-on exercises

---

## 🎯 Deployments Explained

### What is a Deployment?

A Deployment provides **declarative updates** for Pods and ReplicaSets. You describe the **desired state** in a Deployment, and the Deployment Controller changes the **actual state** to match.

```
┌─────────────────────────────────────────────┐
│              Deployment                     │
│          (Desired State)                    │
│                                             │
│  replicas: 5                                │
│  image: nginx:1.25                          │
│  strategy: RollingUpdate                    │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
           ┌──────────────┐
           │   Controller │
           │   Reconciles │
           └──────┬───────┘
                  │
      ┌───────────┼───────────┐
      ▼           ▼           ▼
┌──────────┐ ┌──────────┐ ┌──────────┐
│ReplicaSet│ │ReplicaSet│ │ReplicaSet│
│ (v1.24)  │ │ (v1.25)  │ │ (v1.26)  │
│          │ │          │ │          │
│ Pod-1    │ │ Pod-1    │ │ Pod-1    │
│ Pod-2    │ │ Pod-2    │ │ Pod-2    │
│ Pod-3    │ │ Pod-3    │ │ Pod-3    │
└──────────┘ └──────────┘ └──────────┘
     ↑
  Old revisions (kept for rollback)
```

### Deployment vs ReplicaSet

| Aspect | ReplicaSet | Deployment |
|--------|-----------|------------|
| Purpose | Maintain pod count | Manage declarative updates |
| Updates | Manual | Automated with strategy |
| Rollback | Not supported | Built-in revision history |
| Version tracking | None | Maintains revision history |
| Use directly | No | Yes |

**Golden Rule:** Always use Deployments, never ReplicaSets directly.

---

## 🔄 Update Strategies

### Rolling Update (Default)

Gradually replaces old pods with new ones.

```
Initial:          v1.24 running (5 pods)
                      │
                      ▼
Step 1: Create 1 new pod (v1.25)
        Scale: 5 old + 1 new = 6 total
                      │
                      ▼
Step 2: Delete 1 old pod
        Scale: 4 old + 1 new = 5 total
                      │
                      ▼
Step 3: Create 1 new pod
        Scale: 4 old + 2 new = 6 total
                      │
                      ▼
Continue until: 5 new pods (v1.25)
                0 old pods
```

**Configuration:**
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 1     # Max pods DOWN during update
    maxSurge: 1          # Max pods ABOVE desired during update
```

**Dual Strategy:**
- `maxUnavailable: 0` → Ensure zero downtime (default behavior)
- `maxSurge: 1` → Allow temporary extra pods

---

### Recreate Strategy

Kill all old pods, then create new ones.

```
Step 1: Terminate all 5 old pods
        Available: 0 pods
        DOWNTIME!
                  │
                  ▼
Step 2: Create 5 new pods
        Available: 5 pods
```

**Use case:** When pods cannot run simultaneously (database schema changes)

---

## 🚦 Deployment Patterns

### Blue-Green Deployment

```
┌─────────────────────────────────────────────┐
│               Load Balancer                 │
│                   (Service)                 │
│                      │                      │
│           ┌─────────┴─────────┐            │
│           │                   │            │
│           ▼                   ▼            │
│   ┌──────────────┐   ┌──────────────┐      │
│   │ Blue (Live)  │   │ Green (Idle) │      │
│   │              │   │   (test)     │      │
│   │  v1.0 Active │   │   v2.0 Ready │      │
│   └──────────────┘   └──────────────┘      │
│          ↑                                        │
└──────────┬──────────────────────────────────┘
           │
    Users connected here
```

**Process:**
1. Deploy v1.0 (Blue) - receiving traffic
2. Deploy v2.0 (Green) - idle, test it
3. Switch Service selector to Green
4. Blue still exists for instant rollback

**Advantages:**
- Zero downtime
- Instant rollback
- Full testing before switch

---

### Canary Deployment

```
Load Balancer
      │
      ├─ 95% ──► v1.0 (Stable)
      │
      └─ 5%  ──► v2.0 (Canary)

Monitor metrics:
- Error rate < 1% ✓
- Latency < 100ms ✓
- Then gradually shift traffic:

      ├─ 70% ──► v1.0
      │
      └─ 30% ──► v2.0

Eventually:
      │
      └─ 100% ──► v2.0
```

**Benefits:**
- Test with real production traffic
- Limit blast radius of failures
- Gradual rollout
- Automatic rollback if issues

---

## 📊 StatefulSets

### Why StatefulSets?

**Deployment limitations for stateful apps:**
- Random pod names (hash-based)
- Simultaneous scaling/deletion
- Shared storage
- No stable network identity

**StatefulSet solutions:**
- Predictable pod names: `name-0, name-1, name-2`
- Ordered operations (0, 1, 2...)
- Each pod gets own PersistentVolume
- Stable network identity via headless service

### StatefulSet Pod Management

```
Creation Order:          Deletion Order:
  name-0                    name-2
    │   (wait for ready)     │
    ▼                        ▼
  name-1                    name-1
    │   (wait for ready)     │
    ▼                        ▼
  name-2                    name-0
         
Sequential               Reverse Order
OrderedReady             Parallel
```

**Headless Service for StatefulSet:**
```
Pod: db-0
Access: db-0.db-headless.default.svc.cluster.local
DNS resolves directly to Pod IP (no load balancing)
```

### Use Cases

- Databases (MySQL, PostgreSQL, MongoDB)
- Message queues (Kafka, RabbitMQ)
- Distributed systems (ZooKeeper, etcd)
- Search engines (Elasticsearch)

---

## ⏰ Jobs and CronJobs

### Job

Runs a task to completion.

```yaml
apiVersion: batch/v1
kind: Job
spec:
  completions: 10      # Need 10 successful completions
  parallelism: 3       # Run 3 pods at a time
  activeDeadlineSeconds: 600  # Fail if not done in 10 min
```

**Behavior:**
- Creates pods until `completions` successful pods
- Runs `parallelism` pods concurrently
- Retries failed pods (up to `backoffLimit`)

### CronJob

Scheduled execution of Jobs.

```yaml
apiVersion: batch/v1
kind: CronJob
spec:
  schedule: "0 2 * * *"  # 2 AM daily
  concurrencyPolicy: Forbid  # Don't start if previous still running
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:15
            command: ['pg_dump', ...]
          restartPolicy: OnFailure
```

**Scheduling Format (Cron):**
```
┌───────────── minute (0 - 59)
│ ┌───────────── hour (0 - 23)
│ │ ┌───────────── day of month (1 - 31)
│ │ │ ┌───────────── month (1 - 12)
│ │ │ │ ┌───────────── day of week (0 - 6)
│ │ │ │ │
│ │ │ │ │
* * * * *

Examples:
0 2 * * *     # Daily at 2 AM
*/5 * * * *   # Every 5 minutes
0 0 * * 0     # Weekly on Sunday
```

---

## 👥 DaemonSet

Ensures exactly one pod per node.

```
Cluster:
┌────────────┐  ┌────────────┐  ┌────────────┐
│   Node 1   │  │   Node 2   │  │   Node 3   │
│            │  │            │  │            │
│ ┌────────┐ │  │ ┌────────┐ │  │ ┌────────┐ │
│ │Fluentd │ │  │ │Fluentd │ │  │ │Fluentd │ │
│ │ (log)  │ │  │ │ (log)  │ │  │ │ (log)  │ │
│ └────────┘ │  │ └────────┘ │  │ └────────┘ │
└────────────┘  └────────────┘  └────────────┘

One per node automatically
```

**Use Cases:**
- Log collection (Fluentd, Filebeat)
- Node monitoring (Prometheus node-exporter)
- CNI plugins (Calico, Flannel)
- Storage daemons

**Deployment vs DaemonSet:**
| Deployment | DaemonSet |
|------------|-----------|
| Specified replica count | One per node |
| Any node | All nodes (or subset) |
| User apps | Infrastructure |

---

## 🔄 Rollback

```
v1.0 deployed
    │
    ▼
v1.1 deployed (broken)
    │
    ▼
Rollback to v1.0
    │
    └─► Deployment Controller:
        - Uses old ReplicaSet (v1.0)
        - Scales down v1.1 ReplicaSet
        - Scales up v1.0 ReplicaSet
        - Updates Deployment revision
```

**Commands:**
```bash
# View revisions
kubectl rollout history deployment/myapp

# Rollback to previous
kubectl rollout undo deployment/myapp

# Rollback to specific revision
kubectl rollout undo deployment/myapp --to-revision=2
```

---

## 📊 Theory to Labs

### Lab 3.1: Production Deployment
**Theory Applied:**
- Rolling update configuration
- Health probes integration
- Resource management

### Lab 3.2: Blue-Green Deployment
**Theory Applied:**
- Service selector switching
- Zero-downtime deployments
- Instant rollback

### Lab 3.3: StatefulSet
**Theory Applied:**
- Ordered pod management
- Persistent volume per pod
- Headless service DNS

### Lab 3.4: CronJob
**Theory Applied:**
- Scheduled execution
- Concurrency policies
- Job completions

---

## 📖 Key Takeaways

1. **Deployment = ReplicaSet + Updates:** Use always for stateless apps
2. **Rolling Update:** Zero downtime (maxSurge/maxUnavailable)
3. **Blue-Green:** Fast switch, good for critical apps
4. **Canary:** Gradual rollout, test with real traffic
5. **StatefulSet:** Use for databases, ordered ops, stable identity
6. **Job:** Run to completion, can be parallel
7. **DaemonSet:** One per node, for infrastructure
8. **Revision History:** All changes tracked, rollback anytime

---

## ❓ Interview Questions

### Q: RollingUpdate vs Recreate?

**Answer:**

| Aspect | RollingUpdate | Recreate |
|--------|---------------|----------|
| **Downtime** | Zero | Yes (brief) |
| **Old/New pods** | Run simultaneously | Never together |
| **Resources** | Needs extra capacity | Same resources |
| **Use case** | Stateless apps | Schema changes, incompatible versions |

**RollingUpdate parameters:**
- `maxUnavailable`: Max pods that can be down
- `maxSurge`: Max pods above desired count

---

### Q: Deployment vs StatefulSet?

**Answer:**

| Feature | Deployment | StatefulSet |
|---------|------------|-------------|
| Pod names | Random (hash) | Ordinal (0, 1, 2) |
| Scaling | Any order | Sequential |
| Storage | Shared | Per-pod PVC |
| Network | ClusterIP | Headless service |
| Use case | Web apps, APIs | Databases, queues |

---

## 🔗 Next Steps

1. Review theory above
2. Complete [Lab 3.1](./LABS.md) - Production Deployment
3. Complete [Lab 3.2](./LABS.md) - Blue-Green
4. Complete [Lab 3.3](./LABS.md) - StatefulSet

**Next Chapter:** [Chapter 4: Networking](../chapter-04/)
