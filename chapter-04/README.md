# Chapter 4: Services & Networking

## 📚 Learning Objectives

By the end of this chapter, you will:
- Understand all service types
- Know how pod-to-pod communication works
- Configure ingress routing
- Implement network policies
- Debug networking issues

**Estimated Time:** 4 days

---

## 4.1 Service Types

### Comparison

| Type | Internal IP | Node Port | External LB | Use Case |
|------|-------------|-----------|-------------|----------|
| **ClusterIP** | ✅ | ❌ | ❌ | Internal microservices |
| **NodePort** | ✅ | ✅ | ❌ | Quick external access |
| **LoadBalancer** | ✅ | ✅ | ✅ | Cloud environments |
| **ExternalName** | ✅ | ❌ | ❌ | External DNS mapping |
| **Headless** | ❌ | ❌ | ❌ | Stateful apps |

### Diagram
```
                External Client
                      ↓
            ┌─────────┴─────────┐
            ▼                   ▼
    ┌──────────────┐   ┌──────────────┐
    │ LoadBalancer │   │   NodePort   │
    │  (cloud LB)  │   │  (:30000+)   │
    └──────┬───────┘   └──────┬───────┘
           │                  │
           └────────┬─────────┘
                    ▼
           ┌──────────────┐
           │   ClusterIP  │
           │  (only pod)  │
           └──────┬───────┘
                  │
        ┌─────────┼─────────┐
        ▼         ▼         ▼
    ┌───────┐ ┌───────┐ ┌───────┐
    │ Pod 1 │ │ Pod 2 │ │ Pod 3 │
    └───────┘ └───────┘ └───────┘
```

---

## 4.2 Service Discovery

### DNS Naming

| Record Type | Format | Example |
|-------------|--------|---------|
| Service | `<service>.<namespace>.svc.cluster.local` | `my-svc.default.svc.cluster.local` |
| Pod | `<pod-ip>.<namespace>.pod.cluster.local` | `10-244-1-5.default.pod.cluster.local` |

### Short Names
```
Same namespace:      my-service
Different namespace: my-service.other-namespace
Full:                my-service.default.svc.cluster.local
```

---

## 4.3 kube-proxy

**Maintains network rules for services**

### Modes

| Mode | Mechanism | Scales To |
|------|-----------|-----------|
| **iptables** (default) | IPTables NAT rules | ~5,000 services |
| **IPVS** | Kernel IPVS load balancer | >10,000 services |
| **userspace** (legacy) | User-space proxy | Don't use |

---

## ❓ Interview Questions (25)

### Q1: What is the difference between ClusterIP, NodePort, and LoadBalancer?

**Answer:**

**ClusterIP:**
- Only accessible within cluster
- Default type
- Stable internal IP

**NodePort:**
- Exposes service on each node's IP at static port (30000-32767)
- Accessible externally via node IP
- NodePort → Service IP → Pod IP

**LoadBalancer:**
- Cloud provider provisions external load balancer
- Gets external IP
- Handles traffic distribution across nodes

### Q2: How does kube-proxy work?

**Answer:**
watches Service/Endpoint objects → updates node network rules (iptables/IPVS) → routes traffic to pods

### Q3: What is a Headless service?

**Answer:**
```yaml
spec:
  clusterIP: None  # Makes it headless
```

- No ClusterIP assigned
- DNS returns pod IPs directly
- Used for StatefulSets
- Client connects directly to pods
- Allows pod-to-pod communication

### Q4-25: [See full README for all 25 questions]

---

## ✅ Chapter Completion

Mark completed in [CHECKLIST.md](../CHECKLIST.md)

**Next:** [Chapter 5: Storage](../chapter-05/)
