#!/usr/bin/env python3
"""
Batch URL Fetcher with Rate Limiting and Error Handling

Fetches multiple URLs with rate limiting to avoid throttling.
Handles invalid URLs, retries on failures, and outputs JSON results.

Usage:
    # From command line with URLs as arguments
    python batch_fetch.py https://example.com https://example.org

    # From stdin (one URL per line)
    echo -e "https://example.com\nhttps://example.org" | python batch_fetch.py

    # With custom rate limit
    python batch_fetch.py --delay 2.0 --max-retries 3 https://example.com

    # Output to file
    python batch_fetch.py --output results.json https://example.com
"""

import sys
import json
import time
import argparse
import urllib.parse
from typing import List, Dict, Optional, Tuple
from urllib.parse import urlparse, urlunparse
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry


class BatchFetcher:
    """Batch URL fetcher with rate limiting and error handling."""

    def __init__(
        self,
        delay: float = 1.0,
        max_retries: int = 3,
        timeout: int = 30,
        user_agent: Optional[str] = None,
    ):
        """
        Initialize batch fetcher.

        Args:
            delay: Seconds to wait between requests (default: 1.0)
            max_retries: Maximum retry attempts for failed requests (default: 3)
            timeout: Request timeout in seconds (default: 30)
            user_agent: Custom User-Agent string (default: None)
        """
        self.delay = delay
        self.max_retries = max_retries
        self.timeout = timeout
        self.user_agent = user_agent or (
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
            "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        )

        # Setup session with retry strategy
        self.session = requests.Session()
        retry_strategy = Retry(
            total=max_retries,
            backoff_factor=1,
            status_forcelist=[429, 500, 502, 503, 504],
            allowed_methods=["GET", "HEAD"],
        )
        adapter = HTTPAdapter(max_retries=retry_strategy)
        self.session.mount("http://", adapter)
        self.session.mount("https://", adapter)
        
        # Set realistic browser headers to avoid blocking
        self.session.headers.update({
            "User-Agent": self.user_agent,
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.9,sv;q=0.8",
            "Accept-Encoding": "gzip, deflate, br",
            "DNT": "1",
            "Connection": "keep-alive",
            "Upgrade-Insecure-Requests": "1",
            "Sec-Fetch-Dest": "document",
            "Sec-Fetch-Mode": "navigate",
            "Sec-Fetch-Site": "none",
            "Sec-Fetch-User": "?1",
            "Cache-Control": "max-age=0",
        })

    def validate_url(self, url: str) -> Tuple[bool, Optional[str], Optional[str]]:
        """
        Validate and normalize URL.

        Returns:
            Tuple of (is_valid, normalized_url, error_message)
        """
        if not url or not isinstance(url, str):
            return False, None, "URL is empty or not a string"

        url = url.strip()
        if not url:
            return False, None, "URL is empty after stripping"

        # Try to parse URL
        try:
            parsed = urlparse(url)
        except Exception as e:
            return False, None, f"URL parse error: {str(e)}"

        # Check if URL has scheme
        if not parsed.scheme:
            # Try adding https://
            try:
                url = "https://" + url
                parsed = urlparse(url)
            except Exception:
                return False, None, "URL missing scheme and cannot add https://"

        # Validate scheme
        if parsed.scheme not in ("http", "https"):
            return False, None, f"Invalid scheme: {parsed.scheme}"

        # Validate netloc (domain)
        if not parsed.netloc:
            return False, None, "URL missing domain (netloc)"

        # Normalize URL
        normalized = urlunparse(
            (
                parsed.scheme.lower(),
                parsed.netloc.lower(),
                parsed.path or "/",
                parsed.params,
                parsed.query,
                "",  # Remove fragment
            )
        )

        return True, normalized, None

    def fetch_url(self, url: str) -> Dict:
        """
        Fetch a single URL with error handling.

        Returns:
            Dictionary with result data
        """
        # Validate URL
        is_valid, normalized_url, error = self.validate_url(url)
        if not is_valid:
            return {
                "url": url,
                "normalized_url": None,
                "success": False,
                "status_code": None,
                "error": error,
                "content_length": None,
                "content_type": None,
                "final_url": None,
            }

        # Attempt fetch with retries
        for attempt in range(self.max_retries + 1):
            try:
                response = self.session.get(
                    normalized_url, timeout=self.timeout, allow_redirects=True
                )
                
                # Handle HTTP error status codes
                if response.status_code == 403:
                    return {
                        "url": url,
                        "normalized_url": normalized_url,
                        "success": False,
                        "status_code": 403,
                        "error": "Access forbidden - website blocked automated requests (403 Forbidden)",
                        "content_length": len(response.content) if response.content else None,
                        "content_type": response.headers.get("Content-Type"),
                        "final_url": response.url,
                        "blocked": True,
                    }
                elif response.status_code == 401:
                    return {
                        "url": url,
                        "normalized_url": normalized_url,
                        "success": False,
                        "status_code": 401,
                        "error": "Unauthorized - authentication required (401 Unauthorized)",
                        "content_length": len(response.content) if response.content else None,
                        "content_type": response.headers.get("Content-Type"),
                        "final_url": response.url,
                        "blocked": True,
                    }
                elif response.status_code >= 400:
                    error_msg = f"HTTP {response.status_code} - {response.reason}"
                    # Don't retry 4xx errors (client errors)
                    return {
                        "url": url,
                        "normalized_url": normalized_url,
                        "success": False,
                        "status_code": response.status_code,
                        "error": error_msg,
                        "content_length": len(response.content) if response.content else None,
                        "content_type": response.headers.get("Content-Type"),
                        "final_url": response.url,
                    }
                
                # Success (2xx status codes)
                return {
                    "url": url,
                    "normalized_url": normalized_url,
                    "success": True,
                    "status_code": response.status_code,
                    "error": None,
                    "content_length": len(response.content),
                    "content_type": response.headers.get("Content-Type"),
                    "final_url": response.url,
                }
                
            except requests.exceptions.Timeout:
                error_msg = f"Timeout after {self.timeout}s"
                if attempt < self.max_retries:
                    time.sleep(2 ** attempt)  # Exponential backoff
                    continue
            except requests.exceptions.ConnectionError as e:
                error_msg = f"Connection error: {str(e)}"
                if attempt < self.max_retries:
                    time.sleep(2 ** attempt)
                    continue
            except requests.exceptions.TooManyRedirects:
                error_msg = "Too many redirects"
                break  # Don't retry redirect loops
            except requests.exceptions.HTTPError as e:
                # Handle HTTP errors that weren't caught above
                if e.response is not None:
                    status_code = e.response.status_code
                    if status_code == 403:
                        return {
                            "url": url,
                            "normalized_url": normalized_url,
                            "success": False,
                            "status_code": 403,
                            "error": "Access forbidden - website blocked automated requests (403 Forbidden)",
                            "content_length": None,
                            "content_type": None,
                            "final_url": None,
                            "blocked": True,
                        }
                error_msg = f"HTTP error: {str(e)}"
                break  # Don't retry HTTP errors
            except requests.exceptions.RequestException as e:
                error_msg = f"Request error: {str(e)}"
                if attempt < self.max_retries:
                    time.sleep(2 ** attempt)
                    continue
            except Exception as e:
                error_msg = f"Unexpected error: {str(e)}"
                break  # Don't retry unexpected errors

        return {
            "url": url,
            "normalized_url": normalized_url,
            "success": False,
            "status_code": None,
            "error": error_msg,
            "content_length": None,
            "content_type": None,
            "final_url": None,
        }

    def fetch_batch(self, urls: List[str], verbose: bool = False) -> List[Dict]:
        """
        Fetch multiple URLs with rate limiting.

        Args:
            urls: List of URLs to fetch
            verbose: Print progress to stderr

        Returns:
            List of result dictionaries
        """
        results = []
        total = len(urls)

        for idx, url in enumerate(urls, 1):
            if verbose:
                print(f"[{idx}/{total}] Fetching: {url}", file=sys.stderr)

            result = self.fetch_url(url)
            results.append(result)

            if verbose:
                status = "✓" if result["success"] else "✗"
                status_code = result.get('status_code', 'N/A')
                error = result.get('error', 'OK')
                if result.get('blocked'):
                    print(
                        f"  {status} {status_code} - ⚠️  BLOCKED: {error}",
                        file=sys.stderr,
                    )
                else:
                    print(
                        f"  {status} {status_code} - {error}",
                        file=sys.stderr,
                    )

            # Rate limiting: wait between requests (except for last one)
            if idx < total:
                time.sleep(self.delay)

        return results


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Batch fetch URLs with rate limiting and error handling",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "urls",
        nargs="*",
        help="URLs to fetch (if not provided, read from stdin)",
    )
    parser.add_argument(
        "--delay",
        type=float,
        default=1.0,
        help="Delay between requests in seconds (default: 1.0)",
    )
    parser.add_argument(
        "--max-retries",
        type=int,
        default=3,
        help="Maximum retry attempts (default: 3)",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=30,
        help="Request timeout in seconds (default: 30)",
    )
    parser.add_argument(
        "--output",
        "-o",
        help="Output file path (default: stdout)",
    )
    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Print progress to stderr",
    )
    parser.add_argument(
        "--user-agent",
        help="Custom User-Agent string",
    )

    args = parser.parse_args()

    # Get URLs from args or stdin
    urls = args.urls
    if not urls:
        urls = [line.strip() for line in sys.stdin if line.strip()]

    if not urls:
        print("Error: No URLs provided", file=sys.stderr)
        parser.print_help()
        sys.exit(1)

    # Create fetcher
    fetcher = BatchFetcher(
        delay=args.delay,
        max_retries=args.max_retries,
        timeout=args.timeout,
        user_agent=args.user_agent,
    )

    # Fetch URLs
    try:
        results = fetcher.fetch_batch(urls, verbose=args.verbose)
    except KeyboardInterrupt:
        print("\nInterrupted by user", file=sys.stderr)
        sys.exit(130)

    # Prepare output
    blocked_count = sum(1 for r in results if r.get("blocked", False))
    output_data = {
        "total": len(results),
        "successful": sum(1 for r in results if r["success"]),
        "failed": sum(1 for r in results if not r["success"]),
        "blocked": blocked_count,
        "results": results,
    }
    
    if args.verbose and blocked_count > 0:
        print(
            f"\n⚠️  Warning: {blocked_count} URL(s) were blocked (403/401). "
            "These websites may require manual access or different access methods.",
            file=sys.stderr,
        )

    # Output results
    output_json = json.dumps(output_data, indent=2)
    if args.output:
        with open(args.output, "w") as f:
            f.write(output_json)
        if args.verbose:
            print(f"\nResults saved to {args.output}", file=sys.stderr)
    else:
        print(output_json)

    # Exit with error code if any failed
    sys.exit(0 if output_data["failed"] == 0 else 1)


if __name__ == "__main__":
    main()
