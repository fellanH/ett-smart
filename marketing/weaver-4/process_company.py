#!/usr/bin/env python3
"""
Wrapper script for processing Swedish companies.
Automates the workflow: reads state, generates search URLs, and provides helpers for updating CSV.
"""

import csv
import json
import re
import sys
import subprocess
from pathlib import Path
from typing import Dict, List, Optional, Tuple


PROMPT_FILE = "PROMPT.md"
CSV_FILE = "blue-collar-companies.csv"


def read_progress_log() -> Dict[str, str]:
    """Read the progress log from PROMPT.md."""
    prompt_path = Path(PROMPT_FILE)
    if not prompt_path.exists():
        raise FileNotFoundError(f"{PROMPT_FILE} not found")
    
    content = prompt_path.read_text(encoding='utf-8')
    
    # Extract progress log section
    match = re.search(r'\[PROGRESS_LOG\](.*?)\[/PROGRESS_LOG\]', content, re.DOTALL)
    if not match:
        raise ValueError("PROGRESS_LOG section not found in PROMPT.md")
    
    log_content = match.group(1)
    
    # Parse key-value pairs
    progress = {}
    for line in log_content.strip().split('\n'):
        if ':' in line:
            key, value = line.split(':', 1)
            progress[key.strip()] = value.strip()
    
    return progress


def read_csv() -> Tuple[List[Dict[str, str]], List[str]]:
    """Read the CSV file and return rows and headers."""
    csv_path = Path(CSV_FILE)
    if not csv_path.exists():
        raise FileNotFoundError(f"{CSV_FILE} not found")
    
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        headers = reader.fieldnames
        rows = list(reader)
    
    return rows, headers


def get_next_company(rows: List[Dict[str, str]], next_index: int) -> Optional[Dict[str, str]]:
    """Get the company at the specified index."""
    if next_index >= len(rows):
        return None
    return rows[next_index]


def generate_search_urls(company_name: str) -> List[Dict[str, str]]:
    """Generate search URLs for a company using search_url_generator.py."""
    try:
        result = subprocess.run(
            ['python', 'search_url_generator.py', company_name, '--all', '--json'],
            capture_output=True,
            text=True,
            check=True
        )
        urls = json.loads(result.stdout)
        return urls
    except subprocess.CalledProcessError as e:
        print(f"Error generating URLs: {e.stderr}", file=sys.stderr)
        return []
    except json.JSONDecodeError as e:
        print(f"Error parsing JSON: {e}", file=sys.stderr)
        return []


def update_csv_row(rows: List[Dict[str, str]], row_index: int, updates: Dict[str, str]) -> None:
    """Update a specific row in the CSV data."""
    if row_index >= len(rows):
        raise IndexError(f"Row index {row_index} out of range")
    
    rows[row_index].update(updates)


def save_csv(rows: List[Dict[str, str]], headers: List[str]) -> None:
    """Save the CSV file."""
    csv_path = Path(CSV_FILE)
    with open(csv_path, 'w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=headers)
        writer.writeheader()
        writer.writerows(rows)


def update_progress_log(company_name: str, next_index: int, total_completed: int, is_complete: bool = False) -> None:
    """Update the progress log in PROMPT.md."""
    prompt_path = Path(PROMPT_FILE)
    content = prompt_path.read_text(encoding='utf-8')
    
    status = "COMPLETED" if is_complete else "IN_PROGRESS"
    
    new_log = f"""[PROGRESS_LOG]
Status: {status}
Last_Processed_Company: {company_name}
Next_Row_Index: {next_index}
Total_Rows_Completed: {total_completed}
[/PROGRESS_LOG]"""
    
    # Replace the progress log section
    pattern = r'\[PROGRESS_LOG\].*?\[/PROGRESS_LOG\]'
    content = re.sub(pattern, new_log, content, flags=re.DOTALL)
    
    prompt_path.write_text(content, encoding='utf-8')


def print_data_collected(data: Dict[str, str], headers: List[str]) -> None:
    """Print collected data in the required format."""
    print("\n=== DATA COLLECTED ===")
    for header in headers:
        if header == "Företagsnamn":
            continue  # Skip company name
        value = data.get(header, "")
        print(f"{header}: {value if value else 'NOT FOUND'}")


def main():
    """Main workflow."""
    try:
        # Step 1: Read state
        progress = read_progress_log()
        next_index = int(progress.get('Next_Row_Index', 0))
        total_completed = int(progress.get('Total_Rows_Completed', 0))
        
        # Read CSV
        rows, headers = read_csv()
        
        # Get next company
        company = get_next_company(rows, next_index)
        if not company:
            print("=== COMPLETE ===")
            print("All companies have been processed!")
            return
        
        company_name = company.get('Företagsnamn', '')
        
        print("=== STARTING ===")
        print(f"Company: {company_name}")
        print(f"Row Index: {next_index}")
        
        # Step 2: Generate search URLs
        print("\n=== GENERATING SEARCH URLS ===")
        search_urls = generate_search_urls(company_name)
        
        if not search_urls:
            print("Warning: Could not generate search URLs. Please check search_url_generator.py")
            return
        
        print(f"Generated {len(search_urls)} search URLs:\n")
        for i, item in enumerate(search_urls, 1):
            print(f"{i}. {item['purpose']}")
            print(f"   Query: {item['query']}")
            print(f"   URL: {item['url']}\n")
        
        print("\n=== NEXT STEPS ===")
        print("1. Use 'mcp_web_fetch' to fetch each URL above")
        print("2. Parse the HTML content to extract company data")
        print("3. Update the CSV row with collected data")
        print("4. Update the progress log")
        print("\nTo update CSV and progress, use:")
        print(f"  python process_company.py --update --row {next_index} --data '{{\"VD\": \"Name\", \"VD E-post\": \"email@example.com\", ...}}'")
        print("\nOr manually edit the CSV and PROMPT.md files.")
        
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


def update_mode():
    """Handle --update flag to update CSV and progress log."""
    if '--update' not in sys.argv:
        return False
    
    try:
        # Parse arguments
        row_index = None
        data_json = None
        
        for i, arg in enumerate(sys.argv):
            if arg == '--row' and i + 1 < len(sys.argv):
                row_index = int(sys.argv[i + 1])
            elif arg == '--data' and i + 1 < len(sys.argv):
                data_json = sys.argv[i + 1]
        
        if row_index is None or data_json is None:
            print("Usage: python process_company.py --update --row <index> --data '<json>'")
            return True
        
        # Parse JSON data
        updates = json.loads(data_json)
        
        # Read current state
        progress = read_progress_log()
        current_index = int(progress.get('Next_Row_Index', 0))
        total_completed = int(progress.get('Total_Rows_Completed', 0))
        
        if row_index != current_index:
            print(f"Warning: Row index {row_index} doesn't match current index {current_index}")
        
        # Read CSV
        rows, headers = read_csv()
        
        # Get company name
        company = rows[row_index]
        company_name = company.get('Företagsnamn', '')
        
        # Update CSV row
        update_csv_row(rows, row_index, updates)
        save_csv(rows, headers)
        
        # Update progress log
        next_index = row_index + 1
        total_completed += 1
        is_complete = next_index >= len(rows)
        
        update_progress_log(company_name, next_index, total_completed, is_complete)
        
        print("=== COMPLETE ===")
        print(f"Updated: {company_name}")
        print(f"Next Row Index: {next_index}")
        print(f"Total Completed: {total_completed}")
        
        return True
        
    except Exception as e:
        print(f"Error updating: {e}", file=sys.stderr)
        return True


if __name__ == "__main__":
    if update_mode():
        sys.exit(0)
    main()
