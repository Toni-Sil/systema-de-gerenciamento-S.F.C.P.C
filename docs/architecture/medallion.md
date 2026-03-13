# Medallion Architecture Strategy - S.F.C.P.C

To ensure data quality for AI/ML and operational excellence, we follow the Medallion Architecture.

## 1. Bronze Layer (Raw)
- **Content**: Raw ingestion from various sources (CSV, Excel, API logs, IoT).
- **Format**: Parquet or JSON (unstructured/semi-structured).
- **Rules**: No deletion, append-only.
- **Location**: `data/bronze/`

## 2. Silver Layer (Cleansed & Standardized)
- **Process**: 
    - Deduplication.
    - Standardizing units (e.g., all mass to KG).
    - Null handling.
    - Schema enforcement using Pydantic models.
- **Format**: Relational (PostgreSQL) and Parquet.
- **Location**: `db/` (Operational) and `data/silver/` (Analytical).

## 3. Gold Layer (Business-Ready)
- **Content**: Aggregated data for KPIs (Turnover, Accuracy, ABC Curve).
- **Process**: Join products with movements and physical counts.
- **Format**: Highly optimized tables for Dashboards and AI ingestion.
- **Location**: `data/gold/`

## Data Quality Checks
- [ ] SKU Format validation.
- [ ] Positive quantity check for stock balances.
- [ ] Validity date logical checks.
