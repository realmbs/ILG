# ILG — Intelligent Lead Generator

AI-powered vertical B2B lead generation with social media sentiment analysis.
Built for a single operator. Adapts to any vertical via natural language input.

## Current Status

**Phase 1 MVP — first E2E test complete, skills optimized based on real-world results.**

What's done:
- Project structure scaffolded (all directories, configs, scripts)
- SQLite database initialized (8 tables, 11 indexes) at `db/ilg.db`
- 3 default vertical configs seeded (law-firms-corporate, law-schools, law-firms-general)
- 4 Claude skills written and tested (vertical-adapter, org-discoverer, contact-extractor, lead-scorer)
- 2 skill stubs for Phase 2/3 (sentiment-classifier, outreach-drafter)
- 4 agent YAML configs defined
- 3 custom MCP server stubs (reddit, twitter, linkedin — Phase 2)
- Docker Desktop installed, n8n configured via docker-compose.yml
- MCP servers configured: Playwright, Filesystem, Sequential Thinking
- **First E2E test completed (2026-02-14):** 10 law firms discovered, 50 contacts extracted
- **Skills updated with E2E learnings:** `browser_run_code` patterns, cookie handling, batch processing, Phase 1 scoring weights
- **DB migration 001 created:** processing status tracking for orgs and contacts

What's next:
- Run DB migration 001 on existing database
- Run lead scoring on extracted contacts and export to CSV
- Second E2E test with optimized batch processing to validate context management
- Test with a different vertical (e.g., law schools) to validate vertical-agnostic design

## Stack

- **Orchestration:** n8n (self-hosted Community Edition, Docker)
- **Intelligence:** Claude Code + custom skills/agents
- **Data Bridge:** MCP servers (Playwright, Filesystem, Sequential Thinking active; Reddit, Twitter, LinkedIn stubs for Phase 2)
- **Storage:** SQLite at `db/ilg.db` (PostgreSQL migration path for SaaS phase)
- **Language:** TypeScript for MCP servers, Python for utility scripts
- **Export:** CSV (Google Sheets deferred to Phase 1b)

## Project Structure

```
ILG/
├── CLAUDE.md                  # This file — project rules and current status
├── PLAN.md                    # Full architecture, data model, research, roadmap
├── .claude/settings.json      # MCP server configs (Playwright, Filesystem, Sequential Thinking)
├── claude-skills/             # Skill definitions (markdown instruction files)
│   ├── vertical-adapter.md    # [DONE] NL → vertical_config JSON
│   ├── org-discoverer.md      # [DONE] Playwright crawl → organizations table
│   ├── contact-extractor.md   # [DONE] Website crawl → contacts table
│   ├── lead-scorer.md         # [DONE] Composite scoring model v1
│   ├── sentiment-classifier.md # [STUB] Phase 2
│   └── outreach-drafter.md    # [STUB] Phase 3
├── claude-agents/             # Agent configs (YAML)
│   ├── org-discovery-agent.yaml
│   ├── enrichment-agent.yaml
│   ├── scoring-agent.yaml
│   └── sentiment-agent.yaml   # Phase 2
├── mcp-servers/               # Custom MCP server stubs (Phase 2)
│   ├── reddit-mcp/
│   ├── twitter-mcp/
│   └── linkedin-mcp/
├── n8n-workflows/             # Exported workflow JSON (empty — workflows built in n8n UI)
├── db/                        # SQLite schema and init
│   ├── schema.sql             # 8 tables, 11 indexes
│   ├── init.js                # Node.js init script (better-sqlite3)
│   ├── package.json
│   └── migrations/            # Incremental schema changes
│       └── 001-add-processing-status.sql
├── config/
│   ├── .env.example           # API key template
│   └── default-verticals/     # Pre-built vertical configs (3 files)
├── scripts/
│   ├── setup.sh               # One-command project setup
│   ├── backup-db.sh           # SQLite backup with rotation
│   └── export-leads.py        # CSV export utility
├── docs/                      # Architecture, guides
├── exports/                   # CSV output directory
└── docker-compose.yml         # n8n service
```

## Key Concepts

**Vertical Config** — Every pipeline run is driven by a `vertical_config` JSON object
generated from natural language input. It defines org types, role targets, signal
taxonomy, keywords, subreddits, and scoring weights. Nothing is hardcoded to a
specific industry. See PLAN.md Section 2 for full schema.

**Pipeline Stages** — Five sequential stages:
1. Org Discovery (Playwright crawl of directories/listings)
2. Contact Extraction (website crawl for team pages — LinkedIn enrichment in Phase 2)
3. Signal Collection (LinkedIn, Reddit, Twitter raw text — Phase 2)
4. Sentiment Analysis (Claude classifies signals per vertical taxonomy — Phase 2)
5. Scoring & Export (composite lead scores to CSV — Google Sheets in Phase 1b)

**Skills** — Markdown instruction files in `claude-skills/`. Claude Code reads them as
context when performing pipeline tasks. They define the step-by-step process, SQL
queries, error handling, and rate limits for each stage.

**Agents** — YAML configs in `claude-agents/`. They declare which skills and MCP servers
to use, autonomy level, and review checkpoints. Not runnable code — declarative configs.

## Playwright Best Practices

Learned from the first E2E test (2026-02-14). Critical for preventing context exhaustion.

**Use `browser_run_code` by default.** Executes full Playwright scripts in a single turn. Click-by-click (`browser_click` → `browser_snapshot` → repeat) consumes 5-10x more context. Reserve click-by-click for reading nav structure or filling search forms.

**Dismiss cookie popups first on every page.** ~60% of sites have consent banners that intercept pointer events. Non-blocking — continue if not found:
```javascript
const btn = page.locator('button:has-text("Accept"), button:has-text("Agree")').first();
if (await btn.isVisible({ timeout: 2000 }).catch(() => false)) await btn.click().catch(() => {});
```

**Batch processing: 5 orgs per batch.** Commit to DB after each batch. Prevents context exhaustion and enables resume after session interruption.

**URL discovery for people/team pages.** Check nav menu first (most reliable), then try common URL patterns (`/attorneys`, `/people`, `/team`, `/professionals`), fallback to sitemap.xml. Mark org as `no_public_team_page` if all fail — don't retry endlessly.

## Commands

```bash
# Setup (first time)
bash scripts/setup.sh                   # Creates DB, seeds verticals, copies .env

# n8n
docker compose up -d                    # Start n8n (http://localhost:5678, admin/ilg-admin)
docker compose down                     # Stop n8n

# Database
cd db && npm run init                   # Initialize/reinitialize SQLite schema
cd db && npm run reset                  # Delete DB and reinitialize from scratch

# Run pipeline (via Claude Code — example prompts)
"Show me all configured verticals"
"Discover organizations for law firms in Texas doing corporate litigation"
"Extract contacts for law-firms-tx-corporate-lit"
"Score leads for law-firms-tx-corporate-lit"

# Utilities
bash scripts/backup-db.sh              # Backup SQLite with timestamp
python3 scripts/export-leads.py        # Export all scored leads to CSV
python3 scripts/export-leads.py law-firms-tx-corporate-lit  # Export specific vertical
```

## Code Style

- TypeScript: ES modules, strict mode, explicit types, no `any`
- Python: Type hints, f-strings, pathlib over os.path
- SQL: Lowercase keywords, snake_case tables/columns
- All MCP servers: Standard npm packages with README, `.env.example`, error handling on every API call
- Commits: Conventional commits (`feat:`, `fix:`, `docs:`)

## Key Rules

- **Budget ceiling:** Total operational cost must stay under $5/month. Free tiers everywhere. Batch API calls. Cache aggressively.
- **Rate limits are hard stops.** Twitter: stop at 1,400 reads/month. LinkedIn: stop at 45 lookups/day. Track in `api_usage` table.
- **Never fail silently.** Log errors to `logs/` with full context. Continue processing remaining items on non-fatal errors.
- **Vertical config is the contract.** Every skill and agent reads from it. Never hardcode industry-specific logic in pipeline code.
- **Confirm before committing.** org-discovery-agent shows a summary and gets user approval before writing to DB.
- **Scraping safety:** Randomized delays (2-8s web, 30-120s LinkedIn). No data behind auth walls.
- **No PII in Claude API prompts** when avoidable. Summarize before sending for analysis.

## Database Quick Reference

8 tables, 11 indexes in `db/ilg.db` (full schema in `db/schema.sql`):

| Table | Purpose |
|-------|---------|
| `vertical_configs` | Cached vertical definitions (3 seeded) |
| `organizations` | Discovered orgs |
| `contacts` | People at orgs |
| `signals` | Raw + analyzed social signals (Phase 2) |
| `lead_scores` | Composite scores with tier labels |
| `enrichment_cache` | Prevents redundant API calls |
| `outreach_log` | Draft/sent message tracking (Phase 3) |
| `api_usage` | Rate limit tracking for free tier budgets |

## Detailed Documentation

- Full architecture, data model, MCP specs, skills, agents, roadmap → `PLAN.md`
- Database schema → `db/schema.sql`
- Vertical config examples → `config/default-verticals/`
- Individual skill instructions → `claude-skills/*.md`
- Adding new verticals → `docs/ADDING-VERTICALS.md`
- MCP server build guide → `docs/MCP-SERVER-GUIDE.md`
- Architecture overview → `docs/ARCHITECTURE.md`

## Active Verticals (seeded in DB)

| vertical_id | Name | Status |
|-------------|------|--------|
| `law-firms-tx-corporate-lit` | Corporate Litigation Law Firms — Texas | Primary target |
| `law-schools-aba-accredited` | ABA-Accredited Law Schools — Nationwide | Active |
| `law-firms-general` | Law Firms — All Practice Areas | Broad template |

## Gotchas

- SQLite has no concurrent writes. Serialize n8n DB writes or migrate to PostgreSQL.
- Proxycurl free tier resets daily, not monthly. Plan LinkedIn batches accordingly.
- Reddit OAuth2 requires "script" app type for personal use. "Web app" type needs a redirect URI.
- Twitter/X free tier: 1,500 reads/month TOTAL across all endpoints. One `search_recent` with `max_results=100` = 1 read.
- n8n webhook URLs break if machine IP changes. Use DuckDNS or static IP for stable webhooks.
- Google Sheets API: 300 req/min quota. Batch writes into single `spreadsheets.values.update` calls.
- MCP server package names: `@playwright/mcp`, `@modelcontextprotocol/server-filesystem`, `@modelcontextprotocol/server-sequential-thinking`. Originally scaffolded with wrong `@anthropic-ai/mcp-*` names — fixed 2026-02-14.
- **Playwright `browser_run_code` vs click-by-click:** `run_code` is 5-10x more efficient for data extraction. The first E2E test exhausted context window processing 10 firms with click-by-click; `run_code` completed same task in 1/5 the turns.
- **Cookie popups are universal:** ~60% of crawled sites in E2E test had cookie consent banners blocking clicks. Always dismiss proactively when landing on any page.
- **Email addresses often not public:** In corporate law firm test, 40% of firms had no individual emails on public team pages. Don't fail extraction — store contacts and track via `email_status` column.
- **People page URLs have no standard:** Tested: `/attorneys`, `/people`, `/team`, `/professionals`, `/our-attorneys`, `/our-people`, `/lawyers`, `/leadership`. Always check nav menu first.
- **Phase 1 scoring uses different weights:** Signal score is always 0 when no sentiment data exists. lead-scorer uses phase-aware weights: `(role * 0.6) + (org_fit * 0.4)` when signals table is empty.
