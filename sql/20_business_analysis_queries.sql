-- =========================================================================================
-- Customer Behavior & Cohort Retention - 20+ Advanced SQL Business Queries
-- Author: Ravikant Yadav
-- Database Platform: SQL Server (T-SQL) / PostgreSQL Compatible
-- Description: This script contains 22 production-grade, highly optimized SQL queries
--              designed to answer critical executive business questions regarding customer
--              behavior, RFM segment economics, and cohort retention lifecycle value.
-- =========================================================================================

-- -----------------------------------------------------------------------------------------
-- QUERY 1: Executive KPI Scorecard
-- Purpose: Calculates high-level North Star metrics: total revenue, transaction counts,
--          unique active customer counts, and average order value (AOV).
-- -----------------------------------------------------------------------------------------
SELECT
    COUNT(DISTINCT CustomerID) AS Total_Unique_Customers,
    COUNT(OrderID) AS Total_Orders,
    SUM(Quantity * ItemPrice) AS Total_Gross_Revenue,
    ROUND(SUM(Quantity * ItemPrice) / COUNT(OrderID), 2) AS Average_Order_Value,
    SUM(Quantity) AS Total_Units_Sold
FROM Fact_Orders
WHERE Quantity > 0;


-- -----------------------------------------------------------------------------------------
-- QUERY 2: Monthly Active Customers (MAC) & Revenue Growth Trends
-- Purpose: Identifies Month-over-Month (MoM) revenue growth rates and transaction volume
--          trends to capture retail seasonality and consumer demand shifts.
-- -----------------------------------------------------------------------------------------
WITH MonthlyAggregates AS (
    SELECT
        DATETRUNC(month, OrderDate) AS Order_Month,
        COUNT(DISTINCT CustomerID) AS Monthly_Active_Customers,
        COUNT(OrderID) AS Transaction_Count,
        SUM(Quantity * ItemPrice) AS Monthly_Revenue
    FROM Fact_Orders
    WHERE Quantity > 0
    GROUP BY DATETRUNC(month, OrderDate)
)
SELECT
    Order_Month,
    Monthly_Active_Customers,
    Transaction_Count,
    ROUND(Monthly_Revenue, 2) AS Monthly_Revenue,
    ROUND(Monthly_Revenue - LAG(Monthly_Revenue, 1) OVER (ORDER BY Order_Month), 2) AS MoM_Revenue_Variance,
    ROUND(((Monthly_Revenue - LAG(Monthly_Revenue, 1) OVER (ORDER BY Order_Month)) /
           LAG(Monthly_Revenue, 1) OVER (ORDER BY Order_Month)) * 100, 2) AS MoM_Growth_Rate_Percent
FROM MonthlyAggregates
ORDER BY Order_Month;


-- -----------------------------------------------------------------------------------------
-- QUERY 3: Customer Acquisition Cohort Identification
-- Purpose: Groups customers based on their acquisition (first purchase) month and tracks
--          the size of each monthly signup cohort.
-- -----------------------------------------------------------------------------------------
SELECT
    CohortMonth,
    COUNT(DISTINCT CustomerID) AS Acquisition_Cohort_Size,
    ROUND(SUM(FirstMonthRevenue), 2) AS Initial_Cohort_Value
FROM (
    SELECT
        CustomerID,
        DATETRUNC(month, MIN(OrderDate)) AS CohortMonth,
        SUM(Quantity * ItemPrice) AS FirstMonthRevenue
    FROM Fact_Orders
    WHERE Quantity > 0
    GROUP BY CustomerID
) AS CustomerCohorts
GROUP BY CohortMonth
ORDER BY CohortMonth;


-- -----------------------------------------------------------------------------------------
-- QUERY 4: 12-Month Cohort Retention Grid (The Retention Cliff)
-- Purpose: Computes rolling monthly customer retention percentages. Identifies exactly
--          where customer retention drops (the 'retention cliff') after initial signup.
-- -----------------------------------------------------------------------------------------
WITH CohortAcquisition AS (
    SELECT
        CustomerID,
        DATETRUNC(month, MIN(OrderDate)) AS Cohort_Month
    FROM Fact_Orders
    WHERE Quantity > 0
    GROUP BY CustomerID
),
CohortLapses AS (
    SELECT
        o.CustomerID,
        ca.Cohort_Month,
        DATETRUNC(month, o.OrderDate) AS Activity_Month,
        DATEDIFF(month, ca.Cohort_Month, DATETRUNC(month, o.OrderDate)) AS Cohort_Index
    FROM Fact_Orders o
    JOIN CohortAcquisition ca ON o.CustomerID = ca.CustomerID
    WHERE o.Quantity > 0
),
CohortCounts AS (
    SELECT
        Cohort_Month,
        Cohort_Index,
        COUNT(DISTINCT CustomerID) AS Active_Customers
    FROM CohortLapses
    WHERE Cohort_Index BETWEEN 0 AND 12
    GROUP BY Cohort_Month, Cohort_Index
),
CohortSizes AS (
    SELECT
        Cohort_Month,
        Active_Customers AS Cohort_Size
    FROM CohortCounts
    WHERE Cohort_Index = 0
)
SELECT
    cc.Cohort_Month,
    cs.Cohort_Size,
    cc.Cohort_Index,
    cc.Active_Customers AS Retained_Customers,
    ROUND((cc.Active_Customers * 100.0) / cs.Cohort_Size, 2) AS Retention_Percent
FROM CohortCounts cc
JOIN CohortSizes cs ON cc.Cohort_Month = cs.Cohort_Month
ORDER BY cc.Cohort_Month, cc.Cohort_Index;


-- -----------------------------------------------------------------------------------------
-- QUERY 5: Recency, Frequency, and Monetary (RFM) Scores
-- Purpose: Evaluates customer value across Recency (days since last purchase),
--          Frequency (total lifetime orders), and Monetary (total spent).
-- -----------------------------------------------------------------------------------------
SELECT
    CustomerID,
    DATEDIFF(day, MAX(OrderDate), '2026-01-01') AS Recency_Days,
    COUNT(DISTINCT OrderID) AS Frequency_Orders,
    ROUND(SUM(Quantity * ItemPrice), 2) AS Monetary_Value
FROM Fact_Orders
WHERE Quantity > 0
GROUP BY CustomerID
ORDER BY Monetary_Value DESC;


-- -----------------------------------------------------------------------------------------
-- QUERY 6: Customer Segmentation using SQL-Based Quintiles (NTILE)
-- Purpose: Divides customers into segments using the NTILE window function, ranking
--          recency, frequency, and monetary parameters from 1 (lowest) to 5 (highest).
-- -----------------------------------------------------------------------------------------
WITH RFMRaw AS (
    SELECT
        CustomerID,
        DATEDIFF(day, MAX(OrderDate), '2026-01-01') AS Recency,
        COUNT(DISTINCT OrderID) AS Frequency,
        SUM(Quantity * ItemPrice) AS Monetary
    FROM Fact_Orders
    WHERE Quantity > 0
    GROUP BY CustomerID
),
RFMTile AS (
    SELECT
        CustomerID,
        Recency,
        Frequency,
        Monetary,
        -- Lower recency days are better, so we rank ascending for Recency Tiles
        NTILE(5) OVER (ORDER BY Recency ASC) AS R_Tile,
        NTILE(5) OVER (ORDER BY Frequency DESC) AS F_Tile,
        NTILE(5) OVER (ORDER BY Monetary DESC) AS M_Tile
    FROM RFMRaw
)
SELECT
    CustomerID,
    Recency,
    Frequency,
    ROUND(Monetary, 2) AS Monetary,
    R_Tile,
    -- Flipping frequency and monetary so 5 represents the highest/best score
    (6 - F_Tile) AS F_Score,
    (6 - M_Tile) AS M_Score,
    CONCAT(R_Tile, (6 - F_Tile), (6 - M_Tile)) AS RFM_Class
FROM RFMTile
ORDER BY Monetary DESC;


-- -----------------------------------------------------------------------------------------
-- QUERY 7: Revenue Contribution by RFM Customer Segment
-- Purpose: Connects customer behavioral groups to actual revenue impact. Shows which
--          groups (e.g. Champions, Slipping) drive the majority of sales.
-- -----------------------------------------------------------------------------------------
WITH RFMScores AS (
    SELECT
        CustomerID,
        DATEDIFF(day, MAX(OrderDate), '2026-01-01') AS Recency,
        COUNT(DISTINCT OrderID) AS Frequency,
        SUM(Quantity * ItemPrice) AS Monetary
    FROM Fact_Orders
    WHERE Quantity > 0
    GROUP BY CustomerID
),
RFMTiled AS (
    SELECT
        CustomerID,
        Monetary,
        NTILE(5) OVER (ORDER BY Recency ASC) AS R,
        6 - NTILE(5) OVER (ORDER BY Frequency DESC) AS F
    FROM RFMScores
),
RFMSegmented AS (
    SELECT
        CustomerID,
        Monetary,
        CASE
            WHEN R >= 4 AND F >= 4 THEN 'Champions'
            WHEN R >= 3 AND F >= 3 THEN 'Loyal Customers'
            WHEN R >= 4 AND F <= 2 THEN 'Recent/New Customers'
            WHEN R <= 2 AND F >= 3 THEN 'At Risk / Slipping'
            ELSE 'Hibernating / Lost'
        END AS Customer_Segment
    FROM RFMTiled
)
SELECT
    Customer_Segment,
    COUNT(CustomerID) AS Customer_Count,
    ROUND(SUM(Monetary), 2) AS Segment_Revenue,
    ROUND((SUM(Monetary) * 100.0) / (SELECT SUM(Quantity * ItemPrice) FROM Fact_Orders WHERE Quantity > 0), 2) AS Revenue_Contribution_Percent,
    ROUND(AVG(Monetary), 2) AS Average_Spend_Per_Customer
FROM RFMSegmented
GROUP BY Customer_Segment
ORDER BY Segment_Revenue DESC;


-- -----------------------------------------------------------------------------------------
-- QUERY 8: "Champions" Cohort Drill Down
-- Purpose: Identifies and extracts details on VIP customer profiles (Champions).
--          These are highly active, high-spending, and recently purchased customers.
-- -----------------------------------------------------------------------------------------
WITH RFMScores AS (
    SELECT
        CustomerID,
        DATEDIFF(day, MAX(OrderDate), '2026-01-01') AS Recency,
        COUNT(DISTINCT OrderID) AS Frequency,
        SUM(Quantity * ItemPrice) AS Monetary
    FROM Fact_Orders
    WHERE Quantity > 0
    GROUP BY CustomerID
),
RFMTiled AS (
    SELECT
        CustomerID,
        Recency,
        Frequency,
        Monetary,
        NTILE(5) OVER (ORDER BY Recency ASC) AS R,
        6 - NTILE(5) OVER (ORDER BY Frequency DESC) AS F
    FROM RFMScores
)
SELECT
    CustomerID,
    Recency AS Days_Since_Last_Order,
    Frequency AS Lifetime_Orders,
    ROUND(Monetary, 2) AS Total_Lifetime_Spend,
    ROUND(Monetary / Frequency, 2) AS Average_Basket_Value
FROM RFMTiled
WHERE R >= 4 AND F >= 4
ORDER BY Total_Lifetime_Spend DESC;


-- -----------------------------------------------------------------------------------------
-- QUERY 9: At-Risk / Slipping Customers (High Value, No Recent Activity)
-- Purpose: Identifies historical high-spending customers who have not ordered recently,
--          marking them as targets for retention email campaigns.
-- -----------------------------------------------------------------------------------------
WITH RFMScores AS (
    SELECT
        CustomerID,
        DATEDIFF(day, MAX(OrderDate), '2026-01-01') AS Recency,
        COUNT(DISTINCT OrderID) AS Frequency,
        SUM(Quantity * ItemPrice) AS Monetary
    FROM Fact_Orders
    WHERE Quantity > 0
    GROUP BY CustomerID
),
RFMTiled AS (
    SELECT
        CustomerID,
        Recency,
        Frequency,
        Monetary,
        NTILE(5) OVER (ORDER BY Recency ASC) AS R,
        6 - NTILE(5) OVER (ORDER BY Frequency DESC) AS F
    FROM RFMScores
)
SELECT
    CustomerID,
    Recency AS Idle_Days,
    Frequency AS Historic_Orders,
    ROUND(Monetary, 2) AS Historic_Value
FROM RFMTiled
WHERE R <= 2 AND F >= 3
ORDER BY Monetary DESC, Recency ASC;


-- -----------------------------------------------------------------------------------------
-- QUERY 10: Customer Lifecycle Value (CLV) & Average Tenure
-- Purpose: Estimates Customer Lifetime Value and average lifespan (days between first and
--          most recent transactions) to inform customer acquisition cost (CAC) caps.
-- -----------------------------------------------------------------------------------------
WITH CustomerLifespans AS (
    SELECT
        CustomerID,
        MIN(OrderDate) AS First_Purchase,
        MAX(OrderDate) AS Last_Purchase,
        DATEDIFF(day, MIN(OrderDate), MAX(OrderDate)) AS Lifespan_Days,
        COUNT(DISTINCT OrderID) AS Total_Orders,
        SUM(Quantity * ItemPrice) AS Total_Monetary
    FROM Fact_Orders
    WHERE Quantity > 0
    GROUP BY CustomerID
)
SELECT
    COUNT(CustomerID) AS Total_Segmented_Customers,
    ROUND(AVG(Lifespan_Days), 1) AS Average_Lifespan_Days,
    ROUND(AVG(Total_Orders), 1) AS Average_Orders_Per_Customer,
    ROUND(AVG(Total_Monetary), 2) AS Average_Customer_Lifetime_Value,
    ROUND(SUM(Total_Monetary) / SUM(Total_Orders), 2) AS Combined_AOV
FROM CustomerLifespans;


-- -----------------------------------------------------------------------------------------
-- QUERY 11: Customer Churn Probability and Segment Warnings
-- Purpose: Calculates potential churn risk using standard recency parameters (customers
--          inactive for over 180 days relative to overall average inactivity).
-- -----------------------------------------------------------------------------------------
WITH CustomerRecency AS (
    SELECT
        CustomerID,
        DATEDIFF(day, MAX(OrderDate), '2026-01-01') AS Days_Since_Last_Order,
        COUNT(DISTINCT OrderID) AS Total_Orders,
        SUM(Quantity * ItemPrice) AS Total_Spend
    FROM Fact_Orders
    WHERE Quantity > 0
    GROUP BY CustomerID
)
SELECT
    CustomerID,
    Days_Since_Last_Order AS Inactive_Days,
    Total_Orders,
    ROUND(Total_Spend, 2) AS Total_Spend,
    CASE
        WHEN Days_Since_Last_Order > 270 THEN 'Severely Churned'
        WHEN Days_Since_Last_Order BETWEEN 180 AND 270 THEN 'High Churn Risk'
        WHEN Days_Since_Last_Order BETWEEN 90 AND 179 THEN 'Mild Inactivity'
        ELSE 'Active'
    END AS Retention_Risk_Level
FROM CustomerRecency
ORDER BY Days_Since_Last_Order DESC;


-- -----------------------------------------------------------------------------------------
-- QUERY 12: Year-over-Year Cohort Comparison
-- Purpose: Evaluates customer behaviors across consecutive yearly cohorts, checking if
--          customers acquired in 2025 are more valuable than those acquired in 2024.
-- -----------------------------------------------------------------------------------------
WITH AcquisitionYears AS (
    SELECT
        CustomerID,
        YEAR(MIN(OrderDate)) AS Acquisition_Year,
        SUM(Quantity * ItemPrice) AS Initial_Year_Spend
    FROM Fact_Orders
    WHERE Quantity > 0
    GROUP BY CustomerID
)
SELECT
    Acquisition_Year,
    COUNT(CustomerID) AS New_Customers_Acquired,
    ROUND(SUM(Initial_Year_Spend), 2) AS Total_First_Year_Revenue,
    ROUND(AVG(Initial_Year_Spend), 2) AS Average_First_Year_Value
FROM AcquisitionYears
GROUP BY Acquisition_Year
ORDER BY Acquisition_Year;


-- -----------------------------------------------------------------------------------------
-- QUERY 13: Customer Re-Engagement Velocity (Frequency Analysis)
-- Purpose: Analyzes the distribution of days between consecutive customer orders to
--          understand purchasing cycles and marketing touchpoint pacing.
-- -----------------------------------------------------------------------------------------
WITH NextOrderDetails AS (
    SELECT
        CustomerID,
        OrderDate,
        LAG(OrderDate, 1) OVER (PARTITION BY CustomerID ORDER BY OrderDate) AS Prior_Order_Date
    FROM Fact_Orders
    WHERE Quantity > 0
)
SELECT
    CustomerID,
    ROUND(AVG(DATEDIFF(day, Prior_Order_Date, OrderDate)), 1) AS Average_Days_Between_Orders,
    COUNT(OrderDate) AS Total_Transactions_Analyzed
FROM NextOrderDetails
WHERE Prior_Order_Date IS NOT NULL
GROUP BY CustomerID
ORDER BY Average_Days_Between_Orders ASC;


-- -----------------------------------------------------------------------------------------
-- QUERY 14: Return / Cancellation Rates by RFM Segment
-- Purpose: Identifies customer segments with unusually high return rates to check if VIPs
--          or high-spending cohorts have operational margin loss from returns.
-- -----------------------------------------------------------------------------------------
WITH CustomerRFM AS (
    SELECT
        CustomerID,
        DATEDIFF(day, MAX(CASE WHEN Quantity > 0 THEN OrderDate END), '2026-01-01') AS Recency,
        COUNT(DISTINCT CASE WHEN Quantity > 0 THEN OrderID END) AS Frequency
    FROM Fact_Orders
    GROUP BY CustomerID
),
TiledRFM AS (
    SELECT
        CustomerID,
        NTILE(5) OVER (ORDER BY Recency ASC) AS R,
        6 - NTILE(5) OVER (ORDER BY Frequency DESC) AS F
    FROM CustomerRFM
),
Segmented AS (
    SELECT
        CustomerID,
        CASE
            WHEN R >= 4 AND F >= 4 THEN 'Champions'
            WHEN R >= 3 AND F >= 3 THEN 'Loyal Customers'
            WHEN R >= 4 AND F <= 2 THEN 'Recent/New Customers'
            WHEN R <= 2 AND F >= 3 THEN 'At Risk / Slipping'
            ELSE 'Hibernating / Lost'
        END AS Customer_Segment
    FROM TiledRFM
),
OrderCalculations AS (
    SELECT
        CustomerID,
        COUNT(CASE WHEN Quantity > 0 THEN OrderID END) AS Valid_Orders_Count,
        COUNT(CASE WHEN Quantity < 0 THEN OrderID END) AS Returned_Orders_Count,
        ABS(SUM(CASE WHEN Quantity < 0 THEN Quantity * ItemPrice ELSE 0 END)) AS Refund_Amount,
        SUM(CASE WHEN Quantity > 0 THEN Quantity * ItemPrice ELSE 0 END) AS Purchase_Amount
    FROM Fact_Orders
    GROUP BY CustomerID
)
SELECT
    s.Customer_Segment,
    SUM(oc.Valid_Orders_Count) AS Total_Valid_Orders,
    SUM(oc.Returned_Orders_Count) AS Total_Returned_Orders,
    ROUND(SUM(oc.Refund_Amount), 2) AS Total_Refunded_Cash,
    ROUND((SUM(oc.Returned_Orders_Count) * 100.0) / NULLIF(SUM(oc.Valid_Orders_Count), 0), 2) AS Segment_Return_Rate_Percent,
    ROUND((SUM(oc.Refund_Amount) * 100.0) / NULLIF(SUM(oc.Purchase_Amount), 0), 2) AS Revenue_Refund_Rate_Percent
FROM Segmented s
JOIN OrderCalculations oc ON s.CustomerID = oc.CustomerID
GROUP BY s.Customer_Segment
ORDER BY Revenue_Refund_Rate_Percent DESC;


-- -----------------------------------------------------------------------------------------
-- QUERY 15: Outlier Spend Analysis (Statistical Z-Score Filter)
-- Purpose: Flags transactions with extreme financial profiles (Z-Score > 3.0 relative to
--          mean order value) that could distort average segment metrics.
-- -----------------------------------------------------------------------------------------
WITH SalesMetrics AS (
    SELECT
        AVG(Quantity * ItemPrice) AS Average_Order_Spend,
        STDEV(Quantity * ItemPrice) AS Standard_Deviation_Spend
    FROM Fact_Orders
    WHERE Quantity > 0
)
SELECT
    o.OrderID,
    o.CustomerID,
    o.OrderDate,
    ROUND(o.Quantity * o.ItemPrice, 2) AS Order_Spend,
    ROUND(sm.Average_Order_Spend, 2) AS Global_Mean_Spend,
    ROUND((o.Quantity * o.ItemPrice - sm.Average_Order_Spend) / sm.Standard_Deviation_Spend, 2) AS Spend_Z_Score
FROM Fact_Orders o
CROSS JOIN SalesMetrics sm
WHERE o.Quantity > 0
  AND (o.Quantity * o.ItemPrice - sm.Average_Order_Spend) / sm.Standard_Deviation_Spend > 3.0
ORDER BY Order_Spend DESC;


-- -----------------------------------------------------------------------------------------
-- QUERY 16: Customer Purchase Concentration (Pareto Principle / 80-20 Rule)
-- Purpose: Evaluates if 80% of company revenue is generated by the top 20% of customer
--          profiles, checking business concentration risk.
-- -----------------------------------------------------------------------------------------
WITH CustomerRevenues AS (
    SELECT
        CustomerID,
        SUM(Quantity * ItemPrice) AS Lifetime_Value,
        ROW_NUMBER() OVER (ORDER BY SUM(Quantity * ItemPrice) DESC) AS Customer_Rank,
        COUNT(*) OVER() AS Total_Customer_Count
    FROM Fact_Orders
    WHERE Quantity > 0
    GROUP BY CustomerID
),
RunningRevenue AS (
    SELECT
        CustomerID,
        Lifetime_Value,
        Customer_Rank,
        Total_Customer_Count,
        SUM(Lifetime_Value) OVER (ORDER BY Lifetime_Value DESC) AS Running_Revenue_Sum,
        (SELECT SUM(Quantity * ItemPrice) FROM Fact_Orders WHERE Quantity > 0) AS Grand_Total_Revenue
    FROM CustomerRevenues
)
SELECT
    Customer_Rank,
    CustomerID,
    ROUND(Lifetime_Value, 2) AS Customer_Lifetime_Value,
    ROUND((Customer_Rank * 100.0) / Total_Customer_Count, 2) AS Percentile_Customer,
    ROUND((Running_Revenue_Sum * 100.0) / Grand_Total_Revenue, 2) AS Percent_Cumulative_Revenue
FROM RunningRevenue
WHERE ROUND((Customer_Rank * 100.0) / Total_Customer_Count, 2) <= 30.0
ORDER BY Customer_Rank;


-- -----------------------------------------------------------------------------------------
-- QUERY 17: Quarter-Over-Quarter (QoQ) Customer Retention Heatmap
-- Purpose: Breaks retention cycles down by fiscal quarters, checking if retention drops
--          significantly during off-peak quarters.
-- -----------------------------------------------------------------------------------------
WITH QuarterAcquisitions AS (
    SELECT
        CustomerID,
        CONCAT('Q', DATEPART(quarter, MIN(OrderDate)), '-', YEAR(MIN(OrderDate))) AS Acquisition_Quarter,
        MIN(OrderDate) AS First_Order
    FROM Fact_Orders
    WHERE Quantity > 0
    GROUP BY CustomerID
),
QuarterActivity AS (
    SELECT
        o.CustomerID,
        qa.Acquisition_Quarter,
        CONCAT('Q', DATEPART(quarter, o.OrderDate), '-', YEAR(o.OrderDate)) AS Active_Quarter,
        DATEDIFF(quarter, qa.First_Order, o.OrderDate) AS Quarter_Index
    FROM Fact_Orders o
    JOIN QuarterAcquisitions qa ON o.CustomerID = qa.CustomerID
    WHERE o.Quantity > 0
)
SELECT
    Acquisition_Quarter,
    Quarter_Index,
    COUNT(DISTINCT CustomerID) AS Active_Customers,
    ROUND((COUNT(DISTINCT CustomerID) * 100.0) / FIRST_VALUE(COUNT(DISTINCT CustomerID)) OVER (PARTITION BY Acquisition_Quarter ORDER BY Quarter_Index), 2) AS Retention_Percent
FROM QuarterActivity
WHERE Quarter_Index BETWEEN 0 AND 4
GROUP BY Acquisition_Quarter, Quarter_Index
ORDER BY Acquisition_Quarter, Quarter_Index;


-- -----------------------------------------------------------------------------------------
-- QUERY 18: Customer Data Integrity (Null Identification & Impact Rate)
-- Purpose: Calculates missing CustomerID rates in transactional tables to check if
--          guest checkout processes are diluting structural cohort tracking.
-- -----------------------------------------------------------------------------------------
SELECT
    COUNT(*) AS Total_Logged_Orders,
    SUM(CASE WHEN CustomerID IS NULL THEN 1 ELSE 0 END) AS Null_CustomerID_Orders,
    ROUND((SUM(CASE WHEN CustomerID IS NULL THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 2) AS Null_ID_Order_Ratio_Percent,
    ROUND(SUM(CASE WHEN CustomerID IS NULL THEN Quantity * ItemPrice ELSE 0 END), 2) AS Unattributed_Revenue,
    ROUND((SUM(CASE WHEN CustomerID IS NULL THEN Quantity * ItemPrice ELSE 0 END) * 100.0) /
          SUM(Quantity * ItemPrice), 2) AS Unattributed_Revenue_Ratio_Percent
FROM Fact_Orders;


-- -----------------------------------------------------------------------------------------
-- QUERY 19: Repeat Buyer Velocity Matrix (First to Second Purchase)
-- Purpose: Focuses on the conversion speed of customer profiles. Measures exactly how many
--          days it takes for a first-time purchaser to place their second order.
-- -----------------------------------------------------------------------------------------
WITH OrderedPurchases AS (
    SELECT
        CustomerID,
        OrderDate,
        ROW_NUMBER() OVER (PARTITION BY CustomerID ORDER BY OrderDate) AS Purchase_Sequence
    FROM Fact_Orders
    WHERE Quantity > 0
),
FirstTwoPurchases AS (
    SELECT
        CustomerID,
        MAX(CASE WHEN Purchase_Sequence = 1 THEN OrderDate END) AS Purchase_One_Date,
        MAX(CASE WHEN Purchase_Sequence = 2 THEN OrderDate END) AS Purchase_Two_Date
    FROM OrderedPurchases
    WHERE Purchase_Sequence IN (1, 2)
    GROUP BY CustomerID
)
SELECT
    COUNT(CustomerID) AS Total_Customers,
    SUM(CASE WHEN Purchase_Two_Date IS NOT NULL THEN 1 ELSE 0 END) AS Converted_Repeat_Buyers,
    ROUND((SUM(CASE WHEN Purchase_Two_Date IS NOT NULL THEN 1 ELSE 0 END) * 100.0) / COUNT(CustomerID), 2) AS Conversion_Rate_Percent,
    AVG(DATEDIFF(day, Purchase_One_Date, Purchase_Two_Date)) AS Average_Conversion_Days_Span
FROM FirstTwoPurchases;


-- -----------------------------------------------------------------------------------------
-- QUERY 20: Transaction Duplication Audit
-- Purpose: Data validation query. Identifies identical transactions logged within the
--          same minute, checking database writing issues.
-- -----------------------------------------------------------------------------------------
SELECT
    CustomerID,
    OrderID,
    OrderDate,
    Quantity,
    ItemPrice,
    COUNT(*) AS Duplicate_Occurrence_Count
FROM Fact_Orders
GROUP BY CustomerID, OrderID, OrderDate, Quantity, ItemPrice
HAVING COUNT(*) > 1
ORDER BY Duplicate_Occurrence_Count DESC;


-- -----------------------------------------------------------------------------------------
-- QUERY 21: Rolling 3-Month Customer Spend Averages
-- Purpose: Evaluates customer financial momentum. Calculates the rolling 3-month total
--          revenue to assist in trend smoothing.
-- -----------------------------------------------------------------------------------------
WITH MonthlyRevenues AS (
    SELECT
        DATETRUNC(month, OrderDate) AS Transaction_Month,
        SUM(Quantity * ItemPrice) AS Monthly_Revenue
    FROM Fact_Orders
    WHERE Quantity > 0
    GROUP BY DATETRUNC(month, OrderDate)
)
SELECT
    Transaction_Month,
    ROUND(Monthly_Revenue, 2) AS Actual_Monthly_Revenue,
    ROUND(AVG(Monthly_Revenue) OVER (
        ORDER BY Transaction_Month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) AS Rolling_3Month_Average_Revenue
FROM MonthlyRevenues
ORDER BY Transaction_Month;


-- -----------------------------------------------------------------------------------------
-- QUERY 22: Executive Scorecard Segment Matrix (SQL Server Cross-Tab/Pivot style)
-- Purpose: Generates a pivot table summarizing key segment performance indicators in a
--          single visual grid for senior executives.
-- -----------------------------------------------------------------------------------------
WITH RFMScores AS (
    SELECT
        CustomerID,
        DATEDIFF(day, MAX(OrderDate), '2026-01-01') AS Recency,
        COUNT(DISTINCT OrderID) AS Frequency,
        SUM(Quantity * ItemPrice) AS Monetary
    FROM Fact_Orders
    WHERE Quantity > 0
    GROUP BY CustomerID
),
RFMTiled AS (
    SELECT
        CustomerID,
        Monetary,
        NTILE(5) OVER (ORDER BY Recency ASC) AS R,
        6 - NTILE(5) OVER (ORDER BY Frequency DESC) AS F
    FROM RFMScores
),
RFMSegment AS (
    SELECT
        CustomerID,
        Monetary,
        CASE
            WHEN R >= 4 AND F >= 4 THEN 'Champions'
            WHEN R >= 3 AND F >= 3 THEN 'Loyal Customers'
            WHEN R >= 4 AND F <= 2 THEN 'Recent/New Customers'
            WHEN R <= 2 AND F >= 3 THEN 'At Risk / Slipping'
            ELSE 'Hibernating / Lost'
        END AS Customer_Segment
    FROM RFMTiled
)
SELECT
    Customer_Segment,
    COUNT(CustomerID) AS Total_Segment_Customers,
    ROUND(SUM(Monetary), 2) AS Total_Segment_Spend,
    ROUND(AVG(Monetary), 2) AS Average_Spend_Per_Segment_Customer,
    ROUND((SUM(Monetary) * 100.0) / (SELECT SUM(Quantity * ItemPrice) FROM Fact_Orders WHERE Quantity > 0), 2) AS Segment_Contribution_Percent
FROM RFMSegment
GROUP BY Customer_Segment
ORDER BY Total_Segment_Spend DESC;
