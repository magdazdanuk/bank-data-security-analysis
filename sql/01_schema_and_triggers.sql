-- =============================================================================
-- BANKING DATA PIPELINE: SCHEMA & AUTOMATED TRIGGERS
-- =============================================================================

-- 1. DATABASE SCHEMA SETUP
CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE transactions (
    transaction_id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES customers(customer_id) ON DELETE CASCADE,
    amount NUMERIC(12, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'PLN',
    transaction_type VARCHAR(20) CHECK (transaction_type IN ('CARD_PAYMENT', 'TRANSFER', 'ATM_WITHDRAWAL', 'LOAN_REPAYMENT')),
    merchant_category VARCHAR(50),
    location_city VARCHAR(50),
    transaction_time TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE audit_logs (
    log_id SERIAL PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    operation VARCHAR(10) NOT NULL,
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    user_name VARCHAR(50) DEFAULT CURRENT_USER,
    old_data JSONB,
    new_data JSONB
);

-- 2. AUTOMATED DATA CLEANING TRIGGER
CREATE OR REPLACE FUNCTION fn_clean_transaction_data()
RETURNS TRIGGER AS $$
BEGIN
    -- Trim whitespace and uppercase location/city
    NEW.location_city := UPPER(TRIM(NEW.location_city));
    
    -- Ensure standard currency uppercase
    NEW.currency := UPPER(TRIM(NEW.currency));
    
    -- Reject invalid negative values for card payments
    IF NEW.amount <= 0 THEN
        RAISE EXCEPTION 'Transaction amount must be strictly positive. Value provided: %', NEW.amount;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_clean_transaction
BEFORE INSERT OR UPDATE ON transactions
FOR EACH ROW
EXECUTE FUNCTION fn_clean_transaction_data();

-- 3. AUDIT LOGGING TRIGGER
CREATE OR REPLACE FUNCTION fn_auto_audit_log()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        INSERT INTO audit_logs (table_name, operation, old_data)
        VALUES (TG_TABLE_NAME, 'DELETE', row_to_json(OLD)::jsonb);
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO audit_logs (table_name, operation, old_data, new_data)
        VALUES (TG_TABLE_NAME, 'UPDATE', row_to_json(OLD)::jsonb, row_to_json(NEW)::jsonb);
        RETURN NEW;
    ELSIF (TG_OP = 'INSERT') THEN
        INSERT INTO audit_logs (table_name, operation, new_data)
        VALUES (TG_TABLE_NAME, 'INSERT', row_to_json(NEW)::jsonb);
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_transactions
AFTER INSERT OR UPDATE OR DELETE ON transactions
FOR EACH ROW
EXECUTE FUNCTION fn_auto_audit_log();
