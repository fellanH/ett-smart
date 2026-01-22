#!/usr/bin/env python3
"""
Search URL Generator Tool
Generates direct URLs to Swedish company databases (allabolag.se, ratsit.se) 
and LinkedIn, which work better with mcp_web_fetch than Google search URLs.
"""

import urllib.parse
import sys
import json
from typing import List, Dict, Optional


def generate_duckduckgo_search_url(query: str, site: Optional[str] = None) -> str:
    """
    Generate a DuckDuckGo search URL. DuckDuckGo is more accessible than Google
    and works better with web fetch tools (doesn't block automated access).
    
    Args:
        query: The search query string
        site: Optional site restriction (e.g., "allabolag.se")
    
    Returns:
        Formatted DuckDuckGo search URL
    """
    # Build final query with site restriction if provided
    final_query = query
    if site:
        if query.startswith('"') and query.endswith('"'):
            final_query = f'{query} site:{site}'
        else:
            final_query = f'"{query}" site:{site}'
    
    # DuckDuckGo HTML search URL (works better with web fetch tools)
    base_url = "https://html.duckduckgo.com/html/"
    params = {
        "q": final_query,
    }
    
    param_string = urllib.parse.urlencode(params)
    return f"{base_url}?{param_string}"


def generate_google_search_url(query: str, site: Optional[str] = None, language: str = "sv", use_duckduckgo: bool = True) -> str:
    """
    Generate a search URL optimized for web fetching.
    
    By default uses DuckDuckGo (more accessible, doesn't block automated access).
    Can fallback to Google if needed.
    
    Args:
        query: The search query string (may already contain quotes)
        site: Optional site restriction (e.g., "allabolag.se")
        language: Language code (default: "sv" for Swedish) - only used for Google
        use_duckduckgo: If True, use DuckDuckGo (default). If False, use Google.
    
    Returns:
        Formatted search URL
    """
    # Build final query with site restriction if provided
    final_query = query
    if site:
        # If query already has quotes, add site restriction outside
        if query.startswith('"') and query.endswith('"'):
            final_query = f'{query} site:{site}'
        else:
            final_query = f'"{query}" site:{site}'
    
    # Use DuckDuckGo by default (better web fetch compatibility)
    if use_duckduckgo:
        return generate_duckduckgo_search_url(query, site)
    
    # Google search URL (may be blocked by web fetch tools)
    base_url = "https://www.google.com/search"
    params = {
        "q": final_query,
        "hl": language,  # Swedish
        "lr": f"lang_{language}",  # Language restriction
        "num": "20",  # Number of results
    }
    
    param_string = urllib.parse.urlencode(params)
    return f"{base_url}?{param_string}"


def generate_direct_url(company_name: str, site: str) -> str:
    """
    Generate direct URL to Swedish company database sites.
    These URLs should work with mcp_web_fetch (unlike Google search URLs).
    
    Args:
        company_name: Company name
        site: Site domain (allabolag.se, ratsit.se, etc.)
    
    Returns:
        Direct URL to search the company on the site
    """
    # URL encode company name (remove common suffixes for better matching)
    clean_name = company_name.replace(" Ab", "").replace(" AB", "").strip()
    encoded_name = urllib.parse.quote_plus(clean_name)
    
    if site == "allabolag.se":
        # Allabolag.se direct search URL
        return f"https://www.allabolag.se/{encoded_name}"
    elif site == "ratsit.se":
        # Ratsit.se search URL format
        return f"https://www.ratsit.se/sok/{encoded_name}"
    elif site == "linkedin.com":
        # LinkedIn company search URL
        return f"https://www.linkedin.com/search/results/companies/?keywords={encoded_name}"
    else:
        # Fallback to Google search
        return generate_google_search_url(company_name, site)


def generate_company_search_urls(company_name: str) -> List[Dict[str, str]]:
    """
    Generate all required search URLs for a Swedish company research workflow.
    Uses direct URLs to Swedish company databases instead of Google search URLs
    to avoid blocking issues with mcp_web_fetch.
    
    Args:
        company_name: The name of the company to research
    
    Returns:
        List of dictionaries with 'query', 'url', 'purpose', and 'type' keys
    """
    searches = [
        {
            "query": company_name,
            "site": "allabolag.se",
            "purpose": "Get revenue, address, VD name, contact details",
            "type": "direct"
        },
        {
            "query": company_name,
            "site": "ratsit.se",
            "purpose": "Verify/supplement data",
            "type": "direct"
        },
        {
            "query": f'"{company_name}" VD email',
            "site": None,
            "purpose": "CEO contact",
            "type": "search"  # Uses DuckDuckGo (more accessible than Google)
        },
        {
            "query": company_name,
            "site": "linkedin.com",
            "purpose": "Company page, employee profiles",
            "type": "direct"
        },
        {
            "query": f'"{company_name}" HR personal kontakt',
            "site": None,
            "purpose": "HR contact",
            "type": "search"  # Uses DuckDuckGo
        },
        {
            "query": f'"{company_name}" official website',
            "site": None,
            "purpose": "Contact page, team page",
            "type": "search"  # Uses DuckDuckGo
        },
        {
            "query": f'"{company_name}" kontakt',
            "site": None,
            "purpose": "General contact information",
            "type": "search"  # Uses DuckDuckGo
        },
        {
            "query": f'"{company_name}" om oss',
            "site": None,
            "purpose": "About us page with team info",
            "type": "search"  # Uses DuckDuckGo
        },
    ]
    
    results = []
    for search in searches:
        if search.get("type") == "direct" and search.get("site"):
            url = generate_direct_url(company_name, search["site"])
        else:
            url = generate_google_search_url(
                query=search["query"],
                site=search.get("site"),
                language="sv"
            )
        
        # Build display query
        display_query = search["query"]
        if search.get("site"):
            if display_query.startswith('"') and display_query.endswith('"'):
                display_query = f'{display_query} site:{search["site"]}'
            else:
                display_query = f'"{display_query}" site:{search["site"]}'
        
        results.append({
            "query": display_query,
            "url": url,
            "purpose": search["purpose"],
            "type": search.get("type", "search")
        })
    
    return results


def main():
    """CLI interface for the search URL generator."""
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python search_url_generator.py <company_name>")
        print("  python search_url_generator.py <query> --site <site>")
        print("  python search_url_generator.py <company_name> --all")
        sys.exit(1)
    
    # Check if --all flag is used (generate all company search URLs)
    if "--all" in sys.argv:
        company_name = sys.argv[1]
        urls = generate_company_search_urls(company_name)
        
        # Output as JSON for easy parsing
        if "--json" in sys.argv:
            print(json.dumps(urls, indent=2, ensure_ascii=False))
        else:
            print(f"Generated {len(urls)} search URLs for: {company_name}\n")
            for i, item in enumerate(urls, 1):
                print(f"{i}. {item['purpose']}")
                print(f"   Query: {item['query']}")
                print(f"   URL: {item['url']}\n")
    
    # Check if --site flag is used
    elif "--site" in sys.argv:
        query = sys.argv[1]
        site_index = sys.argv.index("--site")
        if site_index + 1 < len(sys.argv):
            site = sys.argv[site_index + 1]
        else:
            site = None
        url = generate_google_search_url(query, site)
        print(url)
    
    # Single query
    else:
        query = " ".join(sys.argv[1:])
        url = generate_google_search_url(query)
        print(url)


if __name__ == "__main__":
    main()
