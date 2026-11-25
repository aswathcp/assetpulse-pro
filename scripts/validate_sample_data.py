import openpyxl

h_wb = openpyxl.load_workbook('Hierarchy_Master_Sample_Medium.xlsx', data_only=True)
a_wb = openpyxl.load_workbook('Asset_Master_Sample_Medium.xlsx', data_only=True)

def sheet_dicts(wb, sname):
    ws = wb[sname]
    rows = list(ws.iter_rows(values_only=True))
    headers = [str(h).strip() for h in rows[0]]
    res = []
    for r in rows[1:]:
        if not any(r): continue
        d = {headers[i]: r[i] for i in range(len(headers))}
        res.append(d)
    return res

areas = sheet_dicts(h_wb, 'Physical Areas')
rooms = sheet_dicts(h_wb, 'Panel Rooms')
panels = sheet_dicts(h_wb, 'Panels')
feeders = sheet_dicts(h_wb, 'Feeders')
transformers = sheet_dicts(h_wb, 'Transformers')
master_eq = sheet_dicts(h_wb, 'Master Equipment')

area_ids = {a['id'] for a in areas}
room_ids = {r['id'] for r in rooms}
panel_ids = {p['id'] for p in panels}
feeder_ids = {f['id'] for f in feeders}
tr_ids = {t['id'] for t in transformers}
me_ids = {m['id'] for m in master_eq}

print("=== HIERARCHY MASTER COUNTS ===")
print(f"  Physical Areas:    {len(areas)}")
print(f"  Panel Rooms:       {len(rooms)}")
print(f"  Panels:            {len(panels)}")
print(f"  Feeders:           {len(feeders)}")
print(f"  Transformers:      {len(transformers)}")
print(f"  Master Equipments: {len(master_eq)}")

errors = []

# Validate Rooms -> Areas
for r in rooms:
    if r['locationId'] not in area_ids:
        errors.append(f"Room {r['id']} has invalid locationId: {r['locationId']}")

# Validate Panels -> Rooms
for p in panels:
    if p['panelRoomId'] not in room_ids:
        errors.append(f"Panel {p['id']} has invalid panelRoomId: {p['panelRoomId']}")

# Validate Feeders -> Panels
for f in feeders:
    if f['panelId'] not in panel_ids:
        errors.append(f"Feeder {f['id']} has invalid panelId: {f['panelId']}")

# Validate Transformers
for t in transformers:
    if t['primarySourceFeederId'] and t['primarySourceFeederId'] not in feeder_ids:
        errors.append(f"Transformer {t['id']} has invalid primarySourceFeederId: {t['primarySourceFeederId']}")
    if t['secondaryTargetPanelId'] and t['secondaryTargetPanelId'] not in panel_ids:
        errors.append(f"Transformer {t['id']} has invalid secondaryTargetPanelId: {t['secondaryTargetPanelId']}")
    if t['tertiaryTargetPanelId'] and t['tertiaryTargetPanelId'] not in panel_ids:
        errors.append(f"Transformer {t['id']} has invalid tertiaryTargetPanelId: {t['tertiaryTargetPanelId']}")
    if t['locationId'] and t['locationId'] not in area_ids:
        errors.append(f"Transformer {t['id']} has invalid locationId: {t['locationId']}")

# Validate Master Equipment -> Locations, Rooms, Panels, Feeders
for m in master_eq:
    if m['locationId'] not in area_ids:
        errors.append(f"Master Eq {m['id']} has invalid locationId: {m['locationId']}")
    if m['panelRoomId'] not in room_ids:
        errors.append(f"Master Eq {m['id']} has invalid panelRoomId: {m['panelRoomId']}")
    if m['panelId'] not in panel_ids:
        errors.append(f"Master Eq {m['id']} has invalid panelId: {m['panelId']}")
    if m['feederId'] not in feeder_ids:
        errors.append(f"Master Eq {m['id']} has invalid feederId: {m['feederId']}")

# Validate Assets -> Master Equipment
print("\n=== ASSET MASTER COUNTS ===")
asset_sheets = ['Motors', 'Brakes', 'Actuators', 'Gearboxes', 'Pumps']
total_assets = 0
for s in asset_sheets:
    items = sheet_dicts(a_wb, s)
    total_assets += len(items)
    print(f"  {s}: {len(items)}")
    for it in items:
        pe = it.get('parentEquipment')
        status = str(it.get('status', '')).lower()
        if status == 'active':
            if not pe or pe not in me_ids:
                errors.append(f"Asset {it['tagNo']} in {s} has invalid parentEquipment: {pe}")
        app_parents = it.get('applicableParentEquipmentIds')
        if app_parents:
            for p in str(app_parents).split(','):
                p_clean = p.strip()
                if p_clean and p_clean not in me_ids:
                    errors.append(f"Asset {it['tagNo']} has invalid applicableParentEquipment: {p_clean}")

print(f"\nTotal Assets: {total_assets}")

if errors:
    print(f"\n[FAIL] {len(errors)} errors found:")
    for e in errors:
        print("  -", e)
else:
    print("\n[SUCCESS] 100% of references and power flow links are strictly valid!")
