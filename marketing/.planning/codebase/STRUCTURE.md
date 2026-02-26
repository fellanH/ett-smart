# Codebase Structure

**Analysis Date:** 2026-01-22

## Directory Layout

```
/Users/admin/dev/work.ett/marketing/
├── weaver-1/                    # Initial prototype (data analysis foundation)
│   ├── data/
│   ├── docs/
│   └── notes/
├── weaver-2/                    # Data enrichment iteration
│   ├── data/
│   └── docs/
├── weaver-3/                    # CSV visualization dashboard (Node.js)
│   ├── src/                     # Frontend code (HTML/CSS/JS)
│   ├── data/                    # Sample CSV files
│   ├── docs/
│   ├── server.js                # Express server for dashboard
│   └── package.json
├── weaver-4/                    # Agent-driven processing prototype
│   ├── .logs/                   # Processing logs
│   ├── tools/
│   ├── process_company.py       # CSV state management wrapper
│   ├── search_url_generator.py  # Search URL template generation
│   ├── ralph.sh                 # Batch orchestration shell script
│   └── ralph-config.sh          # Configuration template
├── weaver-5/                    # Production batch processor (current)
│   ├── .logs/                   # Execution logs (60+ batches)
│   ├── blue-collar-companies.csv# Main data file (730+ companies processed)
│   ├── batch_fetch.py           # URL fetching with rate limiting
│   ├── search_helper.py         # Search URL generation
│   ├── csv_to_excel.py          # CSV-to-Excel conversion utility
│   ├── test_tools.py            # Tool validation utilities
│   ├── test_tools.sh            # Shell-based tool testing
│   ├── test_results.json        # Cached test results
│   ├── PROMPT.md                # Agent prompt + state (130+ lines)
│   ├── ralph.sh                 # Batch orchestration script
│   ├── urls_batch*.json         # Cached URL fetch results
│   └── PRODUCT_PLAN.md          # Productization roadmap
├── src/                         # Root data files
│   ├── Migrationsverket_företag-med-arbetstillstånd_2024_25.xlsx
│   └── Migrationsverket_företag-med-arbetstillstånd_2024_25.csv
├── presentation/                # Marketing/client materials
├── presentation-sv/             # Swedish marketing materials
├── .planning/
│   ├── codebase/                # This analysis directory
│   └── intel/
└── .git/                        # Version control (150+ commits)
```

## Directory Purposes

**weaver-5/ (Current Production):**
- Purpose: Automated batch processing of Swedish company data with agent-driven enrichment
- Contains: Python utilities, shell orchestration, prompts, CSV data, logs
- Key files: `blue-collar-companies.csv` (state), `PROMPT.md` (agent instructions), `ralph.sh` (orchestration)

**weaver-3/ (Dashboard):**
- Purpose: Web-based visualization and analysis of CSV data
- Contains: Express server, HTML/CSS/JS frontend, sample data
- Key files: `server.js` (API + static serving), `src/scripts/app.js` (client logic)

**weaver-4/ (Prototype):**
- Purpose: Earlier iteration of batch processing with Python-first approach
- Contains: Company processing wrapper, search generators
- Deprecated in favor of weaver-5's agent-driven approach

**weaver-1, weaver-2/:**
- Purpose: Initial research and foundation work
- Status: Historical; not actively used

**src/:**
- Purpose: Source data files
- Contains: CSV/XLSX with Swedish company data from Migrationsverket (work permit database)

## Key File Locations

**Entry Points:**

- `weaver-5/ralph.sh`: Main batch orchestration (runs loops, invokes agent)
- `weaver-3/server.js`: Dashboard server startup (http://localhost:3000)
- `weaver-5/PROMPT.md`: Agent prompt + state (direct agent invocation path)

**Configuration:**

- `weaver-5/PROMPT.md`: Batch instructions, validation rules, current row index, field mappings
- `weaver-5/.logs/`: Execution logs (60+ runs, each 5-50 companies per batch)
- `weaver-5/blue-collar-companies.csv`: Primary data file with company records

**Core Logic:**

- `weaver-5/batch_fetch.py`: HTTP fetching with retry/rate-limiting (161 lines)
- `weaver-5/search_helper.py`: URL generation for blocked sites (117 lines)
- `weaver-5/process_company.py`: CSV/progress state wrapper (250 lines)
- `weaver-4/process_company.py`: Earlier CSV wrapper implementation

**Utilities:**

- `weaver-5/csv_to_excel.py`: Convert CSV results to Excel format
- `weaver-5/test_tools.py`: Validate tool availability
- `weaver-5/test_tools.sh`: Shell-based testing

**Dashboard Frontend:**

- `weaver-3/src/index.html`: Main UI (HTML structure)
- `weaver-3/src/scripts/app.js`: Client logic (CSV upload, search, filter, table rendering)
- `weaver-3/src/styles/main.css`: Dark mode styling (glassmorphism)
- `weaver-3/src/styles/terminal.css`: Terminal panel styling

**Data Files:**

- `weaver-5/blue-collar-companies.csv`: Primary working data (730+ rows, processed by batches)
- `weaver-5/urls_batch*.json`: Cached batch_fetch results (for retry/audit)
- `weaver-5/test_results.json`: Cached test execution results
- `src/Migrationsverket_*.csv/xlsx`: Source data (company registry with work permits)

## Naming Conventions

**Files:**

- Python scripts: `snake_case.py` (e.g., `batch_fetch.py`, `search_helper.py`)
- Shell scripts: `lowercase.sh` (e.g., `ralph.sh`, `test_tools.sh`)
- Data files: `descriptive-name.csv/xlsx` (e.g., `blue-collar-companies.csv`)
- Logs: `run-YYYYMMDD-HHMMSS-loopN-rowX.log` (timestamp + loop number + row)
- Config files: `*.config`, `.*.config` (e.g., `.ralph.config`)

**Directories:**

- Feature/project: `weaver-N` (numbered iterations, e.g., weaver-1 through weaver-5)
- Utilities: Lowercase functional names (e.g., `src/`, `data/`, `tools/`)
- Build/runtime: Dotfiles for hidden dirs (e.g., `.logs/`, `.planning/`)

**Variables (PROMPT.md & Scripts):**

- CSV fields: Swedish names (`Företagsnamn`, `VD`, `Årlig omsättning`)
- Configuration: UPPERCASE_WITH_UNDERSCORES (e.g., `MAX_LOOPS`, `BATCH_SIZE`, `START_ROW`)
- State: Title_Case for log entries (e.g., `Last_Processed_Company`, `Total_Rows_Completed`)

## Where to Add New Code

**New Data Enrichment Logic:**
- Primary code: `weaver-5/PROMPT.md` (update validation rules or extraction patterns in Phase 1/2)
- Supporting utilities: New Python scripts in `weaver-5/` (follow naming: `new_feature.py`)
- Tests: `weaver-5/test_*.py` for utility validation

**New API/Source Integration:**
- Implementation: Create new Python module in `weaver-5/` (e.g., `source_integration.py`)
- URL generation: Extend `weaver-5/search_helper.py` with new search URL templates
- Rate limiting: Use `weaver-5/batch_fetch.py` for HTTP calls

**New Dashboard Feature:**
- Frontend: Add to `weaver-3/src/scripts/app.js` (new event handlers, view logic)
- Styling: Update `weaver-3/src/styles/main.css` or add new stylesheet
- Server endpoint: Add to `weaver-3/server.js` (new POST/GET route)

**New Batch Processing Integration:**
- Orchestration: Modify `weaver-5/ralph.sh` loop logic (adjust MAX_LOOPS, BATCH_SIZE)
- State tracking: Update PROMPT.md structure in `weaver-5/PROMPT.md` (if new fields needed)
- Commit strategy: Ensure new logic commits to git (see git section in PROMPT.md)

**Performance/Utility Scripts:**
- Location: `weaver-5/` directory (no subdirectories for Python utilities)
- Testing: Add validation to `weaver-5/test_tools.py`

## Special Directories

**.logs/ (weaver-4, weaver-5):**
- Purpose: Execution logs from batch processing runs
- Generated: True (created by ralph.sh)
- Committed: No (git-ignored)
- Contents: JSON stream output from agent invocations, one log per batch loop
- Format: `run-YYYYMMDD-HHMMSS-loopN-rowX.log`

**.planning/ (root):**
- Purpose: Analysis and planning artifacts
- Generated: True (by orchestrator commands)
- Committed: Yes (source control for plans)
- Subdirs:
  - `codebase/`: ARCHITECTURE.md, STRUCTURE.md, STACK.md, INTEGRATIONS.md, CONVENTIONS.md, TESTING.md, CONCERNS.md
  - `intel/`: Strategic/business analysis documents

**.git/ (root):**
- Purpose: Version control history
- Generated: True (by git init)
- Committed: Yes (metadata only)
- Key: Each batch processing run creates a commit with row range (e.g., "Processed companies rows 730-732 (batch of 3)")

**__pycache__/ (weaver-4):**
- Purpose: Python bytecode cache
- Generated: True (by Python interpreter)
- Committed: No (git-ignored)

**node_modules/ (weaver-3):**
- Purpose: NPM dependencies
- Generated: True (by npm install)
- Committed: No (git-ignored)
- Contents: express, cors, body-parser, etc. (defined in package.json)

## CSV Schema (blue-collar-companies.csv)

**Headers (extracted from processing):**
- `Företagsnamn` (Company Name)
- `Status` (Active/Skipped/Processing status)
- `Årlig omsättning` (Annual Revenue)
- `Org. Nummer` (Organization Number)
- `Gatuadress` (Street Address)
- `Postnummer` (Postal Code)
- `Ort` (City)
- `VD` (CEO/Director name)
- `VD E-post` (CEO email)
- `VD Telefon` (CEO phone)
- `HR Kontakt` (HR contact name)
- `HR E-post` (HR email)
- `Projektledare` (Project Manager)
- `Administratör` (Administrator)
- Plus additional role-specific and research fields

---

*Structure analysis: 2026-01-22*
