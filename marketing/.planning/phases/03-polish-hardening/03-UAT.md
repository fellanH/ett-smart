---
status: testing
phase: 03-polish-hardening
source: [03-01-SUMMARY.md]
started: 2026-01-22T13:00:00Z
updated: 2026-01-22T13:01:00Z
---

## Current Test

number: 4
name: Empty file upload error
expected: |
  1. Create an empty CSV file (0 bytes)
  2. Upload it to the app
  3. Should see error message "File is empty" (not a crash or stack trace)
awaiting: user response

## Tests

### 1. Formula injection in CSV export
expected: Download CSV, open in text editor. Cells starting with =+\-@ should have leading quote prefix.
result: pass

### 2. Formula injection in Excel export
expected: Download Excel, open in text editor or check cell values. Formula-like cells should be text, not executing.
result: pass

### 3. URL preservation in exports
expected: Allabolag URLs (https://...) in downloaded CSV/Excel should NOT have quote prefix - they remain clickable links.
result: pass

### 4. Empty file upload error
expected: Upload an empty CSV file. Should see error message "File is empty" (not a crash or stack trace).
result: [pending]

### 5. Headers-only file upload error
expected: Upload a CSV with only column headers (no data rows). Should see error about "contains only headers, no data rows".
result: [pending]

### 6. Stack traces hidden
expected: If something goes wrong (e.g., internal error), user should see friendly error message, NOT Python stack trace.
result: [pending]

## Summary

total: 6
passed: 3
issues: 0
pending: 3
skipped: 0

## Gaps

[none yet]
