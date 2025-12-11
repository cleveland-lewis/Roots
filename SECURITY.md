# Security Policy

Roots is a macOS student planner intended for real-world academic use, so security and stability are treated as first-class concerns.

This document explains:

- Which versions receive security updates
- How to report a vulnerability
- How we handle and track security issues

---

## Supported Versions

Security fixes are only guaranteed for actively maintained releases.

Update this table as you cut real versions:

| Version   | Supported          |
|----------|--------------------|
| 0.2.x    | ✅ Active          |
| 0.1.x    | ⚠️ Critical-fixes only |
| < 0.1    | ❌ Not supported   |

Interpretation:

- **Active** – receives all applicable security fixes and high-impact bug fixes.
- **Critical-fixes only** – only critical security issues (e.g., data loss, privacy leaks) may be patched.
- **Not supported** – no security updates; upgrade to a supported version.

---

## Reporting a Vulnerability

If you believe you have found a security or privacy issue in Roots:

1. **Do not open a public GitHub Issue.**
2. Instead, send a private report to:

   - `security@` (replace with your actual security contact email), **or**
   - GitHub Security Advisory (if enabled for this repo).

Your report should include:

- A short description of the issue
- Steps to reproduce
- Impact assessment (what an attacker can do)
- Any relevant logs, screenshots, or PoC code

If the issue involves sensitive user data, keep all details in private channels only.

---

## Response Expectations

After you submit a report:

- **Acknowledgment** – We aim to acknowledge reports within **3 business days**.
- **Initial assessment** – We will triage and attempt an initial severity assessment within **7 days**.
- **Status updates** – While the issue is being investigated, we will provide updates at least every **14 days**, or sooner if there is a release or important change.

We may ask for more details, logs, or environment information to reproduce and understand the issue.

---

## Handling & Disclosure

Once a vulnerability is confirmed:

1. **Triage and classification**
   - Assign a severity (e.g., Critical / High / Medium / Low).
   - Identify affected versions and components.

2. **Fix development**
   - Implement and test a fix in a private branch.
   - Run the full test suite, including security workflows (CodeQL, tests, etc.).

3. **Release**
   - Release a patched version.
   - Update release notes with a short description of the issue (without sensitive exploit details).
   - Optionally credit the reporter (with their consent).

4. **Advisory**
   - If appropriate, publish a GitHub Security Advisory linked to the affected commits and releases.

We will avoid publishing exploit details that would meaningfully increase risk before most users can reasonably update.

---

## Security Hardening & Automation

This repository uses (or intends to use):

- **Code scanning** with [GitHub CodeQL](https://github.com/github/codeql-action) for Swift to detect common vulnerability patterns.   
- **Dependency review** on pull requests to surface risky or vulnerable dependencies before merging.
- **Dependabot** to keep GitHub Actions and Swift dependencies up to date, including security advisories and version updates for Swift.   

Breaking changes or security-relevant changes are expected to be covered by automated tests and CI workflows before release.

---

## Out of Scope

The following are generally **out of scope** for security reports:

- Local development misconfigurations that do not affect production builds.
- Issues that require root/system-level compromise outside the app’s control.
- Behavior that is part of the documented limitations of the platform (e.g., macOS sandboxing rules).

If you are unsure whether something is in scope, send a report anyway. Worst case, it will be closed as informational.
