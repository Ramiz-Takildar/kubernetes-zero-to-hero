# Chapter 9: Security

## 📚 Learning Objectives

By the end of this chapter, you will:
- Implement RBAC for access control
- Secure pods with security contexts
- Use Network Policies for micro-segmentation
- Apply Pod Security Standards

**Estimated Time:** 3 days  
**Labs:** 4 hands-on exercises

---

## 🔐 RBAC (Role-Based Access Control)

### Core Components

```
┌────────────────────────────────────────────────────────┐
│                    RBAC Flow                           │
│                                                        │
│  User/ServiceAccount                                   │
│       │                                                │
│       │ Authenticated (Who are you?)                   │
│       ▼                                                │
│  API Server                                            │
│       │                                                │
│       │ Authorized (What can you do?)                  │
│       ▼                                                │
│  Role/ClusterRole (What resources? What verbs?)        │
│       │                                                │
│       │ RoleBinding/ClusterRoleBinding (Who gets it?)  │
│       ▼                                                │
│  Action Allowed/Denied                                 │
└────────────────────────────────────────────────────────┘
```

### RBAC Resources

| Resource | Scope | Description |
|----------|-------|-------------|
| **Role** | Namespace | Permissions within a namespace |
| **ClusterRole** | Cluster-wide | Permissions across all namespaces |
| **RoleBinding** | Namespace | Grants Role to user/SA in namespace |
| **ClusterRoleBinding** | Cluster-wide | Grants ClusterRole to user/SA |

### Permission Model

```yaml
rules:
- apiGroups: [""]          # "", apps, rbac.authorization.k8s.io
  resources: ["pods"]      # pods, deployments, services
  verbs: ["get", "list"]   # get, list, watch, create, update, delete
```

---

## 🛡️ Security Contexts

### Container Hardening

```yaml
securityContext:
  # Run as non-root
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  
  # Prevent privilege escalation
  allowPrivilegeEscalation: false
  
  # Read-only filesystem
  readOnlyRootFilesystem: true
  
  # Drop all capabilities
  capabilities:
    drop:
    - ALL
  
  # Use seccomp
  seccompProfile:
    type: RuntimeDefault
```

### Pod vs Container Security

**Pod-level:** Applies to all containers
**Container-level:** Overrides pod-level

```yaml
spec:
  securityContext:          # Pod level
    runAsNonRoot: true
    fsGroup: 2000
  containers:
  - name: app
    securityContext:        # Container level
      allowPrivilegeEscalation: false
```

---

## 🌐 Network Policies

### Default Behavior

**By default:** All pods can talk to all pods (allow all).

### Zero-Trust Model

```yaml
# Step 1: Default deny all
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

```yaml
# Step 2: Allow specific traffic
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
      port: 8080
```

---

## 📊 Pod Security Standards

### Levels

| Level | Restrictions | Use Case |
|-------|--------------|----------|
| **Privileged** | Unrestricted | System workloads |
| **Baseline** | Minimal restrictions | Standard workloads |
| **Restricted** | Highly restricted | Critical workloads |

### Enforcing at Namespace Level

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: restricted-ns
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

**Violations:**
- `enforce`: Pod rejected
- `audit`: Pod allowed, event logged
- `warn`: Pod allowed, warning shown

---

## 📊 Theory to Labs

### Lab 9.1: RBAC
**Theory Applied:**
- Role/ClusterRole creation
- Bindings
- Service accounts

### Lab 9.2: Pod Security
**Theory Applied:**
- Security contexts
- Non-root containers
- Security standards

### Lab 9.3: Network Policies
**Theory Applied:**
- Default deny
- Explicit allow
- Ingress/egress rules

---

## 📖 Key Takeaways

1. **RBAC:** Who can do what
2. **Role:** Namespace-scoped permissions
3. **ClusterRole:** Cluster-wide permissions
4. **Binding:** Connects role to user/SA
5. **Security Context:** Container hardening
6. **Network Policy:** Pod firewall
7. **Pod Security Standards:** Predefined security levels

---

## ❓ Interview Questions

### Q: Role vs ClusterRole?

**Answer:**

| Role | ClusterRole |
|------|-------------|
| Namespace scope | Cluster scope |
| Resources in one namespace | Resources across cluster |
| RoleBinding | ClusterRoleBinding |

---

## 🔗 Next Steps

1. Review theory above
2. Complete [Lab 9.1](./LABS.md) - RBAC
3. Complete [Lab 9.2](./LABS.md) - Pod Security
4. Complete [Lab 9.3](./LABS.md) - Network Policies

**Next Chapter:** [Chapter 10: Advanced Topics](../chapter-10/)
