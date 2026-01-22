# Weaver 3 - CSV Analysis Tool

This is a static web application designed to analyze and visualize CSV data, specifically tailored for company analysis tasks.

## Structure

- **src/**: Contains the source code for the web client.
  - `index.html`: Main entry point.
  - `styles/`: CSS files (Vanilla CSS).
  - `scripts/`: JavaScript files (Vanilla JS).
- **data/**: Contains sample data files.
- **docs/**: Documentation and tasks.

## usage

1. Open `src/index.html` in any modern web browser.
2. Drag and drop a CSV file (e.g., from the `data/` directory) into the upload zone.
3. View the dashboard to analyze the data, search records, and see summary statistics.

## Features

- **Dark Mode UI**: Modern, glassmorphism-inspired design.
- **Client-Side Processing**: No server required; all processing happens in the browser.
- **CSV Parsing**: Robust parsing using PapaParse.
- **Dynamic Stats**: Automatically detects columns like "Status" or "Omsättning" to generate insights.
- **Search & Filter**: Real-time filtering of records.

## Sample Data

You can test the application with:
- `data/anlaggningsarbetare_company_analysis.csv`
- `data/Migrationsverket_företag-med-arbetstillstånd_2024_25.csv`
