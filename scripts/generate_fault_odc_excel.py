import os
import shutil
import zipfile
import tempfile
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

def create_styled_sheet(ws, title, headers, data, header_fill_color="1A365D"):
    ws.title = title
    ws.views.sheetView[0].showGridLines = True

    # Styling definitions
    header_font = Font(name="Segoe UI", size=11, bold=True, color="FFFFFF")
    header_fill = PatternFill(start_color=header_fill_color, end_color=header_fill_color, fill_type="solid")
    header_align = Alignment(horizontal="center", vertical="center", wrap_text=True)

    data_font = Font(name="Segoe UI", size=10, color="1A202C")
    id_font = Font(name="Consolas", size=10, bold=True, color="0D47A1")
    data_align_left = Alignment(horizontal="left", vertical="center")
    data_align_center = Alignment(horizontal="center", vertical="center")

    thin_border = Border(
        left=Side(style="thin", color="CBD5E0"),
        right=Side(style="thin", color="CBD5E0"),
        top=Side(style="thin", color="CBD5E0"),
        bottom=Side(style="thin", color="CBD5E0")
    )
    zebra_fill = PatternFill(start_color="F7FAFC", end_color="F7FAFC", fill_type="solid")

    # Header Row
    ws.append(headers)
    ws.row_dimensions[1].height = 28

    for col_idx in range(1, len(headers) + 1):
        cell = ws.cell(row=1, column=col_idx)
        cell.font = header_font
        cell.fill = header_fill
        cell.alignment = header_align
        cell.border = thin_border

    # Data Rows
    for row_idx, row_values in enumerate(data, start=2):
        ws.append(row_values)
        ws.row_dimensions[row_idx].height = 22
        is_even = (row_idx % 2 == 0)

        for col_idx in range(1, len(headers) + 1):
            cell = ws.cell(row=row_idx, column=col_idx)
            cell.border = thin_border
            if is_even:
                cell.fill = zebra_fill

            if col_idx == 1: # ID column
                cell.font = id_font
                cell.alignment = data_align_center
            elif col_idx in [3, 4]: # category or type
                cell.font = data_font
                cell.alignment = data_align_center
            else:
                cell.font = data_font
                cell.alignment = data_align_left

    # Column Auto-Width
    for col in ws.columns:
        max_len = 0
        col_letter = get_column_letter(col[0].column)
        for cell in col:
            val_str = str(cell.value or "")
            if len(val_str) > max_len:
                max_len = len(val_str)
        ws.column_dimensions[col_letter].width = max(max_len + 4, 14)


# Comprehensive Steel Plant & Pig Iron Manufacturing Fault Catalog
FAULT_TYPES_HEADERS = ["id", "name", "category", "equipmentType"]

FAULT_TYPES_DATA = [
    # --- ELECTRICAL: MOTORS, DRIVES, FEEDERS & SWITCHGEAR ---
    ["FT-EL-001", "Motor Overload Relay Tripped (Thermal / Electronic)", "Electrical", "Motor"],
    ["FT-EL-002", "Single Phasing / Phase Unbalance Trip", "Electrical", "Motor"],
    ["FT-EL-003", "Stator Winding Earth Fault / Megger Value Low (<1 MΩ)", "Electrical", "Motor"],
    ["FT-EL-004", "Rotor Bar Breakage / High Slip / Current Oscillation", "Electrical", "Motor"],
    ["FT-EL-005", "Stator Inter-turn Short Circuit / Phase Smoke", "Electrical", "Motor"],
    ["FT-EL-006", "Terminal Box Sparking / Loose Lug Connection Hotspot", "Electrical", "Motor"],
    ["FT-EL-007", "Motor Space Heater Open Circuit / Internal Condensation", "Electrical", "Motor"],
    ["FT-EL-008", "Bearing Fluting / Shaft Voltage Induced Electrical Pitting", "Electrical", "Motor"],
    ["FT-EL-009", "VFD DC Bus Over-Voltage on Deceleration / Braking", "Electrical", "VFD"],
    ["FT-EL-010", "VFD Inverter IGBT Power Module Failure / Short", "Electrical", "VFD"],
    ["FT-EL-011", "VFD Cooling Fan Failure / Heat Sink Over-Temperature", "Electrical", "VFD"],
    ["FT-EL-012", "Slip Ring Carbon Brush Sparking / Pigtail Disconnection", "Electrical", "Motor"],
    ["FT-EL-013", "Liquid Resistance Starter (LRS) Electrolyte Level Low", "Electrical", "Motor"],
    ["FT-EL-014", "Air Circuit Breaker (ACB) Under-Voltage Release Trip", "Electrical", "Feeder"],
    ["FT-EL-015", "Vacuum Circuit Breaker (VCB) Vacuum Loss / Interrupter Alarm", "Electrical", "Feeder"],
    ["FT-EL-016", "Breaker Spring Charging Motor Failure / Limit Switch Not Cutoff", "Electrical", "Feeder"],
    ["FT-EL-017", "Feeder Instantaneous Over-Current (50) Protection Trip", "Electrical", "Feeder"],
    ["FT-EL-018", "Feeder Restricted Earth Fault / Sensitive Earth Fault (51N)", "Electrical", "Feeder"],
    ["FT-EL-019", "MCC Contactor Coil Burnout / Contact Chattering & Pitting", "Electrical", "Panel / Switchboard"],
    ["FT-EL-020", "Busbar Fish-Plate Joint Thermal Hotspot (>90°C)", "Electrical", "Panel / Switchboard"],
    ["FT-EL-021", "APFC Capacitor Bank Burst / Blown HRC Backup Fuse", "Electrical", "Panel / Switchboard"],
    ["FT-EL-022", "110V DC Control Power Failure / Battery Bank Float Ground Fault", "Electrical", "Panel / Switchboard"],
    ["FT-EL-023", "Distribution Transformer Buchholz Relay Gas Accumulation Alarm", "Electrical", "Transformer"],
    ["FT-EL-024", "Transformer Winding Over-Temperature (WTI) Trip (>105°C)", "Electrical", "Transformer"],
    ["FT-EL-025", "Transformer Oil Over-Temperature (OTI) Trip (>90°C)", "Electrical", "Transformer"],
    ["FT-EL-026", "Transformer Pressure Relief Valve (PRV) Diaphragm Burst", "Electrical", "Transformer"],
    ["FT-EL-027", "Transformer Silica Gel Pink Saturated / Breather Oil Cup Choked", "Electrical", "Transformer"],
    ["FT-EL-028", "Transformer HT / LT Bushing Flashover / Oil Seepage", "Electrical", "Transformer"],

    # --- MECHANICAL: PUMPS, STIRRERS, BLOWERS, COMPRESSORS & DRYERS ---
    ["FT-MC-001", "Slag Pump Impeller Slurry Erosion / Shell Punctured", "Mechanical", "Pump"],
    ["FT-MC-002", "Pump Mechanical Seal Carbon Face Leakage / Quench Water Loss", "Mechanical", "Pump"],
    ["FT-MC-003", "Pump Gland Packing Excessive Hot Water Leakage / Shaft Sleeve Scored", "Mechanical", "Pump"],
    ["FT-MC-004", "Pump Cavitation / Air Entrapment / Delivery Pressure Fluctuation", "Mechanical", "Pump"],
    ["FT-MC-005", "Pump Drive End (DE) Bearing Seizure / Cage Broken", "Mechanical", "Pump"],
    ["FT-MC-006", "Stirrer / Agitator Paddle Blade Detachment / Shaft Wobbling", "Mechanical", "Stirrer"],
    ["FT-MC-007", "Stirrer Reduction Gearbox Oil Overheating / Tooth Spalling", "Mechanical", "Stirrer"],
    ["FT-MC-008", "Stirrer Nitrogen Purge Rotary Joint Seal Gas Leakage", "Mechanical", "Stirrer"],
    ["FT-MC-009", "ID / FD Fan Impeller Ash / Dust Dynamic Unbalance Vibration (>7.1 mm/s)", "Mechanical", "Fan / Blower"],
    ["FT-MC-010", "Fan Impeller Blade Leading Edge Slag Erosion / Pitting Holes", "Mechanical", "Fan / Blower"],
    ["FT-MC-011", "Fan Plummet Block Bearing High Temperature (>85°C)", "Mechanical", "Fan / Blower"],
    ["FT-MC-012", "Fan V-Belt Slippage / Squealing Under Acceleration", "Mechanical", "Fan / Blower"],
    ["FT-MC-013", "Fan Multiple V-Belt Set Snap / Pulley Groove Wear", "Mechanical", "Fan / Blower"],
    ["FT-MC-014", "Air Compressor Screw Air-End Bearing Seizure / Clearance Loss", "Mechanical", "Compressor"],
    ["FT-MC-015", "Screw Compressor Air-Oil Separator Element High Differential Pressure", "Mechanical", "Compressor"],
    ["FT-MC-016", "Compressor Intake Unloader Valve Stuck Open / Cannot Load", "Mechanical", "Compressor"],
    ["FT-MC-017", "Refrigerated Air Dryer Condenser Fan Motor Seized / High Dew Point", "Mechanical", "Air Dryer"],
    ["FT-MC-018", "Air Dryer Refrigerant Gas Leakage / Low Suction Pressure Trip", "Mechanical", "Air Dryer"],
    ["FT-MC-019", "Desiccant Air Dryer Auto-Drain Valve Solenoid Choked / Water Carryover", "Mechanical", "Air Dryer"],
    ["FT-MC-020", "Desiccant Activated Alumina Powdering / Exhaust Muffler Clogged", "Mechanical", "Air Dryer"],

    # --- MECHANICAL: TRUCK UNLOADER, HYDRAULICS & PNEUMATICS ---
    ["FT-MC-021", "Truck Unloader Main Hydraulic Tilting Cylinder Piston Seal Blowby", "Mechanical", "Truck Unloader"],
    ["FT-MC-022", "Truck Unloader Platform Hinge Pin Seizure / Lack of Lubrication", "Mechanical", "Truck Unloader"],
    ["FT-MC-023", "Truck Unloader Wheel Stopper Hydraulic Clamping Cylinder Leakage", "Mechanical", "Truck Unloader"],
    ["FT-MC-024", "Hydraulic Power Pack Axial Piston Pump Slipper Scuffing / No Pressure", "Mechanical", "Hydraulic Machine"],
    ["FT-MC-025", "Hydraulic Main Pressure Relief Valve Chattered / Pressure Drop", "Mechanical", "Hydraulic Machine"],
    ["FT-MC-026", "Hydraulic Oil Return Line Filter Choked / Bypass Indicator Popped", "Mechanical", "Hydraulic Machine"],
    ["FT-MC-027", "Hydraulic Water-Oil Cooler Tube Leakage / Oil Emulsification", "Mechanical", "Hydraulic Machine"],
    ["FT-MC-028", "Mud Gun / Taphole Drill Hydraulic Directional Valve Spool Jammed", "Mechanical", "Hydraulic Machine"],
    ["FT-MC-029", "Blast Furnace Tuyere Stock Pneumatic Cylinder Rod Bent / Air Leak", "Mechanical", "Pneumatic Machine"],
    ["FT-MC-030", "Pulse Jet Baghouse Pulse Solenoid Valve Diaphragm Rupture", "Mechanical", "Solenoid Valve"],
    ["FT-MC-031", "Pneumatic FRL Unit Lubricator Empty / Regulator Diaphragm Torn", "Mechanical", "Pneumatic Machine"],

    # --- MECHANICAL: CONVEYORS, IDLERS, PULLEYS & GUARDS ---
    ["FT-MC-032", "Conveyor Rubber Belt Longitudinal Tear / Rip by Foreign Metal", "Mechanical", "Conveyor"],
    ["FT-MC-033", "Conveyor Belt Cold Splice / Vulcanized Joint Separation", "Mechanical", "Conveyor"],
    ["FT-MC-034", "Conveyor Drive Pulley Ceramic / Rubber Lagging Worn Out", "Mechanical", "Conveyor"],
    ["FT-MC-035", "Conveyor Snub / Bend Pulley Bearing Seizure / Locked Shaft", "Mechanical", "Conveyor"],
    ["FT-MC-036", "Conveyor Carrying Troughing Idler Roller Jammed / Shell Cut Through", "Mechanical", "Conveyor"],
    ["FT-MC-037", "Conveyor Return Idler Rubber Ring Damaged / Belt Wandering", "Mechanical", "Conveyor"],
    ["FT-MC-038", "Conveyor Side Skirt Board Rubber Worn / Heavy Material Spillage", "Mechanical", "Conveyor"],
    ["FT-MC-039", "Conveyor Tail Pulley Guard Displaced / Safety Guard Missing", "Mechanical", "Conveyor"],
    ["FT-MC-040", "Conveyor Side Walkway Guard Handrail Damaged / Loose Anchor", "Mechanical", "Conveyor"],
    ["FT-MC-041", "Conveyor Gravity Take-Up Counterweight Guide Wire Misalignment", "Mechanical", "Conveyor"],

    # --- INSTRUMENTATION: LIMIT SWITCHES (LEVER, ROTARY CAM, DIFFERENTIAL, GRAVITY) ---
    ["FT-IN-001", "Lever Type Limit Switch Roller Arm Bent / Return Spring Snapped", "Instrumentation", "Limit Switch"],
    ["FT-IN-002", "Lever Type Limit Switch Internal Microswitch Contact Welded", "Instrumentation", "Limit Switch"],
    ["FT-IN-003", "Rotary Cam Limit Switch Drive Coupling Loose / Cam Timing Slipped", "Instrumentation", "Limit Switch"],
    ["FT-IN-004", "Rotary Cam Limit Switch Gearbox Internal Tooth Stripped", "Instrumentation", "Limit Switch"],
    ["FT-IN-005", "Differential Limit Switch Cable Tension Imbalance / Pivot Seized", "Instrumentation", "Limit Switch"],
    ["FT-IN-006", "Differential Limit Switch Microswitch Actuator Arm Dislodged", "Instrumentation", "Limit Switch"],
    ["FT-IN-007", "Counterweight / Gravity Limit Switch Weight Jammed on Guide", "Instrumentation", "Limit Switch"],
    ["FT-IN-008", "Gravity Limit Switch Wire Rope Snapped / Counterweight Dropped", "Instrumentation", "Limit Switch"],

    # --- INSTRUMENTATION: CONVEYOR SAFETY INTERLOCKS ---
    ["FT-IN-009", "Conveyor Pull Chord Switch Trip / Reset Lever Not Locking", "Instrumentation", "Conveyor Interlock"],
    ["FT-IN-010", "Conveyor Pull Chord Wire Rope Snapped / Sagging False Trip", "Instrumentation", "Conveyor Interlock"],
    ["FT-IN-011", "Conveyor Belt Sway Switch Roller Jammed / Switch Arm Broken", "Instrumentation", "Conveyor Interlock"],
    ["FT-IN-012", "Belt Sway Switch Actuated Due to Severe Belt Misalignment", "Instrumentation", "Conveyor Interlock"],
    ["FT-IN-013", "Zero Speed Switch (ZSS) Inductive Proximity Sensor Target Lost", "Instrumentation", "Conveyor Interlock"],
    ["FT-IN-014", "Zero Speed Switch Electronic Controller Fault / Tripping at Full Speed", "Instrumentation", "Conveyor Interlock"],
    ["FT-IN-015", "Chute Jam / Blockage Diaphragm Sensor False Trip by Caked Dust", "Instrumentation", "Conveyor Interlock"],
    ["FT-IN-016", "Conveyor Tail Guard Safety Interlock Limit Switch Open Circuit", "Instrumentation", "Conveyor Interlock"],

    # --- INSTRUMENTATION: SOLENOID VALVES, SENSORS & PROCESS TRANSMITTERS ---
    ["FT-IN-017", "24V DC / 110V AC Solenoid Valve Coil Burnout / Open Circuit", "Instrumentation", "Solenoid Valve"],
    ["FT-IN-018", "Pneumatic Solenoid Valve Pilot Vent Orifice Clogged with Dust", "Instrumentation", "Solenoid Valve"],
    ["FT-IN-019", "RTD Pt100 Duplex Temperature Element Open Circuit / High Resistance", "Instrumentation", "Sensor"],
    ["FT-IN-020", "Blast Furnace Taphole Thermocouple Type-K / Type-S Sheath Melted", "Instrumentation", "Sensor"],
    ["FT-IN-021", "4-20mA Current Loop Broken / Signal Wire Termination Corroded", "Instrumentation", "Sensor"],
    ["FT-IN-022", "Smart Differential Pressure (DP) Transmitter Impulse Tube Choked", "Instrumentation", "Sensor"],
    ["FT-IN-023", "Electromagnetic Water Flowmeter Electrode Scale Coating / False Zero", "Instrumentation", "Sensor"],
    ["FT-IN-024", "Radar Sump Level Transmitter Antenna Slag Cake Attenuation", "Instrumentation", "Sensor"],
    ["FT-IN-025", "Control Valve Smart Electro-Pneumatic Positioner Air Leak", "Instrumentation", "Valve"],
    ["FT-IN-026", "Piezoelectric Vibration Sensor Accelerometer Cable Torn", "Instrumentation", "Sensor"],

    # --- INSTRUMENTATION: METALLURGICAL & QUALITY LAB EQUIPMENTS ---
    ["FT-IN-027", "Optical Emission Spectrometer (OES) Argon Gas Flush Pressure Low", "Instrumentation", "LAB Equipment"],
    ["FT-IN-028", "OES Spark Stand Tungsten Electrode Contaminated / High Burn Error", "Instrumentation", "LAB Equipment"],
    ["FT-IN-029", "OES Vacuum Optics Chamber Vacuum Pump Failure / Pressure Rise", "Instrumentation", "LAB Equipment"],
    ["FT-IN-030", "Carbon & Sulphur Combustion Analyzer Induction Furnace Tube Cracked", "Instrumentation", "LAB Equipment"],
    ["FT-IN-031", "Carbon-Sulphur Analyzer Solid State IR Detector Temperature Drift", "Instrumentation", "LAB Equipment"],
    ["FT-IN-032", "Metallurgical Sample Surface Grinder / Polisher Disc Glazed", "Instrumentation", "LAB Equipment"],
    ["FT-IN-033", "Moisture Halogen Analyzer Heating Lamp Open Circuit", "Instrumentation", "LAB Equipment"],
    ["FT-IN-034", "Laboratory Bomb Calorimeter Oxygen Ignition Wire Breakage", "Instrumentation", "LAB Equipment"],

    # --- AUTOMATION & CONTROL: PLC, NETWORK & SCADA ---
    ["FT-AU-001", "PLC CPU Controller Fault / Watchdog Timeout Error", "Automation", "Panel / Switchboard"],
    ["FT-AU-002", "Remote I/O Drop Communication Loss (Profibus / Modbus TCP Disruption)", "Automation", "Panel / Switchboard"],
    ["FT-AU-003", "PLC Analog Input (AI) Card Channel Blown by External Overvoltage", "Automation", "Panel / Switchboard"],
    ["FT-AU-004", "PLC Digital Output (DO) Relay Contact Welded by High Inrush Load", "Automation", "Panel / Switchboard"],
    ["FT-AU-005", "SCADA HMI Server Communication Freeze / Screen Frozen", "Automation", "Panel / Switchboard"],
    ["FT-AU-006", "Safety Interlock Chain Open Circuit / External Permit Not Satisfied", "Automation", "Panel / Switchboard"],

    # --- OPERATIONAL & PROCESS TRIPS ---
    ["FT-OP-001", "Slag Pump Pit High Sump Level Overflow Alarm Trip", "Operational", "Pump"],
    ["FT-OP-002", "Water Cooling Booster Pump Low Suction Pressure / Cavitation Cutoff", "Operational", "Pump"],
    ["FT-OP-003", "Conveyor Discharge Transfer Chute Heavy Jamming / Raw Material Overfill", "Operational", "Conveyor"],
    ["FT-OP-004", "Field Emergency Stop (E-Stop) Push Button Actuated by Operator", "Operational", "All"],
    ["FT-OP-005", "Blast Furnace Gas Bleeder Hydraulic Damper Interlock Open", "Operational", "Blast Furnace"],
]


# Comprehensive Steel Plant & Pig Iron ODC (Object Damage Causes)
ODC_CAUSES_HEADERS = ["id", "name", "category"]

ODC_CAUSES_DATA = [
    # --- WEAR & TEAR ---
    ["ODC-WT-001", "Slag / Abrasive Iron Ore Slurry Wear on Impeller & Casing", "Wear & Tear"],
    ["ODC-WT-002", "Normal Bearing Roller & Race Fatigue Surface Spalling", "Wear & Tear"],
    ["ODC-WT-003", "Mechanical Seal Silicon Carbide / Carbon Face Frictional Wear", "Wear & Tear"],
    ["ODC-WT-004", "Flexible Coupling Polyurethane Spider / Tyre Element Hardening", "Wear & Tear"],
    ["ODC-WT-005", "Conveyor Belt Top Cover Gouging by Sharp Lump Rocks", "Wear & Tear"],
    ["ODC-WT-006", "V-Belt Rubber Ageing, Edge Cracking & Tensile Cord Fatigue", "Wear & Tear"],
    ["ODC-WT-007", "Gearbox Helical Gear Tooth Surface Micropitting & Scuffing", "Wear & Tear"],
    ["ODC-WT-008", "Switchgear Power Breaker Main Contact Silver-Tip Arc Erosion", "Wear & Tear"],
    ["ODC-WT-009", "Limit Switch Operating Roller Grooving & Cam Face Abrasion", "Wear & Tear"],

    # --- ENVIRONMENTAL & SLAG INGRESS ---
    ["ODC-EN-001", "Iron Ore Dust & Granulated Slag Powder Infiltration into Bearing Housing", "Environmental"],
    ["ODC-EN-002", "Granulation Steam & Moisture Ingress into Electrical Terminal Box", "Environmental"],
    ["ODC-EN-003", "Radiant Heat Radiation (>55°C Ambient) near Blast Furnace Runner", "Environmental"],
    ["ODC-EN-004", "Rainwater / Hose Down Washdown Water Jet Spraying into Enclosure", "Environmental"],
    ["ODC-EN-005", "Acidic Fumes / SO2 Atmospheric Corrosion on Metallic Contacts", "Environmental"],
    ["ODC-EN-006", "Cast House Dust Layer Accumulation on Motor Cooling Fins Causing Choke", "Environmental"],
    ["ODC-EN-007", "Rodent / Lizard Ingress Causing Phase-to-Phase Busbar Arc Fault", "Environmental"],

    # --- LUBRICATION & HYDRAULIC DEFECTS ---
    ["ODC-LB-001", "Complete Lubricant Starvation / Dry Running Bearing", "Lubrication"],
    ["ODC-LB-002", "Excessive Over-Greasing Leading to Thermal Expansion Choke", "Lubrication"],
    ["ODC-LB-003", "Incorrect Grease Specification (Non-EP or Low Drop Point Used)", "Lubrication"],
    ["ODC-LB-004", "Water Contamination Causing Grease Emulsification & Oil Separation", "Lubrication"],
    ["ODC-LB-005", "Hydraulic Oil Particulate Contamination Exceeding NAS Class 9", "Hydraulics"],
    ["ODC-LB-006", "Hydraulic Oil Thermal Oxidation / Varnish Formation on Valve Spools", "Hydraulics"],
    ["ODC-LB-007", "Air Ingress into Hydraulic Pump Suction Causing Foaming & Cavitation", "Hydraulics"],
    ["ODC-LB-008", "Compressor Synthetic Oil Carryover Due to Saturated Separator", "Lubrication"],

    # --- ELECTRICAL STRESS & TERMINAL DEFECTS ---
    ["ODC-ES-001", "Loose Cable Lug Screw / Bolt Joint Vibration Hotspot", "Electrical Stress"],
    ["ODC-ES-002", "Severe Supply Grid Voltage Dip / Transients During Heavy Arc Melting", "Electrical Stress"],
    ["ODC-ES-003", "Harmonic Current Overheating on Transformer Secondary & Neutrals", "Electrical Stress"],
    ["ODC-ES-004", "Supply Voltage Unbalance (>2.5%) Inducing Excessive Rotor Eddy Currents", "Electrical Stress"],
    ["ODC-ES-005", "Frequent Motor Inrush Starts Without Adequate Thermal Cooling Interval", "Electrical Stress"],
    ["ODC-ES-006", "Solenoid Valve Surge Suppressor Diode Failure Causing Coil Overheat", "Electrical Stress"],

    # --- MECHANICAL & ASSEMBLY MISALIGNMENT ---
    ["ODC-MC-001", "Angular & Radial Shaft Misalignment Between Motor and Machine", "Mechanical & Assembly"],
    ["ODC-MC-002", "Rotor Dynamic Unbalance Following Material Deposition on Impeller", "Mechanical & Assembly"],
    ["ODC-MC-003", "External Piping Strain Transferring Excessive Thrust to Pump Casing", "Mechanical & Assembly"],
    ["ODC-MC-004", "Civil Foundation Concrete Grout Breakdown / Soft Foot Condition", "Mechanical & Assembly"],
    ["ODC-MC-005", "Loose Machine Holding-Down Anchor Bolts Under Reciprocating Vibration", "Mechanical & Assembly"],
    ["ODC-MC-006", "Incorrect Bearing Fitment (Heavy Sledgehammer Impact on Inner Race)", "Mechanical & Assembly"],
    ["ODC-MC-007", "Rotary Cam Limit Switch Shaft Set Screw Loosened Under Machine Vibration", "Mechanical & Assembly"],
    ["ODC-MC-008", "Conveyor Belt Sway Switch Lever Roller Set at Incorrect Offset Angle", "Mechanical & Assembly"],

    # --- OPERATIONAL & HUMAN FACTORS ---
    ["ODC-OP-001", "Pump Run Against Closed Discharge Valve Causing Thermal Cavitation", "Operational & Human"],
    ["ODC-OP-002", "Oversized Tramp Iron / Foreign Steel Scrap Jamming Material Chute", "Operational & Human"],
    ["ODC-OP-003", "Truck Unloader Tilting Rate Set Exceeding Truck Gross Weight Limit", "Operational & Human"],
    ["ODC-OP-004", "Conveyor Chute Overfilling Due to Upstream Feed Rate Surge", "Operational & Human"],
    ["ODC-OP-005", "Operator Bypassed Safety Interlock Limit Switch Wire at J-Box", "Operational & Human"],
    ["ODC-OP-006", "Failure to Replenish Lubrication Reservoir During Planned PM Shift", "Operational & Human"],
]


def post_process_rels(file_path):
    """Strip leading slash from Target paths in workbook.xml.rels for package:excel compatibility"""
    temp_fd, temp_path = tempfile.mkstemp(suffix=".xlsx")
    os.close(temp_fd)

    with zipfile.ZipFile(file_path, 'r') as zin:
        with zipfile.ZipFile(temp_path, 'w', compression=zipfile.ZIP_DEFLATED) as zout:
            for item in zin.infolist():
                data = zin.read(item.filename)
                if item.filename == 'xl/_rels/workbook.xml.rels':
                    data = data.replace(b'Target="/xl/', b'Target="')
                zout.writestr(item, data)

    shutil.move(temp_path, file_path)


def main():
    out_dir = r"d:\AssetPulse-Pro\Excel Import"
    root_dir = r"d:\AssetPulse-Pro"
    os.makedirs(out_dir, exist_ok=True)

    # 1. Fault Types Master File
    wb_ft = openpyxl.Workbook()
    ws_ft = wb_ft.active
    create_styled_sheet(ws_ft, "Fault_Types", FAULT_TYPES_HEADERS, FAULT_TYPES_DATA, header_fill_color="1A365D")
    ft_path = os.path.join(out_dir, "Fault_Types_Master.xlsx")
    wb_ft.save(ft_path)
    post_process_rels(ft_path)
    shutil.copy2(ft_path, os.path.join(root_dir, "Fault_Types_Master.xlsx"))
    print(f"Created: {ft_path} ({len(FAULT_TYPES_DATA)} records)")

    # 2. ODC Causes Master File
    wb_odc = openpyxl.Workbook()
    ws_odc = wb_odc.active
    create_styled_sheet(ws_odc, "ODC_Causes", ODC_CAUSES_HEADERS, ODC_CAUSES_DATA, header_fill_color="2D3748")
    odc_path = os.path.join(out_dir, "ODC_Causes_Master.xlsx")
    wb_odc.save(odc_path)
    post_process_rels(odc_path)
    shutil.copy2(odc_path, os.path.join(root_dir, "ODC_Causes_Master.xlsx"))
    print(f"Created: {odc_path} ({len(ODC_CAUSES_DATA)} records)")

    # 3. Combined Fault Types and ODC Master File
    wb_combined = openpyxl.Workbook()
    ws_c_ft = wb_combined.active
    create_styled_sheet(ws_c_ft, "Fault_Types", FAULT_TYPES_HEADERS, FAULT_TYPES_DATA, header_fill_color="1A365D")
    ws_c_odc = wb_combined.create_sheet(title="ODC_Causes")
    create_styled_sheet(ws_c_odc, "ODC_Causes", ODC_CAUSES_HEADERS, ODC_CAUSES_DATA, header_fill_color="2D3748")
    combined_path = os.path.join(out_dir, "Fault_Types_and_ODC_Master.xlsx")
    wb_combined.save(combined_path)
    post_process_rels(combined_path)
    shutil.copy2(combined_path, os.path.join(root_dir, "Fault_Types_and_ODC_Master.xlsx"))
    print(f"Created: {combined_path} (Both sheets)")


if __name__ == "__main__":
    main()
