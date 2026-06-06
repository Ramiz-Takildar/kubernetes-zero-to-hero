# Chapter 7 Labs: Observability

## Lab 7.1: Liveness Probe

### Objective
Implement and test liveness probes.

### Exercise
```bash
# 1. Create pod with file-based liveness probe
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: liveness-file
spec:
  containers:
  - name: app
    image: busybox
    command:
    - /bin/sh
    - -c
    - |
      echo "Creating health file"
      touch /tmp/healthy
      sleep 30
      echo "Removing health file - simulating failure"
      rm /tmp/healthy
      sleep 600
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      initialDelaySeconds: 5
      periodSeconds: 5
      timeoutSeconds: 1
      failureThreshold: 3
EOF

# 2. Watch pod status
kubectl get pod liveness-file -w

# Expected:
# Running
# After ~30s: Liveness probe fails
# Container restarts

# 3. Check restart count
kubectl get pod liveness-file
# Shows RESTARTS: 1 (or more)

# 4. View events
kubectl describe pod liveness-file | grep -A20 Events

# 5. Create HTTP liveness probe
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: liveness-http
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
    livenessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 10
      periodSeconds: 5
EOF

kubectl get pod liveness-http

# 6. Create TCP liveness probe
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: liveness-tcp
spec:
  containers:
  - name: mysql
    image: mysql:8.0
    env:
    - name: MYSQL_ROOT_PASSWORD
      value: secret
    ports:
    - containerPort: 3306
    livenessProbe:
      tcpSocket:
        port: 3306
      initialDelaySeconds: 30
      periodSeconds: 10
EOF

kubectl get pod liveness-tcp

# 7. Clean up
kubectl delete pod liveness-file liveness-http liveness-tcp
```

---

## Lab 7.2: Readiness Probe

### Objective
Control pod traffic with readiness probes.

### Exercise
```bash
# 1. Create deployment with readiness probe
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: readiness-demo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: readiness
  template:
    metadata:
      labels:
        app: readiness
    spec:
      containers:
      - name: app
        image: busybox
        command:
        - sh
        - -c
        - |
          echo "Starting app..."
          sleep 20  # Simulate slow startup
          touch /tmp/ready
          echo "App ready!"
          sleep 3600
        readinessProbe:
          exec:
            command:
            - cat
            - /tmp/ready
          initialDelaySeconds: 5
          periodSeconds: 5
        livenessProbe:
          exec:
            command:
            - cat
            - /tmp/ready
          initialDelaySeconds: 25
          periodSeconds: 10
EOF

# 2. Watch pods - all start as 0/1 ready
kubectl get pods -l app=readiness -w

# 3. Create service
kubectl expose deployment readiness-demo --port=80

# 4. Check endpoints - only ready pods listed
sleep 30
kubectl get endpoints readiness-demo

# 5. Create pod to test service
kubectl run test --image=busybox --restart=Never --rm -it -- \
  wget -qO- http://readiness-demo

# 6. Simulate readiness failure (manual check)
kubectl exec deployment/readiness-demo -- rm /tmp/ready
kubectl get po -l app=readiness
# Shows 0/1 or 1/2 ready

# 7. Check endpoints again
kubectl get endpoints readiness-demo

# 8. Restore readiness
kubectl exec deployment/readiness-demo -- touch /tmp/ready

# 9. Clean up
kubectl delete deployment readiness-demo
kubectl delete svc readiness-demo
```

---

## Lab 7.3: Debugging Pod Issues

### Objective
Systematic debugging approach.

### Exercise
```bash
# Scenario 1: ImagePullBackOff
kubectl run bad-image --image=this-image-does-not-exist:latest
kubectl get pod bad-image
kubectl describe pod bad-image | grep -A10 Events
kubectl delete pod bad-image

# Scenario 2: CrashLoopBackOff
kubectl run crash-pod --image=busybox --restart=Never -- /bin/false
sleep 5
kubectl get pod crash-pod
kubectl describe pod crash-pod
kubectl logs crash-pod  # No logs (no output)
kubectl logs crash-pod --previous  # Also empty for --restart=Never
kubectl get pod crash-pod -o jsonpath='{.status.containerStatuses[0].state.terminated.exitCode}'
# Returns: 1
kubectl delete pod crash-pod

# Scenario 3: Pending (resource constraints)
kubectl run huge-pod --image=nginx --requests='cpu=100,memory=1000Gi'
kubectl get pod huge-pod
kubectl describe pod huge-pod | grep -A5 Events
# Shows: Insufficient memory
kubectl delete pod huge-pod

# Scenario 4: OOMKilled
kubectl run oom-pod --image=polinux/stress \
  --limits='memory=64Mi' -- \
  --vm 1 --vm-bytes 128M --vm-hang 1
sleep 10
kubectl get pod oom-pod
kubectl describe pod oom-pod | grep -i oom
kubectl get pod oom-pod -o jsonpath='{.status.containerStatuses[0].state.terminated.exitCode}'
# Returns: 137
kubectl delete pod oom-pod

# Debugging checklist
# 1. kubectl get pods
# 2. kubectl describe pod (check Events)
# 3. kubectl logs
# 4. kubectl logs --previous
# 5. kubectl exec -it pod -- sh
# 6. kubectl get events --sort-by=.metadata.creationTimestamp
```

---

## Lab 7.4: Startup Probes

### Objective
Handle slow-starting containers.

### Exercise
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: startup-demo
spec:
  containers:
  - name: slow-app
    image: busybox
    command:
    - sh
    - -c
    - |
      echo "Starting slow application..."
      sleep 60  # Simulate slow startup
      touch /tmp/started
      echo "Application started!"
      sleep 3600
    ports:
    - containerPort: 8080
    startupProbe:
      exec:
        command:
        - cat
        - /tmp/started
      initialDelaySeconds: 10
      periodSeconds: 10
      failureThreshold: 30  # 10 * 30 = 300s = 5min
    livenessProbe:
      tcpSocket:
        port: 8080
      initialDelaySeconds: 10
      periodSeconds: 10
    readinessProbe:
      tcpSocket:
        port: 8080
      initialDelaySeconds: 5
      periodSeconds: 5
EOF

# Without startupProbe:
# - livenessProbe starts checking at 10s
# - App not ready, so it would restart loop

# With startupProbe:
# - liveness and readiness disabled until startup succeeds
# - startupProbe checks every 10s for up to 300s
# - Once /tmp/started exists, liveness/readiness take over

kubectl get pod startup-demo -w
# Shows startup probe in progress

kubectl delete pod startup-demo
```

---

## Lab 7.5: Events and Monitoring

### Objective
Monitor cluster events.

### Exercise
```bash
# 1. Watch all events
kubectl get events --sort-by=.metadata.creationTimestamp

# 2. Watch events in real-time
kubectl get events -w

# 3. Filter events for a specific resource
kubectl run test --image=nginx
kubectl get events --field-selector involvedObject.name=test

# 4. Filter warning events only
kubectl get events --field-selector type=Warning

# 5. Check events across all namespaces
kubectl get events --all-namespaces

# 6. Get recent events
kubectl get events --sort-by=.lastTimestamp | tail -20

# 7. Describe to see events
kubectl describe pod test | grep -A30 Events

# Clean up
kubectl delete pod test

# 8. Export events for analysis
kubectl get events -o json > events.json
```

---

## Completion Checklist for Chapter 7

| Lab | Description | Status |
|-----|-------------|--------|
| 7.1 | Liveness probe | [ ] |
| 7.2 | Readiness probe | [ ] |
| 7.3 | Debugging scenarios | [ ] |
| 7.4 | Startup probe | [ ] |
| 7.5 | Events monitoring | [ ] |
