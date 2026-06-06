# Chapter 10: Advanced Topics - Interview Questions

> 20+ Interview Questions with Detailed Answers

---

## Basic Level Questions

### Q1: What is a Custom Resource Definition (CRD)?

**Answer:**

**CRD:** Extends Kubernetes API with custom resources.

**Use case:** Create your own Kubernetes-like resources.

**Example:** Database as a resource
```yaml
apiVersion: example.com/v1
kind: Database
metadata:
  name: production-db
spec:
  engine: postgres
  storage: 100Gi
  replicas: 3
```

**Benefits:**
- Declarative management
- Kubernetes-native workflows
- Controller + CRD = Operator

---

### Q2: What is GitOps?

**Answer:**

**Definition:** Using Git as the single source of truth for infrastructure.

**Workflow:**
```
Git Repository
      │
      ├── manifests/
      ├── deployment.yaml
      └── service.yaml
      │
      ▼ (GitOps tool watches)
   Kubernetes
```

**Tools:** Flux, ArgoCD

**Benefits:**
- Version control
- Audit trail
- Easy rollbacks
- Collaboration

---

### Q3: What is etcd backup and why is it important?

**Answer:**

**etcd stores:** All cluster state

**Backup command:**
```bash
ETCDCTL_API=3 etcdctl snapshot save backup.db
```

**Why important:**
- Loss of etcd = Loss of cluster state
- Must restore from backup
- Required for disaster recovery

**Frequency:** Hourly/daily automated backups

---

### Q4: What is an Operator?

**Answer:**

**Operator:** Custom controller + CRDs for complex applications.

**Pattern:**
```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│     CRD      │────►│  Controller  │────►│   Resources  │
│  (Database)  │     │  (Operator)  │     │  (Pods, PVC) │
└──────────────┘     └──────────────┘     └──────────────┘
```

**Examples:**
- Prometheus Operator
- Kafka Operator
- PostgreSQL Operator

---

### Q5: What is multi-cluster management?

**Answer:**

**Tools for managing multiple clusters:**
- **Federation:** Kubernetes native (Kubefed)
- **Rancher:** Multi-cluster management UI
- **GKE Anthos:** Google multi-cloud
- **Azure Arc:** Azure multi-cloud

**Use cases:**
- Geographic distribution
- Disaster recovery
- Workload isolation

---

## Intermediate Level Questions

### Q6: How do you backup a Kubernetes cluster?

**Answer:**

**Three levels:**

1. **etcd backup:** Cluster state
```bash
ETCDCTL_API=3 etcdctl snapshot save backup.db
```

2. **Resource backup:** YAML manifests
```bash
kubectl get all --all-namespaces -o yaml > backup.yaml
```

3. **Stateful data:** Velero
```bash
velero backup create full-backup
```

**Velero backs up:**
- Kubernetes resources
- Persistent volumes (via snapshots)

---

### Q7: What is a Helm chart?

**Answer:**

**Helm:** Package manager for Kubernetes.

**Chart structure:**
```
mychart/
├── Chart.yaml
├── values.yaml
├── templates/
│   ├── deployment.yaml
│   └── service.yaml
└── charts/
```

**Usage:**
```bash
helm install myapp ./mychart
helm upgrade myapp ./mychart
helm rollback myapp 1
```

**Benefits:**
- Templating
- Versioning
- Rollbacks

---

### Q8: What is service mesh?

**Answer:**

**Definition:** Infrastructure layer for service-to-service communication.

**Features:**
- mTLS encryption
- Traffic management
- Observability
- Circuit breaking
- Retries/timeouts

**Tools:** Istio, Linkerd, Consul Connect

**Architecture:**
```
App A ──► Sidecar Proxy ──► Service Mesh Control Plane
             │                      │
             └──────────────────────┘
                        │
App B ──► Sidecar Proxy ┘
```

---

### Q9: What are container runtime interfaces?

**Answer:**

**CRI:** Standard interface between kubelet and container runtime.

**Implementations:**
- containerd (Docker uses this)
- CRI-O
- Docker (deprecated in 1.24+)

**Why CRI:**
- Pluggable runtimes
- Consistent interface
- Easy to swap

---

### Q10: What is Kubernetes API aggregation?

**Answer:**

**Purpose:** Extend API server with custom APIs.

**Use case:** Custom resources with custom API paths.

```
Standard: /apis/apps/v1/deployments
Custom: /apis/custom.example.com/v1/widgets
```

---

## Advanced Level Questions

### Q11: How do you troubleshoot a node that is NotReady?

**Answer:**

**Debug steps:**
```bash
# Check node
kubectl describe node <node>

# Check kubelet
ssh <node>
systemctl status kubelet
journalctl -u kubelet -f

# Check disk space
df -h

# Check kubelet logs
/var/log/kubelet.log

# Common causes:
# - Disk pressure
# - Memory pressure
# - PID pressure
# - Kubelet not running
# - Network issues
```

---

### Q12: What is PodPreset?

**Answer:**

**Deprecated:** Replaced by admission controllers/mutating webhooks.

**Purpose:** Automatically inject settings into pods.

**Migration:** Use mutating webhook admission controller.

---

### Q13: What is LimitRange?

**Answer:**

**Purpose:** Default and max resource limits per namespace.

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: mem-limit-range
spec:
  limits:
  - default:
      memory: 512Mi
    defaultRequest:
      memory: 256Mi
    type: Container
```

**Enforces:**
- Default resource values
- Min/max constraints

---

### Q14: What is ResourceQuota?

**Answer:**

**Purpose:** Limit aggregate resource usage per namespace.

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    pods: "100"
```

**Applies to:**
- CPU/memory
- Storage
- Object counts (pods, services)

---

### Q15: What is finalizer?

**Answer:**

**Purpose:** Prevent deletion until cleanup complete.

**How it works:**
```
User deletes object
   │
   ▼
Deletion timestamp set
   │
   ▼
Finalizer blocks deletion
   │
   ▼
Controller performs cleanup
   │
   ▼
Finalizer removed
   │
   ▼
Object deleted
```

**Example:**
```yaml
metadata:
  finalizers:
  - mycontroller.example.com/cleanup
```

---

## Scenario-Based Questions

### S1: Cluster is completely down. How do you recover?

**Answer:**

**Steps:**
1. Restore etcd from backup
2. Verify control plane components
3. Verify nodes rejoin
4. Restart workloads
5. Verify data consistency

**Prevention:**
- Regular etcd backups
- HA control plane
- Disaster recovery plan

---

### S2: Application needs to span multiple clusters.

**Answer:**

**Options:**
1. **Federation:** Kubernetes Federation v2
2. **Service mesh:** Istio multi-cluster
3. **DNS:** Global load balancing
4. **Tool:** Submariner, Skupper

**Considerations:**
- Latency between clusters
- Data synchronization
- Failover strategy

---

## Quick Reference

| Tool | Purpose |
|------|---------|
| Velero | Backup/restore |
| Helm | Package management |
| Istio | Service mesh |
| Flux/ArgoCD | GitOps |

---

## Key Takeaways

1. **CRD:** Extend Kubernetes API
2. **Operator:** CRD + Controller
3. **GitOps:** Git as source of truth
4. **Velero:** Backup and restore
5. **etcd backup:** Critical for recovery
6. **Helm:** Package management
7. **Service mesh:** Advanced networking

---

## Final Checklist

| Topic | Covered |
|-------|---------|
| Architecture | ✅ |
| Pods | ✅ |
| Workloads | ✅ |
| Networking | ✅ |
| Storage | ✅ |
| Configuration | ✅ |
| Observability | ✅ |
| Scheduling | ✅ |
| Security | ✅ |
| Advanced | ✅ |

---

## You're Ready! 🎉

Review all interview questions before your interview.

**Previous:** [Chapter 9 Interview Questions](../chapter-09/INTERVIEW.md)  
**Complete!** Good luck with your Kubernetes interviews!
