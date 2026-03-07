# Ralph.sh - Batch Company Processing

## Overview

`ralph.sh` deploys a fresh agent instance for each company row, maintaining a clean context window for each research phase. Each agent processes exactly one company and exits.

## Key Changes

### Previous Behavior

- Single agent instance processing multiple companies sequentially
- Context window accumulates across companies
- One continuous loop until completion

### New Behavior

- **Fresh agent per company**: Each company gets its own agent instance
- **Clean context**: Each agent starts with a fresh context window
- **Per-company logging**: Separate log file for each company
- **Progress tracking**: Automatically reads and verifies progress updates

## Usage

### Basic Usage

```bash
./ralph.sh [PROMPT_FILE]
```

Default prompt file is `PROMPT.md`.

### Limit Number of Companies

```bash
MAX_COMPANIES=10 ./ralph.sh
```

Process only 10 companies, then exit.

### Set Budget Limit

```bash
CURSOR_BUDGET_LIMIT=100 ./ralph.sh
```

Set a budget limit of 100 API calls. The script will stop if the limit is reached.

### Combined Limits

```bash
MAX_COMPANIES=50 CURSOR_BUDGET_LIMIT=200 ./ralph.sh
```

Process up to 50 companies or until 200 API calls are used, whichever comes first.

### Process All Remaining Companies

```bash
./ralph.sh
```

Processes all companies from the current `Next_Row_Index` until completion.

## How It Works

1. **Reads Progress State**: Extracts `Next_Row_Index` from `PROMPT.md`
2. **Gets Company Info**: Reads company name from CSV at the current index
3. **Deploys Fresh Agent**: Launches a new Cursor agent instance with `PROMPT.md`
4. **Agent Processes**: Agent researches one company, updates CSV and progress log
5. **Verifies Progress**: Checks that progress log was updated
6. **Continues**: Moves to next company (or exits if complete)

## Log Files

Each company gets its own log file:

```
.logs/company-{ROW_INDEX}-{TIMESTAMP}.json
```

Example:

```
.logs/company-131-20250115-143022.json
.logs/company-132-20250115-143145.json
```

## Exit Conditions

The script exits when:

- ✅ `Status: COMPLETED` found in `PROMPT.md`
- ✅ `Next_Row_Index >= total_rows` (reached end of CSV)
- ✅ `MAX_COMPANIES` limit reached (if set)
- ⚠️ User interrupts (Ctrl+C)

## Features

- **Fresh Context**: Each agent starts clean
- **Progress Verification**: Checks that each company was processed
- **Error Handling**: Continues even if a company fails
- **Timer Display**: Shows elapsed time per company
- **Sleep Prevention**: Uses `caffeinate` to prevent Mac sleep
- **Graceful Shutdown**: Handles SIGINT/SIGTERM
- **Usage Tracking**: Tracks API calls and estimated token usage
- **Budget Limits**: Optional budget limit to prevent overuse
- **Enhanced Logging**: Color-coded logs with detailed status messages
- **Usage Statistics**: Real-time usage stats and budget warnings

## Example Output

```
==========================================
Starting batch processing
Total companies in CSV: 731
Log directory: .logs
==========================================

==========================================
Company #1: Row 131
Company: Cico Entreprenad Ab
Log: .logs/company-131-20250115-143022.json
==========================================
⏱  Elapsed: 02:34

Company #1 (Row 131) completed in 2m 34s (exit: 0)
Progress updated: 131 -> 132

==========================================
Company #2: Row 132
Company: Conseltech Ab
Log: .logs/company-132-20250115-143145.json
==========================================
```

## Troubleshooting

**Progress not updating?**

- Check that the agent is updating `PROMPT.md` correctly
- Verify CSV file is writable
- Check log files for errors

**Script exits early?**

- Check if `Status: COMPLETED` was set incorrectly
- Verify CSV file structure
- Check `MAX_COMPANIES` environment variable

**Company name not found?**

- Verify CSV file format matches expected structure
- Check row index calculation (0-based vs 1-based)
