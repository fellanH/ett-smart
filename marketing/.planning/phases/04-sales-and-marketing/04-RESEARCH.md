# Phase 4: Sales and Marketing - Research

**Researched:** 2026-01-22
**Domain:** Streamlit web application marketing features and lead generation
**Confidence:** MEDIUM

## Summary

Streamlit provides native multi-page app support through `st.Page` and `st.navigation`, enabling clean separation between marketing landing pages and the core application. Lead capture can be implemented using Google Sheets as a lightweight backend (via `streamlit-gsheets-connection`), avoiding database complexity while maintaining PoC simplicity. CRM export formats are standardized across platforms (HubSpot, Pipedrive, Salesforce) with CSV files containing standard contact fields (First Name, Last Name, Email, Company, Phone). Analytics tracking can be achieved using either `streamlit-analytics2` (fork with active maintenance) for automatic widget tracking, or custom file-based logging using Python's standard library.

GDPR compliance for Swedish lead capture requires explicit, unticked consent checkboxes with clear language about data usage. The standard approach combines file-based storage (Google Sheets, JSON, CSV) to avoid database overhead while maintaining production readiness.

**Primary recommendation:** Use `st.navigation` with `position="hidden"` for landing page → app flow, Google Sheets for lead storage, standard CRM CSV format for exports, and `streamlit-analytics2` or custom JSON logging for analytics.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| streamlit | 1.x | Multi-page app framework | Native support for `st.Page` and `st.navigation` |
| streamlit-gsheets-connection | latest | Google Sheets integration | Official Streamlit connection for Sheets CRUD operations |
| gspread | 6.1.2+ | Google Sheets API wrapper | Powers GSheetsConnection, provides `append_row()` method |
| streamlit-analytics2 | latest | Usage analytics tracking | Actively maintained fork, fixes security issues |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| pandas | latest | Data manipulation for exports | Formatting enriched data for CRM import |
| python-dotenv | latest | Secrets management | Local development credentials |
| re (standard lib) | - | Email validation | Form field validation patterns |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Google Sheets | Airtable API | More features but requires paid plan for API access |
| streamlit-analytics2 | Custom JSON logging | More control but manual implementation |
| streamlit-analytics2 | Google Analytics | More features but privacy concerns, external dependency |
| CSV export | Excel export with openpyxl | Already implemented in prior phases |

**Installation:**
```bash
pip install streamlit-gsheets-connection gspread streamlit-analytics2
```

## Architecture Patterns

### Recommended Project Structure
```
app.py                          # Entrypoint with st.navigation
pages/
├── landing.py                  # Marketing landing page
├── enrichment.py               # Main enrichment app (existing)
└── analytics_view.py           # Admin analytics dashboard (optional)
.streamlit/
├── secrets.toml                # Google Sheets credentials (gitignored)
└── config.toml                 # App configuration
data/
└── analytics.json              # File-based analytics storage (if not using Firestore)
```

### Pattern 1: Multi-Page Navigation with Landing Page
**What:** Use `st.navigation()` to route between landing page and main app
**When to use:** When you need a marketing entry point separate from the tool itself
**Example:**
```python
# app.py (entrypoint)
# Source: https://docs.streamlit.io/develop/concepts/multipage-apps/page-and-navigation
import streamlit as st

st.set_page_config(page_title="Swedish Company Enrichment", page_icon="🇸🇪", layout="wide")

landing = st.Page("pages/landing.py", title="Home", icon="🏠", default=True)
enrichment = st.Page("pages/enrichment.py", title="Enrichment Tool", icon="🔍")
analytics_view = st.Page("pages/analytics_view.py", title="Analytics", icon="📊")

pg = st.navigation([landing, enrichment, analytics_view], position="sidebar")
pg.run()
```

### Pattern 2: Hero Section with Centered Content
**What:** Use `st.markdown()` with `unsafe_allow_html=True` for marketing layouts
**When to use:** Creating landing page hero sections with centered text and CTAs
**Example:**
```python
# pages/landing.py
# Source: https://discuss.streamlit.io/t/justifying-or-centering-text-on-streamlit/11564
import streamlit as st

st.markdown("""
    <div style='text-align: center;'>
        <h1>Swedish Company Data Enrichment</h1>
        <p style='font-size: 1.2em;'>Validate and enrich company data from Allabolag and Ratsit in seconds</p>
    </div>
""", unsafe_allow_html=True)

col1, col2, col3 = st.columns([1, 2, 1])
with col2:
    if st.button("Get Started", type="primary", use_container_width=True):
        st.switch_page("pages/enrichment.py")
```

### Pattern 3: Lead Capture to Google Sheets
**What:** Append form submissions to Google Sheets using `GSheetsConnection`
**When to use:** Collecting lead information without database setup
**Example:**
```python
# pages/landing.py - Lead capture form
# Source: https://docs.streamlit.io/develop/tutorials/databases/private-gsheet
# API reference: https://docs.gspread.org/en/latest/api/models/worksheet.html
import streamlit as st
from streamlit_gsheets import GSheetsConnection
import re
from datetime import datetime

conn = st.connection("gsheets", type=GSheetsConnection)

with st.form("lead_form"):
    st.subheader("Request Demo Access")

    name = st.text_input("Full Name*")
    email = st.text_input("Email*")
    company = st.text_input("Company")
    phone = st.text_input("Phone")
    consent = st.checkbox("I consent to my data being stored for demo access purposes*")

    submitted = st.form_submit_button("Submit Request")

    if submitted:
        # Validation
        errors = []
        if not name.strip():
            errors.append("Name is required")
        if not email.strip():
            errors.append("Email is required")
        elif not re.match(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$", email):
            errors.append("Invalid email format")
        if not consent:
            errors.append("You must consent to data storage")

        if errors:
            for error in errors:
                st.error(error)
        else:
            # Append to Google Sheets
            worksheet = conn.read(worksheet="Leads")  # Get worksheet object
            row_data = [
                datetime.now().isoformat(),
                name,
                email,
                company,
                phone,
                "Yes" if consent else "No"
            ]

            # Using underlying gspread worksheet object
            worksheet.append_row(row_data)

            st.success("Thank you! We'll be in touch soon.")
            st.balloons()
```

### Pattern 4: CRM-Ready CSV Export
**What:** Format enriched data with standard CRM field headers
**When to use:** Exporting data for import into HubSpot, Pipedrive, or Salesforce
**Example:**
```python
# Export functionality with CRM-friendly headers
# Sources:
# - https://knowledge.hubspot.com/import-and-export/set-up-your-import-file
# - https://support.pipedrive.com/en/article/importing-mapping-your-fields
import pandas as pd

def format_for_crm(enriched_data: pd.DataFrame) -> pd.DataFrame:
    """
    Convert internal data format to CRM-friendly CSV format.

    Standard CRM fields (all platforms):
    - First Name, Last Name (or Full Name)
    - Email (required for most CRMs)
    - Company/Organization
    - Phone (Work/Mobile)
    - Job Title
    - Website
    - Address, City, Postal Code, Country
    """

    crm_df = pd.DataFrame()

    # Map internal fields to CRM standard fields
    crm_df["Company"] = enriched_data["company_name"]
    crm_df["Email"] = enriched_data["contact_email"]
    crm_df["Phone"] = enriched_data["phone"]
    crm_df["Website"] = enriched_data["website"]
    crm_df["Organization Number"] = enriched_data["org_number"]
    crm_df["Address"] = enriched_data["address"]
    crm_df["City"] = enriched_data["city"]
    crm_df["Postal Code"] = enriched_data["postal_code"]
    crm_df["Country"] = "Sweden"

    # Financial data as custom fields
    crm_df["Annual Revenue"] = enriched_data["revenue"]
    crm_df["Employees"] = enriched_data["employee_count"]
    crm_df["Industry"] = enriched_data["industry"]
    crm_df["Credit Rating"] = enriched_data["credit_rating"]

    # Contact person (if available)
    crm_df["Contact Name"] = enriched_data.get("contact_name", "")
    crm_df["Job Title"] = enriched_data.get("contact_title", "")

    return crm_df

# In Streamlit app
st.download_button(
    label="Download CRM-Ready Export",
    data=format_for_crm(results_df).to_csv(index=False).encode('utf-8'),
    file_name=f"crm_export_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv",
    mime="text/csv"
)
```

### Pattern 5: Usage Analytics with streamlit-analytics2
**What:** Track page views and widget interactions with minimal code
**When to use:** Monitoring usage without complex analytics setup
**Example:**
```python
# app.py (entrypoint)
# Source: https://github.com/444B/streamlit-analytics2
import streamlit as st
import streamlit_analytics2 as streamlit_analytics

with streamlit_analytics.track(
    save_to_json="data/analytics.json",
    load_from_json="data/analytics.json"
):
    # Your app code here
    pg = st.navigation([landing, enrichment])
    pg.run()

# Access analytics at: https://your-app.com/?analytics=on
# Password protect with: track(unsafe_password="your_password")
```

### Pattern 6: Custom Analytics Logging
**What:** Manual event tracking using JSON file storage
**When to use:** When you need custom metrics beyond widget interactions
**Example:**
```python
# utils/analytics.py
import json
import os
from datetime import datetime
from pathlib import Path

ANALYTICS_FILE = Path("data/analytics.json")

def log_event(event_type: str, metadata: dict = None):
    """Log custom analytics event to JSON file."""

    # Initialize file if doesn't exist
    if not ANALYTICS_FILE.exists():
        ANALYTICS_FILE.parent.mkdir(exist_ok=True)
        events = []
    else:
        with open(ANALYTICS_FILE, 'r') as f:
            events = json.load(f)

    # Append event
    events.append({
        "timestamp": datetime.now().isoformat(),
        "event_type": event_type,
        "metadata": metadata or {}
    })

    # Write back
    with open(ANALYTICS_FILE, 'w') as f:
        json.dump(events, f, indent=2)

# Usage in app
from utils.analytics import log_event

if st.button("Enrich Companies"):
    log_event("enrichment_started", {"batch_size": len(companies)})
    # ... enrichment logic ...
    log_event("enrichment_completed", {"batch_size": len(companies), "success_count": successes})

if st.download_button("Download Results"):
    log_event("export_downloaded", {"format": "csv", "row_count": len(results)})
```

### Anti-Patterns to Avoid
- **Storing credentials in code:** Always use `.streamlit/secrets.toml` for API keys and service account credentials
- **Pre-ticked consent checkboxes:** GDPR violation for Swedish users; consent must be explicit opt-in
- **Database over-engineering:** For PoC analytics, file-based storage (JSON/Sheets) is sufficient
- **Blocking landing page:** Don't require form submission to access tool during beta testing
- **Complex analytics setup:** Start with basic tracking (page views, conversions); avoid premature optimization

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Google Sheets integration | Custom OAuth flow + API requests | `streamlit-gsheets-connection` | Official Streamlit connection handles auth, retries, caching, and secrets management |
| Email validation | Regex-only validation | `re.match()` for format + consider email-validator library | Email validation has many edge cases (international domains, special characters) |
| Analytics tracking | Custom session tracking system | `streamlit-analytics2` | Already handles widget tracking, session IDs, storage backends, and visualization |
| Multi-page routing | Session state flags + conditional rendering | `st.navigation()` and `st.Page()` | Native Streamlit feature with proper URL routing and navigation UI |
| Form validation | Manual field checks scattered throughout code | Centralized validation functions | Maintainability and consistency across forms |
| CSV encoding issues | Manual encoding handling | pandas `to_csv(encoding='utf-8')` | Handles special characters, ensures CRM compatibility |

**Key insight:** Streamlit's ecosystem has matured significantly. Most common needs (multi-page apps, external data connections, analytics) have official or well-maintained community solutions. Custom implementations add complexity without benefit for PoC-level projects.

## Common Pitfalls

### Pitfall 1: Google Sheets Write Access Confusion
**What goes wrong:** Developers assume `GSheetsConnection.read()` returns a DataFrame, then try to append rows to it
**Why it happens:** Documentation focuses on read examples; write operations require accessing the underlying `gspread` worksheet object
**How to avoid:** Use `conn.read(worksheet="SheetName")` to get worksheet object, then call `worksheet.append_row(data)` using gspread API
**Warning signs:** Errors like "DataFrame object has no attribute 'append_row'"

### Pitfall 2: GDPR Non-Compliance in Lead Forms
**What goes wrong:** Using pre-ticked consent checkboxes or bundling consent with form submission
**Why it happens:** Developers unfamiliar with Swedish/EU privacy requirements
**How to avoid:**
- Use unticked `st.checkbox()` that users must actively select
- Clearly explain what data is stored and why
- Make consent validation blocking (form won't submit without explicit consent)
- Keep marketing consent separate from service agreement
**Warning signs:** Legal requirements for Swedish market not considered in form design

### Pitfall 3: CSV Export Encoding Issues
**What goes wrong:** Special characters (Swedish ä, ö, å) appear garbled in CRM after import
**Why it happens:** Not specifying UTF-8 encoding in export
**How to avoid:** Always use `.to_csv(index=False).encode('utf-8')` in download_button
**Warning signs:** Test with Swedish company names containing special characters

### Pitfall 4: Analytics File Locking in Production
**What goes wrong:** Multiple concurrent users cause file write conflicts when using JSON-based analytics
**Why it happens:** File-based storage doesn't handle concurrent writes well
**How to avoid:**
- Use `streamlit-analytics2` which handles this internally
- For custom logging, implement file locking or switch to Firestore for production
- Accept that local JSON is PoC-only; plan migration path
**Warning signs:** Occasional analytics events not recorded under load

### Pitfall 5: Landing Page Without Clear CTA Path
**What goes wrong:** Users land on marketing page but can't find how to access the actual tool
**Why it happens:** Focus on content over navigation in design
**How to avoid:**
- Prominent "Get Started" or "Try Tool" button above the fold
- Use `st.switch_page()` to navigate from landing to enrichment app
- Consider sidebar navigation visible even on landing page
**Warning signs:** High bounce rate from landing page in analytics

### Pitfall 6: Overcomplicating Analytics for PoC
**What goes wrong:** Spending time integrating Google Analytics, setting up dashboards, tracking custom events
**Why it happens:** Wanting "real" analytics infrastructure
**How to avoid:**
- Start with `streamlit-analytics2` default tracking (page views, button clicks)
- Log only critical conversions (form submissions, exports)
- Defer advanced analytics until product-market fit is proven
**Warning signs:** More time spent on analytics than core features

## Code Examples

Verified patterns from official sources:

### Google Sheets Service Account Setup
```toml
# .streamlit/secrets.toml
# Source: https://docs.streamlit.io/develop/tutorials/databases/private-gsheet
[connections.gsheets]
spreadsheet = "https://docs.google.com/spreadsheets/d/YOUR_SPREADSHEET_ID/edit"
type = "service_account"
project_id = "your-project-id"
private_key_id = "key-id"
private_key = "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
client_email = "your-service-account@project.iam.gserviceaccount.com"
client_id = "123456789"
auth_uri = "https://accounts.google.com/o/oauth2/auth"
token_uri = "https://oauth2.googleapis.com/token"
auth_provider_x509_cert_url = "https://www.googleapis.com/oauth2/v1/certs"
client_x509_cert_url = "https://www.googleapis.com/robot/v1/metadata/x509/service-account-email"
```

### Email Validation Pattern
```python
# Source: https://medium.com/@richardhightower/article-streamlit-part-3-19c76303aa5a
import re

def validate_email(email: str) -> bool:
    """Validate email format using regex."""
    if not email.strip():
        return False
    pattern = r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    return bool(re.match(pattern, email))

# Usage in form
if submitted:
    if not validate_email(email):
        st.error("Please enter a valid email address")
    else:
        # Process form
        pass
```

### GDPR-Compliant Consent Checkbox
```python
# Source: https://www.mailerlite.com/blog/how-to-create-opt-in-forms-that-still-work-under-gdpr
consent = st.checkbox(
    "I consent to my personal data (name, email, company) being stored for the purpose of demo access. "
    "You can withdraw consent at any time by contacting [email]."
)

if submitted and not consent:
    st.error("You must provide consent to submit this form.")
```

### CRM CSV Export with Standard Headers
```python
# Sources:
# - https://knowledge.hubspot.com/import-and-export/set-up-your-import-file
# - https://support.pipedrive.com/en/article/importing-mapping-your-fields
import pandas as pd
from datetime import datetime

# HubSpot/Pipedrive standard fields
crm_export = pd.DataFrame({
    "Email": results_df["contact_email"],          # Required by most CRMs
    "Company": results_df["company_name"],         # Organization name
    "Phone": results_df["phone"],                  # Work phone
    "Website": results_df["website"],
    "Address": results_df["address"],
    "City": results_df["city"],
    "Postal Code": results_df["postal_code"],
    "Country": "Sweden",
    # Custom fields
    "Organization Number": results_df["org_number"],
    "Annual Revenue": results_df["revenue"],
    "Employees": results_df["employee_count"]
})

# UTF-8 encoding for Swedish characters
csv_data = crm_export.to_csv(index=False).encode('utf-8')

st.download_button(
    label="Download for CRM Import",
    data=csv_data,
    file_name=f"crm_export_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv",
    mime="text/csv"
)
```

### Custom Analytics View
```python
# pages/analytics_view.py - Admin dashboard
import streamlit as st
import json
import pandas as pd
from pathlib import Path

st.title("Usage Analytics")

analytics_file = Path("data/analytics.json")

if not analytics_file.exists():
    st.warning("No analytics data yet.")
else:
    with open(analytics_file) as f:
        events = json.load(f)

    # Convert to DataFrame for analysis
    df = pd.DataFrame(events)
    df['timestamp'] = pd.to_datetime(df['timestamp'])

    # Metrics
    col1, col2, col3, col4 = st.columns(4)

    with col1:
        total_events = len(df)
        st.metric("Total Events", total_events)

    with col2:
        enrichments = len(df[df['event_type'] == 'enrichment_completed'])
        st.metric("Enrichments", enrichments)

    with col3:
        exports = len(df[df['event_type'] == 'export_downloaded'])
        st.metric("Exports", exports)

    with col4:
        conversion_rate = (exports / enrichments * 100) if enrichments > 0 else 0
        st.metric("Export Rate", f"{conversion_rate:.1f}%")

    # Event timeline
    st.subheader("Event Timeline")
    event_counts = df.groupby([df['timestamp'].dt.date, 'event_type']).size().reset_index(name='count')
    st.bar_chart(event_counts.pivot(index='timestamp', columns='event_type', values='count'))
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `st.experimental_get_query_params` | `st.navigation()` and `st.Page()` | Streamlit 1.28+ (2023) | Native multi-page apps without URL hacks |
| Custom OAuth for Google Sheets | `streamlit-gsheets-connection` | 2023 | Official connection with secrets management |
| `streamlit-analytics` (original) | `streamlit-analytics2` | 2024 fork | Fixes 41 security vulnerabilities, maintains compatibility |
| Manual page routing with session state | `st.switch_page()` | Streamlit 1.28+ | Cleaner navigation between pages |
| Separate landing page HTML site | Landing page within Streamlit app | Multi-page support | Single deployment, consistent styling |

**Deprecated/outdated:**
- **streamlit-analytics (original)**: Archived/unmaintained, use `streamlit-analytics2` fork instead
- **Pre-GDPR consent patterns**: Pre-ticked checkboxes no longer legal in Sweden/EU since GDPR (May 2018)
- **Manual multi-page with session state**: Replaced by native `st.navigation()` API

## Open Questions

Things that couldn't be fully resolved:

1. **Google Sheets API Write Rate Limits**
   - What we know: Google Sheets API has rate limits (100 requests per 100 seconds per user)
   - What's unclear: How `streamlit-gsheets-connection` handles rate limiting and retries
   - Recommendation: For PoC with <100 leads/day, unlikely to hit limits. Monitor and add error handling if needed.

2. **streamlit-analytics2 Concurrent Write Handling**
   - What we know: Fork fixes deprecations and security issues
   - What's unclear: How it handles concurrent writes to JSON file in production
   - Recommendation: Test with multiple simultaneous users. Consider Firestore backend if issues arise.

3. **CRM Custom Field Mapping**
   - What we know: Standard contact fields are universal (Name, Email, Company, Phone)
   - What's unclear: How each CRM handles custom fields (Revenue, Employees, Credit Rating)
   - Recommendation: Include all enriched data as columns; users can map during CRM import. Provide field mapping guide in docs.

4. **GDPR Data Retention Requirements**
   - What we know: Consent required for storage, users can withdraw consent
   - What's unclear: Specific retention policies for lead data in Sweden
   - Recommendation: Add timestamp to leads, implement manual cleanup process. Defer automated retention until legal review.

5. **Analytics Performance at Scale**
   - What we know: JSON file-based analytics works for PoC
   - What's unclear: At what user count file-based storage becomes bottleneck
   - Recommendation: Start with JSON, monitor file size. Migrate to Firestore if analytics.json exceeds 10MB or write conflicts occur.

## Sources

### Primary (HIGH confidence)
- [Streamlit Multi-Page Apps Documentation](https://docs.streamlit.io/develop/concepts/multipage-apps/page-and-navigation) - `st.Page` and `st.navigation` API
- [Streamlit Private Google Sheets Tutorial](https://docs.streamlit.io/develop/tutorials/databases/private-gsheet) - GSheetsConnection setup
- [gspread API Documentation](https://docs.gspread.org/en/latest/api/models/worksheet.html) - `append_row()` and `append_rows()` methods
- [streamlit-analytics2 GitHub](https://github.com/444B/streamlit-analytics2) - Actively maintained fork

### Secondary (MEDIUM confidence)
- [HubSpot CSV Import Requirements](https://knowledge.hubspot.com/import-and-export/set-up-your-import-file) - CRM field standards
- [Pipedrive Field Mapping Guide](https://support.pipedrive.com/en/article/importing-mapping-your-fields) - Import format
- [GDPR Marketing Consent Requirements](https://www.mailerlite.com/blog/how-to-create-opt-in-forms-that-still-work-under-gdpr) - Checkbox compliance
- [Electronic Marketing in Sweden - DLA Piper](https://www.dlapiperdataprotection.com/index.html?t=electronic-marketing&c=SE) - Swedish GDPR requirements
- [Streamlit Form Validation Guide](https://medium.com/@richardhightower/article-streamlit-part-3-19c76303aa5a) - Email validation patterns
- [Streamlit Centering Text/Images](https://discuss.streamlit.io/t/justifying-or-centering-text-on-streamlit/11564) - Hero section layouts

### Tertiary (LOW confidence - Community/WebSearch only)
- Hero section design best practices (general web design, not Streamlit-specific)
- CRM standard field conventions (cross-verified with official docs)
- File-based analytics scalability (extrapolated from general Python practices)

## Metadata

**Confidence breakdown:**
- Standard stack: MEDIUM - Streamlit official docs verified, analytics library is maintained fork
- Architecture: MEDIUM - Multi-page apps and Google Sheets patterns verified with official docs; analytics scaling untested at production volumes
- Pitfalls: MEDIUM - GDPR requirements verified with legal sources; file locking and encoding issues based on common Python patterns
- CRM export: MEDIUM - Field standards verified across multiple CRM platforms; exact custom field handling varies

**Research date:** 2026-01-22
**Valid until:** ~30 days (Streamlit stable, CRM standards stable, GDPR requirements stable)

**Validation needed before production:**
- Test Google Sheets write performance with concurrent users
- Legal review of consent language and data retention policy
- CRM import testing with actual HubSpot/Pipedrive accounts
- Analytics file size monitoring under real traffic
