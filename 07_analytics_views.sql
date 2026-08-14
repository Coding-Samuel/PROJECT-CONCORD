-- =============================================================================
-- PROJECT CONCORD: VERIDIAN UNIFIED DATA PLATFORM
-- Analytical SQL Views for Power BI / BigQuery (03_analytics_views.sql)
-- Author: Samuel Enyi (Lead Database Architect & SQL Engineer)
-- Purpose: Pre-built queries solving the 4 Stakeholder Scenarios for BI Devs
-- =============================================================================

-- VIEW 1: Stakeholder Scenario 1 — Store Stockout & Supply Alert (Ngozi's Plantain Alert)
DROP VIEW IF EXISTS retail.v_agricore_retail_supply_alert CASCADE;
CREATE OR REPLACE VIEW retail.v_agricore_retail_supply_alert AS
SELECT 
    s.store_id,
    loc.site_name AS store_location_name,
    loc.city AS store_city,
    loc.country_code,
    p.product_id,
    p.product_name,
    isl.quantity_on_hand AS retail_stock_on_hand,
    COALESCE(hb.total_harvest_kg, 0) AS recent_harvest_volume_kg,
    COALESCE(sd.delivery_status, 'IN_TRANSIT') AS delivery_status
FROM retail.stores s
JOIN core.locations_sites loc ON s.location_id = loc.location_id
JOIN retail.inventory_stock_levels isl ON s.store_id = isl.store_id
JOIN core.product_service_catalogue p ON isl.product_id = p.product_id
LEFT JOIN (
    SELECT product_id, SUM(volume_kg) AS total_harvest_kg
    FROM agricore.harvest_batches
    GROUP BY product_id
) hb ON p.product_id = hb.product_id
LEFT JOIN (
    SELECT DISTINCT ON (store_id) store_id, status AS delivery_status
    FROM retail.supplier_deliveries
    ORDER BY store_id, expected_date DESC
) sd ON s.store_id = sd.store_id;

-- VIEW 2: Stakeholder Scenario 2 — Farmer Cross-Divisional Credit History (Chinedu's Loan View)
DROP VIEW IF EXISTS vfs.v_farmer_credit_evaluation CASCADE;
CREATE OR REPLACE VIEW vfs.v_farmer_credit_evaluation AS
SELECT 
    c.customer_id,
    c.full_name AS farmer_name,
    c.primary_contact,
    sv.supplier_id,
    f.farm_id,
    f.primary_crop,
    f.size_hectares,
    loc.country_code,
    COUNT(DISTINCT hb.harvest_id) AS total_harvest_batches,
    SUM(hb.volume_kg) AS cumulative_harvest_volume_kg,
    MIN(hb.harvest_date) AS first_harvest_date,
    MAX(hb.harvest_date) AS last_harvest_date,
    c.consent_vfs_credit_sharing
FROM core.customers c
JOIN core.suppliers_vendors sv ON c.full_name = sv.legal_name
JOIN agricore.farms f ON sv.supplier_id = f.supplier_id
LEFT JOIN core.locations_sites loc ON f.location_id = loc.location_id
LEFT JOIN agricore.harvest_batches hb ON f.farm_id = hb.farm_id
WHERE c.consent_vfs_credit_sharing = TRUE
GROUP BY c.customer_id, c.full_name, c.primary_contact, sv.supplier_id, f.farm_id, f.primary_crop, f.size_hectares, loc.country_code, c.consent_vfs_credit_sharing;

-- VIEW 3: Stakeholder Scenario 3 — Warehouse Lease & Depot Capacity Status (Funmi's Dispatch View)
DROP VIEW IF EXISTS logistics.v_warehouse_lease_utilization CASCADE;
CREATE OR REPLACE VIEW logistics.v_warehouse_lease_utilization AS
SELECT 
    w.warehouse_id,
    loc.site_name AS warehouse_depot_name,
    loc.city,
    loc.country_code,
    w.capacity_units AS total_pallet_capacity,
    p.property_id,
    p.ownership_status,
    l.lease_id,
    l.monthly_rent,
    l.start_date AS lease_start_date,
    l.end_date AS lease_end_date,
    CASE 
        WHEN l.end_date < CURRENT_DATE THEN 'EXPIRED_LEASE'
        WHEN l.end_date <= CURRENT_DATE + INTERVAL '90 days' THEN 'RENEWAL_DUE_SOON'
        ELSE 'ACTIVE_LEASE'
    END AS lease_status
FROM logistics.warehouses w
JOIN core.locations_sites loc ON w.location_id = loc.location_id
LEFT JOIN properties.properties p ON w.leased_from_property_id = p.property_id
LEFT JOIN properties.leases l ON p.property_id = l.property_id;

-- VIEW 4: Stakeholder Scenario 4 — Executive Consolidated Revenue & Performance (CEO Adaeze's View)
DROP VIEW IF EXISTS core.v_executive_consolidated_revenue CASCADE;
CREATE OR REPLACE VIEW core.v_executive_consolidated_revenue AS
SELECT 
    'MERIDIAN_RETAIL' AS division,
    COALESCE(loc.country_code, 'NG') AS country_code,
    pt.transaction_date::DATE AS transaction_date,
    SUM(pt.total_amount) AS total_revenue_ngn,
    COUNT(pt.transaction_id) AS transaction_count,
    MAX(pt.transaction_date) AS last_transaction_timestamp
FROM retail.pos_transactions pt
LEFT JOIN retail.stores s ON pt.store_id = s.store_id
LEFT JOIN core.locations_sites loc ON s.location_id = loc.location_id
GROUP BY 1, 2, 3

UNION ALL

SELECT 
    'VFS_MICROFINANCE' AS division,
    'NG' AS country_code,
    wt.transaction_date::DATE AS transaction_date,
    SUM(wt.amount) AS total_revenue_ngn,
    COUNT(wt.wallet_txn_id) AS transaction_count,
    MAX(wt.transaction_date) AS last_transaction_timestamp
FROM vfs.wallet_transactions wt
GROUP BY 1, 2, 3

UNION ALL

SELECT 
    'AGRICORE' AS division,
    COALESCE(loc.country_code, 'NG') AS country_code,
    pr.run_date::DATE AS transaction_date,
    SUM(pr.output_volume_kg * 450.00) AS total_revenue_ngn,
    COUNT(pr.run_id) AS transaction_count,
    MAX(pr.run_date::timestamp) AS last_transaction_timestamp
FROM agricore.processing_runs pr
LEFT JOIN core.locations_sites loc ON pr.facility_location_id = loc.location_id
GROUP BY 1, 2, 3

UNION ALL

SELECT 
    'CONCORD_LOGISTICS' AS division,
    COALESCE(loc.country_code, 'NG') AS country_code,
    CURRENT_DATE AS transaction_date,
    COUNT(s.shipment_id) * 185000.00 AS total_revenue_ngn,
    COUNT(s.shipment_id) AS transaction_count,
    CURRENT_TIMESTAMP AS last_transaction_timestamp
FROM logistics.shipments s
LEFT JOIN core.locations_sites loc ON s.origin_location_id = loc.location_id
GROUP BY 1, 2, 3

UNION ALL

SELECT 
    'VERIDIAN_PROPERTIES' AS division,
    COALESCE(loc.country_code, 'NG') AS country_code,
    l.start_date::DATE AS transaction_date,
    SUM(l.monthly_rent * 12) AS total_revenue_ngn,
    COUNT(l.lease_id) AS transaction_count,
    MAX(l.start_date::timestamp) AS last_transaction_timestamp
FROM properties.leases l
LEFT JOIN properties.properties p ON l.property_id = p.property_id
LEFT JOIN core.locations_sites loc ON p.location_id = loc.location_id
GROUP BY 1, 2, 3;

-- End of Analytical Views Script
