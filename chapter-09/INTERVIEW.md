# Chapter 9: Security - Interview Questions

> 20+ Interview Questions with Detailed Answers

---

## Basic Level Questions

### Q1: What is RBAC in Kubernetes?

**Answer:**

**RBAC:** Role-Based Access Control - controls who can do what.

**Core verbs:**
```
CREATE, GET, LIST, WATCH, UPDATE, PATCH, DELETE
```

**Components:**
```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│     Role     │     │  RoleBinding │     │   User/SA    │
│ (What can be │────►│  (Who gets   │────►│   (Who)      │
│    done)     │     │   the role)  │     │              │
└──────────────┘     └──────────────┘     └──────────────┘
```

**Types:**
- **Role:** Namespace-scoped
- **ClusterRole:** Cluster-wide
- **RoleBinding:** Grants Role to user/SA in namespace
- **ClusterRoleBinding:** Grants ClusterRole cluster-wide

---

### Q2: What is the difference between Role and ClusterRole?

**Answer:**

| Role | ClusterRole |
|------|-------------|
| Namespace-scoped | Cluster-wide |
| Resources in one namespace | Resources across all namespaces |
| RoleBinding | ClusterRoleBinding |
| Example: pods, configmaps | Example: nodes, namespaces, CRDs |

**Role example:**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: production
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
```

---

### Q3: What are service accounts?

**Answer:**

**ServiceAccount:** Identity for processes running in pods.

**Default:** Every namespace has a `default` service account.

**Usage:**
```yaml
spec:
  serviceAccountName: my-sa
```

**Token:** Mounted at `/var/run/secrets/kubernetes.io/serviceaccount/token`

**Best practice:** Create dedicated service accounts per app, don't use default.

---

### Q4: What are security contexts?

**Answer:**

**Purpose:** Security settings for containers/pods.

**Common settings:**
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
    - ALL
```

**Pod vs Container:**
- Pod level: Applies to all containers
- Container level: Overrides pod level

---

### Q5: What is a Network Policy?

**Answer:**

**Purpose:** Firewall rules for pods.

**Default:** Allow all (no restriction).

**Example:**
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
      port: 8080
```

**Effect:** Only pods with label `app=web` can connect to port 8080.

---

## Intermediate Level Questions

### Q6: What is the difference between authentication and authorization?

**Answer:**

| Authentication | Authorization |
|----------------|---------------|
| Who are you? | What can you do? |
| Verifies identity | Checks permissions |
| Certificates, tokens | RBAC rules |
| First step | Second step |

**Flow:**
```
Request → Authentication (who?) → Authorization (allowed?) → Action
```

---

### Q7: What are admission controllers?

**Answer:**

**Purpose:** Intercept requests to validate or modify.

**Types:**
- **Mutating:** Can modify (add defaults, inject sidecars)
- **Validating:** Check but don't modify (policies)

**Examples:**
- **PodSecurityPolicy:** Security enforcement
- **ResourceQuota:** Limit resource usage
- **NamespaceLifecycle:** Prevent deleting active namespaces

**Order:** Mutating → Validating

---

### Q8: What are Pod Security Standards?

**Answer:**

**Three levels:**

| Level | Restriction | Use Case |
|-------|-------------|----------|
| **Privileged** | Unrestricted | System workloads |
| **Baseline** | Minimal restrictions | Standard apps |
| **Restricted** | Highly restricted | Security-critical |

**Enforcement:**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  labels:
    pod-security.kubernetes.io/enforce: restricted
```

---

### Q9: What is the principle of least privilege?

**Answer:**

**Definition:** Give minimal permissions needed to accomplish a task.

**Kubernetes application:**

| Bad | Good |
|-----|------|
| `*` on `*` resources | Specific resources only |
| Cluster-admin for everyone | Namespace-scoped roles |
| Wildcard verbs | Explicit verbs |

**Example:**
```yaml
# Bad - too broad
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]

# Good - minimal
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
  resourceNames: ["my-pod"]
```

---

### Q10: How do you restrict pod capabilities?

**Answer:**

**Drop all, add only needed:**
```yaml
securityContext:
  capabilities:
    drop:
    - ALL
    add:  # Only if needed
    - NET_BIND_SERVICE
```

**Why:** Reduces attack surface by removing unnecessary Linux capabilities.

---

## Advanced Level Questions

### Q11: What is Pod Security Admission?

**Answer:**

**Replacement for PodSecurityPolicy (deprecated).**

**Three modes:**
- **enforce:** Violations rejected
- **audit:** Violations logged
- **warn:** Violations warned

```yaml
apiVersion: v1
kind: Namespace
metadata:
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

---

### Q12: What is a security context for read-only root filesystem?

**Answer:**

```yaml
securityContext:
  readOnlyRootFilesystem: true
```

**Effect:** Container cannot write to root filesystem.

**Workarounds for write needs:**
```yaml
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
```

---

### Q13: How do you prevent privilege escalation?

**Answer:**

```yaml
securityContext:
  allowPrivilegeEscalation: false
```

**Effect:** Process cannot gain more privileges than parent.

**Combined with:**
```yaml
runAsNonRoot: true
runAsUser: 1000
```

---

### Q14: What is seccomp?

**Answer:**

**Seccomp:** Secure computing mode - filter system calls.

```yaml
securityContext:
  seccompProfile:
    type: RuntimeDefault
    # or
    type: Localhost
    localhostProfile: profiles/my-profile.json
```

**Profiles:**
- **RuntimeDefault:** Standard Docker/containerd profile
- **Localhost:** Custom profile
- **Unconfined:** No restrictions (dangerous)

---

### Q15: How do you audit RBAC permissions?

**Answer:**

```bash
# List all roles
kubectl get roles --all-namespaces

# Check user permissions
kubectl auth can-i --list --as=user@example.com

# Check specific permission
kubectl auth can-i create pods --as=user@example.com

# List service accounts
kubectl get serviceaccounts --all-namespaces
```

**Tools:**
- RBAC Manager
- RBAC Lookup
- Kubernetes Audit

---

## Scenario-Based Questions

### S1: User can list pods but not see logs.

**Answer:**

**Missing permission:**
```yaml
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["pods/log"]  # Add this
  verbs: ["get"]
```

---

### S2: Application needs to bind to port 80 but runs as non-root.

**Answer:**

**Problem:** Ports < 1024 require root.

**Solutions:**
1. **Use unprivileged port (8080):**
```yaml
ports:
- containerPort: 8080
```

2. **Add capability:**
```yaml
securityContext:
  capabilities:
    add:
    - NET_BIND_SERVICE
```

3. **Init container setup:**
```yaml
initContainers:
- name: setup
  image: busybox
  command: ['sh', '-c', 'setcap cap_net_bind_service=+ep /app']
  securityContext:
    capabilities:
      add:
      - NET_BIND_SERVICE
```

---

## Quick Reference

| Security Feature | Purpose |
|------------------|---------|
| RBAC | Access control |
| Network Policy | Pod firewall |
| Security Context | Container hardening |
| Pod Security Standards | Security enforcement |
| Seccomp | System call filters |

---

## Key Takeaways

1. **RBAC:** Who can do what
2. **Role:** Namespace permissions
3. **ClusterRole:** Cluster-wide permissions
4. **ServiceAccount:** Pod identity
5. **NetworkPolicy:** Micro-segmentation
6. **readOnlyRootFilesystem:** Prevent writes
7. **runAsNonRoot:** Security baseline
8. **drop ALL capabilities:** Reduce attack surface

---

**Previous:** [Chapter 8 Interview Questions](../chapter-08/INTERVIEW.md)  
**Next:** [Chapter 10 Interview Questions](../chapter-10/INTERVIEW.md)
