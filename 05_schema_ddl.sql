-- =============================================================================
-- PROJECT CONCORD: VERIDIAN UNIFIED DATA PLATFORM
-- Production PostgreSQL Operational DDL Script (01_schema_ddl.sql)
-- Author: Samuel Enyi (Lead Database Architect & SQL Engineer)
-- Specification Target: 40-55 Tables (Core Hub + 5 Divisional Modules)
-- =============================================================================
-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
-- Create Logical Schemas
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS retail;
CREATE SCHEMA IF NOT EXISTS logistics;
CREATE SCHEMA IF NOT EXISTS vfs;
CREATE SCHEMA IF NOT EXISTS agricore;
CREATE SCHEMA IF NOT EXISTS properties;
-- =============================================================================
-- PART I: CORE SERVICES HUB (6 Shared Master Entities)
-- =============================================================================
-- 1. Core Locations & Sites
CREATE TABLE core.locations_sites (
    location_id VARCHAR(30) PRIMARY KEY,
    site_name VARCHAR(150) NOT NULL,
    site_type VARCHAR(50) NOT NULL CHECK (
        site_type IN (
            'STORE',
            'WAREHOUSE',
            'FARM',
            'PROPERTY',
            'OFFICE'
        )
    ),
    address TEXT NOT NULL,
    city VARCHAR(100) NOT NULL,
    country_code VARCHAR(5) NOT NULL CHECK (country_code IN ('NG', 'GH', 'KE')),
    latitude DECIMAL(9, 6),
    longitude DECIMAL(9, 6),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
-- 2. Core Customers
CREATE TABLE core.customers (
    customer_id VARCHAR(30) PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL,
    date_of_birth DATE NOT NULL,
    primary_contact VARCHAR(50) NOT NULL,
    registered_country VARCHAR(5) NOT NULL CHECK (registered_country IN ('NG', 'GH', 'KE')),
    consent_retail_loyalty BOOLEAN DEFAULT TRUE,
    consent_vfs_credit_sharing BOOLEAN DEFAULT FALSE,
    created_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
-- 3. Core Suppliers & Vendors (Includes AgriCore Farmers)
CREATE TABLE core.suppliers_vendors (
    supplier_id VARCHAR(30) PRIMARY KEY,
    legal_name VARCHAR(150) NOT NULL,
    supplier_type VARCHAR(50) NOT NULL CHECK (
        supplier_type IN ('FARMER', 'WHOLESALE_VENDOR', 'SERVICE_PROVIDER')
    ),
    primary_division_id VARCHAR(30) NOT NULL CHECK (
        primary_division_id IN (
            'AGRICORE',
            'RETAIL',
            'LOGISTICS',
            'VFS',
            'PROPERTIES'
        )
    ),
    onboarding_date DATE NOT NULL,
    status VARCHAR(30) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'SUSPENDED', 'INACTIVE'))
);
-- 4. Core Employees
CREATE TABLE core.employees (
    employee_id VARCHAR(30) PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL,
    division_id VARCHAR(30) NOT NULL CHECK (
        division_id IN (
            'RETAIL',
            'LOGISTICS',
            'AGRICORE',
            'VFS',
            'PROPERTIES',
            'EXECUTIVE'
        )
    ),
    role_title VARCHAR(100) NOT NULL,
    employment_status VARCHAR(30) DEFAULT 'ACTIVE' CHECK (
        employment_status IN ('ACTIVE', 'ON_LEAVE', 'TERMINATED')
    ),
    hire_date DATE NOT NULL,
    reports_to VARCHAR(30) REFERENCES core.employees(employee_id) ON DELETE
    SET NULL
);
-- 5. Core Product & Service Catalogue
CREATE TABLE core.product_service_catalogue (
    product_id VARCHAR(30) PRIMARY KEY,
    product_name VARCHAR(150) NOT NULL,
    category VARCHAR(50) NOT NULL CHECK (
        category IN (
            'FRESH_PRODUCE',
            'GRAINS',
            'PACKAGED_GOODS',
            'BEVERAGES',
            'SERVICES'
        )
    ),
    unit_of_measure VARCHAR(20) NOT NULL CHECK (
        unit_of_measure IN ('KG', 'TON', 'BAG', 'CARTON', 'LITRE', 'UNIT')
    ),
    primary_division_id VARCHAR(30) NOT NULL CHECK (primary_division_id IN ('AGRICORE', 'RETAIL')),
    is_active BOOLEAN DEFAULT TRUE
);
-- 6. Core Financial Account References (Read-Only Reference to VFS)
CREATE TABLE core.financial_account_references (
    account_ref_id VARCHAR(30) PRIMARY KEY,
    customer_id VARCHAR(30) NOT NULL REFERENCES core.customers(customer_id) ON DELETE RESTRICT,
    account_type VARCHAR(30) NOT NULL CHECK (account_type IN ('SAVINGS', 'WALLET', 'LOAN')),
    account_status VARCHAR(30) DEFAULT 'ACTIVE' CHECK (
        account_status IN ('ACTIVE', 'DORMANT', 'CLOSED')
    ),
    opened_date DATE NOT NULL
);
-- =============================================================================
-- PART II: MERIDIAN RETAIL AND CONSUMER MODULE
-- =============================================================================
CREATE TABLE retail.stores (
    store_id VARCHAR(30) PRIMARY KEY,
    location_id VARCHAR(30) NOT NULL REFERENCES core.locations_sites(location_id) ON DELETE RESTRICT,
    store_format VARCHAR(50) NOT NULL CHECK (
        store_format IN (
            'HYPERMARKET',
            'SUPERMARKET',
            'EXPRESS',
            'ONLINE_FULFILLMENT'
        )
    ),
    opening_date DATE NOT NULL,
    manager_employee_id VARCHAR(30) REFERENCES core.employees(employee_id) ON DELETE RESTRICT,
    property_id VARCHAR(30) -- Cross-Service Link to properties.properties (added via ALTER TABLE later)
);
CREATE TABLE retail.pos_transactions (
    transaction_id VARCHAR(40) PRIMARY KEY,
    store_id VARCHAR(30) NOT NULL REFERENCES retail.stores(store_id) ON DELETE RESTRICT,
    customer_id VARCHAR(30) REFERENCES core.customers(customer_id) ON DELETE
    SET NULL,
        transaction_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
        total_amount DECIMAL(18, 2) NOT NULL CHECK (total_amount > 0),
        payment_method VARCHAR(30) NOT NULL CHECK (
            payment_method IN ('CASH', 'VFS_WALLET', 'DEBIT_CARD', 'POS')
        )
);
CREATE TABLE retail.transaction_line_items (
    line_item_id VARCHAR(40) PRIMARY KEY,
    transaction_id VARCHAR(40) NOT NULL REFERENCES retail.pos_transactions(transaction_id) ON DELETE CASCADE,
    product_id VARCHAR(30) NOT NULL REFERENCES core.product_service_catalogue(product_id) ON DELETE RESTRICT,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(18, 2) NOT NULL CHECK (unit_price > 0)
);
CREATE TABLE retail.inventory_stock_levels (
    stock_id VARCHAR(40) PRIMARY KEY,
    store_id VARCHAR(30) NOT NULL REFERENCES retail.stores(store_id) ON DELETE RESTRICT,
    product_id VARCHAR(30) NOT NULL REFERENCES core.product_service_catalogue(product_id) ON DELETE RESTRICT,
    quantity_on_hand INT NOT NULL CHECK (quantity_on_hand >= 0),
    last_counted_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT idx_store_product_unique UNIQUE (store_id, product_id)
);
CREATE TABLE retail.promotions (
    promotion_id VARCHAR(30) PRIMARY KEY,
    product_id VARCHAR(30) NOT NULL REFERENCES core.product_service_catalogue(product_id) ON DELETE CASCADE,
    discount_type VARCHAR(30) NOT NULL CHECK (
        discount_type IN ('PERCENTAGE', 'FIXED_AMOUNT', 'BUY_1_GET_1')
    ),
    discount_value DECIMAL(18, 2) NOT NULL CHECK (discount_value > 0),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL CHECK (end_date >= start_date)
);
CREATE TABLE retail.loyalty_accounts (
    loyalty_id VARCHAR(30) PRIMARY KEY,
    customer_id VARCHAR(30) NOT NULL REFERENCES core.customers(customer_id) ON DELETE CASCADE,
    tier VARCHAR(20) DEFAULT 'BRONZE' CHECK (tier IN ('BRONZE', 'SILVER', 'GOLD', 'PLATINUM')),
    points_balance INT DEFAULT 0 CHECK (points_balance >= 0),
    enrolment_date DATE NOT NULL DEFAULT CURRENT_DATE
);
CREATE TABLE retail.supplier_deliveries (
    delivery_id VARCHAR(40) PRIMARY KEY,
    supplier_id VARCHAR(30) NOT NULL REFERENCES core.suppliers_vendors(supplier_id) ON DELETE RESTRICT,
    store_id VARCHAR(30) NOT NULL REFERENCES retail.stores(store_id) ON DELETE RESTRICT,
    expected_date DATE NOT NULL,
    received_date DATE,
    status VARCHAR(30) DEFAULT 'SCHEDULED' CHECK (
        status IN (
            'SCHEDULED',
            'RECEIVED',
            'DELAYED',
            'SHORTFALL',
            'CANCELLED'
        )
    )
);
-- =============================================================================
-- PART III: VERIDIAN FINANCIAL SERVICES (VFS) MODULE (Read-Restricted)
-- =============================================================================
CREATE TABLE vfs.wallet_accounts (
    wallet_id VARCHAR(30) PRIMARY KEY,
    customer_id VARCHAR(30) NOT NULL REFERENCES core.customers(customer_id) ON DELETE RESTRICT,
    account_ref_id VARCHAR(30) REFERENCES core.financial_account_references(account_ref_id) ON DELETE
    SET NULL,
        balance DECIMAL(18, 2) NOT NULL DEFAULT 0.00 CHECK (balance >= 0.00),
        status VARCHAR(30) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'BLOCKED', 'SUSPENDED'))
);
CREATE TABLE vfs.wallet_transactions (
    wallet_txn_id VARCHAR(40) PRIMARY KEY,
    wallet_id VARCHAR(30) NOT NULL REFERENCES vfs.wallet_accounts(wallet_id) ON DELETE RESTRICT,
    counterparty_type VARCHAR(50) NOT NULL CHECK (
        counterparty_type IN (
            'MERIDIAN_RETAIL_POS',
            'AGRICORE_PAYOUT',
            'TRANSFER',
            'DEPOSIT',
            'WITHDRAWAL'
        )
    ),
    amount DECIMAL(18, 2) NOT NULL CHECK (amount > 0),
    transaction_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE vfs.loans (
    loan_id VARCHAR(30) PRIMARY KEY,
    borrower_customer_id VARCHAR(30) REFERENCES core.customers(customer_id) ON DELETE RESTRICT,
    borrower_supplier_id VARCHAR(30) REFERENCES core.suppliers_vendors(supplier_id) ON DELETE RESTRICT,
    principal_amount DECIMAL(18, 2) NOT NULL CHECK (principal_amount > 0),
    interest_rate DECIMAL(5, 2) NOT NULL CHECK (interest_rate > 0),
    status VARCHAR(30) DEFAULT 'ACTIVE' CHECK (
        status IN (
            'APPLIED',
            'DISBURSED',
            'ACTIVE',
            'PAID_OFF',
            'DEFAULTED'
        )
    )
);
CREATE TABLE vfs.loan_repayments (
    repayment_id VARCHAR(40) PRIMARY KEY,
    loan_id VARCHAR(30) NOT NULL REFERENCES vfs.loans(loan_id) ON DELETE RESTRICT,
    due_date DATE NOT NULL,
    amount_due DECIMAL(18, 2) NOT NULL CHECK (amount_due > 0),
    paid_amount DECIMAL(18, 2) DEFAULT 0.00 CHECK (paid_amount >= 0),
    paid_date DATE
);
CREATE TABLE vfs.kyc_records (
    kyc_id VARCHAR(30) PRIMARY KEY,
    customer_id VARCHAR(30) NOT NULL REFERENCES core.customers(customer_id) ON DELETE CASCADE,
    verification_level VARCHAR(20) NOT NULL CHECK (
        verification_level IN ('TIER_1', 'TIER_2', 'TIER_3')
    ),
    verified_date DATE NOT NULL DEFAULT CURRENT_DATE
);
CREATE TABLE vfs.merchant_settlements (
    settlement_id VARCHAR(40) PRIMARY KEY,
    division_id VARCHAR(30) NOT NULL CHECK (
        division_id IN ('RETAIL', 'LOGISTICS', 'AGRICORE')
    ),
    settlement_date DATE NOT NULL,
    total_amount DECIMAL(18, 2) NOT NULL CHECK (total_amount > 0)
);
-- =============================================================================
-- PART IV: AGRICORE AGRIBUSINESS MODULE
-- =============================================================================
CREATE TABLE agricore.farms (
    farm_id VARCHAR(30) PRIMARY KEY,
    supplier_id VARCHAR(30) NOT NULL REFERENCES core.suppliers_vendors(supplier_id) ON DELETE RESTRICT,
    location_id VARCHAR(30) NOT NULL REFERENCES core.locations_sites(location_id) ON DELETE RESTRICT,
    size_hectares DECIMAL(8, 2) NOT NULL CHECK (size_hectares > 0),
    primary_crop VARCHAR(50) NOT NULL
);
CREATE TABLE agricore.farmers (
    farmer_id VARCHAR(30) PRIMARY KEY,
    supplier_id VARCHAR(30) NOT NULL REFERENCES core.suppliers_vendors(supplier_id) ON DELETE RESTRICT,
    registration_date DATE NOT NULL,
    cooperative_name VARCHAR(150)
);
CREATE TABLE agricore.harvest_batches (
    harvest_id VARCHAR(30) PRIMARY KEY,
    farm_id VARCHAR(30) NOT NULL REFERENCES agricore.farms(farm_id) ON DELETE RESTRICT,
    product_id VARCHAR(30) NOT NULL REFERENCES core.product_service_catalogue(product_id) ON DELETE RESTRICT,
    harvest_date DATE NOT NULL,
    volume_kg DECIMAL(12, 2) NOT NULL CHECK (volume_kg > 0),
    field_agent_employee_id VARCHAR(30) REFERENCES core.employees(employee_id) ON DELETE
    SET NULL
);
CREATE TABLE agricore.processing_runs (
    run_id VARCHAR(30) PRIMARY KEY,
    harvest_id VARCHAR(30) NOT NULL REFERENCES agricore.harvest_batches(harvest_id) ON DELETE RESTRICT,
    facility_location_id VARCHAR(30) NOT NULL REFERENCES core.locations_sites(location_id) ON DELETE RESTRICT,
    run_date DATE NOT NULL,
    output_volume_kg DECIMAL(12, 2) NOT NULL CHECK (output_volume_kg >= 0)
);
CREATE TABLE agricore.quality_grades (
    grade_id VARCHAR(30) PRIMARY KEY,
    run_id VARCHAR(30) NOT NULL REFERENCES agricore.processing_runs(run_id) ON DELETE CASCADE,
    grade_level VARCHAR(20) NOT NULL CHECK (
        grade_level IN ('GRADE_A', 'GRADE_B', 'GRADE_C', 'REJECTED')
    ),
    moisture_content DECIMAL(5, 2),
    inspector_employee_id VARCHAR(30) REFERENCES core.employees(employee_id) ON DELETE
    SET NULL
);
CREATE TABLE agricore.wholesale_shipments (
    wholesale_id VARCHAR(30) PRIMARY KEY,
    run_id VARCHAR(30) NOT NULL REFERENCES agricore.processing_runs(run_id) ON DELETE RESTRICT,
    destination_type VARCHAR(30) NOT NULL CHECK (
        destination_type IN ('MERIDIAN_RETAIL_STORE', 'THIRD_PARTY_CLIENT')
    ),
    destination_id VARCHAR(30) NOT NULL,
    shipment_id VARCHAR(40) -- Cross-service link to logistics.shipments
);
CREATE TABLE agricore.farmer_loans_reference (
    reference_id VARCHAR(30) PRIMARY KEY,
    farmer_id VARCHAR(30) NOT NULL REFERENCES agricore.farmers(farmer_id) ON DELETE CASCADE,
    loan_id VARCHAR(30) NOT NULL REFERENCES vfs.loans(loan_id) ON DELETE CASCADE,
    visible_summary_status VARCHAR(50) NOT NULL
);
-- =============================================================================
-- PART V: CONCORD LOGISTICS MODULE
-- =============================================================================
CREATE TABLE logistics.vehicles (
    vehicle_id VARCHAR(30) PRIMARY KEY,
    registration_number VARCHAR(30) UNIQUE NOT NULL,
    vehicle_type VARCHAR(50) NOT NULL CHECK (
        vehicle_type IN (
            'LAST_MILE_VAN',
            'HAULAGE_TRUCK',
            'REFRIGERATED_TRUCK'
        )
    ),
    capacity_kg INT NOT NULL CHECK (capacity_kg > 0),
    status VARCHAR(30) DEFAULT 'AVAILABLE' CHECK (
        status IN ('AVAILABLE', 'IN_TRANSIT', 'MAINTENANCE')
    )
);
CREATE TABLE logistics.drivers (
    driver_id VARCHAR(30) PRIMARY KEY,
    employee_id VARCHAR(30) NOT NULL REFERENCES core.employees(employee_id) ON DELETE RESTRICT,
    licence_number VARCHAR(50) UNIQUE NOT NULL,
    licence_expiry DATE NOT NULL
);
CREATE TABLE logistics.shipments (
    shipment_id VARCHAR(40) PRIMARY KEY,
    origin_location_id VARCHAR(30) NOT NULL REFERENCES core.locations_sites(location_id) ON DELETE RESTRICT,
    destination_location_id VARCHAR(30) NOT NULL REFERENCES core.locations_sites(location_id) ON DELETE RESTRICT,
    client_type VARCHAR(50) NOT NULL CHECK (
        client_type IN (
            'INTERNAL_AGRICORE',
            'INTERNAL_RETAIL',
            'THIRD_PARTY_COMMERCIAL'
        )
    ),
    status VARCHAR(30) DEFAULT 'SCHEDULED' CHECK (
        status IN (
            'SCHEDULED',
            'IN_TRANSIT',
            'DELIVERED',
            'DELAYED',
            'CANCELLED'
        )
    ),
    CONSTRAINT chk_diff_locations CHECK (destination_location_id <> origin_location_id)
);
CREATE TABLE logistics.shipment_legs (
    leg_id VARCHAR(40) PRIMARY KEY,
    shipment_id VARCHAR(40) NOT NULL REFERENCES logistics.shipments(shipment_id) ON DELETE CASCADE,
    vehicle_id VARCHAR(30) NOT NULL REFERENCES logistics.vehicles(vehicle_id) ON DELETE RESTRICT,
    driver_id VARCHAR(30) NOT NULL REFERENCES logistics.drivers(driver_id) ON DELETE RESTRICT,
    departure_time TIMESTAMP WITH TIME ZONE,
    arrival_time TIMESTAMP WITH TIME ZONE
);
CREATE TABLE logistics.routes (
    route_id VARCHAR(30) PRIMARY KEY,
    route_name VARCHAR(150) NOT NULL,
    origin_location_id VARCHAR(30) NOT NULL REFERENCES core.locations_sites(location_id) ON DELETE RESTRICT,
    destination_location_id VARCHAR(30) NOT NULL REFERENCES core.locations_sites(location_id) ON DELETE RESTRICT,
    distance_km DECIMAL(8, 2) NOT NULL CHECK (distance_km > 0)
);
CREATE TABLE logistics.warehouses (
    warehouse_id VARCHAR(30) PRIMARY KEY,
    location_id VARCHAR(30) NOT NULL REFERENCES core.locations_sites(location_id) ON DELETE RESTRICT,
    capacity_units INT NOT NULL CHECK (capacity_units > 0),
    leased_from_property_id VARCHAR(30) -- Cross-service link to properties.properties
);
CREATE TABLE logistics.maintenance_logs (
    maintenance_id VARCHAR(40) PRIMARY KEY,
    vehicle_id VARCHAR(30) NOT NULL REFERENCES logistics.vehicles(vehicle_id) ON DELETE CASCADE,
    service_date DATE NOT NULL,
    cost DECIMAL(18, 2) NOT NULL CHECK (cost >= 0),
    description TEXT
);
-- =============================================================================
-- PART VI: VERIDIAN PROPERTIES MODULE
-- =============================================================================
CREATE TABLE properties.properties (
    property_id VARCHAR(30) PRIMARY KEY,
    location_id VARCHAR(30) NOT NULL REFERENCES core.locations_sites(location_id) ON DELETE RESTRICT,
    property_type VARCHAR(50) NOT NULL CHECK (
        property_type IN (
            'RETAIL_STORE_PREMISES',
            'LOGISTICS_WAREHOUSE',
            'AGRI_FACILITY',
            'COMMERCIAL_OFFICE'
        )
    ),
    size_sqm DECIMAL(10, 2) NOT NULL CHECK (size_sqm > 0),
    ownership_status VARCHAR(30) NOT NULL CHECK (
        ownership_status IN ('OWNED_FREEHOLD', 'LEASED_FROM_LANDLORD')
    )
);
CREATE TABLE properties.tenants (
    tenant_id VARCHAR(30) PRIMARY KEY,
    tenant_type VARCHAR(30) NOT NULL CHECK (
        tenant_type IN (
            'INTERNAL_DIVISION',
            'EXTERNAL_COMMERCIAL_TENANT'
        )
    ),
    division_id VARCHAR(30) CHECK (
        division_id IN ('RETAIL', 'LOGISTICS', 'AGRICORE', 'VFS')
    ),
    external_tenant_name VARCHAR(150)
);
CREATE TABLE properties.leases (
    lease_id VARCHAR(30) PRIMARY KEY,
    property_id VARCHAR(30) NOT NULL REFERENCES properties.properties(property_id) ON DELETE RESTRICT,
    tenant_id VARCHAR(30) NOT NULL REFERENCES properties.tenants(tenant_id) ON DELETE RESTRICT,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    monthly_rent DECIMAL(18, 2) NOT NULL CHECK (monthly_rent > 0),
    CONSTRAINT chk_lease_dates CHECK (end_date > start_date)
);
CREATE TABLE properties.maintenance_requests (
    request_id VARCHAR(40) PRIMARY KEY,
    property_id VARCHAR(30) NOT NULL REFERENCES properties.properties(property_id) ON DELETE CASCADE,
    requested_date DATE NOT NULL DEFAULT CURRENT_DATE,
    category VARCHAR(50) NOT NULL,
    status VARCHAR(30) DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'IN_PROGRESS', 'RESOLVED')),
    resolved_date DATE
);
CREATE TABLE properties.property_valuations (
    valuation_id VARCHAR(40) PRIMARY KEY,
    property_id VARCHAR(30) NOT NULL REFERENCES properties.properties(property_id) ON DELETE CASCADE,
    valuation_date DATE NOT NULL,
    assessed_value DECIMAL(18, 2) NOT NULL CHECK (assessed_value > 0)
);
CREATE TABLE properties.utility_accounts (
    utility_id VARCHAR(30) PRIMARY KEY,
    property_id VARCHAR(30) NOT NULL REFERENCES properties.properties(property_id) ON DELETE CASCADE,
    utility_type VARCHAR(30) NOT NULL CHECK (
        utility_type IN ('ELECTRICITY', 'WATER', 'WASTE_MANAGEMENT')
    ),
    provider_name VARCHAR(100) NOT NULL,
    account_number VARCHAR(50) NOT NULL
);
CREATE TABLE properties.facility_assets (
    asset_id VARCHAR(40) PRIMARY KEY,
    property_id VARCHAR(30) NOT NULL REFERENCES properties.properties(property_id) ON DELETE CASCADE,
    asset_type VARCHAR(50) NOT NULL,
    installed_date DATE NOT NULL,
    condition_rating VARCHAR(30) CHECK (
        condition_rating IN ('EXCELLENT', 'GOOD', 'FAIR', 'NEEDS_REPLACEMENT')
    )
);
-- =============================================================================
-- PART VII: CROSS-SERVICE FOREIGN KEY CONSTRAINTS (ALTER TABLE)
-- =============================================================================
ALTER TABLE retail.stores
ADD CONSTRAINT fk_store_property FOREIGN KEY (property_id) REFERENCES properties.properties(property_id) ON DELETE
SET NULL;
ALTER TABLE logistics.warehouses
ADD CONSTRAINT fk_warehouse_property FOREIGN KEY (leased_from_property_id) REFERENCES properties.properties(property_id) ON DELETE
SET NULL;
ALTER TABLE agricore.wholesale_shipments
ADD CONSTRAINT fk_wholesale_shipment FOREIGN KEY (shipment_id) REFERENCES logistics.shipments(shipment_id) ON DELETE
SET NULL;
-- End of DDL Script