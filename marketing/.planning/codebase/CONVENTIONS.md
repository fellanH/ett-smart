# Coding Conventions

**Analysis Date:** 2026-01-22

## Naming Patterns

**Files:**

- Snake case with descriptive names: `batch_fetch.py`, `search_helper.py`, `csv_to_excel.py`
- Script entry point: `main()` function
- Test files: `test_*.py` (e.g., `test_tools.py`)
- Bash scripts: Simple names, typically `*.sh` (e.g., `ralph.sh`, `test_tools.sh`)

**Functions:**

- Snake case: `validate_url()`, `fetch_url()`, `fetch_batch()`, `generate_search_url()`, `read_progress_log()`
- Descriptive action verbs: "generate", "validate", "fetch", "read", "update"
- Private/internal functions not used (no underscore prefix observed)

**Variables:**

- Snake case throughout: `max_retries`, `batch_size`, `current_row`, `log_file`, `error_msg`
- Constants in UPPER_SNAKE_CASE: `PROMPT_FILE`, `CSV_FILE`, `BATCH_SIZE`, `MAX_LOOPS`, `LOG_DIR`
- Tuple unpacking for multi-value returns: `is_valid, normalized_url, error = validate_url(url)`

**Types:**

- Type hints used extensively in function signatures: `def fetch_url(self, url: str) -> Dict:`, `def fetch_batch(self, urls: List[str], verbose: bool = False) -> List[Dict]:`
- Dict, List, Optional, Tuple imported from `typing` module
- Return type annotations consistently applied

## Code Style

**Formatting:**

- No linting/formatting tool detected (no `.flake8`, `pylintrc`, `black`, or `prettier` config)
- Implicit style standard from code review: 4-space indentation (Python standard)
- Line length appears to follow ~100-120 character guideline (based on file content)
- Blank lines between major sections and method definitions

**Linting:**

- No linter configuration found
- Code relies on manual adherence to conventions

## Import Organization

**Order:**

1. Standard library imports (`sys`, `json`, `time`, `argparse`, `urllib.parse`, `subprocess`, `csv`, `pathlib`)
2. Third-party imports (`requests`, `pandas`, `openpyxl`)
3. Local/relative imports (none observed)

**Path Aliases:**

- No path aliases detected (no `@` imports or tsconfig paths)

## Error Handling

**Patterns:**

**Validation with Tuple Returns:**

```python
def validate_url(self, url: str) -> Tuple[bool, Optional[str], Optional[str]]:
    """
    Returns:
        Tuple of (is_valid, normalized_url, error_message)
    """
    if not url or not isinstance(url, str):
        return False, None, "URL is empty or not a string"
    # ...
    return True, normalized, None
```

Location: `batch_fetch.py` lines 89-138

**Try-Except with Specific Exception Types:**

```python
try:
    response = self.session.get(normalized_url, timeout=self.timeout)
except requests.exceptions.Timeout:
    error_msg = f"Timeout after {self.timeout}s"
    if attempt < self.max_retries:
        time.sleep(2 ** attempt)  # Exponential backoff
        continue
except requests.exceptions.ConnectionError as e:
    error_msg = f"Connection error: {str(e)}"
    if attempt < self.max_retries:
        time.sleep(2 ** attempt)
        continue
```

Location: `batch_fetch.py` lines 219-228

**Structured Error Response Objects:**
Returns dict with `success`, `error`, and status information instead of raising exceptions:

```python
return {
    "url": url,
    "normalized_url": None,
    "success": False,
    "status_code": None,
    "error": error,
    "content_length": None,
}
```

Location: `batch_fetch.py` lines 150-159, 259-268

**Bash Error Handling:**
Set strict mode at start of script: `set -uo pipefail`
Explicit error checks with exit codes:

```bash
if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "Error: $PROMPT_FILE not found" >&2
  exit 1
fi
```

Location: `ralph.sh` lines 21-24

## Logging

**Framework:** Console output (no logging library)

**Patterns:**

**Print to stderr for diagnostics:**
Used for progress information and warnings in bash:

```bash
echo "Starting batch processing..." >&2
echo "Loop #$loop_count completed in $((elapsed/60))m $((elapsed%60))s" >&2
```

Location: `ralph.sh` lines 39-41, 106

**Print to stdout for results:**
Used for JSON output and status messages in Python:

```python
print(output_json)  # Main output to stdout
print(f"Results saved to {args.output}", file=sys.stderr)  # Progress to stderr
```

Location: `batch_fetch.py` lines 404-411

**Verbose flag pattern:**
Optional verbose output controlled by flag:

```python
if verbose:
    print(f"[{idx}/{total}] Fetching: {url}", file=sys.stderr)
```

Location: `batch_fetch.py` lines 286-304

**Progress indicators in bash:**
Real-time timer display with carriage return:

```bash
printf "\r⏱  Elapsed: %02d:%02d" $((timer/60)) $((timer%60)) >&2
```

Location: `ralph.sh` lines 78

## Comments

**When to Comment:**

- Module-level docstrings for all scripts explaining purpose and usage
- Function docstrings with Args and Returns sections (Google style)
- Inline comments for complex logic or non-obvious decisions
- No comments for obvious code

**DocString Format (Google Style):**

```python
def fetch_batch(self, urls: List[str], verbose: bool = False) -> List[Dict]:
    """
    Fetch multiple URLs with rate limiting.

    Args:
        urls: List of URLs to fetch
        verbose: Print progress to stderr

    Returns:
        List of result dictionaries
    """
```

Location: `batch_fetch.py` lines 270-280

**Module Docstrings:**
Located at top of file after shebang and encoding declaration:

```python
"""
Batch URL Fetcher with Rate Limiting and Error Handling

Fetches multiple URLs with rate limiting to avoid throttling.
Handles invalid URLs, retries on failures, and outputs JSON results.

Usage:
    # From command line with URLs as arguments
    python batch_fetch.py https://example.com
"""
```

Location: `batch_fetch.py` lines 2-20

## Function Design

**Size:** Functions range from 10-50 lines; class methods average 20-40 lines. No functions exceed 60 lines.

**Parameters:**

- Positional parameters for required inputs
- Keyword-only arguments for configuration/options via `argparse`
- Default values provided for optional parameters: `delay: float = 1.0`, `timeout: int = 30`
- Type hints on all parameters

**Return Values:**

- Dictionaries for structured responses with multiple related fields
- Tuples for fixed-size multi-value returns: `Tuple[bool, Optional[str], Optional[str]]`
- Lists for collections: `List[Dict]`, `List[str]`
- Exit codes in bash scripts (0 for success, 1+ for errors)

## Module Design

**Exports:**

- Main entry point: `if __name__ == "__main__": main()` pattern
- Class-based organization for stateful operations (e.g., `BatchFetcher` class)
- Pure functions for simple utilities

**Barrel Files:**

- Not used (no index files or aggregation modules)
- Each module is self-contained

**Class Organization:**

`BatchFetcher` class in `batch_fetch.py`:

- `__init__()`: Initializes session with retry strategy and headers
- `validate_url()`: URL validation and normalization
- `fetch_url()`: Single URL fetch with error handling
- `fetch_batch()`: Batch processing with rate limiting
  Location: `batch_fetch.py` lines 34-310

---

_Convention analysis: 2026-01-22_
