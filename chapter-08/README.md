# Chapter 8: Scheduling & Scaling

## 📚 Learning Objectives

By the end of this chapter, you will:
- Configure Horizontal Pod Autoscaler (HPA)
- Use node affinity and anti-affinity
- Implement taints and tolerations
- Configure Pod Disruption Budgets
- Understand cluster autoscaling

**Estimated Time:** 3 days  
**Labs:** 4 hands-on exercises

---

## 📈 Horizontal Pod Autoscaler (HPA)

### Purpose

Automatically scale pods based on CPU, memory, or custom metrics.

### How It Works

```
                    ┌─────────────────┐
                    │   Metrics       │
                    │   Server        │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │   HPA           │
                    │   Controller    │
                    │                 │
                    │  Calculation:   │
                    │  desired =      │
                    │  current *      │
                    │  (currentMetric │
                    │   / target)     │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │  Scale          │
                    │  Deployment     │
                    └─────────────────┘
```

### Formula

```
desiredReplicas = ceil[
    currentReplicas * (currentMetricValue / targetMetricValue)
]

Example:
  currentReplicas = 2
  currentCPU = 80%
  targetCPU = 50%
  
  desired = 2 * (80/50) = 2 * 1.6 = 3.2 → ceil to 4
```

### HPA Behavior

```yaml
behavior:
  scaleUp:
    stabilizationWindowSeconds: 60
    policies:
    - type: Percent
      value: 100    # Can double pods
      periodSeconds: 15
  scaleDown:
    stabilizationWindowSeconds: 300  # Wait 5 min before scaling down
    policies:
    - type: Percent
      value: 10     # Reduce by 10% max
      periodSeconds: 60
```

---

## 🎯 Scheduling Controls

### Affinity/Anti-Affinity

#### Node Affinity

**Hard requirement (must match):**
```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: disktype
          operator: In
          values: ["ssd"]
```

**Soft preference (prefer match):**
```yaml
affinity:
  nodeAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      preference:
        matchExpressions:
        - key: zone
          operator: In
          values: ["us-east-1a"]
```

#### Pod Anti-Affinity

Spread pods across nodes:
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

---

## 🚫 Taints and Tolerations

### Concept

```
Node has TAINT          Pod has TOLERATION        Result
────────────────────────────────────────────────────────────
dedicated=true:       dedicated=true:             ✓ Scheduled
NoSchedule            (matches)
                      
dedicated=true:       (none)                      ✗ Blocked
NoSchedule            

gpu=true:             gpu=true:                   ✓ Scheduled
NoSchedule            for any value

(gpu=true):           (none)                      ✗ Blocked
NoSchedule
```

### Taint Effects

| Effect | Behavior |
|--------|----------|
| `NoSchedule` | New pods not scheduled (existing stay) |
| `PreferNoSchedule` | Avoid scheduling (not guaranteed) |
| `NoExecute` | Evict existing pods that don't tolerate |

### Use Cases

- Dedicated nodes (control plane, GPU)
- Maintenance (drain node)
- Special hardware

---

## 🛡️ Pod Disruption Budget (PDB)

### Purpose

Ensure minimum availability during voluntary disruptions (upgrades, drains).

```
Replicas: 5
PDB: minAvailable: 3

Can evict at most: 5 - 3 = 2 pods

Scenario:
Starting: 5 pods running
Eviction 1: 5 → 4 pods (ok, 4 >= 3)
Eviction 2: 4 → 3 pods (ok, 3 >= 3)
Eviction 3: BLOCKED (would go to 2 < 3)
```

### Configuration

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: app-pdb
spec:
  minAvailable: 3  # Or maxUnavailable: 1
  selector:
    matchLabels:
      app: web
```

---

## 📊 Theory to Labs

### Lab 8.1: HPA
**Theory Applied:**
- CPU-based scaling
- Scale up/down behavior
- Pod disruption budgets

### Lab 8.2: Node Scheduling
**Theory Applied:**
- Node affinity
- Pod anti-affinity
- Topology spread constraints

### Lab 8.3: Taints
**Theory Applied:**
- Taint effects
- Tolerations
- Dedicated nodes

---

## 📖 Key Takeaways

1. **HPA:** Scale pods based on metrics
2. **Formula:** desired = current * (current/target)
3. **Stabilization:** Prevents flapping
4. **Affinity:** Prefer/require nodes
5. **Anti-affinity:** Spread pods
6. **Taints:** Block pods from nodes
7. **PDB:** Ensure availability during disruptions
8. **Cluster Autoscaler:** Scale nodes (different from HPA)

---

## ❓ Interview Questions

### Q: HPA vs VPA?

**Answer:**

| HPA | VPA |
|-----|-----|
| Horizontal (more pods) | Vertical (bigger pods) |
| Scale quantity | Scale size |
| CPU/memory/custom | CPU/memory |
| Works with Deployment | Works with Deployment |
| Faster response | Slower response |

---

## 🔗 Next Steps

1. Review theory above
2. Complete [Lab 8.1](./LABS.md) - HPA
3. Complete [Lab 8.2](./LABS.md) - Scheduling
4. Complete [Lab 8.3](./LABS.md) - Taints

**Next Chapter:** [Chapter 9: Security](../chapter-09/)
