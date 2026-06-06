# Chapter 4: Services & Networking

## 📚 Learning Objectives

By the end of this chapter, you will:
- Understand Kubernetes networking model
- Configure all service types (ClusterIP, NodePort, LoadBalancer)
- Implement Ingress for HTTP routing
- Secure traffic with Network Policies
- Debug DNS and connectivity issues

**Estimated Time:** 4 days  
**Labs:** 5 hands-on exercises

---

## 🌐 Kubernetes Networking Model

### Core Principles

Kubernetes networking is based on three fundamental requirements:

1. **All pods can communicate with all other pods** without NAT
2. **All nodes can communicate with all pods** without NAT
3. **Each pod gets its own IP address** (Pod IP)

```
┌─────────────────────────────────────────────────────────────┐
│     Node 1 (10.0.1.10)                                     │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Pod A (10.244.1.2)                      │  │
│  │                 Can reach:                           │  │
│  │                 • Pod B (10.244.1.3) via localhost   │  │
│  │                 • Pod C (10.244.2.2) directly        │  │
│  │                 • Pod D (10.244.2.3) directly        │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
              ▼               ▼               ▼
┌─────────────────  Pod-to-Pod Direct Routing  ───────────────┐
│                     No NAT needed                           │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│     Node 2 (10.0.1.11)                                     │
│  ┌─────────────────────┐        ┌─────────────────────┐     │
│  │   Pod C (10.244.2.2)│        │   Pod D (10.244.2.3)│     │
│  └─────────────────────┘        └─────────────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔌 Service Types Explained

### Service as Load Balancer

```
                    Service (ClusterIP)
                   10.96.0.10:80
                         │
         ┌───────────────┼───────────────┐
         │               │               │
         ▼               ▼               ▼
    ┌─────────┐     ┌─────────┐     ┌─────────┐
    │  Pod 1  │     │  Pod 2  │     │  Pod 3  │
    │10.244.1│     │10.244.1 │     │10.244.1 │
    │    :80  │     │    :80  │     │    :80  │
    └─────────┘     └─────────┘     └─────────┘
    
    kube-proxy (iptables/IPVS)轮询到各个 Pod
```

### 1. ClusterIP (Default)

**Purpose:** Internal cluster access only

```
External User ──✗──► ClusterIP Service ──► Pods
                        (10.96.0.10)

Pod in Cluster ──✓──► ClusterIP Service ──► Pods
```

**Use case:** Microservices communicating internally

---

### 2. NodePort

**Purpose:** Expose service on each node's IP

```
External User
        │
        ▼
   Node IP:30080 (NodePort)
        │
        ▼
   Service:80
        │
        ▼
      Pods
```

**Port Range:** 30000-32767

```yaml
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30080  # Or auto-assigned
```

**Use case:** Development, bare metal clusters

---

### 3. LoadBalancer

**Purpose:** Cloud provider load balancer

```
Internet
    │
    ▼
┌────────────────────────────────────┐
│  Cloud Load Balancer (AWS/GCP/     │
│  Azure provisioned)                │
│  External IP: 203.0.113.10         │
└────────────────────────────────────┘
              │
              ▼
        Service:80
              │
              ▼
            Pods
```

**Use case:** Production, cloud environments

---

### 4. Headless Service

**Purpose:** Direct pod access, no load balancing

```yaml
spec:
  clusterIP: None  # Headless!
```

**DNS Behavior:**
```
Regular Service:    returns Service IP
Headless Service:   returns Pod IPs directly

 StatefulSet: web-0, web-1, web-2
 DNS:
   web-0.web-headless.default.svc.cluster.local → 10.244.1.2
   web-1.web-headless.default.svc.cluster.local → 10.244.1.3
```

**Use case:** StatefulSets, direct pod communication

---

### 5. ExternalName

**Purpose:** DNS alias to external service

```yaml
spec:
  type: ExternalName
  externalName: api.external-provider.com
```

**Result:** `my-service.default.svc.cluster.local` CNAME to `api.external-provider.com`

---

## 🚪 Ingress Explained

### What is Ingress?

Ingress exposes HTTP/HTTPS routes from outside the cluster to services within the cluster.

```
Internet
    │
    ▼
┌────────────────────────────────────────┐
│  Ingress Controller (Nginx/Traefik)   │
│  - Requires installation              │
└────────────────────────────────────────┘
         │
    ┌────┴────┐
    ▼         ▼
Ingress   Ingress
Rules     Rules
    │         │
    ▼         ▼
Service1  Service2
    │         │
    ▼         ▼
  Pods      Pods
```

### Ingress vs LoadBalancer

| LoadBalancer | Ingress |
|-------------|---------|
| One service per LB | Multiple services per Ingress |
| L4 (TCP) | L7 (HTTP) |
| Expensive (cloud) | Cost effective |
| No routing rules | Path/host-based routing |

### Routing Types

**Path-based routing:**
```yaml
spec:
  rules:
  - host: myapp.com
    http:
      paths:
      - path: /api
        backend:
          service: api-service
      - path: /static
        backend:
          service: static-service
```

**Host-based routing:**
```yaml
spec:
  rules:
  - host: api.myapp.com
    http:
      paths:
      - backend:
          service: api-service
  - host: blog.myapp.com
    http:
      paths:
      - backend:
          service: blog-service
```

---

## 🛡️ Network Policies

### Default Behavior

**By default:** All pods can communicate with all pods (allow all).

### Zero-Trust Model

```
Step 1: Default Deny All
┌─────────────────────────────┐
│  Namespace: production     │
│                             │
│  ┌─────────┐  ┌─────────┐  │
│  │  Pod A  │X◄│  Pod B  │  │  ❌ BLOCKED
│  └─────────┘  └─────────┘  │
└─────────────────────────────┘

Step 2: Explicit Allow Rules
┌─────────────────────────────┐
│                             │
│  ┌─────────┐   ┌─────────┐  │
│  │  Web    │──►│   API   │  │  ✓ ALLOWED
│  └─────────┘   └─────────┘  │
└─────────────────────────────┘
```

### Policy Types

**Ingress:** Who can send traffic to this pod
**Egress:** Where this pod can send traffic

**Example Policy:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-policy
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
          app: web  # Only pods with label app=web can connect
    ports:
    - protocol: TCP
      port: 8080
```

---

## 🔍 DNS in Kubernetes

### DNS Records

| Resource | DNS Pattern | Example |
|----------|-------------|---------|
| Service | `service.namespace.svc.cluster.local` | `mysql.production.svc.cluster.local` |
| Pod (headless) | `pod-ip.namespace.pod.cluster.local` | `10-244-1-2.default.pod.cluster.local` |
| StatefulSet | `pod-name.service.namespace.svc.cluster.local` | `web-0.web.production.svc.cluster.local` |

### Short Names

```
same namespace:     mysql
other namespace:    mysql.production
cluster:            mysql.production.svc.cluster.local
```

### CoreDNS

Kubernetes DNS is provided by CoreDNS (or kube-dns in older versions).

```
Pod requests mysql
       │
       ▼
/etc/resolv.conf → search default.svc.cluster.local
       │
       ▼
   CoreDNS Pod
       │
       ▼
   Resolves to Service IP
```

---

## 📊 Theory to Labs

### Lab 4.1: Microservices Architecture
**Theory Applied:**
- ClusterIP for internal communication
- DNS resolution between services
- 3-tier architecture patterns

### Lab 4.2: Network Policies
**Theory Applied:**
- Default deny all pattern
- Explicit allow rules
- Defense in depth

### Lab 4.3: Ingress Routing
**Theory Applied:**
- Path-based routing
- Host-based routing
- SSL/TLS termination

---

## 📖 Key Takeaways

1. **Pod IP unique:** Every pod gets its own IP
2. **Service = Load Balancer:** Distributes traffic to pods
3. **ClusterIP internal:** Only within cluster
4. **NodePort external:** On each node's IP
5. **LoadBalancer cloud:** Cloud provider LB
6. **Ingress L7:** HTTP routing, needs controller
7. **NetworkPolicy firewall:** Default allow, can restrict
8. **DNS automatic:** Services get DNS entries automatically

---

## ❓ Interview Questions

### Q: ClusterIP vs NodePort vs LoadBalancer?

**Answer:**

| Type | Scope | Use Case |
|------|-------|----------|
| **ClusterIP** | Internal only | Microservices communication |
| **NodePort** | External via node IP | Development, bare metal |
| **LoadBalancer** | External via cloud LB | Production cloud environments |

**Traffic flow:**
- ClusterIP: Pod → Service IP → Pod
- NodePort: External → NodeIP:Port → Service → Pod
- LoadBalancer: External → Cloud LB → Service → Pod

---

### Q: What is a Headless service?

**Answer:**

Service with `clusterIP: None`. No virtual IP is assigned.

**DNS behavior difference:**
- Regular service: DNS returns Service ClusterIP
- Headless service: DNS returns individual Pod IPs

**Use cases:**
- StatefulSets (direct pod access)
- Client-side load balancing
- Service discovery

---

## 🔗 Next Steps

1. Review theory above
2. Complete [Lab 4.1](./LABS.md) - Microservices
3. Complete [Lab 4.2](./LABS.md) - Network Policies
4. Complete [Lab 4.3](./LABS.md) - Ingress

**Next Chapter:** [Chapter 5: Storage](../chapter-05/)
