"""
Company Enrichment Platform - Multi-Page Streamlit App

Entrypoint that configures navigation between pages.
"""

import streamlit as st

# Page configuration (must be first Streamlit command)
st.set_page_config(
    page_title="Swedish Company Enrichment",
    page_icon="🇸🇪",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Define pages
landing_page = st.Page(
    "pages/landing.py",
    title="Home",
    icon="🏠",
    default=True  # Landing page is now default
)

enrichment_page = st.Page(
    "pages/enrichment.py",
    title="Enrichment Tool",
    icon="🔍"
)

analytics_page = st.Page(
    "pages/analytics_view.py",
    title="Analytics",
    icon="📊"
)

# Navigation
pg = st.navigation(
    [landing_page, enrichment_page, analytics_page],
    position="sidebar"
)

# Run selected page
pg.run()
