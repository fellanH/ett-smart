"""
Analytics Module - File-based Event Logging

Logs usage events to JSON file for PoC analytics tracking.
For production, consider migrating to Firestore or a proper analytics service.
"""

import json
import os
from datetime import datetime
from pathlib import Path
from typing import Dict, Optional
import threading

# Lock for thread-safe file writes
_file_lock = threading.Lock()

# Analytics file path (relative to webapp directory)
ANALYTICS_DIR = Path(__file__).parent.parent / "data"
ANALYTICS_FILE = ANALYTICS_DIR / "analytics.json"


def _ensure_analytics_file():
    """Create analytics file if it doesn't exist."""
    ANALYTICS_DIR.mkdir(exist_ok=True)
    if not ANALYTICS_FILE.exists():
        with open(ANALYTICS_FILE, 'w') as f:
            json.dump([], f)


def log_event(event_type: str, metadata: Optional[Dict] = None):
    """
    Log a custom analytics event to JSON file.

    Thread-safe with file locking for concurrent access.

    Args:
        event_type: Type of event (e.g., 'enrichment_started', 'export_downloaded')
        metadata: Optional dictionary of additional event data

    Event types used:
    - page_view: User visited a page
    - enrichment_started: Batch enrichment began
    - enrichment_completed: Batch enrichment finished
    - single_lookup: Single company lookup performed
    - export_downloaded: User downloaded results (csv, excel, crm)
    - lead_submitted: Lead form submitted
    """
    try:
        with _file_lock:
            _ensure_analytics_file()

            # Read existing events
            with open(ANALYTICS_FILE, 'r') as f:
                events = json.load(f)

            # Append new event
            events.append({
                "timestamp": datetime.now().isoformat(),
                "event_type": event_type,
                "metadata": metadata or {}
            })

            # Write back (keep last 10000 events to prevent unbounded growth)
            events = events[-10000:]

            with open(ANALYTICS_FILE, 'w') as f:
                json.dump(events, f, indent=2)

    except Exception as e:
        # Analytics should never crash the app
        print(f"Analytics error: {e}")


def get_events():
    """
    Read all analytics events from file.

    Returns:
        List of event dictionaries, or empty list if file doesn't exist
    """
    try:
        _ensure_analytics_file()
        with open(ANALYTICS_FILE, 'r') as f:
            return json.load(f)
    except Exception:
        return []
