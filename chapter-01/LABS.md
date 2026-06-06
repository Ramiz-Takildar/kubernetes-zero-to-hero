# Chapter 1 Labs: Kubernetes Architecture

## Lab 1.1: Explore Control Plane

### Objective
Identify control plane components in your cluster.

### Tasks
```bash
# 1. List all pods in kube-system namespace
kubectl get pods -n kube-system

# Expected output shows:
# - kube-apiserver-*
# - kube-controller-manager-*
# - kube-scheduler-*
# - etcd-*

# 2. Check API server is running
kubectl cluster-info

# 3. Check nodes
kubectl get nodes -o wide

# 4. Describe a node to see capacity
kubectl describe node $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
```

### Solution Verification
```bash
# Verify you can see control plane pods
kubectl get pods -n kube-system | grep -E "(apiserver|controller|scheduler|etcd)"

# Expected: Multiple lines showing control plane components
```

---

## Lab 1.2: etcd Backup and Restore

### Objective
Practice etcd backup operations.

### Prerequisites
Access to control plane node or local cluster.

### Tasks
```bash
# 1. Create a namespace and pod (test data)
kubectl create namespace lab-test
kubectl run test-pod --image=nginx -n lab-test

# 2. Simulate etcd backup using kubectl (since we may not have direct etcd access)
# Export all resources as backup
kubectl get all --all-namespaces -o yaml > cluster-backup.yaml

# 3. Add annotation to mark backup
kubectl annotate namespace lab-test backup-timestamp="$(date)"

# 4. Verify backup has data
grep -c "apiVersion:" cluster-backup.yaml

# 5. Cleanup for restore simulation
kubectl delete namespace lab-test

# 6. Restore from backup
kubectl apply -f cluster-backup.yaml

# 7. Verify restoration
kubectl get namespace lab-test
kubectl get pods -n lab-test
```

### Solution
```bash
#!/bin/bash
# etcd-backup-lab.sh

# Create test data
kubectl create ns backup-test
kubectl create deployment nginx --image=nginx -n backup-test --replicas=2

# Get all resources
kubectl get all -n backup-test -o yaml > backup.yaml

# Verify backup
echo "Backed up resources:"
grep "^kind:" backup.yaml | sort | uniq -c

# Delete
kubectl delete ns backup-test

# Restore
kubectl apply -f backup.yaml

# Verify
echo "After restore:"
kubectl get all -n backup-test
```

---

## Lab 1.3: Simulate API Server Failure

### Objective
Understand what happens when API server is unavailable.

### Tasks
```bash
# 1. Create a deployment
kubectl create deployment resilience-test --image=nginx --replicas=3

# 2. Note the pod names
kubectl get pods -l app=resilience-test

# 3. Delete a pod (API server is available now)
kubectl delete pod $(kubectl get pods -l app=resilience-test -o jsonpath='{.items[0].metadata.name}')

# 4. Observe: New pod is created immediately
kubectl get pods -l app=resilience-test -w

# 5. Clean up
kubectl delete deployment resilience-test
```

### Solution Explanation
- When API server is up: Deleted pod is detected, new one created (self-healing)
- When API server is down: Kubelet continues running pods but can't report status or receive updates

---

## Lab 1.4: Check Controller Manager

### Objective
Observe controller manager in action.

### Tasks
```bash
# 1. Create a ReplicaSet with 5 replicas
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: controller-demo
spec:
  replicas: 5
  selector:
    matchLabels:
      app: demo
  template:
    metadata:
      labels:
        app: demo
    spec:
      containers:
      - name: app
        image: nginx:alpine
EOF

# 2. Check 5 pods created
kubectl get pods -l app=demo

# 3. Delete 2 pods manually
kubectl delete pod $(kubectl get pods -l app=demo -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod $(kubectl get pods -l app=demo -o jsonpath='{.items[0].metadata.name}')

# 4. Watch controller recreate pods
kubectl get pods -l app=demo -w

# 5. Scale to 10 replicas - watch controller act
kubectl scale rs controller-demo --replicas=10

# 6. Clean up
kubectl delete rs controller-demo
```

### Expected Behavior
- Deleted pods are immediately recreated (maintaining 5 replicas)
- Scaling up creates new pods quickly
- Controller continuously reconciles desired vs actual state

---

## Lab 1.5: Scheduler Practice

### Objective
Understand how scheduler places pods on nodes.

### Tasks
```bash
# 1. Check node labels
kubectl get nodes --show-labels

# 2. Create pod with node selector
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: scheduled-pod
spec:
  nodeSelector:
    kubernetes.io/os: linux
  containers:
  - name: app
    image: busybox
    command: ['sleep', '3600']
EOF

# 3. Verify where it was scheduled
kubectl get pod scheduled-pod -o wide

# 4. Check scheduler events
kubectl describe pod scheduled-pod | grep -A5 Events

# 5. Clean up
kubectl delete pod scheduled-pod
```

### Solution
The scheduler filtered nodes based on the nodeSelector and selected one from available Linux nodes.

---

## Completion Checklist for Chapter 1

| Lab | Description | Status |
|-----|-------------|--------|
| 1.1 | Identify control plane components | [ ] |
| 1.2 | etcd backup simulation | [ ] |
| 1.3 | API server failure impact | [ ] |
| 1.4 | Controller manager reconciliation | [ ] |
| 1.5 | Scheduler node selection | [ ] |

**Mark each lab as complete in [CHECKLIST.md](../CHECKLIST.md)**
