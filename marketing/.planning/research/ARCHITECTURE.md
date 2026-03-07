# Architecture Patterns for Web-Wrapped Python Scripts

**Domain:** Web interface for existing data enrichment CLI tools
**Researched:** 2026-01-22
**Confidence:** HIGH (verified with official docs and current best practices)

## Executive Summary

This architecture wraps existing Python CLI scripts (batch_fetch.py, search_helper.py, csv_to_excel.py) in a web interface for CSV upload and single company lookups. The recommended approach is a **three-tier architecture** with Flask for the web layer, SQLite for simple job tracking, and direct subprocess calls to existing scripts.

**Key decision:** For a PoC, prioritize **simplicity over scalability**. Use Flask (not FastAPI), SQLite (not PostgreSQL), and synchronous processing (not Celery queues) to minimize setup overhead while keeping migration paths open for production.

## Recommended Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     PRESENTATION LAYER                      │
│  ┌───────────────┐  ┌──────────────┐  ┌─────────────────┐ │
│  │ Upload Form   │  │ Single Lookup│  │ Results Display │ │
│  │ (CSV file)    │  │ Form         │  │ (HTML + Download)│ │
│  └───────────────┘  └──────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                            ↕ HTTP
┌─────────────────────────────────────────────────────────────┐
│                    APPLICATION LAYER (Flask)                │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Route Handlers                                       │  │
│  │  • /upload (POST)    → CSV batch processing         │  │
│  │  • /lookup (POST)    → Single company lookup        │  │
│  │  • /results/<id>     → Display results             │  │
│  │  • /download/<id>    → Download Excel file         │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Business Logic Layer                                 │  │
│  │  • Input validation & sanitization                   │  │
│  │  • Script orchestration (subprocess calls)           │  │
│  │  • Result aggregation                                │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            ↕
┌─────────────────────────────────────────────────────────────┐
│               EXISTING SCRIPT LAYER (Subprocess)            │
│  ┌────────────────┐  ┌────────────────┐  ┌──────────────┐ │
│  │ batch_fetch.py │  │search_helper.py│  │csv_to_excel  │ │
│  │ (URL fetching) │  │(URL generation)│  │(Excel export)│ │
│  └────────────────┘  └────────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────────┘
                            ↕
┌─────────────────────────────────────────────────────────────┐
│                       DATA LAYER                            │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐  │
│  │ SQLite DB    │  │ Upload Files │  │ Result Files    │  │
│  │ (job tracking)│  │ /uploads/   │  │ /results/       │  │
│  └──────────────┘  └──────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Component Boundaries

| Component               | Responsibility                                      | Communicates With                 |
| ----------------------- | --------------------------------------------------- | --------------------------------- |
| **Flask App**           | HTTP routing, request handling, response rendering  | All components (orchestrator)     |
| **Upload Handler**      | Validate CSV, save to disk, create job record       | Flask routes, SQLite, File System |
| **Script Orchestrator** | Call existing Python scripts via subprocess.run()   | Existing scripts (one-way)        |
| **Result Aggregator**   | Collect script outputs, format for display          | Script Orchestrator, Templates    |
| **SQLite Database**     | Track jobs, status, file paths (metadata only)      | Flask app (via sqlite3 module)    |
| **File System**         | Store uploaded CSVs, generated results, Excel files | All layers (read/write)           |
| **Templates**           | Render HTML for forms, results, error pages         | Flask app (Jinja2)                |

### Data Flow

#### Batch Upload Flow

```
1. User uploads CSV via /upload
   ↓
2. Flask validates file (size, extension, content)
   ↓
3. Save CSV to /uploads/{job_id}.csv
   ↓
4. Create job record in SQLite (status: processing)
   ↓
5. For each row in CSV:
   a. Call search_helper.py to generate URLs
   b. Call batch_fetch.py to fetch company data
   c. Aggregate results into temporary structure
   ↓
6. Call csv_to_excel.py to generate final Excel file
   ↓
7. Update job status (status: completed)
   ↓
8. Redirect to /results/{job_id}
```

#### Single Lookup Flow

```
1. User enters company name in /lookup form
   ↓
2. Flask validates input (non-empty, safe)
   ↓
3. Call search_helper.py with company name
   ↓
4. Call batch_fetch.py with generated URLs
   ↓
5. Parse results, render in HTML table
   ↓
6. Display results immediately (no DB storage for single lookups)
```

## Patterns to Follow

### Pattern 1: Direct Script Invocation (Recommended for PoC)

**What:** Use Python's `subprocess.run()` to call existing scripts directly without modification.

**When:** Scripts are stable, stateless, and designed for CLI use (like batch_fetch.py).

**Why:** Preserves existing scripts unchanged, simplest integration path, easy to debug.

**Example:**

```python
import subprocess
import json
from pathlib import Path

def fetch_company_data(urls: list[str], job_id: str) -> dict:
    """Call batch_fetch.py to fetch multiple URLs."""
    output_file = Path(f"/tmp/fetch_results_{job_id}.json")

    result = subprocess.run(
        [
            "python3", "weaver-5/batch_fetch.py",
            "--delay", "1.5",
            "--output", str(output_file),
            "--verbose",
            *urls
        ],
        capture_output=True,
        text=True,
        timeout=300,  # 5 minute timeout
        check=False   # Don't raise on non-zero exit
    )

    if result.returncode != 0:
        raise RuntimeError(f"Fetch failed: {result.stderr}")

    with open(output_file) as f:
        return json.load(f)
```

**Security considerations:**

- NEVER pass unsanitized user input directly to subprocess
- Use list form (not shell=True) to avoid shell injection
- Validate all inputs before passing to scripts
- Set timeouts to prevent hung processes

### Pattern 2: Repository Pattern for Job Storage

**What:** Separate database access logic from business logic using a repository class.

**When:** Managing job records, file paths, status tracking.

**Example:**

```python
from dataclasses import dataclass
from datetime import datetime
import sqlite3
from typing import Optional

@dataclass
class Job:
    id: str
    status: str  # 'processing', 'completed', 'failed'
    input_file: str
    output_file: Optional[str]
    created_at: datetime
    completed_at: Optional[datetime]
    error_message: Optional[str]

class JobRepository:
    def __init__(self, db_path: str):
        self.db_path = db_path
        self._init_db()

    def _init_db(self):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute('''
                CREATE TABLE IF NOT EXISTS jobs (
                    id TEXT PRIMARY KEY,
                    status TEXT NOT NULL,
                    input_file TEXT NOT NULL,
                    output_file TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    completed_at TIMESTAMP,
                    error_message TEXT
                )
            ''')

    def create(self, job: Job) -> None:
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                'INSERT INTO jobs (id, status, input_file) VALUES (?, ?, ?)',
                (job.id, job.status, job.input_file)
            )

    def update_status(self, job_id: str, status: str,
                     output_file: Optional[str] = None,
                     error_message: Optional[str] = None) -> None:
        with sqlite3.connect(self.db_path) as conn:
            if status == 'completed':
                conn.execute(
                    '''UPDATE jobs
                       SET status=?, output_file=?, completed_at=CURRENT_TIMESTAMP
                       WHERE id=?''',
                    (status, output_file, job_id)
                )
            elif status == 'failed':
                conn.execute(
                    '''UPDATE jobs
                       SET status=?, error_message=?, completed_at=CURRENT_TIMESTAMP
                       WHERE id=?''',
                    (status, error_message, job_id)
                )

    def get(self, job_id: str) -> Optional[Job]:
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row
            row = conn.execute(
                'SELECT * FROM jobs WHERE id = ?', (job_id,)
            ).fetchone()

            if not row:
                return None

            return Job(
                id=row['id'],
                status=row['status'],
                input_file=row['input_file'],
                output_file=row['output_file'],
                created_at=datetime.fromisoformat(row['created_at']),
                completed_at=datetime.fromisoformat(row['completed_at'])
                    if row['completed_at'] else None,
                error_message=row['error_message']
            )
```

### Pattern 3: Secure File Upload Handling

**What:** Validate, sanitize, and safely store uploaded files.

**When:** Accepting CSV uploads from users.

**Example:**

```python
from flask import Flask, request, abort
from werkzeug.utils import secure_filename
import uuid
from pathlib import Path

app = Flask(__name__)
app.config['UPLOAD_FOLDER'] = Path('/var/www/uploads')
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB limit
ALLOWED_EXTENSIONS = {'csv'}

def allowed_file(filename: str) -> bool:
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@app.route('/upload', methods=['POST'])
def upload_file():
    if 'file' not in request.files:
        abort(400, 'No file part in request')

    file = request.files['file']

    if file.filename == '':
        abort(400, 'No file selected')

    if not allowed_file(file.filename):
        abort(400, 'Only CSV files allowed')

    # Generate unique job ID and secure filename
    job_id = str(uuid.uuid4())
    filename = f"{job_id}.csv"
    filepath = app.config['UPLOAD_FOLDER'] / filename

    # Save file
    file.save(filepath)

    # Validate CSV structure (basic check)
    try:
        import csv
        with open(filepath, 'r') as f:
            reader = csv.DictReader(f)
            headers = reader.fieldnames
            if 'Company Name' not in headers:
                filepath.unlink()  # Delete invalid file
                abort(400, 'CSV must contain "Company Name" column')
    except Exception as e:
        if filepath.exists():
            filepath.unlink()
        abort(400, f'Invalid CSV format: {str(e)}')

    return {'job_id': job_id, 'filename': filename}, 202
```

### Pattern 4: Template-Based Result Display

**What:** Use Jinja2 templates to render results in browser-friendly format.

**When:** Displaying enriched company data, job status, error messages.

**Example structure:**

```html
<!-- templates/results.html -->
<!DOCTYPE html>
<html>
  <head>
    <title>Results for Job {{ job.id }}</title>
    <style>
      table {
        border-collapse: collapse;
        width: 100%;
      }
      th,
      td {
        border: 1px solid #ddd;
        padding: 8px;
        text-align: left;
      }
      th {
        background-color: #366092;
        color: white;
      }
      .status-completed {
        color: green;
      }
      .status-failed {
        color: red;
      }
    </style>
  </head>
  <body>
    <h1>Job {{ job.id }}</h1>
    <p>Status: <span class="status-{{ job.status }}">{{ job.status }}</span></p>

    {% if job.status == 'completed' %}
    <a href="/download/{{ job.id }}" download>Download Excel Results</a>

    <h2>Preview (First 10 rows)</h2>
    <table>
      <thead>
        <tr>
          {% for header in results.headers %}
          <th>{{ header }}</th>
          {% endfor %}
        </tr>
      </thead>
      <tbody>
        {% for row in results.rows[:10] %}
        <tr>
          {% for cell in row %}
          <td>{{ cell }}</td>
          {% endfor %}
        </tr>
        {% endfor %}
      </tbody>
    </table>
    {% elif job.status == 'failed' %}
    <p class="error">Error: {{ job.error_message }}</p>
    {% else %}
    <p>Processing... <a href="/results/{{ job.id }}">Refresh</a></p>
    {% endif %}
  </body>
</html>
```

## Anti-Patterns to Avoid

### Anti-Pattern 1: Blocking Requests During Long Processing

**What:** Processing entire CSV upload synchronously within HTTP request handler.

**Why bad:**

- Request timeouts (most web servers timeout after 30-60 seconds)
- Poor UX (user sees loading spinner for minutes)
- Can't handle concurrent requests
- Browser may disconnect during long operations

**Instead:**
For PoC: Accept upload, return immediately with job_id, redirect to status page with auto-refresh.
For Production: Use Celery + Redis for background processing.

**PoC Example:**

```python
@app.route('/upload', methods=['POST'])
def upload_file():
    # Save file and create job (fast)
    job_id = save_upload(request.files['file'])

    # Return immediately, don't wait for processing
    return redirect(f'/results/{job_id}')

@app.route('/results/<job_id>')
def show_results(job_id):
    job = job_repo.get(job_id)

    if job.status == 'pending':
        # Trigger processing asynchronously or show "queued" message
        # For PoC, could use threading (not recommended for production)
        import threading
        threading.Thread(target=process_job, args=(job_id,)).start()
        return render_template('processing.html', job=job)

    return render_template('results.html', job=job)
```

### Anti-Pattern 2: Storing Large Data in Database

**What:** Storing entire CSV contents or fetched HTML in SQLite BLOBs.

**Why bad:**

- Database bloat (SQLite performs poorly with large BLOBs)
- Memory issues when loading results
- Slow queries
- Difficult backups

**Instead:** Store only metadata in database, keep files on disk.

```python
# BAD
job = {
    'id': job_id,
    'csv_content': csv_blob,  # Multi-MB blob
    'html_results': html_blob  # Large HTML strings
}

# GOOD
job = {
    'id': job_id,
    'input_file': '/uploads/12345.csv',  # File path only
    'output_file': '/results/12345.xlsx',
    'status': 'completed'
}
```

### Anti-Pattern 3: Modifying Existing Scripts

**What:** Editing batch_fetch.py, search_helper.py to add web-specific logic.

**Why bad:**

- Breaks CLI usage (existing workflows)
- Mixes concerns (web logic in data fetching)
- Harder to test independently
- Violates separation of concerns

**Instead:** Keep scripts unchanged, orchestrate them from Flask layer.

```python
# BAD: Modifying batch_fetch.py to accept Flask request objects

# GOOD: Flask layer translates web requests to CLI calls
@app.route('/fetch', methods=['POST'])
def fetch_companies():
    urls = request.json['urls']

    # Validate in web layer
    if not urls or len(urls) > 100:
        abort(400)

    # Call unchanged script
    result = subprocess.run(
        ['python3', 'batch_fetch.py', *urls],
        capture_output=True
    )

    return jsonify(json.loads(result.stdout))
```

### Anti-Pattern 4: Using shell=True with Subprocess

**What:** Passing user input to subprocess with shell=True enabled.

**Why bad:**

- Shell injection vulnerability
- User could execute arbitrary commands
- Example: company name "; rm -rf /" would delete files

**Instead:** Always use list-form arguments with shell=False (default).

```python
# EXTREMELY DANGEROUS
company_name = request.form['company']
subprocess.run(f"python3 search_helper.py {company_name}", shell=True)

# SAFE
company_name = request.form['company']
# Validate input first
if not company_name.replace(' ', '').isalnum():
    abort(400, 'Invalid company name')

subprocess.run(
    ['python3', 'search_helper.py', company_name],
    shell=False  # Default, but explicit is better
)
```

## Technology Stack Recommendation

### Web Framework: Flask (Not FastAPI)

**Rationale:** For a PoC wrapping existing scripts, Flask's simplicity outweighs FastAPI's performance benefits.

**Flask advantages for this use case:**

- Simpler mental model (routes, templates, forms)
- Better template integration (Jinja2 built-in)
- Synchronous by default (matches subprocess pattern)
- Fewer moving parts (no async/await complexity)
- Faster to prototype

**When to reconsider:** If you need to handle 100+ concurrent uploads or expose as API for other services, FastAPI's async support becomes valuable.

**Source:** [FastAPI vs Flask comparison](https://strapi.io/blog/fastapi-vs-flask-python-framework-comparison) - Flask handles 3,000 rps, FastAPI 15,000+ rps. For PoC, 3,000 rps is more than sufficient.

### Database: SQLite (Not PostgreSQL)

**Rationale:** SQLite provides zero-setup storage for job metadata without requiring a database server.

**SQLite advantages for PoC:**

- No setup, no server, just a file
- Perfect for single-writer scenarios (one user uploads at a time)
- Fast for simple queries (job lookups by ID)
- Easy to backup (copy one .db file)
- Included in Python standard library

**Limitations to know:**

- Database-level locking (only one writer at a time)
- If you need 10+ concurrent uploads, migrate to PostgreSQL

**Migration path:** Use Repository pattern (above) to abstract database - switching from SQLite to PostgreSQL requires only changing connection string.

**Source:** [SQLite vs PostgreSQL comparison](https://dev.to/sqldocs/sqlite-vs-postgresql-choose-the-right-database-for-your-app-4hch) - "SQLite is perfect for developing prototypes or proof of concepts where you need quick database setup without infrastructure overhead."

### Background Jobs: None for PoC (Celery for Production)

**For PoC:** Use Python threading for async processing (acceptable for 1-5 concurrent jobs).

```python
import threading

def process_job_async(job_id):
    def worker():
        try:
            process_job(job_id)
        except Exception as e:
            job_repo.update_status(job_id, 'failed', error_message=str(e))

    thread = threading.Thread(target=worker)
    thread.daemon = True
    thread.start()
```

**For Production:** Migrate to Celery + Redis when you need:

- Reliable job queues
- Job retry logic
- Distributed workers
- 10+ concurrent uploads

**Source:** [Celery with Redis guide](https://blog.naveenpn.com/implementing-task-queues-in-python-using-celery-and-redis-scalable-background-jobs) - "Celery with Redis provides a battle-tested solution for reliable job processing in Python."

### File Storage: Local Filesystem (Cloud for Production)

**For PoC:** Store uploads and results in local directories.

```
/var/www/app/
├── uploads/
│   └── {job_id}.csv
├── results/
│   └── {job_id}.xlsx
└── app.db
```

**For Production:** Migrate to S3/Azure Blob Storage when deploying to cloud.

## Build Order (Recommended Phase Structure)

### Phase 1: Minimal Web Shell (Day 1-2)

**Goal:** Prove Flask can call existing scripts and display results.

**Build:**

1. Flask app with single route: /test
2. Route calls batch_fetch.py with hardcoded URL
3. Display JSON results in browser
4. No database, no file uploads yet

**Success criteria:** Can view fetched data in browser.

**Why first:** De-risks subprocess integration, validates existing scripts work in web context.

### Phase 2: Single Company Lookup (Day 3-4)

**Goal:** User can enter company name, see enriched data.

**Build:**

1. HTML form accepting company name
2. Form handler validates input
3. Calls search_helper.py to generate URLs
4. Calls batch_fetch.py to fetch data
5. Renders results in HTML table

**No database yet** - just request/response cycle.

**Success criteria:** Can look up one company and see results.

**Why second:** Establishes end-to-end user flow without complexity of file uploads.

### Phase 3: CSV Upload (Day 5-7)

**Goal:** User can upload CSV, get results.

**Build:**

1. SQLite database with jobs table
2. File upload form
3. Upload handler (save file, create job record)
4. Processing logic (read CSV, call scripts for each row)
5. Results page showing job status
6. Download link for Excel results

**Success criteria:** Can upload 10-row CSV and download enriched Excel file.

**Why third:** Adds data layer and file handling, builds on proven single-lookup flow.

### Phase 4: Polish & Error Handling (Day 8-10)

**Goal:** Handle edge cases gracefully.

**Build:**

1. Input validation (CSV structure, company name format)
2. Error pages (404, 400, 500)
3. Timeout handling for hung subprocess calls
4. Progress indicators (job status updates)
5. File size limits
6. Cleanup old jobs/files

**Success criteria:** App handles malformed inputs without crashing.

**Why last:** Polish makes sense only after core functionality works.

## Scalability Considerations

| Concern             | At 1 user (PoC)  | At 10 users          | At 100+ users                         |
| ------------------- | ---------------- | -------------------- | ------------------------------------- |
| **Web Server**      | Flask dev server | Gunicorn (4 workers) | Gunicorn + Nginx + multiple instances |
| **Database**        | SQLite           | SQLite (still OK)    | PostgreSQL with connection pooling    |
| **File Storage**    | Local disk       | Local disk           | S3/Azure Blob Storage                 |
| **Background Jobs** | Threading        | Threading (risky)    | Celery + Redis with multiple workers  |
| **Rate Limiting**   | None             | IP-based limits      | Redis-backed rate limiter             |
| **Deployment**      | Local machine    | Single VPS           | Kubernetes/Cloud Run with autoscaling |

**PoC to Production Migration Path:**

1. Replace SQLite with PostgreSQL (change connection string in Repository)
2. Add Celery for background jobs (extract processing logic to tasks)
3. Deploy with Gunicorn + Nginx
4. Move files to object storage
5. Add Redis for caching and rate limiting

## Deployment Architecture (PoC vs Production)

### PoC Deployment (Single Server)

```
┌────────────────────────────────────┐
│     VPS / Local Machine            │
│  ┌──────────────────────────────┐  │
│  │  Flask (Gunicorn)            │  │
│  │  Port 8000                   │  │
│  └──────────────────────────────┘  │
│  ┌──────────────────────────────┐  │
│  │  SQLite DB                   │  │
│  │  /var/www/app/app.db         │  │
│  └──────────────────────────────┘  │
│  ┌──────────────────────────────┐  │
│  │  File Storage                │  │
│  │  /var/www/app/uploads/       │  │
│  │  /var/www/app/results/       │  │
│  └──────────────────────────────┘  │
└────────────────────────────────────┘
```

**Command to run:**

```bash
gunicorn -w 4 -b 0.0.0.0:8000 app:app
```

### Production Deployment (Scalable)

```
                    ┌──────────────┐
                    │  Load Balancer│
                    │  (Nginx/ALB)  │
                    └───────┬──────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
    ┌───▼────┐         ┌───▼────┐         ┌───▼────┐
    │Flask   │         │Flask   │         │Flask   │
    │Instance│         │Instance│         │Instance│
    └───┬────┘         └───┬────┘         └───┬────┘
        │                  │                   │
        └──────────────────┼───────────────────┘
                           │
            ┌──────────────┼──────────────┐
            │              │              │
       ┌────▼───┐     ┌───▼────┐    ┌───▼────┐
       │Postgres│     │ Redis  │    │  S3    │
       │  DB    │     │ Queue  │    │ Files  │
       └────────┘     └───┬────┘    └────────┘
                          │
                    ┌─────▼──────┐
                    │   Celery   │
                    │   Workers  │
                    └────────────┘
```

## Integration with Existing Scripts

### Current Script Analysis

**batch_fetch.py:**

- **Input:** URLs as CLI arguments or stdin
- **Output:** JSON to stdout or file (--output flag)
- **Integration:** Call via subprocess.run(), parse JSON output
- **Modification needed:** None

**search_helper.py:**

- **Input:** Company name as CLI argument
- **Output:** JSON with search URLs
- **Integration:** Call via subprocess.run(), parse JSON output
- **Modification needed:** None

**csv_to_excel.py:**

- **Input:** CSV file path (hardcoded: 'blue-collar-companies.csv')
- **Output:** Excel file (hardcoded: 'blue-collar-companies.xlsx')
- **Integration:** Requires modification to accept file paths as arguments
- **Modification needed:** Add argparse for --input and --output paths

**Recommended modification to csv_to_excel.py:**

```python
# Add to main() function
import argparse

def main():
    parser = argparse.ArgumentParser(
        description='Convert CSV to formatted Excel file'
    )
    parser.add_argument(
        '--input',
        default='blue-collar-companies.csv',
        help='Input CSV file path'
    )
    parser.add_argument(
        '--output',
        default='blue-collar-companies.xlsx',
        help='Output Excel file path'
    )
    args = parser.parse_args()

    csv_file = args.input
    excel_file = args.output

    # ... rest of existing code ...
```

This maintains backward compatibility (same defaults) while enabling web app to specify custom paths.

## Security Considerations

### Critical Security Measures (Must-Have for PoC)

1. **File Upload Validation**
   - Check file extension (only .csv)
   - Limit file size (e.g., 16MB)
   - Validate CSV structure before processing
   - Use secure_filename() from Werkzeug

2. **Input Sanitization**
   - Validate company names (alphanumeric + spaces only)
   - Reject paths, shell metacharacters
   - Use list-form subprocess (never shell=True)

3. **Subprocess Security**
   - Never pass unsanitized user input to subprocess
   - Set timeout on all subprocess calls
   - Validate output before parsing

4. **File System Security**
   - Store uploads outside web root
   - Use UUID-based filenames (not user-provided names)
   - Set proper file permissions (owner read/write only)
   - Implement cleanup (delete old jobs after 24 hours)

5. **Error Handling**
   - Don't expose system paths in error messages
   - Log detailed errors server-side
   - Show generic messages to users

### Production-Only Security Measures (Defer for PoC)

- HTTPS/TLS (use reverse proxy in production)
- Authentication/Authorization (user accounts)
- CSRF protection (Flask-WTF)
- Rate limiting (prevent abuse)
- Input sanitization for SQL injection (use parameterized queries)
- Content Security Policy headers

## Open Questions & Research Flags

1. **Agent-based processing:** Current PROMPT.md uses Cursor Auto Mode for enrichment. How to replicate this in web context?
   - Option A: Ignore for PoC (manual enrichment only)
   - Option B: Integrate LLM API (OpenAI/Anthropic) for automated enrichment
   - **Recommendation:** Phase 5+ feature, requires separate research

2. **Real-time progress updates:** How to show CSV processing progress (e.g., "Processing row 5 of 100")?
   - Option A: WebSocket connection for live updates
   - Option B: Polling /status endpoint every 2 seconds
   - **Recommendation:** Polling for PoC, WebSocket for production

3. **Concurrent upload handling:** What happens if 2 users upload simultaneously?
   - SQLite handles reads concurrently, but only one write at a time
   - Threading model may conflict with Flask's request handling
   - **Recommendation:** Document limitation "One upload at a time" for PoC

## Sources

### Framework Comparisons

- [FastAPI vs Flask: Performance and Use Cases](https://strapi.io/blog/fastapi-vs-flask-python-framework-comparison)
- [FastAPI vs Flask comparison (Medium, 2026)](https://medium.com/@muhammadshakir4152/fastapi-vs-flask-the-deep-comparison-every-python-developer-needs-in-2026-334ccf9abfa8)
- [Flask vs FastAPI for file uploads](https://betterstack.com/community/guides/scaling-python/flask-vs-fastapi/)

### Architecture Patterns

- [Architecture Patterns with Python](https://www.oreilly.com/library/view/architecture-patterns-with/9781492052197/)
- [Web Application Architecture (2026)](https://www.clickittech.com/software-development/web-application-architecture/)
- [Modern Web App Architectures (2026)](https://tech-stack.com/blog/modern-application-development/)

### Database Selection

- [SQLite vs PostgreSQL for web apps](https://dev.to/sqldocs/sqlite-vs-postgresql-choose-the-right-database-for-your-app-4hch)
- [PostgreSQL vs SQLite comparison](https://www.selecthub.com/relational-database-solutions/postgresql-vs-sqlite/)

### Background Jobs

- [Celery with Redis for Python](https://blog.naveenpn.com/implementing-task-queues-in-python-using-celery-and-redis-scalable-background-jobs)
- [Task Queues in Python](https://www.fullstackpython.com/task-queues.html)

### Subprocess Best Practices

- [Python subprocess documentation](https://docs.python.org/3/library/subprocess.html)
- [Subprocess security guide (Real Python)](https://realpython.com/python-subprocess/)

### File Upload Patterns

- [Flask file upload handling](https://blog.miguelgrinberg.com/post/handling-file-uploads-with-flask)
- [Flask file uploads documentation](https://flask.palletsprojects.com/en/stable/patterns/fileuploads/)

### PoC vs Production Architecture

- [Building Production-Grade Web Apps (2026)](https://dev.to/art_light/building-a-production-grade-ai-web-app-in-2026-architecture-trade-offs-and-hard-won-lessons-4llg)
- [Azure Basic Web App Architecture](https://learn.microsoft.com/en-us/azure/architecture/web-apps/app-service/architectures/basic-web-app)
