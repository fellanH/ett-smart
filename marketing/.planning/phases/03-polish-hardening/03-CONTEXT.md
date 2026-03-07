# Phase 3: Polish + Hardening - Context

**Gathered:** 2026-01-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Make the PoC secure and handle edge cases gracefully. This includes input sanitization (CSV formula injection), file validation (format, size, encoding), and user-friendly error handling. No new features — just hardening what exists.

</domain>

<decisions>
## Implementation Decisions

### CSV Sanitization

- Input files: Warn only about potential formulas (low priority for current use case)
- Output files: Escape formula-like cells with ' prefix in downloaded CSV/Excel
- URLs in output: Keep Allabolag links clickable (useful for verification)

### File Rejection UX

- Error display: Inline banner (red warning box where file uploader is)
- Size limit: No hard cutoff for now — larger files will be supported later
- Guidance: Actionable messages ("File must be CSV. Save your Excel as CSV first.")

### Security Error Messages

- Stack traces: Always hide from users; friendly messages only
- External errors (blocked, rate limited): Claude decides balance of helpfulness vs security
- Per-row error highlighting: Claude decides visual treatment (color, icons, etc.)

### Claude's Discretion

- Empty file handling (headers only, no data)
- Character encoding detection strategy for Swedish data
- Malformed CSV row handling (reject vs skip)
- External error message specificity
- Per-row status visual treatment

</decisions>

<specifics>
## Specific Ideas

- Formula injection prevention matters more on OUTPUT (downloaded files) than input
- Beta users are known — less concern about malicious input, more about protecting their downstream tools (Excel)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

_Phase: 03-polish-hardening_
_Context gathered: 2026-01-22_
