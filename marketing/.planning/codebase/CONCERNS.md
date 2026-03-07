# Codebase Concerns

**Analysis Date:** 2026-01-22

## Tech Debt

**Bare except clause in csv_to_excel.py:**

- Issue: Line 50 uses bare `except:` without exception type, silently catches all errors including system exits
- Files: `weaver-5/csv_to_excel.py:50`
- Impact: Silent failures during Excel column width calculation make debugging impossible; errors go unlogged
- Fix approach: Replace with `except (TypeError, AttributeError, ValueError):` to catch only expected exceptions, log unexpected ones

**Incomplete requirements.txt:**

- Issue: `requests` library used in `batch_fetch.py` is not listed in requirements.txt
- Files: `weaver-5/requirements.txt`, `weaver-5/batch_fetch.py:29`
- Impact: Installation will fail if anyone tries to run `batch_fetch.py` after fresh install; `urllib3` dependency (used by requests) also missing
- Fix approach: Add `requests>=2.28.0` and `urllib3>=1.26.0` to requirements.txt

**Incomplete csv_to_excel.py imports:**

- Issue: Script imports `csv` module but never uses it (line 6)
- Files: `weaver-5/csv_to_excel.py:6`
- Impact: Dead import adds confusion about intended functionality
- Fix approach: Remove unused `import csv` line

**Missing dependencies in requirements.txt:**

- Issue: `openpyxl` and `pandas` are not pinned to specific versions with upper bounds
- Files: `weaver-5/requirements.txt`
- Impact: Major version updates could introduce breaking changes to Excel formatting and CSV processing
- Fix approach: Pin versions: `pandas>=2.0.0,<3.0.0` and `openpyxl>=3.1.0,<4.0.0`

## Known Bugs

**Operator precedence bug in search_helper.py:**

- Symptoms: Incorrect search URL generation when using argument flags
- Files: `weaver-5/search_helper.py:94`
- Trigger: Run with `--ratsit` flag (without `--all`), observe that Google search URL is also generated unexpectedly
- Details: Line 94 has `if not args.allabolag and not args.ratsit or args.all:` which evaluates as `(not args.allabolag and not args.ratsit) or args.all` due to operator precedence, should be `if (not args.allabolag and not args.ratsit) or args.all:` or refactored
- Workaround: Always use `--all` flag or pass `--allabolag --ratsit` together

## Security Considerations

**Overly broad exception handling in batch_fetch.py:**

- Risk: Multiple catch-all `except Exception:` blocks (lines 106, 115, 255) could mask security issues or unexpected attacks
- Files: `weaver-5/batch_fetch.py:106,115,255`
- Current mitigation: Logging to stderr provides visibility, but broad catches hide real errors
- Recommendations: Use specific exception types for each catch block; add structured logging with error context; use logging module instead of print()

**No request validation in batch_fetch.py:**

- Risk: User-Agent header mimics real browser but could be used deceptively; no verification that responses are legitimate
- Files: `weaver-5/batch_fetch.py:73-87`
- Current mitigation: None - code accepts any HTTP response without validation
- Recommendations: Add response content-type validation; check for honeypot markers; implement rate limit detection

**Unauthenticated web scraping without permission checks:**

- Risk: Script bypasses website blocking mechanisms by using browser headers and retries; no checking of robots.txt or legal terms
- Files: `weaver-5/batch_fetch.py:1-419`, `weaver-5/ralph.sh:1-121`
- Current mitigation: Rate limiting (configurable delay) to be respectful
- Recommendations: Add robots.txt parser; implement delay based on site requirements; add consent/license check before scraping; document legal requirements for users

**No rate limiting enforcement in ralph.sh:**

- Risk: The bash script runs batches with only 2-second sleep between loops but each loop spawns a new agent instance that may make multiple requests
- Files: `weaver-5/ralph.sh:117`
- Current mitigation: Individual scripts have rate limiting but no global coordination
- Recommendations: Add request quota tracking across batches; implement backoff strategy if blocked responses detected

## Performance Bottlenecks

**CSV row processing efficiency:**

- Problem: ralph.sh processes only 5 companies per loop; 732-row CSV requires 146+ loops; each loop takes 5-10 minutes
- Files: `weaver-5/ralph.sh:6`, `weaver-5/PROMPT.md:14`
- Cause: Agent initialization overhead dominates; web search/fetch operations are sequential, not parallel
- Improvement path: Increase BATCH_SIZE to 10-20 companies per loop; implement parallel URL fetching within a single batch; use asyncio in batch_fetch.py for concurrent requests

**No connection pooling reuse across script invocations:**

- Problem: Each ralph.sh loop spawns a new agent that re-initializes requests session
- Files: `weaver-5/ralph.sh:85-86`
- Cause: Stateless agent execution model creates new processes for each batch
- Improvement path: Implement persistent worker that handles multiple batches; use message queue (Redis) to coordinate work

**Excessive logging output:**

- Problem: 100+ logs accumulated; largest log is 1MB for a single 5-company batch
- Files: `weaver-5/.logs/` directory
- Cause: Stream-JSON output format (line 86 of ralph.sh) logs all internal agent state; no filtering or compression
- Improvement path: Implement log filtering to only capture errors/warnings; rotate and compress old logs; store structured metrics instead of raw JSON

**Synchronous blocking in batch_fetch.py:**

- Problem: URLs are fetched sequentially with 1-2 second delay between each; fetching 3+ URLs takes 3+ seconds minimum
- Files: `weaver-5/batch_fetch.py:284-308`
- Cause: Single-threaded synchronous design
- Improvement path: Use asyncio with aiohttp for concurrent requests; maintain per-domain rate limiting while parallelizing across domains

## Fragile Areas

**CSV file updates without validation:**

- Files: `weaver-5/PROMPT.md:75-82`, `weaver-5/blue-collar-companies.csv`
- Why fragile: No atomic operations; agent writes directly to CSV using string search/replace; if agent crashes mid-update, CSV is corrupted
- Safe modification: Implement CSV update as atomic transaction: read entire file, modify in memory, write to temp file, rename atomically
- Test coverage: No tests validate CSV integrity after updates; unknown if data is actually being written

**PROMPT.md mutation by ralph.sh:**

- Files: `weaver-5/ralph.sh:45-51`
- Why fragile: bash script directly modifies PROMPT.md file with sed during execution (line 48); if script crashes, PROMPT.md is left in intermediate state
- Safe modification: Use backup/recovery strategy; write to temp file first, then move; validate format after each update
- Test coverage: No validation that sed replacement actually succeeded

**Log directory unbounded growth:**

- Files: `weaver-5/.logs/`
- Why fragile: 400+ log files accumulating with no cleanup; one file already 1MB (row 730 log); disk could fill on extended runs
- Safe modification: Implement log rotation in ralph.sh; compress logs older than 24 hours; set max total log size
- Test coverage: No monitoring of disk space; no alerts if logs fill disk

**Hardcoded row indexing mismatch:**

- Files: `weaver-5/PROMPT.md:14`, `weaver-5/ralph.sh:32`
- Why fragile: PROMPT.md says "0-indexed: row 144" but CSV has 732 total rows; comment suggests row 730 maps to index 144 which is incorrect (would be 729)
- Safe modification: Add explicit validation: read header, count total rows, validate that start_row is within bounds before processing
- Test coverage: No bounds checking; could silently process wrong companies if CSV structure changes

## Scaling Limits

**Single-agent batch processing:**

- Current capacity: 5 companies per 5-10 minutes = 0.5-1 company/minute
- Limit: At this rate, 732 companies take 12+ hours; 1000+ companies would take 16+ hours in a single sequential run
- Scaling path: Deploy multiple parallel agent instances; use work queue (Celery/RQ) to distribute batches; implement checkpointing to resume from failures

**Memory usage of logs:**

- Current: 400+ logs, largest 1MB; approximately 200MB total log storage
- Limit: Extended runs (1000+ companies) could consume 500MB+ of logs
- Scaling path: Implement structured logging; compress old logs; store only errors to external logging service; rotate daily

**No progress tracking across restarts:**

- Current: ralph.sh restarts from hardcoded START_ROW; if interrupted, must manually update PROMPT.md to resume
- Limit: Cannot pause/resume gracefully; no state persistence
- Scaling path: Store processing checkpoint in database; implement graceful shutdown that writes state; allow resume from checkpoint

**URL fetch rate limitations:**

- Current: batch_fetch.py respects per-request delay but no per-domain rate limiting
- Limit: May trigger 429 rate limits or blocking (403) from allabolag.se, google.com if processed too aggressively
- Scaling path: Implement adaptive rate limiting; detect 429/503 responses and back off; spread requests across multiple proxy services

## Dependencies at Risk

**Requests library outdated dependency pattern:**

- Risk: `requests` library is aging and has known security advisories; newer alternatives like `httpx` are preferred
- Impact: Could accumulate security debt over time
- Migration plan: Switch to `httpx` for async support and better modern API; httpx is drop-in compatible for synchronous usage

**Pandas version pinning missing:**

- Risk: pandas 3.0 (when released) will have breaking changes; `>=2.0.0` allows any future version
- Impact: CSV processing could silently break on major version update
- Migration plan: Pin to `pandas>=2.0.0,<3.0.0`; implement CI tests against minor version updates

**openpyxl Excel formatting fragility:**

- Risk: Excel formatting code (csv_to_excel.py) calculates column widths with no error handling; edge cases could cause silent failures
- Impact: Generated Excel files could have misaligned columns or incorrect formatting on certain data
- Migration plan: Add unit tests for edge cases (empty cells, very long strings, unicode characters); implement fallback to default widths on calculation error

## Missing Critical Features

**No data validation or accuracy scoring:**

- Problem: Script collects data but doesn't validate accuracy; no confidence scores or source attribution
- Blocks: Cannot assess data quality; customers don't know which fields are reliable
- Recommended: Add accuracy scoring system; track data sources; implement multi-source verification

**No error recovery mechanism:**

- Problem: Agent crash or network failure in middle of batch loses work; no way to retry failed companies
- Blocks: Long-running batches are risky; any network blip requires restarting entire batch
- Recommended: Implement per-company result caching; add retry logic for transient failures; save state at company level

**No batch status dashboard:**

- Problem: Only raw log files track progress; no real-time visibility into which companies are completed/failed
- Blocks: Cannot easily report progress to stakeholders; difficult to debug stalled batches
- Recommended: Add progress tracking to database; implement web dashboard showing completion %, failures, data quality metrics

**No duplicate detection:**

- Problem: If same company is processed multiple times, no mechanism prevents duplicate records or detects conflicts
- Blocks: Large datasets could accumulate duplicates; no data deduplication
- Recommended: Add company matching on organization number; detect and merge duplicate records; track processing history

## Test Coverage Gaps

**No unit tests for data processing functions:**

- What's not tested: `batch_fetch.py` URL validation, normalization, error handling; CSV row parsing in csv_to_excel.py
- Files: `weaver-5/batch_fetch.py:89-138`, `weaver-5/csv_to_excel.py:73-86`
- Risk: Encoding issues, malformed URLs, edge cases in CSV parsing go undetected; refactoring breaks silently
- Priority: High - these are core data processing functions

**No integration tests for full workflow:**

- What's not tested: End-to-end batch processing from CSV read → enrichment → CSV write → git commit
- Files: `weaver-5/ralph.sh` workflow, `weaver-5/PROMPT.md` execution
- Risk: Workflow breaks could go undetected until production (actual CSV corruption)
- Priority: Critical - this is the entire system

**No tests for edge cases in search_helper.py:**

- What's not tested: URL encoding of special characters, unicode company names, flag precedence logic
- Files: `weaver-5/search_helper.py`
- Risk: Operator precedence bug (line 94) suggests no tests for flag combinations
- Priority: Medium - affects search URL generation

**No tests for Excel formatting edge cases:**

- What's not tested: Very long cell values, unicode, empty rows, number formatting
- Files: `weaver-5/csv_to_excel.py:13-64`
- Risk: Bare except clause (line 50) means some formatting failures are silently ignored
- Priority: Medium - affects output quality

---

_Concerns audit: 2026-01-22_
