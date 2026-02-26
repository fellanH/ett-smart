"""
File Validation Module for Company Enrichment Platform

Provides utilities for:
- CSV formula injection prevention (cell sanitization)
- File encoding detection
- CSV file validation with error messages
"""

import pandas as pd
from io import BytesIO
from typing import Dict, List, Optional, Any

try:
    from charset_normalizer import from_bytes
except ImportError:
    from_bytes = None


def sanitize_cell(value: Any) -> str:
    """
    Sanitize a cell value to prevent CSV formula injection.

    Formula injection occurs when cell values start with characters that
    spreadsheet applications interpret as formulas: = + - @ or tab.
    We prefix these with a single quote to prevent execution.

    Exception: URLs starting with "http" are NOT sanitized to keep them clickable.

    Args:
        value: Cell value to sanitize (can be any type)

    Returns:
        Sanitized string value
    """
    # Handle None and non-string values
    if value is None:
        return ""

    if not isinstance(value, str):
        return str(value)

    # Don't sanitize URLs - keep them clickable
    if value.lower().startswith("http"):
        return value

    # Characters that trigger formula interpretation in Excel/Sheets
    dangerous_prefixes = ('=', '+', '-', '@', '\t')

    if value.startswith(dangerous_prefixes):
        return "'" + value

    return value


def detect_encoding(file_bytes: bytes, sample_size: int = 10000) -> str:
    """
    Detect file encoding using charset-normalizer library.

    Args:
        file_bytes: Raw file bytes to analyze
        sample_size: Number of bytes to sample for detection (default 10KB)

    Returns:
        Detected encoding string (defaults to 'utf-8' if detection fails)
    """
    # Handle empty files
    if not file_bytes:
        return 'utf-8'

    # Sample first N bytes for performance
    sample = file_bytes[:sample_size]

    # Use charset-normalizer if available
    if from_bytes is not None:
        try:
            result = from_bytes(sample).best()
            if result is not None:
                return result.encoding
        except Exception:
            pass

    # Default fallback
    return 'utf-8'


def validate_csv_file(uploaded_file) -> Dict[str, Any]:
    """
    Validate an uploaded CSV file before processing.

    Performs comprehensive validation:
    - Checks if file is empty
    - Detects encoding automatically
    - Parses CSV with error handling
    - Verifies data rows exist (not just headers)
    - Tracks malformed rows with warnings

    Args:
        uploaded_file: Streamlit UploadedFile object or file-like object
            Must have .read() method and optionally .name attribute

    Returns:
        Dictionary with keys:
        - valid (bool): Whether file passed validation
        - error (str|None): Error message if invalid
        - warnings (list): List of warning messages
        - df (DataFrame|None): Parsed DataFrame if valid
    """
    result = {
        "valid": False,
        "error": None,
        "warnings": [],
        "df": None
    }

    try:
        # Read file content
        uploaded_file.seek(0)
        file_bytes = uploaded_file.read()
        uploaded_file.seek(0)  # Reset for potential re-read

        # Check for empty file
        if len(file_bytes) == 0:
            result["error"] = "File is empty"
            return result

        # Detect encoding
        encoding = detect_encoding(file_bytes)

        # Track malformed rows
        bad_lines_count = 0

        def count_bad_lines(bad_line):
            nonlocal bad_lines_count
            bad_lines_count += 1
            return None

        # Parse CSV with error handling
        try:
            # Create BytesIO for pandas
            file_buffer = BytesIO(file_bytes)

            # Try to parse with on_bad_lines='warn' to count issues
            df = pd.read_csv(
                file_buffer,
                encoding=encoding,
                on_bad_lines='skip'
            )

            # Count skipped rows by comparing expected vs actual
            file_buffer.seek(0)
            try:
                total_lines = sum(1 for _ in file_buffer) - 1  # Subtract header
                if total_lines > len(df):
                    bad_lines_count = total_lines - len(df)
            except Exception:
                pass

        except pd.errors.EmptyDataError:
            result["error"] = "File is empty"
            return result
        except pd.errors.ParserError as e:
            result["error"] = f"Invalid CSV format: Unable to parse file. {str(e)}"
            return result
        except UnicodeDecodeError:
            # Try with a different encoding
            try:
                file_buffer = BytesIO(file_bytes)
                df = pd.read_csv(file_buffer, encoding='latin-1', on_bad_lines='skip')
            except Exception as e:
                result["error"] = f"Invalid CSV format: Unable to decode file. Try saving as UTF-8."
                return result

        # Check for headers only (no data rows)
        if len(df) == 0:
            result["error"] = "File contains only headers, no data rows"
            return result

        # Add warning for malformed rows
        if bad_lines_count > 0:
            result["warnings"].append(
                f"Skipped {bad_lines_count} malformed row(s) during import"
            )

        # Validation passed
        result["valid"] = True
        result["df"] = df
        return result

    except Exception as e:
        result["error"] = f"Error reading file: {str(e)}"
        return result
