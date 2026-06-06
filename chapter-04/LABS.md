# Chapter 4 Labs: Services & Networking

## Overview

Learn Kubernetes networking, service discovery, Ingress routing, and network policies.

---

## Lab 4.1: Service Discovery

Create ClusterIP, NodePort services and test DNS resolution.

### Part A: Create Backend Deployment

Create `backend-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: app
        image: hashicorp/http-echo
        args:
          - "-text=Backend Response"
          - "-listen=:8080"
        ports:
        - containerPort: 8080
```

Apply and verify pods are running.

### Part B: Create ClusterIP Service

Create `backend-service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend
spec:
  type: ClusterIP
  selector:
    app: backend
  ports:
  - port: 80
    targetPort: 8080
```

Check endpoints and test connectivity from another pod.

### Part C: Test DNS Resolution

```bash
kubectl run test --rm -i --restart=Never --image=busybox -- nslookup backend
```

---

## Lab 4.2: NodePort Service

Create service accessible externally.

### Create NodePort Service

Create `nodeport-service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-nodeport
spec:
  type: NodePort
  selector:
    app: backend
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30080
```

### Verification

```bash
kubectl get svc web-nodeport
# Note the NodePort (30000-32767 range)

# Access via node IP
# curl http://<node-ip>:30080
```

---

## Lab 4.3: Ingress Routing

Configure HTTP routing with Ingress.

### Step 1: Create Applications

Create `web-v1.yaml`, `web-v2.yaml`, `api-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-v1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
      version: v1
  template:
    metadata:
      labels:
        app: web
        version: v1
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
```

### Step 2: Create Ingress

Create `ingress-routing.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: myapp.local
    http:
      paths:
      - path: /v1
        pathType: Prefix
        backend:
          service:
            name: web-v1
            port:
              number: 80
      - path: /v2
        pathType: Prefix
        backend:
          service:
            name: web-v2
            port:
              number: 80
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api
            port:
              number: 80
```

---

## Lab 4.4: Network Policies

Implement zero-trust network security.

### Step 1: Create Test Pods

Create `network-test-pods.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  labels:
    app: frontend
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'while true; do sleep 10; done']
---
apiVersion: v1
kind: Pod
metadata:
  name: backend
  labels:
    app: backend
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'while true; do sleep 10; done']
```

### Step 2: Create Default Deny

Create `default-deny-netpol.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

### Step 3: Allow Frontend to Backend

Create `allow-frontend.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
```

---

## Lab 4.5: DNS Troubleshooting

Debug and fix DNS issues.

### Step 1: Check CoreDNS

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

### Step 2: Check DNS Config

```bash
kubectl get configmap coredns -n kube-system -o yaml
```

### Step 3: Test DNS

```bash
kubectl run test --rm -i --restart=Never --image=busybox -- nslookup kubernetes.default
```

---

## Completion Checklist

| Lab | Description | Status |
|-----|-------------|--------|
| 4.1 | Service Discovery | [ ] |
| 4.2 | NodePort Service | [ ] |
| 4.3 | Ingress Routing | [ ] |
| 4.4 | Network Policies | [ ] |
| 4.5 | DNS Troubleshooting | [ ] |
