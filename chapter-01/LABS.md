# Chapter 1 Labs: Kubernetes Architecture

## Overview

These labs will help you understand the Kubernetes control plane components through hands-on exercises. Each lab includes theory, objectives, step-by-step instructions, and verification steps.

**Prerequisites:** Working Kubernetes cluster, kubectl configured

---

## Lab 1.1: Explore Control Plane Components

### Learning Objectives
- Identify all control plane components running in your cluster
- Understand the role of each component
- Learn to check component health

### Theory

The Kubernetes control plane consists of four main components:

1. **kube-apiserver:** The API gateway for all cluster operations
2. **etcd:** Distributed database storing all cluster state
3. **kube-scheduler:** Decides which node runs which pod
4. **kube-controller-manager:** Runs controllers that maintain desired state

These typically run as pods in the `kube-system` namespace.

### Steps

#### Step 1: List Control Plane Pods

Run the following command to see all system pods:

```bash
kubectl get pods -n kube-system
```

**Expected Output:**
```
NAME                                     READY   STATUS    RESTARTS
etcd-control-plane                       1/1     Running   0
kube-apiserver-control-plane            1/1     Running   0
kube-controller-manager-control-plane   1/1     Running   0
kube-scheduler-control-plane            1/1     Running   0
```

**What to observe:**
- Note the naming patterns (component-node)
- Check that all are in `Running` status
- Verify RESTARTS count is low (0 or very few)

#### Step 2: Check API Server Health

```bash
kubectl cluster-info
```

This shows the API server endpoint.

#### Step 3: Check Node Status

```bash
kubectl get nodes -o wide
```

**What to observe:**
- All nodes should show `Ready` status
- Note the ROLES column
- Check the VERSION of kubelet on each node

#### Step 4: Describe Control Plane Node

```bash
kubectl describe node $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
```

**Look for:**
- `Capacity` section showing available resources
- `Allocatable` showing what's actually usable
- `Conditions` to check node health
- `Non-terminated Pods` showing what's running
- `Events` for recent activity

### Verification Checklist

- [ ] All kube-system pods are Running
- [ ] cluster-info shows API server URL
- [ ] All nodes are Ready
- [ ] Node description shows capacity and conditions

### Troubleshooting

If pods are not running:
```bash
# Check pod details
kubectl describe pod <pod-name> -n kube-system

# Check pod logs
kubectl logs <pod-name> -n kube-system
```

---

## Lab 1.2: etcd Backup Operations

### Learning Objectives
- Understand etcd as the cluster's source of truth
- Create manual etcd backups
- Simulate backup verification

### Theory

**Why etcd backups are critical:**
- etcd stores ALL cluster state (deployments, pods, secrets, config)
- If etcd is lost without backup, the entire cluster state is lost
- Required for disaster recovery
- Should be automated and tested regularly

### Steps

#### Step 1: Create Test Data

First, create some resources we'll "backup":

```bash
kubectl create namespace lab-backup-test
kubectl run test-pod --image=nginx -n lab-backup-test
kubectl create configmap test-config --from-literal=key=value -n lab-backup-test
```

#### Step 2: Simulate etcd Backup

Since we may not have direct etcd access, we'll simulate with kubectl:

```bash
# Export all resources as YAML (simulating backup)
kubectl get all --all-namespaces -o yaml > cluster-backup-$(date +%Y%m%d).yaml

# Export specific namespace
kubectl get all -n lab-backup-test -o yaml > namespace-backup.yaml

# Verify backup file
echo "Backup size:"
ls -lh cluster-backup-*.yaml
```

#### Step 3: Simulate Data Loss

```bash
# Delete the test namespace
kubectl delete namespace lab-backup-test

# Verify it's gone
kubectl get namespace lab-backup-test
# Should show: "Error from server (NotFound)"
```

#### Step 4: Restore from Backup

```bash
# Restore namespace and resources
kubectl apply -f namespace-backup.yaml

# Verify restoration
kubectl get namespace lab-backup-test
kubectl get all -n lab-backup-test
```

### Verification Checklist

- [ ] Resources exported to YAML files
- [ ] Backup files have non-zero size
- [ ] After delete, namespace not found
- [ ] After restore, all resources recreated

### Cleanup

```bash
kubectl delete namespace lab-backup-test
rm -f cluster-backup-*.yaml namespace-backup.yaml
```

---

## Lab 1.3: API Server Failure Simulation

### Learning Objectives
- Understand what happens when API server is unavailable
- Learn about Kubernetes self-healing behavior
- Test delete and recreate scenarios

### Theory

**What happens when API server fails:**
- No new resources can be created or modified
- Existing pods continue running
- Kubelet uses cached state
- Service routing continues (kube-proxy is local)

### Steps

#### Step 1: Create a Deployment

```bash
kubectl create deployment resilience-test --image=nginx --replicas=3
```

#### Step 2: Observe Pod Names

```bash
kubectl get pods -l app=resilience-test
```

**Record the pod names for comparison.**

#### Step 3: Delete a Pod

```bash
# Delete one pod (simulating failure)
kubectl delete pod $(kubectl get pods -l app=resilience-test -o jsonpath='{.items[0].metadata.name}')

# Watch pods recreate
kubectl get pods -l app=resilience-test -w
# Press Ctrl+C after seeing new pod created
```

#### Step 4: Verify Self-Healing

```bash
kubectl get pods -l app=resilience-test
```

**What happened:**
- The ReplicaSet controller detected 2 pods (not desired 3)
- It created a new pod to restore count to 3
- This demonstrates the reconciliation loop

### Verification Checklist

- [ ] Deployment created with 3 replicas
- [ ] After deleting one pod, count temporarily goes to 2
- [ ] New pod automatically created
- [ ] Final count is 3 pods

### Cleanup

```bash
kubectl delete deployment resilience-test
```

---

## Lab 1.4: Controller Manager in Action

### Learning Objectives
- Observe the ReplicaSet controller behavior
- Understand self-healing at work
- See how scaling works

### Theory

Controllers continuously watch resources and ensure actual state matches desired state.

The ReplicaSet controller:
1. Watches ReplicaSet objects
2. Counts matching pods
3. Creates or deletes pods to match desired count
4. Repeats in a loop

### Steps

#### Step 1: Apply the ReplicaSet

Create file `replicaset-demo.yaml`:

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: controller-demo
  labels:
    lab: controller-test
spec:
  replicas: 5
  selector:
    matchLabels:
      app: controller-demo
  template:
    metadata:
      labels:
        app: controller-demo
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        resources:
          requests:
            memory: "32Mi"
            cpu: "50m"
```

Apply it:
```bash
kubectl apply -f replicaset-demo.yaml
```

#### Step 2: Verify 5 Pods Created

```bash
kubectl get pods -l app=controller-demo
```

You should see exactly 5 pods.

#### Step 3: Manually Delete 2 Pods

```bash
# Delete first pod
POD1=$(kubectl get pods -l app=controller-demo -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod $POD1

# Delete second pod
POD2=$(kubectl get pods -l app=controller-demo -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod $POD2
```

#### Step 4: Watch Auto-Recovery

```bash
kubectl get pods -l app=controller-demo -w
```

**Observe:**
- Count briefly goes to 3 pods
- New pods are immediately created
- Count returns to 5 within seconds

#### Step 5: Scale to 10 Replicas

```bash
kubectl scale rs controller-demo --replicas=10

# Watch scaling
kubectl get pods -l app=controller-demo -w
# Press Ctrl+C after count reaches 10
```

### Verification Checklist

- [ ] 5 pods created initially
- [ ] After deleting 2 pods, count temporarily 3
- [ ] Within seconds, count back to 5
- [ ] Scaling to 10 creates 5 new pods

### Cleanup

```bash
kubectl delete -f replicaset-demo.yaml
rm -f replicaset-demo.yaml
```

---

## Lab 1.5: Scheduler Node Selection

### Learning Objectives
- Understand how the scheduler selects nodes
- Use node selectors
- Observe scheduling decisions

### Theory

The scheduler uses a two-phase algorithm:
1. **Filtering:** Remove nodes that don't fit
2. **Scoring:** Rank remaining nodes, pick best

### Steps

#### Step 1: Check Node Labels

```bash
kubectl get nodes --show-labels | head -1
```

Every node has labels like:
- `kubernetes.io/os=linux`
- `kubernetes.io/arch=amd64`

#### Step 2: Create a Pod with Node Selector

Create file `node-selector-pod.yaml`:

```yaml
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
    resources:
      requests:
        memory: "64Mi"
        cpu: "50m"
```

Apply and check:
```bash
kubectl apply -f node-selector-pod.yaml
kubectl get pod scheduled-pod -o wide
```

The `NODE` column shows where it was scheduled.

#### Step 3: Check Scheduling Events

```bash
kubectl describe pod scheduled-pod | grep -A5 "Node-Selectors\|Node:"
```

You'll see the node assignment and any scheduling constraints.

### Verification Checklist

- [ ] Node labels listed
- [ ] Pod scheduled on appropriate node
- [ ] Wide output shows node assignment
- [ ] Describe shows node selector info

### Cleanup

```bash
kubectl delete pod scheduled-pod
rm -f node-selector-pod.yaml
```

---

## Completion Checklist

| Lab | Description | Status |
|-----|-------------|--------|
| 1.1 | Identify control plane components | [ ] |
| 1.2 | etcd backup operations | [ ] |
| 1.3 | API server failure simulation | [ ] |
| 1.4 | Controller manager behavior | [ ] |
| 1.5 | Scheduler node selection | [ ] |

**Mark each as complete in [CHECKLIST.md](../CHECKLIST.md)**
