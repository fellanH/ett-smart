#!/usr/bin/env python3
"""
Search Helper - Provides alternative search methods when direct fetching is blocked

This script helps when websites block automated requests. It provides:
1. Search URL generation for Google/Bing/DuckDuckGo
2. Instructions for manual search
3. Alternative search strategies
"""

import sys
import urllib.parse
import argparse


def generate_search_url(query: str, engine: str = "google") -> str:
    """
    Generate a search URL for the given query.
    
    Args:
        query: Search query string
        engine: Search engine ('google', 'bing', 'duckduckgo')
    
    Returns:
        Search URL string
    """
    query_encoded = urllib.parse.quote_plus(query)
    
    engines = {
        "google": f"https://www.google.com/search?q={query_encoded}",
        "bing": f"https://www.bing.com/search?q={query_encoded}",
        "duckduckgo": f"https://duckduckgo.com/?q={query_encoded}",
    }
    
    return engines.get(engine.lower(), engines["google"])


def generate_allabolag_search(company_name: str) -> str:
    """Generate Allabolag.se search URL."""
    query = urllib.parse.quote_plus(company_name)
    return f"https://www.allabolag.se/what/{query}"


def generate_ratsit_search(company_name: str) -> str:
    """Generate Ratsit.se search URL."""
    query = urllib.parse.quote_plus(company_name)
    return f"https://www.ratsit.se/sok?q={query}"


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Generate search URLs when direct fetching is blocked",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "query",
        help="Search query or company name",
    )
    parser.add_argument(
        "--engine",
        choices=["google", "bing", "duckduckgo"],
        default="google",
        help="Search engine (default: google)",
    )
    parser.add_argument(
        "--allabolag",
        action="store_true",
        help="Generate Allabolag.se search URL",
    )
    parser.add_argument(
        "--ratsit",
        action="store_true",
        help="Generate Ratsit.se search URL",
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="Generate all search URLs",
    )
    
    args = parser.parse_args()
    
    results = []
    
    if args.allabolag or args.all:
        url = generate_allabolag_search(args.query)
        results.append(("Allabolag.se", url))
    
    if args.ratsit or args.all:
        url = generate_ratsit_search(args.query)
        results.append(("Ratsit.se", url))
    
    if not args.allabolag and not args.ratsit or args.all:
        url = generate_search_url(args.query, args.engine)
        results.append((f"{args.engine.capitalize()}", url))
    
    # Output results
    print("Search URLs generated:", file=sys.stderr)
    print("", file=sys.stderr)
    for name, url in results:
        print(f"{name}:")
        print(url)
        print()
    
    # Also output JSON for programmatic use
    import json
    output = {
        "query": args.query,
        "urls": {name.lower().replace(".", "_"): url for name, url in results}
    }
    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
