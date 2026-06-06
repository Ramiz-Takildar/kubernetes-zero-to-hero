# Chapter 6 Labs: Configuration

## Lab 6.1: ConfigMap Usage Patterns

### Objective
Use ConfigMaps in different ways.

### Exercise

**Create ConfigMap:**
```bash
# Method 1: From literal values
kubectl create configmap app-config \
  --from-literal=database=postgres \
  --from-literal=port=5432 \
  --from-literal=log_level=info

# Method 2: From file
cat > app.properties <<EOF
database.host=localhost
database.port=5432
cache.enabled=true
EOF
kubectl create configmap file-config --from-file=app.properties

# Method 3: From env file
cat > config.env <<EOF
API_KEY=mykey
API_URL=https://api.example.com
EOF
kubectl create configmap env-config --from-env-file=config.env

# View all configmaps
kubectl get configmaps
kubectl get configmap app-config -o yaml
```

**Consume ConfigMap:**
```bash
# Pattern 1: Environment variables
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: env-from-cm
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'echo DB=$DATABASE, PORT=$PORT; sleep 3600']
    envFrom:
    - configMapRef:
        name: app-config
EOF

kubectl logs env-from-cm
# Output: DB=postgres, PORT=5432

# Pattern 2: Specific keys as env vars
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: specific-env
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'echo Log=$LOG_LEVEL; sleep 3600']
    env:
    - name: LOG_LEVEL
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: log_level
EOF

kubectl logs specific-env

# Pattern 3: Mount as files
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: file-mount
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'cat /config/app.properties; ls /config/; sleep 3600']
    volumeMounts:
    - name: config-vol
      mountPath: /config
  volumes:
  - name: config-vol
    configMap:
      name: file-config
EOF

kubectl logs file-mount

# Clean up
kubectl delete pod env-from-cm specific-env file-mount
kubectl delete configmap app-config file-config env-config
rm app.properties config.env
```

---

## Lab 6.2: Secrets Management

### Objective
Create and consume secrets securely.

### Exercise
```bash
# 1. Create secret imperatively
kubectl create secret generic db-secret \
  --from-literal=username=admin \
  --from-literal=password='super-secret!123'

# 2. Create secret from file
echo -n 'my-api-key' > api-key.txt
kubectl create secret generic api-secret --from-file=api-key=api-key.txt
rm api-key.txt

# 3. Create TLS secret
# openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=myapp.local"
# kubectl create secret tls my-tls --cert=tls.crt --key=tls.key

# 4. View secret (values are base64 encoded)
kubectl get secret db-secret -o yaml

# Decode manually
echo 'YWRtaW4=' | base64 --decode  # admin

# 5. Use as environment variables
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: secret-env
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'echo User=$DB_USER, Pass=${DB_PASS:0:3}***; sleep 3600']
    env:
    - name: DB_USER
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: username
    - name: DB_PASS
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: password
EOF

kubectl logs secret-env

# 6. Mount as files
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: secret-file
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'ls -la /secrets/; cat /secrets/username; sleep 3600']
    volumeMounts:
    - name: secret-vol
      mountPath: /secrets
  volumes:
  - name: secret-vol
    secret:
      secretName: db-secret
      defaultMode: 0400
EOF

kubectl logs secret-file

# Verify file permissions (0400 = read-only)
kubectl exec secret-file -- ls -la /secrets/

# 7. Clean up
kubectl delete pod secret-env secret-file
kubectl delete secret db-secret api-secret
```

---

## Lab 6.3: Downward API

### Objective
Expose pod metadata to containers.

### Exercise
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: downward-api-demo
  labels:
    app: myapp
    version: v1
  annotations:
    build: "123"
    commit: "abc123"
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', '
      echo "=== Environment ===" &&
      env | grep -E "^(POD_|NODE_|NAMESPACE)" &&
      echo "" &&
      echo "=== Mounted Files ===" &&
      cat /podinfo/labels &&
      cat /podinfo/annotations &&
      sleep 3600
    ']
    env:
    - name: POD_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
    - name: POD_NAMESPACE
      valueFrom:
        fieldRef:
          fieldPath: metadata.namespace
    - name: POD_IP
      valueFrom:
        fieldRef:
          fieldPath: status.podIP
    - name: NODE_NAME
      valueFrom:
        fieldRef:
          fieldPath: spec.nodeName
    - name: CPU_LIMIT
      valueFrom:
        resourceFieldRef:
          containerName: app
          resource: limits.cpu
    - name: MEM_REQUEST
      valueFrom:
        resourceFieldRef:
          containerName: app
          resource: requests.memory
    volumeMounts:
    - name: podinfo
      mountPath: /podinfo
  volumes:
  - name: podinfo
    downwardAPI:
      items:
      - path: labels
        fieldRef:
          fieldPath: metadata.labels
      - path: annotations
        fieldRef:
          fieldPath: metadata.annotations
      - path: name
        fieldRef:
          fieldPath: metadata.name
EOF

kubectl logs downward-api-demo

# Clean up
kubectl delete pod downward-api-demo
```

---

## Lab 6.4: Projected Volumes

### Objective
Combine multiple sources into single volume.

### Exercise
```bash
# 1. Create prerequisite secrets and configmaps
kubectl create secret generic app-secret \
  --from-literal=token=abc123

kubectl create configmap app-config \
  --from-literal=config=value

# 2. Create service account (default exists)

# 3. Use projected volume
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: projected-demo
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'ls -la /projected/; cat /projected/*; sleep 3600']
    volumeMounts:
    - name: all-in-one
      mountPath: /projected
  volumes:
  - name: all-in-one
    projected:
      sources:
      - secret:
          name: app-secret
          items:
          - key: token
            path: app-token
      - configMap:
          name: app-config
          items:
          - key: config
            path: app-config
      - downwardAPI:
          items:
          - path: podname
            fieldRef:
              fieldPath: metadata.name
      - serviceAccountToken:
          path: token
          expirationSeconds: 3600
EOF
kubectl logs projected-demo

# Clean up
kubectl delete pod projected-demo
kubectl delete secret app-secret
kubectl delete configmap app-config
```

---

## Completion Checklist for Chapter 6

| Lab | Description | Status |
|-----|-------------|--------|
| 6.1 | ConfigMap usage patterns | [ ] |
| 6.2 | Secrets management | [ ] |
| 6.3 | Downward API | [ ] |
| 6.4 | Projected volumes | [ ] |
