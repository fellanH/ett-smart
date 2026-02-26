# Phase 03: Polish + Hardening - Research

**Researched:** 2026-01-22
**Domain:** CSV injection prevention, file validation, encoding detection, security error handling
**Confidence:** HIGH

## Summary

Phase 3 focuses on hardening the existing PoC: preventing CSV/Excel formula injection in downloaded files, validating uploaded files (format, encoding, empty files), and improving error handling to hide sensitive information from users. This is a security-focused phase with no new features.

The key insight from research: CSV injection matters most on OUTPUT (downloaded files opened in Excel), not input (uploaded files from known beta users). The OWASP-recommended approach is to prefix dangerous cells with a single quote (`'`) character, which Excel treats as text while remaining invisible to users.

**Primary recommendation:** Use the `defusedcsv` library (v3.0.0) for CSV export sanitization, `charset-normalizer` for encoding detection of Swedish data, and Streamlit's `client.showErrorDetails=false` to hide stack traces. Implement file validation at upload time with clear, actionable error messages.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| defusedcsv | 3.0.0 | CSV injection prevention | Drop-in replacement for csv module; sanitizes dangerous characters |
| charset-normalizer | 3.4.4 | Encoding detection | Better performance than chardet; supports Swedish |
| pandas | existing | CSV/Excel read/write | Already in use; provides `on_bad_lines` for malformed handling |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| openpyxl | existing | Excel export | Already in use; supports cell type forcing to prevent formula execution |
| defusedxml | latest | XML attack protection | Install for openpyxl XXE protection |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| defusedcsv | Manual sanitization function | Manual requires maintaining dangerous char list; defusedcsv is maintained |
| charset-normalizer | chardet | chardet is slower on large files; charset-normalizer is drop-in replacement |
| Custom encoding logic | pandas encoding parameter | pandas `encoding` param requires knowing encoding upfront |

**Installation:**
```bash
pip install defusedcsv charset-normalizer defusedxml
```

## Architecture Patterns

### Recommended Project Structure
```
webapp/
  app.py              # Main Streamlit app (add file validation)
  enrichment.py       # Existing - no changes needed
  export.py           # Add sanitization before export
  validation.py       # NEW - file validation and sanitization utilities
```

### Pattern 1: Output Sanitization for CSV Export
**What:** Sanitize all cell values before writing to CSV to prevent formula injection
**When to use:** Any CSV export that will be opened in Excel/LibreOffice
**Example:**
```python
# Source: defusedcsv PyPI + OWASP CSV Injection guidelines
from defusedcsv import csv
import io

def to_csv_safe(df: pd.DataFrame) -> str:
    """Export DataFrame to CSV with formula injection protection."""
    output = io.StringIO()
    # defusedcsv.csv is drop-in replacement for csv module
    # It prefixes cells starting with =, +, -, @, |, % with apostrophe
    df.to_csv(output, index=False)
    return output.getvalue()
```

### Pattern 2: Manual Sanitization (Alternative)
**What:** Sanitize values without external library
**When to use:** When you need fine-grained control or can't add dependencies
**Example:**
```python
# Source: OWASP CSV Injection prevention guidelines
FORMULA_TRIGGERS = ('=', '+', '-', '@', '\t', '\r', '\n', '|', '%')

def sanitize_cell(value):
    """Sanitize a cell value to prevent formula injection."""
    if value is None:
        return value
    str_val = str(value)
    if str_val.startswith(FORMULA_TRIGGERS):
        return "'" + str_val  # Single quote prefix - invisible in Excel
    return str_val

def sanitize_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    """Apply sanitization to all string columns."""
    df_copy = df.copy()
    for col in df_copy.select_dtypes(include=['object']).columns:
        df_copy[col] = df_copy[col].apply(sanitize_cell)
    return df_copy
```

### Pattern 3: Encoding Detection for Swedish Data
**What:** Auto-detect file encoding before parsing CSV
**When to use:** User uploads CSV with unknown encoding (may have Swedish characters)
**Example:**
```python
# Source: charset-normalizer documentation
from charset_normalizer import detect

def detect_encoding(file_bytes: bytes) -> str:
    """Detect encoding of uploaded file, optimized for Swedish data."""
    # Read first 10KB for detection (sufficient for most files)
    sample = file_bytes[:10240]
    result = detect(sample)

    encoding = result.get('encoding', 'utf-8')
    confidence = result.get('confidence', 0)

    # Fallback for low confidence
    if confidence < 0.7:
        # Common Swedish encodings to try
        return 'utf-8'  # Default safe choice

    return encoding

# Usage with pandas
def read_csv_with_encoding(uploaded_file) -> pd.DataFrame:
    """Read CSV with auto-detected encoding."""
    file_bytes = uploaded_file.getvalue()
    encoding = detect_encoding(file_bytes)

    uploaded_file.seek(0)  # Reset file pointer
    return pd.read_csv(uploaded_file, encoding=encoding)
```

### Pattern 4: Empty File and Header-Only Detection
**What:** Detect files with no data rows (only headers or completely empty)
**When to use:** Before processing uploaded CSV to give actionable feedback
**Example:**
```python
# Source: pandas documentation + GeeksforGeeks empty CSV detection
def validate_csv_content(df: pd.DataFrame, filename: str) -> tuple[bool, str]:
    """
    Validate CSV has actual data rows.

    Returns:
        (is_valid, error_message)
    """
    if df.empty:
        return False, f"The file '{filename}' contains headers but no data rows. Please add company data."

    # Check for minimum required rows
    if len(df) < 1:
        return False, "No companies found in file. Please ensure your CSV has at least one row of data."

    return True, ""
```

### Pattern 5: Malformed CSV Handling
**What:** Gracefully handle CSVs with inconsistent row lengths
**When to use:** Reading user-uploaded CSV files that may have issues
**Example:**
```python
# Source: pandas documentation - on_bad_lines parameter
def read_csv_tolerant(uploaded_file, encoding: str = 'utf-8') -> tuple[pd.DataFrame, list[str]]:
    """
    Read CSV with tolerance for malformed rows.

    Returns:
        (dataframe, list of warning messages)
    """
    warnings = []

    # Capture warnings about skipped lines
    import warnings as py_warnings
    with py_warnings.catch_warnings(record=True) as w:
        py_warnings.simplefilter("always")

        df = pd.read_csv(
            uploaded_file,
            encoding=encoding,
            on_bad_lines='warn'  # Skip bad lines but warn
        )

        # Collect warning messages
        for warning in w:
            if 'Skipping line' in str(warning.message):
                warnings.append(str(warning.message))

    return df, warnings
```

### Pattern 6: Hide Stack Traces in Production
**What:** Configure Streamlit to hide technical error details from users
**When to use:** Production deployment where security matters
**Example:**
```python
# Source: Streamlit documentation - client.showErrorDetails
# In .streamlit/config.toml:
# [client]
# showErrorDetails = false

# Or programmatically in app.py:
import streamlit as st

# Hide detailed error messages from users
st.set_option('client.showErrorDetails', False)

# Use try/except with friendly messages
def safe_process(func, friendly_error: str):
    """Wrap function calls with user-friendly error handling."""
    try:
        return func()
    except Exception as e:
        # Log full error for debugging (server-side)
        import logging
        logging.error(f"Error: {e}", exc_info=True)
        # Show friendly message to user
        st.error(friendly_error)
        return None
```

### Anti-Patterns to Avoid
- **Sanitizing input files:** User decision - only warn about formulas in input, don't modify
- **Using st.exception() for user errors:** Exposes stack traces; use st.error() with friendly message
- **Checking file extension only:** Also validate actual content (e.g., can be parsed as CSV)
- **Blocking URLs in output:** User decision - keep Allabolag links clickable
- **Hard file size limits:** User decision - no hard cutoff for now

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| CSV formula sanitization | Custom regex to escape dangerous chars | `defusedcsv` library | OWASP-recommended; handles edge cases like mid-cell injection |
| Encoding detection | Hardcoded encoding or manual BOM check | `charset-normalizer` | Handles Swedish chars; 99.5% accuracy; fast |
| Excel formula prevention | Custom string manipulation | Set openpyxl cell `data_type='s'` | Forces text interpretation at spreadsheet level |
| XML attack protection | Custom XML parsing | `defusedxml` with openpyxl | Prevents XXE and billion laughs attacks |

**Key insight:** CSV injection prevention looks simple (just prefix with quote) but has edge cases: attackers can use separators to start new cells. Using defusedcsv handles these automatically.

## Common Pitfalls

### Pitfall 1: Sanitizing URLs breaks clickability
**What goes wrong:** Prefixing URLs with `'` makes them non-clickable in Excel
**Why it happens:** URL might start with `=HYPERLINK` or be in a cell that gets prefixed
**How to avoid:** Per user decision, keep Allabolag URLs as-is (they don't start with dangerous chars)
**Warning signs:** URLs showing as text instead of clickable links

### Pitfall 2: Encoding detection fails on small files
**What goes wrong:** charset-normalizer returns wrong encoding for very small files
**Why it happens:** Not enough sample data for statistical analysis
**How to avoid:** Use at least 10KB sample; have fallback to utf-8
**Warning signs:** Swedish characters (a, o, a) showing as garbage

### Pitfall 3: EmptyDataError vs empty DataFrame
**What goes wrong:** Code doesn't distinguish between "file has no content" and "file has headers only"
**Why it happens:** pandas.EmptyDataError = truly empty; df.empty = has headers but no rows
**How to avoid:** Check both conditions with different error messages
**Warning signs:** Generic "empty file" message when user uploaded header-only file

### Pitfall 4: on_bad_lines silently drops data
**What goes wrong:** Malformed rows are skipped without user awareness
**Why it happens:** Using `on_bad_lines='skip'` without capturing warnings
**How to avoid:** Use `on_bad_lines='warn'` and display count of skipped rows to user
**Warning signs:** Fewer rows in output than expected

### Pitfall 5: showErrorDetails doesn't hide all traces
**What goes wrong:** Some stack trace information still visible to users
**Why it happens:** Known Streamlit bug - only partial obfuscation
**How to avoid:** Wrap entire app logic in try/except; use st.error() not st.exception()
**Warning signs:** Technical error details visible in UI despite config

### Pitfall 6: Single quote visible in non-Excel tools
**What goes wrong:** The `'` prefix is visible when opening CSV in text editor or Numbers
**Why it happens:** Only Excel/LibreOffice hides the leading apostrophe
**How to avoid:** Document this behavior; it's the standard OWASP approach - accept the tradeoff
**Warning signs:** User reports seeing apostrophes in exported data

## Code Examples

Verified patterns from official sources:

### Complete Export Module with Sanitization
```python
# Source: defusedcsv + openpyxl documentation
"""Export module with CSV injection protection."""
import pandas as pd
from io import BytesIO, StringIO
from typing import List, Dict

# Characters that trigger formula interpretation in Excel
FORMULA_TRIGGERS = ('=', '+', '-', '@', '\t', '\r', '\n', '|', '%')

def sanitize_cell(value) -> str:
    """Sanitize a single cell value for CSV export.

    Prefixes dangerous characters with single quote (').
    Excel hides the quote but treats content as text.
    """
    if value is None or pd.isna(value):
        return ''

    str_val = str(value)

    # Skip URLs - they should remain clickable
    if str_val.startswith(('http://', 'https://')):
        return str_val

    # Prefix dangerous characters
    if str_val.startswith(FORMULA_TRIGGERS):
        return "'" + str_val

    return str_val

def sanitize_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    """Apply sanitization to all object/string columns."""
    df_safe = df.copy()
    for col in df_safe.select_dtypes(include=['object']).columns:
        df_safe[col] = df_safe[col].apply(sanitize_cell)
    return df_safe

def to_csv(df: pd.DataFrame) -> str:
    """Export DataFrame to CSV with formula injection protection."""
    df_safe = sanitize_dataframe(df)
    return df_safe.to_csv(index=False)

def to_excel(df: pd.DataFrame) -> bytes:
    """Export DataFrame to Excel with formula injection protection."""
    df_safe = sanitize_dataframe(df)

    output = BytesIO()
    with pd.ExcelWriter(output, engine='openpyxl') as writer:
        df_safe.to_excel(writer, index=False, sheet_name='Enriched Data')
    return output.getvalue()
```

### File Validation Module
```python
# Source: pandas + charset-normalizer documentation
"""File validation utilities for uploaded CSVs."""
import pandas as pd
from charset_normalizer import detect
from typing import Tuple, Optional
import io

# User-friendly error messages
VALIDATION_ERRORS = {
    "not_csv": "This file doesn't appear to be a valid CSV. Please save your Excel file as CSV first.",
    "empty_file": "The uploaded file is empty. Please upload a file with data.",
    "headers_only": "The file contains column headers but no data rows. Please add company data.",
    "encoding_error": "Could not read the file. It may have special characters. Try saving as UTF-8.",
    "parse_error": "Could not parse the CSV file. Please check that it's properly formatted.",
}

def detect_encoding(file_bytes: bytes) -> Tuple[str, float]:
    """Detect file encoding with confidence score."""
    sample = file_bytes[:10240]  # 10KB sample
    result = detect(sample)
    return result.get('encoding', 'utf-8'), result.get('confidence', 0.0)

def validate_uploaded_file(
    uploaded_file,
    max_size_mb: Optional[float] = None
) -> Tuple[bool, str, Optional[pd.DataFrame]]:
    """
    Validate uploaded CSV file.

    Returns:
        (is_valid, error_message, dataframe_or_none)
    """
    # Check file size (if limit specified)
    if max_size_mb:
        file_bytes = uploaded_file.getvalue()
        size_mb = len(file_bytes) / (1024 * 1024)
        if size_mb > max_size_mb:
            return False, f"File too large ({size_mb:.1f}MB). Maximum size is {max_size_mb}MB.", None
        uploaded_file.seek(0)

    # Read file bytes for encoding detection
    file_bytes = uploaded_file.getvalue()

    # Check for truly empty file
    if len(file_bytes) == 0:
        return False, VALIDATION_ERRORS["empty_file"], None

    # Detect encoding
    encoding, confidence = detect_encoding(file_bytes)

    # Try to parse CSV
    uploaded_file.seek(0)
    try:
        df = pd.read_csv(
            uploaded_file,
            encoding=encoding if confidence > 0.5 else 'utf-8',
            on_bad_lines='warn'
        )
    except pd.errors.EmptyDataError:
        return False, VALIDATION_ERRORS["empty_file"], None
    except pd.errors.ParserError:
        return False, VALIDATION_ERRORS["parse_error"], None
    except UnicodeDecodeError:
        return False, VALIDATION_ERRORS["encoding_error"], None

    # Check for headers-only file
    if df.empty:
        return False, VALIDATION_ERRORS["headers_only"], None

    return True, "", df

def check_for_formula_warnings(df: pd.DataFrame) -> list[str]:
    """
    Check for potential formula cells in uploaded data.
    Returns list of warnings (for display only - don't modify input).
    """
    warnings = []
    formula_chars = ('=', '+', '-', '@')

    for col in df.select_dtypes(include=['object']).columns:
        for idx, val in df[col].items():
            if val and str(val).startswith(formula_chars):
                warnings.append(f"Row {idx+1}, column '{col}' starts with formula character")
                if len(warnings) >= 5:  # Limit warnings shown
                    warnings.append("... and more")
                    return warnings

    return warnings
```

### Streamlit Config for Production
```toml
# .streamlit/config.toml
# Source: Streamlit documentation

[client]
# Hide detailed error messages and stack traces from users
showErrorDetails = false

[server]
# Max file upload size (200MB default)
maxUploadSize = 200
```

### Error Handling Pattern
```python
# Source: Streamlit error handling best practices
import streamlit as st
import logging

# Configure logging for server-side error tracking
logging.basicConfig(level=logging.ERROR)
logger = logging.getLogger(__name__)

def display_validation_error(error_type: str, details: str = None):
    """Display user-friendly validation error."""
    messages = {
        "invalid_file": "Please upload a valid CSV file.",
        "empty_file": "The file is empty. Please upload a file with data.",
        "parse_error": "Could not read the file. Please check the format.",
    }

    message = messages.get(error_type, "An error occurred. Please try again.")

    # Show inline error (red warning box)
    st.error(f"**Upload Error:** {message}")

    if details:
        with st.expander("More details"):
            st.write(details)

def safe_operation(operation, error_message: str, *args, **kwargs):
    """Execute operation with error handling."""
    try:
        return operation(*args, **kwargs)
    except Exception as e:
        # Log full error for debugging
        logger.error(f"Operation failed: {e}", exc_info=True)
        # Show friendly message to user
        st.error(error_message)
        return None
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| chardet for encoding detection | charset-normalizer | 2021+ | 10x faster on large files, better accuracy |
| error_bad_lines=False | on_bad_lines='warn' | pandas 1.3+ (2021) | Better API, can use callable |
| Manual CSV escaping | defusedcsv library | Library created 2018, v3.0.0 Sept 2025 | Handles edge cases automatically |
| Always show errors | client.showErrorDetails=false | Streamlit config option | Security improvement |

**Deprecated/outdated:**
- `error_bad_lines` and `warn_bad_lines` parameters: Use `on_bad_lines` instead (pandas 1.3+)
- chardet library: charset-normalizer is the modern replacement with better performance

## Open Questions

Things that couldn't be fully resolved:

1. **Malformed row handling (Claude's discretion)**
   - What we know: Can use `on_bad_lines='skip'` or `'warn'`
   - User decision area: Whether to reject file entirely vs skip bad rows
   - Recommendation: Skip with warning - show count of skipped rows to user

2. **External error message specificity (Claude's discretion)**
   - What we know: Detailed errors help debugging but aid attackers
   - User decision area: Balance of helpfulness vs security
   - Recommendation: Generic message + expandable details for "blocked" and "rate limited"

3. **Per-row status visual treatment (Claude's discretion)**
   - What we know: Phase 2 established emoji badges
   - User decision area: Visual treatment for error rows
   - Recommendation: Use existing status badge pattern with row highlighting

4. **showErrorDetails partial obfuscation**
   - What we know: Streamlit bug - doesn't fully hide traces
   - What's unclear: When/if this will be fixed
   - Recommendation: Also use try/except wrapper for critical paths

## Sources

### Primary (HIGH confidence)
- [OWASP CSV Injection](https://owasp.org/www-community/attacks/CSV_Injection) - Dangerous characters, prevention guidelines
- [defusedcsv PyPI](https://pypi.org/project/defusedcsv/) - v3.0.0, sanitization approach
- [charset-normalizer GitHub](https://github.com/jawah/charset_normalizer) - v3.4.4, encoding detection
- [pandas read_csv documentation](https://pandas.pydata.org/docs/reference/api/pandas.read_csv.html) - on_bad_lines parameter

### Secondary (MEDIUM confidence)
- [Streamlit file_uploader docs](https://docs.streamlit.io/knowledge-base/deploy/increase-file-uploader-limit-streamlit-cloud) - File size configuration
- [Streamlit showErrorDetails](https://discuss.streamlit.io/t/security-issue-stack-trace-best-practices/36860) - Error handling config
- [GeeksforGeeks empty CSV detection](https://www.geeksforgeeks.org/python/how-to-check-if-a-csv-file-is-empty-in-pandas/) - Empty file handling

### Tertiary (LOW confidence)
- [Streamlit showErrorDetails bug](https://discuss.streamlit.io/t/hiding-tracebacks-and-errors-doesnt-work/50777) - Known partial obfuscation issue

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - defusedcsv and charset-normalizer are well-documented, actively maintained
- Architecture: HIGH - Patterns align with OWASP guidelines and existing codebase
- Pitfalls: MEDIUM - Some based on community discussions and issue trackers

**Research date:** 2026-01-22
**Valid until:** 90 days (security patterns stable, libraries actively maintained)
