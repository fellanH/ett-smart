# Roadmap: Swedish Company Data Enrichment PoC

## Overview

This PoC wraps existing weaver-5 Python scripts in a Streamlit web interface. The roadmap prioritizes proving core value fast: CSV batch enrichment first, single lookup second, polish only if time permits. Three phases deliver a testable PoC in 1-2 days.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

- [x] **Phase 1: Core Batch Flow** - CSV upload to enriched download in one session ✓
- [x] **Phase 2: Single Lookup + Error Handling** - Ad-hoc lookup and user-friendly errors ✓
- [x] **Phase 3: Polish + Hardening** - Input validation, security, edge cases (if time) ✓
- [x] **Phase 4: Sales and Marketing** - Sales and marketing features

## Phase Details

### Phase 1: Core Batch Flow
**Goal**: Users can upload a CSV of companies and download enriched results
**Depends on**: Nothing (first phase)
**Requirements**: R1, R2, R3, R4, R5, R6, T1, T2, T3
**Success Criteria** (what must be TRUE):
  1. User can drag-and-drop a CSV file into the web interface
  2. User sees auto-detected column mapping (company name, org number)
  3. User sees progress indicator while batch processes
  4. User sees enriched data in a table (original + enriched columns)
  5. User can download results as CSV or Excel file
**Plans:** 3 plans

Plans:
- [x] 01-01-PLAN.md — Streamlit app scaffold with CSV upload and column mapping ✓
- [x] 01-02-PLAN.md — Script integration with batch processing and progress indicator ✓
- [x] 01-03-PLAN.md — Results display table and CSV/Excel export download ✓

### Phase 2: Single Lookup + Error Handling
**Goal**: Users can look up individual companies and understand failures
**Depends on**: Phase 1
**Requirements**: R7, R8, R9, R10, R11
**Success Criteria** (what must be TRUE):
  1. User can enter company name or org number and see enriched data immediately
  2. User sees clear status per row (success/partial/failed) in batch results
  3. User sees human-readable error messages (not HTTP codes or stack traces)
  4. User sees all enriched fields with clear labeling
**Plans:** 2 plans

Plans:
- [x] 02-01-PLAN.md — Single lookup form with unified input and results display ✓
- [x] 02-02-PLAN.md — Per-row status badges and human-readable error messages ✓

### Phase 3: Polish + Hardening
**Goal**: PoC is secure and handles edge cases gracefully
**Depends on**: Phase 2
**Requirements**: T4
**Success Criteria** (what must be TRUE):
  1. Malicious CSV formulas are sanitized in output (no Excel injection)
  2. Invalid file uploads show clear rejection message
  3. Large files (>50MB) are rejected with guidance
**Plans:** 1 plan

Plans:
- [x] 03-01-PLAN.md — Input sanitization + file validation hardening ✓

### Phase 4: Sales and Marketing
**Goal**: Add marketing and sales enablement features to convert PoC into lead generation tool
**Depends on**: Phase 3
**Requirements**: R12, R13, R14, R15
**Success Criteria** (what must be TRUE):
  1. Visitors see a marketing landing page explaining the tool's value
  2. Users can submit a lead capture form to request access/demo
  3. Enriched data exports include sales-optimized format (e.g., ready for CRM import)
  4. Admin can view basic usage analytics (lookups, exports, conversions)
**Plans:** 4 plans

Plans:
- [x] 04-01-PLAN.md — Convert to multi-page app with st.navigation() ✓
- [x] 04-02-PLAN.md — Marketing landing page with lead capture form ✓
- [x] 04-03-PLAN.md — CRM-ready export format ✓
- [x] 04-04-PLAN.md — Usage analytics tracking and dashboard ✓

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Core Batch Flow | 3/3 | ✓ Complete | 2026-01-22 |
| 2. Single Lookup + Errors | 2/2 | ✓ Complete | 2026-01-22 |
| 3. Polish + Hardening | 1/1 | ✓ Complete | 2026-01-22 |
| 4. Sales and Marketing | 4/4 | ✓ Complete | 2026-01-22 |

## Requirement Coverage

| Requirement | Description | Phase |
|-------------|-------------|-------|
| R1 | CSV file upload with drag-and-drop | Phase 1 |
| R2 | Column mapping with auto-detection | Phase 1 |
| R3 | Basic validation before processing | Phase 1 |
| R4 | Batch processing 10-20 companies | Phase 1 |
| R5 | Results preview in data table | Phase 1 |
| R6 | CSV/Excel export download | Phase 1 |
| R7 | Single company lookup form | Phase 2 |
| R8 | Immediate results display | Phase 2 |
| R9 | Per-row status indicators | Phase 2 |
| R10 | Clear error messages | Phase 2 |
| R11 | Enriched field display | Phase 2 |
| T1 | Reuse weaver-5 enrichment logic | Phase 1 |
| T2 | Rate limiting compliance | Phase 1 |
| T3 | Session state caching | Phase 1 |
| T4 | Input sanitization | Phase 3 |
| R12 | Marketing landing page | Phase 4 |
| R13 | Lead capture form | Phase 4 |
| R14 | Sales-optimized export format | Phase 4 |
| R15 | Usage analytics dashboard | Phase 4 |

**Coverage:** 19/19 requirements mapped
