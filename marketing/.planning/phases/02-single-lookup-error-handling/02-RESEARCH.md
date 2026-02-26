# Phase 02: Single Lookup + Error Handling - Research

**Researched:** 2026-01-22
**Domain:** Streamlit single-lookup forms, status indicators, error UX, Swedish org number validation
**Confidence:** HIGH

## Summary

This phase adds single company lookup and improves error handling in the existing batch flow. Research focused on: (1) Streamlit form patterns for search input, (2) skeleton/loading placeholders, (3) status indicators with badges, (4) Swedish organization number validation, and (5) error message patterns.

The existing `enrichment.py` module already has `enrich_company()` which can be reused directly for single lookup. The main work is UI: a unified search input that auto-detects company name vs org number, loading states, and status indicators for batch results.

**Primary recommendation:** Use `st.form` for Enter-key submission, `st.empty()` with styled placeholders for skeleton loading, `st.badge` for status indicators (green/orange/red), and regex-based detection for org number vs company name input.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| streamlit | 1.44+ | UI framework | Already in use; has `st.badge` and `st.form` |
| pandas | existing | Data tables | Already in use for dataframe display |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| organisationsnummer | 1.0.1 | Validate Swedish org numbers | When auto-detecting if input is org number vs company name |
| re (stdlib) | N/A | Regex for quick org number format check | Lightweight alternative to full validation library |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `organisationsnummer` library | Regex pattern `^\d{6}-?\d{4}$` | Regex is simpler for format detection; library validates checksum too |
| `st.form` for search | Direct `st.text_input` with button | Form enables Enter key submission natively |
| Custom CSS skeleton | `st.spinner` | Spinner is simpler but doesn't reserve layout space |

**Installation:**
```bash
# Optional - only if you want Luhn checksum validation
pip install organisationsnummer
```

## Architecture Patterns

### Recommended Project Structure
```
webapp/
  app.py              # Main Streamlit app with tabs/sections
  enrichment.py       # Existing - add single lookup support (already has enrich_company)
  export.py           # Existing - results merge and export
  error_messages.py   # NEW - human-readable error message mapping
```

### Pattern 1: Unified Search Input with Auto-Detection
**What:** Single text input that detects whether user entered org number or company name
**When to use:** When same action can be triggered by different input types
**Example:**
```python
# Source: Project convention + regex validation
import re

def detect_input_type(query: str) -> str:
    """Auto-detect if input is org number or company name."""
    # Swedish org numbers: 6 digits, optional dash, 4 digits
    # Example: 5560123456 or 556012-3456
    org_pattern = r'^\d{6}-?\d{4}$'

    # Remove whitespace and check pattern
    cleaned = query.strip().replace(' ', '')

    if re.match(org_pattern, cleaned):
        return "org_number"
    return "company_name"
```

### Pattern 2: Form-Based Search with Enter Key Support
**What:** Wrap search input in `st.form` to enable Enter key submission
**When to use:** Single lookup where user types and hits Enter
**Example:**
```python
# Source: https://docs.streamlit.io/develop/concepts/architecture/forms
with st.form(key="single_lookup_form"):
    query = st.text_input(
        "Company name or organization number",
        placeholder="e.g., Volvo AB or 556012-3456",
        help="Enter a Swedish company name or 10-digit organization number"
    )
    submitted = st.form_submit_button("Search", type="primary")

if submitted and query:
    # Process search
    pass
```

### Pattern 3: Skeleton Placeholder with st.empty()
**What:** Reserve layout space during loading with styled placeholder
**When to use:** When you want to prevent layout shift during data fetch
**Example:**
```python
# Source: https://docs.streamlit.io/develop/api-reference/layout/st.empty
def show_skeleton_placeholder():
    """Display a gray placeholder while loading."""
    st.markdown("""
        <style>
        .skeleton-box {
            background: linear-gradient(90deg, #e0e0e0 25%, #f0f0f0 50%, #e0e0e0 75%);
            background-size: 200% 100%;
            animation: shimmer 1.5s infinite;
            border-radius: 4px;
            height: 200px;
        }
        @keyframes shimmer {
            0% { background-position: -200% 0; }
            100% { background-position: 200% 0; }
        }
        </style>
        <div class="skeleton-box"></div>
    """, unsafe_allow_html=True)

# Usage
result_placeholder = st.empty()

if searching:
    with result_placeholder.container():
        show_skeleton_placeholder()

    # Fetch data
    result = enrich_company(query)

    # Replace skeleton with real content
    with result_placeholder.container():
        display_result(result)
```

### Pattern 4: Status Badges with st.badge
**What:** Colored badges for success/partial/failed status
**When to use:** Per-row status indicators in batch results
**Example:**
```python
# Source: https://docs.streamlit.io/develop/api-reference/text/st.badge
# Available in Streamlit 1.44+

def get_status_badge(status: str) -> str:
    """Return markdown badge for status."""
    badges = {
        "success": ":green-badge[:material/check: Success]",
        "partial": ":orange-badge[:material/warning: Partial]",
        "failed": ":red-badge[:material/close: Failed]",
        "blocked": ":orange-badge[:material/block: Blocked]",
        "not_found": ":gray-badge[:material/search_off: Not Found]",
        "error": ":red-badge[:material/error: Error]"
    }
    return badges.get(status, ":gray-badge[Unknown]")

# Usage in dataframe display
st.markdown(get_status_badge(row["status"]))
```

### Pattern 5: Error Message Mapping
**What:** Translate technical errors to human-readable messages
**When to use:** Any user-facing error display
**Example:**
```python
# Source: Project error handling pattern from CONVENTIONS.md
ERROR_MESSAGES = {
    "blocked": "This company's page is temporarily unavailable. Try again later.",
    "not_found": "No company found matching your search. Check the spelling or try the organization number.",
    "timeout": "The search took too long. Please try again.",
    "connection": "Could not connect to the data source. Check your internet connection.",
    "invalid_input": "Please enter a valid company name or 10-digit organization number.",
}

def get_friendly_error(status: str, raw_error: str = None) -> str:
    """Convert technical error to user-friendly message."""
    if status in ERROR_MESSAGES:
        return ERROR_MESSAGES[status]
    if raw_error and "HTTP 404" in raw_error:
        return ERROR_MESSAGES["not_found"]
    if raw_error and "HTTP 403" in raw_error:
        return ERROR_MESSAGES["blocked"]
    return f"Something went wrong. Details: {raw_error or 'Unknown error'}"
```

### Anti-Patterns to Avoid
- **Showing HTTP status codes to users:** "HTTP 404" should become "Company not found"
- **Showing stack traces:** Use st.error() with friendly message, not st.exception()
- **Not reserving space for results:** Use st.empty() to prevent layout shift
- **Separate org number and name fields:** Decision was unified input field
- **Re-fetching on every UI interaction:** Use session_state caching (already established)

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Swedish org number validation | Custom regex + Luhn check | `organisationsnummer` library or basic regex for format detection | Library handles edge cases (samordningsnummer, coordination numbers) |
| Loading animation | Custom JavaScript | `st.spinner` or CSS animation in st.markdown | Browser compatibility, Streamlit quirks |
| Form Enter-key handling | on_change callbacks with key detection | `st.form` with `st.form_submit_button` | Native behavior, fewer bugs |
| Status indicator colors | Custom CSS classes | `st.badge` with built-in colors | Consistent with Streamlit theme |

**Key insight:** Streamlit 1.44+ has `st.badge` which handles status indicators well. Don't build custom components.

## Common Pitfalls

### Pitfall 1: Form Callback Limitations
**What goes wrong:** Trying to use callbacks inside forms doesn't work as expected
**Why it happens:** Only `st.form_submit_button` can have callbacks in forms; other widgets cannot
**How to avoid:** Process form results after the form block, not inside callbacks
**Warning signs:** "Widget X cannot be used in a form" errors

### Pitfall 2: Layout Shift on Data Load
**What goes wrong:** UI jumps around when results appear
**Why it happens:** `st.empty()` doesn't reserve space by default
**How to avoid:** Use skeleton placeholder with fixed height, or use `st.container` with min-height CSS
**Warning signs:** Content jumping when search completes

### Pitfall 3: Session State Key Conflicts
**What goes wrong:** Single lookup and batch results overwrite each other
**Why it happens:** Using same session_state key for different features
**How to avoid:** Use namespaced keys: `single_lookup_result`, `batch_results`
**Warning signs:** Data appearing in wrong section of UI

### Pitfall 4: st.badge Not Available
**What goes wrong:** `st.badge` throws AttributeError
**Why it happens:** Using Streamlit version < 1.44
**How to avoid:** Check Streamlit version; use markdown badges as fallback
**Warning signs:** `AttributeError: module 'streamlit' has no attribute 'badge'`

### Pitfall 5: Org Number Format Variations
**What goes wrong:** User enters "556012 3456" or "SE5560123456" and validation fails
**Why it happens:** Not normalizing input before validation
**How to avoid:** Strip whitespace, remove common prefixes (SE, VAT), handle both dash and no-dash formats
**Warning signs:** Valid org numbers rejected as company names

## Code Examples

Verified patterns from official sources:

### Single Lookup Form (Complete Implementation)
```python
# Source: Streamlit docs + project patterns
import streamlit as st
import re

def single_lookup_section():
    st.header("Single Company Lookup")

    with st.form(key="single_lookup_form"):
        query = st.text_input(
            "Search",
            placeholder="Company name or org number (e.g., Volvo AB or 556012-3456)",
            help="Enter a Swedish company name or 10-digit organization number"
        )
        submitted = st.form_submit_button("Search", type="primary")

    if submitted:
        if not query or not query.strip():
            st.warning("Please enter a company name or organization number")
            return

        # Auto-detect input type
        input_type = detect_input_type(query)

        # Show loading state
        with st.spinner(f"Searching for {query}..."):
            result = enrich_company(
                company_name=query if input_type == "company_name" else None,
                org_number=query if input_type == "org_number" else None
            )

        # Display result
        display_single_result(result)

def detect_input_type(query: str) -> str:
    """Detect if query is org number or company name."""
    cleaned = query.strip().replace(' ', '').replace('-', '')
    # Remove common prefixes
    if cleaned.upper().startswith('SE'):
        cleaned = cleaned[2:]
    # Check if it's 10 digits
    if re.match(r'^\d{10}$', cleaned):
        return "org_number"
    return "company_name"
```

### Status Indicators for Batch Results
```python
# Source: Streamlit 1.44+ st.badge documentation
def display_status_column(df):
    """Add status badges to dataframe display."""
    # Create status display column
    def format_status(status):
        if status == "success":
            return ":green-badge[:material/check: Success]"
        elif status == "blocked":
            return ":orange-badge[:material/block: Blocked]"
        elif status == "not_found":
            return ":gray-badge[:material/search_off: Not Found]"
        else:
            return ":red-badge[:material/error: Error]"

    # Display with custom formatting
    for idx, row in df.iterrows():
        cols = st.columns([3, 1, 3])
        cols[0].write(row["company_name"])
        cols[1].markdown(format_status(row["status"]))
        cols[2].write(row.get("error_message", ""))
```

### Empty State with Helpful Tips
```python
# Source: Project UX decision from CONTEXT.md
def display_empty_state(query: str):
    """Show helpful message when no results found."""
    st.info(f"No company found for '{query}'")

    st.markdown("""
    **Tips for better results:**
    - Try the exact legal company name (e.g., "Volvo Car AB" not "Volvo")
    - Use the 10-digit organization number if you have it
    - Check spelling and remove extra spaces
    """)
```

### Error Message Translation
```python
# Source: Project CONVENTIONS.md error handling patterns
ERROR_MAP = {
    "blocked": {
        "title": "Access Temporarily Blocked",
        "message": "The data source is currently limiting requests. Please try again in a few minutes.",
        "icon": ":material/hourglass_empty:"
    },
    "not_found": {
        "title": "Company Not Found",
        "message": "We couldn't find a company matching your search. Try the organization number instead.",
        "icon": ":material/search_off:"
    },
    "error": {
        "title": "Something Went Wrong",
        "message": "An unexpected error occurred. Please try again.",
        "icon": ":material/error:"
    }
}

def show_error(status: str, technical_error: str = None):
    """Display user-friendly error with optional technical details."""
    error_info = ERROR_MAP.get(status, ERROR_MAP["error"])

    st.error(f"{error_info['icon']} **{error_info['title']}**\n\n{error_info['message']}")

    # Expandable technical details for debugging
    if technical_error:
        with st.expander("Technical details"):
            st.code(technical_error)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Custom colored text for status | `st.badge` component | Streamlit 1.44 (Jan 2025) | Native themed badges, less CSS |
| `st.spinner` only for loading | Skeleton placeholders | Growing pattern | Better UX, no layout shift |
| Multiple input fields | Single unified input | UX best practice | Simpler interface |

**Deprecated/outdated:**
- `st.beta_*` containers: Use stable versions (`st.container`, `st.columns`)
- Custom emoji badges: Use `st.badge` with Material icons

## Open Questions

Things that couldn't be fully resolved:

1. **Multiple match handling (Claude's discretion)**
   - What we know: Both `st.radio` and `st.selectbox` can present options
   - What's unclear: Whether Allabolag returns multiple matches for name searches
   - Recommendation: Start with "show first/best match"; add selection UI if needed after testing

2. **Search history (Claude's discretion)**
   - What we know: Can store in `st.session_state.search_history = []`
   - What's unclear: Value vs. complexity tradeoff
   - Recommendation: Skip for initial implementation; simple to add later

3. **st.skeleton() native support**
   - What we know: PR #7598 added internal skeletons; Issue #8032 proposes `st.skeleton()` API
   - What's unclear: If/when it will be released
   - Recommendation: Use CSS-based skeleton with `st.markdown` for now

## Sources

### Primary (HIGH confidence)
- [Streamlit st.text_input docs](https://docs.streamlit.io/develop/api-reference/widgets/st.text_input) - Form input parameters and usage
- [Streamlit st.form docs](https://docs.streamlit.io/develop/concepts/architecture/forms) - Enter key submission, form batching
- [Streamlit st.badge docs](https://docs.streamlit.io/develop/api-reference/text/st.badge) - Status indicator badges (v1.44+)
- [Streamlit st.empty docs](https://docs.streamlit.io/develop/api-reference/layout/st.empty) - Placeholder pattern
- [organisationsnummer Python package](https://github.com/organisationsnummer/python) - v1.0.1, Swedish org number validation

### Secondary (MEDIUM confidence)
- [Streamlit status display docs](https://docs.streamlit.io/develop/api-reference/status) - st.spinner, st.progress, callout messages
- [Streamlit dataframe column config](https://docs.streamlit.io/develop/concepts/design/dataframes) - Column configuration options
- [Swedish org number format](https://organisationsnummer.dev/) - Format specification

### Tertiary (LOW confidence)
- [st.skeleton() proposal (GitHub #8032)](https://github.com/streamlit/streamlit/issues/8032) - Native skeleton API (not yet released)
- [Error boundary pattern](https://github.com/K-dash/st-error-boundary) - Third-party error handling decorator

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All components verified in official Streamlit docs
- Architecture: HIGH - Patterns align with existing codebase conventions
- Pitfalls: MEDIUM - Based on documentation limitations sections and community discussions

**Research date:** 2026-01-22
**Valid until:** 60 days (Streamlit stable, patterns established)
