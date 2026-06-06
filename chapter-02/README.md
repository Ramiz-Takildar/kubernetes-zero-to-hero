# Chapter 2: Pods & Containers

## 📚 Learning Objectives

By the end of this chapter, you will:
- Understand Pod lifecycle and status
- Create multi-container pods
- Use init containers effectively
- Debug pod issues
- Understand resource QoS classes

**Estimated Time:** 3 days

---

## 2.1 Pod Fundamentals

### What is a Pod?

**Smallest deployable unit in Kubernetes**

```
┌─────────────────────────────────┐
│              POD                │  ← Shared namespace
│  ┌─────────────┐ ┌───────────┐  │  ← Shared IP
│  │ Container 1 │ │ Container │  │  ← Shared volumes
│  │   (app)     │ │ 2 (sidecar)│  │  ← Shared IPC
│  └─────────────┘ └───────────┘  │
└─────────────────────────────────┘
```

**Key Characteristics:**
- One or more containers
- Shared storage (volumes)
- Shared network namespace
- Same IPC namespace
- Cooperatively scheduled

**Why not just containers?**
- Need shared resources
- Co-located, co-managed
- Atomic deployment unit

---

## 2.2 Pod Lifecycle

### Phases (Status)

| Phase | Meaning |
|-------|---------|
| **Pending** | Accepted but containers not running yet (scheduling, image pulling) |
| **Running** | At least one container running |
| **Succeeded** | All containers terminated successfully |
| **Failed** | All containers terminated, at least one failed |
| **Unknown** | Cannot determine state (usually node communication issue) |

### Container States

```
Waiting → Running → Terminated
   ↑         │
   └─────────┘ (restart)
```

| State | Description |
|-------|-------------|
| Waiting | Pulling image, scheduling, resource issues |
| Running | Currently executing |
| Terminated | Exited (Completed or Error) |

### Common Exit Codes

| Code | Meaning | Action |
|------|---------|--------|
| 0 | Success | Normal termination |
| 1 | Error | Application error |
| 137 (128+9) | SIGKILL | OOMKill or force kill |
| 143 (128+15) | SIGTERM | Graceful termination |

---

## 2.3 Multi-Container Pods

### Patterns

#### 1. Sidecar Pattern
Main container + helper container
```
┌──────────────────────────────┐
│             Pod              │
│  ┌─────────┐ ┌────────────┐ │
│  │   App   │ │ Log Agent  │ │
│  │         │ │ (sidecar)  │ │
│  └─────────┘ └────────────┘ │
└──────────────────────────────┘
```

**Use Cases:**
- Log shipping (app → log agent → external)
- Monitoring agent
- Configuration reloading

#### 2. Adapter Pattern
Main container + adapter for external compatibility
```
┌──────────────────────────────┐
│             Pod              │
│  ┌─────────┐ ┌────────────┐ │
│  │ Legacy  │ │  Adapter   │ │
│  │   App   │ │ (format    │ │
│  │         │ │  data)     │ │
│  └─────────┘ └────────────┘ │
└──────────────────────────────┘
```

#### 3. Ambassador Pattern
Main container + proxy for external services
```
┌──────────────────────────────┐
│             Pod              │
│  ┌─────────┐ ┌────────────┐ │
│  │   App   │ │ Ambassador │ │
│  │         │ │ (conn pool │ │
│  │         │ │  sharding) │ │
│  └─────────┘ └────────────┘ │
└──────────────────────────────┘
```

---

## 2.4 Init Containers

**Run before main containers start**

```
Pod Created
    ↓
Init Container 1 (sequentially)
    ↓
Init Container 2
    ↓
Init Container N
    ↓
Main Containers (parallel)
```

**Characteristics:**
- Run to completion (one-shot)
- Sequential execution
- Must all succeed before main containers start
- Different image/resources from main containers

**Use Cases:**
- Database migrations
- Waiting for external service
- Generating config files
- Setting permissions

---

## 2.5 Resource Management

### Requests vs Limits

```yaml
resources:
  requests:  # Guaranteed/Reserved
    memory: "128Mi"
    cpu: "100m"
  limits:    # Maximum allowed
    memory: "256Mi"
    cpu: "500m"
```

| Aspect | Requests | Limits |
|--------|----------|--------|
| Scheduling | Used to fit pod on node | Not used |
| Execution | Guaranteed minimum | Maximum enforced |
| CPU | Allocated | Throttled if exceeded |
| Memory | Reserved | OOMKill if exceeded |

### QoS Classes

Kubernetes assigns QoS based on requests/limits:

| Class | Request = Limit? | Limit Set? | Eviction Priority |
|-------|------------------|------------|-------------------|
| **Guaranteed** | Yes | Yes | Last (best protected) |
| **Burstable** | No | Yes | Middle |
| **BestEffort** | N/A | No | First (least protected) |

### Checking QoS
```bash
kubectl get pod <name> -o jsonpath='{.status.qosClass}'
```

---

## 2.6 Pod Networking

### Network Model

```
┌───────────────────────────────────────┐
│               Node                    │
│  ┌─────────────────────────────────┐ │
│  │              Pod                │ │
│  │  ┌─────────┐     ┌───────────┐ │ │
│  │  │   C1    │ ←→  │    C2     │ │ │  Same localhost
│  │  │ :8080   │     │  :9090    │ │ │
│  │  └─────────┘     └───────────┘ │ │
│  └─────────────────────────────────┘ │
└───────────────────────────────────────┘
```

- Same network namespace
- Communicate via localhost
- Share same IP address
- Port conflicts if both use same port

---

## 2.7 Debugging Pods

### Common Issues

| Issue | Symptom | Debug Command |
|-------|---------|---------------|
| ImagePullBackOff | Wrong image/tag | `kubectl describe pod` |
| CrashLoopBackOff | App crashing | `kubectl logs --previous` |
| Pending | No node fits | `kubectl describe pod` |
| OOMKilled | Memory limit hit | `kubectl describe pod` |
| NodeNotReady | Node down | `kubectl get nodes` |

### Debug Commands

```bash
# Basic status
kubectl get pod <name>

# Detailed info
kubectl describe pod <name> | grep -A 20 Events

# Container logs
kubectl logs <pod> [-c <container>]

# Previous container logs (if crashed)
kubectl logs <pod> --previous

# Execute into running container
kubectl exec -it <pod> -c <container> -- /bin/sh

# Copy files from pod
kubectl cp <pod>:/path/in/pod ./local/path

# Get YAML definition
kubectl get pod <name> -o yaml

# Watch changes
kubectl get pod <name> -w

# All pods statuses
kubectl get pods --all-namespaces
kubectl get pods --field-selector=status.phase!=Running
```

---

## 💻 Hands-On Labs

### Lab 1: Pod Lifecycle Demo

```bash
# Create a pod
kubectl apply -f pod-lifecycle.yaml

# Watch it come up
kubectl get pods -w

# Describe to see events
kubectl describe pod lifecycle-demo

# Delete and observe termination
kubectl delete pod lifecycle-demo
```

### Lab 2: Multi-Container Pod

```bash
# Apply sidecar pattern
kubectl apply -f sidecar-pattern.yaml

# Check both containers
kubectl get pod sidecar-demo
kubectl logs sidecar-demo -c main
kubectl logs sidecar-demo -c logger

# Execute into each
kubectl exec -it sidecar-demo -c main -- sh
kubectl exec -it sidecar-demo -c logger -- sh
```

### Lab 3: Init Container

```bash
kubectl apply -f init-container.yaml

# Watch the init containers
kubectl get pods -w

# See "Init:" status while running
kubectl get pod init-demo

# Check logs of init containers
kubectl logs init-demo -c init-db
kubectl logs init-demo -c init-schema

# Main container starts only after all init complete
```

---

## ❓ Interview Questions (20)

### Q1: What is the difference between a Pod and a Container?

**Answer:**
- **Container:** Lightweight runtime instance with isolated processes
- **Pod:** Kubernetes abstraction that wraps one or more containers
  - Shares network namespace (same IP, localhost)
  - Shares storage volumes
  - Atomic scheduling unit
  - Same lifecycle (created/destroyed together)

A pod encapsulates the container and provides the Kubernetes environment.

---

### Q2: When would you use multiple containers in one pod?

**Answer:**

Use when containers **must** share:
- Same network namespace (localhost communication)
- Same storage volumes
- Same lifecycle

**Patterns:**
1. Sidecar - main app + helper (logging, monitoring)
2. Adapter - main app + protocol translator
3. Ambassador - main app + connection proxy

**Don't use** for independent scaling - use separate deployments.

---

### Q3: What is the difference between Init containers and Sidecars?

**Answer:**

| Aspect | Init Containers | Sidecars |
|--------|-----------------|----------|
| **When they run** | Before main containers | With main containers |
| **Execution** | Sequential, to completion | Parallel, ongoing |
| **Restart** | One-shot (must complete) | Run alongside app |
| **Count** | Multiple, run in order | Usually 1-2 per pod |
| **Use case** | Setup, migrations, wait-for | Ongoing assistance |

---

### Q4: How do containers in the same pod communicate?

**Answer:**
Via **localhost** since they share the same network namespace.

Example:
```
Container A listens on localhost:8080
Container B connects to localhost:8080
```

They also share the same IP address externally, so no port conflicts allowed.

---

### Q5: Explain Pod restart policies

**Answer:**

| Policy | Description |
|--------|-------------|
| **Always** | (Default) Restart on failure and success. Use for long-running apps |
| **OnFailure** | Restart only if container fails (non-zero exit). Use for jobs |
| **Never** | Never restart. Use for one-shot tasks |

Defined in Pod spec:
```yaml
spec:
  restartPolicy: Always
```

---

### Q6: Why is a pod stuck in Pending?

**Answer:**
Common reasons:
1. **No node has enough resources** (CPU/memory)
2. **Node selectors/affinity not matching** any nodes
3. **Taints on nodes** prevent scheduling
4. **PersistentVolume not available**
5. **Image pull secrets missing** (for private registries)

Debug: `kubectl describe pod <name>` and check Events section.

---

### Q7: What does OOMKilled mean and how to fix it?

**Answer:**
**OOMKilled** = Out Of Memory Killed

Container exceeded its memory **limit**, kernel killed it.

**Fix:**
1. Increase memory limit
2. Reduce memory usage in application
3. Request = Limit for Guaranteed QoS

Check: `kubectl describe pod` shows exit code 137 (128+9 SIGKILL).

---

### Q8: What is CrashLoopBackOff?

**Answer:**
Container keeps crashing, Kubernetes keeps trying to restart it with increasing delay.

**Causes:**
1. Application error (bug, missing config)
2. Missing environment variables
3. Wrong command/args
4. Resource limits too low causing OOM
5. Liveness probe misconfigured

**Debug:**
```bash
kubectl logs <pod> --previous
kubectl describe pod <pod>
```

---

### Q9: What is a Static Pod?

**Answer:**
Pods created and managed directly by kubelet, not by API Server.

- Defined by manifest files on node (`/etc/kubernetes/manifests`)
- kubelet watches directory and creates/deletes pods
- No Deployment/ReplicaSet involved
- Common for control plane components

**Use case:** Running critical system pods without depending on control plane.

---

### Q10: Explain QoS classes and their importance

**Answer:**

| Class | Criteria | Eviction Order |
|-------|----------|----------------|
| **Guaranteed** | Request=Limit for CPU & Memory, only limits | Last |
| **Burstable** | Request<Limit OR only one resource specified | Middle |
| **BestEffort** | No requests/limits set | First |

**Importance:**
- Determines which pods get killed first during resource pressure
- Guaranteed pods are safest for critical workloads
- BestEffort pods are first to be evicted

---

### Q11: What is the Pause Container?

**Answer:**
Invisible "holder" container that creates the pod's network namespace.

- Runs in every pod (hidden)
- First container to start
- Maintains network namespace
- Other containers join its namespace
- Process ID 1 in pod's PID namespace

Without it, if all user containers died, network namespace would be lost.

---

### Q12: How does Host networking work?

**Answer:**
Pod uses the node's network namespace instead of its own.

```yaml
spec:
  hostNetwork: true
```

**Implications:**
- Pod uses node's IP
- No network isolation
- Port conflicts possible
- Commonly used for network agents (CNI, monitoring)

---

### Q13: What is ShareProcessNamespace?

**Answer:**
Makes containers share the same PID namespace.

```yaml
spec:
