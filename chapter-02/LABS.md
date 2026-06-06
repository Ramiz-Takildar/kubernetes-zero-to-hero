# Chapter 2 Labs: Pods & Containers

## Lab 2.1: Create and Debug Your First Pod

### Objective
Create a pod, access it, and debug issues.

### Exercise
```bash
# 1. Create a simple pod
kubectl run my-pod --image=nginx:alpine --port=80

# 2. Check status
kubectl get pod my-pod

# 3. Get detailed information
kubectl describe pod my-pod

# 4. Access the pod locally
kubectl port-forward my-pod 8080:80 &
curl http://localhost:8080
kill %1

# 5. Execute into the pod
kubectl exec -it my-pod -- sh
# Inside pod: ls -la /usr/share/nginx/html
# Inside pod: exit

# 6. Get logs
kubectl logs my-pod

# 7. Copy files
kubectl cp my-pod:/etc/nginx/nginx.conf ./nginx.conf

# 8. Clean up
kubectl delete pod my-pod
```

### Solution
All commands should execute without errors. The pod should:
- Start in Running state
- Respond to HTTP requests
- Allow shell access
- Show nginx welcome logs

---

## Lab 2.2: Multi-Container Pod with Shared Volume

### Objective
Create a pod with two containers sharing data.

### Exercise
Create a YAML file `multi-container-lab.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-container-lab
spec:
  volumes:
  - name: shared-storage
    emptyDir: {}
  containers:
  - name: writer
    image: busybox
    command: ['sh', '-c', 'while true; do date >> /shared/output.txt; sleep 5; done']
    volumeMounts:
    - name: shared-storage
      mountPath: /shared
  - name: reader
    image: busybox
    command: ['sh', '-c', 'tail -f /shared/output.txt']
    volumeMounts:
    - name: shared-storage
      mountPath: /shared
```

Apply and verify:
```bash
kubectl apply -f multi-container-lab.yaml

# Check both containers running
kubectl get pod multi-container-lab

# View reader container logs
kubectl logs multi-container-lab -c reader

# Copy file from shared volume
kubectl cp multi-container-lab:/shared/output.txt ./output.txt -c reader
cat output.txt

# Clean up
kubectl delete pod multi-container-lab
```

### Solution Verification
```bash
# Reader logs should show timestamps being written by writer
kubectl logs multi-container-lab -c reader
# Output:
# Wed Jan 01 10:00:00 UTC 2024
# Wed Jan 01 10:00:05 UTC 2024
# ...
```

---

## Lab 2.3: Init Containers Lab

### Objective
Use init containers to prepare before main app starts.

### Exercise
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: init-lab
spec:
  initContainers:
  - name: init-one
    image: busybox
    command: ['sh', '-c', 'echo "Init 1 running"; sleep 5; echo "Init 1 done"']
  - name: init-two
    image: busybox
    command: ['sh', '-c', 'echo "Init 2 running"; sleep 5; echo "Init 2 done"']
  containers:
  - name: main-app
    image: nginx:alpine
    ports:
    - containerPort: 80
```

Apply and observe:
```bash
kubectl apply -f init-lab.yaml

# Watch init containers run (in separate terminal)
kubectl get pods -w

# Check init container logs
kubectl logs init-lab -c init-one
kubectl logs init-lab -c init-two

# Main container starts only after both init complete
kubectl logs init-lab

# Clean up
kubectl delete pod init-lab
```

### Solution
The pod should show:
1. `Init:0/2` pending
2. `Init:1/2` after init-one completes
3. `Init:2/2` after init-two completes
4. `Running` main container starts

---

## Lab 2.4: Resource Limits Lab

### Objective
Experiment with resource requests and limits.

### Exercise

**Part A: Create resource-limited pod**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: resource-test
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'echo CPU: $(nproc); echo MEM:; free -m; sleep 3600']
    resources:
      requests:
        memory: "64Mi"
        cpu: "100m"
      limits:
        memory: "128Mi"
        cpu: "200m"
```

```bash
kubectl apply -f resource-test.yaml
kubectl logs resource-test
kubectl top pod resource-test
kubectl delete pod resource-test
```

**Part B: Trigger OOMKilled**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: oom-test
spec:
  containers:
  - name: memory-eater
    image: polinux/stress
    command: ['stress', '--vm', '1', '--vm-bytes', '250M', '--vm-hang', '1']
    resources:
      limits:
        memory: "128Mi"
```

```bash
kubectl apply -f oom-test.yaml
sleep 10
kubectl get pod oom-test
kubectl describe pod oom-test | grep -i oom
kubectl delete pod oom-test
```

### Solution
- Part A: Pod runs with guaranteed 64Mi, limited to 128Mi
- Part B: Pod shows `OOMKilled` status with exit code 137

---

## Lab 2.5: Debugging Pod Issues

### Objective
Troubleshoot common pod problems.

### Exercise

**Issue 1: ImagePullBackOff**
```bash
# Create pod with wrong image
kubectl run bad-image --image=nginxx:this-does-not-exist

# Debug
kubectl get pod bad-image
kubectl describe pod bad-image | grep -A10 Events
kubectl get events --field-selector involvedObject.name=bad-image

# Fix and verify
kubectl set image pod/bad-image nginxx=nginx:alpine
# Actually, delete and recreate:
kubectl delete pod bad-image
kubectl run bad-image --image=nginx:alpine
kubectl get pod bad-image

# Clean up
kubectl delete pod bad-image
```

**Issue 2: CrashLoopBackOff**
```bash
# Create crashing pod
kubectl run crash-pod --image=busybox --restart=Never -- /bin/false

# Debug
kubectl describe pod crash-pod
kubectl logs crash-pod
kubectl logs crash-pod --previous

# Check exit code
kubectl get pod crash-pod -o jsonpath='{.status.containerStatuses[0].state.terminated.exitCode}'

# Clean up
kubectl delete pod crash-pod
```

**Issue 3: Pending Pod**
```bash
# Create pod with impossible resource request
kubectl run pending-pod --image=nginx --requests='cpu=1000, memory=1000Ti'

# Debug
kubectl describe pod pending-pod | grep -A20 Events

# Common reasons:
# - Insufficient cpu
# - Insufficient memory  
# - No nodes match node selector

# Clean up
kubectl delete pod pending-pod
```

### Solution Commands Summary
```bash
# Debug any pod issue:
kubectl describe pod <name>          # Check Events section
kubectl logs <name>                  # Application logs
kubectl logs <name> --previous       # Previous container logs
kubectl exec -it <name> -- sh        # Interactive debugging
kubectl get events                   # Cluster-wide events
```

---

## Lab 2.6: Pod Lifecycle Hooks

### Objective
Use preStop and postStart hooks.

### Exercise
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: lifecycle-hooks
spec:
  containers:
  - name: app
    image: nginx:alpine
    lifecycle:
      postStart:
        exec:
          command: ['/bin/sh', '-c', 'echo "Container starting" > /usr/share/nginx/html/startup.html']
      preStop:
        exec:
          command: ['/bin/sh', '-c', 'echo "Container stopping"; nginx -s quit; sleep 5']
    ports:
    - containerPort: 80
```

```bash
kubectl apply -f lifecycle-hooks.yaml

# Test postStart hook
kubectl exec lifecycle-hooks -- cat /usr/share/nginx/html/startup.html

# Watch preStop during deletion
kubectl delete pod lifecycle-hooks --grace-period=30 &
kubectl get pod lifecycle-hooks -w

# Clean up
```

### Solution
- postStart: Creates startup.html file
- preStop: Gracefully stops nginx before termination

---

## Completion Checklist for Chapter 2

| Lab | Description | Status |
|-----|-------------|--------|
| 2.1 | Create and debug first pod | [ ] |
| 2.2 | Multi-container pod with shared volume | [ ] |
| 2.3 | Init containers | [ ] |
| 2.4 | Resource limits and OOMKilled | [ ] |
| 2.5 | Debugging pod issues | [ ] |
| 2.6 | Pod lifecycle hooks | [ ] |
