# Chapter 5: Storage - Interview Questions

> 15+ Interview Questions with Detailed Answers

---

## Basic Level Questions

### Q1: What is the difference between PV and PVC?

**Answer:**

| PV (PersistentVolume) | PVC (PersistentVolumeClaim) |
|----------------------|----------------------------|
| Cluster resource | User request |
| Admin/provisioner creates | Developer/user creates |
| Actual storage (NFS, EBS) | Request for storage |
| Independent lifecycle | Bound to PV |

**Relationship:**
```
PVC requests → Matches → PV
binding    ←────────→
```

**Flow:**
1. User creates PVC
2. Kubernetes finds matching PV
3. PV and PVC become Bound
4. Pod uses PVC as volume

---

### Q2: What are the access modes in Kubernetes storage?

**Answer:**

| Mode | Abbreviation | Description |
|------|--------------|-------------|
| **ReadWriteOnce** | RWO | One node, read-write |
| **ReadOnlyMany** | ROX | Many nodes, read-only |
| **ReadWriteMany** | RWX | Many nodes, read-write |
| **ReadWriteOncePod** | RWOP | One pod only (v1.22+) |

**Storage support:**

| Volume Type | RWO | ROX | RWX |
|-------------|-----|-----|-----|
| AWS EBS | ✓ | ✗ | ✗ |
| Azure Disk | ✓ | ✗ | ✗ |
| GCP PD | ✓ | ✗ | ✗ |
| NFS | ✓ | ✓ | ✓ |
| CephFS | ✓ | ✓ | ✓ |

---

### Q3: What is dynamic provisioning?

**Answer:**

**Dynamic:** StorageClass creates PV when PVC requested.

**Static:** Admin pre-creates PVs.

**Dynamic flow:**
```
User creates PVC
       │
       ▼
StorageClass detected
       │
       ▼
Provisioner creates storage in cloud
       │
       ▼
PV created automatically
       │
       ▼
PV binds to PVC
```

**Static flow:**
```
Admin creates PVs manually
User creates PVC
Kubernetes matches PVC to available PV
```

---

### Q4: What is a StorageClass?

**Answer:**

**Purpose:** Enables dynamic provisioning of storage.

**Key parameters:**
```yaml
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3
  encrypted: "true"
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
```

| Parameter | Purpose |
|-----------|---------|
| **provisioner** | Plugin that creates storage |
| **reclaimPolicy** | Delete/Retain when PVC deleted |
| **volumeBindingMode** | Immediate or WaitForFirstConsumer |
| **allowVolumeExpansion** | Allow PVC resize |

**Volume Binding Modes:**
- **Immediate:** Creates PV immediately
- **WaitForFirstConsumer:** Delays until pod scheduled

---

### Q5: What is the reclaim policy?

**Answer:**

| Policy | Behavior | When to Use |
|--------|----------|-------------|
| **Delete** | Deletes PV and underlying storage | Development, ephemeral |
| **Retain** | Keeps PV and data | Production, data retention |

**Delete flow:**
```
PVC deleted → PV deleted → Cloud storage deleted
```

**Retain flow:**
```
PVC deleted → PV Released → Admin manually cleans up
```

---

## Intermediate Level Questions

### Q6: How does StatefulSet work with storage?

**Answer:**

**StatefulSet pattern:**
```
StatefulSet: web-0, web-1, web-2

Each pod gets own PVC:
  web-0 → pvc-data-web-0
  web-1 → pvc-data-web-1
  web-2 → pvc-data-web-2

Pod deleted → PVC remains
Pod recreated → Same PVC reattached
```

**VolumeClaimTemplate:**
```yaml
volumeClaimTemplates:
- metadata:
    name: data
  spec:
    accessModes: ["ReadWriteOnce"]
    resources:
      requests:
        storage: 10Gi
```

**Result:** 3 PVCs created: `data-web-0`, `data-web-1`, `data-web-2`

---

### Q7: What is the difference between emptyDir and hostPath?

**Answer:**

| emptyDir | hostPath |
|----------|----------|
| Created when pod starts | Points to host filesystem |
| Deleted when pod dies | Persists on host |
| Shared between containers | Node-local only |
| Secure | Security risk |

**Use emptyDir for:** Temporary cache, sharing files between containers

**Use hostPath for:** Accessing host logs (system pods only)

**Avoid hostPath for:** User applications (scheduling issues, security)

---

### Q8: How do you expand a PVC?

**Answer:**

**Requirements:**
1. StorageClass must have `allowVolumeExpansion: true`
2. PVC must be bound
3. Volume plugin support

**Process:**
```bash
# Edit PVC
kubectl edit pvc mypvc
# Change spec.resources.requests.storage to larger size

# Verify
kubectl get pvc mypvc
```

**Note:** Can only increase size, not decrease.

---

### Q9: What is a volume snapshot?

**Answer:**

**Purpose:** Point-in-time copy of volume for backup/restore.

**Prerequisites:** CSI driver supporting snapshots

**Flow:**
```
PVC (Running DB)
    │
    ▼
VolumeSnapshot (Backup created)
    │
    ▼
New PVC created from snapshot
    │
    ▼
Pod uses restored data
```

**YAML:**
```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: db-snapshot
spec:
  volumeSnapshotClassName: csi-snapclass
  source:
    persistentVolumeClaimName: db-pvc
```

---

### Q10: What is project volume type?

**Answer:**

**Purpose:** Combine multiple volume sources into one.

**Use case:** Mount ConfigMap, Secret, and Downward API together.

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

## Advanced Level Questions

### Q11: What is WaitForFirstConsumer volume binding mode?

**Answer:**

**Immediate:**
- PV created when PVC is created
- May create PV on node with no room for pod

**WaitForFirstConsumer:**
- PV creation delayed until pod scheduled
- Ensures PV created in same zone as pod
- Solves volume availability issues

```yaml
volumeBindingMode: WaitForFirstConsumer
```

**Common with:** Multi-zone clusters

---

### Q12: What happens when a PVC can't find a PV?

**Answer:**

**State:** PVC remains in Pending

**Causes:**
1. No PV with matching access mode
2. No PV with sufficient capacity
3. No PV with matching storage class
4. No dynamic provisioner for storage class

**Debug:**
```bash
kubectl describe pvc mypvc
# Events show: "waiting for a volume to be created"

# Check storage class
kubectl get storageclass

# Check for dynamic provisioner
kubectl get pods -n kube-system | grep provisioner
```

---

### Q13: How do you backup PersistentVolumes?

**Answer:**

**Methods:**

1. **Volume Snapshots (CSI):**
```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
spec:
  source:
    persistentVolumeClaimName: mysql-pvc
```

2. **Application-level:** Database backups (mysqldump, pg_dump)

3. **Velero:** Cluster-wide backup including PVs

---

### Q14: What is fstype and why does it matter?

**Answer:**

**fstype:** Filesystem type (ext4, xfs, etc.)

**Matters because:**
- Different performance characteristics
- Different size limits
- Different features (journaling, snapshots)

**Common types:**
- **ext4:** Default, good general purpose
- **xfs:** Better for large files
- **btrfs:** Advanced features, snapshots

---

### Q15: Can multiple pods use the same PVC?

**Answer:**

**Depends on access mode:**

| Access Mode | Multiple Pods |
|-------------|---------------|
| RWO | Only on same node |
| RWX | Yes, different nodes |
| ROX | Yes (read-only) |

**Use RWX for:** Shared file storage (NFS, CephFS)

---

## Scenario-Based Questions

### S1: PVC stuck in Pending state.

**Answer:**

**Check:**
```bash
kubectl describe pvc mypvc
# Look for events

# Common causes:
# - No matching PV
# - No storage class
# - Provisioner not running
# - No matching access mode

# Fix:
# - Create PV manually (static)
# - Create storage class (dynamic)
# - Add provisioner
```

---

### S2: StatefulSet pod rescheduled but data missing.

**Answer:**

**Likely causes:**
1. Used Deployment instead of StatefulSet
2. PVC deleted manually
3. Wrong storage class (delete policy)

**Verify StatefulSet:**
```bash
kubectl get statefulset
kubectl get pvc | grep web  # Should see data-web-0, etc.
```

---

## Quick Reference

| Volume Type | Lifecycle | Use Case |
|-------------|-----------|----------|
| emptyDir | Pod | Temp files |
| hostPath | Node | Access host files |
| PVC | PVC | Persistent data |
| configMap | ConfigMap | Config files |
| secret | Secret | Sensitive data |

---

## Key Takeaways

1. **PVC requests, PV provides:** Separation of concerns
2. **Dynamic provisioning:** Automatic via StorageClass
3. **Access modes:** RWO common, RWX needs special storage
4. **StatefulSet:** Each pod gets own PVC
5. **Snapshots:** CSI-based point-in-time backup
6. **Retain policy:** Saves data (manual cleanup needed)

---

**Previous:** [Chapter 4 Interview Questions](../chapter-04/INTERVIEW.md)  
**Next:** [Chapter 6 Interview Questions](../chapter-06/INTERVIEW.md)
