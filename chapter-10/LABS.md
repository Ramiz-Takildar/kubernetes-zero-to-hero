# Chapter 10 Labs: Advanced Topics

## Overview
CRDs, GitOps, disaster recovery.

---

## Lab 10.1: Custom Resource Definition

### Create CRD

Create `database-crd.yaml`:

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
              databaseType:
                type: string
              storageSize:
                type: string
  scope: Namespaced
  names:
    plural: databases
    kind: Database
```

### Create Custom Resource

Create `my-database.yaml`:

```yaml
apiVersion: example.com/v1
kind: Database
metadata:
  name: production-db
spec:
  databaseType: postgres
  storageSize: 100Gi
```

---

## Lab 10.2: GitOps Configuration

### Example Flux Configuration

Create `flux-source.yaml`:

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: production-apps
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/company/production-apps
  ref:
    branch: main
```

---

## Lab 10.3: Disaster Recovery

### etcd Backup

Create `etcd-backup-cronjob.yaml`:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: etcd-backup
  namespace: kube-system
spec:
  schedule: "0 */6 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          hostNetwork: true
          containers:
          - name: backup
            image: bitnami/etcd:3.5
            command:
            - etcdctl
            - snapshot
            - save
            - /backup/etcd-$(date +%Y%m%d-%H%M%S).db
            volumeMounts:
            - name: backup
              mountPath: /backup
          volumes:
          - name: backup
            persistentVolumeClaim:
              claimName: backup-pvc
          restartPolicy: OnFailure
```

---

## Completion Checklist

| Lab | Description | Status |
|-----|-------------|--------|
| 10.1 | CRD | [ ] |
| 10.2 | GitOps | [ ] |
| 10.3 | Disaster Recovery | [ ] |
