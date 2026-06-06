# Chapter 2 Labs: Pods & Containers

## Lab 2.1: Production Multi-Container Pod

### Objective
Deploy a production-grade web application with logging sidecar.

### Production YAML
```yaml
# production-web-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: production-web
  labels:
    app: web
    tier: frontend
    version: v1.0.0
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "9113"
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 101
    runAsGroup: 101
    fsGroup: 101
    seccompProfile:
      type: RuntimeDefault
  
  containers:
  # Main Application Container
  - name: nginx
    image: nginx:1.25-alpine
    ports:
    - name: http
      containerPort: 8080
      protocol: TCP
    
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
      limits:
        memory: "256Mi"
        cpu: "500m"
    
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
    
    volumeMounts:
    - name: tmp
      mountPath: /tmp
    - name: cache
      mountPath: /var/cache/nginx
    - name: run
      mountPath: /var/run
    - name: nginx-config
      mountPath: /etc/nginx/nginx.conf
      subPath: nginx.conf
      readOnly: true
    - name: shared-logs
      mountPath: /var/log/nginx
    
    livenessProbe:
      httpGet:
        path: /healthz
        port: http
      initialDelaySeconds: 10
      periodSeconds: 10
      timeoutSeconds: 5
      failureThreshold: 3
    
    readinessProbe:
      httpGet:
        path: /ready
        port: http
      initialDelaySeconds: 5
      periodSeconds: 5
      timeoutSeconds: 3
      failureThreshold: 2
    
    startupProbe:
      httpGet:
        path: /healthz
        port: http
      initialDelaySeconds: 5
      periodSeconds: 5
      timeoutSeconds: 3
      failureThreshold: 30
  
  # Log Shipper Sidecar
  - name: log-shipper
    image: fluent/fluent-bit:2.2
    args:
    - -c
    - /fluent-bit/etc/fluent-bit.conf
    resources:
      requests:
        memory: "64Mi"
        cpu: "50m"
      limits:
        memory: "128Mi"
        cpu: "100m"
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log/nginx
      readOnly: true
    - name: fluent-bit-config
      mountPath: /fluent-bit/etc
      readOnly: true
  
  # Metrics Exporter Sidecar
  - name: nginx-exporter
    image: nginx/nginx-prometheus-exporter:1.0
    args:
    - -nginx.scrape-uri=http://localhost:8080/stub_status
    ports:
    - name: metrics
      containerPort: 9113
    resources:
      requests:
        memory: "32Mi"
        cpu: "25m"
      limits:
        memory: "64Mi"
        cpu: "50m"
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
  
  volumes:
  - name: tmp
    emptyDir: {}
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
  - name: shared-logs
    emptyDir: {}
  - name: nginx-config
    configMap:
      name: nginx-config
  - name: fluent-bit-config
    configMap:
      name: fluent-bit-config
  
  restartPolicy: Always
  terminationGracePeriodSeconds: 60
  dnsPolicy: ClusterFirst
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
data:
  nginx.conf: |
    user nginx;
    worker_processes auto;
    error_log /var/log/nginx/error.log warn;
    pid /var/run/nginx.pid;
    
    events {
        worker_connections 1024;
    }
    
    http {
        include /etc/nginx/mime.types;
        default_type application/octet-stream;
        
        log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                        '$status $body_bytes_sent "$http_referer" '
                        '"$http_user_agent" "$http_x_forwarded_for"';
        
        access_log /var/log/nginx/access.log main;
        
        server {
            listen 8080;
            server_name localhost;
            
            location / {
                root /usr/share/nginx/html;
                index index.html;
            }
            
            location /healthz {
                access_log off;
                return 200 "healthy\n";
                add_header Content-Type text/plain;
            }
            
            location /ready {
                access_log off;
                return 200 "ready\n";
                add_header Content-Type text/plain;
            }
            
            location /stub_status {
                stub_status;
                allow 127.0.0.1;
                deny all;
            }
        }
    }
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
data:
  fluent-bit.conf: |
    [INPUT]
        Name tail
        Path /var/log/nginx/access.log
        Tag nginx.access
        Parser nginx
    
    [INPUT]
        Name tail
        Path /var/log/nginx/error.log
        Tag nginx.error
        Parser nginx
    
    [OUTPUT]
        Name stdout
        Match *
        Format json_lines
```

### Verification
```bash
kubectl apply -f production-web-pod.yaml

# Check all 3 containers running
kubectl get pod production-web

# Check container logs individually
kubectl logs production-web -c nginx
kubectl logs production-web -c log-shipper
kubectl logs production-web -c nginx-exporter

# Check metrics endpoint
kubectl port-forward pod/production-web 9113:9113 &
curl http://localhost:9113/metrics
kill %1

# Cleanup
kubectl delete -f production-web-pod.yaml
```

---

## Lab 2.2: Database Migration with Init Containers

### Objective
Deploy database with schema migration using init containers.

### Production YAML
```yaml
# database-with-migration.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  labels:
    app: postgres
    version: "15"
spec:
  serviceName: postgres-headless
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 999
        runAsGroup: 999
        fsGroup: 999
      
      initContainers:
      # Init Container 1: Wait for storage
      - name: storage-init
        image: busybox:1.36
        command:
        - sh
        - -c
        - |
          echo "Checking data directory..."
          if [ ! -d /var/lib/postgresql/data ]; then
            echo "Creating data directory"
            mkdir -p /var/lib/postgresql/data
            chown 999:999 /var/lib/postgresql/data
          fi
          ls -la /var/lib/postgresql/
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql
        securityContext:
          runAsUser: 0
        resources:
          requests:
            memory: "32Mi"
            cpu: "50m"
      
      # Init Container 2: Run migrations
      - name: db-migrations
        image: postgres:15-alpine
        env:
        - name: PGHOST
          value: localhost
        - name: PGUSER
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: username
        - name: PGPASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        - name: PGDATABASE
          value: appdb
        command:
        - sh
        - -c
        - |
          echo "Running database migrations..."
          # Wait for postgres to be ready
          until pg_isready -q; do
            echo "Waiting for postgres..."
            sleep 2
          done
          
          echo "Creating schema if not exists..."
          psql -c "CREATE SCHEMA IF NOT EXISTS migrations;"
          
          echo "Migration complete"
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
      
      containers:
      - name: postgres
        image: postgres:15-alpine
        env:
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        - name: POSTGRES_DB
          value: appdb
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        ports:
        - name: postgres
          containerPort: 5432
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - postgres
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - postgres
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
        - name: postgres-config
          mountPath: /etc/postgresql/postgresql.conf
          subPath: postgresql.conf
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: false
      
      volumes:
      - name: postgres-config
        configMap:
          name: postgres-config
  
  volumeClaimTemplates:
  - metadata:
      name: postgres-data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: standard
      resources:
        requests:
          storage: 10Gi
---
apiVersion: v1
kind: Service
metadata:
  name: postgres-headless
spec:
  clusterIP: None
  selector:
    app: postgres
  ports:
  - port: 5432
    name: postgres
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-config
data:
  postgresql.conf: |
    listen_addresses = '*'
    max_connections = 100
    shared_buffers = 256MB
    effective_cache_size = 768MB
    maintenance_work_mem = 64MB
    checkpoint_completion_target = 0.9
    wal_buffers = 7864kB
    default_statistics_target = 100
    random_page_cost = 1.1
    effective_io_concurrency = 200
    work_mem = 1310kB
    min_wal_size = 1GB
    max_wal_size = 4GB
---
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
type: Opaque
data:
  username: cG9zdGdyZXM=  # postgres
  password: c2VjcmV0MTIz  # secret123
```

---

## Lab 2.3: Resource Management Lab

### Objective
Understand resource constraints with production workloads.

### Production YAML
```yaml
# resource-management-lab.yaml
# Guaranteed QoS Pod
apiVersion: v1
kind: Pod
metadata:
  name: guaranteed-pod
  labels:
    qos: guaranteed
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
      limits:
        memory: "128Mi"
        cpu: "100m"
    livenessProbe:
      httpGet:
        path: /
        port: 80
---
# Burstable QoS Pod
apiVersion: v1
kind: Pod
metadata:
  name: burstable-pod
  labels:
    qos: burstable
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    resources:
      requests:
        memory: "64Mi"
        cpu: "50m"
      limits:
        memory: "128Mi"
        cpu: "100m"
---
# BestEffort QoS Pod
apiVersion: v1
kind: Pod
metadata:
  name: besteffort-pod
  labels:
    qos: besteffort
spec:
  containers:
  - name: nginx
    image: nginx:alpine
---
```

### Verification
```bash
kubectl apply -f resource-management-lab.yaml

# Check assigned QoS
kubectl get pod guaranteed-pod -o jsonpath='{.status.qosClass}'
kubectl get pod burstable-pod -o jsonpath='{.status.qosClass}'
kubectl get pod besteffort-pod -o jsonpath='{.status.qosClass}'

# Describe to see resource allocation
kubectl describe pod guaranteed-pod | grep -A2 "QoS"
```

---

## Completion Checklist

| Lab | Description | Status |
|-----|-------------|--------|
| 2.1 | Production Multi-Container Pod | [ ] |
| 2.2 | Database Migration with Init | [ ] |
| 2.3 | Resource Management | [ ] |
