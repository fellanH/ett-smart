#!/usr/bin/env python3
"""Test script to validate batch_fetch.py and search_helper.py tools"""

import subprocess
import json
import sys

# Test companies from CSV (rows 145-154)
COMPANIES = [
    "Delta Group Ab",
    "Destroy Rebuilding Company Aktiebolag",
    "Diamond Express Åkeri Ab",
    "Din Bil Sverige Ab",
    "Direktstäd I Stockholm Ab",
]

print("=" * 60)
print("Testing Tools with Sample Companies")
print("=" * 60)
print()

# Test 1: Generate search URLs
print("1. Testing search_helper.py - Generating search URLs")
print("-" * 60)
urls = []
for company in COMPANIES:
    try:
        result = subprocess.run(
            ["python3", "search_helper.py", company, "--allabolag", "--ratsit"],
            capture_output=True,
            text=True,
            check=True
        )
        # search_helper outputs text to stderr and JSON to stdout
        # Extract JSON from stdout (multiline JSON)
        stdout = result.stdout.strip()
        if stdout:
            # Try to parse multiline JSON - find the JSON object
            lines = stdout.split('\n')
            json_start = None
            json_end = None
            brace_count = 0
            
            # Find JSON object boundaries
            for i, line in enumerate(lines):
                if '{' in line and json_start is None:
                    json_start = i
                    brace_count = line.count('{') - line.count('}')
                elif json_start is not None:
                    brace_count += line.count('{') - line.count('}')
                    if brace_count == 0:
                        json_end = i + 1
                        break
            
            if json_start is not None:
                json_lines = lines[json_start:json_end] if json_end else lines[json_start:]
                json_text = '\n'.join(json_lines)
                try:
                    data = json.loads(json_text)
                    json_line = json_text
                except:
                    json_line = None
            else:
                json_line = None
        else:
            json_line = None
        
        if json_line:
            data = json.loads(json_line)
            allabolag_url = data['urls'].get('allabolag_se')
            if allabolag_url:
                urls.append(allabolag_url)
                print(f"✓ {company}")
                print(f"  → {allabolag_url}")
            else:
                print(f"✗ {company} - No URL generated")
        else:
            print(f"✗ {company} - No JSON output")
    except Exception as e:
        print(f"✗ {company} - Error: {e}")

print()
print(f"Generated {len(urls)} URLs for testing")
print()

# Test 2: Fetch URLs with batch_fetch.py
if urls:
    print("2. Testing batch_fetch.py - Fetching URLs")
    print("-" * 60)
    print(f"Testing with {len(urls)} URLs...")
    print()
    
    try:
        # Run batch_fetch with the URLs
        result = subprocess.run(
            ["python3", "batch_fetch.py", "--delay", "2.0", "--verbose", "--output", "test_results.json"] + urls[:3],  # Test first 3
            text=True,
            check=False
        )
        
        # Read and display results
        try:
            with open("test_results.json", "r") as f:
                data = json.load(f)
            
            print()
            print("Results Summary:")
            print(f"  Total: {data['total']}")
            print(f"  Successful: {data['successful']}")
            print(f"  Failed: {data['failed']}")
            print(f"  Blocked: {data.get('blocked', 0)}")
            print()
            
            print("Detailed Results:")
            for r in data['results']:
                status = "✓" if r['success'] else "✗"
                blocked = " [BLOCKED]" if r.get('blocked') else ""
                print(f"  {status} {r['url']}")
                if r['status_code']:
                    print(f"    Status: {r['status_code']}")
                if r['error']:
                    print(f"    Error: {r['error']}{blocked}")
                print()
        except FileNotFoundError:
            print("✗ Results file not found")
        except json.JSONDecodeError as e:
            print(f"✗ Error parsing results: {e}")
            
    except Exception as e:
        print(f"✗ Error running batch_fetch: {e}")

print()
print("=" * 60)
print("Test Complete")
print("=" * 60)
