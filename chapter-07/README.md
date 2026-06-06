# Chapter 7: Observability

## 📚 Learning Objectives

By the end of this chapter, you will:
- Configure liveness, readiness, and startup probes
- Debug pod failures effectively
- Set up centralized logging
- Implement monitoring with Prometheus

**Estimated Time:** 2 days  
**Labs:** 5 hands-on exercises

---

## 🔍 Health Probes

### Three Types

```
┌──────────────────────────────────────────────────────────┐
│              Container Lifecycle                         │
│                                                          │
│  Container Created                                       │
│       │                                                  │
│       ▼                                                  │
│  ┌────────────────────────────────────────────────────┐  │
│  │              Startup Probe                         │  │
│  │  • Is the container starting successfully?         │  │
│  │  • Disables liveness/readiness until succeeded     │  │
│  └────────────────────┬───────────────────────────────┘  │
│                       │                                  │
│       Success         ▼                                  │
│                       │                                  │
│       ┌───────────────┴───────────────┐                  │
│       │                               │                  │
│       ▼                               ▼                  │
│  ┌──────────────┐              ┌──────────────┐         │
│  │   Liveness   │              │  Readiness   │         │
│  │   Probe      │              │   Probe      │         │
│  │              │              │              │         │
│  │ • Container  │              │ • Ready for  │         │
│  │   running?   │              │   traffic?   │         │
│  │              │              │              │         │
│  │ Fail:        │              │ Fail:        │         │
│  │ RESTART      │              │ REMOVE from  │         │
│  │ container    │              │ service      │         │
│  └──────────────┘              └──────────────┘         │
└──────────────────────────────────────────────────────────┘
```

### Probe Types Comparison

| Probe | Question | Action on Failure | Restart? |
|-------|----------|-------------------|----------|
| **Startup** | Is container starting? | Kill and restart | Yes |
| **Liveness** | Is container alive? | Kill and restart | Yes |
| **Readiness**| Is container ready for traffic? | Remove from endpoints | No |

### Probe Mechanisms

#### HTTP GET

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
    httpHeaders:
    - name: Custom-Header
      value: health-check
```

#### TCP Socket

```yaml
livenessProbe:
  tcpSocket:
    port: 3306
```

#### Exec Command

```yaml
livenessProbe:
  exec:
    command:
    - cat
    - /tmp/healthy
```

### Probe Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `initialDelaySeconds` | 0 | Wait before first check |
| `periodSeconds` | 10 | Check frequency |
| `timeoutSeconds` | 1 | Request timeout |
| `failureThreshold` | 3 | Failures before action |
| `successThreshold` | 1 | Successes to mark healthy |

### Startup Probe Use Case

**Problem:** Slow-starting Java app

**Without startup probe:**
```
T+0:    Pod starts
T+10s:  Liveness check (fails, app not ready)
T+20s:  Liveness check (fails)
T+30s:  Liveness check (fails) → RESTART → Loop forever
```

**With startup probe:**
```
T+0:    Pod starts
T+0:    Startup probe begins (liveness disabled)
T+300s: Startup succeeds (within failureThreshold * periodSeconds)
T+300s: Liveness probe starts
```

---

## 🐛 Debugging

### Common Pod Issues

| Issue | Symptom | Debug Command |
|-------|---------|---------------|
| ImagePullBackOff | Wrong image | `kubectl describe pod` |
| CrashLoopBackOff | App crashes | `kubectl logs --previous` |
| Pending | No node fits | `kubectl describe pod` |
| OOMKilled | Memory exceeded | `kubectl describe pod` |

### Debugging Process

```
1. kubectl get pods
   └─ Check status

2. kubectl describe pod <name>
   └─ Check Events section
   └─ Look for scheduling failures

3. kubectl logs <pod>
   └─ Application logs

4. kubectl logs <pod> --previous
   └─ Previous container logs (if crashed)

5. kubectl exec -it <pod> -- sh
   └─ Interactive debugging

6. kubectl get events --sort-by=.metadata.creationTimestamp
   └─ Cluster-wide events
```

---

## 📊 Theory to Labs

### Lab 7.1: Liveness Probe
**Theory Applied:**
- HTTP, TCP, Exec probes
- Restart behavior
- Failure thresholds

### Lab 7.2: Readiness Probe
**Theory Applied:**
- Traffic control
- Service endpoints
- Separation from liveness

### Lab 7.3: Debugging
**Theory Applied:**
- Common issues
- Debug commands
- Root cause analysis

---

## 📖 Key Takeaways

1. **Startup probe:** For slow starters (disables others)
2. **Liveness probe:** Restart if dead
3. **Readiness probe:** Remove from service if not ready
4. **HTTP probes:** Most common for web apps
5. **Exec probes:** For custom health checks
6. **Describe:** First debug command
7. **Logs --previous:** See crash output

---

## ❓ Interview Questions

### Q: Liveness vs Readiness?

**Answer:**

| Liveness | Readiness |
|----------|-----------|
| Is app running? | Is app ready for traffic? |
| Failure: Restart container | Failure: Remove from endpoints |
| Self-healing | Traffic management |

**Use both:**
- Liveness: Container is alive
- Readiness: Container is ready to receive requests

---

## 🔗 Next Steps

1. Review theory above
2. Complete [Lab 7.1](./LABS.md) - Liveness
3. Complete [Lab 7.2](./LABS.md) - Readiness
4. Complete [Lab 7.3](./LABS.md) - Debugging

**Next Chapter:** [Chapter 8: Scheduling](../chapter-08/)
