# ILG — Intelligent Lead Generator

AI-powered vertical B2B lead generation with social media sentiment analysis.
Built for a single operator. Adapts to any vertical via natural language input.

## Stack

- **Orchestration:** n8n (self-hosted Community Edition, Docker)
- **Intelligence:** Claude Code + custom skills/agents
- **Data Bridge:** MCP servers (Playwright, Reddit, Twitter, LinkedIn, PostgreSQL, Google Sheets)
- **Storage:** SQLite at `db/ilg.db` (PostgreSQL migration path for SaaS phase)
- **Language:** TypeScript for MCP servers, Python for utility scripts
- **Export:** Google Sheets, CSV

## Project Structure

```
ILG/
├── CLAUDE.md              # This file
├── PLAN.md                # Full architecture, data model, research, roadmap
├── .claude/settings.json  # MCP server configs
├── claude-skills/         # Skill definitions (markdown instruction files)
├── claude-agents/         # Agent configs (YAML)
├── mcp-servers/           # Custom MCP servers (reddit, twitter, linkedin)
├── n8n-workflows/         # Exported workflow JSON
├── db/                    # Schema, migrations, seeds
├── config/                # .env, default vertical configs
├── scripts/               # Setup, backup, export utilities
└── docs/                  # Architecture docs, guides
```

## Key Concepts

**Vertical Config** — Every pipeline run is driven by a `vertical_config` JSON object
generated from natural language input. It defines org types, role targets, signal
taxonomy, keywords, subreddits, and scoring weights. Nothing is hardcoded to a
specific industry. See PLAN.md Section 2 for full schema.

**Pipeline Stages** — Five sequential stages, each an n8n workflow:
1. Org Discovery (Playwright crawl of directories/listings)
2. Contact Extraction (website + LinkedIn enrichment)
3. Signal Collection (LinkedIn, Reddit, Twitter raw text)
4. Sentiment Analysis (Claude classifies signals per vertical taxonomy)
5. Scoring & Export (composite lead scores to Google Sheets/CSV)

## Commands

```bash
# Setup
docker compose up -d                    # Start n8n
node db/init.js                         # Initialize SQLite schema

# Run pipeline (via Claude Code — example prompts)
"Run full pipeline for mid-size law firms in Texas doing corporate litigation"
"Discover organizations: paralegal programs in Florida"
"Collect signals for vertical law-firms-tx"
"Score and export leads for law-firms-tx to Google Sheets"

# MCP servers
cd mcp-servers/reddit-mcp && npm start  # Start Reddit MCP
cd mcp-servers/twitter-mcp && npm start # Start Twitter MCP

# Utilities
python scripts/backup-db.py             # Backup SQLite
python scripts/export-leads.py          # CSV export
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

## Detailed Documentation (progressive disclosure)

- Full architecture, data model, MCP specs, skills, agents, roadmap → `PLAN.md`
- Database schema → `db/schema.sql`
- Vertical config examples → `config/default-verticals/`
- Individual skill instructions → `claude-skills/*.md`
- MCP server build guides → `docs/MCP-SERVER-GUIDE.md`

## Active Verticals

1. **Law firms** (corporate litigation) — current Procertas pivot, primary target
2. **Law schools & paralegal programs** — existing vertical, still active

## Gotchas

- SQLite has no concurrent writes. Serialize n8n DB writes or migrate to PostgreSQL.
- Proxycurl free tier resets daily, not monthly. Plan LinkedIn batches accordingly.
- Reddit OAuth2 requires "script" app type for personal use. "Web app" type needs a redirect URI.
- Twitter/X free tier: 1,500 reads/month TOTAL across all endpoints. One `search_recent` with `max_results=100` = 1 read.
- n8n webhook URLs break if machine IP changes. Use DuckDNS or static IP for stable webhooks.
- Google Sheets API: 300 req/min quota. Batch writes into single `spreadsheets.values.update` calls.