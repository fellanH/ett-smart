# Technology Stack

**Project:** Swedish Company Data Enrichment PoC
**Researched:** 2026-01-22
**Domain:** Web wrapper for existing Python data enrichment scripts

## Executive Summary

**Recommendation: Streamlit-based stack** for this PoC because it requires zero frontend code, provides built-in CSV upload/download, and can wrap existing Python scripts with minimal changes. For a proof-of-concept with known beta users and no auth requirements, Streamlit delivers 10x faster than Flask while avoiding overengineering.

## Recommended Stack

### Core Framework

| Technology | Version | Purpose          | Why                                                                                                                      |
| ---------- | ------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------ |
| Streamlit  | 1.53.0  | Web UI framework | Zero HTML/CSS/JS required. Built-in file upload, data tables, and download buttons. Perfect for wrapping Python scripts. |
| Python     | 3.11+   | Runtime          | Required by pandas 3.0+. Stable, widely supported.                                                                       |

### Data Processing (Already in use)

| Technology | Version | Purpose           | Why                                                                                         |
| ---------- | ------- | ----------------- | ------------------------------------------------------------------------------------------- |
| pandas     | 3.0.0   | Data manipulation | Already used in existing scripts. Native integration with Streamlit via `st.dataframe()`.   |
| openpyxl   | 3.1.5   | Excel export      | Already in requirements.txt. Required by pandas for .xlsx export. Production/Stable status. |

### HTTP Requests (Already in use)

| Technology | Version | Purpose      | Why                                                                    |
| ---------- | ------- | ------------ | ---------------------------------------------------------------------- |
| requests   | 2.32.5  | Web scraping | Already used in batch_fetch.py. No changes needed to existing scripts. |

### Supporting Libraries

| Library     | Version | Purpose | When to Use                                         |
| ----------- | ------- | ------- | --------------------------------------------------- |
| None needed | -       | -       | Streamlit includes all UI components needed for PoC |

## Alternatives Considered

| Category      | Recommended             | Alternative           | Why Not                                                                                                                                                                   |
| ------------- | ----------------------- | --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Web Framework | **Streamlit 1.53.0**    | Flask 3.1.2           | Flask requires HTML templates, form handling, CSS, and routing setup. 3-5x more code for same result in a PoC. Only consider Flask if you need custom REST API endpoints. |
| Web Framework | **Streamlit 1.53.0**    | FastAPI               | FastAPI is API-first. You'd still need a frontend. Overkill for a small batch PoC with known users. Use this if building a production API for external integrations.      |
| Web Framework | **Streamlit 1.53.0**    | Gradio                | Similar to Streamlit but designed for ML model demos. Less flexible for general data apps. Streamlit has better dataframe handling and table displays.                    |
| Data Display  | **st.dataframe()**      | Flask + DataTables.js | Requires JavaScript integration, DOM manipulation. Streamlit's built-in interactive tables support sorting, resizing, downloading out-of-box.                             |
| Deployment    | **Local streamlit run** | Docker + nginx        | Unnecessary complexity for PoC with known users. Run `streamlit run app.py` and share network URL. Docker is for production.                                              |

## Installation

```bash
# All dependencies
pip install streamlit>=1.53.0 pandas>=3.0.0 openpyxl>=3.1.5

# requests already in existing requirements.txt
# No additional packages needed
```

## Architecture Decision: Why Streamlit for this PoC

### Context

- **Existing codebase:** Python scripts (batch_fetch.py, search_helper.py) that work
- **Target users:** Known beta testers, internal/trusted users
- **Use case:** CSV upload + batch processing + Excel download
- **Timeline:** PoC/prototype phase, not production MVP
- **Team:** Python developers, no frontend specialists

### Decision Drivers

**1. Zero Frontend Code**

- Streamlit apps are pure Python. No HTML, CSS, or JavaScript required.
- `st.file_uploader()` handles CSV uploads
- `st.dataframe()` displays results as interactive tables
- `st.download_button()` exports to Excel/CSV
- All in ~50 lines of Python vs ~200+ lines for Flask equivalent

**2. Built-in Components Match Requirements Exactly**

- File upload widget: `st.file_uploader(type=['csv'])`
- Single company lookup: `st.text_input()` + `st.button()`
- Results display: `st.dataframe()` with sorting, column resizing, search
- Download: `st.download_button()` with automatic MIME type handling
- Progress: `st.progress()` for batch operations

**3. Trivial Integration with Existing Scripts**

```python
# Existing script
from batch_fetch import BatchFetcher
fetcher = BatchFetcher()
results = fetcher.fetch_batch(urls)

# Streamlit wrapper - just add
import streamlit as st
st.dataframe(results)  # That's it.
```

**4. PoC-Appropriate Deployment**

```bash
streamlit run app.py --server.port 8501
# Share network URL: http://192.168.1.x:8501
# No nginx, no Docker, no DNS needed
```

**5. Active Development & Current**

- Version 1.53.0 released Jan 14, 2026 (8 days ago)
- FastAPI adoption grew 40% in 2025, but Streamlit remains king for data apps
- 38k+ GitHub stars, heavily used in data science community

### When NOT to Use Streamlit

Avoid Streamlit if you need:

- **Custom REST API:** Use FastAPI instead
- **Multi-page complex workflows:** Flask gives more control
- **Production auth:** Streamlit has no built-in auth (you'd need Streamlit Cloud or custom solutions)
- **Mobile-first UI:** Streamlit is desktop-optimized
- **Real-time collaboration:** Streamlit reruns entire app on each interaction

For this PoC: None of these apply. Beta users on desktop, small batches, no auth required.

## Stack Confidence Assessment

| Component    | Confidence | Rationale                                                                                                                                                |
| ------------ | ---------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Streamlit    | **HIGH**   | Official docs verified. Current version (1.53.0, Jan 2026) confirmed via PyPI. File upload and download capabilities verified in official documentation. |
| pandas       | **HIGH**   | Version 3.0.0 released Jan 21, 2026 (verified). Already in use in existing scripts. Streamlit has native pandas integration.                             |
| openpyxl     | **HIGH**   | Already in requirements.txt. Current stable 3.1.5 (verified via PyPI). Pandas-recommended for Excel export.                                              |
| Python 3.11+ | **HIGH**   | Required by pandas 3.0.0 and Streamlit 1.53.0. Well-supported runtime.                                                                                   |

## Implementation Estimate

With Streamlit, the PoC can be built in **1-2 days**:

**Day 1: Core functionality (4-6 hours)**

- File upload handler
- CSV parsing with pandas
- Call existing batch_fetch.py functions
- Display results in st.dataframe()
- Basic error handling

**Day 2: Polish (2-4 hours)**

- Single lookup form
- Progress bars for batch processing
- Excel download with formatting
- Input validation
- Documentation

**Flask alternative:** 3-5 days for equivalent functionality (templates, forms, JavaScript for tables, error pages, styling).

## Pitfalls to Avoid

### Critical Pitfalls

**1. Version Compatibility Cascade**

- pandas 3.0.0 requires Python >=3.11
- Streamlit 1.53.0 requires Python >=3.10
- **Action:** Pin Python 3.11+ in deployment. Document in README.

**2. Streamlit Full App Reruns**

- Streamlit reruns entire script on every interaction
- Batch processing could re-trigger on button clicks
- **Action:** Use `st.session_state` to cache results and prevent re-fetching

**3. File Upload Size Limits**

- Default: 200 MB per file
- CSV with 10-20 companies is tiny, but could hit limit with large historical datasets
- **Action:** Configure `server.maxUploadSize` in `.streamlit/config.toml` if needed

**4. Network URL Access**

- Streamlit binds to localhost by default
- Beta users on LAN won't be able to access
- **Action:** Run with `streamlit run app.py --server.address=0.0.0.0` to allow network access

### Moderate Pitfalls

**5. No Built-in Authentication**

- Streamlit has no auth by default
- Acceptable for PoC with known users, but risky if exposed to internet
- **Action:** Document "LAN only" deployment. Add password check in app if needed.

**6. Existing Scripts Assume CLI**

- batch_fetch.py outputs to stdout/files
- Need to adapt for programmatic use
- **Action:** Import classes directly, don't shell out to scripts

## Migration Path to Production

When PoC graduates to production MVP:

**Option 1: Keep Streamlit + Add Auth**

- Deploy to Streamlit Community Cloud (free auth)
- Or use streamlit-authenticator package
- Add database for job history
- Good for internal tools

**Option 2: Migrate to FastAPI + React**

- Build proper REST API with FastAPI
- React frontend for richer UX
- More work, but production-grade
- Good for external customers

**Option 3: Hybrid**

- Keep Streamlit for admin/internal interface
- Add FastAPI endpoints for programmatic access
- Streamlit 1.53.0 has experimental st.App for custom routes
- Best of both worlds

## Sources

**Framework Comparisons:**

- [Streamlit vs Flask for Deploying AI Models](https://aicompetence.org/streamlit-vs-flask-whats-best-for-deploying/)
- [Top Python Web Frameworks 2026 - Reflex Blog](https://reflex.dev/blog/2026-01-09-top-python-web-frameworks-2026/)
- [FastAPI vs Flask 2025 Performance Comparison](https://strapi.io/blog/fastapi-vs-flask-python-framework-comparison)

**Streamlit Capabilities:**

- [Streamlit File Uploader Documentation](https://docs.streamlit.io/develop/api-reference/widgets/st.file_uploader)
- [Streamlit Download Button Documentation](https://docs.streamlit.io/knowledge-base/using-streamlit/how-download-file-streamlit)
- [Streamlit DataFrame Display Documentation](https://docs.streamlit.io/develop/api-reference/data/st.dataframe)

**Version Information:**

- [Streamlit 1.53.0 Release - PyPI](https://pypi.org/project/streamlit/)
- [pandas 3.0.0 Release Notes](https://pandas.pydata.org/docs/dev/whatsnew/v3.0.0.html)
- [openpyxl 3.1.5 - PyPI](https://pypi.org/project/openpyxl/)
- [Flask 3.1.2 Changes](https://flask.palletsprojects.com/en/stable/changes/)

**Deployment:**

- [Deploy Streamlit on Local Network](https://discuss.streamlit.io/t/how-to-deploy-an-application-on-a-local-area-network/86182)
- [Run Your Streamlit App - Official Docs](https://docs.streamlit.io/develop/concepts/architecture/run-your-app)
