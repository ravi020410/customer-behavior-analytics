# Data Quality Report

    | Check | Result |
    |---|---:|
    | Raw orders | 5,000 |
| Cleaned orders | 4,635 |
| Customers segmented | 989 |
| Total cleaned revenue | $1,099,331 |
| Champions segment customers | 217 |
| Nulls in cleaned orders | 0 |

    ## Cleaning Rules

    - Removed orders with missing `CustomerID` values.
    - Removed return/cancellation rows where quantity was less than or equal to zero.
    - Added `TotalAmount`, `OrderMonth`, and customer-level cohort fields.
    - Calculated RFM quintile scores and business-readable segments.
    - Generated a cohort retention matrix by each customer's true first purchase month.

    Blank cells in the retention matrix represent future or unavailable cohort months, not data corruption.
