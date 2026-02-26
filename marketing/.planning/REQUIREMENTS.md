# Requirements: Swedish Company Data Enrichment PoC

**Version:** v1 (Proof of Concept)
**Updated:** 2026-01-22

## v1 Requirements (PoC)

These are the table-stakes features required to validate the core value proposition: "Upload companies -> Get enriched data."

### Core Batch Flow
| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| R1 | CSV file upload with drag-and-drop | Must | Limit <50 MB, support .csv format |
| R2 | Column mapping with auto-detection | Must | Detect company name, org number headers |
| R3 | Basic validation before processing | Must | File format, required columns, duplicates |
| R4 | Batch processing 10-20 companies | Must | Progress indicator, prevent timeout |
| R5 | Results preview in data table | Must | Show original + enriched fields |
| R6 | CSV/Excel export download | Must | Preserve original columns, append enriched |

### Single Lookup
| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| R7 | Single company lookup form | Must | Enter company name or org number |
| R8 | Immediate results display | Must | Show enriched data for one company |

### Error Handling
| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| R9 | Per-row status indicators | Must | Success/partial/failed per company |
| R10 | Clear error messages | Must | "Company not found" not "HTTP 404" |
| R11 | Enriched field display | Must | Show all fields with source attribution |

### Technical Requirements
| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| T1 | Reuse weaver-5 enrichment logic | Must | Import as modules, not subprocess |
| T2 | Rate limiting compliance | Must | 1-2s delay between external requests |
| T3 | Session state caching | Must | Prevent re-runs on page interaction |
| T4 | Input sanitization | Must | Prevent CSV injection, command injection |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| R1 | Phase 1 | Complete |
| R2 | Phase 1 | Complete |
| R3 | Phase 1 | Complete |
| R4 | Phase 1 | Complete |
| R5 | Phase 1 | Complete |
| R6 | Phase 1 | Complete |
| R7 | Phase 2 | Complete |
| R8 | Phase 2 | Complete |
| R9 | Phase 2 | Complete |
| R10 | Phase 2 | Complete |
| R11 | Phase 2 | Complete |
| T1 | Phase 1 | Complete |
| T2 | Phase 1 | Complete |
| T3 | Phase 1 | Complete |
| T4 | Phase 3 | Complete |

## v2 Requirements (Post-PoC)

Features to add after validating core concept with beta testers.

| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| V2-1 | Progress notifications (email) | Should | When batch completes |
| V2-2 | Batch history | Should | View previous enrichment jobs |
| V2-3 | Field selection | Should | Choose which fields to enrich |
| V2-4 | Duplicate detection | Should | Flag duplicates before processing |
| V2-5 | Data quality scoring | Could | Confidence levels on enriched data |
| V2-6 | Column auto-mapping memory | Could | Remember user's previous mappings |
| V2-7 | Enrichment preview | Could | Sample enrichment before full batch |
| V2-8 | Template CSV download | Could | Example file with correct format |

## Out of Scope (Explicitly Deferred)

Features NOT to build in this PoC. Common mistakes to avoid.

| Feature | Reason Deferred |
|---------|-----------------|
| Real-time enrichment | Batch-only for PoC; real-time adds latency complexity |
| CRM integration | Requires vendor auth, sync logic; users can import CSV manually |
| User authentication | Overkill for known beta testers; add post-PoC |
| API access | Web UI only; API requires versioning, docs, support |
| Scheduled/automated jobs | Manual trigger only; cron adds complexity |
| Data persistence | Process and return; don't store enriched data |
| Multi-provider waterfall | Single source validates concept; waterfall is optimization |
| Advanced analytics | Simple counts sufficient; dashboards are premature |
| Webhook notifications | Email if needed; webhooks are for integrations |
| Custom field mapping | Fixed enrichment schema; custom is enterprise feature |

## Success Criteria

The PoC must validate:

1. **Technical Feasibility:** Python scripts accessible via web with <30s page load
2. **Data Quality:** >80% of enriched fields are accurate (spot-check with beta users)
3. **Workflow Fit:** Users complete upload -> download in single session
4. **Scale:** System handles 20 companies per batch without timeout/crash

## Dependencies

### Existing Assets (from weaver-5)
- `batch_fetch.py` - URL fetching with rate limiting
- `search_helper.py` - Search URL generation for Swedish registries
- `csv_to_excel.py` - Excel export formatting
- Validation logic from `PROMPT.md` - Status/revenue checks

### New Components Needed
- Streamlit web application (new)
- Orchestration layer to call existing scripts (new)
- Input validation module (new)

## Constraints

- **No auth:** Shared URL access for known beta testers only
- **No persistence:** Results exist only during session
- **Small batches:** 10-20 companies max per request
- **Rate limits:** Must respect 1-2s delay per external request
- **Single concurrent user:** PoC limitation, document clearly

---
*Requirements derived from research findings and user preferences*
