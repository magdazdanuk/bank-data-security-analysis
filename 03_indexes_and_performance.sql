-- =============================================================================
-- BANKING DATA PIPELINE: INDEXES & PERFORMANCE OPTIMIZATION
-- =============================================================================

-- 1. B-Tree Composite Index for Customer Analytical Queries
CREATE INDEX idx_transactions_customer_time 
ON transactions(customer_id, transaction_time DESC);

-- 2. Partial Index for High-Value Risk Monitoring
CREATE INDEX idx_transactions_high_value 
ON transactions(amount) 
WHERE amount > 5000;

-- 3. B-Tree Index on City for Geographical Aggregations
CREATE INDEX idx_transactions_city 
ON transactions(location_city);

-- 4. Sample EXPLAIN ANALYZE verification query
EXPLAIN ANALYZE
SELECT 
    customer_id,
    AVG(amount) AS avg_spend
FROM transactions
WHERE transaction_time >= NOW() - INTERVAL '30 days'
GROUP BY customer_id;
