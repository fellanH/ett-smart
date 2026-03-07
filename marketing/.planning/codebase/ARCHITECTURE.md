# Architecture

**Analysis Date:** 2026-01-22

## Pattern Overview

**Overall:** Multi-stage data enrichment pipeline with batch automation and dashboard visualization

**Key Characteristics:**

- Modular separation between data processing layers and UI/dashboard
- Agent-driven batch processing with state management
- Multiple weaver iterations showing evolutionary progression (weaver-1 through weaver-5)
- Automation-first approach with shell script orchestration
- Web scraping and API integration for Swedish company registry data

## Layers

**Data Collection Layer:**

- Purpose: Fetch and validate data from external sources (Allabolag.se, Ratsit.se, LinkedIn, company websites)
- Location: `weaver-4/`, `weaver-5/` (batch_fetch.py, search_helper.py, process_company.py)
- Contains: URL fetching utilities, search query generation, batch processing logic
- Depends on: requests library, urllib for HTTP operations
- Used by: Agent automation (PROMPT.md-driven processing), shell scripts

**Validation Layer:**

- Purpose: Check company status, revenue thresholds, existence in registries, and filter invalid entries
- Location: Logic embedded in `weaver-5/PROMPT.md` (Phase 1 validation rules)
- Contains: Validation logic for status (Aktiv/Konkurs/Likvidation/Avveckling), revenue thresholds (>2M SEK), company age rules
- Depends on: Allabolag.se and Ratsit.se APIs
- Used by: Batch processing workflow

**Enrichment Layer:**

- Purpose: Extract financial data, contact information, organizational structure for valid companies
- Location: `weaver-5/PROMPT.md` (Phase 2 deep research rules)
- Contains: Web search strategies, field extraction patterns (CEO/VD, HR, location, revenue, organizational roles)
- Depends on: Web search tools, batch_fetch.py, LinkedIn searches
- Used by: Agent processing loop

**State Management Layer:**

- Purpose: Track processing progress, batch boundaries, and update CSV with results
- Location: `weaver-5/PROMPT.md`, `weaver-5/ralph.sh`, `weaver-4/process_company.py`
- Contains: CSV reading/writing, progress log updates, batch coordination
- Depends on: CSV file structure, git for commits
- Used by: Shell script orchestration, agent validation

**Dashboard Layer:**

- Purpose: Visualize and analyze collected company data
- Location: `weaver-3/src/` (HTML, CSS, JavaScript client-side application)
- Contains: CSV upload interface, data table visualization, search/filter UI, terminal integration
- Depends on: PapaParse library for CSV parsing
- Used by: End users for data analysis

**Orchestration Layer:**

- Purpose: Coordinate batch processing loops, manage agent invocation, and track completion
- Location: `weaver-5/ralph.sh`, `weaver-4/ralph.sh`
- Contains: Batch loop control (MAX_LOOPS, BATCH_SIZE), agent invocation with prompt injection, log management
- Depends on: Agent CLI, PROMPT.md updates, CSV state
- Used by: User running batch processing

## Data Flow

**CSV Processing Workflow:**

1. **Initialization**: Ralph.sh reads CSV file, determines total rows, sets starting row from PROMPT.md
2. **Batch Loop**: For each batch (default 5 companies):
   a. Update PROMPT.md with current row index
   b. Invoke agent with updated PROMPT.md
   c. Agent processes companies sequentially (validate → enrich → update CSV)
   d. On completion, git commit CSV changes with row range
3. **Progress Tracking**: PROMPT.md "Start Row Index" field maintains state across batch iterations
4. **Completion**: Loop exits when current_row > total_rows or max_loops reached

**Company Processing Flow (Per Batch):**

1. **Phase 1 - Validation (Sequential)**:
   a. Use Allabolag.se/Ratsit.se to check company status
   b. Verify company exists in registry
   c. Check annual revenue (Årlig omsättning)
   d. If company fails any check → mark as SKIPPED, move to next company
   e. If company passes → proceed to Phase 2

2. **Phase 2 - Deep Research (For Valid Companies)**:
   a. Generate search URLs using search_helper.py
   b. Batch fetch URLs using batch_fetch.py with rate limiting (--delay 1.5s)
   c. Extract financial data (revenue, org number, location)
   d. Search for contacts (CEO/VD name, email, phone; HR contacts; specific roles)
   e. Store results in memory for batch update

3. **Phase 3 - CSV Update**:
   a. Read current CSV file
   b. Update rows with validated data
   c. Write CSV back to disk
   d. Commit changes to git with row range

**State Management:**

- Current batch position: Stored in PROMPT.md "Start Row Index" field
- Processing results: Accumulated in agent memory during batch, written to CSV once
- Progress log: PROMPT.md contains last processed company, total completed rows
- Failure recovery: Agent can resume from any row via START_ROW parameter

## Key Abstractions

**Agent-Driven Processing:**

- Purpose: Leverage AI to perform research, validation, and data extraction with natural language reasoning
- Examples: `weaver-5/PROMPT.md` (130+ lines defining multi-phase workflow), `weaver-5/ralph.sh` (invokes agent with prompt)
- Pattern: Prompt injection where script updates PROMPT.md with current row, then invokes `agent` CLI with full prompt context

**Batch Fetcher:**

- Purpose: Fetch multiple URLs with rate limiting, error handling, and retry logic
- Examples: `weaver-5/batch_fetch.py`
- Pattern: Session-based HTTP with retry strategy (Retry lib), browser-like User-Agent headers, exponential backoff on connection errors, detects 403 blocks

**Search URL Generator:**

- Purpose: Create search URLs for blocked/inaccessible registries
- Examples: `weaver-5/search_helper.py`
- Pattern: Template-based URL construction for Allabolag.se, Ratsit.se, Google, Bing, DuckDuckGo searches

**CSV State Machine:**

- Purpose: Maintain single-file state for multi-step processing
- Examples: `weaver-5/blue-collar-companies.csv` (company rows with status, financial data, contact info)
- Pattern: Append-only updates (only process unprocessed rows), git commits for auditability

## Entry Points

**Automated Batch Processing:**

- Location: `weaver-5/ralph.sh`
- Triggers: User runs `./ralph.sh [optional_start_row]`
- Responsibilities:
  - Loop coordination (batch size, max loops)
  - PROMPT.md state updates
  - Agent invocation
  - Progress reporting (elapsed time, loop count)
  - Git commits after CSV updates

**Manual Agent Invocation:**

- Location: `weaver-5/PROMPT.md`
- Triggers: Developer runs `agent -p "$(cat PROMPT.md)"` directly
- Responsibilities:
  - Company validation
  - Data enrichment research
  - CSV updates (direct file write)
  - Git commits

**Dashboard/Visualization:**

- Location: `weaver-3/server.js` + `weaver-3/src/index.html`
- Triggers: User navigates to `http://localhost:3000` or opens HTML in browser
- Responsibilities:
  - CSV file upload/parsing
  - Real-time data visualization
  - Search/filter operations
  - Terminal command execution (via API endpoint)

**Utility Scripts:**

- `weaver-5/batch_fetch.py`: Standalone URL fetching with rate limiting
- `weaver-5/search_helper.py`: Generate search URLs for blocked sites
- `weaver-4/process_company.py`: Wrapper for CSV state and progress tracking

## Error Handling

**Strategy:** Multi-layered error detection and graceful degradation

**Patterns:**

1. **Validation Failures**: Company marked as SKIPPED with reason (Status, Not Found, Low Revenue, Dormant)
2. **Network Errors**: batch_fetch.py retries with exponential backoff; returns error details in JSON
3. **Blocked Sites (403)**: Detected by status code check, batch_fetch.py returns "blocked": true, agent falls back to search_helper.py
4. **Timeout/Connection Errors**: Retry up to max_retries (default 3) with exponential backoff (2^n seconds)
5. **Invalid URLs**: Validated and normalized before fetching; invalid URLs return validation error
6. **Agent Processing Errors**: Logged to `.logs/run-*-loop*-row*.log` file; stderr shows progress/tools used
7. **CSV Structure Errors**: Agent preserves CSV structure on write; only updates specified cells

## Cross-Cutting Concerns

**Logging:**

- Approach: File-based logging to `.logs/` directory with timestamp and loop number
- Format: Each batch generates `run-YYYYMMDD-HHMMSS-loopN-rowX.log` containing agent stream JSON output
- Accessible via: `tail -f .logs/run-*` during execution

**Validation:**

- Approach: Two-phase (Phase 1: status/existence/revenue, Phase 2: data extraction with confidence)
- Checkpoints: Status check blocks further processing; revenue thresholds applied before deep research
- Confidence scoring: Multiple sources consulted (Allabolag, company website, LinkedIn) before accepting data

**Batch Processing:**

- Approach: Fixed batch size (default 5 companies per loop) to control memory and API rate limits
- Rate limiting: batch_fetch.py uses --delay flag (default 1.0s) to space requests; ralph.sh sleeps 2s between loops
- State persistence: CSV + PROMPT.md + git commits enable recovery from any failure point

**Git Auditing:**

- Approach: Mandatory commit after each successful batch with row range
- Format: `git commit -m "Processed companies rows X-Y (batch of Z)"`
- Enables: Time-travel debugging, rollback capability, audit trail of data changes

---

_Architecture analysis: 2026-01-22_
