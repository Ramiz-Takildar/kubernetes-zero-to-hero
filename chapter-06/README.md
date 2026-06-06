# Chapter 6: Configuration

## 📚 Learning Objectives

- ConfigMaps and Secrets
- Environment variables
- Downward API

## ❓ Interview Questions (15)

### Q1: What is the difference between ConfigMap and Secret?

**Answer:**

| ConfigMap | Secret |
|-----------|--------|
| Non-sensitive data | Sensitive data |
| Stored as plain text | Base64 encoded (not encrypted by default) |
| Same consumption methods | Same consumption methods |
| Max 1MB | Max 1MB (encoded) |
| Can be stored in etcd | Should be encrypted at rest |

### Q2-15: [See full README]

---

## ✅ Chapter Completion

Mark completed in [CHECKLIST.md](../CHECKLIST.md)
