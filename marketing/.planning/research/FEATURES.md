# Feature Landscape: Data Enrichment PoC

**Domain:** Web-based data enrichment platform for Swedish company data
**Target Users:** B2B sales teams, recruiters (known beta testers)
**Researched:** 2026-01-22
**Confidence:** MEDIUM

## Executive Summary

Data enrichment tools in 2026 have evolved from simple "fill missing fields" utilities to comprehensive B2B intelligence platforms. However, for a PoC targeting known beta testers, the feature set should be dramatically narrower than commercial tools. This research identifies what's truly table stakes for validating the concept versus what would be premature optimization.

**Key insight:** PoCs should focus on limited scope with core functionality in one business area, not attempt to implement all modules. The primary goal is validating technical feasibility and gathering user feedback, not competing with commercial tools.

## Table Stakes Features

Features users expect for a PoC to be usable. Missing any = concept cannot be validated.

| Feature                   | Why Expected                                             | Complexity | Implementation Notes                                                                                                        |
| ------------------------- | -------------------------------------------------------- | ---------- | --------------------------------------------------------------------------------------------------------------------------- |
| **CSV Upload**            | Standard data input method for batch enrichment          | Low        | Drag-and-drop + click-to-upload. Limit file size to <50 MB. Include template download.                                      |
| **Column Mapping**        | Users need to map their CSV columns to enrichment fields | Medium     | Auto-detect common headers (company name, org number, domain). Allow manual override. Preview mapping before processing.    |
| **Basic Validation**      | Catch errors before enrichment starts                    | Low        | Validate file format, check for required columns, detect duplicate rows. Show clear error messages.                         |
| **Batch Processing**      | Process 10-20 companies without manual intervention      | Medium     | Queue system for background processing. Show progress indicator.                                                            |
| **Results Preview**       | Users must see enriched data before download             | Low        | Simple table view showing original + enriched fields. Highlight what changed.                                               |
| **CSV/Excel Export**      | Standard output format for sales/recruiting workflows    | Low        | Download enriched results as CSV or Excel. Preserve original columns + append enriched data.                                |
| **Single Company Lookup** | Ad-hoc lookup without CSV upload                         | Low        | Simple form: enter company name or org number. Show results immediately. Useful for quick validation.                       |
| **Error Handling**        | Show which companies couldn't be enriched and why        | Medium     | Per-row status (success/partial/failed). Clear error messages (not found, API timeout, invalid input).                      |
| **Data Field Display**    | Show what data was enriched for each company             | Low        | Display enriched fields: company name, industry, size, location, website, contact info. Mark confidence level if available. |

**PoC Scope Rationale:** These 9 features represent the minimum to test the core value proposition: "Upload companies → Get enriched data." Without any of these, beta testers cannot complete a realistic workflow.

## Nice to Have Features

Features that improve usability but aren't critical for PoC validation. Add only if time permits after table stakes are complete.

| Feature                     | Value Proposition                                   | Complexity | Defer Until                                      |
| --------------------------- | --------------------------------------------------- | ---------- | ------------------------------------------------ |
| **Progress Notifications**  | Users know when batch completes without refreshing  | Medium     | Post-PoC if users complain about checking status |
| **Batch History**           | View previous enrichment jobs                       | Low        | Post-PoC when users want to re-download results  |
| **Field Selection**         | Choose which fields to enrich (reduce API costs)    | Medium     | Post-PoC when API costs become significant       |
| **Duplicate Detection**     | Flag duplicate companies before enrichment          | Medium     | Post-PoC if beta data shows duplication issues   |
| **Data Quality Score**      | Show confidence/freshness of enriched data          | High       | Post-PoC; requires vendor support or heuristics  |
| **Batch Size Optimization** | Process in optimal chunks (cost vs speed)           | Low        | Post-PoC based on actual usage patterns          |
| **Multi-File Upload**       | Upload multiple CSVs in one session                 | Low        | Post-PoC if workflow analysis shows need         |
| **Column Auto-Mapping**     | Remember user's previous mappings                   | Medium     | Post-PoC for returning users                     |
| **Enrichment Preview**      | Show sample enrichment before processing full batch | Medium     | Post-PoC if users want cost confidence           |
| **Rate Limiting Display**   | Show API quota/limits remaining                     | Low        | Post-PoC if multiple users share quota           |

**Prioritization Logic:** These features enhance UX but don't block core workflow validation. In PoC stage, manual workarounds (refresh to check status, re-upload file to repeat) are acceptable for known beta testers.

## Anti-Features

Features to explicitly NOT build in a PoC. Common mistakes or premature optimization.

| Anti-Feature                        | Why Avoid                                                 | What to Do Instead                                                                       |
| ----------------------------------- | --------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| **Real-Time Enrichment**            | Adds latency complexity; PoC is batch-focused             | Build batch-only. Real-time is for post-PoC if web form integration becomes a use case.  |
| **CRM Integration**                 | Requires vendor-specific auth, sync logic, error handling | Export CSV/Excel. Users can import to their CRM manually. Validate need before building. |
| **User Authentication**             | Overkill for known beta testers; adds security scope      | Use simple password or no auth for PoC. Add proper auth post-PoC.                        |
| **Multi-Provider Waterfall**        | Complex orchestration; single provider validates concept  | Use one enrichment source. Waterfall is optimization for mature product.                 |
| **Scheduled/Automated Jobs**        | Cron complexity; PoC is manual-trigger only               | Users upload when needed. Schedule feature requires usage patterns first.                |
| **Data Storage/History DB**         | Persistence adds infra complexity; not needed for PoC     | Process and return results. Don't store enriched data. Privacy-friendly and simpler.     |
| **Advanced Analytics**              | Dashboard/reporting is premature; validate core first     | Simple counts (processed/succeeded/failed) is sufficient.                                |
| **API for Developers**              | API design requires versioning, docs, support             | Web UI only for PoC. API can come post-PoC if integration demand emerges.                |
| **Webhook Notifications**           | Complex async pattern; email is sufficient if needed      | If notifications needed, send email. Webhooks are for integration scenarios.             |
| **Data Deduplication Across Files** | Cross-file state management is complex                    | Handle duplicates within single CSV only. Cross-file is post-PoC.                        |
| **Custom Field Mapping**            | User-defined enrichment fields requires flexible schema   | Fixed enrichment schema for PoC. Custom fields are enterprise feature.                   |
| **Batch Cancellation**              | Edge case; acceptable to let batches complete             | Small batches (10-20 rows) complete quickly. Cancellation is nice-to-have.               |

**Anti-Feature Rationale:** Each of these features represents scope creep that would delay PoC launch without improving concept validation. The research shows that **64% of software features are rarely or never used**, and PoCs should ruthlessly cut anything non-essential.

## Feature Dependencies

```
CSV Upload
    ↓
Column Mapping (requires uploaded CSV structure)
    ↓
Validation (requires mapped columns)
    ↓
Batch Processing (requires valid data)
    ↓
Results Preview (requires processed data)
    ↓
Export (requires results)

Single Company Lookup (independent path)
    ↓
Results Preview (reuses same display)
```

**Critical Path:** CSV upload → mapping → validation → processing → export. All table stakes features are on this path.

## PoC Success Metrics

What the PoC must validate:

1. **Technical Feasibility:** Can Python scripts be web-accessible with acceptable performance?
2. **Data Quality:** Is enrichment accuracy good enough for sales/recruiting use?
3. **Workflow Fit:** Does CSV upload → enrich → download match user workflow?
4. **Scale:** Can system handle 10-20 companies per batch without issues?

What the PoC is NOT validating:

- Commercial viability (pricing, market size)
- Production scalability (1000s of companies)
- Integration ecosystems (CRM, API, webhooks)
- Multi-tenant architecture

## MVP Recommendation

For PoC with known beta testers, prioritize in this order:

### Phase 1: Core Batch Flow (Must Have)

1. CSV upload with drag-and-drop
2. Column mapping with auto-detection
3. Basic validation (format, required fields)
4. Batch processing (queue + progress)
5. Results preview (table view)
6. CSV export

**Deliverable:** User can upload CSV, see enriched data, download results.

### Phase 2: Single Lookup + Polish (Should Have)

7. Single company lookup form
8. Error handling (per-row status)
9. Data field display (show all enriched fields)

**Deliverable:** User can also do ad-hoc lookups and understand failures.

### Phase 3: If Time Permits (Nice to Have)

10. Progress notifications (email or UI)
11. Batch history (view previous jobs)
12. Field selection (choose what to enrich)

**Deliverable:** Improved UX for returning users.

### Explicitly Deferred to Post-PoC

- Real-time enrichment
- CRM integration
- User authentication (beyond simple password)
- API access
- Scheduled jobs
- Data persistence

## Domain-Specific Considerations

### Swedish Company Data

- **Organization Number (Organisationsnummer):** 10-digit identifier, standard format XXXXXX-XXXX. This should be primary matching field.
- **Data Sources:** Swedish-specific sources (Bolagsverket, Allabolag) may have different data quality than international sources.
- **GDPR:** Swedish companies are GDPR-strict. Don't store personal data (employee names, contacts) unless necessary.

### B2B Sales Team Workflows

- Export must preserve original columns (sales teams append to existing lists)
- Speed matters less than accuracy (batch can take minutes for 20 companies)
- Error transparency is critical (users need to know why enrichment failed)

### Recruiter Workflows

- Company size/employee count is high-priority field
- Industry classification must be granular
- LinkedIn company URL is valuable for sourcing

## UI/UX Patterns from Research

### CSV Upload Best Practices

- Drag-and-drop with dashed border + click-to-upload button
- File size limit clearly displayed (<50 MB standard)
- Template download link ("Not sure what format? Download template")
- Preview step before processing (show first 5 rows)

### Column Mapping Best Practices

- Auto-detect common headers (Company Name, Organization Number, Domain, Website)
- Visual mapping interface (source column → target field)
- Highlight unmapped required fields in red
- "Skip this column" option for irrelevant data

### Error Handling Best Practices

- Per-row status indicator (✓ success, ⚠ partial, ✗ failed)
- Downloadable error report (CSV with status column)
- Clear error messages ("Company not found in database" not "HTTP 404")
- Retry option for failed rows

### Results Preview Best Practices

- Side-by-side comparison (original → enriched)
- Highlight changed/added fields in color
- Show confidence score if available (HIGH/MEDIUM/LOW)
- Filter by status (show only successes/failures)

## Confidence Assessment

| Area                        | Confidence | Basis                                                           |
| --------------------------- | ---------- | --------------------------------------------------------------- |
| Table Stakes Features       | HIGH       | Multiple sources agree on core batch enrichment requirements    |
| Nice to Have Features       | MEDIUM     | Based on general SaaS patterns, not enrichment-specific         |
| Anti-Features               | HIGH       | PoC best practices strongly recommend limited scope             |
| Swedish Data Considerations | LOW        | Research focused on general B2B enrichment, not Sweden-specific |

## Gaps in Research

Areas where further investigation may be needed during development:

1. **Swedish Data Sources:** Which APIs/sources provide best Swedish company data? (Context7 or vendor docs needed)
2. **Organization Number Validation:** What's the validation algorithm for Swedish org numbers?
3. **Beta Tester Workflows:** What specific fields do YOUR beta testers prioritize? (User interviews needed)
4. **Performance Benchmarks:** What's acceptable batch processing time? (Test with real data)
5. **API Rate Limits:** What are the actual rate limits for chosen enrichment provider? (Vendor docs needed)

## Sources

### Data Enrichment Features & Trends (2026)

- [5 Data Enrichment Tools to Enhance Your Business Data (2026)](https://www.alation.com/blog/data-enrichment-tools/)
- [17 Data Enrichment Tools That Hunt Leads for You (2026)](https://sparkle.io/blog/data-enrichment-tools/)
- [22 Best Data Enrichment Tools for B2B Sales in 2026](https://www.bookyourdata.com/blog/data-enrichment-tools)
- [8 Best Data Enrichment Tools in 2026](https://www.saleshandy.com/blog/data-enrichment-tools/)
- [Top 10 Data Enrichment Tools [2026]](https://www.warmly.ai/p/blog/data-enrichment-tools)
- [What Is Data Enrichment? Why It Matters for B2B Sales in 2026](https://www.genesy.ai/blog/data-enrichment)

### B2B Data Enrichment Requirements

- [12 B2B Contact Data Enrichment Tools [+How to Choose]](https://www.cognism.com/blog/data-enrichment-tools)
- [Why Data Enrichment Tools Are Essential for B2B Businesses in 2026](https://www.smartlead.ai/blog/data-enrichment-tools)
- [8 Best B2B Data Enrichment Tools To Consider in 2026](https://crustdata.com/blog/best-b2b-data-enrichment-tools)

### CSV Upload & UI/UX Best Practices

- [Best UI patterns for file uploads](https://blog.csvbox.io/file-upload-patterns/)
- [5 Best Practices for Building a CSV Uploader](https://www.oneschema.co/blog/building-a-csv-uploader)
- [Designing for Enterprise — Better UX for Bulk Upload](https://manitesharma.medium.com/designing-for-enterprise-better-ux-for-bulk-upload-961e9fd1b80d)
- [Designing An Attractive And Usable Data Importer For Your App](https://www.smashingmagazine.com/2020/12/designing-attractive-usable-data-importer-app/)

### PoC vs MVP Scope & Best Practices

- [PoC, MVP, Pilot, Prototype, Alpha, Beta — What's the Difference?](https://john-elam.medium.com/poc-mvp-pilot-prototype-alpha-beta-whats-the-difference-70d53525c2ab)
- [PoC vs MVP vs Prototype: What's the Difference?](https://softwaremind.com/blog/poc-vs-mvp-vs-prototype-whats-the-difference/)
- [Top 6 Mistakes to Avoid When Running a Data Science POC](https://blog.dataiku.com/top-6-mistakes-to-avoid-when-running-a-data-science-poc)
- [How to manage a POC project for Spend Analytics](https://sievo.com/blog/how-to-manage-poc-project-for-spend-analytics)
- [What Is Proof of Concept? POC Examples & Writing Guide [2026]](https://asana.com/resources/proof-of-concept)

### Batch vs Real-Time Enrichment

- [How to Master Batch Enrichment: A Step-by-Step Guide for Data Teams](https://persana.ai/blogs/batch-enrichment)
- [CRM Enrichment: Real-Time vs Batch Updates](https://tami.ai/crm-enrichment-comparisons/)
- [Which data enrichment tools update HubSpot contacts in real-time vs batch processing](https://coefficient.io/use-cases/real-time-vs-batch-enrichment-hubspot)

### User Experience & Workflow Requirements

- [13 Best Data Enrichment Tools in 2026 [With Expert Insights]](https://www.smarte.pro/blog/data-enrichment-tools)
- [Get started with data enrichment](https://knowledge.hubspot.com/records/get-started-with-data-enrichment)
- [10 Powerful Tools for CRM Data Enrichment in 2026](https://www.default.com/post/crm-data-enrichment)

**Confidence Note:** All findings based on WebSearch of industry articles and tool reviews from 2026. No Context7 or official API documentation was consulted yet. Swedish-specific requirements are LOW confidence and should be verified with official sources or beta tester interviews.
