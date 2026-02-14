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

## Playwright Strategy

**Use `browser_run_code` by default for data extraction. Avoid click-by-click navigation.**

The first E2E test (2026-02-14) showed a 5-10x efficiency difference:
- Click-by-click (`browser_click` → `browser_snapshot` → `browser_click`): 5-10 turns per firm, massive context consumption from snapshot outputs
- `browser_run_code`: 1-2 turns per firm, returns only extracted data

**When to use each approach:**
- `browser_run_code`: Default for extracting contact lists from team pages (90% of cases)
- Click-by-click: Only for initial page navigation when you need to read the nav structure to find the people page URL

**Example `run_code` template for contact extraction:**
```javascript
async (page) => {
  await page.goto(peoplePageUrl);

  // Dismiss cookie popup if present
  const cookieBtn = page.locator('button:has-text("Accept"), button:has-text("Agree"), button:has-text("I Agree"), button:has-text("Got it")').first();
  if (await cookieBtn.isVisible({ timeout: 2000 }).catch(() => false)) {
    await cookieBtn.click().catch(() => {});
  }

  // Wait for content to load
  await page.waitForTimeout(2000);

  // Extract all people data
  const people = await page.evaluate(() => {
    const results = [];
    // Adapt selectors to page structure
    document.querySelectorAll('[class*="attorney"], [class*="people"], [class*="team"], [class*="person"], article, .bio').forEach(el => {
      const name = el.querySelector('h2, h3, h4, [class*="name"]')?.textContent?.trim();
      const title = el.querySelector('[class*="title"], [class*="position"], [class*="role"]')?.textContent?.trim();
      const emailEl = el.querySelector('a[href^="mailto:"]');
      const email = emailEl?.getAttribute('href')?.replace('mailto:', '') || emailEl?.textContent?.trim();
      if (name) results.push({ name, title, email: email || null });
    });
    return results;
  });

  return people;
}
```

If the template selectors don't match the page structure, write a page-specific `run_code` script. Inspect the snapshot once, then extract everything in one `run_code` call.

## Batch Processing

**Process organizations in batches of 5 to prevent context window exhaustion.**

The first E2E test exhausted Claude's context window processing 10 firms sequentially. Batching ensures:
- Incremental persistence — results committed to DB after each batch
- Resume capability — interrupted sessions skip already-enriched orgs
- Predictable context usage — each batch fits comfortably within limits

Workflow:
1. Query 5 un-enriched orgs (Step 1 query with `LIMIT 5`)
2. Extract contacts for all 5
3. Commit to database immediately
4. Report batch progress: "Batch 1 complete: 5/42 orgs, 23 contacts extracted"
5. Query next batch of 5 and repeat
6. Final summary after all batches complete

## Process

### Step 1: Identify Un-enriched Orgs

```sql
SELECT o.id, o.name, o.website FROM organizations o
WHERE o.vertical_id = ?
AND o.processing_status IN ('discovered', 'error')
ORDER BY o.id
LIMIT 5
```

Update each org before processing:
```sql
UPDATE organizations SET processing_status = 'enriching', enrichment_attempted_at = CURRENT_TIMESTAMP WHERE id = ?
```

### Step 2: Crawl Org Website for People Pages

For each org in the current batch:

**Phase A: Cookie/Popup Dismissal**
1. Navigate to the org's website using Playwright MCP
2. As the FIRST action on any page, dismiss cookie/privacy popups:
   - Look for buttons with text: "Accept", "Agree", "I Agree", "Got it", "Accept All", "OK"
   - Click if found (non-blocking — continue if not found or click fails)
   - ~60% of sites have these popups and they will intercept pointer events if not dismissed

**Phase B: Discover People Page URL**
1. Use `browser_snapshot` to read the nav menu and identify the people page link
2. Priority order for link detection in nav/footer:
   - "Attorneys", "People", "Team", "Professionals", "Our Team", "Our People", "Lawyers", "Leadership", "Partners", "Staff", "About"
3. If no link found in nav, try common URL patterns (navigate directly):
   - `/attorneys`, `/our-attorneys`, `/professionals`, `/people`, `/our-people`, `/team`, `/lawyers`, `/leadership`, `/about/team`, `/staff`
   - Test the most likely patterns first based on org type (e.g., law firms → `/attorneys` first)
4. If still not found, check sitemap.xml for relevant page URLs
5. If all methods fail, mark org as `no_public_team_page` and skip

**Phase C: Extract Contacts via `browser_run_code`**
1. Once people page URL is identified, use `browser_run_code` to extract all contacts in a single call
2. If the page uses pagination or "Load More" buttons, handle within the `run_code` script
3. If the page structure doesn't match the template, inspect snapshot once then write a custom `run_code` extraction
4. Randomized delay 2-5 seconds between organizations

### Step 3: Match Against Role Targets

For each person found:
- Compare their title against `role_targets[].title_patterns` using fuzzy matching
- Assign `role_category` based on the matching role target's priority
- Set `is_decision_maker` based on the matching role target
- If title doesn't match any role target, assign `role_category = "low"` and `is_decision_maker = false`

### Step 4: Store Contacts

```sql
INSERT INTO contacts (org_id, first_name, last_name, title, email, role_category,
  is_decision_maker, email_status, profile_data_json)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
```

Set `email_status`:
- `'found'` when email is extracted from the page
- `'not_found'` when the page was checked but no individual email was available

After successful insertion, update the org:
```sql
UPDATE organizations SET processing_status = 'enriched' WHERE id = ?
```

Respect `max_contacts_per_org`. When more contacts are found than the limit, prioritize:
1. High-priority decision makers first
2. High-priority non-decision-makers
3. Medium-priority contacts
4. Low-priority contacts (only if slots remain)

### Step 5: Report

Present summary after each batch and a final summary after all batches:

**Batch report:**
> Batch 2 complete: 10/42 orgs processed, 48 contacts extracted so far

**Final report:**
> Extracted contacts for 42 organizations:
> - Total contacts: 156
> - Decision makers: 67
> - High priority: 89
> - Medium priority: 45
> - Low priority: 22
> - Contacts with email: 112
> - Contacts without email: 44
> - Orgs with no people page found: 8
> - Orgs skipped (already enriched): 3

## Error Handling

- **Cookie/privacy popups**: Dismiss proactively on every page. If dismissal fails, continue anyway (non-blocking).
- **People page not found**: After checking nav, URL patterns, and sitemap — mark org as `no_public_team_page` in database. Do NOT retry endlessly.
- If an org's website is unreachable, update `processing_status = 'error'` with error details in `enrichment_error_log`, skip to the next org.
- If Playwright times out, retry once then skip and log.
- Log all errors to `logs/contact-extraction-YYYY-MM-DD.log`

## Rate Limits

- 2-5 second randomized delay between organizations
- Max 3 page loads per org (home → people page discovery → extraction via `run_code`)
- Total extraction should complete in under 5 minutes per batch of 5 orgs

## Phase 1 Limitations

- LinkedIn enrichment is deferred to Phase 2 (no Proxycurl/LinkedIn MCP integration yet)
- Email extraction is best-effort from website only — 40% of orgs may not have public individual emails
- No email verification or validation
- Contacts without emails are still stored and scored, marked with `email_status = 'not_found'`
