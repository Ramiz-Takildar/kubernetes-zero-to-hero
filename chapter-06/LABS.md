# Chapter 6 Labs: Configuration

## Overview
Learn ConfigMaps, Secrets, Downward API.

---

## Lab 6.1: ConfigMap Usage

### Create ConfigMap

Create `app-config.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  database_url: postgres://db:5432/app
  log_level: info
```

### Use as Environment Variables

Create `config-env-pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: config-env
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'echo DB=$DATABASE_URL; sleep 3600']
    envFrom:
    - configMapRef:
        name: app-config
```

### Use as Files

Create `config-volume-pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: config-file
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'cat /config/app.json; sleep 3600']
    volumeMounts:
    - name: config
      mountPath: /config
  volumes:
  - name: config
    configMap:
      name: app-config
```

---

## Lab 6.2: Secret Management

### Create Secret

Create `db-secret.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
data:
  username: YWRtaW4=
  password: c2VjcmV0MTIz
```

### Use Secret as File

Create `secret-mount-pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-mount
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'cat /secrets/password; sleep 3600']
    volumeMounts:
    - name: secrets
      mountPath: /secrets
      readOnly: true
  volumes:
  - name: secrets
    secret:
      secretName: db-credentials
      defaultMode: 0400
```

---

## Lab 6.3: Downward API

### Expose Pod Metadata

Create `downward-api-pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: downward-demo
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'echo Pod: $POD_NAME; sleep 3600']
    env:
    - name: POD_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
    volumeMounts:
    - name: podinfo
      mountPath: /etc/podinfo
  volumes:
  - name: podinfo
    downwardAPI:
      items:
      - path: labels
        fieldRef:
          fieldPath: metadata.labels
```

---

## Completion Checklist

| Lab | Description | Status |
|-----|-------------|--------|
| 6.1 | ConfigMap Usage | [ ] |
| 6.2 | Secret Management | [ ] |
| 6.3 | Downward API | [ ] |
