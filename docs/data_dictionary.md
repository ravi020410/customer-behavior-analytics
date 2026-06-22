# Data Dictionary

| Field | Description |
|---|---|
| OrderID | Unique order identifier. |
| CustomerID | Customer identifier. Null raw records are excluded from cleaned analysis. |
| OrderDate | Timestamp for the purchase event. |
| Quantity | Number of items purchased. Return rows have negative quantities in raw data. |
| ItemPrice | Price per item. |
| TotalAmount | Quantity multiplied by item price after cleaning. |
| OrderMonth | Calendar month of the order. |
| CohortMonth | Customer's first purchase month. |
| Recency | Days since customer's most recent order at snapshot date. |
| Frequency | Distinct orders by customer. |
| Monetary | Total customer spend. |
| Customer_Segment | Business label derived from RFM scores. |
