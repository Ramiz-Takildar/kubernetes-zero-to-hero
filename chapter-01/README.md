# Chapter 1: Kubernetes Architecture

## 📚 Learning Objectives

By the end of this chapter, you will:
- Master Kubernetes control plane architecture
- Understand how the API Server processes requests
- Learn etcd's role as the single source of truth
- Explain scheduler algorithms and decision-making
- Understand the reconciliation loop concept
- Configure high availability for control plane components

**Prerequisites:** Basic Linux, container concepts  
**Estimated Time:** 2 days  
**Labs:** 4 hands-on exercises

---

## 🏗️ Architecture Overview

### The Big Picture

Kubernetes follows a master-worker architecture. The control plane (master) manages the cluster state, while worker nodes run your applications.

```
                    ┌─────────────────────────────────────┐
                    │         CONTROL PLANE               │
                    │    (Usually 3+ nodes for HA)        │
                    │                                     │
                    │  ┌─────────────┐   ┌─────────────┐ │
                    │  │ API Server  │   │   etcd      │ │
                    │  │ (Kube-api)  │◄─►│ (Database)  │ │
                    │  └──────┬──────┘   └─────────────┘ │
                    │         │                         │
                    │  ┌──────┴──────┐   ┌─────────────┐ │
                    │  │  Scheduler  │   │ Controller  │ │
                    │  │             │   │  Manager    │ │
                    │  └─────────────┘   └─────────────┘ │
                    └──────────┬──────────────────────────┘
                               │
              ┌────────────────┼────────────────┐
              │                │                │
              ▼                ▼                ▼
    ┌─────────────────────────────────────────────────────┐
    │                  WORKER NODES                       │
    │                                                     │
    │  ┌────────────────┐  ┌────────────────┐            │
    │  │    Node 1      │  │    Node 2      │            │
    │  │                │  │                │            │
    │  │  ┌──────────┐  │  │  ┌──────────┐  │            │
    │  │  │ Kubelet  │  │  │  │ Kubelet  │  │            │
    │  │  └────┬─────┘  │  │  └────┬─────┘  │            │
    │  │  ┌────┴─────┐  │  │  ┌────┴─────┐  │            │
    │  │  │ Container│  │  │  │ Container│  │            │
    │  │  │ Runtime  │  │  │  │ Runtime  │  │            │
    │  │  └──────────┘  │  │  └──────────┘  │            │
    │  │  ┌──────────┐  │  │  ┌──────────┐  │            │
    │  │  │Kube-proxy│  │  │  │Kube-proxy│  │            │
    │  │  └──────────┘  │  │  └──────────┘  │            │
    │  └────────────────┘  └────────────────┘            │
    └─────────────────────────────────────────────────────┘
```

---

## 🔧 Control Plane Components Deep Dive

### 1. API Server (kube-apiserver)

**Role:** The brain's receptionist - all communication goes through here.

**Key Responsibilities:**
- **Authentication:** Verifies who you are (certificates, tokens, OIDC)
- **Authorization:** Checks if you're allowed (RBAC, ABAC, Webhook)
- **Validation:** Ensures your YAML is valid
- **Admission Control:** Mutates or validates requests (security policies, quotas)
- **REST API:** Exposes Kubernetes API over HTTPS

**Request Flow:**
```
kubectl apply → API Server → AuthN → AuthZ → Admission → etcd
```

**Scaling:**
- Horizontally scalable (run multiple instances)
- Stateless (all data in etcd)
- Behind a load balancer for HA

**Interview Gold:**
> "When you run kubectl apply, the API Server authenticates you, checks RBAC permissions, runs through admission controllers like ResourceQuota and PodSecurityPolicy, validates the schema, and finally writes to etcd."

---

### 2. etcd - The Single Source of Truth

**What is etcd?**
- Distributed key-value store
- Uses Raft consensus algorithm
- Stores ALL cluster state
- Only API Server talks to etcd

**Data Structure:**
```
/registry/pods/default/my-pod
/registry/deployments/production/api
/registry/secrets/default/db-password
/registry/nodes/worker-1
```

**Critical Concepts:**
- **Consistency:** All API servers see same data
- **Watch:** Uses long-polling for real-time updates
- **Revision:** Every change increments a version number
- **Compaction:** Old revisions removed to save space

**Production Considerations:**
- **Backups Essential:** Loss of etcd = loss of cluster
- **SSD Required:** Disk I/O critical for performance
- **3+ Nodes:** Odd number for quorum (3, 5, 7)
- **Network Latency:** < 10ms between etcd nodes

**Backup Strategy:**
```bash
# Automated backup (every 6 hours)
# See Lab 1.1 for production CronJob
```

---

### 3. Scheduler (kube-scheduler)

**The Matchmaker:** Decides which node runs each pod.

**Two-Phase Algorithm:**

#### Phase 1: Filtering (Remove Unsuitable Nodes)
```
                ┌──────────────────────────────┐
                │   All Nodes (10 nodes)       │
                └──────────────┬───────────────┘
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
   Filter:               Filter:               Filter:
   DiskPressure        Insufficient CPU      Taint Mismatch
        │                      │                      │
        ▼                      ▼                      ▼
┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│ Node 1       │      │ Node 4       │      │ All Others   │
│ ❌ Disk Full │      │ ❌ CPU Low   │      │ ✅ Possible  │
└──────────────┘      └──────────────┘      └──────────────┘
                               
                ┌──────────────────────┐
                │ 3 Nodes Remaining    │
                │ (Node 2, 3, 5)       │
                └──────────┬───────────┘
                           │
                           ▼
```

**Filtering Criteria:**
- Resource requirements (CPU/memory)
- Node selectors and affinity
- Taints and tolerations
- Volume availability
- Hardware/software constraints

#### Phase 2: Scoring (Rank Remaining Nodes)

Each node gets a score (0-100). Highest score wins.

**Scoring Factors:**
| Factor | Weight | Description |
|--------|--------|-------------|
| Least Resource | 10 | Nodes with most available resources |
| Node Affinity | 8 | Matching node labels |
| Inter-pod Affinity | 5 | Pods that should be together |
| Image Locality | 2 | Node already has image |

**Example Decision:**
```
Node A: Score 85 (most free CPU, image cached)
Node B: Score 60 (moderate resources)
Node C: Score 45 (nearly full)

→ Pod scheduled on Node A
```

---

### 4. Controller Manager (kube-controller-manager)

**The Conductor:** Runs multiple controllers in a single process.

**What is a Controller?**
A loop that watches the desired state and makes reality match it.

```
┌─────────────┐
│   Watch     │◄── etcd changes
│    API      │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  Compare    │
│ Desired vs  │
│   Actual    │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Act       │
│  (Create/   │
│  Delete)    │
└─────────────┘
```

**Key Controllers:**

| Controller | Monitors | Action When Needed |
|------------|----------|-------------------|
| **Deployment** | Deployment objects | Creates/updates ReplicaSets |
| **ReplicaSet** | Pod count | Creates/deletes pods |
| **Node** | Node status | Marks nodes unhealthy |
| **Endpoint** | Service + Pods | Updates service endpoints |
| **Service Account** | Namespace | Creates default SA |

**Example - ReplicaSet Controller:**
1. User: Set replicas to 3
2. etcd: Now stores desired=3
3. Controller: Sees 2 pods running
4. Controller: Creates 1 more pod
5. Controller: Watches continuously

---

## 🖥️ Node Components

### Kubelet - The Node Agent

**Responsibilities:**
1. **Registration:** Registers node with API server
2. **Pod Lifecycle:** Creates/destroys containers (via CRI)
3. **Health Reporting:** Reports node and pod status
4. **Volume Mounting:** Mounts volumes for pods
5. **Secret/ConfigMap:** Makes configs available

**Communication:**
```
Kubelet ←──(HTTPS)──→ API Server
   │
   └──(CRI)──→ Container Runtime (containerd/CRI-O)
```

**Important:** If kubelet fails, pods continue running but no new pods are scheduled.

---

### Kube-proxy - Network Proxy

**Purpose:** Implements Kubernetes Service networking.

**Modes:**

| Mode | Mechanism | Pros | Cons |
|------|-----------|------|------|
| **IPTables** (default) | NAT rules via iptables | Universal | O(n) rules |
| **IPVS** | Kernel load balancer | Fast O(1) | Needs kernel module |
| **Userspace** | Userspace proxy | Portable | Slow |

**How It Works (IPTables Mode):**
```
Service IP (10.96.0.1:80)
         │
    Kube-proxy iptables rule
         │
    ┌────┴────┐
    │         │
 Pod IP:1   Pod IP:2
 :8080      :8080
```

---

## 📊 Request Flow Deep Dive

When you run `kubectl apply -f deployment.yaml`:

```
Step 1: kubectl
   - Validates YAML locally (client-side validation)
   - Reads ~/.kube/config for cluster credentials
   - Converts YAML to JSON

Step 2: API Server (kube-apiserver)
   ├─ Authenticates request (cert/token)
   ├─ Authorization check (RBAC)
   ├─ Admission Controllers:
   │  ├─ NamespaceLifecycle (namespace exists?)
   │  ├─ LimitRanger (resource limits ok?)
   │  ├─ ServiceAccount (inject SA if missing)
   │  ├─ ResourceQuota (quota not exceeded?)
   │  └─ PodSecurityPolicy (pod allowed?)
   ├─ Validation (schema valid?)
   └─ Writes to etcd

Step 3: etcd
   - Stores JSON representation
   - Increments resource version
   - Triggers watch notifications

Step 4: Controllers (Deployment Controller)
   - Watches for new Deployment
   - Creates ReplicaSet
   - Watches and reacts

Step 5: Scheduler
   - Sees pod with no node assigned
   - Runs filtering/scoring
   - Binds pod to node

Step 6: Kubelet (on selected node)
   - Notices pod assigned to its node
   - Pulls container image
   - Starts containers
   - Mounts volumes
   - Configures networking

Step 7: Kube-proxy
   - Updates iptables for Service endpoints

Step 8: Status Updates
   - Container runtime reports status
   - Kubelet reports to API Server
   - API Server updates etcd
   - kubectl shows "Running"
```

**Total Latency:** Typically 1-5 seconds for pod startup

---

## 🔄 The Reconciliation Loop

This is the fundamental concept of Kubernetes.

### Concept
```
Desired State ───────┐
   (etcd)            │
     ▲               │
     │ Watch         │ Controller
     │               │ Loop
┌────┴───────────┐   │
│   Actual State │◄──┘
│   (reality)    │
└────┬───────────┘
     │
     │ Observe
     ▼
┌────────────┐
│   Diff?    │ No → Sleep
│            │ Yes → Action
└────┬───────┘
     │
     ▼
┌────────────┐
│   Act      │
│(Create/Del)│
└────────────┘
```

### Example: Deployment Reconciliation

**Initial State:**
- Desired: 3 replicas
- Actual: 0 pods

**Iteration 1:**
- Diff: Need 3 pods
- Act: Create 3 pods
- Actual: 3 pods

**Pod Dies (node fails):**
- Desired: 3
- Actual: 2

**Iteration 2:**
- Diff: Need 1 more
- Act: Create 1 pod
- Actual: 3 pods

**Self-Healing achieved!**

---

## 🎯 Preparing for the Labs

### Lab 1.1: etcd Backup
**Theory Applied:**
- etcd as the cluster database
- Backup importance for disaster recovery
- CronJobs for automation

### Lab 1.2: API Server Monitoring
**Theory Applied:**
- API Server as entry point
- Health endpoints (/healthz, /livez, /readyz)
- Authentication flow

### Lab 1.3: Controller Manager
**Theory Applied:**
- Controller reconciliation loops
- Self-healing behavior
- ReplicaSet management

### Lab 1.4: Scheduler
**Theory Applied:**
- Node selection algorithm
- QoS classes (Guaranteed, Burstable, BestEffort)
- Resource requests and limits

---

## 📖 Key Takeaways

1. **API Server** is the gateway - everything flows through it
2. **etcd** is the truth - protect it with backups
3. **Scheduler** is the matchmaker - finds the right node
4. **Controllers** are the janitors - constantly fixing things
5. **Kubelet** is the executor - does the actual work
6. **Reconciliation Loop** is the magic - self-healing by default

---

## ❓ Interview Questions Explained

### Q1: What happens when you run `kubectl apply`?

**Detailed Answer:**

1. **Client Side:** kubectl validates YAML, converts to JSON, figures out which API endpoint to call
2. **Authentication:** API Server validates your certificate/token
3. **Authorization:** Checks RBAC - can you create Deployments in this namespace?
4. **Admission:** 
   - Mutating webhooks may modify your request (inject sidecars)
   - Validating webhooks check policies
5. **Validation:** JSON schema validation
6. **Persistence:** Written to etcd with new resourceVersion
7. **Reaction:**
   - Deployment controller sees it, creates ReplicaSet
   - ReplicaSet controller sees it, creates Pods
   - Scheduler sees unscheduled pods, assigns nodes
   - kubelet starts containers

**Key Interview Phrases:**
- "Admission controllers can modify or reject requests"
- "etcd is the source of truth, everything else reacts to it"
- "The pattern is watch → compare → act"

---

## 🔗 Next Steps

1. Read the theory above ⬆️
2. Complete [Lab 1.1](./LABS.md#lab-11-high-availability-control-plane-setup)
3. Answer the interview questions at the end of each lab
4. Track progress in [CHECKLIST.md](../CHECKLIST.md)

**Next Chapter:** [Chapter 2: Pods & Containers](../chapter-02/)
