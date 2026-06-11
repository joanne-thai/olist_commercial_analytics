# Archive

This folder contains alternative implementations preserved for reference but
not part of the active analytical pipeline.

## Contents

- `01_setup_and_eda.ipynb` — Pandas-only implementation of the Phase 1 data
  build (loading raw CSVs, constructing the fact table). Equivalent in output
  to the MySQL-based pipeline in the project root (`01_setup_and_eda.ipynb`
  + `sql/01_fact_table.sql`), but kept as a reference for the alternative
  technical approach.