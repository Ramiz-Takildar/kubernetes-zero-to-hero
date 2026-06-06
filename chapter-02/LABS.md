# Chapter 2 Labs: Pods & Containers

## Overview

These labs cover Pod fundamentals, multi-container patterns, init containers, and resource management. Each lab includes detailed explanations, step-by-step instructions, and verification steps.

**Prerequisites:** kubectl configured, basic cluster access

---

## Lab 2.1: Create and Debug Your First Pod

### Learning Objectives
- Create a Pod using kubectl
- Access Pod logs and execute commands
- Debug common Pod issues

### Theory

A Pod is the smallest deployable unit in Kubernetes. It encapsulates one or more containers with shared storage and network resources.

**Key concepts:**
- Pod gets its own IP address
- Containers in a Pod share the IP
- Pod lifecycle is tracked through phases

### Steps

#### Step 1: Create Your First Pod

```bash
kubectl run my-first-pod --image=nginx:alpine --port=80
```

This creates a Pod named `my-first-pod` running nginx on port 80.

#### Step 2: Check Pod Status

```bash
kubectl get pod my-first-pod
```

**Expected output:**
```
NAME           READY   STATUS    RESTARTS   AGE
my-first-pod   1/1     Running   0          10s
```

**Status meanings:**
- `Pending`: Creating/starting
- `Running`: Container running
- `CrashLoopBackOff`: Container crashing
- `Error`: Failed to start

#### Step 3: Get Detailed Information

```bash
kubectl describe pod my-first-pod
```

**Important sections:**
- `Events`: Shows lifecycle events
- `Containers`: Container details
- `Conditions`: Ready status
- `QoS Class`: Resource class

#### Step 4: Access the Pod Locally

```bash
# Start port forwarding in background
kubectl port-forward my-first-pod 8080:80 &

# Test access
curl http://localhost:8080

# Stop port forwarding
kill %1
```

You should see the nginx welcome page.

#### Step 5: Execute Commands in the Pod

```bash
# Run a single command
kubectl exec my-first-pod -- ps aux

# Open an interactive shell
kubectl exec -it my-first-pod -- sh

# Inside the container:
ls -la /usr/share/nginx/html
exit
```

#### Step 6: View Pod Logs

```bash
# View logs
kubectl logs my-first-pod

# Follow logs in real-time
kubectl logs -f my-first-pod

# Press Ctrl+C to stop following
```

You should see nginx access logs showing your curl request.

#### Step 7: Copy Files

```bash
# Copy from pod to local
kubectl cp my-first-pod:/etc/nginx/nginx.conf ./nginx.conf

# Verify
ls -lh nginx.conf
cat nginx.conf
```

### Cleanup

```bash
kubectl delete pod my-first-pod
rm -f nginx.conf
```

---

## Lab 2.2: Multi-Container Pod with Shared Volume

### Learning Objectives
- Create a Pod with multiple containers
- Share data between containers using volumes
- Understand sidecar pattern

### Theory

**Sidecar Pattern:** A secondary container that extends or enhances the main application container.

**Why multiple containers in one Pod:**
- Shared storage (logs, cache)
- Shared network (localhost communication)
- Shared lifecycle (created/destroyed together)

**emptyDir volume:** Created when Pod starts, deleted when Pod dies. Perfect for sharing temp files.

### Steps

#### Step 1: Create the Multi-Container Pod

Create file `multi-container-pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-container-lab
  labels:
    lab: multi-container
spec:
  volumes:
  - name: shared-storage
    emptyDir: {}
  
  containers:
  # Writer container creates log entries
  - name: writer
    image: busybox
    command:
    - /bin/sh
    - -c
    - |
      echo "Writer starting..."
      i=1
      while true; do
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo "[$timestamp] Log entry $i" >> /shared/output.txt
        echo "Writer: Created entry $i"
        i=$((i + 1))
        sleep 5
      done
    volumeMounts:
    - name: shared-storage
      mountPath: /shared
    resources:
      requests:
        memory: "32Mi"
        cpu: "50m"
  
  # Reader container reads log entries
  - name: reader
    image: busybox
    command:
    - /bin/sh
    - -c
    - |
      echo "Reader starting..."
      echo "Waiting for file to appear..."
      sleep 2
      echo "Reading from shared volume:"
      tail -f /shared/output.txt
    volumeMounts:
    - name: shared-storage
      mountPath: /shared
    resources:
      requests:
        memory: "32Mi"
        cpu: "50m"
```

Apply it:
```bash
kubectl apply -f multi-container-pod.yaml
```

#### Step 2: Verify Both Containers Running

```bash
kubectl get pod multi-container-lab
```

**Expected output:**
```
NAME                  READY   STATUS    RESTARTS   AGE
multi-container-lab   2/2     Running   0          10s
```

Note: `2/2` means both containers are running.

#### Step 3: View Writer Container Logs

```bash
kubectl logs multi-container-lab -c writer
```

You should see log entries being created.

#### Step 4: View Reader Container Logs

```bash
kubectl logs multi-container-lab -c reader
```

You should see the log entries being read from the shared file.

#### Step 5: Execute into Reader Container

```bash
kubectl exec -it multi-container-lab -c reader -- sh

# Inside the container:
cat /shared/output.txt
ls -la /shared/
exit
```

This confirms both containers can read/write the same files.

#### Step 6: Copy Shared File

```bash
kubectl cp multi-container-lab:/shared/output.txt ./output.txt -c reader
cat output.txt
```

### Verification Checklist

- [ ] Pod shows `2/2` READY
- [ ] Writer logs show entries being created
- [ ] Reader logs show entries being read
- [ ] File copy succeeds showing shared data

### Cleanup

```bash
kubectl delete -f multi-container-pod.yaml
rm -f multi-container-pod.yaml output.txt
```

---

## Lab 2.3: Init Containers

### Learning Objectives
- Understand init container execution order
- Use init containers for setup tasks
- Observe the blocking behavior

### Theory

**Init Containers:**
- Run before main containers start
- Execute sequentially (not parallel)
- Must all succeed before main containers start
- Often used for: setup, waiting for dependencies, migrations

**Execution flow:**
```
Pod Created
    ↓
Init Container 1 runs
    ↓
Init Container 1 completes
    ↓
Init Container 2 runs
    ↓
Init Container 2 completes
    ↓
Main Containers start (parallel)
```

### Steps

#### Step 1: Create Pod with Init Containers

Create `init-container-pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: init-lab
  labels:
    lab: init-container
spec:
  initContainers:
  # Init 1: Simulates checking database availability
  - name: init-check-db
    image: busybox
    command:
    - sh
    - -c
    - |
      echo "[Init 1] Checking database connection..."
      echo "[Init 1] Simulating database check..."
      sleep 3
      echo "[Init 1] Database is available!"
    resources:
      requests:
        memory: "16Mi"
        cpu: "10m"
  
  # Init 2: Simulates running migrations
  - name: init-migrations
    image: busybox
    command:
    - sh
    - -c
    - |
      echo "[Init 2] Running database migrations..."
      sleep 3
      echo "[Init 2] Migration 1/3 complete"
      sleep 2
      echo "[Init 2] Migration 2/3 complete"
      sleep 2
      echo "[Init 2] Migration 3/3 complete"
      echo "[Init 2] All migrations done!"
    resources:
      requests:
        memory: "32Mi"
        cpu: "50m"
  
  # Init 3: Simulates setting permissions
  - name: init-permissions
    image: busybox
    command:
    - sh
    - -c
    - |
      echo "[Init 3] Setting up directory permissions..."
      mkdir -p /shared/data
      echo "[Init 3] Created /shared/data"
      echo "[Init 3] Permissions set!"
    volumeMounts:
    - name: data-volume
      mountPath: /shared
    resources:
      requests:
        memory: "16Mi"
        cpu: "10m"
  
  # Main container only starts after all init containers complete
  containers:
  - name: main-app
    image: nginx:alpine
    ports:
    - containerPort: 80
    volumeMounts:
    - name: data-volume
      mountPath: /usr/share/nginx/html/data
    resources:
      requests:
        memory: "64Mi"
        cpu: "50m"
  
  volumes:
  - name: data-volume
    emptyDir: {}
```

Apply it:
```bash
kubectl apply -f init-container-pod.yaml
```

#### Step 2: Watch Init Container Execution

```bash
# Watch Pod status change
kubectl get pod init-lab -w
```

**Expected progression:**
1. `Init:0/3` (Pending)
2. `Init:1/3` (First init container running)
3. `Init:2/3` (Second init container running)
4. `Init:3/3` (Third init container running)
5. `Running` (Main container started)

Press `Ctrl+C` when status shows `Running`.

#### Step 3: Check Init Container Logs

```bash
# First init container
kubectl logs init-lab -c init-check-db

# Second init container
kubectl logs init-lab -c init-migrations

# Third init container
kubectl logs init-lab -c init-permissions
```

Each should show completion messages.

#### Step 4: Verify Main Container

```bash
kubectl logs init-lab
```

Main container (nginx) logs should show it started successfully.

### Verification Checklist

- [ ] Pod went through Init:0/3 → Init:3/3 → Running
- [ ] Init container 1 logs show completion
- [ ] Init container 2 logs show all migrations
- [ ] Init container 3 logs show permissions set
- [ ] Main container started after all init complete

### Cleanup

```bash
kubectl delete -f init-container-pod.yaml
rm -f init-container-pod.yaml
```

---

## Lab 2.4: Resource Management and QoS

### Learning Objectives
- Configure resource requests and limits
- Understand QoS classes
- Observe OOMKilled behavior

### Theory

**Requests vs Limits:**
- **Requests:** Guaranteed resources, used for scheduling
- **Limits:** Maximum allowed, enforced at runtime

**QoS Classes:**
- **Guaranteed:** Request = Limit (best protection)
- **Burstable:** Request < Limit
- **BestEffort:** No requests/limits (first evicted)

### Part A: Guaranteed QoS

Create `guaranteed-pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: guaranteed-qos
  labels:
    qos: guaranteed
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
      limits:
        memory: "128Mi"  # Equal to request
        cpu: "100m"       # Equal to request
```

```bash
kubectl apply -f guaranteed-pod.yaml
kubectl get pod guaranteed-qos -o jsonpath='{.status.qosClass}'
# Output: Guaranteed
```

### Part B: Burstable QoS

Create `burstable-pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: burstable-qos
  labels:
    qos: burstable
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    resources:
      requests:
        memory: "64Mi"
        cpu: "50m"
      limits:
        memory: "128Mi"  # Higher than request
        cpu: "100m"
```

```bash
kubectl apply -f burstable-pod.yaml
kubectl get pod burstable-qos -o jsonpath='{.status.qosClass}'
# Output: Burstable
```

### Part C: BestEffort QoS

Create `besteffort-pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: besteffort-qos
  labels:
    qos: besteffort
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    # No resources section = BestEffort
```

```bash
kubectl apply -f besteffort-pod.yaml
kubectl get pod besteffort-qos -o jsonpath='{.status.qosClass}'
# Output: BestEffort
```

### Part D: Demonstrate OOMKilled

Create `oom-test-pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: oom-test
spec:
  containers:
  - name: memory-eater
    image: polinux/stress
    command:
    - stress
    - --vm
    - "1"
    - --vm-bytes
    - "250M"  # Tries to allocate 250MB
    - --vm-hang
    - "1"
    resources:
      limits:
        memory: "128Mi"  # But limited to 128MB
```

```bash
kubectl apply -f oom-test-pod.yaml
sleep 10
kubectl get pod oom-test
kubectl describe pod oom-test | grep -A5 "Last State"
```

**Expected:** Pod shows `OOMKilled` with exit code 137.

### Verification Checklist

- [ ] Guaranteed QoS verified
- [ ] Burstable QoS verified
- [ ] BestEffort QoS verified
- [ ] OOMKilled observed

### Cleanup

```bash
kubectl delete -f guaranteed-pod.yaml
kubectl delete -f burstable-pod.yaml
kubectl delete -f besteffort-pod.yaml
kubectl delete -f oom-test-pod.yaml
rm -f *-pod.yaml
```

---

## Completion Checklist

| Lab | Description | Status |
|-----|-------------|--------|
| 2.1 | Create and debug first pod | [ ] |
| 2.2 | Multi-container pod | [ ] |
| 2.3 | Init containers | [ ] |
| 2.4 | Resource management | [ ] |

**Mark complete in [CHECKLIST.md](../CHECKLIST.md)**
