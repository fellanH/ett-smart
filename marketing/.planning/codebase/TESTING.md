# Testing Patterns

**Analysis Date:** 2026-01-22

## Test Framework

**Runner:**

- No formal test framework detected (pytest/unittest not configured)
- Manual test scripts: `test_tools.py`, `test_tools.sh`

**Assertion Library:**

- None (no `pytest`, `unittest`, or `assertions` library)
- Tests use subprocess calls and output validation

**Run Commands:**

```bash
# Run Python integration tests
python test_tools.py

# Run bash integration tests
bash test_tools.sh
```

## Test File Organization

**Location:**

- Tests co-located in same directory as source code: `weaver-5/test_tools.py`, `weaver-5/test_tools.sh`
- Not separated into dedicated `tests/` directory

**Naming:**

- `test_tools.py`: Integration test script
- `test_tools.sh`: Bash integration test script
- Both files prefixed with `test_`

**Structure:**

```
weaver-5/
├── batch_fetch.py          # Main source
├── search_helper.py         # Main source
├── test_tools.py           # Integration tests
├── test_tools.sh           # Bash tests
└── test_results.json       # Test output artifact
```

## Test Structure

**Test Organization:**

Python integration test in `test_tools.py` (lines 1-136):

```python
#!/usr/bin/env python3
"""Test script to validate batch_fetch.py and search_helper.py tools"""

import subprocess
import json
import sys

# Test companies from CSV (rows 145-154)
COMPANIES = [
    "Delta Group Ab",
    "Destroy Rebuilding Company Aktiebolag",
    "Diamond Express Åkeri Ab",
    "Din Bil Sverige Ab",
    "Direktstäd I Stockholm Ab",
]

print("=" * 60)
print("Testing Tools with Sample Companies")
print("=" * 60)
print()

# Test 1: Generate search URLs
print("1. Testing search_helper.py - Generating search URLs")
print("-" * 60)
# ... test code
```

**Patterns Observed:**

**1. Sequential Test Sections:**

- Clear numbered sections: "Test 1", "Test 2", "Test 3"
- Separated by visual dividers (dashes and equals)
- Each section tests a distinct component

**2. Sample Data Setup:**

```python
COMPANIES = [
    "Delta Group Ab",
    "Destroy Rebuilding Company Aktiebolag",
    # ... 5 test companies
]
```

Location: `test_tools.py` lines 9-15

**3. Subprocess-based Testing:**

```python
try:
    result = subprocess.run(
        ["python3", "search_helper.py", company, "--allabolag", "--ratsit"],
        capture_output=True,
        text=True,
        check=True
    )
```

Location: `test_tools.py` lines 28-33

**4. Output Validation:**

```python
try:
    data = json.loads(json_line)
    allabolag_url = data['urls'].get('allabolag_se')
    if allabolag_url:
        urls.append(allabolag_url)
        print(f"✓ {company}")
    else:
        print(f"✗ {company} - No URL generated")
except Exception as e:
    print(f"✗ {company} - Error: {e}")
```

Location: `test_tools.py` lines 68-80

**5. Result Assertion via File Inspection:**

```python
with open("test_results.json", "r") as f:
    data = json.load(f)

print()
print("Results Summary:")
print(f"  Total: {data['total']}")
print(f"  Successful: {data['successful']}")
print(f"  Failed: {data['failed']}")
```

Location: `test_tools.py` lines 103-111

## Mocking

**Framework:**

- No mocking library detected (unittest.mock or pytest-mock not used)

**Patterns:**
Tests call actual external tools rather than mocking:

```python
# Direct subprocess call - no mocking
result = subprocess.run(
    ["python3", "search_helper.py", company, "--allabolag", "--ratsit"],
    capture_output=True,
    text=True,
    check=False
)
```

Location: `test_tools.py` lines 95-99

**What to Mock:**

- None - codebase does not mock external dependencies
- All tests use real tool invocations

**What NOT to Mock:**

- External tools (intentionally called for real output)
- File operations (actual JSON output files created)
- Subprocess calls (integration tests verify tool behavior)

## Fixtures and Factories

**Test Data:**

Sample company list used for testing:

```python
COMPANIES = [
    "Delta Group Ab",
    "Destroy Rebuilding Company Aktiebolag",
    "Diamond Express Åkeri Ab",
    "Din Bil Sverige Ab",
    "Direktstäd I Stockholm Ab",
]
```

Location: `test_tools.py` lines 9-15

**Location:**

- Defined at module level in test scripts
- Hardcoded test data (no factory or fixture pattern)
- Data represents real Swedish company names from CSV

## Coverage

**Requirements:**

- No test coverage requirement or measurement detected
- No `coverage.py`, `pytest-cov`, or coverage configuration

**View Coverage:**

- Not applicable (coverage not tracked)

## Test Types

**Unit Tests:**

- Not formally implemented
- Tests are integration-style (call actual external tools)

**Integration Tests:**

- `test_tools.py`: Tests pipeline of search_helper → batch_fetch
- `test_tools.sh`: Bash integration test (1810 bytes, purpose unclear from git status)
- Validates end-to-end tool functionality with real data

**E2E Tests:**

- `ralph.sh`: Main batch processing loop acts as E2E test harness
- Processes multiple companies in batches
- Validates workflow: CSV read → company processing → git commit
- Location: `weaver-5/ralph.sh` (lines 1-121)

## Common Patterns

**Subprocess Testing:**

```python
try:
    result = subprocess.run(
        ["python3", "batch_fetch.py", "--delay", "2.0", "--verbose", "--output", "test_results.json"] + urls[:3],
        text=True,
        check=False
    )
except Exception as e:
    print(f"✗ Error running batch_fetch: {e}")
```

Location: `test_tools.py` lines 95-130

**JSON Output Validation:**
Tests verify JSON output files are created and parseable:

```python
try:
    with open("test_results.json", "r") as f:
        data = json.load(f)

    print(f"  Total: {data['total']}")
    print(f"  Successful: {data['successful']}")
except json.JSONDecodeError as e:
    print(f"✗ Error parsing results: {e}")
```

Location: `test_tools.py` lines 102-127

**Tool Output Parsing:**
Extract and parse JSON from multi-line subprocess output:

```python
# Find JSON object boundaries
for i, line in enumerate(lines):
    if '{' in line and json_start is None:
        json_start = i
        brace_count = line.count('{') - line.count('}')
    elif json_start is not None:
        brace_count += line.count('{') - line.count('}')
        if brace_count == 0:
            json_end = i + 1
            break

if json_start is not None:
    json_lines = lines[json_start:json_end]
    json_text = '\n'.join(json_lines)
    data = json.loads(json_text)
```

Location: `test_tools.py` lines 45-62

**Test Artifact Output:**

```python
# Tests write results to file for inspection
result = subprocess.run(
    ["python3", "batch_fetch.py", "--delay", "2.0", "--verbose", "--output", "test_results.json"],
    text=True,
)

# Then read and assert on the file
with open("test_results.json", "r") as f:
    data = json.load(f)
```

Location: `test_tools.py` lines 95-96, 103-104

**Bash Testing Pattern:**
`test_tools.sh` exists but content not analyzed (may follow similar subprocess pattern)

## Running Tests

**Python Integration Tests:**

```bash
python test_tools.py
```

**Expected Output:**

- Section headers with test names
- Checkmark/X indicators for pass/fail
- Summary statistics
- File paths to results

**Example Output Structure:**

```
============================================================
Testing Tools with Sample Companies
============================================================

1. Testing search_helper.py - Generating search URLs
------------------------------------------------------------
✓ Delta Group Ab
  → https://www.allabolag.se/what/...
✗ Destroy Rebuilding Company Aktiebolag - No URL generated

2. Testing batch_fetch.py - Fetching URLs
------------------------------------------------------------
Results Summary:
  Total: 3
  Successful: 2
  Failed: 1
  Blocked: 0
```

---

_Testing analysis: 2026-01-22_
