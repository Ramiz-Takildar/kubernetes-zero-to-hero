# Chapter 10 Labs: Advanced Topics

## Lab 10.1: Custom Resource Definition

### Objective
Create and use custom resources.

### Production YAML
```yaml
# custom-resource.yaml
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
            required: ["databaseType", "storageSize"]
            properties:
              databaseType:
                type: string
                enum: ["postgres", "mysql", "mongodb"]
              storageSize:
                type: string
                pattern: "^[0-9]+(Gi|Mi)$"
              replicas:
                type: integer
                default: 1
                minimum: 1
                maximum: 5
              backupEnabled:
                type: boolean
                default: true
          status:
            type: object
            properties:
              phase:
                type: string
              readyReplicas:
                type: integer
  scope: Namespaced
  names:
    plural: databases
    singular: database
    kind: Database
    shortNames: ["db"]
---
apiVersion: example.com/v1
kind: Database
metadata:
  name: production-db
  namespace: production
  annotations:
    backup.schedule: "0 2 * * *"
    monitoring.enabled: "true"
spec:
  databaseType: postgres
  storageSize: 100Gi
  replicas: 3
  backupEnabled: true
```

---

## Lab 10.2: GitOps Deployment

### Objective
Implement GitOps workflow.

### Production YAML
```yaml
# gitops-config.yaml
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
  secretRef:
    name: github-token
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: production
  namespace: flux-system
spec:
  interval: 10m
  path: ./overlays/production
  prune: true
  sourceRef:
    kind: GitRepository
    name: production-apps
  targetNamespace: production
  validation: client
```

---

## Lab 10.3: Disaster Recovery

### Objective
Backup and restore cluster state.

### Production YAML
```yaml
# disaster-recovery.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cluster-backup
  namespace: kube-system
spec:
  schedule: "0 */6 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: etcd-backup
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
---
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: daily-backup
  namespace: velero
spec:
  schedule: "0 1 * * *"
  includedNamespaces:
  - production
  - staging
  storageLocation: aws-primary
  ttl: 720h0m0s
```

---

## Completion Checklist

| Lab | Description | Status |
|-----|-------------|--------|
| 10.1 | Custom Resource Definition | [ ] |
| 10.2 | GitOps Deployment | [ ] |
| 10.3 | Disaster Recovery | [ ] |
