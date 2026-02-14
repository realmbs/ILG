# Building Custom MCP Servers for ILG

This guide covers how to build and integrate custom MCP servers for the ILG project.

## Architecture Pattern

Each custom MCP server is a Node.js TypeScript application using the `@modelcontextprotocol/sdk` package. Servers expose tools that Claude Code can invoke during pipeline execution.

```
mcp-servers/<server-name>/
├── package.json          # npm package definition
├── index.ts              # MCP server entry point
├── .env.example          # Auth credential template
├── tsconfig.json         # TypeScript config
├── src/
│   ├── tools/            # Individual tool implementations
│   ├── auth.ts           # Authentication logic
│   └── utils/            # Helpers (delays, retries, rate limiting)
└── tests/                # Test files
```

## Existing Stubs

Three custom MCP servers are planned (Phase 2):

| Server | API | Tools | Rate Limit |
|--------|-----|-------|-----------|
| reddit-mcp | Reddit REST API | search_subreddit, get_subreddit_posts, search_all, get_comments | 30 req/min |
| twitter-mcp | Twitter/X API v2 | search_recent, get_user_tweets, search_with_context | 1,400 reads/month |
| linkedin-mcp | Proxycurl | get_profile, get_company, search_people | 45 lookups/day |

## Implementation Requirements

### Rate Limiting
Every MCP server must enforce rate limits:
- Track usage in the `api_usage` SQLite table
- Implement hard stops (never exceed limits)
- Add randomized delays between requests

### Error Handling
- Retry with exponential backoff on transient errors
- Return structured error responses, never crash
- Log all errors with full context

### API Usage Tracking
Every tool call must log to `api_usage`:
```sql
INSERT INTO api_usage (platform, endpoint, requests_made, recorded_at)
VALUES (?, ?, 1, CURRENT_TIMESTAMP)
```

### Randomized Delays
```typescript
function randomDelay(minMs: number, maxMs: number): Promise<void> {
  const delay = Math.floor(Math.random() * (maxMs - minMs + 1)) + minMs;
  return new Promise(resolve => setTimeout(resolve, delay));
}
```

- Web scraping: 2,000-8,000ms
- LinkedIn: 30,000-120,000ms

## Registering with Claude Code

Add to `.claude/settings.json`:
```json
{
  "mcpServers": {
    "your-server": {
      "command": "node",
      "args": ["mcp-servers/your-server/dist/index.js"]
    }
  }
}
```

## Community MCP Servers

Installed via settings.json with `npx`:
- Playwright MCP — web scraping
- Filesystem MCP — local file access
- Sequential Thinking MCP — multi-step reasoning

These are configured in `.claude/settings.json` and require no custom code.
