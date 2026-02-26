"""
Company Enrichment Tool - Streamlit Page

Provides single company lookup and batch CSV enrichment functionality.
"""

import re
import streamlit as st
import pandas as pd
from datetime import datetime
import sys
from pathlib import Path

# Add webapp to path for imports
webapp_dir = Path(__file__).parent.parent
if str(webapp_dir) not in sys.path:
    sys.path.insert(0, str(webapp_dir))

from enrichment import enrich_batch, enrich_company, get_friendly_error
from export import merge_results_with_original, to_csv, to_excel, to_crm_csv
from validation import validate_csv_file
from utils.analytics import log_event


def get_status_badge(status: str) -> str:
    """Return emoji indicator for status.

    Args:
        status: Status code (success, blocked, not_found, error, pending)

    Returns:
        Emoji badge string for display
    """
    badges = {
        "success": ":white_check_mark: Success",
        "partial": ":warning: Partial",
        "blocked": ":no_entry: Blocked",
        "not_found": ":mag: Not Found",
        "error": ":x: Error",
        "pending": ":hourglass_flowing_sand: Pending",
    }
    return badges.get(status, ":question: Unknown")


def detect_input_type(query: str) -> str:
    """Auto-detect if input is org number or company name."""
    # Swedish org numbers: 6 digits, optional dash, 4 digits
    # Example: 5560123456 or 556012-3456
    org_pattern = r'^\d{6}-?\d{4}$'
    cleaned = query.strip().replace(' ', '')
    if re.match(org_pattern, cleaned):
        return "org_number"
    return "company_name"


def show_skeleton_placeholder():
    """Display shimmer loading placeholder."""
    st.markdown("""
        <style>
        .skeleton-box {
            background: linear-gradient(90deg, #d4dcc4 25%, #F0F3E1 50%, #d4dcc4 75%);
            background-size: 200% 100%;
            animation: shimmer 1.5s infinite;
            border-radius: 4px;
            height: 150px;
            margin: 1rem 0;
        }
        @keyframes shimmer {
            0% { background-position: -200% 0; }
            100% { background-position: 200% 0; }
        }
        </style>
        <div class="skeleton-box"></div>
    """, unsafe_allow_html=True)

# Initialize session state
if "uploaded_df" not in st.session_state:
    st.session_state.uploaded_df = None

if "uploaded_file" not in st.session_state:
    st.session_state.uploaded_file = None

if "company_col" not in st.session_state:
    st.session_state.company_col = None

if "org_col" not in st.session_state:
    st.session_state.org_col = None

if "workflow_step" not in st.session_state:
    st.session_state.workflow_step = "upload"

if "enrichment_results" not in st.session_state:
    st.session_state.enrichment_results = None

if "merged_df" not in st.session_state:
    st.session_state.merged_df = None

# Single lookup session state
if "single_lookup_result" not in st.session_state:
    st.session_state.single_lookup_result = None

if "single_lookup_loading" not in st.session_state:
    st.session_state.single_lookup_loading = False

if "single_lookup_query" not in st.session_state:
    st.session_state.single_lookup_query = None

# Header
st.title("🏢 Swedish Company Data Enrichment")
st.markdown("""
Upload a CSV file with Swedish companies to get enriched data including:
- Company validation status
- Financial data (revenue, employees)
- Contact information (CEO, HR, key roles)

**Supported batch size:** 10-20 companies per upload
""")

# Quick Lookup Section
st.header("Quick Lookup")
st.markdown("Look up a single company instantly by name or organization number.")

with st.form(key="single_lookup_form"):
    query = st.text_input(
        "Company name or organization number",
        placeholder="e.g., Volvo AB or 556012-3456",
        help="Enter a Swedish company name or 10-digit organization number (with or without dash)"
    )
    submitted = st.form_submit_button("Search", type="primary")

if submitted and query:
    st.session_state.single_lookup_loading = True
    st.session_state.single_lookup_query = query
    st.session_state.single_lookup_result = None
    st.rerun()

# Show skeleton placeholder while loading
if st.session_state.single_lookup_loading:
    show_skeleton_placeholder()

    # Process single lookup with error handling
    try:
        query = st.session_state.single_lookup_query
        input_type = detect_input_type(query)

        # Call enrich_company with appropriate parameters
        if input_type == "org_number":
            result = enrich_company(company_name=query, org_number=query)
        else:
            result = enrich_company(company_name=query)

        st.session_state.single_lookup_result = result

        # Log analytics event
        log_event("single_lookup", {
            "company_name": query,
            "status": result.get("status", "unknown"),
            "input_type": input_type
        })
    except Exception:
        # Hide technical errors from users
        st.session_state.single_lookup_result = {
            "company_name": st.session_state.single_lookup_query,
            "org_number": "NOT PROVIDED",
            "status": "error",
            "allabolag_url": None,
            "fetch_success": False,
            "error_message": "An unexpected error occurred. Please try again."
        }
    finally:
        st.session_state.single_lookup_loading = False
        st.rerun()

# Display single lookup results
if st.session_state.single_lookup_result is not None:
    result = st.session_state.single_lookup_result
    query = st.session_state.single_lookup_query

    # Handle different status types with user-friendly messages
    if result["status"] == "not_found":
        st.warning(f"No company found for '{query}'. Try the organization number instead, or check the spelling.")
    elif result["status"] == "error":
        st.error(f"Error looking up company: {result.get('error_message', 'Unknown error')}")
    elif result["status"] == "blocked":
        st.warning("The service is temporarily unavailable. Please try again in a few minutes.")
    else:
        # Success - display results in table format
        st.success(f"Found company: {result['company_name']}")

    # Convert single result to DataFrame for consistent display (show for all statuses)
    result_df = pd.DataFrame([{
        "Status": get_status_badge(result["status"]),
        "Company Name": result["company_name"],
        "Org Number": result["org_number"],
        "Allabolag Link": result["allabolag_url"],
        "Data Fetched": result["fetch_success"],
        "Error Details": result.get("error_message", "")
    }])

    st.dataframe(
        result_df,
        column_config={
            "Status": st.column_config.TextColumn(
                "Status",
                help="Enrichment result: success, blocked, not found, or error"
            ),
            "Company Name": st.column_config.TextColumn(
                "Company Name",
                help="Original company name from input"
            ),
            "Org Number": st.column_config.TextColumn(
                "Org Number",
                help="Swedish organization number (10 digits)"
            ),
            "Allabolag Link": st.column_config.LinkColumn(
                "Allabolag Link",
                help="Direct link to company page on Allabolag.se"
            ),
            "Data Fetched": st.column_config.CheckboxColumn(
                "Data Fetched",
                help="Whether company data was successfully retrieved"
            ),
            "Error Details": st.column_config.TextColumn(
                "Error Details",
                help="Error description if lookup failed"
            )
        },
        use_container_width=True,
        hide_index=True
    )

    # Search Another button
    if st.button("Search Another"):
        st.session_state.single_lookup_result = None
        st.session_state.single_lookup_query = None
        st.rerun()

st.divider()

# Section 1: File Upload
st.header("1. Upload Company List")

uploaded_file = st.file_uploader(
    "Choose a CSV file",
    type=["csv"],
    help="Maximum 20 companies per batch. File should include company names and optionally organization numbers.",
    key="file_uploader"
)

# Store uploaded file in session state to prevent re-upload on interaction
if uploaded_file is not None:
    st.session_state.uploaded_file = uploaded_file

    # Validate uploaded file using validation module
    validation = validate_csv_file(uploaded_file)

    if not validation["valid"]:
        st.error(f"Invalid file: {validation['error']}")
        st.session_state.uploaded_df = None
    else:
        st.success(f"File uploaded: {uploaded_file.name}")
        st.session_state.uploaded_df = validation["df"]

        # Show warnings if any (e.g., skipped malformed rows)
        for warning in validation.get("warnings", []):
            st.warning(warning)
else:
    st.info("👆 Drag and drop a CSV file or click to browse")

# Section 2: Column Mapping
st.header("2. Map Columns")

def auto_detect_column(df, keywords):
    """Auto-detect column by searching for keywords (case-insensitive)."""
    for col in df.columns:
        col_lower = col.lower()
        if any(keyword in col_lower for keyword in keywords):
            return col
    return None

if st.session_state.uploaded_df is not None:
    df = st.session_state.uploaded_df

    # Auto-detect company name column
    company_keywords = ["company", "företag", "namn", "name"]
    detected_company = auto_detect_column(df, company_keywords)

    # Auto-detect organization number column
    org_keywords = ["org", "orgnr", "organization", "nummer"]
    detected_org = auto_detect_column(df, org_keywords)

    st.markdown("**Configure column mapping for your data:**")

    col1, col2 = st.columns(2)

    with col1:
        # Company name column selector
        company_col = st.selectbox(
            "Company Name Column *",
            options=df.columns.tolist(),
            index=df.columns.tolist().index(detected_company) if detected_company else 0,
            help="Select the column containing company names"
        )
        st.session_state.company_col = company_col

    with col2:
        # Organization number column selector (optional)
        org_options = ["None"] + df.columns.tolist()
        org_default_idx = 0
        if detected_org:
            org_default_idx = org_options.index(detected_org)

        org_col = st.selectbox(
            "Organization Number Column (optional)",
            options=org_options,
            index=org_default_idx,
            help="Select the column containing organization numbers, or 'None' if not available"
        )
        st.session_state.org_col = None if org_col == "None" else org_col

    # Validate column selection
    if not company_col:
        st.warning("⚠️ Please select the company name column")
    else:
        # Show preview of mapped data
        st.markdown("**Preview of mapped data (first 5 rows):**")
        preview_cols = [company_col]
        if st.session_state.org_col:
            preview_cols.append(st.session_state.org_col)
        st.dataframe(df[preview_cols].head(), use_container_width=True)

        # Data validation
        st.markdown("**Data Quality Check:**")

        # Check for empty company names
        empty_count = df[company_col].isna().sum()

        # Check for duplicates
        duplicate_count = df[company_col].duplicated().sum()

        # Count valid rows
        valid_count = len(df) - empty_count - duplicate_count

        # Display validation results
        validation_cols = st.columns(3)
        with validation_cols[0]:
            st.metric("Total Rows", len(df))
        with validation_cols[1]:
            st.metric("Valid Companies", valid_count)
        with validation_cols[2]:
            issues = empty_count + duplicate_count
            st.metric("Issues Found", issues, delta=None if issues == 0 else f"-{issues}")

        # Show warnings/info for data issues
        if empty_count > 0 or duplicate_count > 0:
            st.info(f"ℹ️ Found {empty_count} empty rows and {duplicate_count} duplicates - these will be skipped during processing")

        # Check for no valid companies
        if valid_count == 0:
            st.error("❌ No valid companies found in the file. Please check your data and try again.")
        else:
            # Warn about large batches
            if valid_count > 50:
                st.warning(f"⚠️ Large batch detected ({valid_count} companies). Processing may take several minutes. Consider splitting into smaller batches for better performance.")

            # Confirm mapping button (only show if valid companies exist)
            if st.button("✅ Confirm Mapping", type="primary"):
                st.session_state.workflow_step = "ready_to_process"
                st.success("✅ Mapping confirmed! Ready to process companies.")
                st.rerun()

else:
    st.info("Upload a file to configure column mapping")

# Section 3: Process
st.header("3. Process Companies")

if st.session_state.workflow_step == "ready_to_process":
    st.markdown("""
    **Ready to enrich your company data!**

    Click the button below to start processing. This will:
    - Validate each company via Allabolag.se
    - Fetch company search results
    - Track processing status for each company
    """)

    # Prepare batch data
    df = st.session_state.uploaded_df
    company_col = st.session_state.company_col
    org_col = st.session_state.org_col

    # Filter out invalid rows
    valid_df = df[df[company_col].notna() & ~df[company_col].duplicated()].copy()

    # Show estimated time
    est_time = len(valid_df) * 2
    st.info(f"⏱️ Estimated time: {est_time} seconds ({len(valid_df)} companies at ~2s each)")

    # Warn about large batches
    if len(valid_df) > 20:
        st.warning("⚠️ Large batch may take several minutes. Consider splitting into smaller batches.")

    col1, col2 = st.columns(2)

    with col1:
        if st.button("🚀 Start Enrichment", type="primary"):
            st.session_state.workflow_step = "processing"
            st.rerun()

    with col2:
        if st.button("Cancel", type="secondary"):
            st.session_state.workflow_step = "upload"
            st.rerun()

elif st.session_state.workflow_step == "processing":
    st.markdown("**Processing companies...**")

    # Prepare batch data
    df = st.session_state.uploaded_df
    company_col = st.session_state.company_col
    org_col = st.session_state.org_col

    # Filter out invalid rows
    valid_df = df[df[company_col].notna() & ~df[company_col].duplicated()].copy()

    companies = []
    for _, row in valid_df.iterrows():
        companies.append({
            "company_name": row[company_col],
            "org_number": row[org_col] if org_col else None
        })

    # Create progress UI elements
    progress_bar = st.progress(0, text="Starting enrichment...")
    status_text = st.empty()

    # Progress callback
    def update_progress(current, total):
        progress = current / total
        progress_bar.progress(progress, text=f"Processing {current}/{total} companies...")

    # Process batch with error handling
    try:
        # Log enrichment started
        log_event("enrichment_started", {
            "company_count": len(companies)
        })

        results = enrich_batch(companies, progress_callback=update_progress)
        st.session_state.enrichment_results = results
        st.session_state.workflow_step = "complete"

        # Log enrichment completed
        log_event("enrichment_completed", {
            "company_count": len(results),
            "success_count": sum(1 for r in results if r["status"] == "success")
        })

        st.success(f"✅ Processing complete! Enriched {len(results)} companies.")
        st.rerun()
    except Exception as e:
        st.error(f"❌ Processing failed: {str(e)}")
        st.session_state.workflow_step = "ready_to_process"
        if st.button("Try Again"):
            st.rerun()

elif st.session_state.workflow_step == "upload":
    st.info("Complete steps 1-2 to start processing")
else:
    st.info("Confirm your column mapping in step 2 to proceed")

# Section 4: Results
st.header("4. Results")

if st.session_state.workflow_step == "complete" and st.session_state.enrichment_results:
    results = st.session_state.enrichment_results

    # Merge results with original data
    merged_df = merge_results_with_original(
        st.session_state.uploaded_df,
        st.session_state.enrichment_results,
        st.session_state.company_col
    )
    st.session_state.merged_df = merged_df

    st.success(f"✅ Successfully enriched {len(results)} companies!")

    # Summary metrics
    success_count = sum(1 for r in results if r["status"] == "success")
    blocked_count = sum(1 for r in results if r["status"] == "blocked")
    not_found_count = sum(1 for r in results if r["status"] == "not_found")
    error_count = sum(1 for r in results if r["status"] == "error")

    metric_cols = st.columns(4)
    with metric_cols[0]:
        st.metric("Successful", success_count, delta=f"{success_count/len(results)*100:.0f}%")
    with metric_cols[1]:
        st.metric("Not Found", not_found_count)
    with metric_cols[2]:
        st.metric("Blocked", blocked_count)
    with metric_cols[3]:
        st.metric("Errors", error_count)

    # Add status badges to merged DataFrame for display
    display_df = merged_df.copy()
    if "Enrichment Status" in display_df.columns:
        display_df["Status"] = display_df["Enrichment Status"].apply(get_status_badge)
        # Reorder columns to put Status first
        cols = display_df.columns.tolist()
        cols.remove("Status")
        cols.insert(0, "Status")
        display_df = display_df[cols]

    # Display merged data table with all columns
    st.markdown("**Enriched Company Data:**")
    st.markdown("*Showing original columns plus enrichment results*")
    st.dataframe(
        display_df,
        column_config={
            "Status": st.column_config.TextColumn(
                "Status",
                help="Enrichment result: success, blocked, not found, or error"
            ),
            "Enrichment Status": st.column_config.TextColumn(
                "Raw Status",
                help="Raw enrichment status code"
            ),
            "Fetch Success": st.column_config.CheckboxColumn(
                "Data Fetched",
                help="Whether company data was successfully retrieved"
            ),
            "Allabolag URL": st.column_config.LinkColumn(
                "Allabolag Link",
                help="Direct link to company page on Allabolag.se"
            ),
            "Error Message": st.column_config.TextColumn(
                "Error Details",
                help="Error description if lookup failed"
            )
        },
        use_container_width=True,
        hide_index=True
    )

    # Error details expander
    failed_results = [r for r in results if r["status"] != "success"]
    if failed_results:
        with st.expander("View Error Details"):
            for r in failed_results:
                company = r.get("company_name", "Unknown")
                error_msg = r.get("error_message", "No details available")
                status = r.get("status", "unknown")
                st.markdown(f"**{company}** ({status}): {error_msg}")

    # Status legend
    with st.expander("Status Legend"):
        st.markdown("""
- **Success**: Company found and data retrieved
- **Blocked**: Website temporarily blocked automated access
- **Not Found**: No matching company in database
- **Error**: Technical issue during lookup
        """)

    # Download section
    st.subheader("Download Results")

    # Generate timestamp for unique filenames
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    col1, col2, col3 = st.columns(3)

    with col1:
        csv_data = to_csv(st.session_state.merged_df)
        if st.download_button(
            label="Download CSV",
            data=csv_data,
            file_name=f"enriched_companies_{timestamp}.csv",
            mime="text/csv",
            type="primary"
        ):
            log_event("export_downloaded", {"format": "csv", "row_count": len(st.session_state.merged_df)})

    with col2:
        excel_data = to_excel(st.session_state.merged_df)
        if st.download_button(
            label="Download Excel",
            data=excel_data,
            file_name=f"enriched_companies_{timestamp}.xlsx",
            mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            type="secondary"
        ):
            log_event("export_downloaded", {"format": "excel", "row_count": len(st.session_state.merged_df)})

    with col3:
        crm_data = to_crm_csv(st.session_state.merged_df)
        if st.download_button(
            label="Download for CRM",
            data=crm_data,
            file_name=f"crm_import_{timestamp}.csv",
            mime="text/csv",
            type="secondary",
            help="CSV formatted for HubSpot, Pipedrive, or Salesforce import"
        ):
            log_event("export_downloaded", {"format": "crm", "row_count": len(st.session_state.merged_df)})

    # Process another batch button
    st.divider()
    if st.button("Process Another File"):
        st.session_state.workflow_step = "upload"
        st.session_state.uploaded_df = None
        st.session_state.uploaded_file = None
        st.session_state.enrichment_results = None
        st.session_state.merged_df = None
        st.rerun()

else:
    st.info("Results will appear here after processing")
