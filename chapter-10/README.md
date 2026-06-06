# Chapter 10: Advanced Topics & Scenarios

## 📚 Learning Objectives

- Operators and CRDs
- Real-world troubleshooting
- Performance optimization
- Best practices

---

## Top 50 Kubernetes Interview Questions - Master List

### Architecture (5 questions)
1. ✅ What happens when you run `kubectl apply`? → [Ch1 Q1](../chapter-01/README.md#q1)
2. ✅ Explain etcd architecture → [Ch1 Q2](../chapter-01/README.md#q2)
3. ✅ How does the scheduler decide which node? → [Ch1 Q3](../chapter-01/README.md#q3)
4. ✅ What is the reconciliation loop? → [Ch1 Q4](../chapter-01/README.md#q4)
5. ✅ Control plane vs Data plane → [Ch1 Q5](../chapter-01/README.md#q5)

### Pods (5 questions)
6. ✅ Pod vs Container → [Ch2 Q1](../chapter-02/README.md#q1)
7. ✅ Multi-container pod use cases → [Ch2 Q2](../chapter-02/README.md#q2)
8. ✅ Init containers vs sidecars → [Ch2 Q3](../chapter-02/README.md#q3)
9. ✅ Pod communication within same pod → [Ch2 Q4](../chapter-02/README.md#q4)
10. ✅ Pod restart policies → [Ch2 Q5](../chapter-02/README.md#q5)

### Workloads (5 questions)
11. ✅ Deployment vs ReplicaSet → [Ch3 Q1](../chapter-03/README.md#q1)
12. ✅ Rolling update strategy → [Ch3 Q2](../chapter-03/README.md#q2)
13. ✅ How to rollback → [Ch3 Q3](../chapter-03/README.md#q3)
14. ✅ maxUnavailable vs maxSurge → [Ch3 Q4](../chapter-03/README.md#q4)
15. ✅ When to use DaemonSet → [Ch3 Q5](../chapter-03/README.md#q5)

### Networking (10 questions)
16. ✅ ClusterIP vs NodePort vs LoadBalancer → [Ch4 Q1](../chapter-04/README.md#q1)
17. ✅ How kube-proxy works → [Ch4 Q2](../chapter-04/README.md#q2)
18. ✅ Headless service → [Ch4 Q3](../chapter-04/README.md#q3)
19. DNS resolution in Kubernetes
20. Service endpoints
21. External traffic policy
22. Session affinity
23. Ingress vs LoadBalancer
24. Network policies default deny
25. CNI plugins

### Storage (4 questions)
26. ✅ PV vs PVC → [Ch5 Q1](../chapter-05/README.md#q1)
27. ✅ Access modes → [Ch5 Q2](../chapter-05/README.md#q2)
28. Storage class purpose
29. Dynamic vs static provisioning

### Configuration (3 questions)
30. ✅ ConfigMap vs Secret → [Ch6 Q1](../chapter-06/README.md#q1)
31. Secret encryption
32. Downward API

### Observability (5 questions)
33. ✅ Liveness vs Readiness → [Ch7 Q1](../chapter-07/README.md#q1)
34. Probe types and parameters
35. Startup probes
36. Debugging CrashLoopBackOff
37. OOMKilled investigation

### Scheduling (5 questions)
38. ✅ How HPA works → [Ch8 Q1](../chapter-08/README.md#q1)
39. ✅ HPA vs VPA → [Ch8 Q2](../chapter-08/README.md#q2)
40. Node affinity
41. Taints and tolerations
42. Pod disruption budgets

### Security (8 questions)
43. ✅ RBAC components → [Ch9 Q1](../chapter-09/README.md#q1)
44. ✅ Network policies → [Ch9 Q2](../chapter-09/README.md#q2)
45. Service account tokens
46. Pod security standards
47. Security contexts
48. Secret management best practices
49. TLS in Kubernetes
50. Principle of least privilege

---

## Scenario-Based Questions

### S1: Application is down
**Debug steps:**
1. `kubectl get pods` - check status
2. `kubectl describe pod` - check Events
3. `kubectl logs` - check app logs
4. `kubectl logs --previous` - if crashed
5. `kubectl get events --sort-by=.metadata.creationTimestamp`
6. Check resource limits, node status, network policies

### S2: Slow application performance
**Investigate:**
1. `kubectl top pods` - check resource usage
2. `kubectl top nodes` - check node capacity
3. HPA status
4. Node affinity/distribution
5. Network latency

### S3: Image pull errors
**Common causes:**
- Wrong image name/tag
- Private registry without imagePullSecret
- Network connectivity issues
- Registry authentication expired

### S4: DNS not resolving
**Debug:**
1. Check CoreDNS pods: `kubectl get pods -n kube-system -l k8s-app=kube-dns`
2. Test from pod: `nslookup kubernetes.default`
3. Check CoreDNS config: `kubectl get configmap coredns -n kube-system`
4. Check network policies blocking DNS (port 53)

### S5: Volume mount issues
**Check:**
1. PVC status: `kubectl get pvc`
2. PV availability
3. Mount permissions
4. SELinux/AppArmor blocking

---

## ✅ Chapter Completion

Mark completed in [CHECKLIST.md](../CHECKLIST.md)

**Congratulations! You've completed all chapters!**
