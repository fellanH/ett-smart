# Phase 2: Single Lookup + Error Handling - Context

**Gathered:** 2026-01-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can look up individual companies by name or org number and see enriched data immediately. Batch results show per-row status (success/partial/failed) with human-readable error messages. This phase adds single lookup capability on top of existing batch flow.

</domain>

<decisions>
## Implementation Decisions

### Lookup form design
- Single unified input field accepts company name OR org number (auto-detects which)
- Search triggered by Enter key or button click
- No autocomplete or type-ahead

### Results presentation
- Reuse the same table format as batch results (consistency)
- Single lookup shows one row in the familiar table layout
- No export button for single lookup — it's for quick viewing only
- Skeleton placeholder shows during search (gray boxes where results will appear)
- Empty state: "No company found for [query]" plus helpful tips like "Try the org number instead"

### Claude's Discretion
- Multiple match handling: Claude decides whether to show selection list or auto-pick best match
- Search history: Claude decides whether to show recent searches in session (based on implementation simplicity)
- Exact skeleton placeholder design
- Status indicator styling for batch results (success/partial/failed icons and colors)
- Error message wording and tone

</decisions>

<specifics>
## Specific Ideas

- Table format consistency is important — single lookup and batch should feel like the same tool
- Helpful empty states guide users toward success (suggest trying org number if name fails)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-single-lookup-error-handling*
*Context gathered: 2026-01-22*
