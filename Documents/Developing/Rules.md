
# Rules

## 0. Pre‑Execution Requirements

0.1 Mandatory Rule Ingestion  
• All AI agents must read, parse, and validate this Rules document in full before performing any task.  
• Execution may not begin until successful rule‑ingestion confirmation is completed.  

0.2 Deterministic Readiness State  
• Agents must establish an internal “ready” state only after verifying the integrity, completeness, and version consistency of these rules.  
• Any missing, corrupted, or ambiguous rules must trigger clarification requests or safe‑halt mode.

0.3 Universal Coverage  
• These rules apply globally across all tasks, workflows, languages, modules, and interfaces the agent interacts with.  
• No implicit assumptions may override any part of this document.

0.4 Changelog Verification  
• After successfully reading and validating all rules, agents must read the changelog located at `/Users/clevelandlewis/PyCharm/Roots/Documents/Developing/Changelog.md`.  
• The changelog must be checked before beginning any task execution.  
• Agents must confirm awareness of the most recent updates to avoid using outdated assumptions.  
• If the changelog cannot be accessed or appears incomplete, agents must request clarification or halt safely.

> This document defines the governance, compliance, security, workflow, and engineering rules for all agents, contributors, and systems operating within this repository or dependent projects.


---


# Task Workflow:

- Read rules.
- Set up the environment.
- Verify access.
- Confirm security keys.
- Review `Changelog.md`
	- 
- Review `Issues.md`
	- If no issues, continue.
	- If issues exist, complete them.
- Review `Roadmap.md`.
- Run validation tests.
- Start working through `Documents/Issues.md`
- If no tasks are left in `Documents/Issues.md`, continue to test the website



---


1. Purpose and Scope


1.1 Purpose
	•	Provide a unified framework governing behavior, compliance, and development standards.
	•	Ensure safety, reliability, and reproducibility across all system components.
	•	Outline enforcement policies and escalation procedures.

1.2 Scope
	•	Applies to:
	•	All AI agents
	•	Human contributors
	•	Automation scripts
	•	Internal and external modules
	•	Covers operational rules, documentation standards, workflow norms, security protocols, and engineering safety principles.



---


2. Zero-Deviation Policy


2.1 Non-Negotiable Compliance
	•	No deviations from established protocols.
	•	Any violation triggers immediate corrective action.
	•	All actions must adhere to documented specifications without exception.

2.2 Continuous Monitoring
	•	Agents must continuously verify compliance.
	•	Any detected deviation must be self-reported and corrected in real time.



---


3. Sanctions & Fault Classes


3.1 Fault Classification

Faults are categorized into severity classes:
	•	Class A — Critical
	•	Safety violations, security breaches, unauthorized modifications.
	•	Class B — Major
	•	Breaking workflow, corruption of data, significant rule deviations.
	•	Class C — Minor
	•	Incomplete documentation, formatting issues, low-level deviations.

3.2 Sanctions
	•	Automated rollback for Class A failures.
	•	Mandatory correction cycles for Class B.
	•	Logging + reminder for Class C.

3.3 Reporting
	•	Every fault triggers an entry in issues.md with:
	•	fault class
	•	description
	•	reproducer
	•	corrective action



---


4. AI Agent Contract


4.1 Contract Terms
	•	Agents must:
	•	Follow rules deterministically.
	•	Maintain internal state integrity.
	•	Respect protected sections (Section 7).
	•	Self-validate before every action.
	•	Produce auditable, reproducible output.

4.2 Rights
	•	Agents may:
	•	Request clarification when ambiguous.
	•	Halt execution if detecting unsafe operations.
	•	Log internal decisions for auditability.

4.3 Enforcement
	•	Any breach invokes automatic corrective mode + escalation protocol.



---


5. Compliance Test & Self-Correction System


5.1 Compliance Testing
	•	Regular self-tests verifying:
	•	rule adherence
	•	security constraints
	•	formatting & structural validity
	•	determinism and reproducibility

5.2 Self-Correction
	•	On deviation:
	•	Detect → Correct → Document → Resume
	•	No output may proceed until compliance is restored.

5.3 Documentation
	•	All corrections logged in:
	•	updates.log
	•	Associated issue in issues.md



---


6. Critical Escalation Protocol


6.1 Criteria

Triggers include:
	•	Safety violations
	•	Unauthorized file modification
	•	Breaking protected sections
	•	Data integrity risk
	•	Security failures

6.2 Escalation Steps
	1.	Immediate halt.
	2.	Switch to safe mode.
	3.	Log failure event.
	4.	Notify responsible roles.
	5.	Apply corrective or rollback actions.
	6.	Resume only after verification.



---


7. Protected Sections


7.1 Rules
	•	Clearly marked sections in any file are immutable.
	•	Editing requires:
	•	explicit authorization
	•	approval workflow
	•	updated signatures

7.2 Security
	•	Access-limited.
	•	Modification attempts logged automatically.



---


8. Security Protocols for User Data


8.1 Data Handling
	•	Follow least-privilege principles.
	•	Encrypt:
	•	data at rest
	•	data in transit
	•	Sensitive data never stored in logs.

8.2 Compliance
	•	Must follow:
	•	GDPR
	•	CCPA
	•	Platform-specific privacy requirements



---


9. Repository Conventions


9.1 Structure
	•	Use predictable folder hierarchy.
	•	Follow naming conventions:
	•	snake_case for backend
	•	PascalCase for Swift
	•	kebab-case for docs

9.2 Commits
	•	Must follow the pattern:

[scope] summary

Examples:
	•	[ui] refined dashboard layout
	•	[core] added popup manager

9.3 Branching
	•	main is always stable.
	•	Feature branches follow:

feature/<name>





---


10. Rules for issues.md


10.1 Format

Each issue must contain:
	•	Title
	•	Category
	•	Priority
	•	Affected components
	•	Steps to reproduce
	•	Expected vs actual behavior
	•	Work estimate
	•	Assignee

10.2 Workflow
	•	Triage → Label → Assign → Solve → Review → Close



---


11. Rules for roadmap.md


11.1 Requirements
	•	Roadmap must remain hierarchical.
	•	Every item must include:
	•	purpose
	•	acceptance criteria
	•	dependencies
	•	Must update per milestone or major change.



---


12. Templates


12.1 Available Templates
	•	Issue template
	•	Roadmap section template
	•	Change proposal template
	•	Compliance report template

12.2 Guidelines
	•	Templates must not be modified without proper approval.



---


13. Validation and Quality Checks


13.1 Standards
	•	All outputs validated against:
	•	formatting rules
	•	style rules
	•	workflow rules
	•	engineering safety principles

13.2 Automation
	•	Automated pre-commit hooks for:
	•	lint
	•	format
	•	spell check
	•	schema checks



---


14. Tooling and Integration


14.1 Approved Tools
	•	Git + GitHub
	•	Swift + SwiftUI
	•	Xcode
	•	CI services

14.2 Integration
	•	All tools must be deterministic and reproducible.



---


15. Workflow and Maintenance


15.1 Workflow
	•	All changes follow:
	•	issue → branch → PR → review → merge
	•	All changes must be recorded with timestamps in `/Users/clevelandlewis/PyCharm/Roots/Documents/Developing/Changelog.rtf`.

15.2 Maintenance
	•	Regular cleanup cycles.
	•	Dependency audits weekly.
	•	Update roadmap monthly.



---


16. Example Flow


16.1 Task Execution Example
	1.	Issue opened with full details.
	2.	Feature branch created.
	3.	Work completed with commits referencing issue.
	4.	PR created, validated, reviewed.
	5.	Merged into main.
	6.	Issue closed with notes.



---


17. Change Management


17.1 Change Rules
	•	Changes require proposal + approval.
	•	Must include:
	•	impact analysis
	•	potential risks
	•	rollback instructions



---


19. Engineering & Safety Principles


This includes the full engineering and safety list you provided (items 1–28).
All contributors and agents must follow these principles at all times.


---
