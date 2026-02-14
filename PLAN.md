# ILG — Intelligent Lead Generator: Project Plan

> Comprehensive architecture, research, and implementation plan.
> Referenced by CLAUDE.md. This is the detailed spec — read relevant sections as needed.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Vertical Adaptation System](#2-vertical-adaptation-system)
3. [Pipeline Architecture](#3-pipeline-architecture)
4. [Skills](#4-skills)
5. [Agents](#5-agents)
6. [MCP Servers](#6-mcp-servers)
7. [Database Schema](#7-database-schema)
8. [n8n Integration Patterns](#8-n8n-integration-patterns)
9. [Sentiment Analysis Architecture](#9-sentiment-analysis-architecture)
10. [Cost Analysis](#10-cost-analysis)
11. [Rate Limits & Safety](#11-rate-limits--safety)
12. [Development Roadmap](#12-development-roadmap)
13. [Risk Analysis](#13-risk-analysis)
14. [Research Notes](#14-research-notes)

---

## 1. Project Overview

ILG is an AI-powered lead generation tool that builds targeted prospect databases enriched
with social media sentiment analysis. It is designed for a single operator running business
development for B2B verticals, starting with legal education and law firms.

### Design Principles

- **Vertical-agnostic from day one.** The entire pipeline is parameterized by a `vertical_config`
  object generated from natural language. Switching from "law schools in Texas" to "accounting
  firms in New York" requires zero code changes.
- **Near-zero operational cost.** Self-hosted open-source tooling, free API tiers, aggressive
  caching. Target: under $5/month total.
- **Claude Code as the intelligence layer.** Not just an API call — full agent capabilities with
  custom skills, MCP server tool use, and multi-step autonomous reasoning.
- **n8n as the orchestration backbone.** Visual workflow builder, self-hosted Community Edition
  (free, unlimited executions), Docker deployment.
- **SaaS extraction without re-architecture.** Single-tenant SQLite now, PostgreSQL + multi-tenant
  later. Clean separation of concerns enables future productization.

### Architecture Layers

| Layer          | Technology                          | Role                                                    |
|----------------|-------------------------------------|---------------------------------------------------------|
| Orchestration  | n8n (self-hosted Docker)            | Workflow execution, scheduling, triggers                |
| Intelligence   | Claude Code + skills + agents       | Analysis, classification, scoring, content generation   |
| Data Bridge    | MCP servers (community + custom)    | LinkedIn, Reddit, Twitter, web scraping, DB, Sheets     |
| Storage        | SQLite (MVP) / PostgreSQL (scale)   | Org DB, contacts, signals, scores, cache, audit         |
| Output         | Export adapters                     | Google Sheets API, CSV, future CRM webhooks             |

---

## 2. Vertical Adaptation System

This is the core architectural innovation. Every pipeline stage consumes a `vertical_config`
object. Nothing downstream is hardcoded to any industry.

### Flow

1. User provides natural language input: `"Mid-size law firms (50-200 attorneys) in Texas handling corporate litigation"`
2. The `vertical-adapter` skill parses this into a structured config
3. Config is stored in `vertical_configs` table (cached for repeat runs)
4. All downstream skills and agents read from this config

### vertical_config Schema

```json
{
  "vertical_id": "law-firms-tx-corporate-lit",
  "vertical_name": "Corporate Litigation Law Firms — Texas",
  "description": "Mid-size law firms with 50-200 attorneys handling corporate litigation in Texas",

  "org_discovery": {
    "org_types": ["law firm"],
    "size_filter": { "min_employees": 50, "max_employees": 200 },
    "geography": { "states": ["TX"], "cities": [] },
    "industry_filters": ["corporate litigation", "commercial litigation", "business disputes"],
    "discovery_sources": [
      "Martindale-Hubbell directory",
      "Texas State Bar member search",
      "Chambers and Partners rankings",
      "Google Maps business search"
    ],
    "qualifying_signals": [
      "practice area pages mentioning litigation technology",
      "recent case volume indicators"
    ]
  },

  "contact_targeting": {
    "role_targets": [
      {
        "title_patterns": ["Managing Partner", "COO", "Director of Operations"],
        "priority": "high",
        "is_decision_maker": true
      },
      {
        "title_patterns": ["IT Director", "CIO", "Director of Technology", "Innovation Officer"],
        "priority": "high",
        "is_decision_maker": true
      },
      {
        "title_patterns": ["Legal Administrator", "Office Manager"],
        "priority": "medium",
        "is_decision_maker": false
      }
    ],
    "max_contacts_per_org": 5
  },

  "signal_taxonomy": [
    {
      "type": "HIRING_INTENT",
      "weight": 1.5,
      "description": "Job postings for tech, operations, or innovation roles",
      "keywords": ["hiring", "job opening", "now hiring", "seeking candidates"]
    },
    {
      "type": "PAIN_POINT",
      "weight": 1.5,
      "description": "Expressed frustration with tools, processes, or inefficiencies",
      "keywords": ["frustrated", "struggling", "outdated", "inefficient"]
    },
    {
      "type": "TECH_ADOPTION",
      "weight": 2.0,
      "description": "Evaluating, adopting, or migrating technology platforms",
      "keywords": ["implementing", "evaluating", "migrating to", "piloting", "AI tools"]
    },
    {
      "type": "COMPETITIVE",
      "weight": 1.5,
      "description": "Mentions of competitor products or alternative solutions",
      "keywords": []
    },
    {
      "type": "BUDGET",
      "weight": 2.0,
      "description": "Budget discussions, funding, or investment signals",
      "keywords": ["budget", "investment", "modernization", "digital transformation"]
    },
    {
      "type": "GROWTH",
      "weight": 1.8,
      "description": "Expansion, new offices, mergers, practice area growth",
      "keywords": ["expansion", "new office", "merger", "growing practice"]
    },
    {
      "type": "REGULATORY",
      "weight": 1.0,
      "description": "Response to regulatory changes affecting operations or tech",
      "keywords": []
    }
  ],

  "social_monitoring": {
    "linkedin_keywords": ["legal technology", "litigation management", "ediscovery", "legal ops"],
    "reddit_subreddits": ["r/law", "r/lawyers", "r/LegalTech", "r/biglaw"],
    "reddit_keywords": ["law firm software", "case management", "practice management"],
    "twitter_hashtags": ["#LegalTech", "#LegalOps", "#LawFirm"],
    "twitter_keywords": ["law firm technology", "legal innovation"]
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

  "competitor_products": [],
  "value_proposition_context": ""
}
```

### Default Verticals (pre-built in `config/default-verticals/`)

| File                        | Vertical                                     | Status     |
|-----------------------------|----------------------------------------------|------------|
| `law-firms-corporate.json`  | Corporate litigation law firms               | Primary    |
| `law-schools.json`          | ABA-accredited law schools                   | Active     |
| `paralegal-programs.json`   | Paralegal/legal assistant training programs  | Active     |
| `law-firms-general.json`    | All-practice law firms (broad net)           | Template   |

When the user says "run for law firms" or similar shorthand, load the matching config from
`vertical_configs` table first, then fall back to `config/default-verticals/`.

---

## 3. Pipeline Architecture

Five stages, each implemented as an n8n workflow. Stages can run independently or chained
via the `00-full-pipeline.json` master workflow. All stages are user-triggered batch operations.

### Stage 1: Org Discovery

- **Input:** `vertical_config.org_discovery`
- **Process:** Playwright MCP crawls discovery sources (directories, bar associations, rankings sites, Google Maps). Claude Code org-discoverer skill extracts structured org records.
- **Output:** Rows in `organizations` table (name, website, location, size, fit_score)
- **Review gate:** Agent presents summary for user approval before DB commit

### Stage 2: Contact Extraction

- **Input:** Un-enriched `organizations` records + `vertical_config.contact_targeting`
- **Process:** Playwright MCP crawls org websites for team/about/people pages. LinkedIn MCP or Proxycurl enriches profiles. Matches titles against role_targets.
- **Output:** Rows in `contacts` table linked to orgs
- **Rate limits:** Max 50 LinkedIn lookups/day, 2-5s delays between web requests

### Stage 3: Signal Collection

- **Input:** `vertical_config.social_monitoring` keyword sets and subreddit lists
- **Process:** Reddit MCP searches configured subreddits. Twitter MCP searches keywords/hashtags. LinkedIn MCP collects recent post activity from identified contacts.
- **Output:** Raw rows in `signals` table (source_platform, raw_text, captured_at)
- **Rate limits:** Reddit 30 req/min throttle, Twitter hard stop at 1,400/month

### Stage 4: Sentiment Analysis

- **Input:** Unanalyzed `signals` rows + `vertical_config.signal_taxonomy`
- **Process:** Two-pass analysis. Pass 1: cheap keyword/regex filter removes obvious noise. Pass 2: Claude API (batches of 20-50 signals per call) classifies each signal by type, polarity, intensity, relevance. Entity resolution links signals to contacts/orgs.
- **Output:** Updated `signals` rows with analysis fields populated
- **Cost control:** Batching, caching (30-day TTL), Haiku for pass 1, Sonnet for pass 2

### Stage 5: Scoring & Export

- **Input:** All contacts with associated signals + `vertical_config.scoring`
- **Process:** Composite score = weighted sum of (signal_intensity * type_weight * recency_multiplier) + role_score + org_fit_score. Multi-signal bonus applied for 3+ signal types. Tier assignment: HOT (top 10%), WARM (next 20%), COOL (next 30%), COLD (bottom 40%).
- **Output:** `lead_scores` table rows + Google Sheets/CSV export
- **Export:** Strips raw text, exports only summaries, scores, contact info, and reasoning

---

## 3.5 Lessons Learned: First E2E Test (2026-02-14)

The first end-to-end pipeline test ("corporate litigation law firms in Texas") validated the core architecture but exposed critical operational issues. 10 orgs discovered, 50 contacts extracted (5 per firm) across Org Discovery and Contact Extraction stages.

### Key Findings

**1. Context Window Management is Critical**
- Processing 10 firms sequentially exhausted Claude's context window mid-extraction, requiring a session restart
- Each Playwright `browser_snapshot` generates large accessibility tree outputs that accumulate rapidly
- **Solution**: Batch processing (5 orgs at a time), incremental DB commits after each batch, prefer `browser_run_code` over click-by-click

**2. Playwright `browser_run_code` is 5-10x More Efficient**
- Click-by-click navigation: 5-10 turns per firm, massive context consumption from snapshot outputs
- `browser_run_code`: 1-2 turns per firm, returns only extracted data
- **Pattern**: Use `run_code` as default for data extraction; reserve click-by-click for search form interaction or when nav structure needs reading

**3. Cookie Popups Block Automation**
- ~60% of crawled sites had cookie consent banners intercepting pointer events
- Not accounted for in original skill designs
- **Solution**: Proactive popup dismissal as first step when visiting any page (non-blocking, continue if not found)

**4. People Page URLs Have No Standard**
- Tested: `/people`, `/professionals`, `/attorneys`, `/our-attorneys`, `/our-people`, `/lawyers`, `/team`, `/leadership`
- Many first attempts returned 404s, wasting turns and context
- **Solution**: Check nav menu + footer first (most reliable), then try URL patterns, fallback to sitemap.xml

**5. Email Addresses Often Missing**
- 4/10 firms (40%) had no individual emails on public team pages
- Original skill had no guidance on fallback or tracking
- **Solution**: Add `email_status` column to contacts table to distinguish "not found" from "not yet checked"

**6. Phase 1 Scoring Formula Needed Rebalancing**
- Original: `(signal * 0.5) + (role * 0.3) + (org_fit * 0.2)` — but signal_score is always 0 in Phase 1
- 50% of formula produced zeros, compressing effective score variance
- **Solution**: Phase-aware weighting — use `(role * 0.6) + (org_fit * 0.4)` when no signals exist

**7. Database Lacked Processing State Tracking**
- No `processing_status` on organizations — couldn't distinguish "not yet enriched" from "enrichment failed"
- Session interruptions required manual DB inspection to determine restart point
- **Solution**: Migration 001 adding `processing_status`, `enrichment_attempted_at`, `email_status` columns

### Changes Implemented

| Change | Files |
|--------|-------|
| Playwright `run_code` preference + cookie handling | `org-discoverer.md`, `contact-extractor.md` |
| Batch processing (5 orgs/batch) with incremental commits | `contact-extractor.md` |
| Phase 1 scoring weight override | `lead-scorer.md` |
| Processing status tracking columns | `schema.sql`, migration `001` |
| URL discovery strategy (nav → patterns → sitemap) | `contact-extractor.md` |
| Email status tracking | `schema.sql`, `contact-extractor.md` |

### Validation Status

| Stage | Status | Notes |
|-------|--------|-------|
| Org Discovery | Validated | 10 law firms discovered from web sources |
| Contact Extraction | Validated | 50 contacts across 10 firms, 30 with emails |
| Lead Scoring | Formula updated | Phase 1 weights ready, not yet run on test data |
| Signal Collection | Not tested | Phase 2 |
| Sentiment Analysis | Not tested | Phase 2 |

---

## 4. Skills

Skills are markdown instruction files in `claude-skills/`. Each defines what Claude should do
for a specific task. Skills are loaded as context when invoked.

### vertical-adapter

**File:** `claude-skills/vertical-adapter.md`

Translates natural language vertical descriptions into structured `vertical_config` objects.

Responsibilities:
- Parse user input for: industry, org type, size, geography, ICP characteristics
- Generate complete config following the schema in Section 2
- For unspecified fields, infer intelligent defaults based on the vertical
- If input is ambiguous, ask clarifying questions BEFORE generating
- Store config in `vertical_configs` table with human-readable `vertical_id`

### org-discoverer

**File:** `claude-skills/org-discoverer.md`

Discovers organizations matching the vertical config.

Responsibilities:
- Use Playwright MCP to crawl discovery sources in `vertical_config.org_discovery.discovery_sources`
- Extract: name, website, location, size indicators, practice areas / program types
- Deduplicate against existing `organizations` table
- Assign initial `fit_score` based on config filter match quality
- Return summary: orgs found, new, updated

### contact-extractor

**File:** `claude-skills/contact-extractor.md`

Finds and profiles contacts at discovered organizations.

Responsibilities:
- Crawl org websites for team/people pages via Playwright MCP
- Match names/titles against `vertical_config.contact_targeting.role_targets`
- Enrich with LinkedIn data (Proxycurl free tier or LinkedIn MCP)
- Flag `is_decision_maker` per config role definitions
- Respect `max_contacts_per_org`
- Skip orgs already enriched within cache TTL (30 days)

### sentiment-classifier

**File:** `claude-skills/sentiment-classifier.md`

Classifies raw social signals per the vertical's signal taxonomy.

Per-signal output:
- `signal_type`: From `vertical_config.signal_taxonomy` (NOT hardcoded)
- `polarity`: positive | negative | neutral
- `intensity`: 1-10
- `relevance_score`: 0.0-1.0
- `summary`: One-sentence plain English
- `entity_mentions`: Orgs/people that may resolve to DB records

Processing rules:
- Batch 20-50 signals per API call
- First-pass filter: skip signals with zero vertical relevance
- The taxonomy comes from the config — it auto-adapts when vertical changes

### lead-scorer

**File:** `claude-skills/lead-scorer.md`

Computes composite lead scores from enrichment data.

Per-contact computation:
- `signal_score` = SUM(intensity * type_weight * recency_multiplier) for all signals
- `role_score` = priority level (high=3, medium=2, low=1) * decision_maker_bonus
- `org_fit_score` = from org's fit_score
- `composite_score` = weighted combination
- Apply `multi_signal_bonus` when 3+ distinct signal types present
- Assign tier: HOT / WARM / COOL / COLD
- Write `signal_breakdown_json` for explainability

### outreach-drafter

**File:** `claude-skills/outreach-drafter.md`

Generates personalized outreach messages from lead intelligence.

Rules:
- Reference highest-intensity signals as personalization hooks
- Match tone to role level (executive = concise/strategic, practitioner = tactical)
- If `value_proposition_context` is populated, weave naturally
- Generate both email and LinkedIn connection request variants
- Never fabricate signals or information not in the data
- Output to `outreach_log` as drafts (status: "draft")

---

## 5. Agents

Agents are YAML configs in `claude-agents/` defining which skills and MCP servers to use,
autonomy level, and review checkpoints.

### org-discovery-agent

| Field       | Value                                                          |
|-------------|----------------------------------------------------------------|
| MCP Servers | Playwright, File System, PostgreSQL                            |
| Skills      | vertical-adapter, org-discoverer                               |
| Autonomy    | Semi-autonomous (pauses for review before DB commit)           |

Workflow:
1. Accept vertical description (or load existing config)
2. If new: invoke vertical-adapter to generate config
3. Invoke org-discoverer
4. Present summary for user review
5. On approval, commit to database

### enrichment-agent

| Field       | Value                                                          |
|-------------|----------------------------------------------------------------|
| MCP Servers | Playwright, LinkedIn MCP, PostgreSQL, File System              |
| Skills      | contact-extractor                                              |
| Autonomy    | Autonomous within rate limits                                  |

Workflow:
1. Load un-enriched orgs from DB
2. For each org, invoke contact-extractor
3. Enforce rate limits: 50 LinkedIn/day, 2-5s web delays
4. Log all activity for audit
5. Report summary on completion

### sentiment-agent

| Field       | Value                                                          |
|-------------|----------------------------------------------------------------|
| MCP Servers | Reddit MCP, Twitter MCP, LinkedIn MCP, PostgreSQL, File System |
| Skills      | sentiment-classifier                                           |
| Autonomy    | Autonomous                                                     |

Workflow:
1. Load `vertical_config.social_monitoring` for keywords and subreddits
2. Collect raw signals via Reddit, Twitter, LinkedIn MCPs
3. Store raw signals in `signals` table
4. Batch and invoke sentiment-classifier
5. Write classified results back
6. Resolve entity mentions to existing DB records

### scoring-agent

| Field       | Value                                                          |
|-------------|----------------------------------------------------------------|
| MCP Servers | PostgreSQL, Google Sheets MCP, File System                     |
| Skills      | lead-scorer                                                    |
| Autonomy    | Autonomous                                                     |

Workflow:
1. Load all contacts with associated signals for the vertical
2. Invoke lead-scorer
3. Write to `lead_scores` table
4. Export to Google Sheets and/or CSV
5. Report: total scored, tier distribution, top 10 leads with reasoning

---

## 6. MCP Servers

### Community Servers (install via AITMPL)

```bash
npx claude-code-templates@latest
# Select: Playwright, PostgreSQL, File System, Sequential Thinking, Google Sheets
```

| Server              | Purpose                                           |
|---------------------|---------------------------------------------------|
| Playwright MCP      | Web scraping with accessibility tree navigation   |
| PostgreSQL MCP      | Direct DB queries (production/SaaS phase)         |
| File System MCP     | Local file read/write for batch processing        |
| Sequential Thinking | Multi-step reasoning for complex analysis         |
| Google Sheets MCP   | Direct export to Google Sheets                    |

### Custom Servers (build in `mcp-servers/`)

#### reddit-mcp (`mcp-servers/reddit-mcp/`)

- **Language:** TypeScript (Node.js)
- **API:** Reddit REST API, OAuth2 "script" app type, free personal tier (100 req/min)
- **Auth:** Client ID + secret in `.env`. Register at https://www.reddit.com/prefs/apps
- **Tools:**
  - `search_subreddit(subreddit, query, time_filter, limit)` — Search posts in a subreddit
  - `get_subreddit_posts(subreddit, sort, time_filter, limit)` — Recent posts
  - `search_all(query, subreddits[], time_filter, limit)` — Cross-subreddit search
  - `get_comments(post_id, limit)` — Post comments

#### twitter-mcp (`mcp-servers/twitter-mcp/`)

- **Language:** TypeScript (Node.js)
- **API:** Twitter/X API v2, free tier (1,500 reads/month)
- **Auth:** Bearer token in `.env`. Apply at https://developer.x.com/en/portal/dashboard
- **Tools:**
  - `search_recent(query, max_results)` — Keyword/hashtag search
  - `get_user_tweets(username, max_results)` — User timeline
  - `search_with_context(query, max_results)` — Search with author/metrics context
- **Critical:** Track usage against 1,500/month ceiling via `api_usage` table. Hard stop at 1,400.

#### linkedin-mcp (`mcp-servers/linkedin-mcp/`)

- **Language:** TypeScript (Node.js)
- **API:** Proxycurl free tier (~50 lookups/day). Fallback: open-source scraper with aggressive rate limiting.
- **Auth:** Proxycurl API key in `.env`. Fallback uses session cookie (higher risk).
- **Tools:**
  - `get_profile(linkedin_url)` — Structured profile data
  - `get_company(linkedin_url)` — Company page data
  - `search_people(keywords, location, current_company)` — People search (limited)
- **Safety:** 30-120 second randomized delays. Daily hard stop at 45 lookups.

---

## 7. Database Schema

SQLite at `db/ilg.db` for MVP. All tables include audit columns. Full SQL in `db/schema.sql`.

### Tables

| Table              | Purpose                                              | Key Fields                                                              |
|--------------------|------------------------------------------------------|-------------------------------------------------------------------------|
| `vertical_configs` | Cached vertical definitions                          | vertical_id (unique), vertical_name, config_json                        |
| `organizations`    | Discovered orgs                                      | vertical_id, name, website, state, city, fit_score, discovery_source    |
| `contacts`         | People at orgs                                       | org_id, name, title, email, linkedin_url, role_category, is_decision_maker |
| `signals`          | Raw + analyzed social signals                        | contact_id, org_id, vertical_id, source_platform, raw_text, signal_type, polarity, intensity, relevance_score |
| `lead_scores`      | Composite scores with explainability                 | contact_id, vertical_id, composite_score, tier, signal_breakdown_json   |
| `enrichment_cache` | Prevents redundant API calls                         | entity_type, entity_id, cache_key, data_json, expires_at               |
| `outreach_log`     | Draft/sent message tracking                          | contact_id, vertical_id, channel, message_draft, status                 |
| `api_usage`        | Rate limit tracking for free tier budgets            | platform, endpoint, tokens_used, requests_made, cost_estimate_usd      |

### Key Indexes

- `idx_orgs_vertical` on organizations(vertical_id)
- `idx_contacts_org` on contacts(org_id)
- `idx_signals_contact` on signals(contact_id)
- `idx_signals_type` on signals(signal_type)
- `idx_lead_scores_tier` on lead_scores(tier)
- `idx_cache_lookup` on enrichment_cache(entity_type, entity_id, cache_key)
- `idx_api_usage_platform` on api_usage(platform, recorded_at)

---

## 8. n8n Integration Patterns

Two patterns for connecting n8n (orchestration) to Claude Code (intelligence):

### Pattern A: n8n calls Claude API directly

For stateless tasks: sentiment classification, lead scoring, outreach drafting, data cleaning.
Use n8n's HTTP Request node or native AI node to call the Anthropic API.

### Pattern B: n8n triggers Claude Code agent via CLI

For multi-step tasks requiring tool use: org discovery, deep enrichment, research.
n8n executes a shell command that launches a Claude Code session with the appropriate agent config.

### Master Workflow (`00-full-pipeline.json`)

1. User triggers manually (or on schedule)
2. n8n calls Claude Code org-discovery-agent (Pattern B) with target params
3. Agent uses Playwright MCP to crawl sources, builds org records in SQLite
4. n8n iterates over new orgs, triggers enrichment-agent (Pattern B) for each
5. Enrichment-agent uses LinkedIn MCP + Playwright MCP to find/profile contacts
6. n8n triggers signal collection (Pattern A/B) via Reddit + Twitter + LinkedIn MCPs
7. n8n sends batched raw signals to Claude API (Pattern A) for sentiment analysis
8. n8n calls lead-scorer via Claude API (Pattern A) for composite scoring
9. n8n exports scored leads to Google Sheets via Google Sheets MCP or API

### n8n Deployment

| Option                    | Cost        | Recommendation                              |
|---------------------------|-------------|---------------------------------------------|
| Local Docker              | $0          | Start here. Fast iteration, zero cost.      |
| AWS Free Tier EC2         | $0 (12 mo)  | Graduate here when you need always-on.      |
| AWS EC2 post-free-tier    | ~$8/mo      | Long-term. Familiar stack.                  |

```bash
# Local Docker start
docker run -it --rm --name n8n -p 5678:5678 -v n8n_data:/home/node/.n8n n8nio/n8n
```

---

## 9. Sentiment Analysis Architecture

### Multi-Platform Signal Sources

**LinkedIn** (highest value for B2B):
- Profile data: role, tenure, skills (via Proxycurl / LinkedIn MCP)
- Post activity: recent posts and articles by decision-makers
- Engagement: content they like/comment/share (indicates current interests)
- Rate: max 50 profile lookups/day, 30-120s randomized delays

**Reddit** (candid, unfiltered discussion):
- Target subreddits: configured per vertical in `social_monitoring.reddit_subreddits`
- Keyword monitoring: configured in `social_monitoring.reddit_keywords`
- API: free personal tier, 100 req/min (throttle to 30/min)

**Twitter/X** (real-time reactions, institutional announcements):
- Hashtag + keyword monitoring from `social_monitoring.twitter_*`
- API: free tier, 1,500 reads/month (hard stop at 1,400)
- Prioritize keyword precision over breadth given the tight ceiling

### Analysis Pipeline

1. **Relevance filter** (cheap, local): Keyword/regex match against vertical's taxonomy keywords. Discard obvious noise before spending Claude API tokens.
2. **Classification** (Claude API, batched): Type, polarity, intensity, relevance per the vertical's signal taxonomy. Taxonomy is NOT hardcoded — it comes from `vertical_config`.
3. **Entity resolution** (Claude API or local): Link signals to existing contacts/orgs in DB. "The new IT director at Baker McKenzie" should resolve to the correct record.

### Cost Control

- Batch 20-50 signals per API call (structured JSON prompt)
- Use Haiku for pass 1 (relevance filtering), Sonnet for pass 2 (classification)
- Cache analysis results with 30-day TTL in `enrichment_cache`
- Track token usage in `api_usage` table with hard budget cap at $5/month
- Expected: $1-3/month for Anthropic API at MVP scale (500-1000 orgs)

---

## 10. Cost Analysis

| Component       | Service                              | Monthly Cost | Notes                                    |
|-----------------|--------------------------------------|-------------|------------------------------------------|
| Orchestration   | n8n Community (Docker)               | $0          | Unlimited executions                     |
| Intelligence    | Anthropic API (Haiku + Sonnet)       | $1-3        | Batched, ~50-100K tokens/month           |
| LinkedIn data   | Proxycurl free tier                  | $0          | ~50 lookups/day                          |
| Reddit data     | Reddit API free tier                 | $0          | 100 req/min                              |
| Twitter data    | Twitter/X API free tier              | $0          | 1,500 reads/month                        |
| Database        | SQLite (local file)                  | $0          | Zero infra                               |
| Compute         | Local / AWS Free Tier                | $0-8        | Free 12 months, ~$8 after               |
| Google Sheets   | Google Sheets API free tier          | $0          | Generous personal quota                  |
| **Total**       |                                      | **$1-5**    |                                          |

---

## 11. Rate Limits & Safety

### API Budget Enforcement (via `api_usage` table)

| Platform    | Limit                 | Enforcement                           |
|-------------|-----------------------|---------------------------------------|
| Twitter/X   | 1,500 reads/month     | Hard stop at 1,400. Warn at 1,000.   |
| Reddit      | 100 req/min           | Throttle to 30/min.                   |
| LinkedIn    | ~50 lookups/day       | Hard stop at 45. 8-hour spread.       |
| Anthropic   | $5/month budget       | Track tokens per call. Alert at $3.   |

### Scraping Safety Rules

- Randomized delays: 2-8 seconds (web), 30-120 seconds (LinkedIn)
- User-Agent rotation on Playwright requests
- Never scrape behind authentication walls
- Never store non-public data
- Respect robots.txt
- Separate scraping account from personal LinkedIn (if doing LinkedIn scraping)

### Data Handling

- All PII stored locally only (SQLite file)
- No PII in Claude API prompts when avoidable
- Google Sheets export strips raw text, shows only summaries and scores
- Enrichment cache auto-expires (30-day TTL)

### Compliance Notes

- LinkedIn ToS: direct scraping violates terms. Use official APIs (Proxycurl) where possible. Rate limit aggressively. Accept the risk for open-source scraper fallback.
- GDPR: applies to EU-based contacts regardless of operator location. Minimize PII storage, implement deletion capability.
- CCPA: applies to California contacts. Same mitigations as GDPR.

---

## 12. Development Roadmap

### Phase 1: Foundation MVP (Weeks 1-3)

**Goal:** Working local pipeline from vertical input to scored leads in CSV.

Tasks:
1. ~~Scaffold project structure per CLAUDE.md~~ **DONE**
2. ~~Initialize SQLite with schema from Section 7~~ **DONE** (8 tables, 10 indexes)
3. ~~Build `vertical-adapter` skill~~ **DONE** (`claude-skills/vertical-adapter.md`)
4. ~~Build `org-discoverer` skill + org-discovery-agent~~ **DONE** (skill + YAML config)
5. ~~Implement Playwright MCP web scraping for directory crawling~~ **DONE** (validated with 10 law firms, 2026-02-14)
6. ~~Build `lead-scorer` skill~~ **DONE** (`claude-skills/lead-scorer.md`, Phase 1 weight override added)
7. ~~Build `contact-extractor` skill~~ **DONE** (`claude-skills/contact-extractor.md`, batch processing + `run_code` patterns added)
8. ~~CSV export workflow~~ **DONE** (`scripts/export-leads.py`); Google Sheets deferred to Phase 1b
9. ~~Create default vertical configs for law firms and law schools~~ **DONE** (3 configs seeded)
10. ~~Test end-to-end: "law firms in Texas" → contacts extracted~~ **DONE** (10 orgs, 50 contacts, 2026-02-14)
11. ~~Update skills with E2E test learnings~~ **DONE** (Playwright efficiency, cookie handling, batch processing, Phase 1 scoring)
12. ~~DB migration 001: processing status tracking~~ **DONE** (`db/migrations/001-add-processing-status.sql`)
13. Run lead scoring on test data and export to CSV — **NEXT**
14. Second E2E test with batch processing to validate context management — **NEXT**

**Deliverable:** Manually triggered pipeline that produces a scored lead list within 15 minutes. **STATUS: Org discovery + contact extraction validated. Scoring and export pending.**

### Phase 2: Sentiment Layer (Weeks 4-6)

**Goal:** Social media sentiment analysis dramatically improves lead quality.

Tasks:
1. Build `reddit-mcp` custom MCP server
2. Build `twitter-mcp` custom MCP server
3. Build `sentiment-classifier` skill with vertical-aware taxonomy
4. Implement LinkedIn signal collection (Proxycurl + optional scraping)
5. Build enrichment-agent and sentiment-agent
6. Upgrade lead-scorer to use sentiment-weighted composite scoring
7. Implement `api_usage` tracking with hard stops

**Deliverable:** Lead lists include intelligence like "This managing partner posted about litigation management frustrations 3 days ago."

### Phase 3: Automation & Polish (Weeks 7-9)

**Goal:** Reduce manual effort, prepare for scaling.

Tasks:
1. Scheduled batch runs in n8n (weekly org refresh, daily signals)
2. Build `outreach-drafter` skill
3. Enrichment caching with TTL
4. Simple dashboard for reviewing scored leads
5. Deploy n8n to AWS EC2
6. Data deduplication and contact merge logic

### Phase 4: SaaS Preparation (Weeks 10+)

**Goal:** Extract into multi-vertical, multi-user product.

Tasks:
1. Migrate SQLite to PostgreSQL
2. Build Next.js/React web frontend
3. User auth + tenant isolation
4. Vertical configuration UI
5. Billing integration (Stripe, usage-based)
6. Package custom MCP servers for distribution

---

## 13. Risk Analysis

| Risk                                        | Severity | Likelihood | Mitigation                                                                                          |
|---------------------------------------------|----------|------------|------------------------------------------------------------------------------------------------------|
| LinkedIn account ban from scraping           | High     | Medium     | Official APIs first, rate limiting, dedicated scraping account, human-behavior delays                |
| Twitter/X free tier quota exhaustion         | Medium   | High       | Precise keywords, caching, prioritize LinkedIn + Reddit                                             |
| Claude API cost spike from bad prompts       | Medium   | Medium     | Batching, two-pass filter, token monitoring, hard $5 cap                                            |
| Stale data (wrong contacts, old roles)       | Medium   | High       | Cache TTL, periodic re-verification, confidence scoring                                             |
| Scope creep delaying MVP                     | High     | High       | Strict phase gating. Phase 1 must work before Phase 2 starts.                                      |
| Reddit/Twitter API terms change              | Medium   | Low        | MCP server abstraction makes platform logic swappable                                               |
| Vertical config doesn't generalize well      | Medium   | Medium     | Test with 3+ verticals in Phase 1. Fix schema gaps early.                                          |

---

## 14. Research Notes

### AITMPL.com (Claude Code Templates)

Open-source repo of pre-built Claude Code configurations: skills, agents, commands, settings,
hooks, MCP server configs. Provides a Stack Builder that composes components into a single
`npx` install command. Relevant for installing community MCP servers (Playwright, PostgreSQL,
File System, Sequential Thinking). Also useful as a reference for structuring custom skills
and agents. MIT licensed. GitHub: `davila7/claude-code-templates`.

### n8n (Self-Hosted)

Community Edition is free with unlimited executions, workflows, and integrations under a
fair-code license. Self-hosted on Docker or any Linux server. Cloud plans start at
EUR 24/month but are unnecessary for this project. The execution-based billing model (vs
per-task like Zapier) means complex multi-step workflows are cheap. 529+ lead generation
workflow templates exist in the n8n community library as reference implementations.
Native AI nodes support Anthropic Claude for direct API integration.

### LinkedIn Scraping Landscape

Direct scraping violates LinkedIn ToS. Safe approaches ranked by risk:
1. **Proxycurl** (free tier ~50/day) — REST API, structured JSON, lowest risk
2. **LinkedIn MCP** (community) — Wraps official or semi-official access
3. **Open-source scrapers** (e.g., `joeyism/linkedin_scraper`) — Selenium/Puppeteer based, moderate risk with proper rate limiting
4. **Browser extensions** (Evaboot, Dripify, etc.) — Paid, use session cookies, moderate risk
5. **Direct scraping** (custom Playwright) — Highest risk, requires aggressive anti-detection

Recommendation: Proxycurl free tier as primary, open-source scraper as fallback with
30-120 second delays and dedicated account.

### Reddit API

Free for personal/non-commercial use under OAuth2 "script" app type. 100 requests/minute
limit is generous. PRAW (Python) and snoowrap (JavaScript) are mature wrapper libraries.
No read limits beyond rate throttling. Best free data source for candid B2B discussion.

### Twitter/X API

Free tier: 1,500 tweet reads/month via v2 API. Adequate for targeted vertical monitoring
but requires precise keyword selection. No streaming on free tier — polling only.
The 1,500 ceiling is the tightest constraint in the system.

### Sentiment Analysis Approaches

Using Claude as the analysis engine (vs. dedicated NLP services) is the correct choice for
this project because: (a) domain-specific prompting produces richer output than generic
sentiment APIs, (b) the signal taxonomy is configurable per vertical which generic APIs
cannot accommodate, (c) cost at MVP scale ($1-3/month) is lower than most paid services,
and (d) it eliminates an additional external dependency.

### Claude Code Best Practices Applied

This project follows established CLAUDE.md patterns:
- **Concise root CLAUDE.md** (~100 lines) with WHAT/WHY/HOW and pointers to detailed docs
- **Progressive disclosure** via PLAN.md, `claude-skills/*.md`, and `docs/`
- **Specific commands** over vague instructions
- **Document what Claude gets wrong** (Gotchas section) rather than comprehensive manual
- **Sub-directory CLAUDE.md files** can be added to `mcp-servers/` or `claude-skills/` as complexity grows