# Chapter 8 Labs: Scheduling & Scaling

## Lab 8.1: Production Horizontal Pod Autoscaler

### Objective
Configure production-grade autoscaling.

### Production YAML
```yaml
# production-hpa.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scalable-api
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: scalable-api
  template:
    metadata:
      labels:
        app: scalable-api
    spec:
      containers:
      - name: api
        image: nginx:alpine
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: scalable-api
  namespace: production
spec:
  selector:
    app: scalable-api
  ports:
  - port: 80
    targetPort: 8080
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: scalable-api-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: scalable-api
  minReplicas: 3
  maxReplicas: 50
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 70
  - type: Pods
    pods:
      metric:
        name: http_requests_per_second
      target:
        type: AverageValue
        averageValue: "100"
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
      - type: Pods
        value: 4
        periodSeconds: 15
      selectPolicy: Max
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
      - type: Pods
        value: 4
        periodSeconds: 60
      selectPolicy: Min
---
# Cluster Autoscaler PodDisruptionBudget
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: scalable-api-pdb
  namespace: production
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: scalable-api
```

---

## Lab 8.2: Advanced Node Scheduling

### Objective
Implement complex scheduling rules.

### Production YAML
```yaml
# advanced-scheduling.yaml
# Node with taints
apiVersion: v1
kind: Node
metadata:
  name: dedicated-node
  labels:
    node-type: dedicated
    hardware: gpu
spec:
  taints:
  - key: dedicated
    value: "true"
    effect: NoSchedule
  - key: nvidia.com/gpu
    value: "true"
    effect: NoSchedule
---
# Pod with advanced scheduling
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gpu-workload
  namespace: production
spec:
  replicas: 2
  selector:
    matchLabels:
      app: gpu-app
  template:
    metadata:
      labels:
        app: gpu-app
    spec:
      nodeSelector:
        hardware: gpu
      tolerations:
      - key: dedicated
        operator: Equal
        value: "true"
        effect: NoSchedule
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: node-type
                operator: In
                values:
                - dedicated
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: topology.kubernetes.io/zone
                operator: In
                values:
                - us-east-1a
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - gpu-app
            topologyKey: kubernetes.io/hostname
      containers:
      - name: app
        image: nvidia/cuda:latest
        resources:
          limits:
            nvidia.com/gpu: 1
          requests:
            nvidia.com/gpu: 1
---
# Topology spread for high availability
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ha-application
  namespace: production
spec:
  replicas: 6
  selector:
    matchLabels:
      app: ha-app
  template:
    metadata:
      labels:
        app: ha-app
    spec:
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: ha-app
      - maxSkew: 1
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: ScheduleAnyway
        labelSelector:
          matchLabels:
            app: ha-app
      containers:
      - name: app
        image: nginx:alpine
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
```

---

## Lab 8.3: Priority and Preemption

### Objective
Configure pod priority classes.

### Production YAML
```yaml
# priority-classes.yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: system-critical
value: 1000000
globalDefault: false
description: "System critical pods"
preemptionPolicy: PreemptLowerPriority
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 100000
globalDefault: false
description: "High priority user workloads"
preemptionPolicy: PreemptLowerPriority
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: standard
value: 10000
globalDefault: true
description: "Default priority"
preemptionPolicy: PreemptLowerPriority
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: low-priority
value: 1000
globalDefault: false
description: "Low priority batch jobs"
preemptionPolicy: Never
---
# Critical system pod
apiVersion: v1
kind: Pod
metadata:
  name: monitoring-agent
  namespace: kube-system
spec:
  priorityClassName: system-critical
  containers:
  - name: agent
    image: prom/node-exporter:latest
    resources:
      requests:
        memory: "64Mi"
        cpu: "50m"
---
# User workload with high priority
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-service
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: payment
  template:
    metadata:
      labels:
        app: payment
    spec:
      priorityClassName: high-priority
      containers:
      - name: api
        image: nginx:alpine
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
---
# Batch job with low priority
apiVersion: batch/v1
kind: CronJob
metadata:
  name: report-generator
  namespace: production
spec:
  schedule: "0 2 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          priorityClassName: low-priority
          containers:
          - name: generator
            image: busybox
            command: ['sh', '-c', 'echo Generating report; sleep 300']
            resources:
              requests:
                memory: "512Mi"
                cpu: "500m"
          restartPolicy: OnFailure
```

---

## Completion Checklist

| Lab | Description | Status |
|-----|-------------|--------|
| 8.1 | Production HPA | [ ] |
| 8.2 | Advanced Scheduling | [ ] |
| 8.3 | Priority Classes | [ ] |
