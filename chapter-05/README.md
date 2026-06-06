# Chapter 5: Storage

## 📚 Learning Objectives

By the end of this chapter, you will:
- Understand PV/PVC lifecycle
- Configure dynamic provisioning with StorageClasses
- Choose appropriate access modes
- Use volume types effectively
- Implement backup and restore strategies

**Estimated Time:** 3 days  
**Labs:** 4 hands-on exercises

---

## 💾 Storage Architecture

### The Storage Flow

```
┌──────────────────────────────────────────────────────────────┐
│                    User / Developer                          │
│                                                              │
│  ┌────────────────────────────────────────────────────┐     │
│  │  PersistentVolumeClaim (PVC)                       │     │
│  │  - "I need 10Gi of storage"                        │     │
│  │  - "I need ReadWriteOnce access"                   │     │
│  └────────────────────┬───────────────────────────────┘     │
│                       │                                      │
│                       │ Binding                              │
│                       ▼                                      │
│  ┌────────────────────────────────────────────────────┐     │
│  │  PersistentVolume (PV)                             │     │
│  │  - Actual storage (NFS, EBS, etc.)                 │     │
│  │  - Created by admin or dynamic provisioner         │     │
│  └────────────────────┬───────────────────────────────┘     │
│                       │                                      │
│                       │ Provisioning                         │
│                       ▼                                      │
│  ┌────────────────────────────────────────────────────┐     │
│  │  Physical Storage                                  │     │
│  │  - AWS EBS / Azure Disk / GCP PD                   │     │
│  │  - NFS / iSCSI / Ceph                              │     │
│  └────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────┘
```

---

## 📦 PV vs PVC

### PersistentVolume (PV)

**What:** Cluster resource representing a piece of storage
**Created by:** Administrator or dynamic provisioner
**Lifecycle:** Independent of any single pod

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ebs-volume
spec:
  capacity:
    storage: 10Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: fast-ssd
  awsElasticBlockStore:
    volumeID: vol-12345
    fsType: ext4
```

### PersistentVolumeClaim (PVC)

**What:** User request for storage
**Created by:** Developer/user
**Lifecycle:** Bound to a PV, used by pods

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: fast-ssd
```

### Binding Process

```
Step 1: PVC Created
        "I need 10Gi RWO"
              │
              ▼
Step 2: Control Loop Matches
        Find PV where:
        - Capacity >= 10Gi ✓
        - AccessMode = RWO ✓
        - Available (unbound) ✓
              │
              ▼
Step 3: Bound
        PVC ──► PV
        1:1 relationship
              │
              ▼
Step 4: Pod Uses
        mountPath: /data
```

---

## 🔑 Access Modes

| Mode | Abbreviation | Description | Use Case |
|------|--------------|-------------|----------|
| **ReadWriteOnce** | RWO | One node can mount as read-write | Single pod databases |
| **ReadOnlyMany** | ROX | Many nodes read-only | Sharing static content |
| **ReadWriteMany** | RWX | Many nodes read-write | Shared storage (NFS) |
| **ReadWriteOncePod** | RWOP | One pod only (v1.22+) | Enhanced security |

```
RWO:    Single Pod ────────► Single Node ────────► Volume
        [Can write]

ROX:    Multiple Pods ─────► Multiple Nodes ─────► Volume
        [Read only]

RWX:    Multiple Pods ─────► Multiple Nodes ─────► Volume
        [All can write]
```

**Storage Support:**
| Volume Type | RWO | ROX | RWX |
|-------------|-----|-----|-----|
| AWS EBS | ✓ | ✗ | ✗ |
| Azure Disk | ✓ | ✗ | ✗ |
| GCP PD | ✓ | ✗ | ✗ |
| NFS | ✓ | ✓ | ✓ |
| CephFS | ✓ | ✓ | ✓ |
| hostPath | ✓ | ✗ | ✗ |

---

## ⚙️ StorageClass

### Purpose

StorageClass enables **dynamic provisioning** - automatically creating PVs when PVCs are requested.

### Static vs Dynamic Provisioning

```
Static (Manual):
┌─────────┐     ┌─────────┐     ┌─────────┐
│  Admin  │────►│   PV    │◄────│   PVC   │
└─────────┘     └─────────┘     └─────────┘
  Creates          Waits          Claims
  manually         for            storage
                  binding

Dynamic (Automatic):
┌─────────┐     ┌─────────────┐     ┌─────────┐
│   PVC   │────►│ StorageClass │────►│   PV    │
│ Created │     │ Automatic    │     │ Created │
└─────────┘     │ Provisioner  │     │ on fly  │
                └─────────────┘     └─────────┘
```

### StorageClass Definition

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3
  encrypted: "true"
  iopsPerGB: "10"
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

### Key Parameters

| Parameter | Description |
|-----------|-------------|
| **provisioner** | Plugin that creates storage (AWS/GCP/Azure/NFS) |
| **parameters** | Cloud-specific settings (disk type, encryption) |
| **reclaimPolicy** | What happens when PVC is deleted (Delete/Retain) |
| **volumeBindingMode** | When to provision (Immediate/WaitForFirstConsumer) |
| **allowVolumeExpansion** | Can PVC request more storage later |

### Reclaim Policies

| Policy | Behavior | When to Use |
|--------|----------|-------------|
| **Delete** | Deletes PV and underlying storage when PVC deleted | Development, ephemeral |
| **Retain** | Keeps PV and data | Production, important data |

---

## 📊 StatefulSets with Storage

### Pattern

```
StatefulSet: web-0, web-1, web-2

Each pod gets its own PVC:
  web-0 ──► data-web-0 (PV)
  web-1 ──► data-web-1 (PV)
  web-2 ──► data-web-2 (PV)

Pod deleted? PVC remains → Pod recreated → Same PVC attached
```

### VolumeClaimTemplate

```yaml
volumeClaimTemplates:
- metadata:
    name: data
  spec:
    accessModes: ["ReadWriteOnce"]
    storageClassName: fast-ssd
    resources:
      requests:
        storage: 10Gi
```

**Result:** 3 PVCs created: `data-web-0`, `data-web-1`, `data-web-2`

---

## 📦 Volume Types

### emptyDir

**Lifecycle:** Pod lifetime (deleted when pod dies)

```yaml
volumes:
- name: cache
  emptyDir: {}
```

**Use cases:**
- Temporary cache
- Sharing files between containers in pod

---

### hostPath

**Lifecycle:** Node lifetime (survives pod restart, persists on node)

```yaml
volumes:
- name: logs
  hostPath:
    path: /var/log/myapp
    type: DirectoryOrCreate
```

**DANGER:**
- Security risk (access to host filesystem)
- Scheduling issues (pod tied to specific node)
- Use only for system pods (logging, monitoring)

---

### PersistentVolumeClaim

**Lifecycle:** Independent of pod (survives pod deletion)

```yaml
volumes:
- name: data
  persistentVolumeClaim:
    claimName: my-pvc
```

**Use cases:**
- Databases
- User data
- Any data that must persist

---

### projected

Combines multiple sources into one volume:

```yaml
volumes:
- name: all-in-one
  projected:
    sources:
    - secret:
        name: my-secret
    - configMap:
        name: my-config
    - downwardAPI:
        items:
        - path: podname
          fieldRef:
            fieldPath: metadata.name
```

---

## 💾 Volume Snapshots

**Purpose:** Point-in-time copy of a volume for backup/restore.

```
PVC (Running DB)
    │
    ▼
VolumeSnapshot (Backup created)
    │
    ▼
New PVC created from snapshot (Restore)
    │
    ▼
New Pod uses restored data
```

---

## 📊 Theory to Labs

### Lab 5.1: Database Storage
**Theory Applied:**
- PVC creation
- Mounting to StatefulSet
- Data persistence across pod restarts

### Lab 5.2: Shared Storage
**Theory Applied:**
- RWX access mode
- NFS for multi-pod access
- Read-only mounts

### Lab 5.3: Volume Snapshots
**Theory Applied:**
- CSI drivers
- Creating snapshots
- Restoring from snapshot

---

## 📖 Key Takeaways

1. **PVC = Request, PV = Resource:** User requests, cluster provides
2. **Dynamic Provisioning:** StorageClass creates PVs on demand
3. **Access Modes:** RWO most common, RWX needs special storage
4. **StatefulSet:** Each pod gets own PVC, stable identity
5. **emptyDir:** Temporary, pod lifetime
6. **hostPath:** Dangerous, avoid in user workloads
7. **Snapshots:** Point-in-time backups with CSI
8. **VolumeExpansion:** Can grow PVC (if SC allows)

---

## ❓ Interview Questions

### Q: PV vs PVC?

**Answer:**

| PV | PVC |
|----|-----|
| Cluster resource | User request |
| Admin or provisioner creates | Developer creates |
| Actual storage (NFS, EBS) | Request for storage |
| Persistent | Bound to Pod lifecycle |

**Relationship:** Many-to-one binding. One PVC binds to one PV.

---

### Q: Static vs Dynamic Provisioning?

**Answer:**

**Static:**
- Admin manually creates PVs
- PVC claims existing PV
- Good for predictable workloads

**Dynamic:**
- StorageClass creates PV when PVC requested
- Automatic, scalable
- Default for cloud environments

```yaml
# Dynamic - just request
spec:
  storageClassName: standard  # Creates automatically
```

---

## 🔗 Next Steps

1. Review theory above
2. Complete [Lab 5.1](./LABS.md) - Database Storage
3. Complete [Lab 5.2](./LABS.md) - Shared Storage
4. Complete [Lab 5.3](./LABS.md) - Snapshots

**Next Chapter:** [Chapter 6: Configuration](../chapter-06/)
