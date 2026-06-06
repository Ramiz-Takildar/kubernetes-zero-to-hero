# Chapter 7 Labs: Observability

## Lab 7.1: Comprehensive Health Checks

### Objective
Deploy production-grade health checking.

### Production YAML
```yaml
# production-health-checks.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: health-monitored-app
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: monitored
  template:
    metadata:
      labels:
        app: monitored
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 8080
        
        # Startup probe - handles slow starting apps
        startupProbe:
          httpGet:
            path: /healthz/startup
            port: 8080
            httpHeaders:
            - name: Accept
              value: application/json
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 30  # 10 * 30 = 300 seconds max
        
        # Liveness probe - restart if dead
        livenessProbe:
          httpGet:
            path: /healthz/live
            port: 8080
          initialDelaySeconds: 0  # Managed by startup probe
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
          successThreshold: 1
        
        # Readiness probe - remove from service if not ready
        readinessProbe:
          httpGet:
            path: /healthz/ready
            port: 8080
          initialDelaySeconds: 0  # Managed by startup probe
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 2
          successThreshold: 2  # Must be ready twice
        
        # Resource monitoring
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
        
        # Pre-stop hook for graceful shutdown
        lifecycle:
          preStop:
            exec:
              command:
              - /bin/sh
              - -c
              - "nginx -s quit; sleep 30"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tcp-health-check
  namespace: production
spec:
  replicas: 2
  selector:
    matchLabels:
      app: tcp-app
  template:
    metadata:
      labels:
        app: tcp-app
    spec:
      containers:
      - name: database
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: root-password
        ports:
        - containerPort: 3306
        
        # TCP socket probe
        livenessProbe:
          tcpSocket:
            port: 3306
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
        
        readinessProbe:
          exec:
            command:
            - mysql
            - -h
            - localhost
            - -u
            - root
            - -p${MYSQL_ROOT_PASSWORD}
            - -e
            - "SELECT 1"
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: advanced-probes
  namespace: production
spec:
  replicas: 1
  selector:
    matchLabels:
      app: advanced
  template:
    metadata:
      labels:
        app: advanced
    spec:
      containers:
      - name: app
        image: busybox
        command:
        - sh
        - -c
        - |
          # Simulate startup delay
          echo "Initializing..."
          sleep 20
          
          # Create health check file
          mkdir -p /var/health
          touch /var/health/live
          touch /var/health/ready
          
          echo "Application started"
          
          # Simulate occasional readiness issues
          while true; do
            sleep 30
            if [ $(($(date +%s) % 120)) -gt 60 ]; then
              rm -f /var/health/ready
              echo "Not ready"
            else
              touch /var/health/ready
              echo "Ready"
            fi
          done
        
        livenessProbe:
          exec:
            command:
            - cat
            - /var/health/live
          initialDelaySeconds: 5
          periodSeconds: 10
        
        readinessProbe:
          exec:
            command:
            - cat
            - /var/health/ready
          initialDelaySeconds: 25
          periodSeconds: 5
```

---

## Lab 7.2: Centralized Logging

### Objective
Deploy centralized logging with Fluentd.

### Production YAML
```yaml
# centralized-logging.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
  namespace: kube-system
  labels:
    k8s-app: fluentd-logging
spec:
  selector:
    matchLabels:
      name: fluentd
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
  template:
    metadata:
      labels:
        name: fluentd
    spec:
      serviceAccountName: fluentd
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        effect: NoSchedule
      containers:
      - name: fluentd
        image: fluent/fluentd:v1.16-debian
        env:
        - name: FLUENTD_OPT
          value: "-v"
        - name: FLUENT_UID
          value: "0"
        resources:
          limits:
            memory: 500Mi
          requests:
            cpu: 100m
            memory: 200Mi
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
        - name: fluentd-config
          mountPath: /fluentd/etc
        securityContext:
          privileged: true
      terminationGracePeriodSeconds: 30
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
      - name: fluentd-config
        configMap:
          name: fluentd-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluentd-config
  namespace: kube-system
data:
  fluent.conf: |
    <source>
      @type tail
      path /var/log/containers/*.log
      pos_file /var/log/fluentd-docker.pos
      tag kubernetes.*
      <parse>
        @type json
        time_format %Y-%m-%dT%H:%M:%S.%NZ
      </parse>
    </source>
    
    <filter kubernetes.**>
      @type kubernetes_metadata
    </filter>
    
    <match kubernetes.**>
      @type elasticsearch
      host elasticsearch-logging
      port 9200
      logstash_format true
      logstash_prefix kubernetes
    </match>
```

---

## Lab 7.3: Prometheus Monitoring

### Objective
Deploy prometheus monitoring for applications.

### Production YAML
```yaml
# prometheus-monitoring.yaml
apiVersion: v1
kind: ServiceMonitor
metadata:
  name: app-metrics
  namespace: monitoring
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app: monitored
  endpoints:
  - port: metrics
    interval: 15s
    path: /metrics
    honorLabels: true
    metricRelabelings:
    - sourceLabels: [__name__]
      regex: 'go_.*'
      action: drop
---
apiVersion: v1
kind: Service
metadata:
  name: app-metrics
  namespace: production
  labels:
    app: monitored
spec:
  selector:
    app: monitored
  ports:
  - name: metrics
    port: 9090
    targetPort: 9090
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus-exporter
  namespace: production
spec:
  replicas: 2
  selector:
    matchLabels:
      app: monitored
  template:
    metadata:
      labels:
        app: monitored
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
        prometheus.io/path: "/metrics"
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
          name: http
        - containerPort: 9090
          name: metrics
```

---

## Completion Checklist

| Lab | Description | Status |
|-----|-------------|--------|
| 7.1 | Comprehensive Health Checks | [ ] |
| 7.2 | Centralized Logging | [ ] |
| 7.3 | Prometheus Monitoring | [ ] |
