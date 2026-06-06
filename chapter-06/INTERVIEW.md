# Chapter 6: Configuration - Interview Questions

> 15+ Interview Questions with Detailed Answers

---

## Basic Level Questions

### Q1: What is the difference between ConfigMap and Secret?

**Answer:**

| ConfigMap | Secret |
|-----------|--------|
| Non-sensitive data | Sensitive data |
| Plain text | Base64 encoded |
| Configuration files | Passwords, tokens, keys |
| Same consumption methods | Same consumption methods |

**Important:** Secrets are base64 encoded, NOT encrypted by default. Enable encryption at rest for production.

---

### Q2: How many ways can you consume a ConfigMap?

**Answer:**

**Three ways:**

1. **Environment variables (all):**
```yaml
envFrom:
- configMapRef:
    name: my-config
```

2. **Specific environment variable:**
```yaml
env:
- name: DATABASE_URL
  valueFrom:
    configMapKeyRef:
      name: my-config
      key: db-url
```

3. **Volume mount (as files):**
```yaml
volumeMounts:
- name: config
  mountPath: /etc/app
volumes:
- name: config
  configMap:
    name: my-config
```

---

### Q3: Is Secret data encrypted?

**Answer:**

**By default:** NO - only base64 encoded.

**Enable encryption at rest:**
```yaml
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

**Best practices:**
- Enable encryption at rest
- Use RBAC to limit secret access
- Rotate secrets regularly
- Use external secret management (Vault, AWS Secrets Manager)

---

### Q4: What is the Downward API?

**Answer:**

**Purpose:** Expose pod metadata to containers.

**Two methods:**

1. **Environment variables:**
```yaml
env:
- name: POD_NAME
  valueFrom:
    fieldRef:
      fieldPath: metadata.name
- name: POD_IP
  valueFrom:
    fieldRef:
      fieldPath: status.podIP
```

2. **Files via volume:**
```yaml
volumes:
- name: podinfo
  downwardAPI:
    items:
    - path: labels
      fieldRef:
        fieldPath: metadata.labels
```

**Available fields:**
- `metadata.name` - Pod name
- `metadata.namespace` - Namespace
- `status.podIP` - Pod IP
- `spec.nodeName` - Node name
- `limits.cpu` - CPU limit
- `limits.memory` - Memory limit

---

### Q5: What are immutable ConfigMaps and Secrets?

**Answer:**

**Feature:** Mark ConfigMap/Secret as immutable.

**Benefits:**
- Prevents accidental changes
- Improves performance (no watches needed)
- Better security

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-config
immutable: true
data:
  key: value
```

**Note:** Can't modify after creation. Must delete and recreate.

---

## Intermediate Level Questions

### Q6: Secret size limit?

**Answer:**

**Limit:** 1MiB (encoded size)

**Error if exceeded:**
```
 Secret "my-secret" is invalid: data: Too long: must have at most 1048576 bytes
```

**Workarounds for large secrets:**
- Split across multiple secrets
- Use volume mounts instead of env vars
- Store in external secret management

---

### Q7: Can you update a ConfigMap and have pods automatically reload?

**Answer:**

**Environment variables:** NO - set at container startup

**Volume mounts:** YES - files update automatically

**But:** Applications must watch and reload config files

**Solutions for hot reload:**
1. Use tools like Reloader/Stakater
2. Application watches file changes
3. Restart deployment (rolling update)

---

### Q8: What is subPath in volumeMounts?

**Answer:**

**Purpose:** Mount a single file instead of replacing entire directory.

**Without subPath:**
```yaml
volumeMounts:
- name: config
  mountPath: /etc/nginx/nginx.conf
```
Result: nginx.conf is directory, not file

**With subPath:**
```yaml
volumeMounts:
- name: config
  mountPath: /etc/nginx/nginx.conf
  subPath: nginx.conf
```
Result: nginx.conf is file, other files preserved

---

### Q9: What are the different Secret types?

**Answer:**

| Type | Use Case |
|------|----------|
| `Opaque` | Generic user-defined data |
| `kubernetes.io/tls` | TLS certificates |
| `kubernetes.io/dockerconfigjson` | Docker registry auth |
| `kubernetes.io/basic-auth` | Basic authentication |
| `kubernetes.io/ssh-auth` | SSH private keys |
| `bootstrap.kubernetes.io/token` | Bootstrap tokens |

---

### Q10: What is the projected volume type?

**Answer:**

**Purpose:** Combine multiple sources into single volume.

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

**Use case:** Mount secrets, configs, and metadata together.

---

## Advanced Level Questions

### Q11: Can environment variables reference each other inside a pod?

**Answer:**

**Yes, with caution:**
```yaml
env:
- name: FIRST
  value: "Hello"
- name: SECOND
  value: "$(FIRST) World"  # References FIRST
```

**Order matters:** Referenced variable must be defined first.

**Note:** Not recursive - can't reference looped variables.

---

### Q12: How do you use ConfigMap for command arguments?

**Answer:**

```yaml
containers:
- name: app
  image: myapp
  command: ["app"]
  args:
  - "--config"
  - "/config/app.conf"
  - "--log-level"
  - "$(LOG_LEVEL)"
  envFrom:
  - configMapRef:
      name: app-config
```

---

### Q13: Best practices for managing secrets in GitOps?

**Answer:**

**Problem:** Can't store secrets in Git (even encrypted).

**Solutions:**

1. **Sealed Secrets:** Encrypt secrets for Git
2. **External Secrets Operator:** Sync from AWS/GCP/Azure
3. **SOPS:** Encrypt with PGP/KMS
4. **Vault:** Dynamic secret injection

```yaml
# External Secret example
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
spec:
  secretStoreRef:
    name: aws-secrets-manager
  target:
    name: db-credentials
  data:
  - secretKey: password
    remoteRef:
      key: production/db
      property: password
```

---

### Q14: What happens if a referenced ConfigMap/Secret doesn't exist?

**Answer:**

**Pod creation:** FAILS - pod won't start

**Error:**
```
Error: configmaps "my-config" not found
```

**Solution:** Create ConfigMap first, then pod.

**Or use optional:**
```yaml
envFrom:
- configMapRef:
    name: my-config
    optional: true  # Won't fail if missing
```

---

### Q15: Can pods in different namespaces share ConfigMaps?

**Answer:**

**No:** ConfigMaps are namespace-scoped.

**Solutions:**
1. Create ConfigMap in each namespace
2. Use a shared namespace
3. Use external configuration service

**Note:** Create ConfigMap in same namespace as pod.

---

## Scenario-Based Questions

### S1: Application needs database password but shouldn't be in env vars.

**Answer:**

**Solution:** Mount as file
```yaml
volumeMounts:
- name: db-password
  mountPath: /secrets
  readOnly: true
volumes:
- name: db-password
  secret:
    secretName: db-secret
    items:
    - key: password
      path: password.txt
      mode: 0400
```

Application reads from `/secrets/password.txt`

---

### S2: Need to rotate database credentials without restarting pods.

**Answer:**

**Challenge:** Env vars don't update; mounted secrets do but apps don't re-read.

**Solutions:**
1. Use external secret management (Vault) with dynamic credentials
2. Sidecar that watches and signals app to reload
3. Rolling restart (kubectl rollout restart)

---

## Quick Reference

| Resource | Sensitive | Methods |
|----------|-----------|---------|
| ConfigMap | No | Env, Volume |
| Secret | Yes | Env, Volume |
| Downward API | No | Env, Volume |

---

## Key Takeaways

1. **ConfigMap:** Non-sensitive config
2. **Secret:** Sensitive data (encode, don't encrypt by default)
3. **Volume mount preferred:** For large configs/secrets
4. **Downward API:** Access pod metadata
5. **Immutable:** Prevent accidental changes
6. **Encryption at rest:** Enable for production secrets

---

**Previous:** [Chapter 5 Interview Questions](../chapter-05/INTERVIEW.md)  
**Next:** [Chapter 7 Interview Questions](../chapter-07/INTERVIEW.md)
