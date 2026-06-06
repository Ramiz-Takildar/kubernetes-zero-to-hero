# Chapter 4 Labs: Services & Networking

## Lab 4.1: ClusterIP Service Discovery

### Objective
Create services and test internal communication.

### Exercise
```bash
# 1. Create backend deployment
kubectl create deployment backend --image=hashicorp/http-echo \
  --replicas=3 -- \
  -text="Backend Response" -listen=:8080

# 2. Expose as ClusterIP service
kubectl expose deployment backend --port=80 --target-port=8080

# 3. Verify service has endpoints
kubectl get svc backend
kubectl get endpoints backend

# 4. Create client pod to test service discovery
kubectl run client --image=busybox --restart=Never --rm -it -- \
  wget -qO- http://backend

# Output: "Backend Response"

# 5. Test DNS resolution
kubectl run client --image=busybox --restart=Never --rm -it -- \
  nslookup backend

# 6. Check environment variables injected
kubectl run client --image=busybox --restart=Never --rm -it -- \
  env | grep BACKEND

# 7. Access via full DNS name
kubectl run client --image=busybox --restart=Never --rm -it -- \
  wget -qO- http://backend.default.svc.cluster.local

# 8. Create in different namespace
kubectl create namespace other-ns
kubectl create deployment backend --image=hashicorp/http-echo \
  --replicas=1 -n other-ns -- \
  -text="Other NS Backend" -listen=:8080
kubectl expose deployment backend --port=80 --target-port=8080 -n other-ns

# 9. Access cross-namespace
kubectl run client --image=busybox --restart=Never --rm -it -- \
  wget -qO- http://backend.other-ns

# 10. Clean up
kubectl delete deployment backend
kubectl delete service backend
kubectl delete namespace other-ns
```

### Solution Verification
```bash
# Verify service works internally
kubectl run verify --image=busybox --restart=Never --rm -it -- \
  wget -qO- http://backend 2>/dev/null && echo "✓ Service accessible"
```

---

## Lab 4.2: NodePort Service

### Objective
Expose service externally via NodePort.

### Exercise
```bash
# 1. Create deployment
kubectl create deployment frontend --image=nginx --replicas=2

# 2. Expose as NodePort
kubectl expose deployment frontend --type=NodePort --port=80

# 3. Get NodePort details
kubectl get svc frontend
# Note the NodePort (30000-32767)

# 4. Get node IP
kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}'

# 5. Access via NodePort (replace <node-ip> and <node-port>)
# curl http://<node-ip>:<node-port>

# For testing, use port-forward
kubectl port-forward svc/frontend 8080:80 &
curl http://localhost:8080
kill %1

# 6. Specify NodePort (if available)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: nodeport-custom
spec:
  type: NodePort
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
EOF

# 7. Clean up
kubectl delete deployment frontend
kubectl delete service frontend nodeport-custom
kubectl delete service frontend --ignore-not-found
```

---

## Lab 4.3: Ingress Routing

### Objective
Configure HTTP routing with Ingress.

### Prerequisites
Ingress controller installed (nginx-ingress)

### Exercise
```bash
# 1. Create applications
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-v1
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
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: web-v1
spec:
  selector:
    app: web
    version: v1
  ports:
  - port: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-v2
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
      version: v2
  template:
    metadata:
      labels:
        app: web
        version: v2
    spec:
      containers:
      - name: nginx
        image: httpd:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: web-v2
spec:
  selector:
    app: web
    version: v2
  ports:
  - port: 80
---
apiVersion: v1
kind: Service
metadata:
  name: api
spec:
  selector:
    app: api
  ports:
  - port: 8080
EOF

# Create a simple API app
kubectl create deployment api --image=hashicorp/http-echo \
  --replicas=1 -- -text="API Response" -listen=:8080

# 2. Create Ingress resource
cat <<EOF | kubectl apply -f -
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
              number: 8080
EOF

# 3. Check ingress status
kubectl get ingress
kubectl describe ingress web-ingress

# 4. Test (requires /etc/hosts entry or DNS)
# Or use port-forward to ingress controller
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80 2>/dev/null &
# curl -H "Host: myapp.local" http://localhost:8080/v1
# curl -H "Host: myapp.local" http://localhost:8080/v2
# curl -H "Host: myapp.local" http://localhost:8080/api

# 5. Clean up
kubectl delete deployment app-v1 app-v2 api
kubectl delete service web-v1 web-v2 api
kubectl delete ingress web-ingress
```

---

## Lab 4.4: Network Policy

### Objective
Implement micro-segmentation with Network Policies.

### Prerequisites
CNI plugin that supports NetworkPolicy (Calico, Cilium, etc.)

### Exercise
```bash
# 1. Create namespace
kubectl create namespace secure-app

# 2. Create frontend, backend, and database
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: secure-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: app
        image: busybox
        command: ['sh', '-c', 'echo Frontend; sleep 3600']
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: secure-app
spec:
  replicas: 2
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
        image: busybox
        command: ['sh', '-c', 'echo Backend; sleep 3600']
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
  namespace: secure-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      containers:
      - name: db
        image: busybox
        command: ['sh', '-c', 'echo Database; sleep 3600']
EOF

# 3. Test connectivity (everything can talk)
kubectl exec -n secure-app deployment/frontend -- nc -zv backend 80 || echo "Can connect"

# 4. Apply default deny policy (blocks all traffic)
cat <<EOF | kubectl apply -f -napiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: secure-app
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF

# 5. Allow frontend to backend
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: secure-app
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
EOF

# 6. Allow backend to database
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-database
  namespace: secure-app
spec:
  podSelector:
    matchLabels:
      app: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: backend
EOF

# 7. Test connectivity
# Frontend to Backend: SUCCESS
# Backend to Database: SUCCESS
# Frontend to Database: DENIED (by default deny)
# External to Frontend: DENIED (need additional policy)

# 8. Allow ingress to frontend
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress-to-frontend
  namespace: secure-app
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 80
EOF

# 9. Clean up
kubectl delete namespace secure-app
```

### Solution
Network flow:
```
External → Frontend → Backend → Database
                  ↘         ↗
                 (database blocks direct)
```

---

## Lab 4.5: DNS Troubleshooting

### Objective
Debug DNS resolution issues.

### Exercise
```bash
# 1. Create test pods
kubectl create deployment dns-test --image=busybox --replicas=2 -- sleep 3600

# 2. Test DNS from pod
kubectl exec deployment/dns-test -- nslookup kubernetes.default

# 3. Test service DNS
kubectl expose deployment dns-test --port=80
kubectl exec deployment/dns-test -- nslookup dns-test

# 4. Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# 5. Check CoreDNS config
kubectl get configmap coredns -n kube-system -o yaml

# 6. Enable CoreDNS logging (if needed)
kubectl edit configmap coredns -n kube-system
# Add: log
# Restart CoreDNS: kubectl rollout restart deployment coredns -n kube-system

# 7. Simulate DNS issue - create pod without DNS policy
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: no-dns
spec:
  dnsPolicy: Default
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'echo Testing DNS; nslookup google.com || echo DNS failed; sleep 3600']
EOF

kubectl logs no-dns

# 8. Clean up
kubectl delete deployment dns-test
kubectl delete service dns-test
kubectl delete pod no-dns
```

---

## Completion Checklist for Chapter 4

| Lab | Description | Status |
|-----|-------------|--------|
| 4.1 | ClusterIP service discovery | [ ] |
| 4.2 | NodePort service | [ ] |
| 4.3 | Ingress routing | [ ] |
| 4.4 | Network policy | [ ] |
| 4.5 | DNS troubleshooting | [ ] |
