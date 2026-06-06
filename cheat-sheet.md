# Kubernetes Cheat Sheet

## Quick Commands

```bash
# Pods
kubectl get pods
kubectl get pods -o wide
kubectl get pods --all-namespaces
kubectl get pods --show-labels
kubectl get pods -l app=nginx
kubectl get pods --field-selector=status.phase!=Running
kubectl describe pod <name>
kubectl logs <pod>
kubectl logs <pod> -f
kubectl logs <pod> --previous
kubectl logs <pod> -c <container>
kubectl exec -it <pod> -- /bin/sh
kubectl cp <pod>:/remote/file ./local
kubectl top pod

# Services
kubectl get svc
kubectl get endpoints <svc>
kubectl describe svc <name>
kubectl expose deployment <name> --port=80

# Deployments
kubectl get deploy
kubectl get deploy -o yaml
kubectl create deploy <name> --image=nginx --replicas=3
kubectl scale deploy <name> --replicas=5
kubectl set image deploy/<name> container=image:tag
kubectl rollout status deploy/<name>
kubectl rollout history deploy/<name>
kubectl rollout undo deploy/<name>
kubectl rollout undo deploy/<name> --to-revision=2
kubectl rollout pause deploy/<name>
kubectl rollout resume deploy/<name>
kubectl rollout restart deploy/<name>

# ConfigMaps & Secrets
kubectl get cm
kubectl get secret
kubectl create cm <name> --from-file=config.txt
kubectl create secret generic <name> --from-literal=key=value
kubectl create secret tls <name> --cert=cert.pem --key=key.pem

# Storage
kubectl get pvc
kubectl get pv
kubectl get sc

# Namespaces
kubectl get ns
kubectl create ns <name>
kubectl config set-context --current --namespace=<name>

# Nodes
kubectl get nodes
kubectl get nodes -o wide
kubectl describe node <name>
kubectl top node
kubectl cordon <node>
kubectl uncordon <node>
kubectl drain <node> --ignore-daemonsets

# Apply
kubectl apply -f file.yaml
kubectl apply -f dir/
kubectl apply -k kustomization/
kubectl delete -f file.yaml
kubectl diff -f file.yaml

# Debugging
kubectl get events --sort-by=.metadata.creationTimestamp
kubectl get events --field-selector type!=Normal
kubectl cluster-info
kubectl cluster-info dump
kubectl api-resources
kubectl api-versions
kubectl explain pod.spec
kubectl version
```

## YAML Templates

### Basic Pod
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-name
spec:
  containers:
  - name: container-name
    image: nginx:alpine
    ports:
    - containerPort: 80
```

### Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deployment-name
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: app
        image: nginx:alpine
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
```

### Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: service-name
spec:
  type: ClusterIP
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 80
```

### Ingress
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-name
spec:
  rules:
  - host: example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: service-name
            port:
              number: 80
```

### ConfigMap
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: config-name
data:
  key: value
  file.txt: |
    multi
    line
    content
```

### Secret
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: secret-name
type: Opaque
data:
  # base64 encoded
  username: YWRtaW4=
  password: cGFzc3dvcmQ=
```

### PVC
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-name
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

### RBAC
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: role-name
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: binding-name
subjects:
- kind: ServiceAccount
  name: sa-name
roleRef:
  kind: Role
  name: role-name
  apiGroup: rbac.authorization.k8s.io
```

## Resource Shortcuts

| Short | Full |
|-------|------|
| po | pods |
| svc | services |
| deploy | deployments |
| rs | replicasets |
| sts | statefulsets |
| ds | daemonsets |
| job | jobs |
| cj | cronjobs |
| ns | namespaces |
| cm | configmaps |
| secret | secrets |
| pvc | persistentvolumeclaims |
| pv | persistentvolumes |
| ing | ingresses |
| sa | serviceaccounts |
| rb | rolebindings |
| crb | clusterrolebindings |
