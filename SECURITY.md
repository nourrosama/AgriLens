# AgriLens Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.0.x   | Yes       |

## Reporting a Vulnerability

If you discover a security vulnerability, please report it privately to the project team:

- **Email**: s-rahma.shaaban@zewailcity.edu.eg
- **Response time**: Within 72 hours
- Do **not** open a public GitHub issue for security vulnerabilities.

---

## Security Controls Implemented

### Authentication & Authorization

| Control | Implementation | Standard |
|---------|---------------|----------|
| Stateless authentication | JWT (HS256), 24-hour expiry | OWASP A07 |
| OTP-only login | No passwords stored; 6-digit codes via SMS/email | OWASP A07 |
| Role-based access control | Roles: farmer, researcher, admin | OWASP A01 |
| Subscription-tier access | @require_plan decorator on premium endpoints | OWASP A01 |
| Admin isolation | @require_admin stacked on @require_auth | OWASP A01 |

### Input Validation & Injection Prevention

| Control | Implementation | Standard |
|---------|---------------|----------|
| Phone validation | E.164 format enforced; sanitize_phone() normalizes input | OWASP A03 |
| Email validation | Regex + lower-case normalization | OWASP A03 |
| File upload validation | Magic-byte verification (not extension-only) | OWASP A03 |
| File size limit | 50 MB maximum content length | OWASP A04 |
| MongoDB parameterization | PyMongo driver uses BSON ObjectId; no string query injection | OWASP A03 |

### Rate Limiting

| Endpoint | Limit | Backend |
|----------|-------|---------|
| OTP send | 3 per 10 minutes per phone/email | Redis |
| OTP verify | 5 attempts per 10 minutes | Redis |
| Scan upload | 10 per minute | Redis |
| Global API | 50,000 per minute / 500,000 per hour | Redis |

### Transport Security

- **HTTPS** enforced via Flask-Talisman (FORCE_HTTPS=true in production)
- **HSTS** (Strict-Transport-Security) header enabled
- **X-Frame-Options** set to DENY (clickjacking protection)
- **Content-Security-Policy** headers configured
- **Referrer-Policy**: strict-origin-when-cross-origin
- **MongoDB** connection uses TLS with certifi certificate verification
- **SMTP** (OTP email delivery) uses SSL/TLS (port 465)

### Data Protection

- Auth tokens stored in **OS keychain** on mobile (flutter_secure_storage with Android Keystore / iOS Keychain)
- OTPs stored in **Redis with 10-minute TTL** — automatically expire
- Audit logs stored in MongoDB with **90-day TTL index** (auto-deleted)
- User passwords: **not stored** (OTP-only authentication)
- Profile images: stored on Cloudinary or local filesystem (not in MongoDB)

### Audit Logging

All sensitive actions are logged to the `audit_logs` collection with:
- User ID, action name, IP address, resource ID, timestamp (UTC)
- Actions covered: otp_sent, login_success, register_success, account_deleted, data_export_requested

### GDPR Controls

| Right | Implementation |
|-------|---------------|
| Right to erasure | DELETE /api/auth/account — cascades across all collections |
| Right to portability | GET /api/auth/export-data — JSON bundle of profile, farms, scans |
| Consent | Checkbox at registration captures consent_given_at timestamp |
| Data minimization | OTP-only auth (no password); minimal profile fields required |

---

## OWASP Top 10 (2021) Mapping

| Risk | Status | Implementation |
|------|--------|---------------|
| A01 Broken Access Control | Mitigated | JWT + RBAC + user-scoped MongoDB queries |
| A02 Cryptographic Failures | Mitigated | TLS for DB/SMTP/HTTPS; secure token storage |
| A03 Injection | Mitigated | Input validation, BSON parameterization, magic-byte checks |
| A04 Insecure Design | Mitigated | Rate limiting, confidence thresholds, subscription tiers |
| A05 Security Misconfiguration | Mitigated | Flask-Talisman headers; secrets via environment variables |
| A06 Vulnerable Components | Ongoing | Dependencies pinned in requirements.txt / pubspec.yaml |
| A07 Auth Failures | Mitigated | OTP auth, rate-limited verify, JWT expiry |
| A08 Software Integrity Failures | Mitigated | Magic-byte upload verification |
| A09 Logging Failures | Mitigated | Structured JSON audit logging with user ID and IP |
| A10 SSRF | N/A | No server-side URL fetching from user input |

---

## ISO/IEC 27001 Alignment

| ISO 27001 Control | Implementation |
|-------------------|---------------|
| A.9 Access Control | JWT bearer tokens, RBAC, @require_auth decorators |
| A.10 Cryptography | TLS in transit; OS keychain for mobile tokens |
| A.12 Operations Security | Structured audit logs, rate limiting, health monitoring |
| A.13 Communications Security | HTTPS enforcement, CORS restricted to /api/* routes |
| A.16 Incident Management | Audit log trail enables post-incident investigation |
| A.18 Compliance | GDPR-aligned data deletion and export endpoints |
