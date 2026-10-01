-- =============================================================================
-- BANKING DATA PIPELINE: ANALYTICAL VIEWS
-- =============================================================================

-- 1. EXECUTIVE FINANCIAL OVERVIEW & ROLLING METRICS
CREATE OR REPLACE VIEW v_customer_transaction_trends AS
SELECT 
    t.transaction_id,
    t.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    t.amount,
    t.transaction_type,
    t.location_city,
    t.transaction_time,
    -- 5-Transaction Moving Average per Customer
    AVG(t.amount) OVER (
        PARTITION BY t.customer_id 
        ORDER BY t.transaction_time 
        ROWS BETWEEN 4 PRECEDING AND CURRENT ROW
    ) AS rolling_avg_amount_5tx,
    -- Running Total Expenditures per Customer
    SUM(t.amount) OVER (
        PARTITION BY t.customer_id 
        ORDER BY t.transaction_time
    ) AS customer_running_total
FROM transactions t
JOIN customers c ON t.customer_id = c.customer_id;

-- 2. FRAUD DETECTION & RISK PATTERNS (IMPOSSIBLE TRAVEL)
CREATE OR REPLACE VIEW v_fraud_detection_patterns AS
WITH ranked_transactions AS (
    SELECT 
        t.transaction_id,
        t.customer_id,
        t.amount,
        t.location_city,
        t.transaction_time,
        LAG(t.location_city) OVER (PARTITION BY t.customer_id ORDER BY t.transaction_time) AS prev_city,
        LAG(t.transaction_time) OVER (PARTITION BY t.customer_id ORDER BY t.transaction_time) AS prev_time
    FROM transactions t
)
SELECT 
    transaction_id,
    customer_id,
    amount,
    location_city AS current_city,
    prev_city,
    transaction_time AS current_time,
    prev_time,
    EXTRACT(EPOCH FROM (transaction_time - prev_time)) / 60.0 AS minutes_since_last_tx,
    CASE 
        WHEN location_city != prev_city 
             AND EXTRACT(EPOCH FROM (transaction_time - prev_time)) / 60.0 < 30 
        THEN 'HIGH_RISK_IMPOSSIBLE_TRAVEL'
        WHEN amount > 10000 
        THEN 'HIGH_VALUE_ALERT'
        ELSE 'NORMAL'
    END AS risk_flag
FROM ranked_transactions;
