# Kubernetes Interview Mastery - Complete Guide

> **Goal:** Crack any Kubernetes interview from Junior to Senior/DevOps levels

## 📋 Progress Tracking

Track your learning progress in multiple formats:

| Format | File | Best For |
|--------|------|----------|
| Markdown | [PROGRESS.md](./PROGRESS.md) | Reading and editing |
| CSV | [PROGRESS.csv](./PROGRESS.csv) | Excel/Google Sheets |
| JSON | [PROGRESS.json](./PROGRESS.json) | Apps and automation |
| Script | [progress.sh](./progress.sh) | Command-line tracking |

### Quick Progress Check

```bash
# View status summary
./progress.sh status

# List incomplete items
./progress.sh list

# Mark chapter 1 theory complete
./progress.sh mark 1 theory
```

| Status | Meaning |
|--------|---------|
| ⬜ | Not Started |
| 🟡 | In Progress |
| ✅ | Completed |

## 📚 Chapters Overview

| Chapter | Topic | Interview Focus | Est. Time |
|---------|-------|-----------------|-----------|
| [Chapter 01](./chapter-01) | Kubernetes Architecture | Control plane, components, etcd | 2 days |
| [Chapter 02](./chapter-02) | Pods & Containers | Multi-container, lifecycle, networking | 3 days |
| [Chapter 03](./chapter-03) | Workloads & Controllers | Deployments, scaling, strategies | 3 days |
| [Chapter 04](./chapter-04) | Services & Networking | ClusterIP, NodePort, Ingress, CNI | 4 days |
| [Chapter 05](./chapter-05) | Storage & Volumes | PV/PVC, storage classes, CSI | 3 days |
| [Chapter 06](./chapter-06) | Configuration | ConfigMaps, Secrets, downward API | 2 days |
| [Chapter 07](./chapter-07) | Observability | Probes, logging, monitoring, debugging | 3 days |
| [Chapter 08](./chapter-08) | Scheduling & Scaling | HPA, VPA, affinity, taints, PDB | 3 days |
| [Chapter 09](./chapter-09) | Security | RBAC, network policies, Pod Security | 3 days |
| [Chapter 10](./chapter-10) | Advanced & Real-World | Operators, CRDs, troubleshooting scenarios | 4 days |

**Total Duration:** ~4 weeks (with practice)

---

## 🎯 Interview Levels

### Junior Level (0-2 years)
Focus on: Chapters 1-6
Key areas: Pods, Deployments, Services, ConfigMaps, basic troubleshooting

### Mid Level (2-5 years)
Focus on: Chapters 1-9
Key areas: All above + Networking, Storage, RBAC, HPA, advanced debugging

### Senior/DevOps (5+ years)
Focus on: All chapters + Chapter 10
Key areas: All above + Operators, multi-cluster, disaster recovery, security hardening

---

## 📝 How to Use This Guide

1. **Open CHECKLIST.md** - Mark your progress as you go
2. **Read the chapter** - Theory with diagrams
3. **Review interview questions** - At the end of each chapter
4. **Practice with YAMLs** - Apply every example
5. **Complete hands-on labs** - Real-world scenarios
6. **Mark complete** in checklist when done

---

## 🚨 Interview Success Formula

```
Theory Understanding (30%)
    +
Hands-on Practice (40%)
    +
Real-world Scenarios (20%)
    +
Communication Skills (10%)
    = 
✅ Interview Cracked
```

---

## 🏆 Top 50 Interview Questions (Preview)

### Architecture (Chapter 1)
1. What happens when you run `kubectl apply`?
2. Explain the role of etcd in Kubernetes
3. How does the scheduler decide which node to place a pod?

### Pods (Chapter 2)
4. Difference between Pod and Container?
5. What are init containers and when to use them?
6. How do containers in the same pod communicate?

### Deployments (Chapter 3)
7. What is the difference between Deployment and ReplicaSet?
8. Explain RollingUpdate vs Recreate strategies
9. How do you rollback a deployment?

### Services (Chapter 4)
10. Difference between ClusterIP, NodePort, LoadBalancer?
11. How does kube-proxy work?
12. What is a Headless service and when to use it?

*[See CHECKLIST.md for full 50-question index with links to answers]*

---

## 🔗 Quick Links

- [Progress Tracker](./PROGRESS.md) - Multiple formats available:
  - [PROGRESS.md](./PROGRESS.md) - Human-readable markdown
  - [PROGRESS.csv](./PROGRESS.csv) - Spreadsheet compatible
  - [PROGRESS.json](./PROGRESS.json) - Machine-readable
  - [progress.sh](./progress.sh) - Command-line tool
- [Top 50 Questions Quick Reference](./chapter-10/50-interview-questions.md)
- [Scenario-Based Questions](./chapter-10/scenario-questions.md)
- [Cheat Sheet](./cheat-sheet.md)

---

## 🎓 Certification Correlation

| Certification | Chapters Needed |
|---------------|-----------------|
| KCNA | Chapters 1-5 |
| CKA | Chapters 1-8 |
| CKAD | Chapters 1-7 |
| CKS | Chapters 1-10 (Security focus) |

---

**Ready to start? Open [CHECKLIST.md](./CHECKLIST.md) and Chapter 01!**
