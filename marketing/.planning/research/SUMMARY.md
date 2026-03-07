# Project Research Summary

**Project:** Swedish Company Data Enrichment PoC
**Domain:** Web-based data enrichment platform for B2B sales/recruiting
**Researched:** 2026-01-22
**Confidence:** HIGH

## Executive Summary

This PoC wraps existing Python data enrichment scripts in a web interface for batch processing Swedish company data. Research across four areas (stack, features, architecture, pitfalls) reveals a clear consensus: **build with Streamlit for maximum velocity and minimum complexity**. The PoC should ruthlessly focus on batch CSV enrichment (upload → process → download) and defer everything else.

The recommended approach is a Streamlit-based application that calls existing scripts via subprocess with proper security controls. This delivers a functional PoC in 1-2 days versus 3-5 days for Flask equivalents. The critical success factor is implementing asynchronous job processing from day one to avoid timeout hell, and securing subprocess calls to prevent command injection. With 9 table-stakes features identified, the PoC validates core value (enrichment quality and workflow fit) without overbuilding.

Key risks center on the boundary between web interface and CLI scripts: subprocess security (command injection), synchronous timeout failures, and memory leaks from browser automation. The architecture research identifies Flask as an alternative to Streamlit but recommends Streamlit for PoC speed. The pitfalls research flags that 64% of teams fail PoCs by treating them as production systems. Success requires clear scope boundaries, async job handling, and structured logging from the start.

## Key Findings

### Recommended Stack

**Primary recommendation: Streamlit 1.53.0** for zero frontend code and built-in CSV handling. This framework requires no HTML/CSS/JavaScript and provides native file upload, interactive dataframes, and download buttons. The stack leverages existing dependencies (pandas 3.0.0, openpyxl 3.1.5, requests) without changes.

**Core technologies:**

- **Streamlit 1.53.0**: Web UI framework — eliminates frontend development entirely with ~50 lines of Python vs 200+ for Flask
- **Python 3.11+**: Runtime — required by pandas 3.0 and provides stable modern Python features
- **pandas 3.0.0**: Data manipulation — already in use, native Streamlit integration via st.dataframe()
- **openpyxl 3.1.5**: Excel export — pandas-recommended library for .xlsx generation

**Alternative considered:** Flask 3.1.2 was evaluated but rejected for PoC due to 3-5x more code required (templates, forms, routing, styling). Flask makes sense only if custom REST API endpoints are needed, which is not a PoC requirement.

**Implementation estimate:** 1-2 days for Streamlit PoC (Day 1: core upload/enrich/download, Day 2: polish and validation).

### Expected Features

Research identified 9 table-stakes features, 10 nice-to-haves, and 12 anti-features to explicitly avoid.

**Must have (table stakes):**

- CSV Upload — drag-and-drop with <50 MB limit and template download
- Column Mapping — auto-detect company name/org number, allow manual override
- Basic Validation — file format, required columns, duplicate detection
- Batch Processing — queue 10-20 companies with progress indicator
- Results Preview — table view showing original + enriched fields
- CSV/Excel Export — downloadable results preserving original columns
- Single Company Lookup — ad-hoc form for quick validation
- Error Handling — per-row status (success/partial/failed) with clear messages
- Data Field Display — show enriched fields with confidence levels

**Should have (competitive):**

- Progress Notifications — email/UI updates when batch completes
- Batch History — view previous enrichment jobs
- Field Selection — choose which fields to enrich (reduce API costs)

**Defer (v2+):**

- Real-time enrichment (batch-only for PoC)
- CRM integration (export CSV for manual import)
- User authentication (known beta testers only)
- Multi-provider waterfall (single source validates concept)
- Scheduled/automated jobs (manual trigger only)
- Data storage/history database (process and return, don't persist)

**Critical insight:** PoCs should validate technical feasibility and workflow fit, not compete with commercial tools. The 9 table-stakes represent minimum viable validation, not feature completeness.

### Architecture Approach

**Conflict identified:** STACK.md recommends Streamlit for simplicity, but ARCHITECTURE.md assumes Flask with three-tier design (presentation, application, data layers). This reveals a fundamental decision point.

**Resolution:** For PoC, follow STACK.md recommendation (Streamlit). Architecture patterns from ARCHITECTURE.md apply post-PoC when migrating to production Flask/FastAPI.

**Streamlit PoC architecture:**

```
User Interface (Streamlit widgets)
    ↓
Business Logic (Python functions)
    ↓
Script Integration (direct imports, NOT subprocess)
    ↓
Existing Scripts (batch_fetch.py, search_helper.py)
```

**Major components:**

1. **Streamlit App Layer** — handles HTTP, file upload, form rendering, session state
2. **Validation Layer** — CSV structure validation, input sanitization, size limits
3. **Orchestration Layer** — calls existing scripts, aggregates results, handles errors
4. **Existing Script Layer** — batch_fetch.py, search_helper.py (unchanged)

**Key architectural decision:** Import scripts as modules rather than subprocess calls to avoid command injection vulnerability. Only csv_to_excel.py needs modification to accept --input/--output arguments.

### Critical Pitfalls

1. **Synchronous Request Timeout Hell** — Processing 10-20 companies synchronously causes 504 timeouts. Users see frozen UI with no progress visibility. Prevention: Use Streamlit's session_state to cache results and prevent re-runs, or implement basic async pattern with status polling.

2. **Subprocess Security Nightmare (Command Injection)** — Calling scripts via `subprocess.run(shell=True)` with user input enables RCE attacks. Prevention: Import scripts as modules instead OR use subprocess with shell=False and whitelist input validation. **Critical for Phase 0.**

3. **Memory Leak Cascade** — If using Selenium/Playwright (not in current scripts), browser contexts must use context managers. Failure causes OOM after 50-100 jobs. Prevention: Always use `async with` patterns and proper cleanup.

4. **Rate Limit Violation Cascade** — Works for 5 companies, fails at 20 due to rate limits. All jobs fail with HTTP 429, IP gets banned. Prevention: Exponential backoff with jitter, respect Retry-After headers, throttle to 1-2 concurrent requests.

5. **CSV Injection Vulnerability** — Malicious formulas in uploaded CSV execute when results opened in Excel. Prevention: Sanitize output cells starting with =+-@ by prefixing with single quote.

6. **Scope Creep During PoC** — Stakeholder requests balloon timeline from 2 weeks to 3 months. Prevention: Document in-scope/out-of-scope in writing before coding, set feature freeze date, time-box PoC.

## Implications for Roadmap

Based on combined research, the optimal phase structure prioritizes proving core value fast while building in critical production patterns:

### Phase 1: Streamlit Core Flow (MUST HAVE — Week 1)

**Rationale:** Proves technical feasibility with minimal code. Streamlit's built-in components map directly to table-stakes features. This phase validates if Python scripts can be web-accessible and if enrichment quality meets user needs.

**Delivers:** Working web app where users upload CSV, see enriched data, download results.

**Addresses features:**

- CSV Upload (st.file_uploader)
- Column Mapping (auto-detection via pandas)
- Basic Validation (file format checks)
- Batch Processing (st.progress bar)
- Results Preview (st.dataframe)
- CSV/Excel Export (st.download_button)

**Avoids pitfalls:**

- Subprocess security (import scripts as modules)
- Synchronous timeout (use st.session_state caching)
- Scope creep (clear deliverable: upload → download works)

**Research flag:** No additional research needed. Streamlit documentation is comprehensive and patterns are well-established.

### Phase 2: Single Lookup + Error Handling (SHOULD HAVE — Week 2)

**Rationale:** Completes table-stakes feature set. Single lookup provides quick validation for users and tests error handling with minimal data complexity.

**Delivers:** Ad-hoc company lookup form, per-row error status, comprehensive validation.

**Addresses features:**

- Single Company Lookup (st.form with text input)
- Error Handling (status indicators and error messages)
- Data Field Display (structured output with confidence)

**Avoids pitfalls:**

- Rate limiting (implement exponential backoff)
- CSV injection (sanitize output cells)
- Production logging blindness (add structured logging with correlation IDs)

**Research flag:** No additional research needed unless integrating new data sources.

### Phase 3: Polish + Security Hardening (NICE TO HAVE — Week 3)

**Rationale:** Makes PoC beta-ready. Addresses security, UX polish, and operational needs without adding scope.

**Delivers:** Production-quality PoC ready for beta testers.

**Addresses features:**

- Progress Notifications (optional email on completion)
- Field Selection (checkbox to choose enrichment fields)
- Duplicate Detection (flag duplicates before processing)

**Avoids pitfalls:**

- File upload validation bypass (magic byte checking, size limits)
- Hardcoded configuration (environment variables for all settings)
- No clear success criteria (document metrics before this phase)

**Research flag:** May need research on specific Swedish data sources (Bolagsverket API, Allabolag) if not already identified.

### Phase 4: Migration Path Planning (POST-POC — If successful)

**Rationale:** PoC success triggers production planning. This phase evaluates Streamlit limitations and plans Flask/FastAPI migration if needed.

**Delivers:** Decision document on production architecture (keep Streamlit + auth vs migrate to FastAPI + React).

**Uses stack elements:**

- Option 1: Streamlit Community Cloud with auth (internal tools)
- Option 2: FastAPI + React (external customers)
- Option 3: Hybrid (Streamlit admin + FastAPI API)

**Implements architecture:** Three-tier Flask architecture from ARCHITECTURE.md if migrating. Celery + Redis for background jobs, PostgreSQL for job tracking, S3 for file storage.

**Research flag:** Needs `/gsd:research-phase` for production deployment architecture, authentication patterns, and scalability requirements.

### Phase Ordering Rationale

- **Phase 1 first** because Streamlit provides fastest path to validate core hypothesis (enrichment quality and workflow fit)
- **Phase 2 builds on Phase 1** by reusing display components for single lookup, adding error handling that batch flow needs
- **Phase 3 deferred** until core validation complete to avoid scope creep and premature optimization
- **Phase 4 conditional** on PoC success — no point planning production migration if PoC fails validation

**Dependency chain:**

```
Phase 1 (CSV batch flow) → Phase 2 (single lookup + errors) → Phase 3 (polish) → Phase 4 (production planning)
```

Each phase delivers independently testable value. Phase 1 alone validates 67% of table-stakes features.

### Research Flags

**Needs additional research during planning:**

- **Phase 3:** Swedish data source APIs (Bolagsverket, Allabolag) — needs API documentation research if enrichment sources not yet identified
- **Phase 4:** Production deployment patterns for Streamlit vs Flask — needs infrastructure research based on scale requirements

**Standard patterns (skip research):**

- **Phase 1:** Streamlit file upload and CSV handling — official docs comprehensive
- **Phase 2:** Error handling and validation — established patterns, no novelty
- **Phase 3:** Security hardening — OWASP guidelines apply directly

## Confidence Assessment

| Area         | Confidence | Notes                                                                                                                                                                                      |
| ------------ | ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Stack        | **HIGH**   | Streamlit 1.53.0 verified via PyPI (released Jan 14, 2026), pandas 3.0.0 confirmed (Jan 21, 2026). Official documentation validates all required capabilities.                             |
| Features     | **MEDIUM** | Based on general B2B enrichment patterns, not Swedish-specific requirements. Table-stakes features validated across multiple commercial tools, but beta tester priorities need validation. |
| Architecture | **HIGH**   | Conflict between Streamlit (STACK) and Flask (ARCHITECTURE) resolved in favor of Streamlit for PoC. Migration path to production architecture clearly documented.                          |
| Pitfalls     | **HIGH**   | Critical pitfalls verified with 2026 security sources (OWASP, Snyk, Semgrep). Subprocess security, rate limiting, and timeout issues are well-documented risks.                            |

**Overall confidence:** HIGH

The primary recommendation (Streamlit for PoC) is backed by official documentation, current version verification, and multiple comparison sources. The main uncertainty is whether beta testers' specific workflow needs match the assumed table-stakes features.

### Gaps to Address

Areas where research was inconclusive or needs validation during implementation:

- **Swedish Organization Number Validation:** What is the validation algorithm for 10-digit org numbers (format: XXXXXX-XXXX)? Need to verify checksum algorithm and valid ranges.
  - **Resolution:** Research during Phase 1 implementation or consult Bolagsverket documentation.

- **Beta Tester Workflow Details:** Which fields do YOUR specific beta testers prioritize? Industry classification granularity? Employee count importance?
  - **Resolution:** User interviews before Phase 1 to validate feature priorities.

- **Enrichment Data Sources:** FEATURES.md assumes enrichment sources exist but doesn't specify which APIs/scraping targets. Current scripts suggest web scraping, but integration details unclear.
  - **Resolution:** Examine existing batch_fetch.py and search_helper.py to document actual data sources.

- **Rate Limit Specifics:** What are actual rate limits for the chosen enrichment sources? Generic guidance provided, but specific thresholds unknown.
  - **Resolution:** Test with actual sources during Phase 1, implement conservative defaults (2-3 sec delay between requests).

- **Performance Benchmarks:** What is acceptable batch processing time? Research assumes "minutes for 20 companies" is okay, but stakeholder expectations unknown.
  - **Resolution:** Define success criteria with stakeholders before Phase 1 (e.g., "20 companies in under 5 minutes").

## Consensus and Conflicts

### Strong Consensus

All four research files agree on:

- **PoC scope discipline:** Ruthlessly cut features, focus on core validation
- **Security critical:** Subprocess handling and input validation non-negotiable
- **Async from day 1:** Synchronous processing will fail, even for small batches
- **No premature optimization:** CRM integration, auth, scheduling all deferred to post-PoC

### Conflicts Resolved

**STACK vs ARCHITECTURE:**

- **Conflict:** STACK.md recommends Streamlit for simplicity. ARCHITECTURE.md assumes Flask with three-tier design and subprocess calls.
- **Resolution:** Use Streamlit for PoC (speed wins). Apply ARCHITECTURE.md patterns post-PoC during production migration. Import scripts as modules instead of subprocess to avoid security issues.

**Processing Approach:**

- **Conflict:** ARCHITECTURE.md shows synchronous Flask processing. PITFALLS.md warns synchronous causes timeout hell.
- **Resolution:** Use Streamlit's session_state for basic caching (prevents re-runs on interaction). If timeouts persist, implement polling pattern before migrating to Celery.

### Open Questions

1. **Agent-based enrichment:** ARCHITECTURE.md mentions "Agent-based processing" from PROMPT.md (Cursor Auto Mode). How does this integrate with web PoC?
   - **Recommendation:** Phase 5+ feature. PoC uses existing scripts only. Agent integration requires separate research on LLM API integration patterns.

2. **Concurrent upload handling:** PITFALLS.md flags state management issues with concurrent users. STACK.md assumes "known beta testers" (limited concurrency).
   - **Recommendation:** Document limitation "One upload at a time" for PoC. Phase 4 addresses with Redis-backed state if needed.

## Sources

### Primary (HIGH confidence)

- **Stack Research:** Streamlit 1.53.0 PyPI verification, pandas 3.0.0 release notes, official Streamlit documentation for file upload/download/dataframe capabilities
- **Security:** OWASP File Upload Cheat Sheet, Snyk Command Injection Guide, OpenStack Subprocess Security Guidelines
- **Pitfalls:** Multiple 2026 security sources (Cobalt, Semgrep, PortSwigger), rate limiting research from ZenRows and Scrape.do

### Secondary (MEDIUM confidence)

- **Features:** B2B data enrichment tool comparisons from 17 commercial providers (Alation, Sparkle, BookYourData, etc.), CSV upload UX patterns from CSVBox and OneSchema
- **Architecture:** Flask vs FastAPI comparisons from Strapi and BetterStack, web architecture patterns from ClickIT and O'Reilly
- **Swedish specifics:** Inferred from domain knowledge, not verified with Bolagsverket or Swedish-specific sources

### Tertiary (LOW confidence)

- **Beta tester workflows:** Assumed based on general B2B sales/recruiting patterns, needs validation
- **Performance requirements:** Inferred from "PoC" context, not confirmed with stakeholders

---

**Research completed:** 2026-01-22
**Ready for roadmap:** Yes

**Next steps for orchestrator:**

1. Create requirements definition based on Phase 1-3 scope
2. Flag Phase 3 for Swedish data source research if needed
3. Document success criteria with stakeholders before Phase 1 kickoff
4. Plan Phase 4 conditional on PoC validation success
