# Chapter 2: Pods & Containers - Interview Questions

> 20+ Interview Questions with Detailed Answers

---

## Basic Level Questions

### Q1: What is the difference between a Pod and a Container?

**Answer:**

| Container | Pod |
|-----------|-----|
| Single process isolation | Group of containers |
| Own network namespace | Shared network namespace |
| No shared storage | Can share volumes |
| Managed by container runtime | Managed by Kubernetes |

**Pod provides:**
- Shared IP address
- Shared storage volumes
- Shared network namespace (localhost communication)
- Atomic lifecycle (created/destroyed together)

**Analogy:** Container = room, Pod = apartment with shared living space

---

### Q2: When would you use multiple containers in one pod?

**Answer:**

**Use when containers:**
- Must share the same network namespace
- Must share storage volumes
- Have the same lifecycle

**Common Patterns:**
1. **Sidecar:** Main app + log shipper (share logs volume)
2. **Init:** Migration job that runs before main app
3. **Adapter:** Main app + protocol converter

**Example:**
```
Pod:
├── Nginx (main app)
└── Fluentd (sidecar)
    └── Shares /var/log/nginx via volume
```

**Don't use when:**
- Need independent scaling → Use separate Deployments
- Different lifecycles → Separate Pods

---

### Q3: What are Pod lifecycle states?

**Answer:**

| State | Meaning | Cause |
|-------|---------|-------|
| **Pending** | Accepted but not running | Scheduling, image pulling |
| **Running** | At least one container running | Normal operation |
| **Succeeded** | All containers completed | Job finished |
| **Failed** | All containers exited, at least one error | Crash |
| **Unknown** | Can't determine state | Node communication lost |
| **CrashLoopBackOff** | Container crashing repeatedly | App error |
| **ImagePullBackOff** | Can't pull image | Wrong image/private registry |
| **OOMKilled** | Out of memory | Exceeded memory limit |

---

### Q4: What is CrashLoopBackOff and how do you fix it?

**Answer:**

**What:** Container starts, crashes, Kubernetes restarts it, repeat. Each restart delays longer (backoff).

**Common causes:**
1. Application error/app crashes
2. Missing environment variables
3. Wrong command/arguments
4. Resource limits too low (OOM)
5. Missing dependencies

**Debug steps:**
```bash
# Check logs
kubectl logs <pod> --previous

# Check events
kubectl describe pod <pod>

# Check exit code
kubectl get pod <pod> -o jsonpath='{.status.containerStatuses[0].state.terminated.exitCode}'
```

**Fix:** Identify root cause from logs, fix configuration/image.

---

### Q5: What is the difference between an Init container and a Sidecar?

**Answer:**

| | Init Container | Sidecar |
|----|----------------|---------|
| **Runs when** | Before main containers | With main containers |
| **Execution** | Sequential, to completion | Parallel, ongoing |
| **Restart** | No (one-shot) | Yes (with pod) |
| **Purpose** | Setup, migrations | Ongoing assistance |

**Example Init:**
```yaml
initContainers:
- name: init-db
  command: ['sh', '-c', 'until pg_isready; do sleep 2; done']
```

**Example Sidecar:**
```yaml
containers:
- name: app
  image: myapp
- name: nginx-exporter  # sidecar
  image: nginx/nginx-prometheus-exporter
```

---

## Intermediate Level Questions

### Q6: Explain resource requests and limits.

**Answer:**

| | Request | Limit |
|--|---------|-------|
| **Purpose** | Scheduling guarantee | Runtime maximum |
| **CPU** | Guaranteed share | Throttled if exceeded |
| **Memory** | Reserved memory | OOMKill if exceeded |
| **Enforcement** | Scheduler uses | Cgroup enforces |

**Example:**
```yaml
resources:
  requests:
    memory: 128Mi
    cpu: 100m
  limits:
    memory: 256Mi
    cpu: 500m
```

**Behavior:**
- Container can use between request and limit
- CPU: Throttled at limit
- Memory: Killed (OOMKilled) at limit

---

### Q7: What are QoS classes in Kubernetes?

**Answer:**

| Class | Criteria | Eviction Priority |
|-------|----------|-------------------|
| **Guaranteed** | Limits = Requests for all resources | Last (protected) |
| **Burstable** | Limits ≠ Requests | Middle |
| **BestEffort** | No requests/limits set | First (evicted) |

**Guaranteed example:**
```yaml
resources:
  requests:
    memory: 128Mi
    cpu: 100m
  limits:
    memory: 128Mi  # Equal
    cpu: 100m       # Equal
```

**Check QoS:**
```bash
kubectl get pod <name> -o jsonpath='{.status.qosClass}'
```

---

### Q8: What is OOMKilled (Exit Code 137)?

**Answer:**

**Meaning:** Container exceeded its memory limit and was killed by the Linux OOM killer.

**Exit code:** 137 = 128 + 9 (SIGKILL)

**Symptoms:**
```bash
kubectl get pod  # Shows OOMKilled
kubectl describe pod  # Reason: OOMKilled
```

**Fix:**
1. Increase memory limit:
```yaml
resources:
  limits:
    memory: 512Mi  # Increase from 256Mi
```

2. Or optimize application memory usage

**Verify:** Check in describe output:
```
Last State: Terminated
  Reason:   OOMKilled
  Exit Code: 137
```

---

### Q9: How do containers in the same Pod communicate?

**Answer:**

**Via localhost** - they share the same network namespace.

```
Container A: localhost:8080
Container B: localhost:9090

Container A → curl http://localhost:9090 → Container B
```

**Also share:**
- Same IP address
- Same port space (can't use same port)
- IPC namespace (can use shared memory)
- Volumes

**Different from:** Pod-to-Pod communication (uses Service DNS)

---

### Q10: What is a static Pod?

**Answer:**

**Definition:** Pod managed directly by kubelet on a node, not through API Server.

**Location:** `/etc/kubernetes/manifests/` on node

**Characteristics:**
- No Deployment/ReplicaSet
- Specified by manifest file on node
- Useful for control plane components
- kubelet watches directory and creates/deletes pods

**Example use:** Running etcd, API Server as pods on control plane node.

---

## Advanced Level Questions

### Q11: Explain the Pause container.

**Answer:**

**What:** An invisible container in every pod that holds the network namespace.

**Why needed:**
- Holds the Pod's IP address and network namespace
- If all user containers die, network namespace would be lost
- With pause container, network persists

**Visibility:**
```bash
# You don't see it in kubectl describe, but it exists
# Process ID: 1 in pod's PID namespace
# Image: k8s.gcr.io/pause:3.x
```

**Analogy:** Like a rental agreement holder - holds the lease while roommates (containers) come and go.

---

### Q12: What is a Pod's restartPolicy?

**Answer:**

| Policy | Behavior | Use Case |
|--------|----------|----------|
| **Always** | (Default) Restart on failure and success | Long-running apps |
| **OnFailure** | Restart only on failure | Jobs/batch processing |
| **Never** | Never restart | One-off tasks, debugging |

**Important:** Applies to all containers in the pod, not just one.

---

### Q13: How do you debug a Pod stuck in Pending?

**Answer:**

**Debug steps:**

```bash
# 1. Check events
kubectl describe pod <name>
# Look for: "Insufficient cpu", "Insufficient memory", "node(s) had taint"

# 2. Check resources
kubectl describe pod | grep -A10 "Requests"

# 3. Check nodes
kubectl get nodes -o wide
kubectl describe node <node>

# 4. Check taints
kubectl get nodes -o json | jq '.items[].spec.taints'

# 5. Check PVCs (if used)
kubectl get pvc
```

**Common causes:**
- No node with sufficient resources
- Node selector/affinity mismatch
- Taints preventing scheduling
- PersistentVolume not available
- Image pull secrets missing

---

### Q14: What is shareProcessNamespace?

**Answer:**

**Feature:** Makes containers in a pod share the same PID namespace.

**Use case:**
- Debugging tools can see processes in other containers
- Signal forwarding between containers
- Shared process management

```yaml
spec:
  shareProcessNamespace: true
  containers:
  - name: app
    image: myapp
  - name: debugger
    image: debug-tools
    # Can see app's processes
```

---

### Q15: How do you handle secrets in a multi-container Pod?

**Answer:**

**Methods:**

1. **Environment variables:** Each container can mount different secret keys
```yaml
containers:
- name: app1
  envFrom:
  - secretRef:
      name: app1-secrets
- name: app2
  envFrom:
  - secretRef:
      name: app2-secrets
```

2. **Volumes:** Shared volume, but different permissions
```yaml
volumes:
- name: secrets
  secret:
    secretName: shared-secret
volumeMounts:
- name: secrets
  mountPath: /secrets/app1
  subPath: app1
```

**Security:** Each container only gets secrets it needs (principle of least privilege).

---

## Scenario-Based Questions

### S1: One container in multi-container pod is failing. Others need to know.

**Answer:**

**Options:**

1. **Shared volume with status files:**
```yaml
containers:
- name: app
  volumeMounts:
  - name: status
    mountPath: /status
  # Write /status/healthy or /status/failed
- name: monitor
  volumeMounts:
  - name: status
    mountPath: /status
  # Watch /status files
```

2. **Process namespace sharing + signals**

3. **Sidecar pattern with shared memory**

---

### S2: Application needs 2GB memory during startup, then uses 512MB.

**Answer:**

**Problem:** If limit = 512MB, startup OOMKilled. If limit = 2GB, waste during runtime.

**Solution:** Use init container for heavy startup work:

```yaml
initContainers:
- name: init
  image: app
  command: ['app', '--init-mode']  # Heavy initialization
  resources:
    limits:
      memory: 2Gi
containers:
- name: app
  image: app
  command: ['app', '--serve']  # Normal operation
  resources:
    limits:
      memory: 512Mi
```

---

## Quick Reference

| Issue | Debug Command |
|-------|---------------|
| CrashLoopBackOff | `kubectl logs --previous` |
| Pending | `kubectl describe pod` |
| OOMKilled | `kubectl describe` (Reason: OOMKilled) |
| ImagePullBackOff | `kubectl describe` (Events) |

---

## Key Takeaways

1. **Pod > Container:** Pod is the atomic unit
2. **Init before App:** Init containers run first, sequentially
3. **Sidecar alongside:** Sidecars run with main app
4. **Request = Schedule:** Used for placement
5. **Limit = Throttle/OOM:** Runtime ceiling
6. **QoS = Protection:** Guaranteed class survives eviction
7. **Describe = Debug:** First command for issues

---

**Previous:** [Chapter 1 Interview Questions](../chapter-01/INTERVIEW.md)  
**Next:** [Chapter 3 Interview Questions](../chapter-03/INTERVIEW.md)
