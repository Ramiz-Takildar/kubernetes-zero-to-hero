# Chapter 3 Labs: Workloads & Controllers

## Lab 3.1: Production Deployment with Rolling Update

### Objective
Deploy a production-grade application with proper update strategy.

### Production YAML
```yaml
# production-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-service
  namespace: production
  labels:
    app: api
    tier: backend
    version: v1.0.0
  annotations:
    deployment.kubernetes.io/revision: "1"
spec:
  replicas: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: api
      tier: backend
  template:
    metadata:
      labels:
        app: api
        tier: backend
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      serviceAccountName: api-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - api
              topologyKey: kubernetes.io/hostname
      
      terminationGracePeriodSeconds: 60
      
      containers:
      - name: api
        image: nginx:1.25-alpine
        imagePullPolicy: IfNotPresent
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
        - name: config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
          readOnly: true
        
        startupProbe:
          httpGet:
            path: /healthz
            port: http
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 12
        
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
          failureThreshold: 3
          successThreshold: 1
        
        lifecycle:
          preStop:
            exec:
              command:
              - /bin/sh
              - -c
              - "nginx -s quit; sleep 30"
      
      volumes:
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir: {}
      - name: run
        emptyDir: {}
      - name: config
        configMap:
          name: api-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-config
  namespace: production
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
        }
    }
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: api-sa
  namespace: production
automountServiceAccountToken: false
---
apiVersion: v1
kind: Service
metadata:
  name: api-service
  namespace: production
  labels:
    app: api
    tier: backend
spec:
  type: ClusterIP
  selector:
    app: api
    tier: backend
  ports:
  - name: http
    port: 80
    targetPort: 8080
    protocol: TCP
  sessionAffinity: None
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: api-pdb
  namespace: production
spec:
  minAvailable: 3
  selector:
    matchLabels:
      app: api
      tier: backend
```

### Verification
```bash
# Apply deployment
kubectl apply -f production-deployment.yaml

# Check rolling update in progress
kubectl rollout status deployment/api-service -n production

# Current revision
kubectl rollout history deployment/api-service -n production

# Pods distribution across nodes
kubectl get pods -n production -o wide -l app=api

# PDB status
kubectl get pdb -n production

# Update to new version
kubectl set image deployment/api-service api=nginx:1.26-alpine -n production

# Watch rollout
kubectl get pods -n production -w

# Rollback if needed
kubectl rollout undo deployment/api-service -n production
```

---

## Lab 3.2: Blue-Green Deployment

### Objective
Implement zero-downtime blue-green deployment strategy.

### Production YAML
```yaml
# blue-green-deployment.yaml
# Blue (Current) Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-blue
  labels:
    app: web
    version: blue
    track: stable
spec:
  replicas: 4
  selector:
    matchLabels:
      app: web
      version: blue
  template:
    metadata:
      labels:
        app: web
        version: blue
    spec:
      containers:
      - name: app
        image: nginx:1.24-alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
---
# Green (New) Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-green
  labels:
    app: web
    version: green
    track: canary
spec:
  replicas: 4
  selector:
    matchLabels:
      app: web
      version: green
  template:
    metadata:
      labels:
        app: web
        version: green
    spec:
      containers:
      - name: app
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
---
# Preview Service (for testing green)
apiVersion: v1
kind: Service
metadata:
  name: app-preview
spec:
  selector:
    app: web
    version: green
  ports:
  - port: 80
    targetPort: 80
---
# Production Service (switches between blue/green)
apiVersion: v1
kind: Service
metadata:
  name: app-production
spec:
  selector:
    app: web
    version: blue  # Switch to green when ready
  ports:
  - port: 80
    targetPort: 80
```

### Switch Traffic to Green
```bash
# Apply both deployments
kubectl apply -f blue-green-deployment.yaml

# Test blue (production)
kubectl run test --rm -i --restart=Never --image=busybox -- wget -qO- http://app-production

# Test green (preview)
kubectl run test --rm -i --restart=Never --image=busybox -- wget -qO- http://app-preview

# Switch production to green
kubectl patch service app-production -p '{"spec":{"selector":{"version":"green"}}}'

# Verify traffic switch
kubectl run test --rm -i --restart=Never --image=busybox -- wget -qO- http://app-production

# Rollback to blue if needed
kubectl patch service app-production -p '{"spec":{"selector":{"version":"blue"}}}'
```

---

## Lab 3.3: Stateful Application with StatefulSet

### Objective
Deploy a production Redis cluster using StatefulSet.

### Production YAML
```yaml
# redis-statefulset.yaml
apiVersion: v1
kind: Service
metadata:
  name: redis-headless
  labels:
    app: redis
spec:
  ports:
  - port: 6379
    name: redis
  clusterIP: None
  selector:
    app: redis
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
  labels:
    app: redis
spec:
  serviceName: redis-headless
  replicas: 3
  podManagementPolicy: OrderedReady
  updateStrategy:
    type: RollingUpdate
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      terminationGracePeriodSeconds: 30
      containers:
      - name: redis
        image: redis:7-alpine
        command:
        - redis-server
        - /etc/redis/redis.conf
        ports:
        - containerPort: 6379
          name: redis
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
        readinessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
        volumeMounts:
        - name: data
          mountPath: /data
        - name: config
          mountPath: /etc/redis
      volumes:
      - name: config
        configMap:
          name: redis-config
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: standard
      resources:
        requests:
          storage: 1Gi
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-config
data:
  redis.conf: |
    port 6379
    dir /data
    appendonly yes
    appendfsync everysec
    save 900 1
    save 300 10
    save 60 10000
    maxmemory 256mb
    maxmemory-policy allkeys-lru
```

### Verification
```bash
kubectl apply -f redis-statefulset.yaml

# Check ordered pod creation
kubectl get pods -l app=redis -w
# redis-0, then redis-1, then redis-2

# Check PVCs created
kubectl get pvc

# Each pod gets its own PVC
kubectl get pvc -l app=redis

# Test Redis
kubectl exec redis-0 -- redis-cli ping
kubectl exec redis-1 -- redis-cli ping

# Write data to redis-0
kubectl exec redis-0 -- redis-cli set testkey "hello"

# Read from redis-1
kubectl exec redis-1 -- redis-cli get testkey
```

---

## Lab 3.4: CronJob for Database Backup

### Objective
Schedule automated database backups.

### Production YAML
```yaml
# database-backup-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: database-backup
  namespace: production
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  timeZone: "America/New_York"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  startingDeadlineSeconds: 3600
  jobTemplate:
    spec:
      activeDeadlineSeconds: 3600
      backoffLimit: 3
      ttlSecondsAfterFinished: 86400
      template:
        metadata:
          labels:
            app: database-backup
        spec:
          restartPolicy: OnFailure
          containers:
          - name: backup
            image: postgres:15-alpine
            env:
            - name: PGHOST
              value: postgres.production.svc.cluster.local
            - name: PGDATABASE
              value: appdb
            - name: PGUSER
              valueFrom:
                secretKeyRef:
                  name: postgres-credentials
                  key: username
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgres-credentials
                  key: password
            command:
            - /bin/sh
            - -c
            - |
              TIMESTAMP=$(date +%Y%m%d_%H%M%S)
              BACKUP_FILE="/backup/${PGDATABASE}_${TIMESTAMP}.sql.gz"
              
              echo "Starting backup at $(date)"
              echo "Backing up database: ${PGDATABASE}"
              
              pg_dump --verbose --format=plain \
                | gzip > "${BACKUP_FILE}"
              
              if [ $? -eq 0 ]; then
                echo "Backup successful: ${BACKUP_FILE}"
                ls -lh "${BACKUP_FILE}"
                
                # Keep only last 7 backups
                cd /backup && ls -t *.sql.gz | tail -n +8 | xargs -r rm -v
                
                # Upload to S3 (if configured)
                if [ -n "$S3_BUCKET" ]; then
                  echo "Uploading to S3..."
                  aws s3 cp "${BACKUP_FILE}" "s3://${S3_BUCKET}/backups/"
                fi
              else
                echo "Backup failed!"
                exit 1
              fi
            volumeMounts:
            - name: backup
              mountPath: /backup
            resources:
              requests:
                memory: "256Mi"
                cpu: "200m"
              limits:
                memory: "512Mi"
                cpu: "500m"
            securityContext:
              runAsNonRoot: true
              runAsUser: 999
              allowPrivilegeEscalation: false
              readOnlyRootFilesystem: false
          volumes:
          - name: backup
            persistentVolumeClaim:
              claimName: backup-pvc
```

---

## Completion Checklist

| Lab | Description | Status |
|-----|-------------|--------|
| 3.1 | Production Deployment | [ ] |
| 3.2 | Blue-Green Deployment | [ ] |
| 3.3 | StatefulSet Redis | [ ] |
| 3.4 | Backup CronJob | [ ] |
