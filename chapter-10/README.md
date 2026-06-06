# Chapter 10: Advanced Topics

## 📚 Learning Objectives

By the end of this chapter, you will:
- Create Custom Resource Definitions (CRDs)
- Implement GitOps workflows
- Understand disaster recovery strategies
- Prepare for real-world scenarios

**Estimated Time:** 4 days  
**Labs:** 3 hands-on exercises

---

## 🔧 Custom Resource Definitions (CRD)

### Purpose

Extend Kubernetes API with custom resources.

### How CRDs Work

```
┌─────────────────────────────────────────────────────┐
│  User defines CRD                                   │
│  (Custom Resource Definition)                       │
│          │                                          │
│          ▼                                          │
│  Kubernetes API extended                            │
│  - New API endpoint created                         │
│  - Validation schema registered                     │
│          │                                          │
│          ▼                                          │
│  User creates Custom Resource                       │
│  (instance of the CRD)                              │
│          │                                          │
│          ▼                                          │
│  Operator watches and acts                          │
│  - Reconciles desired state                         │
│  - Manages real resources                           │
└─────────────────────────────────────────────────────┘
```

### Example: Database CRD

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: databases.example.com
spec:
  group: example.com
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              replicas:
                type: integer
                minimum: 1
              storage:
                type: string
  scope: Namespaced
  names:
    plural: databases
    kind: Database
```

---

## 🔄 GitOps

### Concept

Git as single source of truth for cluster state.

```
┌─────────────────────────────────────────────────────┐
│                                                     │
│   Git Repository                                    │
│   ├── manifests/                                    │
│   │   ├── deployment.yaml                           │
│   │   ├── service.yaml                              │
│   │   └── configmap.yaml                            │
│   └── kustomization.yaml                            │
│          │                                          │
│          │ GitOps Tool (Flux/ArgoCD) watches        │
│          ▼                                          │
│   Kubernetes Cluster                                │
│   - Resources automatically applied                 │
│   - Drift detection and correction                  │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### Benefits

- Version control for infrastructure
- Audit trail
- Easy rollbacks
- Collaboration
- Drift detection

---

## 💾 Disaster Recovery

### etcd Backup

```bash
# Backup
etcdctl snapshot save backup.db

# Restore
etcdctl snapshot restore backup.db
```

### Velero for Cluster Backup

Backs up:
- Kubernetes resources
- Persistent volumes

```yaml
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: daily-backup
spec:
  includedNamespaces:
  - production
  storageLocation: aws
  ttl: 720h
```

---

## 📊 Theory to Labs

### Lab 10.1: CRD
**Theory Applied:**
- Custom resource definition
- Schema validation
- Creating instances

### Lab 10.2: GitOps
**Theory Applied:**
- GitOps principles
- Flux/ArgoCD setup
- Declarative updates

### Lab 10.3: Disaster Recovery
**Theory Applied:**
- etcd backup
- Velero backup
- Restore procedures

---

## 📖 Key Takeaways

1. **CRD:** Extend Kubernetes API
2. **Operator:** Controller for custom resources
3. **GitOps:** Git as source of truth
4. **etcd Backup:** Critical for disaster recovery
5. **Velero:** Full cluster backup solution

---

## 🎓 Congratulations!

You have completed all 10 chapters!

### Next Steps

1. Complete all labs
2. Practice interview questions
3. Take the CKA/CKAD exam
4. Build real projects

---

## 🔗 Repository

**GitHub:** https://github.com/Ramiz-Takildar/kubernetes-zero-to-hero

**Track Progress:** [CHECKLIST.md](../CHECKLIST.md)
