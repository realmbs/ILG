```
 ██╗ ██╗      ██████╗
 ██║ ██║     ██╔════╝
 ██║ ██║     ██║  ███╗
 ██║ ██║     ██║   ██║
 ██║ ███████╗╚██████╔╝
 ╚═╝ ╚══════╝ ╚═════╝
 Intelligent Lead Generator
```

AI-powered vertical B2B lead generation with social media sentiment analysis.
Built for a single operator. Adapts to any vertical via natural language input.

## How It Works

Describe your target market in plain English — ILG builds a full lead pipeline:

1. **Org Discovery** — crawls directories and listings for matching organizations
2. **Contact Extraction** — enriches with website and LinkedIn data
3. **Signal Collection** — monitors LinkedIn, Reddit, and Twitter for buying signals
4. **Sentiment Analysis** — classifies signals against your vertical's taxonomy
5. **Scoring & Export** — ranks leads and pushes to Google Sheets or CSV

## Stack

| Layer | Tech |
|---|---|
| Orchestration | n8n (self-hosted, Docker) |
| Intelligence | Claude Code + custom skills/agents |
| Data Bridge | MCP servers (Playwright, Reddit, Twitter, LinkedIn, PostgreSQL, Google Sheets) |
| Storage | SQLite (PostgreSQL migration path) |
| Language | TypeScript (MCP servers), Python (utilities) |

## Quick Start

```bash
docker compose up -d          # Start n8n
node db/init.js               # Initialize database
```

Then use Claude Code:

```
"Run full pipeline for mid-size law firms in Texas doing corporate litigation"
"Discover organizations: paralegal programs in Florida"
"Score and export leads for law-firms-tx to Google Sheets"
```

## Documentation

- **[CLAUDE.md](CLAUDE.md)** — Project rules, structure, commands, code style
- **[PLAN.md](PLAN.md)** — Full architecture, data model, research, roadmap

## License

Private — all rights reserved.
