# Security Policy

> ⚠️ **Note:** This repository is source-visible for inspection only and is NOT open source. 
> See [LICENSE](LICENSE) for usage restrictions.

Roots is a macOS student planner distributed as proprietary software. This source code 
is made available for security auditing, transparency, and educational purposes only.

This document explains how to report security vulnerabilities discovered through code inspection.

---

## Code Availability

The source code is visible to allow security researchers and users to:
- Audit the codebase for security vulnerabilities
- Verify privacy and data handling practices
- Review the implementation for transparency

**You may NOT:**
- Use findings from code inspection to create competing implementations
- Share exploit code or detailed vulnerability information publicly before responsible disclosure
- Submit pull requests or code contributions (this is not an open source project)

---

## Reporting a Vulnerability

If you discover a security vulnerability through code inspection or testing:

1. **Do NOT open a public GitHub Issue** describing the vulnerability
2. **Do NOT submit a pull request** attempting to fix it (PRs are not accepted)
3. **Do** report it privately via:
   - GitHub Security Advisories (preferred)
   - Direct contact: Cleveland Lewis (see repository profile)

### What to Include in Your Report

- Description of the vulnerability
- Affected code locations (file paths and line numbers)
- Steps to reproduce (if applicable)
- Potential impact assessment
- Suggested remediation (optional)

**Keep all details confidential** until the issue is resolved and disclosed responsibly.

---

## Response Timeline

After submitting a security report:

- **Acknowledgment:** Within 3 business days
- **Initial assessment:** Within 7 days
- **Status updates:** Every 14 days until resolution

We may request additional information to validate and reproduce the issue.

---

## Disclosure Process

Once a vulnerability is confirmed and fixed:

1. The fix will be released in an updated version
2. Security advisory may be published (with reporter credit, if desired)
3. Coordinated disclosure timeline will be followed

We follow responsible disclosure practices and will not publish exploit details 
prematurely.

---

## Out of Scope

The following are typically **out of scope** for security reports:

- Issues requiring physical device access or system-level compromise
- Theoretical vulnerabilities without practical exploit path
- Issues in third-party dependencies (report to the upstream project)
- Platform limitations (macOS sandboxing, system permission requirements)
- Social engineering attacks

When in doubt, report it anyway—we'll triage appropriately.

---

## Recognition

Security researchers who responsibly disclose valid vulnerabilities may be acknowledged 
in security advisories or release notes (with your permission).

---

## Questions

For questions about this security policy or licensing inquiries, contact Cleveland Lewis.
