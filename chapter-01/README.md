# Chapter 1: Kubernetes Architecture

## 📚 Learning Objectives

By the end of this chapter, you will:
- Understand all Control Plane components
- Understand all Node components
- Know how requests flow through the system
- Understand etcd's role
- Explain the reconciliation loop

**Estimated Time:** 2 days

---

## 1.1 Control Plane Components

### API Server (kube-apiserver)

**What it does:**
- Front-end for Kubernetes API
- Validates and processes all REST requests
- Serves as the central communication hub

**Key Points:**
```
All communication → API Server → Other components
                         ↑
                    etcd (data store)
```

**Interview Focus:**
- Single entry point to cluster
- Authentication & Authorization happens here
- Rate limiting and admission control
- Can be scaled horizontally for HA

### etcd

**What it does:**
- Distributed key-value store
- Stores ALL cluster state and configuration
- Only component that talks directly to storage

**Key Commands:**
```bash
# Check etcd pods
kubectl get pods -n kube-system | grep etcd

# Backup etcd
ETCDCTL_API=3 etcdctl snapshot save backup.db

# Restore etcd
ETCDCTL_API=3 etcdctl snapshot restore backup.db
```

**Critical Interview Points:**
- Only API server talks to etcd
- Must be backed up regularly
- Corruption = cluster failure
- Uses Raft consensus algorithm

### Scheduler (kube-scheduler)

**What it does:**
- Watches for unassigned pods
- Determines which node runs which pod

**Scheduling Algorithm:**
1. **Filtering:** Remove nodes that don't fit
   - Resource availability
   - Node selectors
   - Taints/tolerations
   - Affinity rules

2. **Scoring:** Rank remaining nodes
   - Resource utilization
   - Affinity weights
   - Inter-pod affinity

**Customize Scheduler:**
```yaml
apiVersion: v1
kind: Pod
spec:
  schedulerName: my-custom-scheduler
```

### Controller Manager

**What it does:**
- Runs various controllers in a loop
- Each controller watches specific resources

**Key Controllers:**
| Controller | Watches | Does |
|------------|---------|------|
| Node Controller | Node status | Responds to node failure |
| Replication Controller | Pods | Maintains correct pod count |
| Endpoints Controller | Services/Pods | Links services to pods |
| Service Account Controller | SAs | Creates default service accounts |

---

## 1.2 Node Components

### Kubelet

**What it does:**
- Agent running on every node
- Ensures containers are running in pods
- Reports node and pod status to API server

**Key Operations:**
- Pod spec received from API server
- Talks to container runtime via CRI
- Mounts volumes
- Executes probes

**Interview Point:**
```
If kubelet fails → Pods on that node become orphaned
Pod continues running but no status updates
```

### Container Runtime

**Options:**
- **containerd** (Docker uses this internally)
- **CRI-O** (Red Hat preferred)
- **Docker** (deprecated in K8s 1.24+)

**Interface:** CRI (Container Runtime Interface)

### Kube-proxy

**What it does:**
- Maintains network rules for services
- Enables service abstraction

**Modes:**
| Mode | How it works |
|------|--------------|
| iptables (default) | IPTables rules for routing |
| IPVS | Kernel-level load balancing |
| userspace | Legacy mode (rarely used) |

---

## 1.3 Request Flow

```
User runs: kubectl apply -f pod.yaml

    ↓
┌─────────────────┐
│   kubectl       │ ← Validates YAML, sends to API Server
└────────┬────────┘
         ↓
┌─────────────────┐
│   API Server    │ ← Authenticates user, validates request
└────────┬────────┘
         ↓
┌─────────────────┐
│      etcd       │ ← Stores the desired state
└────────┬────────┘
         ↓ (Controllers watch for changes)
┌─────────────────┐
│   Scheduler     │ ← Assigns node to unassigned pod
└────────┬────────┘
         ↓
┌─────────────────┐
│     Kubelet     │ ← On assigned node, creates pod
└────────┬────────┘
         ↓
┌─────────────────┐
│ Container Runtime│ ← Pulls image, starts container
└─────────────────┘
```

---

## 1.4 The Reconciliation Loop

**Core Principle:**
```
Desired State (in etcd) ←──→ Actual State (in cluster)
                                  ↑
                            Controller makes
                            them match
```

**Example:**
1. User creates Deployment with 3 replicas
2. Desired state: 3 pods
3. Controller sees 0 pods
4. Controller creates 3 pods
5. Controller continuously checks: "Do we have 3 pods?"
6. If pod dies → Controller creates new one

---

## 💻 Hands-On

```bash
# Check control plane pods
kubectl get pods -n kube-system

# Check node components
systemctl status kubelet

# View API server logs
kubectl logs -n kube-system kube-apiserver-<node>

# Check kube-proxy mode
kubectl get configmap kube-proxy -n kube-system -o yaml | grep mode
```

---

## ❓ Interview Questions (15)

### Q1: What happens when you run `kubectl apply`?

**Answer:**
1. kubectl validates YAML locally
2. Converts to JSON, sends POST/PUT to API Server
3. API Server authenticates & authorizes request
4. Admission controllers modify/validate request
5. Request stored in etcd
6. Controllers watch for changes via API Server
7. Scheduler assigns node (if needed)
8. Kubelet creates pod on node
9. Container runtime starts containers
10. Status reported back to API Server

---

### Q2: Explain etcd architecture and why it's critical

**Answer:**
- Distributed key-value store using Raft consensus
- Stores cluster state, configuration, secrets
- Only API Server communicates with etcd
- **Single source of truth**
- **If etcd is lost → cluster is lost**
- Regular backups essential
- Should run on dedicated, fast storage (SSD)

---

### Q3: How does the scheduler decide which node to place a pod?

**Answer:**

Two-phase process:

**1. Filtering:** Eliminate unsuitable nodes
- Resource requirements (CPU, memory)
- Node selectors
- Taints and tolerations
- Hardware/software constraints

**2. Scoring:** Rank remaining nodes
- Least requested resources gets higher score
- Affinity rules add points
- Pod spread adds points

Highest scoring node wins.

---

### Q4: What is the reconciliation loop?

**Answer:**
The continuous process where controllers ensure the **actual state** matches the **desired state** stored in etcd.

Example: Deployment controller constantly checks pod count. If a pod dies, it creates a new one. If too many exist, it removes extras.

---

### Q5: Control plane vs Data plane

**Answer:**

| Control Plane | Data Plane |
|---------------|------------|
| Makes decisions | Executes decisions |
| API Server, etcd, Scheduler, Controller Manager | kubelet, kube-proxy, Container Runtime |
| Can be replicated for HA | Runs on every worker node |
| Brain of the cluster | Muscles of the cluster |

---

### Q6: What happens when control plane node fails?

**Answer:**
Depends on setup:

**Single control plane:**
- No new pods can be scheduled
- Existing pods continue running
- Cannot make changes to cluster

**Multi-node HA control plane:**
- etcd quorum maintained (majority up)
- Other API servers take over
- Cluster continues operating

---

### Q7: Explain API Server authentication flow

**Answer:**
1. Client presents credentials (cert, token, etc.)
2. API Server validates against configured auth method
3. If valid, determines username
4. Authorization: Check RBAC/ABAC for permissions
5. Admission: Mutating webhooks modify request
6. Validating webhooks check request
7. Store in etcd

---

### Q8: How are resources stored in etcd?

**Answer:**
As key-value pairs with prefixed paths:
```
/registry/pods/default/my-pod
/registry/deployments/default/my-deploy
/registry/secrets/default/my-secret
```

Values are JSON-encoded resource objects.

---

### Q9: Explain kube-proxy modes

**Answer:**

| Mode | Mechanism | Pros | Cons |
|------|-----------|------|------|
| **iptables** | iptables rules | Works everywhere | Large clusters = slow, O(n) rules |
| **IPVS** | Kernel load balancer | Fast, O(1) lookups | Requires ipvs kernel module |
| **userspace** | Userspace proxy | Legacy, portable | Slow, extra hop |

---

### Q10: What happens if etcd fails?

**Answer:**
- Cluster becomes read-only
- Cannot create/update/delete resources
- Existing pods continue running
- Kubelet doesn't receive updates

**Recovery:** Restore from backup on new etcd cluster.

---

### Q11: How to backup and restore etcd?

**Answer:**

**Backup:**
```bash
ETCDCTL_API=3 etcdctl snapshot save backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

**Restore:**
```bash
ETCDCTL_API=3 etcdctl snapshot restore backup.db \
  --data-dir=/var/lib/etcd-restore
# Update etcd to use new data-dir
```

---

### Q12: How to set up HA control plane?

**Answer:**
- Minimum 3 control plane nodes (for etcd quorum)
- Stacked topology: etcd runs on control plane nodes
- External topology: etcd runs on separate nodes
- Use load balancer in front of API servers
- All kubelets connect to LB endpoint

---

### Q13: What is resource versioning in etcd?

**Answer:**
Each resource has a `resourceVersion` field. Used for:
- Optimistic concurrency control
- Watch mechanism to detect changes
- Prevents updates based on stale data

---

### Q14: Explain the Watch mechanism

**Answer:**
API Server provides watch endpoint for real-time notifications.

**Flow:**
1. Controller opens watch connection to API Server
2. API Server watches etcd for changes
3. Change occurs → etcd notifies API Server
4. API Server streams change to controller
5. Controller reacts (reconciliation)

**Benefit:** Efficient - no polling needed.

---

### Q15: What are Admission Controllers?

**Answer:**
Plugins that intercept requests to API Server.

**Types:**
- **Mutating:** Modify requests (add defaults, inject sidecars)
- **Validating:** Reject invalid requests

**Common controllers:**
- NamespaceLifecycle
- LimitRanger
- ServiceAccount
- DefaultStorageClass
- ResourceQuota
- PodSecurityPolicy

---

## ✅ Chapter Completion

Mark completed in [CHECKLIST.md](../CHECKLIST.md):
- [ ] All theory sections read
- [ ] All 15 interview questions reviewed
- [ ] Hands-on commands executed
- [ ] Can whiteboard architecture diagram

**Next:** [Chapter 2: Pods & Containers](../chapter-02/)
