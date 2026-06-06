# Chapter 6 Labs: Configuration

## Lab 6.1: Production ConfigMap Management

### Objective
Manage application configuration with hot-reloading.

### Production YAML
```yaml
# production-configmaps.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: production
  annotations:
    configmap.reloader.stakater.com/auto: "true"
data:
  # Application settings
  application.properties: |
    server.port=8080
    server.tomcat.max-threads=200
    server.tomcat.min-spare-threads=10
    spring.datasource.hikari.maximum-pool-size=20
    spring.datasource.hikari.minimum-idle=5
    spring.datasource.hikari.idle-timeout=300000
    spring.datasource.hikari.max-lifetime=1200000
    spring.datasource.hikari.connection-timeout=20000
    logging.level.root=INFO
    logging.level.com.company=DEBUG
    
  # Feature flags
  features.json: |
    {
      "newUI": false,
      "betaFeature": false,
      "maintenanceMode": false,
      "rateLimiting": true
    }
    
  # Logback configuration
  logback.xml: |
    <?xml version="1.0" encoding="UTF-8"?>
    <configuration>
      <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
        <encoder>
          <pattern>%d{yyyy-MM-dd HH:mm:ss} [%thread] %-5level %logger{36} - %msg%n</pattern>
        </encoder>
      </appender>
      <root level="INFO">
        <appender-ref ref="CONSOLE" />
      </root>
    </configuration>
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: production
data:
  nginx.conf: |
    user nginx;
    worker_processes auto;
    error_log /var/log/nginx/error.log warn;
    pid /var/run/nginx.pid;
    
    events {
        worker_connections 4096;
        use epoll;
        multi_accept on;
    }
    
    http {
        include /etc/nginx/mime.types;
        default_type application/octet-stream;
        
        log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                        '$status $body_bytes_sent "$http_referer" '
                        '"$http_user_agent" "$http_x_forwarded_for" '
                        '$request_time $upstream_response_time';
        
        access_log /var/log/nginx/access.log main;
        
        sendfile on;
        tcp_nopush on;
        tcp_nodelay on;
        keepalive_timeout 65;
        types_hash_max_size 2048;
        
        # Gzip compression
        gzip on;
        gzip_vary on;
        gzip_min_length 1024;
        gzip_types text/plain text/css text/xml text/javascript application/json;
        
        # Rate limiting
        limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
        
        server {
            listen 80;
            server_name _;
            
            location / {
                limit_req zone=api burst=20 nodelay;
                proxy_pass http://backend;
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
            }
        }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: config-consumer
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: consumer
  template:
    metadata:
      labels:
        app: consumer
    spec:
      containers:
      - name: app
        image: nginx:alpine
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
        - name: app-config
          mountPath: /config
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
      volumes:
      - name: config
        configMap:
          name: nginx-config
      - name: app-config
        configMap:
          name: app-config
```

---

## Lab 6.2: Secret Management with Encryption

### Objective
Secure secret management with rotation.

### Production YAML
```yaml
# production-secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: database-credentials
  namespace: production
  annotations:
    secret.reloader.stakater.com/auto: "true"
type: Opaque
stringData:
  host: postgres.production.svc.cluster.local
  port: "5432"
  database: appdb
  username: appuser
  password: "ChangeMe123!@#"
  url: "postgresql://appuser:ChangeMe123!@#@postgres.production.svc.cluster.local:5432/appdb"
---
apiVersion: v1
kind: Secret
metadata:
  name: api-keys
  namespace: production
type: Opaque
stringData:
  external-api-key: "sk_live_1234567890abcdef"
  internal-api-key: "sk_internal_0987654321fedcba"
---
apiVersion: v1
kind: Secret
metadata:
  name: tls-certificate
  namespace: production
type: kubernetes.io/tls
data:
  tls.crt: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUM=
  tls.key: LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0tCk1JSUV2ZndCQW9=
---
apiVersion: v1
kind: Secret
metadata:
  name: registry-credentials
  namespace: production
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: eyJhdXRocyI6eyJyZWdpc3RyeS5leGFtcGxlLmNvbSI6eyJ1c2VybmFtZSI6InVzZXIiLCJwYXNzd29yZCI6InBhc3MiLCJhdXRoIjoiZFhObGNqcHdZWE56Y2pwMWMyVnlPblZ6WlhJNmMyVmpjbVYwTVRJI319
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secret-consumer
  namespace: production
spec:
  replicas: 2
  selector:
    matchLabels:
      app: secret-app
  template:
    metadata:
      labels:
        app: secret-app
    spec:
      imagePullSecrets:
      - name: registry-credentials
      containers:
      - name: app
        image: private-registry.example.com/app:latest
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: database-credentials
              key: url
        - name: API_KEY
          valueFrom:
            secretKeyRef:
              name: api-keys
              key: external-api-key
        volumeMounts:
        - name: tls
          mountPath: /etc/tls
          readOnly: true
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
      volumes:
      - name: tls
        secret:
          secretName: tls-certificate
          defaultMode: 0400
```

---

## Lab 6.3: Downward API for Pod Metadata

### Objective
Expose pod information to applications.

### Production YAML
```yaml
# downward-api-usage.yaml
apiVersion: v1
kind: Pod
metadata:
  name: metadata-aware-app
  labels:
    app: web
    version: v1.0.0
    tier: frontend
  annotations:
    build.id: "12345"
    commit.sha: "abc123def456"
    deploy.time: "2024-01-01T00:00:00Z"
spec:
  serviceAccountName: app-sa
  containers:
  - name: app
    image: busybox
    command:
    - sh
    - -c
    - |
      echo "=== Pod Identity ==="
      echo "Name: $POD_NAME"
      echo "Namespace: $POD_NAMESPACE"
      echo "Node: $NODE_NAME"
      echo "Pod IP: $POD_IP"
      echo "Service Account: $POD_SERVICE_ACCOUNT"
      echo ""
      echo "=== Resource Limits ==="
      echo "CPU Limit: $CPU_LIMIT"
      echo "Memory Limit: $MEMORY_LIMIT"
      echo "CPU Request: $CPU_REQUEST"
      echo "Memory Request: $MEMORY_REQUEST"
      echo ""
      echo "=== Mounted Files ==="
      cat /etc/podinfo/labels
      cat /etc/podinfo/annotations
      echo ""
      echo "=== Owner Reference ==="
      cat /etc/podinfo/owner
      sleep 3600
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
    - name: POD_SERVICE_ACCOUNT
      valueFrom:
        fieldRef:
          fieldPath: spec.serviceAccountName
    - name: CPU_LIMIT
      valueFrom:
        resourceFieldRef:
          containerName: app
          resource: limits.cpu
    - name: MEMORY_LIMIT
      valueFrom:
        resourceFieldRef:
          containerName: app
          resource: limits.memory
    - name: CPU_REQUEST
      valueFrom:
        resourceFieldRef:
          containerName: app
          resource: requests.cpu
    - name: MEMORY_REQUEST
      valueFrom:
        resourceFieldRef:
          containerName: app
          resource: requests.memory
    resources:
      requests:
        memory: "64Mi"
        cpu: "50m"
      limits:
        memory: "128Mi"
        cpu: "100m"
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
      - path: annotations
        fieldRef:
          fieldPath: metadata.annotations
      - path: name
        fieldRef:
          fieldPath: metadata.name
      - path: namespace
        fieldRef:
          fieldPath: metadata.namespace
      - path: owner
        fieldRef:
          fieldPath: metadata.ownerReferences
```

---

## Completion Checklist

| Lab | Description | Status |
|-----|-------------|--------|
| 6.1 | Production ConfigMaps | [ ] |
| 6.2 | Secret Management | [ ] |
| 6.3 | Downward API | [ ] |
