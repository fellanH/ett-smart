Remaining Work: LinkedIn Contacts

The contact columns (contact_name, contact_title, contact_linkedin) are ready to be populated. LinkedIn research requires manual effort due to access restrictions. The research guide provides:

- Target roles in priority order (Global Mobility Manager > HR Manager > Office Manager)
- Search strategies for each company tier
- Time estimates (~20-25 hours total)
- Instructions for the top 17 high-priority companies to start with

Data Sources Used

- Migrationsverket: 21,822 work permit records → 238 companies with 10+ permits
- Allabolag.se: Company location, employee count, and revenue data

# Project Scope: Corporate Housing Lead Generation

**Client:** Dag Hellström – _Ett Smart Hotell_
**Goal:** Deliver a prospect list of companies with verified accommodation needs for international workers.

---

## Target Audience

**238 companies** with 10+ approved work permits (Migrationsverket 2024-25 data)

- No industry filter — includes IT, Engineering, Finance, Education, Construction, etc.
- Volume-based selection: any company bringing 10+ international workers is a potential client

---

## Deliverable

**One enriched prospect list** (CSV/spreadsheet) containing:

| Field                    | Source                |
| ------------------------ | --------------------- |
| Company name             | Migrationsverket data |
| Permit count             | Migrationsverket data |
| Location/HQ              | Allabolag.se          |
| Company size (employees) | Allabolag.se          |
| Annual revenue           | Allabolag.se          |
| Key contact name         | LinkedIn research     |
| Contact title            | LinkedIn research     |
| Contact LinkedIn URL     | LinkedIn research     |

**Contact prioritization:**

1. Global Mobility Manager / Relocation Specialist
2. HR Manager / People Operations
3. Office Manager / Executive Assistant
4. General management (for smaller firms)

---

## Out of Scope

The following are **not** part of this project:

- Target audience profiles / persona documents
- Marketing strategy recommendations
- Tiered approach or segmentation strategy
- Ad copy, email templates, or campaign materials
- Messaging recommendations

_Rationale: The marketing agency will handle strategy. This project delivers the raw prospect list only._

---

## Source Data

- **Input:** `data/Migrationsverket_companies_with_work_permits_2024_25.csv`
- **Contains:** 6,551 unique companies, 21,785 permit records
- **Filter applied:** Companies with 10+ permits → 238 companies

---

## Process

1. Extract 238 companies with 10+ permits from source data
2. Enrich with company data (location, size, revenue) via Allabolag.se
3. Research and add key contacts via LinkedIn
4. Deliver final CSV to client

---

## Timeline

_To be determined based on LinkedIn research capacity._
