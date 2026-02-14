# Skill: Outreach Drafter

## Purpose

Generate personalized outreach messages based on lead intelligence.

## Status: Phase 3

This skill will be implemented in Phase 3. For Phase 1 and 2, the scored lead list exported as CSV serves as the output, and outreach is manual.

## Planned Behavior

### Inputs
- Scored lead record with associated signals
- `vertical_config.value_proposition_context`

### Rules
- Reference the highest-intensity signals as personalization hooks
- Match tone to the contact's role level:
  - Executive (Managing Partner, COO, CIO): concise, strategic framing
  - Practitioner (IT Director, Legal Administrator): tactical, specific details
  - Junior (Associate, Of Counsel): informational, lighter ask
- If `value_proposition_context` is populated, weave it naturally into the message
- Generate both email and LinkedIn connection request variants
- Never fabricate signals or information not present in the data
- Output to `outreach_log` table as drafts (status: "draft")

### Output Format
For each lead, generate:
1. **Email draft**: Subject line + body (3-4 paragraphs max)
2. **LinkedIn connection request**: 300-character personalized note
3. **Talking points**: 3-5 bullet points for a phone call or in-person meeting
