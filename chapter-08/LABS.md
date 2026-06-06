# Chapter 8 Labs: Scheduling & Scaling

## Lab 8.1: Horizontal Pod Autoscaler

### Objective
Configure automatic pod scaling based on CPU.

### Prerequisites
metrics-server must be installed.

### Exercise
```bash
# 0. Verify metrics-server
kubectl get pods -n kube-system | grep metrics

# 1. Create deployment with resource requests
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hpa-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hpa
  template:
    metadata:
      labels:
        app: hpa
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
EOF

# 2. Expose service
kubectl expose deployment hpa-demo --port=80

# 3. Create HPA
kubectl autoscale deployment hpa-demo \
  --cpu-percent=50 \
  --min=1 \
  --max=10

# Or via YAML
cat <<EOF | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: hpa-demo
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: hpa-demo
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 30
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
EOF

# 4. Check current status
kubectl get hpa
# Shows: TARGETS 0%/50%, MINPODS 1, MAXPODS 10

# 5. Generate load
kubectl run load-generator --image=busybox --restart=Never -- \
  sh -c "while true; do wget -q -O- http://hpa-demo; done"

# 6. Watch HPA in action
kubectl get hpa -w
# Shows CPU increasing, eventually replicas scale up

# 7. Watch pods scale
kubectl get pods -l app=hpa -w
# Shows new pods being created

# 8. Wait and verify scaling
sleep 60
kubectl get pods -l app=hpa
# Shows multiple pods (up to 10)

# 9. Stop load generator
kubectl delete pod load-generator

# 10. Watch scale down
kubectl get hpa -w
# Eventually scales back to 1

# 11. Clean up
kubectl delete deployment hpa-demo
kubectl delete svc hpa-demo
kubectl delete hpa hpa-demo
```

---

## Lab 8.2: Node Affinity

### Objective
Control which nodes pods run on.

### Exercise
```bash
# 1. Check available node labels
kubectl get nodes --show-labels

# 2. Label a node (if multiple nodes available)
kubectl label nodes <node-name> disktype=ssd

# 3. Create pod with node selector (simple)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: node-selector
spec:
  nodeSelector:
    kubernetes.io/os: linux
  containers:
  - name: app
    image: busybox
    command: ['sleep', '3600']
EOF

kubectl get pod node-selector -o wide

# 4. Create pod with required node affinity
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: required-affinity
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: kubernetes.io/os
            operator: In
            values:
            - linux
  containers:
  - name: app
    image: busybox
    command: ['sleep', '3600']
EOF

kubectl get pod required-affinity -o wide

# 5. Create pod with preferred node affinity
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: preferred-affinity
spec:
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 10
        preference:
          matchExpressions:
          - key: disktype
            operator: In
            values:
            - ssd
  containers:
  - name: app
    image: busybox
    command: ['sleep', '3600']
EOF

kubectl get pod preferred-affinity -o wide
kubectl describe pod preferred-affinity | grep -A5 "Node-Selectors"

# 6. Create pod with anti-affinity (spread across nodes)
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spread-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: spread
  template:
    metadata:
      labels:
        app: spread
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - spread
              topologyKey: kubernetes.io/hostname
      containers:
      - name: app
        image: busybox
        command: ['sleep', '3600']
EOF

# Check distribution
kubectl get pods -l app=spread -o wide

# 7. Clean up
kubectl delete pod node-selector required-affinity preferred-affinity
kubectl delete deployment spread-deployment
kubectl label nodes <node-name> disktype-  # Remove label
```

---

## Lab 8.3: Taints and Tolerations

### Objective
Prevent pods from scheduling on specific nodes.

### Note
For single-node clusters (minikube, kind), this won't show full effect.

### Exercise
```bash
# 1. Check existing taints
kubectl describe nodes | grep Taints

# 2. Add taint to node
kubectl taint nodes <node-name> dedicated=special-user:NoSchedule

# 3. Try to schedule pod (will stay Pending)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: no-toleration
spec:
  containers:
  - name: app
    image: busybox
    command: ['sleep', '3600']
EOF

kubectl get pod no-toleration
kubectl describe pod no-toleration | grep -A5 Events
# Shows: node(s) had taint {dedicated=special-user: NoSchedule}

# 4. Add toleration to pod
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: with-toleration
spec:
  tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "special-user"
    effect: "NoSchedule"
  containers:
  - name: app
    image: busybox
    command: ['sleep', '3600']
EOF

kubectl get pod with-toleration -o wide
# Now it schedules

# 5. Use taint for dedicated control plane
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: control-plane-pod
spec:
  tolerations:
  - key: "node-role.kubernetes.io/control-plane"
    operator: "Exists"
    effect: "NoSchedule"
  containers:
  - name: app
    image: busybox
    command: ['sleep', '3600']
EOF

# 6. Remove taint
kubectl taint nodes <node-name> dedicated=special-user:NoSchedule-

# 7. Clean up
kubectl delete pod no-toleration with-toleration control-plane-pod
```

---

## Lab 8.4: Pod Disruption Budget

### Objective
Ensure minimum availability during disruptions.

### Exercise
```bash
# 1. Create deployment
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: critical-app
spec:
  replicas: 5
  selector:
    matchLabels:
      app: critical
  template:
    metadata:
      labels:
        app: critical
    spec:
      containers:
      - name: app
        image: nginx:alpine
EOF

# 2. Wait for pods to be ready
kubectl wait --for=condition=available --timeout=60s deployment/critical-app

# 3. Create Pod Disruption Budget
cat <<EOF | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: critical-pdb
spec:
  minAvailable: 3
  selector:
    matchLabels:
      app: critical
EOF

# 4. Check PDB status
kubectl get pdb
# Shows: MIN AVAILABLE 3, ALLOWED DISRUPTIONS 2

# 5. Try to drain node (if multi-node)
# kubectl drain <node-name> --ignore-daemonsets
# This will be blocked if it would violate PDB

# 6. Scale down to test PDB
kubectl scale deployment critical-app --replicas=2
kubectl get pdb
# Shows: ALLOWED DISRUPTIONS 0

# 7. Alternative PDB using maxUnavailable
cat <<EOF | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: critical-pdb-percent
spec:
  maxUnavailable: 30%
  selector:
    matchLabels:
      app: critical
EOF

# 8. Clean up
kubectl delete deployment critical-app
kubectl delete pdb critical-pdb critical-pdb-percent
```

---

## Completion Checklist for Chapter 8

| Lab | Description | Status |
|-----|-------------|--------|
| 8.1 | Horizontal Pod Autoscaler | [ ] |
| 8.2 | Node affinity | [ ] |
| 8.3 | Taints and tolerations | [ ] |
| 8.4 | Pod Disruption Budget | [ ] |
