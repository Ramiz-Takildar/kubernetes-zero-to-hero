# Chapter 7: Observability

## Interview Questions (15)

### Q1: What is the difference between Liveness and Readiness probes?

**Answer:**

| Probe | Purpose | Action on Failure |
|-------|---------|-------------------|
| **Liveness** | Is container running correctly? | Restart container |
| **Readiness** | Is container ready for traffic? | Remove from service endpoints |

**Timing:**
- Readiness fails immediately → traffic stops
- Liveness fails after threshold → container restarts

---

## ✅ Chapter Completion

Mark completed in [CHECKLIST.md](../CHECKLIST.md)
