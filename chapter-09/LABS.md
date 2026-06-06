# Chapter 9 Labs: Security

## Lab 9.1: RBAC - Roles and Bindings

### Objective
Configure role-based access control.

### Exercise
```bash
# 1. Create namespace
kubectl create namespace rbac-test

# 2. Create ServiceAccount
kubectl create serviceaccount dev-user -n rbac-test

# 3. Create Role (namespace-scoped)
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: rbac-test
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get", "list"]
EOF

# 4. Bind Role to ServiceAccount
kubectl create rolebinding dev-user-binding \
  --role=pod-reader \
  --serviceaccount=rbac-test:dev-user \
  -n rbac-test

# 5. Test access with impersonation
# Should work:
kubectl get pods -n rbac-test --as=system:serviceaccount:rbac-test:dev-user

# Should fail (no permission):
kubectl create deployment test --image=nginx -n rbac-test \
  --as=system:serviceaccount:rbac-test:dev-user 2>&1
# Error: forbidden

# 6. Create ClusterRole
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-viewer
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["nodes/proxy"]
  verbs: ["get"]
EOF

# 7. Bind ClusterRole cluster-wide
kubectl create clusterrolebinding node-viewer-binding \
  --clusterrole=node-viewer \
  --serviceaccount=rbac-test:dev-user

# 8. Test cluster-scoped access
kubectl get nodes --as=system:serviceaccount:rbac-test:dev-user

# 9. Check access with auth can-i
kubectl auth can-i get pods -n rbac-test \
  --as=system:serviceaccount:rbac-test:dev-user
# yes

kubectl auth can-i create deployments -n rbac-test \
  --as=system:serviceaccount:rbac-test:dev-user
# no

# 10. Clean up
kubectl delete namespace rbac-test
kubectl delete clusterrole node-viewer
kubectl delete clusterrolebinding node-viewer-binding
```

---

## Lab 9.2: Network Policies

### Objective
Implement network segmentation.

### Prerequisites
CNI plugin supporting NetworkPolicy (Calico, Cilium, etc.)

### Exercise
```bash
# 1. Create test namespace
kubectl create namespace netpol-test

# 2. Create pods
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  namespace: netpol-test
  labels:
    app: frontend
spec:
  containers:
  - name: app
    image: busybox
    command: ['nc', '-lk', '-p', '80', '-e', 'echo', 'Frontend']
---
apiVersion: v1
kind: Pod
metadata:
  name: backend
  namespace: netpol-test
  labels:
    app: backend
spec:
  containers:
  - name: app
    image: busybox
    command: ['nc', '-lk', '-p', '80', '-e', 'echo', 'Backend']
---
apiVersion: v1
kind: Pod
metadata:
  name: database
  namespace: netpol-test
  labels:
    app: database
spec:
  containers:
  - name: app
    image: busybox
    command: ['nc', '-lk', '-p', '5432', '-e', 'echo', 'Database']
---
apiVersion: v1
kind: Pod
metadata:
  name: attacker
  namespace: netpol-test
  labels:
    app: attacker
spec:
  containers:
  - name: app
    image: busybox
    command: ['sleep', '3600']
EOF

# 3. Test connectivity (should work)
kubectl exec -n netpol-test attacker -- nc -zv backend 80

# 4. Apply default deny
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: netpol-test
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF

# 5. Test connectivity (should fail now)
kubectl exec -n netpol-test attacker -- nc -zv backend 80 -w 2 2>&1 || echo "Blocked!"

# 6. Allow frontend to backend
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-to-backend
  namespace: netpol-test
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
    ports:
    - protocol: TCP
      port: 80
EOF

# 7. Test from frontend (should work)
kubectl exec -n netpol-test frontend -- sh -c "nc -zv backend 80 && echo 'Success'"

# 8. Test from attacker (should fail)
kubectl exec -n netpol-test attacker -- nc -zv backend 80 -w 2 2>&1 || echo "Blocked as expected"

# 9. Allow backend to database
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-to-db
  namespace: netpol-test
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
    ports:
    - protocol: TCP
      port: 5432
---
# Allow backend egress to db
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-egress
  namespace: netpol-test
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: database
    ports:
    - protocol: TCP
      port: 5432
  - to: []  # DNS
    ports:
    - protocol: UDP
      port: 53
EOF

# 10. Allow DNS
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: netpol-test
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector: {}
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
EOF

# 11. Clean up
kubectl delete namespace netpol-test
```

---

## Lab 9.3: Security Contexts

### Objective
Restrict container privileges.

### Exercise
```bash
# 1. Create privileged pod (DANGEROUS)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: privileged-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'id; sleep 3600']
    securityContext:
      privileged: true  # Full access to host
EOF

kubectl logs privileged-pod
date
kubectl delete pod privileged-pod

# 2. Create restrictive pod
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'id; sleep 3600']
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
      readOnlyRootFilesystem: true
      seccompProfile:
        type: RuntimeDefault
    volumeMounts:
    - name: tmp
      mountPath: /tmp
    - name: cache
      mountPath: /var/cache
  volumes:
  - name: tmp
    emptyDir: {}
  - name: cache
    emptyDir: {}
EOF

kubectl logs secure-pod
# Shows: uid=1000 gid=3000

kubectl delete pod secure-pod

# 3. Test permission denied for root actions
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: nonroot-test
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 1000
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'whoami; mkdir /root-test 2>&1 || echo "Permission denied"; sleep 3600']
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
EOF

kubectl logs nonroot-test
# root uid=1000
# mkdir: can't create directory '/root-test': Permission denied
# Permission denied

kubectl delete pod nonroot-test
```

---

## Lab 9.4: Pod Security Standards

### Objective
Apply Pod Security Standards.

### Exercise
```bash
# 1. Check current Pod Security Standard
kubectl get namespace -o jsonpath='{range .items[*]}{@.metadata.name}{"\t"}{@.metadata.labels}{"\n"}{end}' | grep pod-security

# 2. Label namespace with security standard
kubectl create namespace secure-ns
kubectl label namespace secure-ns pod-security.kubernetes.io/enforce=restricted
kubectl label namespace secure-ns pod-security.kubernetes.io/warn=restricted
kubectl label namespace secure-ns pod-security.kubernetes.io/audit=restricted

# 3. Try to create insecure pod (should be blocked)
cat <<EOF | kubectl apply -f - -n secure-ns 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: insecure
spec:
  containers:
  - name: app
    image: nginx
    securityContext:
      privileged: true
EOF
# Error: violates PodSecurity

# 4. Create compliant pod
cat <<EOF | kubectl apply -f - -n secure-ns
apiVersion: v1
kind: Pod
metadata:
  name: secure
spec:
  securityContext:
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: nginx
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: tmp
      mountPath: /tmp
    - name: cache
      mountPath: /var/cache
    - name: run
      mountPath: /var/run
  volumes:
  - name: tmp
    emptyDir: {}
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
EOF

# 5. Check pod is running
kubectl get pod -n secure-ns

# 6. Clean up
kubectl delete namespace secure-ns
```

---

## Completion Checklist for Chapter 9

| Lab | Description | Status |
|-----|-------------|--------|
| 9.1 | RBAC roles and bindings | [ ] |
| 9.2 | Network policies | [ ] |
| 9.3 | Security contexts | [ ] |
| 9.4 | Pod Security Standards | [ ] |
