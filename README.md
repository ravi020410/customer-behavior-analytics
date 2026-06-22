# Customer Behavior and Cohort Retention Dashboard

    ![Power BI](https://img.shields.io/badge/Power_BI-dashboard_spec-F2C811)
    ![Python](https://img.shields.io/badge/Python-RFM_and_cohorts-blue)
    ![SQL](https://img.shields.io/badge/SQL-retention_analysis-blue)
    ![Status](https://img.shields.io/badge/status-portfolio_ready-386411)

    ## About This Project

    This project analyzes customer behavior with RFM segmentation and cohort retention. It is designed to show how a data analyst can move from transaction logs to segment definitions, churn-risk signals, and retention reporting.

    ## Business Problem

    A customer-driven business needs to know which customers are highly valuable, which customers are slipping, and when retention drops after first purchase. The goal is to support targeted lifecycle marketing and loyalty decisions.

    ## Dashboard Preview

    ![RFM Customer Segmentation](images/01_rfm_customer_segmentation.svg)

    ![Cohort Retention Heatmap](images/02_cohort_retention_heatmap.svg)

    ## Data Assets

    | File | Purpose |
    |---|---|
    | `data/raw_customer_orders.csv` | Synthetic raw order data with missing customer IDs and return rows. |
    | `data/cleaned_customer_orders.csv` | Cleaned order-level analytical table. |
    | `data/customer_rfm_segments.csv` | Customer-level RFM scores and segment labels. |
    | `data/customer_cohort_retention_matrix.csv` | Cohort retention matrix by first purchase month. |
    | `docs/data_dictionary.md` | Field definitions for project datasets. |
    | `docs/data_quality_report.md` | Data validation and cleaning summary. |

    ## Key Metrics From Current Data

    | KPI | Value |
    |---|---:|
    | Raw orders | 5,000 |
| Cleaned orders | 4,635 |
| Customers segmented | 989 |
| Total cleaned revenue | $1,099,331 |
| Champions segment customers | 217 |
| Nulls in cleaned orders | 0 |

    ## Technical Workflow

    1. Generate synthetic customer order data in `rfm_and_cohort_analysis.py`.
    2. Remove missing customer identifiers and return/cancellation rows.
    3. Calculate `TotalAmount`, order month, and each customer's first purchase month.
    4. Build RFM scores using quintiles.
    5. Generate segment labels such as Champions, Loyal Customers, At Risk, and Hibernating.
    6. Create a cohort retention matrix for retention diagnostics.

    ## How To Run

    ```bash
    python -m pip install -r requirements.txt
    python rfm_and_cohort_analysis.py
    ```

    ## Repository Structure

    ```text
    data/        Raw, cleaned, RFM, and cohort CSV files
    docs/        Data dictionary and data quality report
    images/      Dashboard preview charts generated from the data
    powerbi/     Dashboard specification, DAX measures, and theme JSON
    sql/         Analytical SQL queries
    ```

    ## Interview Talking Points

    - Shows customer segmentation with RFM scoring.
    - Shows cohort retention logic based on each customer's true first purchase month.
    - Shows lifecycle marketing and churn-risk thinking.
    - Strong supporting project next to the larger SaaS and retail showcase repositories.
## Project Overview

Customer Behavior Analytics project built as a recruiter-ready analytics case study with reproducible data, SQL, Python, dashboards, reports, and business recommendations.

## Dataset Information

Data is organized into `data/raw` and `data/processed` so reviewers can distinguish source-like inputs from analysis-ready outputs.

## Tech Stack

Python, pandas, SQL, Excel/BI planning, dashboard documentation, Git, and GitHub.

## Architecture Diagram

See `docs/` and dashboard documentation for the data flow, modeling approach, and reporting layers.

## Project Workflow

1. Generate or collect source-like data.
2. Validate and clean the dataset.
3. Build processed analytical tables.
4. Analyze KPIs with SQL and Python.
5. Create dashboard and reporting assets.
6. Convert insights into recommendations.

## KPIs

- Customers Segmented
- Total Revenue
- Champions
- Month 1 Retention
- Churn Risk

## Methodology

The analysis uses data quality checks, KPI aggregation, segment analysis, trend analysis, and business recommendation framing.

## Visualizations

Dashboard previews and chart assets are stored in `images/`.

## Dashboard Screenshots

Dashboard documentation and walkthrough files are stored in `dashboards/`.

## Key Insights

- The project identifies performance patterns across the most important business dimensions.
- Processed datasets make the analysis reproducible.
- The dashboard flow supports executive review and analyst drill-down.

## Business Recommendations

- Review the weakest segment first for short-term improvement.
- Use the strongest segment as a performance benchmark.
- Track the core KPI set weekly.

## Folder Structure

```text
data/raw
data/processed
notebooks
sql
dashboards
reports
images
src
docs
```

## Results

The repository now meets a standardized recruiter-ready analytics portfolio structure.

## Future Enhancements

- Add live BI platform files when Power BI Desktop or Tableau is available.
- Add automated CI checks for data quality.
- Add forecasting models where historical signal supports it.

## Author

Ravikant Yadav - Data Analyst Portfolio
