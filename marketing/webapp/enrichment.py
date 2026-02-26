"""
Company Enrichment Module

Wraps weaver-5 scripts to provide batch enrichment functionality for Swedish companies.
Handles rate limiting, error handling, and progress tracking.
"""

import sys
import time
from pathlib import Path
from typing import Dict, List, Optional, Callable

# Add weaver-5 directory to Python path for imports
weaver_path = Path(__file__).parent.parent / "weaver-5"
sys.path.insert(0, str(weaver_path))

# Import weaver-5 modules
try:
    from batch_fetch import BatchFetcher
    from search_helper import generate_allabolag_search, generate_ratsit_search
except ImportError as e:
    raise ImportError(
        f"Could not import weaver-5 modules. Ensure weaver-5/ exists and contains "
        f"required modules (batch_fetch.py, search_helper.py): {e}"
    )


# Human-readable error messages for user display
ERROR_MESSAGES = {
    "blocked": "This company's page is temporarily unavailable. Try again later.",
    "not_found": "No company found matching your search. Check the spelling or try the organization number.",
    "timeout": "The search took too long. Please try again.",
    "connection": "Could not connect to the data source. Check your internet connection.",
    "invalid_input": "Please enter a valid company name or 10-digit organization number.",
    "unknown": "An unexpected error occurred. Please try again.",
}


def get_friendly_error(status: str, raw_error: str = None) -> str:
    """Convert technical error to user-friendly message.

    Args:
        status: Error status code (blocked, not_found, timeout, etc.)
        raw_error: Optional raw error string for pattern matching

    Returns:
        Human-readable error message
    """
    if status in ERROR_MESSAGES:
        return ERROR_MESSAGES[status]
    if raw_error:
        # Check for common error patterns
        raw_lower = raw_error.lower()
        if "timeout" in raw_lower:
            return ERROR_MESSAGES["timeout"]
        if "connection" in raw_lower:
            return ERROR_MESSAGES["connection"]
    return ERROR_MESSAGES["unknown"]


def enrich_company(
    company_name: str,
    org_number: Optional[str] = None,
    fetcher: Optional[BatchFetcher] = None
) -> Dict:
    """
    Enrich a single company with data from Allabolag.

    For PoC Phase 1: Validates that the URL fetch works.
    Full HTML parsing is handled by existing weaver-5 agent workflow (out of scope for PoC).

    Args:
        company_name: Name of the company to enrich
        org_number: Optional organization number
        fetcher: Optional BatchFetcher instance to reuse (for efficiency)

    Returns:
        Dictionary with enrichment results:
        - company_name: Original company name
        - org_number: Organization number or "NOT PROVIDED"
        - status: "success" | "blocked" | "not_found" | "error"
        - allabolag_url: Generated search URL
        - fetch_success: Boolean indicating if fetch succeeded
        - error_message: Error details if any
    """
    result = {
        "company_name": company_name,
        "org_number": org_number or "NOT PROVIDED",
        "status": "pending",
        "allabolag_url": None,
        "fetch_success": False,
        "error_message": None
    }

    try:
        # Generate Allabolag search URL
        result["allabolag_url"] = generate_allabolag_search(company_name)

        # Create fetcher if not provided (for single-company calls)
        if fetcher is None:
            fetcher = BatchFetcher(delay=1.5, timeout=30)

        # Fetch with timeout and retry handling (built into BatchFetcher)
        fetch_result = fetcher.fetch_url(result["allabolag_url"])

        result["fetch_success"] = fetch_result["success"]

        # Handle different error cases
        if fetch_result.get("blocked"):
            result["status"] = "blocked"
            result["error_message"] = get_friendly_error("blocked")
        elif fetch_result["success"]:
            result["status"] = "success"
        elif fetch_result.get("status_code") == 404:
            result["status"] = "not_found"
            result["error_message"] = get_friendly_error("not_found")
        else:
            result["status"] = "error"
            raw_error = fetch_result.get("error", "")
            result["error_message"] = get_friendly_error("error", raw_error)

    except Exception as e:
        result["status"] = "error"
        raw_error = str(e)
        result["error_message"] = get_friendly_error("error", raw_error)

    return result


def enrich_batch(
    companies: List[Dict],
    progress_callback: Optional[Callable[[int, int], None]] = None
) -> List[Dict]:
    """
    Enrich a batch of companies with rate limiting.

    Args:
        companies: List of dicts with keys:
            - company_name: Required company name
            - org_number: Optional organization number
        progress_callback: Optional callback function(current, total)

    Returns:
        List of enrichment result dictionaries

    Raises:
        ValueError: If companies list is empty
    """
    if not companies:
        raise ValueError("Companies list cannot be empty")

    results = []
    total = len(companies)

    # Create single BatchFetcher instance to reuse connection pool
    fetcher = BatchFetcher(delay=1.5, timeout=30)

    for i, company in enumerate(companies):
        try:
            # Validate company data
            if not company.get("company_name"):
                results.append({
                    "company_name": "INVALID",
                    "org_number": company.get("org_number", "NOT PROVIDED"),
                    "status": "error",
                    "allabolag_url": None,
                    "fetch_success": False,
                    "error_message": "Company name is required"
                })
            else:
                # Enrich single company with shared fetcher
                result = enrich_company(
                    company["company_name"],
                    company.get("org_number"),
                    fetcher=fetcher
                )
                results.append(result)

            # Update progress after each company
            if progress_callback:
                progress_callback(i + 1, total)

            # Rate limiting: 1.5s between requests (except after last)
            # This ensures we respect website rate limits
            if i < total - 1:
                time.sleep(1.5)

        except Exception as e:
            # Handle unexpected errors gracefully
            results.append({
                "company_name": company.get("company_name", "UNKNOWN"),
                "org_number": company.get("org_number", "NOT PROVIDED"),
                "status": "error",
                "allabolag_url": None,
                "fetch_success": False,
                "error_message": f"Processing error: {str(e)}"
            })

            # Still update progress even on error
            if progress_callback:
                progress_callback(i + 1, total)

    return results
