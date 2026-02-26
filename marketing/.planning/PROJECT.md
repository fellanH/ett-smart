# Swedish Company Data Enrichment Platform

## What This Is

A proof of concept web application that lets users enrich Swedish company data — either by uploading a CSV of companies or looking up a single company. It wraps the existing weaver-5 enrichment logic (validation, financial data extraction, contact discovery) in a simple web interface for beta testing with known users.

## Core Value

Users can upload a list of Swedish companies and get back validated, enriched data (status, revenue, contacts) in seconds — replacing hours of manual research per company.

## Requirements

### Validated

- ✓ Company validation via Allabolag.se/Ratsit.se — existing
- ✓ Revenue threshold filtering (>2M SEK) — existing
- ✓ Contact discovery (CEO/VD, HR, organizational roles) — existing
- ✓ CSV/Excel export with formatting — existing

### Active

- [ ] Web interface for CSV upload (10-20 companies per batch)
- [ ] Single company lookup by name
- [ ] View enriched results in browser (data table)
- [ ] Download results as Excel/CSV
- [ ] Progress indicator during enrichment
- [ ] Error handling and display (failed lookups, blocked sites)

### Out of Scope

- User authentication — PoC uses shared URL for known beta users
- User accounts and billing — future MVP feature
- API access — future MVP feature
- Job queue / async processing — batches are small enough for sync processing
- Multi-tenancy — single deployment for all beta users
- Data persistence — results exist only during session (download to keep)

## Context

**Existing System (weaver-5):**
- Python-based batch processing for Swedish company enrichment
- Validates companies via Allabolag.se and Ratsit.se
- Extracts financial data, org numbers, contacts (CEO, HR, etc.)
- CLI-driven with shell script orchestration
- Successfully processed 700+ companies

**Target Users:**
- B2B sales teams needing lead enrichment
- Recruitment agencies finding decision-makers
- Known beta users who've expressed interest

**Swedish Data Sources:**
- Allabolag.se — company registry, financials, status
- Ratsit.se — contact information, organizational data
- Company websites and LinkedIn for additional contact discovery

## Constraints

- **Reuse existing logic**: Port weaver-5 Python scripts, don't rewrite enrichment from scratch
- **Simple stack**: Fastest path to working PoC (Python backend + minimal frontend)
- **No auth complexity**: Shared URL access for known beta users only
- **Small batches**: 10-20 companies per request (synchronous processing OK)
- **Rate limits**: Must respect external site rate limits (1-2s delay between requests)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| PoC before full MVP | Validate concept with real users before building full auth/billing | — Pending |
| No auth for PoC | Known beta users only; reduces complexity | — Pending |
| Sync processing | 10-20 companies takes ~30-60s, acceptable wait | — Pending |
| Reuse weaver-5 logic | Already proven to work on 700+ companies | — Pending |

---
*Last updated: 2026-01-22 after initialization*
