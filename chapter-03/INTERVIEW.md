# Chapter 3: Workloads & Controllers - Interview Questions

> 20+ Interview Questions with Detailed Answers

---

## Basic Level Questions

### Q1: What is the difference between a Deployment and a ReplicaSet?

**Answer:**

| Deployment | ReplicaSet |
|------------|------------|
| Manages declarative updates | Ensures pod count |
| Version tracking + Rollback | No version tracking |
| Update strategies | No update strategy |
| Use this directly | Don't use directly |

**Relationship:**
```
Deployment → manages → ReplicaSet → manages → Pods
```

**Golden Rule:** Always use Deployments, never ReplicaSets directly.

---

### Q2: What are the different Deployment strategies?

**Answer:**

| Strategy | Behavior | Downtime | Use Case |
|----------|----------|----------|----------|
| **RollingUpdate** | Gradual replacement | Zero | Default, stateless apps |
| **Recreate** | Kill all, then create | Yes | Schema changes, DB migrations |

**RollingUpdate parameters:**
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 1  # Max pods down during update
    maxSurge: 1       # Max pods above desired
```

**Recreate:**
```yaml
strategy:
  type: Recreate
```

---

### Q3: How do you rollback a Deployment?

**Answer:**

**Commands:**
```bash
# View revision history
kubectl rollout history deployment/myapp

# Rollback to previous version
kubectl rollout undo deployment/myapp

# Rollback to specific revision
kubectl rollout undo deployment/myapp --to-revision=2

# Check rollback status
kubectl rollout status deployment/myapp
```

**What happens:**
1. Controller scales down new ReplicaSet
2. Controller scales up old ReplicaSet
3. Deployment revision incremented
4. Pods gradually replaced

---

### Q4: What is the difference between maxUnavailable and maxSurge?

**Answer:**

| Parameter | Controls | Default | Risk |
|-----------|----------|---------|------|
| **maxUnavailable** | Max pods DOWN during update | 25% | Lower = safer, slower |
| **maxSurge** | Max EXTRA pods above desired | 25% | Higher = faster, more resources |

**Example with 10 replicas:**
```
maxUnavailable: 2, maxSurge: 2

Update flow:
Step 1: 10 old running
Step 2: 10 old + 2 new = 12 total (2 surge)
Step 3:  8 old + 2 new = 10 total (2 unavailable)
Step 4:  8 old + 4 new = 12 total
...
Step N:  0 old + 10 new = 10 total (done)
```

---

### Q5: When would you use a DaemonSet?

**Answer:**

**Use when you need exactly one pod per node.**

**Common use cases:**
- Log collection (Fluentd, Filebeat)
- Node monitoring (Prometheus node-exporter)
- Network agents (CNI plugins)
- Storage daemons

**Deployment vs DaemonSet:**
| Deployment | DaemonSet |
|------------|-----------|
| Specified replicas | One per node |
| Elastic scaling | Fixed per node |
| User applications | Infrastructure |

---

## Intermediate Level Questions

### Q6: What is a StatefulSet and when do you use it?

**Answer:**

**Use for stateful applications requiring:**
- Stable, unique network identifiers
- Stable persistent storage
- Ordered, graceful deployment and scaling
- Ordered, automated rolling updates

**StatefulSet features:**
| Feature | StatefulSet | Deployment |
|---------|-------------|------------|
| Pod names | Predictable (web-0, web-1) | Random (web-abc123) |
| Scaling | Ordered | Any order |
| Storage | Per-pod PVC | Shared |
| Network | Headless service | ClusterIP |

**Use cases:** Databases (MySQL, PostgreSQL, MongoDB), message queues (Kafka), distributed systems (ZooKeeper).

---

### Q7: Explain Blue-Green deployment.

**Answer:**

**Pattern:**
```
Production traffic
       │
       ▼
┌──────────────────────────────────┐
│  Blue (v1.0)  ◄── Current active │
│  Green (v2.0)  ── Idle, tested   │
└──────────────────────────────────┘
```

**Process:**
1. Deploy v1.0 (Blue) - active
2. Deploy v2.0 (Green) - idle, test it
3. Switch Service selector to Green
4. Blue still exists for instant rollback

**Pros:**
- Zero downtime
- Instant rollback
- Full testing in production environment

**Cons:**
- Double resource usage
- Database schema challenges

---

### Q8: Explain Canary deployment.

**Answer:**

**Pattern:**
```
Load Balancer
      │
      ├─ 95% ──► v1.0 (Stable)
      │
      └─ 5%  ──► v2.0 (Canary)

Monitor → Gradually shift traffic
      │
      ├─ 70% ──► v1.0
      │
      └─ 30% ──► v2.0

Finally:
      └─ 100% ──► v2.0
```

**Benefits:**
- Test with real production traffic
- Limit blast radius
- Automatic rollback if metrics bad

**Implementation:** Two Deployments with different replica counts, or service mesh (Istio).

---

### Q9: What is the difference between a Job and a CronJob?

**Answer:**

| Job | CronJob |
|-----|---------|
| Runs once to completion | Scheduled execution |
| Creates one or more pods | Creates Jobs on schedule |
| Good for batch processing | Good for periodic tasks |

**Job parameters:**
```yaml
spec:
  completions: 10      # Need 10 successful pods
  parallelism: 3       # Run 3 at a time
  ttlSecondsAfterFinished: 3600  # Clean up after 1 hour
```

**CronJob:**
```yaml
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
```

---

### Q10: How do Jobs handle failures?

**Answer:**

**Retry behavior:**
```yaml
spec:
  backoffLimit: 6      # Retry 6 times before marking failed
  activeDeadlineSeconds: 600  # Timeout after 10 minutes
```

**Failure scenarios:**
- Container exit code != 0 → Retry
- Pod eviction → Retry
- Deadline exceeded → Mark failed
- Backoff limit reached → Mark failed

**Restart policy:** Must be OnFailure or Never (not Always)

---

## Advanced Level Questions

### Q11: What is a PodDisruptionBudget (PDB)?

**Answer:**

**Purpose:** Ensure minimum availability during voluntary disruptions (node drains, upgrades).

**How it works:**
```
5 replicas, PDB: minAvailable: 3

Can evict at most: 5 - 3 = 2 pods

Eviction 1: 5 → 4 (ok)
Eviction 2: 4 → 3 (ok)
Eviction 3: BLOCKED (would be 2 < 3)
```

**Configuration:**
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
spec:
  minAvailable: 3  # Or maxUnavailable: 1
  selector:
    matchLabels:
      app: web
```

---

### Q12: How does HPA decide to scale?

**Answer:**

**Formula:**
```
desiredReplicas = ceil[currentReplicas * (currentMetric / targetMetric)]

Example:
  current: 2 pods
  currentCPU: 80%
  targetCPU: 50%
  
  desired = 2 * (80/50) = 3.2 → ceil → 4 pods
```

**HPA Behavior:**
```yaml
spec:
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
    scaleDown:
      stabilizationWindowSeconds: 300
```

---

### Q13: What is the difference between HPA and VPA?

**Answer:**

| HPA | VPA |
|-----|-----|
| Horizontal (more pods) | Vertical (bigger pods) |
| Scale quantity | Scale resource size |
| CPU/memory custom metrics | CPU/memory only |
| Fast response | Slower response |
| Works with Deployment | Works with Deployment |

**Use HPA when:** Variable load, stateless
**Use VPA when:** Fixed pod count, variable resource needs

---

### Q14: Why does my Deployment create new ReplicaSets?

**Answer:**

Every Deployment revision creates a new ReplicaSet.

```
Deployment
    ├── ReplicaSet v1 (old, scaled to 0)
    ├── ReplicaSet v2 (old, scaled to 0)
    └── ReplicaSet v3 (current, active)

Revision history kept for rollback.
```

**Clean up old ReplicaSets:**
```yaml
spec:
  revisionHistoryLimit: 5  # Keep only 5 revisions
```

---

### Q15: What is OnDelete update strategy for StatefulSets?

**Answer:**

**StatefulSet strategies:**
- **RollingUpdate:** Automatic rolling update (default)
- **OnDelete:** Manual update - pods only update when manually deleted

**Use OnDelete when:**
- You need fine-grained control
- Applications can't handle automatic rolling
- Zero-downtime not possible with automatic

---

## Scenario-Based Questions

### S1: How do you deploy a database schema update with zero downtime?

**Answer:**

**Approach:**
1. **Pre-deployment:** Add new columns/tables (non-breaking)
2. **Deployment:** Deploy new app version
3. **Post-deployment:** Remove old columns (after verification)

**Or use:**
- **Expand-contract pattern:** Add new, migrate data, remove old
- **Feature flags:** Toggle behavior without deployment

**Not:** Recreate strategy (requires downtime)

---

### S2: Your canary deployment is causing errors. How do you rollback?

**Answer:**

**Immediate:**
```bash
# Switch service back to stable
kubectl patch service myapp -p '{"spec":{"selector":{"version":"stable"}}}'
```

**Or scale canary to 0:**
```bash
kubectl scale deployment myapp-canary --replicas=0
```

**Then investigate:**
```bash
kubectl logs deployment/myapp-canary
kubectl describe deployment/myapp-canary
```

---

## Quick Reference

| Resource | Use For |
|----------|---------|
| Deployment | Stateless apps |
| StatefulSet | Stateful apps |
| DaemonSet | One per node |
| Job | Batch tasks |
| CronJob | Scheduled tasks |

---

## Key Takeaways

1. **Deployment = Update + ReplicaSet:** Use for most apps
2. **StatefulSet:** Ordered, named, persistent
3. **RollingUpdate:** Zero downtime
4. **Canary:** Test with real traffic
5. **PDB:** Protect availability during disruptions
6. **HPA:** Autoscale pod count

---

**Previous:** [Chapter 2 Interview Questions](../chapter-02/INTERVIEW.md)  
**Next:** [Chapter 4 Interview Questions](../chapter-04/INTERVIEW.md)
