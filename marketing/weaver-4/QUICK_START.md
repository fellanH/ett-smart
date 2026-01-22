# Quick Start Guide

## Workflow Overview

1. **Generate search URLs** → 2. **Fetch URLs** → 3. **Extract data** → 4. **Update CSV & Progress**

## Step-by-Step

### 1. Start Processing Next Company
```bash
python process_company.py
```

This outputs:
- Company name and row index
- 8 search URLs ready to fetch
- Next steps instructions

### 2. Fetch Each URL
Use `mcp_web_fetch` to fetch each URL:
```python
# Example: Fetch first URL
mcp_web_fetch(url="https://www.google.com/search?q=...")
```

### 3. Parse HTML Content
Extract data from the fetched HTML:
- Revenue (Årlig omsättning)
- Address (Gatuadress, Postnummer, Ort)
- CEO info (VD, VD E-post, VD Telefon)
- Owner (Ägare)
- HR info (HR-ansvarig, HR E-post)
- Other roles (Projektledare, Administratör, etc.)

### 4. Update CSV and Progress
```bash
python process_company.py --update --row 131 --data '{
  "VD": "John Doe",
  "VD E-post": "john@company.se",
  "VD Telefon": "070-123 45 67",
  "Årlig omsättning": "5000000",
  "Gatuadress": "Main Street 1",
  "Postnummer": "123 45",
  "Ort": "Stockholm"
}'
```

## Example JSON Data Format
```json
{
  "VD": "Full Name",
  "VD E-post": "email@example.com",
  "VD Telefon": "070-123 45 67",
  "Årlig omsättning": "1000000",
  "Gatuadress": "Street Address",
  "Postnummer": "123 45",
  "Ort": "City",
  "Ägare": "Owner Name",
  "HR-ansvarig": "HR Manager Name",
  "HR E-post": "hr@example.com"
}
```

## Manual Alternative

If you prefer to update files manually:
1. Edit `blue-collar-companies.csv` - update the row
2. Edit `PROMPT.md` - update `[PROGRESS_LOG]` section

## Troubleshooting

**URLs not generating?**
- Check that `search_url_generator.py` is executable: `chmod +x search_url_generator.py`
- Verify Python 3 is installed: `python --version`

**CSV update failing?**
- Ensure row index matches current `Next_Row_Index` in PROMPT.md
- Check JSON syntax is valid
- Verify column names match CSV headers exactly
