# Skill: Contact Extractor

## Purpose

Find and profile contacts at discovered organizations by crawling their websites for team/people/about pages and matching found names/titles against the vertical config's role targets.

## When to Invoke

- After org discovery is complete and organizations exist in the database
- User says "enrich contacts for [vertical]" or "extract contacts"
- enrichment-agent workflow triggers

## Inputs

- Un-enriched organization records from the database
- `vertical_config.contact_targeting` (role_targets, max_contacts_per_org)

## Process

### Step 1: Identify Un-enriched Orgs

```sql
SELECT o.id, o.name, o.website FROM organizations o
WHERE o.vertical_id = ?
AND o.id NOT IN (
  SELECT DISTINCT org_id FROM contacts WHERE org_id IS NOT NULL
)
```

### Step 2: Crawl Org Website for People Pages

For each org with a website:
1. Use Playwright MCP to navigate to the org's website
2. Look for links containing: "team", "people", "attorneys", "professionals", "about", "our firm", "staff", "leadership", "partners", "our people"
3. Navigate to the most promising page
4. Use `browser_snapshot` to read the accessibility tree and extract names and titles
5. If no people page is found, try common URL patterns: `/team`, `/people`, `/attorneys`, `/about`, `/our-firm`, `/professionals`
6. Randomized delay 2-8 seconds between page loads

### Step 3: Match Against Role Targets

For each person found:
- Compare their title against `role_targets[].title_patterns` using fuzzy matching
- Assign `role_category` based on the matching role target's priority
- Set `is_decision_maker` based on the matching role target
- If title doesn't match any role target, assign `role_category = "low"` and `is_decision_maker = false`

### Step 4: Store Contacts

```sql
INSERT INTO contacts (org_id, first_name, last_name, title, role_category,
  is_decision_maker, profile_data_json)
VALUES (?, ?, ?, ?, ?, ?, ?)
```

Respect `max_contacts_per_org`. When more contacts are found than the limit, prioritize:
1. High-priority decision makers first
2. High-priority non-decision-makers
3. Medium-priority contacts
4. Low-priority contacts (only if slots remain)

### Step 5: Report

Present summary:
> Extracted contacts for 42 organizations:
> - Total contacts: 156
> - Decision makers: 67
> - High priority: 89
> - Medium priority: 45
> - Low priority: 22
> - Orgs with no people page found: 8
> - Orgs skipped (already enriched): 3

## Error Handling

- If an org's website is unreachable, log and skip to the next org
- If no people/team page is found, log and skip (some orgs don't have public team pages)
- If Playwright times out, retry once then skip
- Log all errors to `logs/contact-extraction-YYYY-MM-DD.log`

## Rate Limits

- 2-8 second randomized delay between Playwright page loads
- Max 3 page loads per org (home → people page → detail pages)
- Total extraction should complete in under 15 minutes for 50 orgs

## Phase 1 Limitations

- LinkedIn enrichment is deferred to Phase 2 (no Proxycurl/LinkedIn MCP integration yet)
- Email extraction is best-effort from website only
- No email verification or validation
