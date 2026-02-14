# Skill: Lead Scorer

## Purpose

Compute composite lead scores for contacts based on their associated signals, role data, and organization fit. Assigns tier labels (HOT/WARM/COOL/COLD) and provides explainable scoring breakdowns.

## When to Invoke

- After contact extraction and/or signal collection is complete
- User says "score leads for [vertical]"
- scoring-agent workflow reaches the scoring stage

## Inputs

- Contact records with associated signals from the database
- `vertical_config.scoring` weights and recency windows
- `vertical_config.contact_targeting` for role-based scoring

## Scoring Model (v1)

Phase 1 uses a simplified scoring model. Sentiment analysis signals may not yet be populated. The scorer must work with whatever data is available.

### Step 1: Load Data

```sql
SELECT c.id, c.first_name, c.last_name, c.title, c.role_category,
       c.is_decision_maker, o.fit_score AS org_fit_score, o.name AS org_name
FROM contacts c
JOIN organizations o ON c.org_id = o.id
WHERE o.vertical_id = ?
```

For each contact, also load signals:
```sql
SELECT signal_type, intensity, relevance_score, captured_at
FROM signals
WHERE contact_id = ? OR org_id = (SELECT org_id FROM contacts WHERE id = ?)
```

### Step 2: Compute Signal Score

For each contact's associated signals:
```
signal_score = SUM(
  intensity * type_weight * recency_multiplier
)
```

Where:
- `intensity`: 1-10 from the signal record
- `type_weight`: From `vertical_config.signal_taxonomy[].weight` matching the signal_type
- `recency_multiplier`: Based on days since `captured_at`:
  - 0-7 days: `recency_windows.hot.multiplier` (3.0)
  - 8-30 days: `recency_windows.warm.multiplier` (1.5)
  - 31-90 days: `recency_windows.cool.multiplier` (1.0)
  - 91-180 days: `recency_windows.stale.multiplier` (0.3)
  - 180+ days: 0.0 (expired, do not count)

If no signals exist for a contact (common in Phase 1), signal_score = 0.

### Step 3: Compute Role Score

```
role_score = priority_value * decision_maker_multiplier
```

Where:
- `priority_value`: high=3, medium=2, low=1 (from contact's role_category)
- `decision_maker_multiplier`: If `is_decision_maker` is true, multiply by `scoring.weights.decision_maker_bonus` (1.5). Otherwise, multiply by 1.0.

### Step 4: Compute Org Fit Score

```
org_fit_score = organization.fit_score * scoring.weights.org_size_fit_bonus
```

The `org_size_fit_bonus` (1.2) applies when the org falls within the configured size range.

### Step 5: Compute Composite Score

```
composite_score = (signal_score * 0.5) + (role_score * 0.3) + (org_fit_score * 0.2)
```

Apply bonuses:
- `multi_signal_bonus` (1.3x): If the contact has 3+ distinct signal_types

Normalize final score to a 0-100 scale.

### Step 6: Assign Tiers

Sort all contacts by composite_score descending, then assign:
- **HOT**: Top 10% of scored contacts
- **WARM**: Next 20% (10th-30th percentile)
- **COOL**: Next 30% (30th-60th percentile)
- **COLD**: Bottom 40%

If fewer than 10 contacts total, use absolute score thresholds instead:
- HOT: score >= 70
- WARM: score >= 40
- COOL: score >= 20
- COLD: score < 20

### Step 7: Write Results

```sql
INSERT OR REPLACE INTO lead_scores
  (contact_id, vertical_id, composite_score, tier, signal_score, role_score,
   org_fit_score, signal_breakdown_json, scoring_model_version)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'v1')
```

The `signal_breakdown_json` should contain:
```json
{
  "signal_score": 12.5,
  "signal_details": [
    {"type": "TECH_ADOPTION", "intensity": 8, "weight": 2.0, "recency": "hot", "contribution": 48.0}
  ],
  "role_score": 4.5,
  "role_details": {"priority": "high", "is_decision_maker": true},
  "org_fit_score": 0.86,
  "bonuses_applied": ["multi_signal_bonus"],
  "model_version": "v1"
}
```

### Step 8: Report Summary

Present to user:
> **Scoring Results for [vertical_name]:**
> - Total contacts scored: 142
> - HOT: 14 contacts
> - WARM: 29 contacts
> - COOL: 43 contacts
> - COLD: 56 contacts
>
> **Top 10 Leads:**
> 1. Jane Smith, Managing Partner at Baker Law (score: 87, tier: HOT)
>    Signals: TECH_ADOPTION (8/10, 3 days ago), GROWTH (6/10, 12 days ago)
> 2. John Doe, CIO at Thompson & Associates (score: 82, tier: HOT)
>    Role: High-priority decision maker, org fit: 0.92
> ...
