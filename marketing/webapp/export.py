"""
Export Module for Enriched Company Data

Provides functions to merge enrichment results with original data
and export to CSV and Excel formats with formula injection protection.
"""

import pandas as pd
from io import BytesIO
from typing import List, Dict

from validation import sanitize_cell


def merge_results_with_original(
    original_df: pd.DataFrame,
    results: List[Dict],
    company_col: str
) -> pd.DataFrame:
    """
    Merge enrichment results with original DataFrame, preserving all original columns.

    Args:
        original_df: Original uploaded DataFrame with all user columns
        results: List of enrichment result dictionaries
        company_col: Name of the company column in original_df

    Returns:
        DataFrame with original columns plus enrichment results
    """
    # Create results DataFrame
    results_df = pd.DataFrame(results)

    # Rename to avoid collision with original columns
    results_df = results_df.rename(columns={
        "company_name": "_enriched_company",
        "status": "Enrichment Status",
        "allabolag_url": "Allabolag URL",
        "fetch_success": "Fetch Success",
        "error_message": "Error Message"
    })

    # Filter original_df to only valid rows (no NaN, no duplicates)
    # This must match the filtering logic in app.py
    valid_df = original_df[
        original_df[company_col].notna() &
        ~original_df[company_col].duplicated()
    ].copy()

    # Add results as new columns (aligned by index)
    merged = valid_df.copy()
    for col in ["Enrichment Status", "Allabolag URL", "Fetch Success", "Error Message"]:
        if col in results_df.columns:
            merged[col] = results_df[col].values

    return merged


def sanitize_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    """
    Apply cell sanitization to all string columns to prevent formula injection.

    Formula injection occurs when cell values start with characters that
    spreadsheet applications interpret as formulas. This function prefixes
    dangerous characters with a single quote.

    URLs starting with 'http' are NOT sanitized to keep them clickable.

    Args:
        df: DataFrame to sanitize

    Returns:
        New DataFrame with sanitized string values
    """
    df_copy = df.copy()
    for col in df_copy.columns:
        if df_copy[col].dtype == 'object':  # String columns
            df_copy[col] = df_copy[col].apply(
                lambda x: sanitize_cell(x) if isinstance(x, str) else x
            )
    return df_copy


def to_csv(df: pd.DataFrame) -> str:
    """
    Convert DataFrame to CSV string with formula injection protection.

    All string columns are sanitized to prevent CSV formula injection attacks
    when the file is opened in Excel or other spreadsheet applications.

    Args:
        df: DataFrame to export

    Returns:
        CSV string representation with sanitized cell values
    """
    sanitized_df = sanitize_dataframe(df)
    return sanitized_df.to_csv(index=False)


def to_excel(df: pd.DataFrame) -> bytes:
    """
    Convert DataFrame to Excel bytes (xlsx format) with formula injection protection.

    All string columns are sanitized to prevent formula injection attacks
    when the file is opened in Excel. Excel also interprets formulas,
    so the same sanitization is required as for CSV exports.

    Args:
        df: DataFrame to export

    Returns:
        Excel file as bytes with sanitized cell values
    """
    sanitized_df = sanitize_dataframe(df)
    output = BytesIO()
    with pd.ExcelWriter(output, engine='openpyxl') as writer:
        sanitized_df.to_excel(writer, index=False, sheet_name='Enriched Data')
    return output.getvalue()


def format_for_crm(df: pd.DataFrame) -> pd.DataFrame:
    """
    Convert enriched data to CRM-friendly format with standard headers.

    Standard CRM fields (HubSpot, Pipedrive, Salesforce compatible):
    - Company (organization name)
    - Email (contact email if available)
    - Phone (company phone)
    - Website (company URL)
    - Address, City, Postal Code, Country
    - Custom fields: Organization Number, Revenue, Employees, Credit Rating

    Args:
        df: DataFrame with enriched company data

    Returns:
        DataFrame with CRM-standard column headers
    """
    crm_df = pd.DataFrame()

    # Map existing columns to CRM standard names
    # Handle both original column names and enrichment results

    # Company name - try multiple possible source columns
    if "company_name" in df.columns:
        crm_df["Company"] = df["company_name"]
    elif "Company Name" in df.columns:
        crm_df["Company"] = df["Company Name"]
    else:
        # Find first column that might be company name
        for col in df.columns:
            if "company" in col.lower() or "företag" in col.lower():
                crm_df["Company"] = df[col]
                break

    # Organization number
    if "org_number" in df.columns:
        crm_df["Organization Number"] = df["org_number"]
    elif "Org Number" in df.columns:
        crm_df["Organization Number"] = df["Org Number"]

    # Allabolag URL as Website (if no other website available)
    if "Allabolag URL" in df.columns:
        crm_df["Website"] = df["Allabolag URL"]
    elif "website" in df.columns:
        crm_df["Website"] = df["website"]

    # Status for CRM notes
    if "Enrichment Status" in df.columns:
        crm_df["Lead Status"] = df["Enrichment Status"].map({
            "success": "Verified",
            "partial": "Needs Review",
            "blocked": "Needs Manual Lookup",
            "not_found": "Not Found",
            "error": "Error"
        }).fillna("Unknown")

    # Add Country column (all Swedish companies)
    crm_df["Country"] = "Sweden"

    # Placeholder columns for future enrichment data
    # These are standard CRM fields that may be populated in future versions
    crm_df["Email"] = ""  # Contact email (future)
    crm_df["Phone"] = ""  # Company phone (future)
    crm_df["Address"] = ""  # Street address (future)
    crm_df["City"] = ""  # City (future)
    crm_df["Postal Code"] = ""  # Postal code (future)

    # Reorder columns for CRM import (most important first)
    column_order = [
        "Company",
        "Organization Number",
        "Website",
        "Lead Status",
        "Email",
        "Phone",
        "Address",
        "City",
        "Postal Code",
        "Country"
    ]

    # Only include columns that exist
    final_columns = [col for col in column_order if col in crm_df.columns]
    crm_df = crm_df[final_columns]

    return crm_df


def to_crm_csv(df: pd.DataFrame) -> str:
    """
    Convert DataFrame to CRM-ready CSV with standard headers and UTF-8 encoding.

    Args:
        df: DataFrame with enriched company data

    Returns:
        CSV string with CRM-standard headers, UTF-8 encoded for Swedish characters
    """
    crm_df = format_for_crm(df)
    sanitized_df = sanitize_dataframe(crm_df)
    return sanitized_df.to_csv(index=False)
