# External Integrations

**Analysis Date:** 2026-01-22

## APIs & External Services

**Web Scraping & Search:**
- Google Search - URL generation for manual search fallback in `weaver-5/search_helper.py`
  - SDK/Client: Manual URL construction via `urllib.parse.quote_plus()`
  - No API key required (search URL generation only)

- Bing Search - URL generation for manual search fallback in `weaver-5/search_helper.py`
  - SDK/Client: Manual URL construction
  - Auth: None (public search URLs)

- DuckDuckGo - URL generation for manual search fallback in `weaver-5/search_helper.py`
  - SDK/Client: Manual URL construction
  - Auth: None

- Allabolag.se - Swedish company information portal
  - SDK/Client: Manual URL construction via `weaver-5/search_helper.py::generate_allabolag_search()`
  - Purpose: Company data lookup for Swedish businesses
  - Usage: Batch search URL generation for human-driven research

- Ratsit.se - Swedish company registry
  - SDK/Client: Manual URL construction via `weaver-5/search_helper.py::generate_ratsit_search()`
  - Purpose: Company registration and contact data
  - Usage: Batch search URL generation for Swedish company lookup

**HTTP Client:**
- Batch HTTP Fetcher - `weaver-5/batch_fetch.py`
  - Framework: requests library with urllib3 retries
  - Features: Rate limiting (configurable delay, default 1.0s), automatic retries (status codes 429, 500-504)
  - User-Agent: Browser-like Mozilla/5.0 headers to bypass basic blocking
  - Timeout: 30 seconds per request (configurable)
  - Error Handling: Specific handling for 403 Forbidden and 401 Unauthorized responses

## Data Storage

**Databases:**
- None - Not used in this codebase

**File Storage:**
- Local filesystem only
- CSV files: `blue-collar-companies.csv` in `weaver-5/` and `weaver-4/`
  - Format: UTF-8 encoded CSV with headers
  - Columns include: Företagsnamn (company name), status fields, financial data (Omsättning/Turnover)
  - Processed by pandas in `weaver-5/csv_to_excel.py`

- Excel files: `blue-collar-companies.xlsx` in `weaver-5/`
  - Format: Excel XLSX with openpyxl styling
  - Frozen header row, formatted cells with borders, auto-width columns
  - Generated from CSV by `weaver-5/csv_to_excel.py`

**Caching:**
- None detected

## Authentication & Identity

**Auth Provider:**
- None - No authentication system in place
- Terminal endpoint in `weaver-3/server.js` has no auth protection (local dev only per code comments)
- All data access is public/internal

## Monitoring & Observability

**Error Tracking:**
- None - No error tracking service integrated

**Logs:**
- File-based logging:
  - `weaver-3/server.js`: Console logging of HTTP requests (timestamp, method, URL)
  - `weaver-5/batch_fetch.py`: Verbose output to stderr during batch operations
  - `weaver-5/ralph.sh`: Log files created to `.logs/` directory with timestamped format `run-YYYYMMDD-HHMMSS-loopN-rowX.log`
  - Logs captured as JSON stream output from Claude Code CLI

**Progress Tracking:**
- PROMPT.md files in `weaver-5/` and `weaver-4/` used for state persistence
- Progress log format: CSV-like key-value pairs
  - Last_Processed_Company
  - Next_Row_Index
  - Total_Rows_Completed
  - Status (IN_PROGRESS/COMPLETED)

## CI/CD & Deployment

**Hosting:**
- Local development only (no production infrastructure detected)
- Express server runs on `http://localhost:3000`

**CI Pipeline:**
- None - No CI/CD configuration detected

**Manual Orchestration:**
- Bash script `weaver-5/ralph.sh` manages batch processing loops
  - Configuration: MAX_LOOPS=150, BATCH_SIZE=5, START_ROW parameter
  - Loops run Claude Code CLI agent with PROMPT.md
  - Timer and progress tracking via stderr

## Environment Configuration

**Required env vars:**
- None explicitly required
- Python imports managed via virtual environment (`weaver-5/.venv/`)
- Express PORT hardcoded to 3000 in `weaver-3/server.js`

**Secrets location:**
- No secrets detected in codebase
- Terminal endpoint comment in `weaver-3/server.js` indicates this is unsafe for production

## Webhooks & Callbacks

**Incoming:**
- None - No webhook endpoints detected

**Outgoing:**
- Claude Code CLI integration in `weaver-5/ralph.sh`:
  - Command: `agent -p --force --output-format stream-json "$(cat "$PROMPT_FILE")"`
  - Output: Stream-JSON format with tool_call and other event types
  - Integration: Bash wrapper parses stream output for progress updates

## Data Flow

**Weaver-5 Batch Processing Pipeline:**
1. CSV file read via pandas (`blue-collar-companies.csv`)
2. Search URLs generated for companies via `search_helper.py` or `batch_fetch.py`
3. HTTP fetching with rate limiting and retry logic
4. Results written back to CSV
5. Excel export via `csv_to_excel.py` with formatting
6. Progress tracked in PROMPT.md

**Weaver-3 Web UI Flow:**
1. User uploads CSV file
2. Frontend parses via PapaParse library
3. Data displayed in table with search functionality
4. Terminal commands sent to `/api/terminal/run` endpoint
5. Server executes via Node.js child_process `exec()`
6. Results streamed back to terminal

**Request/Response Format:**
- HTTP: JSON for API requests/responses
- CSV: UTF-8 text for data files
- HTML: Static files served from `weaver-3/src/`

---

*Integration audit: 2026-01-22*
