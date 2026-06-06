# Chapter 7: Observability - Interview Questions

> 15+ Interview Questions with Detailed Answers

---

## Basic Level Questions

### Q1: What is the difference between liveness and readiness probes?

**Answer:**

| Probe | Question | Action on Failure | Restart? |
|-------|----------|-------------------|----------|
| **Liveness** | Is container running? | Kill and restart | Yes |
| **Readiness** | Is container ready for traffic? | Remove from service endpoints | No |

**Visual:**
```
Traffic
   │
   ▼
Service ──► Endpoint (only if Ready)
   │
   ▼
Pod
├── Container (restart if Liveness fails)
└── Container (removed from service if Readiness fails)
```

**Use both:**
- Liveness: Restart dead containers
- Readiness: Control traffic to warming up containers

---

### Q2: What are the different probe types?

**Answer:**

1. **HTTP GET:**
```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
```

2. **TCP Socket:**
```yaml
livenessProbe:
  tcpSocket:
    port: 3306
```

3. **Exec:**
```yaml
livenessProbe:
  exec:
    command:
    - cat
    - /tmp/healthy
```

**Choose based on:**
- HTTP probe: Web applications
- TCP probe: Databases, TCP services
- Exec probe: Custom health checks

---

### Q3: What is a startup probe?

**Answer:**

**Purpose:** For slow-starting applications.

**Problem without startup probe:**
```
Slow app (60s to start)
Liveness starts checking at 10s (fails)
Container restarted before ready
CrashLoopBackOff
```

**Solution:**
```yaml
startupProbe:
  httpGet:
    path: /healthz
    port: 8080
  failureThreshold: 30  # 10s * 30 = 300s
```

**Behavior:**
- Disables liveness and readiness until succeeds
- Gives slow apps time to start
- Once succeeds, normal probes take over

---

### Q4: What are probe parameters?

**Answer:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `initialDelaySeconds` | 0 | Wait before first check |
| `periodSeconds` | 10 | Check frequency |
| `timeoutSeconds` | 1 | Request timeout |
| `failureThreshold` | 3 | Failures before action |
| `successThreshold` | 1 | Successes to mark healthy |

**Calculation:**
- Time to failure = `initialDelaySeconds + (failureThreshold - 1) * periodSeconds`
- Example: 0 + (3 - 1) * 10 = 20 seconds to restart

---

### Q5: What is OOMKilled and how is it different from CrashLoopBackOff?

**Answer:**

| OOMKilled | CrashLoopBackOff |
|-----------|------------------|
| Memory limit exceeded | Application crash (any reason) |
| Exit code 137 (128+9) | Any non-zero exit code |
| Resource issue | Application issue |
| Fix: Increase limit | Fix: Debug application |

---

## Intermediate Level Questions

### Q6: How do you debug a pod stuck in Pending?

**Answer:**

**Debug steps:**
```bash
# 1. Check events
kubectl describe pod <name>
# Look for: Insufficient cpu, memory, node selector mismatch

# 2. Check resources
kubectl describe pod | grep -A10 "Requests"

# 3. Check nodes
kubectl get nodes
kubectl describe node <node>

# 4. Check taints
kubectl get nodes -o json | jq '.items[].spec.taints'

# Common causes:
# - No node with enough resources
# - Node selector mismatch
# - Taints preventing scheduling
# - Volume not available
```

---

### Q7: What are common pod failure exit codes?

**Answer:**

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 126 | Permission denied |
| 127 | Command not found |
| 137 (128+9) | SIGKILL (OOMKilled / manual kill) |
| 143 (128+15) | SIGTERM |

**Check:**
```bash
kubectl get pod <name> -o jsonpath='{.status.containerStatuses[0].state.terminated.exitCode}'
```

---

### Q8: How do preStop hooks work?

**Answer:**

**Purpose:** Graceful shutdown before termination.

**Example:**
```yaml
lifecycle:
  preStop:
    exec:
      command:
      - sh
      - -c
      - "nginx -s quit; sleep 30"
```

**Flow:**
```
Pod deletion requested
     │
     ├─► preStop hook runs
     │   (grace period: default 30s)
     │
     ├─► SIGTERM sent
     │   (grace period continues)
     │
     └─► SIGKILL sent (force kill)
```

**Note:** PreStop must complete within terminationGracePeriodSeconds

---

### Q9: How do you troubleshoot DNS issues?

**Answer:**

```bash
# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Test DNS
kubectl run -it --rm debug --image=busybox -- nslookup kubernetes.default

# Check DNS config
kubectl get configmap coredns -n kube-system -o yaml

# Check resolv.conf
kubectl exec <pod> -- cat /etc/resolv.conf

# Common fixes:
# - Restart CoreDNS
# - Check network policies
# - Verify DNS service endpoints
```

---

### Q10: What are sidecar containers for logging?

**Answer:**

**Pattern:** Main app writes logs, sidecar ships them.

```yaml
containers:
- name: app
  volumeMounts:
  - name: logs
    mountPath: /var/log/app
- name: fluentd
  image: fluent/fluentd
  volumeMounts:
  - name: logs
    mountPath: /var/log/app
```

**Why sidecar:**
- App doesn't need to know about logging system
- Can use specialized logging image
- Independent upgrades

---

## Advanced Level Questions

### Q11: What is a termination grace period?

**Answer:**

**Definition:** Time between termination request and SIGKILL.

**Default:** 30 seconds

**Customize:**
```yaml
spec:
  terminationGracePeriodSeconds: 60
```

**Flow:**
```
T+0:   Delete pod signal
T+0:   preStop hook starts
T+30:  preStop must complete, SIGTERM sent
T+60:  SIGKILL sent (total grace period)
```

**Application handling:**
```
// Catch SIGTERM, finish requests, then exit
process.on('SIGTERM', () => {
  server.close(() => process.exit(0));
});
```

---

### Q12: What is Priority for pods?

**Answer:**

**Definition:** Which pods to evict first under resource pressure.

**Classes:**

| Priority | Eviction Order |
|----------|----------------|
| Guaranteed QoS | Last |
| Burstable QoS | Middle |
| BestEffort QoS | First |

**Custom PriorityClass:**
```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000000
globalDefault: false
preemptionPolicy: PreemptLowerPriority
```

---

### Q13: What causes ImagePullBackOff?

**Answer:**

**Causes:**
1. Wrong image name/tag
2. Private registry without imagePullSecret
3. Network issues reaching registry
4. Registry authentication expired

**Debug:**
```bash
kubectl describe pod <name>
# Events: Failed to pull image, rpc error

# Fix image:
kubectl set image deployment/app app=correct-image:tag

# Fix secret:
kubectl create secret docker-registry regcred \
  --docker-server=registry.example.com
```

---

### Q14: How do you monitor pod health at scale?

**Answer:**

**Tools:**
1. **Prometheus + Alertmanager:** Metrics and alerting
2. **Grafana:** Dashboards
3. **Loki:** Log aggregation
4. **Jaeger:** Distributed tracing

**Key metrics:**
- Container restart rate
- Pod phase distribution
- Resource utilization
- Probe failure rate

**Health checks:**
```yaml
livenessProbe:
  httpGet:
    path: /metrics  # Prometheus compatible
    port: 9090
```

---

### Q15: What is the difference between kubectl logs and kubectl describe?

**Answer:**

| kubectl logs | kubectl describe |
|--------------|------------------|
| Application stdout/stderr | Kubernetes events |
| Container output | Pod lifecycle |
| `--previous` for crashed | Resource details |
| Real-time with `-f` | Current state |

**Use both:**
```bash
# Application issue
kubectl logs <pod>
kubectl logs <pod> --previous  # If crashed

# Kubernetes issue
kubectl describe pod <pod>
```

---

## Scenario-Based Questions

### S1: Application shows healthy but not serving traffic.

**Answer:**

**Check:**
1. Is readiness probe passing?
```bash
kubectl get pod -o yaml | grep -A10 readinessProbe
```

2. Is service selector matching?
```bash
kubectl get svc -o yaml | grep selector
kubectl get pods -l app=web
```

3. Are endpoints populated?
```bash
kubectl get endpoints <service>
```

**Fix:**
- Fix readiness probe path
- Fix service selector labels

---

### S2: Pod keeps restarting but logs are empty.

**Answer:**

**Causes:**
1. Very fast crash (logs not written)
2. Logs written to file, not stdout
3. Container exits immediately

**Debug:**
```bash
# Check previous logs
kubectl logs --previous

# Check events
kubectl describe pod | grep -A20 Events

# Check exit code
kubectl get pod -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}'

# Exec into running pod (if not crashing)
kubectl exec -it <pod> -- sh
```

---

## Quick Reference

| Command | Purpose |
|---------|---------|
| `kubectl logs` | Application logs |
| `kubectl logs --previous` | Previous container logs |
| `kubectl describe` | Kubernetes events |
| `kubectl get events` | Cluster events |
| `kubectl top pod` | Resource usage |

---

## Key Takeaways

1. **Liveness:** Restart if dead
2. **Readiness:** Remove from service if not ready
3. **Startup:** Disable others for slow starters
4. **OOMKilled:** Increase memory limit
5. **CrashLoopBackOff:** Check `--previous` logs
6. **Pending:** Check describe events
7. **Describe + Logs:** Debug combo

---

**Previous:** [Chapter 6 Interview Questions](../chapter-06/INTERVIEW.md)  
**Next:** [Chapter 8 Interview Questions](../chapter-08/INTERVIEW.md)
