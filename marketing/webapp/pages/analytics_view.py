"""
Analytics Dashboard - Usage Metrics and Event Tracking

Displays key metrics, charts, and event history for admin monitoring.
"""

import streamlit as st
import pandas as pd
from datetime import datetime, timedelta
from collections import Counter
import sys
from pathlib import Path

# Add webapp to path for imports
webapp_dir = Path(__file__).parent.parent
if str(webapp_dir) not in sys.path:
    sys.path.insert(0, str(webapp_dir))

from utils.analytics import get_events, log_event

# Log page view
log_event("page_view", {"page": "analytics"})

st.title("📊 Analytics Dashboard")
st.markdown("Monitor usage patterns, enrichments, and export conversions.")

# Load events
events = get_events()

if not events:
    st.info("No analytics data yet. Start using the enrichment tool to see metrics here!")
    st.stop()

# Convert to DataFrame for easier analysis
df = pd.DataFrame(events)
df['timestamp'] = pd.to_datetime(df['timestamp'])

# Calculate metrics
total_events = len(events)
enrichments_started = sum(1 for e in events if e['event_type'] == 'enrichment_started')
enrichments_completed = sum(1 for e in events if e['event_type'] == 'enrichment_completed')
exports = sum(1 for e in events if e['event_type'] == 'export_downloaded')
single_lookups = sum(1 for e in events if e['event_type'] == 'single_lookup')
leads = sum(1 for e in events if e['event_type'] == 'lead_submitted')

# Calculate export rate (conversion)
export_rate = (exports / enrichments_completed * 100) if enrichments_completed > 0 else 0

# Calculate total companies processed
companies_processed = 0
for event in events:
    if event['event_type'] == 'enrichment_completed':
        metadata = event.get('metadata', {})
        companies_processed += metadata.get('company_count', 0)

# Calculate active days
if len(df) > 0:
    active_dates = df['timestamp'].dt.date.unique()
    active_days = len(active_dates)
else:
    active_days = 0

# Key Metrics Section
st.subheader("Key Metrics")

col1, col2, col3, col4 = st.columns(4)

with col1:
    st.metric(
        label="Total Events",
        value=total_events,
        help="Total number of tracked events"
    )

with col2:
    st.metric(
        label="Enrichments",
        value=enrichments_completed,
        help="Number of completed batch enrichments"
    )

with col3:
    st.metric(
        label="Exports",
        value=exports,
        delta=f"{export_rate:.1f}% conversion",
        help="Number of export downloads (CSV, Excel, CRM)"
    )

with col4:
    st.metric(
        label="Single Lookups",
        value=single_lookups,
        help="Number of individual company lookups"
    )

# Secondary Metrics
col5, col6, col7 = st.columns(3)

with col5:
    st.metric(
        label="Companies Processed",
        value=companies_processed,
        help="Total companies enriched across all batches"
    )

with col6:
    st.metric(
        label="Leads Captured",
        value=leads,
        help="Number of lead form submissions"
    )

with col7:
    st.metric(
        label="Active Days",
        value=active_days,
        help="Number of days with recorded activity"
    )

st.divider()

# Event Breakdown Chart
st.subheader("Event Breakdown")

event_counts = Counter(e['event_type'] for e in events)
event_df = pd.DataFrame([
    {"Event Type": event_type.replace('_', ' ').title(), "Count": count}
    for event_type, count in event_counts.items()
])
event_df = event_df.sort_values('Count', ascending=False)

st.bar_chart(event_df.set_index('Event Type'))

# Event type legend
with st.expander("Event Type Definitions"):
    st.markdown("""
- **Page View**: User visited a page
- **Enrichment Started**: Batch enrichment process began
- **Enrichment Completed**: Batch enrichment finished
- **Single Lookup**: Individual company lookup performed
- **Export Downloaded**: Results exported (CSV, Excel, or CRM format)
- **Lead Submitted**: Lead form submission (if implemented)
    """)

st.divider()

# Recent Events Table
st.subheader("Recent Events")

# Show last 50 events
recent_events = events[-50:][::-1]  # Reverse to show newest first

recent_df = pd.DataFrame([
    {
        "Time": datetime.fromisoformat(e['timestamp']).strftime('%Y-%m-%d %H:%M:%S'),
        "Event Type": e['event_type'].replace('_', ' ').title(),
        "Details": str(e.get('metadata', {})) if e.get('metadata') else '-'
    }
    for e in recent_events
])

st.dataframe(
    recent_df,
    column_config={
        "Time": st.column_config.TextColumn(
            "Timestamp",
            help="When the event occurred"
        ),
        "Event Type": st.column_config.TextColumn(
            "Event",
            help="Type of event tracked"
        ),
        "Details": st.column_config.TextColumn(
            "Metadata",
            help="Additional event information"
        )
    },
    use_container_width=True,
    hide_index=True
)

st.divider()

# Export Analytics Data
st.subheader("Export Analytics")

st.markdown("Download raw analytics data for external analysis.")

# Convert all events to DataFrame
export_df = pd.DataFrame([
    {
        "timestamp": e['timestamp'],
        "event_type": e['event_type'],
        "metadata": str(e.get('metadata', {}))
    }
    for e in events
])

csv_data = export_df.to_csv(index=False)

st.download_button(
    label="Download Analytics CSV",
    data=csv_data,
    file_name=f"analytics_export_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv",
    mime="text/csv",
    help="Download all analytics events as CSV"
)

# Refresh button
st.divider()
if st.button("🔄 Refresh Dashboard"):
    st.rerun()
