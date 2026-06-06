# Chapter 9: Security

## Interview Questions (20)

### Q1: How does RBAC work?

**Answer:**
```
User/SA → Role (permissions) + RoleBinding (associates them)
```

| Resource | Scope |
|----------|-------|
| Role | Namespace |
| ClusterRole | Cluster-wide |
| RoleBinding | Binds Role to subject in namespace |
| ClusterRoleBinding | Binds ClusterRole to subject cluster-wide |

### Q2: What are Network Policies?

**Answer:**
Kubernetes firewall - controls traffic between pods/namespaces.

Default: **Allow all**

Best practice: Default deny + explicit allow.

---

## ✅ Chapter Completion

Mark completed in [CHECKLIST.md](../CHECKLIST.md)
