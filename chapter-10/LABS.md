# Chapter 10 Labs: Advanced Topics

## Lab 10.1: Custom Resource Definition (CRD)

### Objective
Create and use custom resources.

### Exercise
```bash
# 1. Define CRD
cat <<EOF | kubectl apply -f -
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
              replicas:
                type: integer
  scope: Namespaced
  names:
    plural: databases
    singular: database
    kind: Database
    shortNames: ["db"]
EOF

# 2. Create custom resource
cat <<EOF | kubectl apply -f -
apiVersion: example.com/v1
kind: Database
metadata:
  name: mydb
spec:
  databaseType: postgres
  storageSize: 10Gi
  replicas: 3
EOF

# 3. List custom resources
kubectl get databases
kubectl get db

# 4. Delete
kubectl delete db mydb
kubectl delete crd databases.example.com
```

---

## Lab 10.2: Troubleshooting Scenario

### Common Issues

#### Pod Stuck in Pending
```bash
kubectl describe pod <name>
# Check Events for:
# - Insufficient cpu
# - Insufficient memory
# - No nodes match selector
# - Taints
```

#### CrashLoopBackOff
```bash
kubectl logs <pod> --previous
kubectl describe pod <pod>
# Check exit code
```

#### ImagePullBackOff
```bash
kubectl describe pod <pod>
# Check:
# - Wrong image name
# - No imagePullSecret for private registry
```

---

## Completion Checklist for Chapter 10

| Lab | Description | Status |
|-----|-------------|--------|
| 10.1 | Custom Resource Definition | [ ] |
| 10.2 | Troubleshooting scenarios | [ ] |
