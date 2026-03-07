# Agent Tools

## search_url_generator.py

A tool for generating Google search URLs that can be fetched using web fetch capabilities.

### Usage

**Generate all company research URLs:**

```bash
python search_url_generator.py "Company Name" --all
```

**Generate a single search URL:**

```bash
python search_url_generator.py "query text"
```

**Generate a site-specific search URL:**

```bash
python search_url_generator.py "Company Name" --site allabolag.se
```

**Output as JSON (for programmatic use):**

```bash
python search_url_generator.py "Company Name" --all --json
```

### Example Output

When using `--all`, the script generates URLs for:

1. Allabolag.se search (revenue, address, VD info)
2. Ratsit.se search (verification)
3. VD email search
4. LinkedIn search
5. HR contact search
6. Official website search
7. General contact search
8. About us page search

### Integration with Agent

The agent can call this script to generate URLs, then use `mcp_web_fetch` to fetch the search results.
