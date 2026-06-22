-- =========================================================================================
-- Customer Behavior & Cohort Retention - Analytical Queries
-- Author: Ravikant Yadav
-- Database Platform: SQL Server (T-SQL) / PostgreSQL Compatible
-- Description: This script contains advanced SQL queries executed to transform and analyze
--              customer behavioral transaction records. It showcases relational joins,
--              SQL-based RFM partitioning, and cohort index calculation logic.
-- =========================================================================================

-- -----------------------------------------------------------------------------------------
-- QUERY 1: Preview Customer Demographics & Transaction Relationship
-- Purpose: Inspect join integrity between transaction logs and customer profile dimensions.
-- -----------------------------------------------------------------------------------------

SELECT TOP 5
    o.OrderID,
    o.CustomerID,
    o.OrderDate,
    o.Quantity,
    (o.Quantity * o.ItemPrice) AS TransactionAmount,
    c.Gender,
    c.Age,
    c.AcquisitionChannel
FROM Fact_Orders o
JOIN Dim_Customer c ON o.CustomerID = c.CustomerID
WHERE o.Quantity > 0;


-- -----------------------------------------------------------------------------------------
-- QUERY 2: SQL-Based RFM Score Computation (No Python Dependency)
-- Techniques Used: CTEs, Window Functions (NTILE), Aggregate Functions
-- Purpose: Performs raw database-level customer segmentation, grouping customers into
--          quintiles (1 to 5) for Recency, Frequency, and Monetary value.
-- -----------------------------------------------------------------------------------------

WITH CustomerAggregates AS (
    -- Step 1: Calculate raw RFM metrics per customer
    SELECT
        CustomerID,
        -- Days since last order (using a static reference snapshot of 2026-01-01)
        DATEDIFF(day, MAX(OrderDate), '2026-01-01') AS Recency,
        -- Total distinct orders placed
        COUNT(DISTINCT OrderID) AS Frequency,
        -- Total spent
        SUM(Quantity * ItemPrice) AS Monetary
    FROM Fact_Orders
    WHERE Quantity > 0
    GROUP BY CustomerID
),
RFMBins AS (
    -- Step 2: Use NTILE to divide metrics into quintiles (1-5 scale)
    SELECT
        CustomerID,
        Recency,
        Frequency,
        Monetary,
        -- Recency: Lower value is better, so reverse the scoring (NTILE(5) over ORDER BY Recency ASC means low recency gets 1, we want it to get 5)
        NTILE(5) OVER (ORDER BY Recency ASC) AS R_Group, -- 1 is most recent, 5 is oldest. We will invert in the outer select.
        NTILE(5) OVER (ORDER BY Frequency ASC) AS F_Group,
        NTILE(5) OVER (ORDER BY Monetary ASC) AS M_Group
    FROM CustomerAggregates
)
SELECT
    CustomerID,
    Recency,
    Frequency,
    Monetary,
    -- Invert Recency score so 5 is the most recent (best) and 1 is the oldest
    (6 - R_Group) AS R_Score,
    F_Group AS F_Score,
    M_Group AS M_Score,
    -- Combine scores into a joint class string (e.g., '555' or '111')
    CONCAT(CAST(6 - R_Group AS VARCHAR), CAST(F_Group AS VARCHAR), CAST(M_Group AS VARCHAR)) AS RFM_Class
FROM RFMBins
ORDER BY Monetary DESC;


-- -----------------------------------------------------------------------------------------
-- QUERY 3: Demographic Profiling of Customer Segments
-- Techniques Used: Subqueries, Relational Joins, Multi-Group Aggregation
-- Purpose: Evaluate if specific age brackets or genders dominate your top "Champions" segment.
-- -----------------------------------------------------------------------------------------

WITH CustomerRFM AS (
    SELECT
        CustomerID,
        DATEDIFF(day, MAX(OrderDate), '2026-01-01') AS Recency,
        COUNT(DISTINCT OrderID) AS Frequency,
        SUM(Quantity * ItemPrice) AS Monetary
    FROM Fact_Orders
    WHERE Quantity > 0
    GROUP BY CustomerID
),
SegmentedCustomers AS (
    SELECT
        CustomerID,
        Monetary,
        CASE
            WHEN Frequency >= 10 AND Recency <= 30 THEN 'Champions'
            WHEN Frequency >= 5 AND Recency <= 90 THEN 'Loyal Customers'
            WHEN Frequency <= 2 AND Recency <= 30 THEN 'New Customers'
            WHEN Recency BETWEEN 91 AND 180 THEN 'At Risk'
            ELSE 'Hibernating'
        END AS Segment
    FROM CustomerRFM
)
SELECT
    s.Segment,
    c.Gender,
    COUNT(DISTINCT s.CustomerID) AS CustomerCount,
    ROUND(SUM(s.Monetary), 2) AS SegmentTotalRevenue,
    ROUND(AVG(c.Age), 1) AS AverageAge,
    ROUND(AVG(s.Monetary), 2) AS AverageSpendPerCustomer
FROM SegmentedCustomers s
JOIN Dim_Customer c ON s.CustomerID = c.CustomerID
GROUP BY s.Segment, c.Gender
ORDER BY SegmentTotalRevenue DESC;


-- -----------------------------------------------------------------------------------------
-- QUERY 4: E-Commerce Cohort Analysis (Relational Retention Matrix)
-- Techniques Used: CTEs, Date Math, Join Partitioning, Aggregations
-- Purpose: Track customer sign-up month cohorts and calculate subsequent return rates.
-- -----------------------------------------------------------------------------------------

WITH CustomerSignup AS (
    -- Step 1: Identify the cohort month (first purchase month) for each customer
    SELECT
        CustomerID,
        MIN(OrderDate) AS FirstOrderDate,
        -- Standardize to the first day of that month
        DATEADD(month, DATEDIFF(month, 0, MIN(OrderDate)), 0) AS CohortMonth
    FROM Fact_Orders
    WHERE Quantity > 0
    GROUP BY CustomerID
),
TransactionActivity AS (
    -- Step 2: Get all purchase months for these customers
    SELECT DISTINCT
        o.CustomerID,
        DATEADD(month, DATEDIFF(month, 0, o.OrderDate), 0) AS PurchaseMonth,
        c.CohortMonth
    FROM Fact_Orders o
    JOIN CustomerSignup c ON o.CustomerID = c.CustomerID
    WHERE o.Quantity > 0
),
CohortLapse AS (
    -- Step 3: Calculate the month index (difference between transaction month and signup month)
    SELECT
        CustomerID,
        CohortMonth,
        PurchaseMonth,
        DATEDIFF(month, CohortMonth, PurchaseMonth) AS CohortIndex
    FROM TransactionActivity
)
-- Step 4: Pivot / Group cohorts to display returning counts across retention indexes (0 to 6 months)
SELECT
    CohortMonth,
    COUNT(DISTINCT CASE WHEN CohortIndex = 0 THEN CustomerID END) AS Size_Month_0,
    COUNT(DISTINCT CASE WHEN CohortIndex = 1 THEN CustomerID END) AS Month_1_Active,
    COUNT(DISTINCT CASE WHEN CohortIndex = 2 THEN CustomerID END) AS Month_2_Active,
    COUNT(DISTINCT CASE WHEN CohortIndex = 3 THEN CustomerID END) AS Month_3_Active,
    COUNT(DISTINCT CASE WHEN CohortIndex = 4 THEN CustomerID END) AS Month_4_Active,
    COUNT(DISTINCT CASE WHEN CohortIndex = 5 THEN CustomerID END) AS Month_5_Active,
    COUNT(DISTINCT CASE WHEN CohortIndex = 6 THEN CustomerID END) AS Month_6_Active
FROM CohortLapse
GROUP BY CohortMonth
ORDER BY CohortMonth;


-- -----------------------------------------------------------------------------------------
-- QUERY 5: Rolling Customer Churn Risk Assessment
-- Techniques Used: CTEs, Analytic LAG, Window Partitioning
-- Purpose: Monitor consecutive gaps between customer orders to flag profiles showing
--          escalating churn probability.
-- -----------------------------------------------------------------------------------------

WITH OrderedTransactions AS (
    SELECT
        CustomerID,
        OrderID,
        OrderDate,
        -- Fetch the timestamp of the customer's previous transaction
        LAG(OrderDate, 1) OVER (PARTITION BY CustomerID ORDER BY OrderDate) AS PreviousOrderDate
    FROM Fact_Orders
    WHERE Quantity > 0
),
OrderIntervals AS (
    SELECT
        CustomerID,
        OrderID,
        OrderDate,
        PreviousOrderDate,
        DATEDIFF(day, PreviousOrderDate, OrderDate) AS DaysBetweenOrders
    FROM OrderedTransactions
    WHERE PreviousOrderDate IS NOT NULL
)
SELECT
    CustomerID,
    COUNT(OrderID) AS TotalRepeatOrders,
    AVG(DaysBetweenOrders) AS AveragePurchaseIntervalDays,
    MAX(DaysBetweenOrders) AS LongestInactivityWindowDays,
    CASE
        WHEN AVG(DaysBetweenOrders) > 90 THEN 'Critical Churn Risk'
        WHEN AVG(DaysBetweenOrders) BETWEEN 45 AND 90 THEN 'Moderate Inactivity'
        ELSE 'Healthy Activity Frequency'
    END AS ChurnRiskStatus
FROM OrderIntervals
GROUP BY CustomerID
ORDER BY AveragePurchaseIntervalDays DESC;
