# Chapter 1: Kubernetes Architecture - Interview Questions

> 20+ Interview Questions with Detailed Answers

---

## Basic Level Questions

### Q1: What is Kubernetes and why do we need it?

**Answer:**
Kubernetes is an open-source container orchestration platform that automates the deployment, scaling, and management of containerized applications.

**Why we need it:**
- **Self-healing:** Automatically restarts failed containers
- **Scaling:** Horizontal scaling based on demand
- **Load balancing:** Distributes traffic across containers
- **Storage orchestration:** Mounts storage automatically
- **Automated rollouts/rollbacks:** Updates with zero downtime
- **Service discovery:** Built-in DNS and load balancing

**Real-world analogy:** Kubernetes is like a data center operating system. Just as Linux manages processes on one machine, Kubernetes manages containers across many machines.

---

### Q2: Explain the Kubernetes architecture with all components.

**Answer:**

**Control Plane (Master):**
- **API Server:** Front-end for Kubernetes API, handles all requests
- **etcd:** Distributed key-value store for cluster state
- **Scheduler:** Assigns pods to nodes based on resources
- **Controller Manager:** Runs controllers (deployment, replica set, etc.)

**Worker Nodes:**
- **Kubelet:** Agent that runs on each node, manages containers
- **Container Runtime:** Docker/containerd to run containers
- **Kube-proxy:** Manages network rules for services

**Request Flow:**
```
kubectl apply → API Server → Authentication → Authorization → etcd
                                          ↓
                                   Scheduler (if new pod)
                                          ↓
                                   Kubelet (on assigned node)
                                          ↓
                                   Container Runtime
```

---

### Q3: What is etcd and why is it critical?

**Answer:**

**What is etcd:**
- Distributed key-value database
- Stores cluster configuration and state
- Uses Raft consensus algorithm

**Why critical:**
- **Single source of truth:** All cluster state stored here
- **If etcd fails:** Entire cluster becomes read-only
- **If etcd lost:** Must restore from backup or rebuild cluster
- **Only API Server talks to etcd:** No other component accesses it directly

**Storage structure:**
```
/registry/pods/default/my-pod
/registry/deployments/production/api
/registry/secrets/default/password
```

**Backup command:**
```bash
ETCDCTL_API=3 etcdctl snapshot save backup.db
```

---

### Q4: What happens when you run kubectl apply?

**Answer:**

**Step-by-step:**

1. **kubectl validation:** Validates YAML locally
2. **REST API call:** Converts to JSON, sends to API Server
3. **Authentication:** Verifies identity (certificates, tokens)
4. **Authorization:** Checks RBAC permissions
5. **Admission Controllers:**
   - Mutating webhooks (modify requests)
   - Validating webhooks (policy checks)
6. **Validation:** Schema validation
7. **etcd write:** Stores desired state
8. **Watch events:** Controllers notified
9. **Reconciliation:** Controllers take action
10. **Scheduler:** Assigns node (for pods)
11. **Kubelet:** Creates containers
12. **Status updates:** Reports back to API Server

**Timeline:** ~1-5 seconds for pod startup

---

### Q5: What is the reconciliation loop?

**Answer:**

**Concept:**
Controllers continuously compare desired state (in etcd) with actual state (in cluster) and take action to make them match.

**Example with ReplicaSet:**
```
Desired: 3 pods
Actual:  2 pods
Diff:    -1
Action:  Create 1 pod

Desired: 3 pods
Actual:  3 pods
Diff:    0
Action:  No action

Desired: 3 pods
Actual:  2 pods (1 died)
Diff:    -1
Action:  Create 1 pod (self-healing)
```

**Key characteristic:** Continuous loop - never stops watching

---

## Intermediate Level Questions

### Q6: How does the Kubernetes scheduler decide which node to place a pod?

**Answer:**

**Two-phase algorithm:**

**Phase 1: Filtering (remove unsuitable nodes)**
- Resource availability (CPU/memory)
- Node selectors
- Taints and tolerations
- Volume availability
- Affinity rules

**Phase 2: Scoring (rank remaining nodes)**
- Resource utilization
- Node affinity
- Pod affinity
- Image locality (already has image)

**Example:**
```
10 nodes available
Node 1: Insufficient CPU ❌
Node 2: Disk pressure ❌
Node 3: Taint mismatch ❌
Nodes 4-10: Passed filtering ✅

Scoring:
Node 4: Score 85 (most free resources)
Node 5: Score 60
→ Pod scheduled on Node 4
```

---

### Q7: What is the difference between a control plane and data plane?

**Answer:**

| Control Plane | Data Plane |
|---------------|------------|
| Makes decisions | Executes decisions |
| API Server, etcd, Scheduler, Controller Manager | Kubelet, Kube-proxy, Container Runtime |
| Brain of cluster | Muscles of cluster |
| Can be replicated for HA | Runs on every node |

**Traffic flow:**
- Control plane: Decides what should run where
- Data plane: Actually runs the workloads

---

### Q8: Explain kube-proxy modes (iptables vs IPVS).

**Answer:**

| Mode | Mechanism | Pros | Cons |
|------|-----------|------|------|
| **iptables** (default) | NAT rules | Universal support | O(n) latency, limited to 5K services |
| **IPVS** | Kernel load balancer | Fast O(1), supports 100K+ services | Requires kernel module |
| **userspace** (legacy) | Userspace proxy | Portable | Slow, extra hop |

**iptables flow:**
```
Service IP → iptables DNAT → Pod IP
```

**IPVS flow:**
```
Service IP → IPVS load balancer → Pod IP
```

**Switch to IPVS:**
```yaml
mode: "ipvs"
ipvs:
  scheduler: "rr"  # round-robin
```

---

### Q9: How does high availability work in Kubernetes?

**Answer:**

**Control Plane HA:**
- **API Server:** Run multiple instances behind load balancer
- **etcd:** Run 3 or 5 nodes (odd number for quorum)
- **Scheduler/Controller Manager:** Run active-passive (use leader election)

**Worker Node HA:**
- Pods automatically rescheduled if node fails
- Use multiple worker nodes across availability zones
- Use Pod Disruption Budgets during maintenance

**Stacked vs External etcd:**
- **Stacked:** etcd runs on control plane nodes (simpler)
- **External:** etcd runs on separate nodes (more resilient)

---

### Q10: What is an admission controller?

**Answer:**

**Purpose:** Intercept requests to API Server and modify or validate them.

**Types:**
- **Mutating:** Can modify requests (add sidecars, inject defaults)
- **Validating:** Can only reject requests (policy enforcement)

**Common admission controllers:**
- **NamespaceLifecycle:** Prevents deleting active namespaces
- **LimitRanger:** Applies default resource limits
- **ResourceQuota:** Enforces namespace quotas
- **PodSecurityPolicy:** Security policy enforcement
- **DefaultStorageClass:** Adds default storage class to PVCs

**Order:** Mutating → Validating

---

## Advanced Level Questions

### Q11: What happens if the API Server goes down?

**Answer:**

**Immediate impact:**
- No new deployments/pods can be created
- No configuration changes possible
- kubectl commands fail

**What continues to work:**
- Existing pods keep running
- Node-level operations (kubelet)
- Pod-to-pod communication
- Service routing

**Recovery:**
- If HA setup: Traffic routes to other API servers
- If single node: Restore API server or promote another node

**Key point:** API Server is stateless; data is in etcd

---

### Q12: How do you backup and restore etcd?

**Answer:**

**Backup:**
```bash
# Single command
ETCDCTL_API=3 etcdctl snapshot save backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Verify backup
ETCDCTL_API=3 etcdctl  snapshot status backup.db
```

**Restore:**
```bash
# Stop etcd
systemctl stop etcd

# Restore snapshot
ETCDCTL_API=3 etcdctl snapshot restore backup.db \
  --data-dir=/var/lib/etcd-restored

# Update etcd config to use new data dir
# Start etcd
systemctl start etcd
```

**Production:** Use automated CronJob (see Lab 1.1)

---

### Q13: Explain the watch mechanism in Kubernetes.

**Answer:**

**Concept:** Instead of polling, controllers use long-lived connections to watch for changes.

**How it works:**
```
1. Controller opens HTTP watch connection to API Server
2. Connection stays open
3. When change occurs in etcd:
   - API Server notified by etcd
   - API Server pushes change to watching controllers
4. Controllers react immediately
```

**Benefits:**
- Real-time reactions (no polling delay)
- Reduced load on API Server
- Scalable (thousands of watchers)

**Implementation:** HTTP chunked encoding (text/event-stream)

---

### Q14: What is resource versioning in etcd?

**Answer:**

**resourceVersion:** A string that identifies the internal version of any Kubernetes object.

**Purposes:**
- **Optimistic concurrency control:** Prevent conflicts during updates
- **Watch bookmark:** Resume watching from specific point
- **Cache invalidation:** Know when to refresh cached data

**Example:**
```yaml
metadata:
  resourceVersion: "12345"
```

**Conflict resolution:**
```
User A reads object (rv=100)
User B reads object (rv=100)
User A updates object (rv=101)
User B tries to update with rv=100 → CONFLICT → Must retry
```

---

### Q15: How do you troubleshoot a control plane issue?

**Answer:**

**Step 1: Check component health**
```bash
kubectl get componentstatuses
kubectl get nodes
```

**Step 2: Check pod status in kube-system**
```bash
kubectl get pods -n kube-system
```

**Step 3: Check logs**
```bash
kubectl logs -n kube-system kube-apiserver-<node>
kubectl logs -n kube-system kube-scheduler-<node>
kubectl logs -n kube-system kube-controller-manager-<node>
```

**Step 4: Check etcd**
```bash
kubectl exec -n kube-system etcd-<node> -- etcdctl endpoint health
```

**Step 5: Check certificates**
```bash
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -text -noout
check expiration dates
```

---

## Scenario-Based Questions

### S1: Your etcd cluster is full. How do you fix it?

**Answer:**

**Problem:** etcd has default 2GB limit, compaction needed.

**Solution:**
```bash
# Compact old revisions
ETCDCTL_API=3 etcdctl compact $(ETCDCTL_API=3 etcdctl endpoint status --write-out="json" | egrep -o '"revision":[0-9]*' | egrep -o '[0-9].*')

# Defragment
ETCDCTL_API=3 etcdctl defrag

# Enable auto-compaction
etcd --auto-compaction-retention=1
```

---

### S2: API Server is responding slowly. Debug steps?

**Answer:**

1. **Check etcd latency:** Is etcd the bottleneck?
2. **Check admission controllers:** Are any slow?
3. **Increase API Server replicas:** Add more instances
4. **Check audit logs:** Are there spammy clients?
5. **Enable API priority and fairness:** Protect API server from overload
6. **Check authentication webhooks:** Are they slow?

---

## Quick Reference

| Component | If Fails | Impact |
|-----------|----------|--------|
| API Server | Down | Read-only cluster |
| etcd | Down | Read-only cluster |
| Scheduler | Down | New pods not scheduled |
| Controller Manager | Down | Self-healing stops |
| Kubelet | Down | Node marked NotReady |

---

## Key Takeaways

1. **etcd = Source of truth:** Protect it with backups
2. **Control Plane = Brain:** Needs redundancy
3. **Reconciliation = Magic:** Self-healing by design
4. **Scheduler = Matchmaker:** Finds best node for pod
5. **Watch = Efficient:** No polling needed

---

**Next:** [Chapter 2 Interview Questions](../chapter-02/INTERVIEW.md)
