# Chapter 4: Services & Networking - Interview Questions

> 25+ Interview Questions with Detailed Answers

---

## Basic Level Questions

### Q1: What are the different Kubernetes Service types?

**Answer:**

| Type | Scope | External Access | Use Case |
|------|-------|-----------------|----------|
| **ClusterIP** | Internal | No | Microservices communication |
| **NodePort** | External via node | Yes (30000-32767) | Development, bare metal |
| **LoadBalancer** | External via cloud LB | Yes | Production cloud |
| **ExternalName** | External DNS | Yes | Point to external service |
| **Headless** | Pod IPs directly | N/A | StatefulSets |

**Traffic flow:**
```
ClusterIP:      Pod → Service IP → Pod
NodePort:       External → NodeIP:Port → Service → Pod
LoadBalancer:   External → Cloud LB → Service → Pod
```

---

### Q2: What is the difference between ClusterIP, NodePort and LoadBalancer?

**Answer:**

**ClusterIP:**
- Internal cluster IP only
- Accessible only within cluster
- Default type

**NodePort:**
- Opens port (30000-32767) on every node
- External access via NodeIP:NodePort
- Kube-proxy forwards to Service

**LoadBalancer:**
- Cloud provider provisions external load balancer
- Gets external IP address
- Forwards to service endpoints

**Cost/Complexity:** ClusterIP < NodePort < LoadBalancer

---

### Q3: What is a Headless Service?

**Answer:**

**Definition:** Service with `clusterIP: None` - no virtual IP assigned.

**Behavior difference:**
- Regular service: DNS returns Service ClusterIP
- Headless service: DNS returns Pod IPs directly

**Use cases:**
- StatefulSets (direct pod access)
- Client-side load balancing
- Service discovery where you need pod IPs

**Example:**
```yaml
spec:
  clusterIP: None
  selector:
    app: web
```

**DNS:** `web-0.web.default.svc.cluster.local` resolves to pod IP

---

### Q4: How does kube-proxy work?

**Answer:**

**Purpose:** Implements Kubernetes Service networking.

**Three modes:**

| Mode | Mechanism | Scale |
|------|-----------|-------|
| **iptables** (default) | NAT rules | ~5K services |
| **IPVS** | Kernel load balancer | >100K services |
| **userspace** (legacy) | Proxy process | Obsolete |

**iptables:**
```
Pod → iptables DNAT rule → Service IP → Random Pod IP
```

**IPVS:**
```
Pod → IPVS load balancer (kernel space) → Selected Pod IP
```

---

### Q5: What is an Ingress?

**Answer:**

**Definition:** API object that manages external HTTP/HTTPS access to services.

**Why use Ingress:**
| LoadBalancer | Ingress |
|--------------|---------|
| One service per LB | Many services per Ingress |
| Layer 4 (TCP) | Layer 7 (HTTP) |
| Expensive (cloud) | Cost-effective |
| No routing rules | Path/host-based routing |

**Requires:** Ingress Controller (Nginx, Traefik, Istio)

**Routing types:**
- Path-based: `/api` → api-service
- Host-based: `api.example.com` → api-service

---

## Intermediate Level Questions

### Q6: Explain the Kubernetes networking model.

**Answer:**

**Three core principles:**
1. All pods can communicate with all other pods (no NAT)
2. All nodes can communicate with all pods (no NAT)
3. Each pod gets its own IP address

**Pod-to-Pod:** Direct routing via CNI plugin
**Pod-to-Service:** Via kube-proxy (iptables/IPVS)
**External-to-Pod:** Via NodePort/LoadBalancer/Ingress

**CNI plugins:** Flannel, Calico, Cilium, Weave

---

### Q7: What is DNS resolution in Kubernetes?

**Answer:**

**Records:**

| Resource | DNS Format | Example |
|----------|------------|---------|
| Service | `service.namespace.svc.cluster.local` | `mysql.production.svc.cluster.local` |
| Pod | `pod-ip.namespace.pod.cluster.local` | `10-244-1-2.default.pod.cluster.local` |
| StatefulSet | `pod-name.service.namespace.svc.cluster.local` | `web-0.web.production.svc.cluster.local` |

**Short names:**
- Same namespace: `mysql`
- Other namespace: `mysql.production`

**CoreDNS:** Kubernetes DNS server, runs as pods in kube-system

---

### Q8: What are Network Policies?

**Answer:**

**Purpose:** Control traffic flow at IP/port level (firewall for pods).

**Default:** Allow all (open by default)

**Zero-trust approach:**
```
Step 1: Default deny all
Step 2: Explicitly allow required traffic
```

**Policy types:**
- **Ingress:** Who can send traffic to pod
- **Egress:** Where pod can send traffic

**Example:**
```yaml
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: web
```

---

### Q9: What is a Service Endpoint?

**Answer:**

**Definition:** IP:Port combination of pods backing a service.

**How it works:**
```
Service selector: app=web
Matches pods with label app=web

Endpoints object created:
- 10.244.1.2:8080
- 10.244.1.3:8080
- 10.244.1.4:8080

kube-proxy uses endpoints for routing
```

**Check endpoints:**
```bash
kubectl get endpoints <service-name>
```

---

### Q10: What is External Traffic Policy?

**Answer:**

**Options for LoadBalancer/NodePort:**

| Policy | Behavior | Pros | Cons |
|--------|----------|------|------|
| **Cluster** (default) | Route to any pod | Balanced distribution | Extra hop, SNAT hides source IP |
| **Local** | Route only to local pods | Preserves source IP | Potential imbalance |

**Use Local when:** You need original client IP

---

## Advanced Level Questions

### Q11: What is a CNI plugin?

**Answer:**

**CNI:** Container Network Interface - standard for network plugins.

**Responsibilities:**
- Allocate IP addresses to pods
- Create network interfaces
- Configure pod-to-pod routing

**Popular CNI plugins:**

| Plugin | Pros | Cons |
|--------|------|------|
| **Calico** | Network policies, BGP, scalable | Complex |
| **Flannel** | Simple, works everywhere | No network policies |
| **Cilium** | eBPF-based, observability, security | Kernel requirements |
| **Weave** | Easy, encrypted by default | Slower |

---

### Q12: How do you troubleshoot DNS resolution issues?

**Answer:**

**Debug steps:**
```bash
# 1. Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# 2. Test DNS from pod
kubectl run -it --rm debug --image=busybox -- nslookup kubernetes.default

# 3. Check DNS service
kubectl get svc -n kube-system kube-dns

# 4. Check CoreDNS config
kubectl get configmap -n kube-system coredns

# 5. Check network policies
kubectl get networkpolicy --all-namespaces

# 6. Check DNS resolution in container
cat /etc/resolv.conf
```

**Common fixes:**
- Restart CoreDNS pods
- Check DNS service endpoints
- Verify no blocking network policies

---

### Q13: What is the difference between Ingress and LoadBalancer?

**Answer:**

| LoadBalancer | Ingress |
|--------------|---------|
| Layer 4 (TCP) | Layer 7 (HTTP) |
| One service per LB | Multiple services per Ingress |
| Cloud provider manages | You manage controller |
| Expensive per service | Cost-effective |
| Simple | More complex routing |

**Typical setup:**
```
Internet
    │
    ▼
LoadBalancer (cloud)
    │
    ▼
Ingress Controller
    │
    ├─► Service A (path: /api)
    └─► Service B (path: /app)
```

---

### Q14: How does session affinity work in Services?

**Answer:**

**Configuration:**
```yaml
spec:
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 10800  # 3 hours
```

**How it works:**
- Client IP hashed → always routed to same pod
- Based on source IP
- Timeouts after configured duration

**Limitations:**
- Not guaranteed if pod dies
- May not work well with proxies/NAT

---

### Q15: What is a Network Policy default deny?

**Answer:**

**Implementation:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
spec:
  podSelector: {}  # All pods
  policyTypes:
  - Ingress
  - Egress
```

**Effect:**
- Blocks ALL incoming traffic to all pods in namespace
- Blocks ALL outgoing traffic from all pods
- Must explicitly add "allow" policies

**Add DNS:**
```yaml
spec:
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector: {}
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
```

---

## Scenario-Based Questions

### S1: Pod can reach internet but not other pods in cluster.

**Answer:**

**Likely causes:**
1. Network policy blocking internal traffic
2. CNI plugin configuration issue
3. Network segmentation/firewall

**Debug:**
```bash
# Check network policies
kubectl get networkpolicies --all-namespaces

# Test pod-to-pod communication
kubectl exec pod-a -- ping <pod-b-ip>

# Check CNI logs
kubectl logs -n kube-system -l k8s-app=calico-node
```

---

### S2: Service endpoints are empty.

**Answer:**

**Causes:**
1. Wrong selector (labels don't match)
2. Pods not ready
3. No pods with matching labels

**Fix:**
```bash
# Check selector
kubectl get svc mysvc -o yaml | grep selector

# Check pods
kubectl get pods -l app=web

# Check readiness
kubectl get pods -l app=web | grep Running
```

---

## Quick Reference

| Service Type | DNS | External |
|--------------|-----|----------|
| ClusterIP | Yes | No |
| NodePort | Yes | Yes (NodeIP:Port) |
| LoadBalancer | Yes | Yes (External IP) |
| Headless | Pod IPs | N/A |

---

## Key Takeaways

1. **ClusterIP internal:** For microservices
2. **NodePort for dev:** Quick external access
3. **LoadBalancer prod:** Cloud load balancer
4. **Headless bypass:** Direct pod access
5. **NetworkPolicy firewall:** Default allow, can restrict
6. **CoreDNS required:** For service discovery
7. **CNI required:** For pod networking

---

**Previous:** [Chapter 3 Interview Questions](../chapter-03/INTERVIEW.md)  
**Next:** [Chapter 5 Interview Questions](../chapter-05/INTERVIEW.md)
