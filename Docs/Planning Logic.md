# Planning Logic

This document defines the scoring logic for computing a final schedule_index ∈ [0, 1] and the rules for assigning tasks to time slots.

The scheduler uses four independent factors:
	1.	Priority Factor
	2.	Due Date Factor
	3.	Category Modifier
	4.	Energy Compatibility

Urgency is additive, not multiplicative.
Energy influences placement, not urgency.

⸻

# 1. Priority Factor

Priority represents user-assigned importance.

Priority	Factor
Low	0.4
Medium	0.7
High	1.0

priority_factor ∈ [0.4, 1.0]

⸻

# 2. Due Date Factor

Convert the due date into a continuous urgency signal.

days_until_due = max(0, (due_date - today).inDays)
horizon_days = 14
due_factor_raw = 1 - (days_until_due / horizon_days)
due_factor = clamp(due_factor_raw, 0.0, 1.0)

Examples (horizon_days = 14):
	•	Due today → 1.0
	•	Due in 7 days → 0.5
	•	Due in ≥14 days → 0.0

due_factor ∈ [0.0, 1.0]

⸻

# 3. Category Modifier

Category nudges urgency but never dominates it.

Category	Modifier
Exam	1.0
Project	0.9
Quiz	0.8
Homework	0.7
Reading	0.6

category_factor ∈ [0.6, 1.0]

⸻

# 4. Base Urgency Score

Urgency is computed additively:

base_urgency =
    0.5 * priority_factor +
    0.4 * due_factor +
    0.1 * category_factor

This avoids multiplicative collapse and keeps urgency interpretable.

You may optionally normalize:

schedule_index = clamp(base_urgency, 0.0, 1.0)

Range of possible schedule_index: 0.26–1.0

⸻

# 5. Energy Compatibility

Energy does not change urgency.
Instead, it determines which time slot is a better fit.

## 5.1 Task Energy Requirement

Requirement	Value
Low	0.0
Medium	0.5
High	1.0

task_energy_required ∈ {0.0, 0.5, 1.0}

## 5.2 Slot Energy Level

Each time block represents a predicted user energy level:

slot_energy ∈ [0.0, 1.0]

## 5.3 Energy Match Score

energy_match = 1 - abs(task_energy_required - slot_energy)

	•	Perfect match → 1.0
	•	Total mismatch → 0.0

## 5.4 Placement Score for Each Slot

placement_score =
    0.8 * schedule_index +
    0.2 * energy_match

The scheduler tests each slot and selects the slot with the highest placement_score.

⸻

# 6. Full Pipeline Summary
	1.	User enters task (priority, category, due date, energy requirement).
	2.	Convert to numeric values:
	•	priority_factor
	•	due_factor
	•	category_factor
	3.	Compute urgency → base_urgency → schedule_index.
	4.	For each available time slot:
	•	Calculate energy_match
	•	Calculate placement_score
	5.	Choose the slot with the best score.
	6.	Resolve conflicts by shifting lower-urgency tasks.
	7.	Re-run scheduler whenever:
	•	A task is completed
	•	A task becomes overdue
	•	A task is added
	•	User updates energy level

⸻

# 7. Implementation Notes
	•	All constants should be user-configurable:
	•	horizon_days
	•	urgency weights
	•	energy weight
	•	Log urgency and energy values for debugging.
	•	Visualize schedule_index in your dashboard for transparency.
	•	Avoid storing raw factors in the database; compute them on the fly.

⸻
