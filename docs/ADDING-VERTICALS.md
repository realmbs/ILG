# Adding New Verticals

ILG is vertical-agnostic. Adding a new target industry requires zero code changes — only a new vertical config.

## Option 1: Natural Language (Recommended)

Tell Claude Code:
```
Create a new vertical for [your description]
```

Examples:
- "Create a new vertical for mid-size accounting firms in California"
- "Create a new vertical for SaaS companies with 50-200 employees, we sell developer tools competing with Datadog"
- "Create a new vertical for dental practices in the Southeast US"

Claude will:
1. Parse your description
2. Generate a complete `vertical_config` with intelligent defaults
3. Show you a summary for approval
4. Store the config in the database

## Option 2: Load a Default Config

Pre-built configs exist in `config/default-verticals/`:
- `law-firms-corporate.json` — Corporate litigation law firms in Texas
- `law-schools.json` — ABA-accredited law schools nationwide
- `law-firms-general.json` — All-practice law firms (broad)

These are seeded into the database on setup. To use one:
```
Show me all configured verticals
```

## Option 3: Manual JSON

Create a JSON file in `config/default-verticals/` following the schema. Required fields:

```json
{
  "vertical_id": "kebab-case-id",
  "vertical_name": "Human Readable Name",
  "description": "One-sentence description",
  "org_discovery": { ... },
  "contact_targeting": { ... },
  "signal_taxonomy": [ ... ],
  "social_monitoring": { ... },
  "scoring": { ... },
  "competitor_products": [],
  "value_proposition_context": ""
}
```

Then re-run setup to seed it:
```bash
bash scripts/setup.sh
```

## Modifying an Existing Vertical

Tell Claude Code:
```
Update the law-firms-tx-corporate-lit vertical to also target firms in New York
```

Claude will load the existing config, apply your modifications, and save the updated version.

## Viewing Verticals

```
Show me all configured verticals
```

```bash
sqlite3 db/ilg.db "SELECT vertical_id, vertical_name FROM vertical_configs;"
```
