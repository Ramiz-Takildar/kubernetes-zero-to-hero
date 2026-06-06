# Chapter 8 Labs: Scheduling & Scaling

## Overview
Learn HPA, affinity, taints, PDB.

---

## Lab 8.1: Horizontal Pod Autoscaler

### Create Deployment

Create `hpa-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scalable-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: scalable
  template:
    metadata:
      labels:
        app: scalable
    spec:
      containers:
      - name: app
        image: nginx:alpine
        resources:
          requests:
            memory: 128Mi
            cpu: 100m
```

### Create HPA

Create `hpa.yaml`:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: scalable-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: scalable-app
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
```

### Generate Load and Watch Scaling

---

## Lab 8.2: Node Affinity

### Create Pod with Node Selector

Create `node-affinity-pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: affinity-pod
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: kubernetes.io/os
            operator: In
            values: ["linux"]
  containers:
  - name: app
    image: busybox
    command: ['sleep', '3600']
```

---

## Lab 8.3: Taints and Tolerations

### Add Taint to Node

```bash
kubectl taint nodes <node> dedicated=true:NoSchedule
```

### Create Pod with Toleration

Create `toleration-pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: toleration-pod
spec:
  tolerations:
  - key: dedicated
    operator: Equal
    value: "true"
    effect: NoSchedule
  containers:
  - name: app
    image: busybox
    command: ['sleep', '3600']
```

---

## Lab 8.4: Pod Disruption Budget

### Create PDB

Create `pdb.yaml`:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: app-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: critical
```

---

## Completion Checklist

| Lab | Description | Status |
|-----|-------------|--------|
| 8.1 | HPA | [ ] |
| 8.2 | Node Affinity | [ ] |
| 8.3 | Taints | [ ] |
| 8.4 | PDB | [ ] |
