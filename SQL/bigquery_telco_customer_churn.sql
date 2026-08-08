-- ==============================================
-- Telecom Customer Churn Analysis
-- Tool: Google BigQuery
-- Author: Sinchana Bhat
-- Dataset: IBM Telco Customer Churn (via Kaggle)
-- ==============================================

-- ============================================================
-- 1. DATA EXPLORATION
-- ============================================================
-- Preview the dataset
SELECT * FROM `data-eye-503306-k8.telco_customer_churn.customer_churn` LIMIT 10;

-- Total number of customers
SELECT COUNT(*) AS total_customers FROM `data-eye-503306-k8.telco_customer_churn.customer_churn`;


-- Checking target variable churn
SELECT Churn,COUNT(*) AS customer_count FROM `data-eye-503306-k8.telco_customer_churn.customer_churn` GROUP BY Churn;

-- Summary statistics for numeric columns
SELECT 
MIN(tenure) AS min_tenure,
MAX(tenure) AS max_tenure,
AVG(tenure) AS avg_tenure,
MIN(MonthlyCharges) AS min_monthly,
MAX(MonthlyCharges) AS max_monthly,
AVG(MonthlyCharges) AS avg_monthly,
FROM `data-eye-503306-k8.telco_customer_churn.customer_churn`;

-- ============================================================
-- 2. DATA CLEANING
-- ============================================================
-- Count blank TotalCharges values
SELECT COUNT(*) AS blank_totalcharges FROM `data-eye-503306-k8.telco_customer_churn.customer_churn` WHERE TRIM(TotalCharges)='';

-- Display rows with blank TotalCharges
SELECT customerID,tenure,MonthlyCharges,TotalCharges FROM `data-eye-503306-k8.telco_customer_churn.customer_churn` WHERE TRIM(TotalCharges)='';

-- Create cleaned table (blank TotalCharges converted to proper NULL/FLOAT64)
CREATE OR REPLACE TABLE `data-eye-503306-k8.telco_customer_churn.customer_churn_cleaned` AS SELECT * EXCEPT(TotalCharges),SAFE_CAST(NULLIF(TRIM(TotalCharges), '') AS FLOAT64) AS TotalCharges
FROM `data-eye-503306-k8.telco_customer_churn.customer_churn`;

-- Verify remaining NULL values
SELECT TotalCharges from `data-eye-503306-k8.telco_customer_churn.customer_churn_cleaned` WHERE TotalCharges IS NULL;

-- ============================================================
-- 3. CHURN OVERVIEW
-- ============================================================

-- total churned customers
SELECT Churn,COUNT(*) AS churned_customers
FROM `data-eye-503306-k8.telco_customer_churn.customer_churn_cleaned` GROUP BY Churn;

-- churned customer percentage
SELECT ROUND(COUNTIF(Churn = true) * 100.0 / COUNT(*),2) AS churn_rate
FROM `data-eye-503306-k8.telco_customer_churn.customer_churn_cleaned`;

-- ============================================================
-- 4. CHURN BY CUSTOMER SEGMENT
-- ============================================================
-- which contract type has more churn rate
SELECT 
Contract,
COUNT(*) as total_customers,
COUNTIF(Churn=true) as churned_customers,
ROUND(COUNTIF(Churn = true) * 100.0 / COUNT(*),2) AS churn_rate 
from `data-eye-503306-k8.telco_customer_churn.customer_churn_cleaned` 
GROUP BY Contract
ORDER BY churn_rate DESC;

-- Do senior citizens churn more than non-senior citizens?
SELECT SeniorCitizen, 
COUNT(*) as total_customers,
COUNTIF(churn=true) churned_customers,
ROUND(COUNTIF(Churn = true) * 100.0 / COUNT(*),2) AS churn_rate 
FROM `data-eye-503306-k8.telco_customer_churn.customer_churn_cleaned`
GROUP BY SeniorCitizen;

-- Does gender affect churn?
SELECT gender, 
COUNT(*) as total_customers,
COUNTIF(churn=true) churned_customers,
ROUND(COUNTIF(Churn = true) * 100.0 / COUNT(*),2) AS churn_rate 
FROM `data-eye-503306-k8.telco_customer_churn.customer_churn_cleaned`
GROUP BY gender;

-- Does having partner affect churn?
SELECT Partner, 
COUNT(*) as total_customers,
COUNTIF(churn=true) churned_customers,
ROUND(COUNTIF(Churn = true) * 100.0 / COUNT(*),2) AS churn_rate 
FROM `data-eye-503306-k8.telco_customer_churn.customer_churn_cleaned`
GROUP BY Partner;

-- Does having dependents affect churn?
SELECT Dependents, 
COUNT(*) as total_customers,
COUNTIF(churn=true) churned_customers,
ROUND(COUNTIF(Churn = true) * 100.0 / COUNT(*),2) AS churn_rate 
FROM `data-eye-503306-k8.telco_customer_churn.customer_churn_cleaned`
GROUP BY Dependents;

-- Does paperless billing affect churn?
SELECT PaperlessBilling, 
COUNT(*) as total_customers,
COUNTIF(churn=true) churned_customers,
ROUND(COUNTIF(Churn = true) * 100.0 / COUNT(*),2) AS churn_rate 
FROM `data-eye-503306-k8.telco_customer_churn.customer_churn_cleaned`
GROUP BY PaperlessBilling;

-- ============================================================
-- 5. CHURN VS. FINANCIAL METRICS
-- ============================================================
-- Average tenure for churned vs not churned
SELECT Churn,ROUND(AVG(tenure),2) AS avg_tenure FROM `data-eye-503306-k8.telco_customer_churn.customer_churn_cleaned`
GROUP BY Churn;

-- Do churned customers pay higher monthly charges than retained customers?
SELECT churn, ROUND(AVG(MonthlyCharges),2) AS avg_monthly_charges FROM `data-eye-503306-k8.telco_customer_churn.customer_churn_cleaned` GROUP BY Churn;

-- Average TotalCharges by Churn status
SELECT churn, ROUND(AVG(TotalCharges),2) AS avg_monthly_charges FROM `data-eye-503306-k8.telco_customer_churn.customer_churn_cleaned` GROUP BY Churn;

-- Which monthly charge ranges have the highest churn?
SELECT
CASE
WHEN MonthlyCharges < 25 THEN '0-25'
WHEN MonthlyCharges < 50 THEN '25-50'
WHEN MonthlyCharges < 75 THEN '50-75'
WHEN MonthlyCharges < 100 THEN '75-100'
ELSE '100+'
END AS monthly_charge_range,
COUNT(*) AS total_customers,
COUNTIF(Churn = TRUE) AS churned_customers,
ROUND(COUNTIF(Churn = TRUE) * 100.0 / COUNT(*),2) AS churn_rate
FROM `data-eye-503306-k8.telco_customer_churn.customer_churn_cleaned`
GROUP BY monthly_charge_range
ORDER BY monthly_charge_range;

-- ============================================================
-- 6. ADVANCED ANALYSIS: WINDOW FUNCTIONS & CTEs
-- ============================================================
-- Rank payment methods by their churn rate, so we can see which payment method is riskiest relative to the others
SELECT
  PaymentMethod,
  COUNT(*) AS total_customers,
  COUNTIF(Churn = TRUE) AS churned_customers,
  ROUND(COUNTIF(Churn = TRUE) * 100.0 / COUNT(*), 2) AS churn_rate,
  RANK() OVER (ORDER BY COUNTIF(Churn = TRUE) * 100.0 / COUNT(*) DESC) AS churn_risk_rank
FROM `data-eye-503306-k8.telco_customer_churn.customer_churn_cleaned`
GROUP BY PaymentMethod
ORDER BY churn_risk_rank;


-- How does each contract type's churn rate compare to the overall average churn rate?
WITH overall_churn AS (
  SELECT
    ROUND(COUNTIF(Churn = TRUE) * 100.0 / COUNT(*), 2) AS overall_churn_rate
  FROM `data-eye-503306-k8.telco_customer_churn.customer_churn_cleaned`
)

SELECT
  c.Contract,
  COUNT(*) AS total_customers,
  COUNTIF(c.Churn = TRUE) AS churned_customers,
  ROUND(COUNTIF(c.Churn = TRUE) * 100.0 / COUNT(*), 2) AS contract_churn_rate,
  o.overall_churn_rate,
  ROUND(
    (COUNTIF(c.Churn = TRUE) * 100.0 / COUNT(*)) - o.overall_churn_rate, 2
  ) AS difference_from_average
FROM `data-eye-503306-k8.telco_customer_churn.customer_churn_cleaned` c
CROSS JOIN overall_churn o
GROUP BY c.Contract, o.overall_churn_rate
ORDER BY contract_churn_rate DESC;