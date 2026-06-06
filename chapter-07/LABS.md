# Chapter 7 Labs: Observability

## Overview
Learn liveness, readiness, startup probes and debugging.

---

## Lab 7.1: Liveness Probe

### Create Pod with Failing Liveness

Create `liveness-fail.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: liveness-fail
spec:
  containers:
  - name: app
    image: k8s.gcr.io/busybox
    args:
    - /bin/sh
    - -c
    - touch /tmp/healthy; sleep 30; rm /tmp/healthy; sleep 600
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      initialDelaySeconds: 5
      periodSeconds: 5
```

### Verification

Watch pod restart after health check fails.

---

## Lab 7.2: Readiness Probe

### Create Deployment with Readiness

Create `readiness-deployment.yaml`:

```yaml
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
        image: nginx:alpine
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
```

### Verification

- Service only routes to ready pods
- Readiness failures remove from endpoints

---

## Lab 7.3: Debugging Pod Issues

### Scenario 1: ImagePullBackOff

```bash
kubectl run bad-image --image=this-does-not-exist
describe pod bad-image
```

### Scenario 2: CrashLoopBackOff

```bash
kubectl run crash-pod --image=busybox -- /bin/false
kubectl logs crash-pod --previous
```

### Scenario 3: OOMKilled

Create `oom-pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: oom-test
spec:
  containers:
  - name: app
    image: polinux/stress
    command: ['stress', '--vm', '1', '--vm-bytes', '250M']
    resources:
      limits:
        memory: 128Mi
```

---

## Completion Checklist

| Lab | Description | Status |
|-----|-------------|--------|
| 7.1 | Liveness Probe | [ ] |
| 7.2 | Readiness Probe | [ ] |
| 7.3 | Debugging | [ ] |
