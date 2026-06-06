# Chapter 2: Pods & Containers

## 📚 Learning Objectives

By the end of this chapter, you will:
- Understand the Pod abstraction and its lifecycle
- Master multi-container patterns (sidecar, init, ambassador)
- Configure resource requests, limits, and QoS classes
- Debug common pod issues (CrashLoopBackOff, OOMKilled, ImagePullBackOff)
- Use security contexts and harden containers
- Implement init containers for startup workflows

**Estimated Time:** 3 days  
**Labs:** 6 hands-on exercises  
**Prerequisites:** Chapter 1 (Architecture)

---

## 📦 What is a Pod?

### Concept
A Pod is the **smallest deployable unit** in Kubernetes. It represents a single instance of a running process in your cluster.

### Anatomy of a Pod

```
┌─────────────────────────────────────────────┐
│                    POD                      │
│           (Single IP Address)               │
│                                             │
│  ┌───────────────────────────────────────┐  │
│  │  Shared Resources:                    │  │
│  │  • Network namespace (IP, ports)      │  │
│  │  • Storage volumes                    │  │
│  │  • IPC namespace                      │  │
│  │  • UTS namespace (hostname)           │  │
│  └───────────────────────────────────────┘  │
│                                             │
│  ┌────────────┐     ┌────────────┐         │
│  │ Container 1│     │ Container 2│         │
│  │ :8080      │◄───►│ :9090      │         │
│  │ (main app) │     │ (sidecar)  │         │
│  └────────────┘     └────────────┘         │
│                                             │
│  ┌────────────┐     ┌────────────┐         │
│  │ Volume A   │     │ Volume B   │         │
│  │ (shared)   │     │ (config)   │         │
│  └────────────┘     └────────────┘         │
│                                             │
└─────────────────────────────────────────────┘
```

**Key Insight:** Containers in the same Pod share:
- **Network:** Same IP, localhost communication
- **Storage:** Shared volumes
- **Lifecycle:** Created/destroyed together
- **Resources:** CPU/memory limits apply to Pod total

### Why Not Just Containers?

| Container Alone | With Pod |
|-----------------|----------|
| No shared storage | Shared volumes |
| No localhost communication | Same network namespace |
| No atomic deployment | All-or-nothing deployment |
| No unified management | Single management unit |

**Use Case Example:** A web server + log shipper need shared logs and localhost communication.

---

## 🔄 Pod Lifecycle

### Pod States (Phases)

```
┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
│ Pending  │──►│ Running  │──►│ Succeeded│   │  Failed  │   │ Unknown  │
│          │   │          │   │          │   │          │   │          │
│ Scheduled│   │ Container│   │ All      │   │ One+     │   │ Cant     │
│ Starting │   │ Running  │   │ Completed│   │ Failed   │   │ Determine│
└──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘
       │                                                           
       ▼                                                           
┌──────────────────────────────────────────────────────────────────┐
│                     Container States                             │
│                                                                  │
│  Waiting ─┬─► Running ─┬─► Terminated                            │
│           │            │                                         │
│           │            └─► OOMKilled, Error, Completed           │
│           │                                                      │
│           └─► ImagePullBackOff, CrashLoopBackOff                 │
└──────────────────────────────────────────────────────────────────┘
```

### Detailed Phase Descriptions

| Phase | Meaning | Common Causes |
|-------|---------|---------------|
| **Pending** | Accepted, not running yet | Scheduling, image pulling, volume mounting |
| **Running** | At least one container running | Normal operation |
| **Succeeded** | All containers completed successfully | Jobs, one-off tasks |
| **Failed** | All containers terminated, at least one failed | Application error, OOM |
| **Unknown** | Can't determine state | Node communication lost |

### Container Exit Codes

| Code | Meaning | When It Happens |
|------|---------|-----------------|
| 0 | Success | Normal termination |
| 1 | General error | Application crash |
| 137 (128+9) | SIGKILL | OOMKilled, manual kill |
| 143 (128+15) | SIGTERM | Graceful termination |
| 126 | Command not executable | Permission denied |
| 127 | Command not found | Wrong binary path |

---

## 🏗️ Multi-Container Patterns

### Pattern 1: Sidecar

**Purpose:** Enhance or extend the main application

```
┌─────────────────────────────────────┐
│              Pod                    │
│                                     │
│  ┌─────────────────────────────┐   │
│  │      Main Application       │   │
│  │      (Nginx, Your App)      │   │
│  └──────────────┬──────────────┘   │
│                 │ Writes logs       │
│                 ▼                   │
│  ┌─────────────────────────────┐   │
│  │      Shared Volume          │   │
│  │      (/var/log/nginx)       │   │
│  └──────────────┬──────────────┘   │
│                 │ Reads logs        │
│                 ▼                   │
│  ┌─────────────────────────────┐   │
│  │      Sidecar Container      │   │
│  │      (Log Shiper)           │   │
│  │      - Reads logs           │   │
│  │      - Ships to ELK/Splunk  │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

**Common Sidecars:**
- Log aggregation (Fluentd, Filebeat)
- Monitoring (Prometheus exporter)
- Configuration reloading (Consul template)
- Service mesh proxy (Istio Envoy)

---

### Pattern 2: Init Container

**Purpose:** Run setup tasks before the main application starts

```
Time ───────────────────────────────────────────────►

┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────────┐
│  Init 1  │──►│  Init 2  │──►│  Init N  │──►│ Main Container│
│          │   │          │   │          │   │               │
│ Wait for │   │ Run DB   │   │ Set      │   │ Long-running  │
│ database │   │ Migration│   │ perms    │   │ application   │
│          │   │          │   │          │   │               │
│ Must     │   │ Must     │   │ Must     │   │ Starts only   │
│ complete │   │ complete │   │ complete │   │ after all     │
└──────────┘   └──────────┘   └──────────┘   └───────────────┘
     ↑                                              ↑
   Sequential                                    Parallel
   (blocking)                                   (main containers)
```

**Use Cases:**
- Database schema migrations
- Waiting for external services
- Generating configuration files
- Setting up permissions
- Cloning code/repositories

**Key Characteristics:**
- Run to completion (not continuous)
- Execute sequentially
- Must all succeed before main containers start
- Can have different images/resources than main containers

---

### Pattern 3: Ambassador

**Purpose:** Proxy connections to external services

```
Main Container ──► Ambassador Sidecar ──► External Database
                   (Connection pooling,
                    Circuit breaking,
                    Retry logic)
```

---

## 💾 Resource Management

### Requests vs Limits

```
┌────────────────────────────────────────────────────────────┐
│                     Node (8 CPU, 32GB RAM)                 │
│                                                            │
│  ┌────────────────────────────────────────────────────┐   │
│  │                Pod Resources                        │   │
│  │                                                     │   │
│  │   Request ───────────────────────────────────┐      │   │
│  │   (Guaranteed minimum)                       │      │   │
│  │                                              │      │   │
│  │                   Limit ─────────────────────┼──────┤   │
│  │                   (Absolute maximum)         │      │   │
│  │                                              │      │   │
│  │   ┌──────────┐                               │      │   │
│  │   │ Actually │                               │      │   │
│  │   │ Used     │                               │      │   │
│  │   └──────────┘                               │      │   │
│  │                                              │      │   │
│  └──────────────────────────────────────────────┴──────┘   │
│                                                            │
│  Scheduling: Uses REQUEST                                  │
│  Enforcement: Uses LIMIT                                   │
└────────────────────────────────────────────────────────────┘
```

**Behavior:**

| Aspect | Request | Limit |
|--------|---------|-------|
| **Purpose** | Scheduling guarantee | Runtime ceiling |
| **CPU** | Guaranteed share | Throttled if exceeded |
| **Memory** | Reserved memory | OOMKill if exceeded |
| **Scheduling** | Used to fit on node | Not used |

**Example Scenario:**
```yaml
resources:
  requests:
    cpu: "100m"      # 0.1 CPU cores
    memory: "128Mi"
  limits:
    cpu: "500m"      # 0.5 CPU cores
    memory: "256Mi"
```

- **Scheduling:** Scheduler finds node with at least 100m CPU and 128Mi free
- **Runtime:** Container can use up to 500m CPU, then throttled
- **Runtime:** If memory exceeds 256Mi → OOMKilled

---

## 🎯 QoS Classes

Kubernetes assigns a Quality of Service class to every Pod:

### Guaranteed (Best Protection)
**Criteria:**
- Every container has memory limit = memory request
- Every container has CPU limit = CPU request
- Only limits set (implicitly request = limit)

```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "128Mi"  # Equal to request
    cpu: "100m"       # Equal to request
```

**Eviction Priority:** Last (best protected)

---

### Burstable (Standard)
**Criteria:**
- At least one container has request ≠ limit
- Or only requests set, no limits

```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "50m"
  limits:
    memory: "128Mi"  # Different from request
    cpu: "100m"
```

**Eviction Priority:** Middle

---

### BestEffort (Least Protection)
**Criteria:**
- No requests or limits set

```yaml
# No resources section
```

**Eviction Priority:** First (least protected)

---

## 🐛 Common Pod Issues

### Issue 1: ImagePullBackOff

**Symptoms:**
```
NAME    READY   STATUS             RESTARTS
my-pod  0/1     ImagePullBackOff   0
```

**Causes:**
1. Wrong image name/tag
2. Private registry without imagePullSecret
3. Network connectivity to registry
4. Image doesn't exist

**Debug:**
```bash
kubectl describe pod my-pod
# Events: Failed to pull image: not found
```

---

### Issue 2: CrashLoopBackOff

**Symptoms:**
```
NAME    READY   STATUS             RESTARTS
my-pod  0/1     CrashLoopBackOff   5
```

**Causes:**
1. Application crashes on start
2. Missing environment variables
3. Wrong command/args
4. Resource limits too low

**Debug:**
```bash
kubectl logs my-pod --previous  # See crash output
kubectl describe pod my-pod     # Check events
```

---

### Issue 3: OOMKilled

**Symptoms:**
```
NAME    READY   STATUS         RESTARTS
my-pod  0/1     OOMKilled      1
```

**Cause:** Container exceeded memory limit

**Debug:**
```bash
kubectl describe pod my-pod
# State: Terminated, Reason: OOMKilled, Exit Code: 137
```

**Fix:** Increase memory limit or optimize application

---

### Issue 4: Pending

**Symptoms:**
```
NAME    READY   STATUS    RESTARTS
my-pod  0/1     Pending   0
```

**Causes:**
1. No node has enough resources
2. Node selector mismatch
3. Taints preventing scheduling
4. PersistentVolume not available

**Debug:**
```bash
kubectl describe pod my-pod
# Events: 0/3 nodes are available: Insufficient cpu
```

---

## 🔒 Security Contexts

### Container Hardening Checklist

```yaml
securityContext:
  # Run as non-root user
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  
  # Prevent privilege escalation
  allowPrivilegeEscalation: false
  
  # Read-only root filesystem
  readOnlyRootFilesystem: true
  
  # Drop all capabilities, add only needed ones
  capabilities:
    drop:
    - ALL
    add:  # Only if needed
    - NET_BIND_SERVICE
  
  # Restrict filesystem
  seccompProfile:
    type: RuntimeDefault  # or Localhost
```

---

## 📊 Theory to Labs Connection

### Lab 2.1: Multi-Container Pod
**Theory Applied:**
- Sidecar pattern explained
- Volume sharing between containers
- Shared network namespace

### Lab 2.2: Database Migration
**Theory Applied:**
- Init container sequential execution
- Blocking behavior during startup
- Pre-main setup workflows

### Lab 2.3: Resource Management
**Theory Applied:**
- Requests vs limits behavior
- QoS class assignment
- OOMKilled demonstration

---

## 📖 Key Takeaways

1. **Pod > Container:** Pod is the atomic unit, not container
2. **Shared Resources:** Same IP, volumes, IPC for containers in a Pod
3. **Init First:** Init containers must complete before main containers start
4. **Requests = Schedule:** Used for scheduling decisions
5. **Limits = Enforce:** Absolute maximum enforced at runtime
6. **Guaranteed QoS:** Equal requests and limits = best eviction protection
7. **Debug Pattern:** `describe` + `logs --previous` = solve most issues

---

## ❓ Interview Questions

### Q: Difference between Pod and Container?

**Answer:**
- **Container** is a single process with its own isolated filesystem, process tree, and network (via container runtime)
- **Pod** is a Kubernetes abstraction that wraps one or more containers:
  - Single IP address shared by all containers
  - Shared volumes (can read/write same files)
  - Shared network namespace (localhost communication)
  - Single lifecycle (created/destroyed together)
  
**Analogy:** Container is a room, Pod is an apartment with shared living space.

---

### Q: When to use multiple containers in one pod?

**Answer:**

**Use when containers MUST:**
- Share the same network namespace (localhost communication)
- Share files via volumes
- Scale together (same lifecycle)

**Patterns:**
1. **Sidecar:** Main app + log shipper/monitoring agent
2. **Ambassador:** Main app + proxy for external connections
3. **Adapter:** Main app + data format converter

**Don't use when:**
- Containers need to scale independently → Use separate Deployments
- No resource sharing needed → Separate Pods

---

## 🔗 Next Steps

1. Review the theory above
2. Complete [Lab 2.1](./LABS.md) - Multi-container Pod
3. Complete [Lab 2.2](./LABS.md) - Init Containers
4. Complete [Lab 2.3](./LABS.md) - Resource Management
5. Update [CHECKLIST.md](../CHECKLIST.md)

**Next Chapter:** [Chapter 3: Workloads & Controllers](../chapter-03/)
