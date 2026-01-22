#!/bin/bash
# Test script to validate batch_fetch.py and search_helper.py tools

set -e

echo "=========================================="
echo "Testing Tools with Sample Companies"
echo "=========================================="
echo ""

# Test companies from CSV (rows 145-154)
COMPANIES=(
    "Delta Group Ab"
    "Destroy Rebuilding Company Aktiebolag"
    "Diamond Express Åkeri Ab"
    "Din Bil Sverige Ab"
    "Direktstäd I Stockholm Ab"
)

echo "1. Testing search_helper.py - Generating search URLs"
echo "---------------------------------------------------"
for company in "${COMPANIES[@]}"; do
    echo ""
    echo "Company: $company"
    python3 search_helper.py "$company" --allabolag --ratsit | grep -E "(Allabolag|Ratsit|urls)" | head -3
done

echo ""
echo ""
echo "2. Testing batch_fetch.py - Fetching URLs"
echo "---------------------------------------------------"

# Generate URLs first
URLS=()
for company in "${COMPANIES[@]}"; do
    allabolag_url=$(python3 search_helper.py "$company" --allabolag --ratsit 2>/dev/null | grep -oP 'allabolag_se": "\K[^"]+')
    if [[ -n "$allabolag_url" ]]; then
        URLS+=("$allabolag_url")
    fi
done

if [[ ${#URLS[@]} -gt 0 ]]; then
    echo "Testing with ${#URLS[@]} URLs..."
    echo "${URLS[@]}" | tr ' ' '\n' | python3 batch_fetch.py --delay 2.0 --verbose --output test_results.json
    echo ""
    echo "Results saved to test_results.json"
    echo ""
    echo "Summary:"
    python3 -c "import json; d=json.load(open('test_results.json')); print(f\"Total: {d['total']}, Successful: {d['successful']}, Failed: {d['failed']}, Blocked: {d.get('blocked', 0)}\")"
else
    echo "No URLs generated for testing"
fi

echo ""
echo "=========================================="
echo "Test Complete"
echo "=========================================="
