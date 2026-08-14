-- =============================================================================
-- PROJECT CONCORD: VERIDIAN UNIFIED DATA PLATFORM
-- Database Security & Row Level Security (RLS) Policies (02_security_rls.sql)
-- Author: Samuel Enyi (Lead Database Architect & SQL Engineer)
-- Compliance Target: Central Bank Microfinance Guidelines & Nigeria Data Protection Act
-- =============================================================================

-- 1. Create Database Roles
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'retail_staff') THEN
        CREATE ROLE retail_staff;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'logistics_staff') THEN
        CREATE ROLE logistics_staff;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'agricore_staff') THEN
        CREATE ROLE agricore_staff;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'properties_staff') THEN
        CREATE ROLE properties_staff;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'vfs_staff') THEN
        CREATE ROLE vfs_staff;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'executive_role') THEN
        CREATE ROLE executive_role;
    END IF;
END $$;

-- 2. Enable Row Level Security (RLS) on Sensitive VFS Tables
ALTER TABLE vfs.wallet_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE vfs.wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE vfs.loans ENABLE ROW LEVEL SECURITY;
ALTER TABLE vfs.loan_repayments ENABLE ROW LEVEL SECURITY;
ALTER TABLE vfs.kyc_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.customers ENABLE ROW LEVEL SECURITY;

-- 3. RLS Policy: VFS Staff Full Access to Banking Data
CREATE POLICY vfs_staff_full_wallet_policy ON vfs.wallet_accounts
    FOR ALL TO vfs_staff USING (TRUE);

CREATE POLICY vfs_staff_full_loans_policy ON vfs.loans
    FOR ALL TO vfs_staff USING (TRUE);

CREATE POLICY vfs_staff_full_kyc_policy ON vfs.kyc_records
    FOR ALL TO vfs_staff USING (TRUE);

-- 4. RLS Policy: Executive Read Access (Consolidated Reporting)
CREATE POLICY executive_wallet_read_policy ON vfs.wallet_accounts
    FOR SELECT TO executive_role USING (TRUE);

CREATE POLICY executive_loans_read_policy ON vfs.loans
    FOR SELECT TO executive_role USING (TRUE);

-- 5. RLS Policy: Customer Consent-Based Cross-Divisional Access (Scenario 2)
-- Allows VFS loan officers to query AgriCore harvest supply history ONLY IF customer consented
CREATE POLICY vfs_farmer_harvest_view_policy ON agricore.farms
    FOR SELECT
    TO vfs_staff
    USING (
        EXISTS (
            SELECT 1 FROM core.customers c 
            WHERE c.customer_id = farms.supplier_id 
            AND c.consent_vfs_credit_sharing = TRUE
        )
    );

-- 6. PII Masking View for Non-VFS Staff
CREATE OR REPLACE VIEW core.v_masked_customers AS
SELECT 
    customer_id,
    full_name,
    registered_country,
    consent_retail_loyalty,
    consent_vfs_credit_sharing,
    -- Mask contact details for non-VFS roles
    CONCAT(SUBSTRING(primary_contact FROM 1 FOR 6), 'XXXX') AS masked_contact,
    created_date
FROM core.customers;

-- End of Security & RLS Script
