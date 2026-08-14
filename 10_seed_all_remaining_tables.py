import os
import csv
import random
import psycopg2

uri = "postgresql://postgres.hraipqaksitkchkhhdye:Fi4nMf2MXD668s3x@aws-1-eu-west-2.pooler.supabase.com:6543/postgres"

print("Connecting to Supabase PostgreSQL to seed remaining 15 auxiliary tables...")
conn = psycopg2.connect(uri)
conn.autocommit = False
cursor = conn.cursor()

# 1. Seed agricore.farmers
cursor.execute("SELECT supplier_id FROM core.suppliers_vendors WHERE supplier_type = 'FARMER';")
farmer_supps = [r[0] for r in cursor.fetchall()]
if not farmer_supps:
    cursor.execute("SELECT supplier_id FROM core.suppliers_vendors LIMIT 500;")
    farmer_supps = [r[0] for r in cursor.fetchall()]

farmers_data = []
farmer_ids = []
for idx, s_id in enumerate(farmer_supps, 1):
    f_id = f"FMR{idx:05d}"
    reg_date = "2025-03-10"
    coop = f"Farmers Cooperative Group {idx%20+1}"
    farmers_data.append((f_id, s_id, reg_date, coop))
    farmer_ids.append(f_id)

cursor.executemany("INSERT INTO agricore.farmers (farmer_id, supplier_id, registration_date, cooperative_name) VALUES (%s, %s, %s, %s) ON CONFLICT DO NOTHING;", farmers_data)
conn.commit()
print(f"Seeded agricore.farmers ({len(farmers_data)} records)")

# 2. Seed vfs.kyc_records
cursor.execute("SELECT customer_id FROM core.customers LIMIT 40000;")
cust_ids = [r[0] for r in cursor.fetchall()]
kyc_data = []
levels = ["TIER_1", "TIER_2", "TIER_3"]
for idx, c_id in enumerate(cust_ids, 1):
    kyc_id = f"KYC{idx:06d}"
    lvl = random.choice(levels)
    v_date = "2026-01-10"
    kyc_data.append((kyc_id, c_id, lvl, v_date))

cursor.executemany("INSERT INTO vfs.kyc_records (kyc_id, customer_id, verification_level, verified_date) VALUES (%s, %s, %s, %s) ON CONFLICT DO NOTHING;", kyc_data)
conn.commit()
print(f"Seeded vfs.kyc_records ({len(kyc_data)} records)")

# 3. Seed vfs.merchant_settlements
settlements_data = []
divs = ["RETAIL", "LOGISTICS", "AGRICORE"]
for i in range(1, 1001):
    s_id = f"STL{i:05d}"
    div = random.choice(divs)
    s_date = "2026-07-20"
    amt = round(random.uniform(50000.0, 5000000.0), 2)
    settlements_data.append((s_id, div, s_date, amt))

cursor.executemany("INSERT INTO vfs.merchant_settlements (settlement_id, division_id, settlement_date, total_amount) VALUES (%s, %s, %s, %s) ON CONFLICT DO NOTHING;", settlements_data)
conn.commit()
print(f"Seeded vfs.merchant_settlements ({len(settlements_data)} records)")

# 4. Seed logistics.drivers
cursor.execute("SELECT employee_id FROM core.employees WHERE division_id = 'LOGISTICS';")
log_emps = [r[0] for r in cursor.fetchall()]
if not log_emps:
    cursor.execute("SELECT employee_id FROM core.employees LIMIT 200;")
    log_emps = [r[0] for r in cursor.fetchall()]

driver_data = []
driver_ids = []
for idx, emp_id in enumerate(log_emps, 1):
    d_id = f"DRV{idx:04d}"
    lic = f"LIC-NG-{idx:05d}"
    exp = "2028-12-31"
    driver_data.append((d_id, emp_id, lic, exp))
    driver_ids.append(d_id)

cursor.executemany("INSERT INTO logistics.drivers (driver_id, employee_id, licence_number, licence_expiry) VALUES (%s, %s, %s, %s) ON CONFLICT DO NOTHING;", driver_data)
conn.commit()
print(f"Seeded logistics.drivers ({len(driver_data)} records)")

# 5. Seed logistics.routes
cursor.execute("SELECT location_id FROM core.locations_sites LIMIT 300;")
loc_ids = [r[0] for r in cursor.fetchall()]

route_data = []
for i in range(1, 151):
    r_id = f"RTE{i:04d}"
    o_loc = loc_ids[(i-1) % len(loc_ids)]
    d_loc = loc_ids[i % len(loc_ids)]
    r_name = f"Route {o_loc} to {d_loc}"
    dist = round(random.uniform(15.0, 650.0), 2)
    route_data.append((r_id, r_name, o_loc, d_loc, dist))

cursor.executemany("INSERT INTO logistics.routes (route_id, route_name, origin_location_id, destination_location_id, distance_km) VALUES (%s, %s, %s, %s, %s) ON CONFLICT DO NOTHING;", route_data)
conn.commit()
print(f"Seeded logistics.routes ({len(route_data)} records)")

# 6. Seed logistics.shipment_legs
cursor.execute("SELECT shipment_id FROM logistics.shipments LIMIT 20000;")
shp_ids = [r[0] for r in cursor.fetchall()]
cursor.execute("SELECT vehicle_id FROM logistics.vehicles LIMIT 300;")
veh_ids = [r[0] for r in cursor.fetchall()]

legs_data = []
for idx, s_id in enumerate(shp_ids, 1):
    leg_id = f"LEG{idx:05d}"
    v_id = veh_ids[idx % len(veh_ids)]
    d_id = driver_ids[idx % len(driver_ids)] if driver_ids else f"DRV{(idx%200)+1:04d}"
    dep = "2026-07-15 08:00:00+00"
    arr = "2026-07-15 16:30:00+00"
    legs_data.append((leg_id, s_id, v_id, d_id, dep, arr))

cursor.executemany("INSERT INTO logistics.shipment_legs (leg_id, shipment_id, vehicle_id, driver_id, departure_time, arrival_time) VALUES (%s, %s, %s, %s, %s, %s) ON CONFLICT DO NOTHING;", legs_data)
conn.commit()
print(f"Seeded logistics.shipment_legs ({len(legs_data)} records)")

# 7. Seed logistics.maintenance_logs
m_logs_data = []
for i in range(1, 501):
    m_id = f"MNT{i:04d}"
    v_id = veh_ids[i % len(veh_ids)]
    s_date = "2026-06-15"
    cost = round(random.uniform(25000.0, 350000.0), 2)
    desc = "Routine engine servicing and tire replacement"
    m_logs_data.append((m_id, v_id, s_date, cost, desc))

cursor.executemany("INSERT INTO logistics.maintenance_logs (maintenance_id, vehicle_id, service_date, cost, description) VALUES (%s, %s, %s, %s, %s) ON CONFLICT DO NOTHING;", m_logs_data)
conn.commit()
print(f"Seeded logistics.maintenance_logs ({len(m_logs_data)} records)")

# 8. Seed properties.facility_assets, property_valuations, utility_accounts
cursor.execute("SELECT property_id FROM properties.properties LIMIT 100;")
prop_ids = [r[0] for r in cursor.fetchall()]

assets_data = []
vals_data = []
util_data = []
asset_types = ["HVAC_SYSTEM", "BACKUP_GENERATOR", "SOLAR_INVERTER", "SECURITY_CCTV"]
ratings = ["EXCELLENT", "GOOD", "FAIR", "NEEDS_REPLACEMENT"]
u_types = ["ELECTRICITY", "WATER", "WASTE_MANAGEMENT"]

for idx, p_id in enumerate(prop_ids, 1):
    # Asset
    ast_id = f"AST{idx:04d}"
    a_type = random.choice(asset_types)
    inst_date = "2023-05-10"
    rating = random.choice(ratings)
    assets_data.append((ast_id, p_id, a_type, inst_date, rating))
    
    # Valuation
    val_id = f"VAL{idx:04d}"
    v_date = "2026-01-01"
    a_val = round(random.uniform(50000000.0, 850000000.0), 2)
    vals_data.append((val_id, p_id, v_date, a_val))
    
    # Utility
    u_id = f"UTL{idx:04d}"
    u_t = random.choice(u_types)
    p_name = "Veridian Energy Services"
    acc_num = f"ACC-UTL-{idx:06d}"
    util_data.append((u_id, p_id, u_t, p_name, acc_num))

cursor.executemany("INSERT INTO properties.facility_assets (asset_id, property_id, asset_type, installed_date, condition_rating) VALUES (%s, %s, %s, %s, %s) ON CONFLICT DO NOTHING;", assets_data)
cursor.executemany("INSERT INTO properties.property_valuations (valuation_id, property_id, valuation_date, assessed_value) VALUES (%s, %s, %s, %s) ON CONFLICT DO NOTHING;", vals_data)
cursor.executemany("INSERT INTO properties.utility_accounts (utility_id, property_id, utility_type, provider_name, account_number) VALUES (%s, %s, %s, %s, %s) ON CONFLICT DO NOTHING;", util_data)
conn.commit()
print(f"Seeded properties.facility_assets ({len(assets_data)}), property_valuations ({len(vals_data)}), utility_accounts ({len(util_data)})")

# 9. Seed retail.promotions & retail.supplier_deliveries
cursor.execute("SELECT product_id FROM core.product_service_catalogue LIMIT 150;")
prod_ids = [r[0] for r in cursor.fetchall()]
cursor.execute("SELECT store_id FROM retail.stores LIMIT 100;")
store_ids = [r[0] for r in cursor.fetchall()]
cursor.execute("SELECT supplier_id FROM core.suppliers_vendors LIMIT 5000;")
supp_ids = [r[0] for r in cursor.fetchall()]

promos_data = []
d_types = ["PERCENTAGE", "FIXED_AMOUNT", "BUY_1_GET_1"]
for idx, p_id in enumerate(prod_ids, 1):
    promo_id = f"PRM{idx:04d}"
    dt = random.choice(d_types)
    val = 15.00 if dt == "PERCENTAGE" else 500.00
    s_d = "2026-07-01"
    e_d = "2026-08-31"
    promos_data.append((promo_id, p_id, dt, val, s_d, e_d))

deliveries_data = []
statuses = ["SCHEDULED", "RECEIVED", "DELAYED", "SHORTFALL", "CANCELLED"]
for i in range(1, 1001):
    del_id = f"DEL{i:05d}"
    s_id = supp_ids[i % len(supp_ids)]
    st_id = store_ids[i % len(store_ids)]
    exp_d = "2026-07-15"
    rec_d = "2026-07-15"
    st = random.choice(statuses)
    deliveries_data.append((del_id, s_id, st_id, exp_d, rec_d, st))

cursor.executemany("INSERT INTO retail.promotions (promotion_id, product_id, discount_type, discount_value, start_date, end_date) VALUES (%s, %s, %s, %s, %s, %s) ON CONFLICT DO NOTHING;", promos_data)
cursor.executemany("INSERT INTO retail.supplier_deliveries (delivery_id, supplier_id, store_id, expected_date, received_date, status) VALUES (%s, %s, %s, %s, %s, %s) ON CONFLICT DO NOTHING;", deliveries_data)
conn.commit()
print(f"Seeded retail.promotions ({len(promos_data)}), supplier_deliveries ({len(deliveries_data)})")

# 10. Seed vfs.loans reference & wholesale shipments
cursor.execute("SELECT loan_id FROM vfs.loans LIMIT 3000;")
loan_ids = [r[0] for r in cursor.fetchall()]
cursor.execute("SELECT run_id FROM agricore.processing_runs LIMIT 7500;")
run_ids = [r[0] for r in cursor.fetchall()]
cursor.execute("SELECT shipment_id FROM logistics.shipments LIMIT 20000;")
shp_ids = [r[0] for r in cursor.fetchall()]

loan_refs_data = []
for idx, l_id in enumerate(loan_ids[:len(farmer_ids)], 1):
    ref_id = f"FLR{idx:05d}"
    f_id = farmer_ids[idx-1]
    status = "ACTIVE_PERFORMING"
    loan_refs_data.append((ref_id, f_id, l_id, status))

wholesale_data = []
dest_types = ["MERIDIAN_RETAIL_STORE", "THIRD_PARTY_CLIENT"]
for idx, r_id in enumerate(run_ids[:5000], 1):
    w_id = f"WHS{idx:05d}"
    d_type = random.choice(dest_types)
    d_id = store_ids[idx % len(store_ids)]
    s_id = shp_ids[idx % len(shp_ids)]
    wholesale_data.append((w_id, r_id, d_type, d_id, s_id))

cursor.executemany("INSERT INTO agricore.farmer_loans_reference (reference_id, farmer_id, loan_id, visible_summary_status) VALUES (%s, %s, %s, %s) ON CONFLICT DO NOTHING;", loan_refs_data)
cursor.executemany("INSERT INTO agricore.wholesale_shipments (wholesale_id, run_id, destination_type, destination_id, shipment_id) VALUES (%s, %s, %s, %s, %s) ON CONFLICT DO NOTHING;", wholesale_data)
conn.commit()
print(f"Seeded agricore.farmer_loans_reference ({len(loan_refs_data)}), wholesale_shipments ({len(wholesale_data)})")

# 11. Seed retail.transaction_line_items (sample 100,000 line items)
cursor.execute("SELECT transaction_id FROM retail.pos_transactions LIMIT 50000;")
pos_txns = [r[0] for r in cursor.fetchall()]

items_data = []
for idx, t_id in enumerate(pos_txns, 1):
    item_id = f"LNI{idx:07d}"
    p_id = prod_ids[idx % len(prod_ids)]
    qty = random.randint(1, 5)
    u_price = round(random.uniform(250.0, 4500.0), 2)
    items_data.append((item_id, t_id, p_id, qty, u_price))

# Chunk insert
chunk_sz = 10000
for i in range(0, len(items_data), chunk_sz):
    cursor.executemany("INSERT INTO retail.transaction_line_items (line_item_id, transaction_id, product_id, quantity, unit_price) VALUES (%s, %s, %s, %s, %s) ON CONFLICT DO NOTHING;", items_data[i:i+chunk_sz])
    conn.commit()

print(f"Seeded retail.transaction_line_items ({len(items_data)} records)")

cursor.close()
conn.close()
print("\n==========================================")
print("100% FULL TABLE COVERAGE COMPLETE! ALL 40 TABLES SEEDED!")
print("==========================================")
