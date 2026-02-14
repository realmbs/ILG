# Skill: Sentiment Classifier

## Purpose

Analyze raw social media signals and classify them per the vertical's signal taxonomy.

## Status: Phase 2

This skill will be fully implemented in Phase 2 when the Reddit MCP, Twitter MCP, and LinkedIn MCP custom servers are built. For Phase 1, the lead-scorer skill operates without sentiment signals (role_score and org_fit_score carry the scoring weight).

## Planned Behavior

### Inputs
- Raw text corpus from social media signals (Reddit posts, tweets, LinkedIn posts)
- `vertical_config.signal_taxonomy` defining signal types, weights, and keywords

### Per-Signal Output
- `signal_type`: One of the types defined in the vertical's taxonomy (NOT hardcoded)
- `polarity`: positive | negative | neutral
- `intensity`: 1-10 scale
- `relevance_score`: 0.0-1.0 (how relevant to the vertical specifically)
- `summary`: One-sentence plain-English summary of the signal
- `entity_mentions`: Organizations or people mentioned that may resolve to DB records

### Processing Rules
- Batch 20-50 signals per API call for cost efficiency
- First-pass filter: keyword/regex match removes obvious noise before spending Claude API tokens
- Use Haiku for pass 1 (relevance filtering), Sonnet for pass 2 (classification)
- The taxonomy comes from `vertical_config.signal_taxonomy` — it auto-adapts when vertical changes
- Cache analysis results with 30-day TTL in `enrichment_cache`
- Track token usage in `api_usage` table

### Entity Resolution
- After classification, attempt to link `entity_mentions` to existing contact/org records in the database
- "The new IT director at Baker McKenzie" should resolve to the correct contact record
- Use fuzzy name matching against organizations and contacts tables
