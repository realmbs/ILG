/**
 * ILG LinkedIn MCP Server
 *
 * Status: Phase 2 stub
 *
 * Tools to implement:
 * - get_profile(linkedin_url)                          — Get structured profile data
 * - get_company(linkedin_url)                          — Get company page data
 * - search_people(keywords, location, current_company) — People search (limited on free tier)
 *
 * Auth: Proxycurl API key (primary) at https://nubela.co/proxycurl
 *       Fallback: open-source scraper with aggressive rate limiting
 *
 * Rate limit: ~50 lookups/day via Proxycurl (HARD STOP at 45)
 * Delays: 30-120 second randomized delays between requests
 *
 * NOTE: Proxycurl free tier resets DAILY, not monthly.
 * Direct LinkedIn scraping violates ToS — use Proxycurl as primary.
 */

console.log("LinkedIn MCP server — not yet implemented (Phase 2)");
console.log("Get Proxycurl API key at https://nubela.co/proxycurl");
console.log("Add key to mcp-servers/linkedin-mcp/.env");
