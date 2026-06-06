# Chapter 8: Scheduling & Scaling

## Interview Questions (20)

### Q1: How does HPA work?

**Answer:**
```
Metrics Server → HPA Controller → Calculate replicas → Scale deployment
```

Formula:
```
desiredReplicas = currentReplicas × (currentMetricValue / targetMetricValue)
```

### Q2: What is the difference between HPA and VPA?

**Answer:**

| | HPA | VPA |
|---|-----|-----|
| Direction | Horizontal (more pods) | Vertical (bigger pods) |
| Resource | CPU/Memory/Custom | CPU/Memory |
| Works with | Deployments, RS, SS | Deployments, SS |
| Use case | Scale quantity | Scale size |

---

## ✅ Chapter Completion

Mark completed in [CHECKLIST.md](../CHECKLIST.md)
