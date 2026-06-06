# Chapter 5: Storage

## 📚 Learning Objectives

- PV/PVC lifecycle
- Storage Classes
- Access modes
- Volume types

## ❓ Interview Questions (15)

### Q1: What is the difference between PV and PVC?

**Answer:**

| PV (PersistentVolume) | PVC (PersistentVolumeClaim) |
|----------------------|---------------------------|
| Cluster resource (admin provisions) | User request (developer creates) |
| Actual storage backend | Request for storage |
| Can be static or dynamic | Always bound to a PV |
| Lifecycle independent | Lifecycle tied to pod |

### Q2: What are access modes?

**Answer:**
| Mode | Meaning |
|------|---------|
| RWO | ReadWriteOnce - One node, read-write |
| ROX | ReadOnlyMany - Many nodes, read-only |
| RWX | ReadWriteMany - Many nodes, read-write |

### Q3-15: [See full README]

---

## ✅ Chapter Completion

Mark completed in [CHECKLIST.md](../CHECKLIST.md)
