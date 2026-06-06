# Chapter 9 Labs: Security

## Overview
Learn RBAC, network policies, security contexts.

---

## Lab 9.1: RBAC Setup

### Create ServiceAccount

Create `developer-sa.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: developer
  namespace: default
```

### Create Role

Create `pod-reader-role.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
```

### Create RoleBinding

Create `developer-binding.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-binding
subjects:
- kind: ServiceAccount
  name: developer
  namespace: default
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

### Test Authorization

```bash
kubectl get pods --as=system:serviceaccount:default:developer
```

---

## Lab 9.2: Pod Security Standards

### Enable Restricted Policy

Create `restricted-ns.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: restricted-ns
  labels:
    pod-security.kubernetes.io/enforce: restricted
```

### Create Compliant Pod

Create `secure-pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
  namespace: restricted-ns
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  containers:
  - name: app
    image: nginx:alpine
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
    volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: tmp
    emptyDir: {}
```

---

## Lab 9.3: Network Policies

### Create Default Deny

Create `default-deny.yaml`:

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

### Create Allow Policy

Create `allow-policy.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-web-to-api
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: web
    ports:
    - protocol: TCP
      port: 80
```

---

## Completion Checklist

| Lab | Description | Status |
|-----|-------------|--------|
| 9.1 | RBAC | [ ] |
| 9.2 | Pod Security | [ ] |
| 9.3 | Network Policies | [ ] |
