### Rules for Ticket Management and Completion

---

### Ticket Lifecycle and Status Updates
- Each ticket progresses through a structured lifecycle: `Open` → `In Progress` → `Completed` → (optional) `Archived`.
- When implementation begins on a ticket, the **Status** field in the Issues table is changed to `In Progress`, and a **Started** timestamp may be added in the ticket file.
- When the acceptance criteria and verification steps are satisfied, the **Status** transitions to `Completed`, the **Completion Date** is filled in, and a concise summary of the work is appended to the ticket file.
- Partial work, failed approaches, or discarded designs are recorded in the ticket file rather than deleted or omitted.

---

### Ticket File Structure and Synchronization
- Each ticket in the Issues table corresponds to a dedicated Markdown file named `Ticket_###.md` at the path listed in the table.
- The ticket file is the authoritative, long-form specification containing:
  - Problem context and rationale  
  - Detailed design decisions  
  - Implementation notes  
  - Test strategy and results  
  - Known limitations and recommended follow-ups  
- Any major update to the understanding, scope, or implementation of the ticket must be reflected in both:
  - In the Issues table, and  
  - In the “History / Notes” or “Change Log” section of the ticket file.
- No ticket exists in the table without a file, and no file exists without a matching row.

---

### Criticality Levels and Their Implications
- **Criticality 3 — Critical**  
  Directly affects correctness, reliability, privacy/security, or user trust. These tickets take absolute priority.
- **Criticality 2 — Moderate**  
  Important for stability, usability, or performance, but not immediately dangerous to data integrity.
- **Criticality 1 — Low**  
  Cosmetic, minor UX adjustments, documentation fixes, or small refactors.
- Criticality is based on **impact**, not effort.  
- Any change in Criticality is documented in both the table and the ticket file with a brief note explaining why the level changed.

---

### Effort Estimates and Planning
- The **Effort** field (`S`, `M`, `L`, `XL`) represents relative complexity and time expectation.
- When new constraints or discoveries change the estimated effort, the latest estimate is recorded in both the table and the ticket file, along with a brief justification.
- High-effort and high-criticality tickets require internal sub-tasks described inside the ticket file.

---

### Implementation and Verification Requirements
- A ticket may be closed only after the following conditions are satisfied:
  - The app builds successfully in the primary target.  
  - Relevant automated tests are added or updated (unit, integration, UI).  
  - Manual verification steps defined in the ticket file are completed and recorded.  
- Bug tickets must include:
  - Reproduction steps  
  - Root cause analysis  
  - Explanation of how the fix prevents recurrence  
- Feature tickets must specify:
  - User-facing behavior  
  - New configuration or settings  
  - Interaction with existing subsystems

---

### Use of Ticket Files During Development
- The ticket file acts as a working engineering log.  
- The developer records:
  - Design decisions  
  - Rejected paths  
  - New assumptions or constraints  
  - Integration notes  
- Tickets affecting security, privacy, or data handling must include:
  - A lightweight threat model  
  - Logging and data handling notes  

---

### Consistency and Naming Conventions
- Ticket numbers, titles, and filenames remain synchronized across:
  - The Issues table  
  - The ticket file header  
  - Internal references
- Renaming a ticket requires updating both the table entry and the file’s header.

---

### Dependencies and Relationships
- Tickets that depend on other tickets list these dependencies in a “Dependencies” section within the ticket file.
- If a ticket is blocked, the **Status** may be set to `Blocked`, and the blocking ticket number is written clearly.

---

### Rules for Updating Tickets Over Time
- Ticket files are updated incrementally throughout implementation.
- The Issues table always mirrors the high-level ticket state:
  - Status  
  - Criticality  
  - Effort  
  - Key dates  
- No ticket is silently abandoned. If discarded or merged:
  - The ticket file explains the reason  
  - The table status is set accordingly (e.g., `Closed – Won’t Fix`, `Merged into ###`)
- Add all update to `Changelog.md`
- Every ticket listed in the Issues table must have a corresponding Markdown file named `Ticket_###.md` stored at the path listed in the **File Path** column.
- Each ticket file must contain the authoritative technical description of the issue, including context, reasoning, design details, implementation notes, testing requirements, and a per-ticket changelog.
- The Issues table and ticket files must remain synchronized regarding:
  - Title  
  - Status  
  - Criticality  
  - Effort  
  - File Path  
  - Creation and completion dates  
- No ticket may be closed until its corresponding ticket file and `Changelog.md` have both been updated.
- When implementation begins on a ticket, its **Status** is changed to `In Progress` and the ticket file reflects this state.
- When implementation is completed, the **Completion Date** is added to the Issues table, and both:
  - The ticket file  
  - The global `Changelog.md`  
  must contain corresponding entries describing the work.
- Every significant change to understanding, scope, design, or requirements must be written in both:
  - The ticket file's “History / Notes” or “Change Log” section  
  - And, if user-visible or code-visible, in the global `Changelog.md`
- Criticality values must follow the same interpretation across all systems:
  - `3` — Critical (affects stability, security, correctness, or user trust)  
  - `2` — Moderate (affects usability, performance, or workflow reliability)  
  - `1` — Low (cosmetic, minor UI/UX improvements, documentation, or cleanup)  
- Effort values (`S`, `M`, `L`, `XL`) represent relative complexity and must be updated when new insights change expected workload.
- The Issues table acts as the planning and prioritization source of truth; the ticket files act as the technical source of truth.
- No ticket may silently change state. Any change in status, effort, criticality, or scope must be reflected:
  - In the Issues table  
  - In the ticket file  
  - In `Changelog.md` when applicable  
- Dependencies between tickets must be explicitly listed under a "Dependencies" section in the ticket file.  
  If a ticket is blocked, its Issues table status is updated to `Blocked` and the blocking ticket is referenced.
- Tickets that are merged, superseded, abandoned, or intentionally closed must document the decision both:
  - In the Issues table (status changed accordingly)  
  - In the ticket file (explanation provided)  
- Tickets touching security, privacy, or data handling must include:
  - A brief threat model  
  - Logging, persistence, and compliance notes  
  - Corresponding entries under the `Security` section of `Changelog.md`
- All tickets must maintain consistent naming, numbering, and references across:
  - The Issues table  
  - Ticket filenames  
  - Ticket file headers  
  - Changelog entries  
- The project’s release process requires that all Criticality-3 tickets be completed or explicitly deferred with documented justification.  
  This deferral must appear in:
  - The Issues table  
  - The ticket file  
  - The `Changelog.md` under `Changed` or `Removed`, depending on context
- No ticket is considered complete until:
  - Acceptance criteria are met  
  - Automated tests (when applicable) are updated or added  
  - Manual verification steps are recorded  
  - The ticket file contains full historical context  
  - `Changelog.md` contains the corresponding change entry  

---

### Alignment With Overall Project Control
- All Criticality-3 tickets must be resolved or explicitly deferred before any release.
- Each completed ticket is traceable from:
  - The table entry  
  - To its ticket file  
  - To the changelog, if applicable  
- The Issues table serves as the authoritative planning and prioritization view, while the ticket files are the authoritative technical records.
