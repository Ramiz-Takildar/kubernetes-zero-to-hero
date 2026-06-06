# Chapter 6: Configuration

## 📚 Learning Objectives

By the end of this chapter, you will:
- Master ConfigMaps for non-sensitive configuration
- Securely manage Secrets
- Use the Downward API for pod metadata
- Implement configuration hot-reloading
- Follow configuration best practices

**Estimated Time:** 2 days  
**Labs:** 4 hands-on exercises

---

## 🔧 ConfigMaps

### Purpose

Store non-sensitive configuration data in key-value pairs or files.

### Example Use Cases

```
ConfigMap uses:
├── Environment Variables
│   └── DATABASE_URL=postgres://db:5432/app
├── Configuration Files
│   └── nginx.conf
│   └── application.properties
└── Command-line Arguments
    └── --log-level=debug
```

### Consumption Methods

#### Method 1: Environment Variables (all keys)

```yaml
envFrom:
- configMapRef:
    name: app-config
```

All ConfigMap keys become environment variables.

#### Method 2: Specific Environment Variables

```yaml
env:
- name: DATABASE_URL
  valueFrom:
    configMapKeyRef:
      name: app-config
      key: database-url
```

#### Method 3: Volume Mount (as files)

```yaml
volumeMounts:
- name: config
  mountPath: /etc/app

volumes:
- name: config
  configMap:
    name: app-config
```

ConfigMap keys become filenames, values become file contents.

---

## 🔒 Secrets

### Purpose

Store sensitive data (passwords, tokens, keys).

### Base64 Encoding (Not Encryption!)

Data is base64 encoded at rest by default. **Not encrypted!**

```bash
# Encode
echo -n 'password' | base64  # cGFzc3dvcmQ=

# Decode
echo 'cGFzc3dvcmQ=' | base64 --decode  # password
```

### Encryption at Rest

For real security, enable encryption at rest:
```yaml
# EncryptionConfiguration
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: key1
        secret: <base64-encoded-key>
```

### Secret Types

| Type | Use Case |
|------|----------|
| `Opaque` | Generic user-defined data |
| `kubernetes.io/tls` | TLS certificates |
| `kubernetes.io/dockerconfigjson` | Registry auth |
| `kubernetes.io/basic-auth` | Basic authentication |
| `kubernetes.io/ssh-auth` | SSH private keys |

---

## 🔽 Downward API

Expose pod/node metadata to the container.

### Two Methods

#### 1. Environment Variables

```yaml
env:
- name: POD_NAME
  valueFrom:
    fieldRef:
      fieldPath: metadata.name
- name: NODE_NAME
  valueFrom:
    fieldRef:
      fieldPath: spec.nodeName
- name: CPU_LIMIT
  valueFrom:
    resourceFieldRef:
      containerName: app
      resource: limits.cpu
```

**Available Fields:**
- `metadata.name` - Pod name
- `metadata.namespace` - Namespace
- `metadata.labels` - All labels
- `metadata.annotations` - All annotations
- `spec.nodeName` - Node name
- `status.podIP` - Pod IP
- `limits.cpu` - CPU limit
- `limits.memory` - Memory limit
- `requests.cpu` - CPU request
- `requests.memory` - Memory request

#### 2. Volume Files

```yaml
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
```

---

## 📊 Theory to Labs

### Lab 6.1: ConfigMaps
**Theory Applied:**
- Creating ConfigMaps
- Multiple consumption methods
- Configuration management

### Lab 6.2: Secrets
**Theory Applied:**
- Creating Secrets
- Mounting as files vs env vars
- Security best practices

### Lab 6.3: Downward API
**Theory Applied:**
- Pod metadata access
- Resource information
- Use cases for dynamic configuration

---

## 📖 Key Takeaways

1. **ConfigMap:** Non-sensitive data
2. **Secret:** Sensitive data (base64 encoded)
3. **Enable Encryption:** For production secrets
4. **Mount as files:** For complex configs
5. **Downward API:** Access pod metadata
6. **Immutable:** Make configs immutable for security
7. **SubPath:** Mount single files without replacing directory

---

## ❓ Interview Questions

### Q: ConfigMap vs Secret?

**Answer:**

| ConfigMap | Secret |
|-----------|--------|
| Non-sensitive | Sensitive |
| Plain text | Base64 encoded |
| Config files, env vars | Passwords, tokens, keys |
| Same consumption | Same consumption |
| No encryption by default | Should enable encryption |

---

## 🔗 Next Steps

1. Review theory above
2. Complete [Lab 6.1](./LABS.md) - ConfigMaps
3. Complete [Lab 6.2](./LABS.md) - Secrets
4. Complete [Lab 6.3](./LABS.md) - Downward API

**Next Chapter:** [Chapter 7: Observability](../chapter-07/)
