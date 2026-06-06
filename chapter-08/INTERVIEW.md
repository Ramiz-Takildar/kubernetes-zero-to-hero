# Chapter 8: Scheduling & Scaling - Interview Questions

> 20+ Interview Questions with Detailed Answers

---

## Basic Level Questions

### Q1: What is HPA and how does it work?

**Answer:**

**HPA:** Horizontal Pod Autoscaler - automatically scales pod count.

**How it works:**
```
Metrics Server
       │
       ▼
HPA Controller
       │
       ├─── current > target? ──► Scale up
       │
       └─── current < target? ──► Scale down
```

**Formula:**
```
desiredReplicas = ceil[currentReplicas * (currentMetric / targetMetric)]

Example:
  currentReplicas = 2
  currentCPU = 80%
  targetCPU = 50%
  
  desired = 2 * (80/50) = 3.2 → ceil → 4
```

**Metrics:**
- CPU utilization
- Memory utilization
- Custom metrics (via Prometheus Adapter)

---

### Q2: What is the difference between HPA and VPA?

**Answer:**

| HPA | VPA |
|-----|-----|
| Horizontal (more pods) | Vertical (bigger pods) |
| Scale quantity | Scale resources per pod |
| Works with Deployment | Works with Deployment |
| CPU/memory/custom | CPU/memory only |
| Can cause scheduling churn | May restart pods |

**Use HPA when:** Variable load, stateless
**Use VPA when:** Fixed pod count, variable resource needs

---

### Q3: What is a Pod Disruption Budget (PDB)?

**Answer:**

**Purpose:** Ensure minimum availability during voluntary disruptions.

**Scenario:**
```
5 replicas
PDB: minAvailable: 3

Can evict at most: 5 - 3 = 2 pods

Node drain:
- Pod 1 evicted: 5 → 4 ✓
- Pod 2 evicted: 4 → 3 ✓
- Pod 3 blocked: Would be 3 → 2 ✗
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

### Q4: What are node selectors and affinity?

**Answer:**

**Node Selector:** Simple key-value matching
```yaml
nodeSelector:
  disktype: ssd
```

**Node Affinity:** More expressive (preferred/required)
```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: disktype
          operator: In
          values: ["ssd", "ssd-fast"]
```

**Difference:**
| Selector | Affinity |
|----------|----------|
| Simple equality | Complex expressions |
| Hard requirement | Can be preferred |
| One key-value | Multiple conditions |

---

### Q5: What is pod anti-affinity?

**Answer:**

**Purpose:** Spread pods across nodes/availability zones.

**Example:**
```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchLabels:
            app: web
        topologyKey: kubernetes.io/hostname
```

**Effect:** Try to put web pods on different nodes.

**Use case:** High availability, failure isolation.

---

## Intermediate Level Questions

### Q6: What are taints and tolerations?

**Answer:**

**Concept:** Taint on node prevents pod scheduling unless pod tolerates it.

```
Node has taint          Pod tolerates         Scheduled?
dedicated=true:         dedicated=true:       YES
NoSchedule              Equal                
                                              
gpu=true:               (none)                NO
NoSchedule                                    
                                             
maintenance:            maintenance:           YES (but not new)
NoExecute               Exists
```

**Use cases:**
- Dedicated nodes (GPU, control plane)
- Maintenance (drain node)
- Special hardware requirements

---

### Q7: What are the taint effects?

**Answer:**

| Effect | Behavior |
|--------|----------|
| **NoSchedule** | No new pods scheduled |
| **PreferNoSchedule** | Avoid scheduling (not guaranteed) |
| **NoExecute** | Evict existing pods that don't tolerate |

**Drain node:**
```bash
kubectl taint node <node> node.kubernetes.io/unschedulable:NoSchedule
kubectl drain <node> --ignore-daemonsets
```

---

### Q8: How does Cluster Autoscaler work?

**Answer:**

**Cluster Autoscaler:** Adds/removes nodes based on pod scheduling.

**Scale up:**
```
Pod can't be scheduled (Insufficient resources)
        │
        ▼
Cluster Autoscaler sees pending pods
        │
        ▼
Adds new node(s)
        │
        ▼
Pending pods scheduled
```

**Scale down:**
```
Node utilization low (< 50% for 10 min)
        │
        ▼
Check: Can pods move to other nodes?
        │
        ▼
Drain and terminate node
```

**Key difference:**
- HPA: Scales pods
- Cluster Autoscaler: Scales nodes

---

### Q9: What is topology spread constraints?

**Answer:**

**Purpose:** Even distribution across failure domains.

```yaml
topologySpreadConstraints:
- maxSkew: 1
  topologyKey: topology.kubernetes.io/zone
  whenUnsatisfiable: DoNotSchedule
  labelSelector:
    matchLabels:
      app: web
```

**Example:**
```
Zone A: 2 web pods
Zone B: 3 web pods  
Zone C: 0 web pods

maxSkew: 1
Max difference allowed: 1
Result: Pods rescheduled to balance
```

**Use case:** Multi-zone high availability.

---

### Q10: What are priority classes?

**Answer:**

**Purpose:** Decides which pods get evicted first under resource pressure.

```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000000
globalDefault: false
preemptionPolicy: PreemptLowerPriority
```

**Usage:**
```yaml
spec:
  priorityClassName: high-priority
```

**Eviction order (lowest priority first):**
1. BestEffort pods
2. Burstable pods
3. Guaranteed pods
4. By PriorityClass value

---

## Advanced Level Questions

### Q11: What is preemption?

**Answer:**

**Definition:** Higher priority pod can evict lower priority pods to schedule.

**Flow:**
```
High priority pod needs to schedule
        │
        ▼
No node has capacity
        │
        ▼
Find node with lowest priority pods
        │
        ▼
Evict low priority pods
        │
        ▼
Schedule high priority pod
```

**Enable:**
```yaml
preemptionPolicy: PreemptLowerPriority
```

---

### Q12: How do you prevent a pod from being evicted?

**Answer:**

**Methods:**

1. **PriorityClass:** Set high priority
2. **QoS:** Use Guaranteed class
3. **PDB:** Set minAvailable
4. **Tolerations:** For taints (but won't prevent all evictions)

**Note:** PDB only protects from voluntary disruptions (not OOM or node failure).

---

### Q13: What is the difference between preferred and required affinity?

**Answer:**

| Required | Preferred |
|----------|-----------|
| Hard requirement | Soft preference |
| Pod won't schedule if not met | Pod schedules anyway |
| `RequiredDuringScheduling` | `PreferredDuringScheduling` |
| Use for critical constraints | Use for optimization |

```yaml
# Required - Must have
requiredDuringSchedulingIgnoredDuringExecution:
  nodeSelectorTerms:
  - matchLabels:
      zone: us-east-1a

# Preferred - Nice to have
preferredDuringSchedulingIgnoredDuringExecution:
- weight: 100
  preference:
    matchLabels:
      zone: us-east-1a
```

---

### Q14: What are the HPA scale stabilization windows?

**Answer:**

**Purpose:** Prevent flapping (rapid scale up/down).

```yaml
behavior:
  scaleUp:
    stabilizationWindowSeconds: 60
    policies:
    - type: Percent
      value: 100
      periodSeconds: 15
  scaleDown:
    stabilizationWindowSeconds: 300
    policies:
    - type: Percent
      value: 10
      periodSeconds: 60
```

**Defaults:**
- Scale up: 0s (immediate)
- Scale down: 5 minutes

**Why:** Scale down slower to prevent thrashing.

---

### Q15: How does scheduler scoring work?

**Answer:**

**Scoring factors and weights:**

| Factor | Weight | Description |
|--------|--------|-------------|
| LeastAllocated | 10 | Favor nodes with most free resources |
| NodeAffinity | 8 | Match node affinity |
| PodAffinity | 5 | Pods that should be together |
| ImageLocality | 2 | Node has image cached |

**Calculation:**
- Node scores 0-100 on each factor
- Weighted average
- Highest score wins

---

## Scenario-Based Questions

### S1: Pod keeps evicting under resource pressure.

**Answer:**

**Solutions:**

1. Increase resource requests (better QoS)
```yaml
resources:
  requests:
    memory: 512Mi  # Increase from 100Mi
```

2. Set PriorityClass higher

3. Set PDB to protect during drains

4. Move to dedicated node pool

---

### S2: HPA keeps thrashing (scaling up/down rapidly).

**Answer:**

**Fix:**

```yaml
behavior:
  scaleUp:
    stabilizationWindowSeconds: 120
    policies:
    - type: Percent
      value: 50
      periodSeconds: 30
  scaleDown:
    stabilizationWindowSeconds: 300
    policies:
    - type: Percent
      value: 10
      periodSeconds: 60
```

**Or adjust target:**
- Target 70% instead of 50%
- Wider threshold reduces sensitivity

---

## Quick Reference

| Resource | What It Scales |
|----------|----------------|
| HPA | Pod count |
| VPA | Pod resources |
| Cluster Autoscaler | Node count |

---

## Key Takeaways

1. **HPA:** Scale pod count horizontally
2. **VPA:** Scale pod resources vertically
3. **PDB:** Protect availability during disruptions
4. **Taints:** Repel pods from nodes
5. **Affinity:** Attract pods to nodes/other pods
6. **Anti-affinity:** Spread pods apart
7. **Priority:** Eviction order
8. **Topology spread:** Distribute across zones

---

**Previous:** [Chapter 7 Interview Questions](../chapter-07/INTERVIEW.md)  
**Next:** [Chapter 9 Interview Questions](../chapter-09/INTERVIEW.md)
