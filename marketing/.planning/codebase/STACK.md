# Technology Stack

**Analysis Date:** 2026-01-22

## Languages

**Primary:**
- Python 3.13 - Data processing and web scraping automation in `weaver-5/`, `weaver-4/`
- JavaScript (ES6+) - Client-side web UI in `weaver-3/src/scripts/app.js`
- HTML/CSS - Frontend templates and styling in `weaver-3/src/`
- Bash - Build and batch processing automation in `weaver-5/ralph.sh`

**Secondary:**
- Markdown - Documentation and configuration in PROMPT.md files

## Runtime

**Environment:**
- Python 3.13 (primary backend runtime)
- Node.js (Express server for `weaver-3`)
- Bash/sh (orchestration and batch processing)

**Package Manager:**
- pip (Python) - Manages Python dependencies
- npm (Node.js) - Manages JavaScript dependencies in `weaver-3/`
- Lockfile: `package-lock.json` present in `/Users/admin/dev/work.ett/marketing/weaver-3/`

## Frameworks

**Core:**
- Express.js 5.2.1 - HTTP server framework in `weaver-3/server.js`
- Pandas 2.0.0+ - Data manipulation and CSV processing in `weaver-5/csv_to_excel.py`
- openpyxl 3.1.0+ - Excel file formatting in `weaver-5/csv_to_excel.py`

**HTTP & Client:**
- requests - HTTP client for batch URL fetching in `weaver-5/batch_fetch.py`
- urllib - URL parsing and query encoding in `weaver-5/search_helper.py`

**Build/Dev:**
- Bash automation - Script-based batch processing in `weaver-5/ralph.sh`
- No formal build tool detected (direct Python/Node execution)

## Key Dependencies

**Critical:**
- pandas 2.0.0 - Required for CSV reading, DataFrame operations in `weaver-5/csv_to_excel.py`
- openpyxl 3.1.0 - Required for Excel file creation and styling in `weaver-5/csv_to_excel.py`
- requests - HTTP requests library for web scraping in `weaver-5/batch_fetch.py` (provides retry strategies, session management)
- urllib3 - Underlying HTTP retry logic used by requests in `weaver-5/batch_fetch.py`

**Infrastructure:**
- express 5.2.1 - Web server framework for file serving and API endpoints in `weaver-3/`
- body-parser 2.2.2 - JSON/URL-encoded request parsing middleware in `weaver-3/server.js`
- cors 2.8.5 - Cross-Origin Resource Sharing middleware in `weaver-3/server.js`

**Frontend Libraries:**
- PapaParse 5.4.1 - CSV parsing library loaded from CDN in `weaver-3/src/index.html`
- Font Awesome 6.4.0 - Icon library loaded from CDN in `weaver-3/src/index.html`
- Google Fonts - Typography (Outfit font family) loaded from CDN in `weaver-3/src/index.html`

## Configuration

**Environment:**
- Python virtual environment at `weaver-5/.venv/` (Python 3.13)
- No `.env` files detected; configuration via command-line arguments and script parameters
- Shell scripts use environment defaults with override capability (e.g., `START_ROW` in `weaver-5/ralph.sh`)

**Build:**
- No build configuration files detected (tsconfig.json, webpack.config.js, etc.)
- Direct script execution: `python script.py`, `node server.js`, `bash script.sh`
- Express server hardcoded to listen on `PORT 3000` in `weaver-3/server.js`

## Platform Requirements

**Development:**
- Python 3.13 with pip
- Node.js with npm
- Bash shell
- Standard Unix utilities (sed, wc, jq)
- Claude Code CLI for automation (referenced in `weaver-5/ralph.sh` and `weaver-3/src/index.html`)

**Production:**
- Node.js runtime for Express server (`weaver-3/`)
- Python 3.13 runtime for data processing (`weaver-5/`, `weaver-4/`)
- Static file serving capability (Express provides this in `weaver-3/`)
- No database required - all data stored in CSV/Excel files

## Architecture Notes

**Weaver-3 (Web UI):**
- Client-server model with Express backend
- Static file serving + API endpoint for terminal command execution
- Runs on `http://localhost:3000`
- Cross-origin requests from browser to localhost:3000

**Weaver-5 (Data Processing):**
- CLI-based Python scripts for batch operations
- Orchestrated by Bash wrapper script (`ralph.sh`) that loops through CSV rows
- Integrates with Claude Code CLI for AI-powered processing
- Rate-limited HTTP fetching (default 1 second delay between requests)

**Weaver-4 (Company Processing):**
- Similar pattern to Weaver-5
- CSV-based state management
- Progress tracking via PROMPT.md file

---

*Stack analysis: 2026-01-22*
