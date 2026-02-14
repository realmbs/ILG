# Skill: Vertical Adapter

## Purpose

Translate a natural language vertical description into a structured `vertical_config` JSON object that drives the entire ILG pipeline. This is the critical first step — every downstream skill and agent reads from the config this skill produces.

## When to Invoke

- User provides a new vertical description (e.g., "mid-size law firms in Texas doing corporate litigation")
- User modifies an existing vertical config
- User says "create a new vertical for ..."
- Pipeline run is triggered but no matching vertical_config exists

## Input

Natural language text from the user describing their target vertical. May include any combination of:
- Industry / org type (e.g., "law firms", "accounting firms", "SaaS companies")
- Size criteria (e.g., "50-200 attorneys", "mid-size", "under 100 employees")
- Geography (e.g., "in Texas", "Northeast US", "nationwide")
- Practice area / specialty (e.g., "corporate litigation", "tax advisory")
- ICP characteristics (e.g., "with technology decision-makers", "that handle M&A")
- Product context (e.g., "we sell legal tech training software")
- Competitor mentions (e.g., "competing with LegalZoom and Clio")

## Output

A complete `vertical_config` JSON object following this exact schema:

```json
{
  "vertical_id": "<kebab-case-identifier>",
  "vertical_name": "<Human-Readable Name — Geography>",
  "description": "<One-sentence description matching the user's input>",

  "org_discovery": {
    "org_types": ["<primary org type>"],
    "size_filter": { "min_employees": <int>, "max_employees": <int> },
    "geography": { "states": ["<2-letter codes>"], "cities": ["<city names>"] },
    "industry_filters": ["<specific practice areas or specialties>"],
    "discovery_sources": ["<specific directories, rankings, or search sources>"],
    "qualifying_signals": ["<what to look for on org websites that indicates fit>"]
  },

  "contact_targeting": {
    "role_targets": [
      {
        "title_patterns": ["<title 1>", "<title 2>"],
        "priority": "high|medium|low",
        "is_decision_maker": true|false
      }
    ],
    "max_contacts_per_org": 5
  },

  "signal_taxonomy": [
    {
      "type": "<SIGNAL_TYPE_NAME>",
      "weight": <float>,
      "description": "<what this signal type means>",
      "keywords": ["<keyword1>", "<keyword2>"]
    }
  ],

  "social_monitoring": {
    "linkedin_keywords": ["<keyword>"],
    "reddit_subreddits": ["<r/subreddit>"],
    "reddit_keywords": ["<keyword>"],
    "twitter_hashtags": ["<#hashtag>"],
    "twitter_keywords": ["<keyword>"]
  },

  "scoring": {
    "weights": {
      "signal_recency_decay": 0.9,
      "decision_maker_bonus": 1.5,
      "multi_signal_bonus": 1.3,
      "org_size_fit_bonus": 1.2
    },
    "recency_windows": {
      "hot":   { "days": 7,   "multiplier": 3.0 },
      "warm":  { "days": 30,  "multiplier": 1.5 },
      "cool":  { "days": 90,  "multiplier": 1.0 },
      "stale": { "days": 180, "multiplier": 0.3 }
    }
  },

  "competitor_products": ["<product name>"],
  "value_proposition_context": "<what the user sells and why it matters to this vertical>"
}
```

## Behavior Rules

### 1. Clarification Before Generation

If the user's input is ambiguous or missing critical information, ask clarifying questions BEFORE generating the config. Specifically ask about:
- **Geography** if not specified: "Should I target a specific state or region, or nationwide?"
- **Org size** if not specified: "Any size preference, or should I cast a wide net?"
- **Specialty** if the vertical is broad: "Any specific practice area or specialty to focus on?"
- **Product context** if not mentioned: "What product or service are you selling to this vertical? (Optional — helps personalize outreach later)"

Do NOT ask about fields you can intelligently infer (subreddits, role titles, signal keywords).

### 2. Intelligent Defaults

For every field the user does NOT specify, infer the best default based on the vertical:

- **org_types**: Infer from industry (e.g., "law firm" for legal, "CPA firm" for accounting)
- **discovery_sources**: Research and list the 3-5 most authoritative directories or rankings for this specific vertical. Be specific — name the actual directories, not generic placeholders.
- **role_targets**: Think about who buys technology/services in this type of organization. Always include at least one executive-level decision maker and one operational/technology role.
- **signal_taxonomy**: Always include these 7 core types (adjust keywords per vertical): HIRING_INTENT, PAIN_POINT, TECH_ADOPTION, COMPETITIVE, BUDGET, GROWTH, REGULATORY
- **social_monitoring**: Find the actual relevant subreddits (verify they exist and are active), identify industry-specific hashtags, and choose precise LinkedIn keywords.
- **scoring.weights**: Use the defaults shown in the schema unless the vertical has specific characteristics that warrant adjustment (e.g., heavily regulated industries might increase REGULATORY weight).

### 3. Discovery Sources Quality

Discovery sources must be SPECIFIC and CRAWLABLE. Good examples:
- "Martindale-Hubbell directory" (has searchable web interface)
- "Texas State Bar member search" (public search tool)
- "U.S. News Best Law Schools rankings" (structured list)
- "Google Maps business search" (searchable by category + location)

Bad examples (too vague to be actionable):
- "industry databases"
- "professional associations"
- "online directories"

### 4. Signal Taxonomy Keywords

Keywords should be PRECISE for the vertical. The pipeline operates under tight API rate limits, so precision matters more than recall.

For each signal type, provide 4-8 keywords that are specific enough to avoid false positives but common enough to actually appear in social media posts. Include both formal and informal language (e.g., for PAIN_POINT in legal: "frustrated with", "our system is terrible", "legacy software", "manual process").

### 5. Vertical ID Generation

Generate a human-readable, URL-safe `vertical_id` using kebab-case:
- `law-firms-tx-corporate-lit` (good — specific)
- `law-schools-aba-accredited` (good — specific)
- `law-firms` (too generic unless intentionally broad)
- `vertical-1` (bad — not human-readable)

### 6. Storage

After generating the config:
1. Present a brief summary to the user for confirmation:
   - Vertical name
   - Target org types and geography
   - Number of discovery sources
   - Key role targets
   - Estimated API calls for a full pipeline run
2. On user approval, store in the `vertical_configs` table:
   ```sql
   INSERT OR REPLACE INTO vertical_configs (vertical_id, vertical_name, config_json, updated_at)
   VALUES (?, ?, ?, CURRENT_TIMESTAMP)
   ```
3. Also check `config/default-verticals/` for existing configs that match. If one exists, use it as a starting point and merge the user's modifications.

### 7. Existing Config Lookup

Before generating a new config, check if one already exists:
1. Query `vertical_configs` table for matching or similar `vertical_id`
2. Check `config/default-verticals/*.json` for pre-built configs
3. If found, present it to the user: "I found an existing config for [name]. Use it as-is, modify it, or create a new one?"

## Examples

### Example 1: Specific vertical

**Input:** "Mid-size law firms in Texas doing corporate litigation"

**Output summary shown to user:**
> **Vertical: Corporate Litigation Law Firms — Texas**
> - Targeting: Law firms, 50-200 attorneys, in TX
> - Discovery: Martindale-Hubbell, TX State Bar, Chambers, Super Lawyers, Google Maps (5 sources)
> - Roles: Managing Partner, COO, IT Director, CIO, Legal Administrator (3 priority tiers)
> - Signals: 7 types (HIRING_INTENT, PAIN_POINT, TECH_ADOPTION, COMPETITIVE, BUDGET, GROWTH, REGULATORY)
> - Estimated pipeline: ~50 orgs discovered, ~250 contacts, ~500 social signals
> - Estimated API usage: ~20 Playwright crawls, ~100 LinkedIn lookups (2 days), ~200 Reddit queries, ~50 Twitter reads

### Example 2: Vertical with product context

**Input:** "Accounting firms nationwide, we sell audit automation software competing with Caseware and TeamMate"

**Output:** Config with:
- `org_types`: `["accounting firm", "CPA firm", "audit firm"]`
- `discovery_sources`: `["AICPA firm search", "Accounting Today Top 100", "Inside Public Accounting rankings"]`
- `role_targets`: Partner, Managing Partner, Director of Audit, IT Director, Chief Innovation Officer
- `competitor_products`: `["Caseware", "TeamMate"]`
- `value_proposition_context`: `"Audit automation software for accounting firms"`
- `signal_taxonomy` keywords tuned for accounting: "audit efficiency", "workpaper management", etc.
