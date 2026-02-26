"""
Marketing Landing Page with Lead Capture

Displays value proposition and collects leads via GDPR-compliant form.
"""

import streamlit as st
import re
from datetime import datetime

# Hero Section
st.markdown(
    """
    <div style='text-align: center; padding: 2rem 0;'>
        <h1 style='font-size: 3rem; margin-bottom: 1rem; color: #191514;'>
            Swedish Company Data Enrichment
        </h1>
        <p style='font-size: 1.5rem; color: #555555; margin-bottom: 2rem;'>
            Validate and enrich company data from Allabolag and Ratsit in seconds
        </p>
    </div>
    """,
    unsafe_allow_html=True
)

# Primary CTA button
col1, col2, col3 = st.columns([1, 1, 1])
with col2:
    if st.button("🔍 Try the Tool", type="primary", use_container_width=True):
        st.switch_page("pages/enrichment.py")

st.divider()

# Value Propositions (3-column layout)
st.markdown("### Why Choose Our Platform?")
col1, col2, col3 = st.columns(3)

with col1:
    st.markdown(
        """
        <div style='text-align: center; padding: 1rem;'>
            <h3>⚡ Instant Validation</h3>
            <p>Verify company status and org numbers against official Swedish registries</p>
        </div>
        """,
        unsafe_allow_html=True
    )

with col2:
    st.markdown(
        """
        <div style='text-align: center; padding: 1rem;'>
            <h3>💰 Financial Insights</h3>
            <p>Access revenue, employee count, and credit ratings in real-time</p>
        </div>
        """,
        unsafe_allow_html=True
    )

with col3:
    st.markdown(
        """
        <div style='text-align: center; padding: 1rem;'>
            <h3>👥 Contact Discovery</h3>
            <p>Find CEO, HR managers, and key decision-makers effortlessly</p>
        </div>
        """,
        unsafe_allow_html=True
    )

st.divider()

# Lead Capture Form
st.markdown("### Request Demo Access")
st.markdown("Fill out the form below to get started with our platform")


def validate_email(email: str) -> bool:
    """Validate email format using regex."""
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return re.match(pattern, email) is not None


# Create form
with st.form("lead_capture_form", clear_on_submit=True):
    name = st.text_input("Full Name *", placeholder="John Doe")
    email = st.text_input("Email *", placeholder="john@company.com")
    company = st.text_input("Company", placeholder="Acme AB (optional)")
    phone = st.text_input("Phone", placeholder="+46 70 123 4567 (optional)")

    # GDPR consent checkbox (UNTICKED by default)
    consent = st.checkbox(
        "I consent to my personal data (name, email, company) being stored for the purpose of demo access. "
        "You can withdraw consent at any time by contacting support@companyenrichment.se",
        value=False
    )

    submitted = st.form_submit_button("Request Demo Access", type="primary", use_container_width=True)

    if submitted:
        # Validation
        errors = []

        if not name or not name.strip():
            errors.append("Name is required")

        if not email or not email.strip():
            errors.append("Email is required")
        elif not validate_email(email):
            errors.append("Please enter a valid email address")

        if not consent:
            errors.append("You must consent to data storage to proceed (GDPR compliance)")

        # Display errors or submit
        if errors:
            for error in errors:
                st.error(error)
        else:
            # Save to Google Sheets
            try:
                # Initialize Google Sheets connection
                conn = st.connection("gsheets", type="gsheets")

                # Prepare data row
                timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                new_row = {
                    "Timestamp": timestamp,
                    "Name": name.strip(),
                    "Email": email.strip(),
                    "Company": company.strip() if company else "",
                    "Phone": phone.strip() if phone else "",
                    "Consent": "Yes"
                }

                # Append to sheet
                # Note: This requires a worksheet with headers: Timestamp, Name, Email, Company, Phone, Consent
                df = conn.read(worksheet="Leads", ttl=0)
                import pandas as pd
                df = pd.concat([df, pd.DataFrame([new_row])], ignore_index=True)
                conn.update(worksheet="Leads", data=df)

                st.success("✅ Thank you! Your demo access request has been submitted.")
                st.balloons()
                st.info("We'll get back to you within 24 hours at the email address provided.")

            except Exception as e:
                # Graceful error handling - don't crash the app
                st.warning(
                    "⚠️ We're experiencing technical difficulties saving your request. "
                    "Please email us directly at support@companyenrichment.se"
                )
                st.error(f"Technical details: {str(e)}")

# Footer
st.divider()
st.markdown(
    """
    <div style='text-align: center; color: #555555; font-size: 0.9rem; padding: 2rem 0;'>
        <p>Built for Swedish businesses | GDPR Compliant | Secure Data Handling</p>
    </div>
    """,
    unsafe_allow_html=True
)
