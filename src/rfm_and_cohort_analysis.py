"""
Customer Behavior Analytics - Cohort & RFM Segmentation Pipeline
Author: Ravikant Yadav
Description: This script simulates the advanced customer analytical pipeline outlined in the resume.
             It generates transactional data for 1,000 customers, calculates Recency, Frequency, and Monetary (RFM) metrics,
             segments them into actionable cohorts, and computes a customer cohort retention matrix.
"""

import pandas as pd
import numpy as np
import os
from datetime import datetime

def generate_messy_customer_data(num_orders=5000):
    """Generates transactional records for a simulated e-commerce customer cohort"""
    np.random.seed(101)

    # Simulated Customer ID pool (approx 1,000 distinct customers)
    customer_pool = [f"CUST-{1000 + i}" for i in range(1000)]
    customer_ids = np.random.choice(customer_pool, num_orders).astype(object)

    # Ingest Null Customer IDs (simulating guest checkouts or incomplete registrations as per resume)
    for i in range(num_orders):
        if np.random.rand() < 0.05:  # 5% null customer IDs in raw transaction streams
            customer_ids[i] = None

    # Transaction Dates spanning 12 months (Jan 2025 to Dec 2025)
    date_range = pd.date_range(start="2025-01-01", end="2025-12-31", freq="min")
    dates = np.random.choice(date_range, num_orders)

    # E-commerce quantities and order values
    order_ids = [f"ORD-{50000 + i}" for i in range(num_orders)]
    quantities = np.random.randint(1, 6, num_orders)
    item_prices = np.random.uniform(5.0, 150.0, num_orders).round(2)

    df = pd.DataFrame({
        "OrderID": order_ids,
        "CustomerID": customer_ids,
        "OrderDate": dates,
        "Quantity": quantities,
        "ItemPrice": item_prices
    })

    # Add negative quantity transactions (returns/cancellations)
    return_indices = np.random.choice(num_orders, int(num_orders * 0.03), replace=False)
    df.loc[return_indices, "Quantity"] = -df.loc[return_indices, "Quantity"]

    return df

def process_customer_analytics(df):
    """Performs RFM analysis and Cohort Retention clustering"""
    print("--- Starting Customer Behavior analytical Pipeline ---")
    print(f"Raw Transaction Shape: {df.shape}")

    # 1. Clean Data: Drop null customer IDs and drop returns
    print("Dropping transactional logs with null CustomerIDs...")
    cleaned_df = df.dropna(subset=["CustomerID"]).copy()

    print("Handling negative/return transactions (removing orders with quantity <= 0)...")
    cleaned_df = cleaned_df[cleaned_df["Quantity"] > 0]

    # Calculate Total Amount per order
    cleaned_df["TotalAmount"] = (cleaned_df["Quantity"] * cleaned_df["ItemPrice"]).round(2)

    print(f"Transactions after data sanitization: {cleaned_df.shape}")

    # 2. Cohort Analytics Setup
    print("Beginning Cohort Analysis calculations...")
    # Get the billing month for each transaction
    cleaned_df["OrderMonth"] = cleaned_df["OrderDate"].dt.to_period("M")
    # Identify each customer's first purchase month.
    cleaned_df["CohortMonth"] = cleaned_df.groupby("CustomerID")["OrderMonth"].transform("min")

    # 3. RFM Analysis Calculations
    print("Executing RFM Segmentation...")
    # Define reference date for Recency (usually 1 day after the max date in dataset)
    snapshot_date = cleaned_df["OrderDate"].max() + pd.Timedelta(days=1)

    # Group by Customer to aggregate RFM metrics
    rfm = cleaned_df.groupby("CustomerID").agg({
        "OrderDate": lambda x: (snapshot_date - x.max()).days, # Recency
        "OrderID": "nunique",                                  # Frequency
        "TotalAmount": "sum"                                   # Monetary
    }).rename(columns={"OrderDate": "Recency", "OrderID": "Frequency", "TotalAmount": "Monetary"})

    # Bin customer scores into quintiles (1-5 scale) using qcut
    print("Calculating RFM Quintile scores...")
    rfm["R_Score"] = pd.qcut(rfm["Recency"], 5, labels=[5, 4, 3, 2, 1])  # Lower recency = better customer (5)
    rfm["F_Score"] = pd.qcut(rfm["Frequency"].rank(method="first"), 5, labels=[1, 2, 3, 4, 5])
    rfm["M_Score"] = pd.qcut(rfm["Monetary"], 5, labels=[1, 2, 3, 4, 5])

    # Construct joint RFM Score
    rfm["RFM_Class"] = rfm["R_Score"].astype(str) + rfm["F_Score"].astype(str) + rfm["M_Score"].astype(str)

    # Categorize into human-readable business segments
    print("Segmenting customers based on behavioral profiles...")
    def segment_rfm(row):
        r, f = int(row["R_Score"]), int(row["F_Score"])
        if r >= 4 and f >= 4:
            return "Champions"
        elif r >= 3 and f >= 3:
            return "Loyal Customers"
        elif r >= 4 and f <= 2:
            return "Recent/New Customers"
        elif r <= 2 and f >= 3:
            return "At Risk / Slipping"
        else:
            return "Hibernating / Lost"

    rfm["Customer_Segment"] = rfm.apply(segment_rfm, axis=1)

    # 4. Compute Cohort Retention Heatmap Data
    print("Generating Cohort Retention matrix...")
    # Count customer activity by Cohort month and billing lapse index
    cohort_group = cleaned_df.groupby(["CohortMonth", "OrderMonth"])
    cohort_data = cohort_group["CustomerID"].nunique().reset_index()

    # Calculate index (difference in months between cohort signup and order date)
    def calculate_cohort_index(row):
        cohort_year = row["CohortMonth"].year
        cohort_month = row["CohortMonth"].month
        order_year = row["OrderMonth"].year
        order_month = row["OrderMonth"].month
        return (order_year - cohort_year) * 12 + (order_month - cohort_month)

    cohort_data["CohortIndex"] = cohort_data.apply(calculate_cohort_index, axis=1)

    # Pivot table to construct cohort matrix
    cohort_matrix = cohort_data.pivot(index="CohortMonth", columns="CohortIndex", values="CustomerID")
    cohort_sizes = cohort_matrix.iloc[:, 0]
    retention_matrix = cohort_matrix.divide(cohort_sizes, axis=0).round(4) * 100

    print("--- Cohort & RFM Calculations Finished Successfully ---")

    return cleaned_df, rfm, retention_matrix

if __name__ == "__main__":
    # Create output directory using relative paths
    os.makedirs("data", exist_ok=True)

    # Run Simulation
    raw_data = generate_messy_customer_data(5000)
    cleaned_orders, rfm_results, cohort_matrix = process_customer_analytics(raw_data)

    # Save to CSV Files for reference in relative paths
    raw_data.to_csv("data/raw_customer_orders.csv", index=False)
    cleaned_orders.to_csv("data/cleaned_customer_orders.csv", index=False)
    rfm_results.to_csv("data/customer_rfm_segments.csv")
    cohort_matrix.to_csv("data/customer_cohort_retention_matrix.csv")

    print("\nCustomer RFM Segment distribution:")
    print(rfm_results["Customer_Segment"].value_counts())

    print("\nCohort Retention Matrix Preview (Lapse months 0 to 5, in %):")
    print(cohort_matrix.iloc[:5, :6])
