# Skill: Org Discoverer

## Purpose

Discover organizations matching a vertical config's org_discovery criteria using web scraping via Playwright MCP. Produces structured org records for the organizations table.

## When to Invoke

- After a vertical_config is created or loaded
- User says "discover organizations for [vertical]"
- org-discovery-agent workflow reaches the discovery stage

## Inputs

- `vertical_config.org_discovery` object containing: org_types, size_filter, geography, industry_filters, discovery_sources, qualifying_signals
- `vertical_config.vertical_id` for foreign key linkage

## Process

### Step 1: Plan Discovery Strategy

For each source in `discovery_sources`, determine the crawl approach:
- **Directory sites** (Martindale-Hubbell, Chambers, etc.): Navigate to search page, enter filters for geography + practice area, paginate through results
- **Bar association searches**: Use state bar member search with practice area filters
- **Google Maps**: Search for "[org_type] in [city/state]" and extract business listings
- **Rankings lists**: Navigate to the rankings page, extract the structured list

Present the discovery plan to the user before executing:
> Planning to crawl 5 sources for law firms in TX:
> 1. Martindale-Hubbell: search by state=TX, practice=corporate litigation
> 2. Texas State Bar: member search, filter by practice area
> ...
> Estimated: ~50 page loads, ~3 minutes

### Step 2: Execute Crawls via Playwright MCP

For each discovery source:
1. Use Playwright MCP `browser_navigate` to load the search page
2. Use `browser_snapshot` to read the accessibility tree
3. Identify search/filter form elements
4. Use `browser_click` and `browser_type` to fill in search criteria from the config
5. Submit the search and read results
6. For paginated results, iterate through pages (max 10 pages per source to respect rate limits)
7. Pause 2-8 seconds (randomized) between page loads

### Step 3: Extract Org Data

From each search result, extract:
- `name`: Organization name
- `website`: URL (follow through to get the canonical domain)
- `state`: 2-letter state code
- `city`: City name
- `size_estimate`: Any available size indicator (employee count, partner count, office count)
- `org_type`: From config (e.g., "law firm")
- `industry_tags`: JSON array of practice areas or specialties found
- `discovery_source`: Which source this org was found on

### Step 4: Deduplicate

Before inserting, check for existing orgs:
```sql
SELECT id, name, website FROM organizations
WHERE vertical_id = ? AND (
  name LIKE ? OR website LIKE ?
)
```

Deduplication rules:
- Same website domain = same org (merge, update if newer data is richer)
- Very similar names in same city = likely same org (flag for review, do not auto-merge)

### Step 5: Score Initial Fit

Assign `fit_score` (0.0-1.0) based on how well the org matches config criteria:
- Size within `size_filter` range: +0.3
- Geography match: +0.2
- Industry filters match (practice areas overlap): +0.3
- Found on high-authority source (rankings vs. generic search): +0.1
- Has qualifying signals visible on website: +0.1

### Step 6: Present Summary for Review

Before committing to the database, present:
> **Discovery Results:**
> - Sources crawled: 5
> - Total orgs found: 47
> - New orgs (not in DB): 42
> - Updated orgs: 5
> - Average fit_score: 0.72
> - Top 5 by fit_score: [list]
>
> Commit to database? [y/n]

### Step 7: Commit to Database

On user approval:
```sql
INSERT INTO organizations (vertical_id, name, org_type, website, state, city, size_estimate,
  industry_tags, fit_score, discovery_source, raw_data_json)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
```

## Error Handling

- If a discovery source is unreachable or has changed its layout, log the error and continue with remaining sources. Never fail the entire discovery because one source is down.
- If Playwright MCP times out on a page, retry once with a longer timeout, then skip and log.
- Log all errors to `logs/org-discovery-YYYY-MM-DD.log` with full context.

## Rate Limits

- Max 10 pages per discovery source (prevents runaway crawls)
- 2-8 second randomized delay between Playwright page loads
- Total discovery should complete in under 10 minutes for a typical vertical
