import openpyxl
from openpyxl.worksheet.table import Table, TableStyleInfo
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation

def create_massive_odc_catalog(filepath):
    wb = openpyxl.Workbook()
    
    # ----------------------------------------------------
    # Sheet 1: Master ODC Table
    # ----------------------------------------------------
    ws = wb.active
    ws.title = "ODC_Master"
    ws.views.sheetView[0].showGridLines = True
    
    headers = [
        "ODC_ID",
        "Discipline",
        "Equipment_Category",
        "Object_Part",
        "Damage_Mode",
        "Root_Cause",
        "ISO_14224_Code",
        "Severity",
        "Recommended_Action",
        "Plant_ID",
        "Unit_ID"
    ]
    ws.append(headers)
    
    # Comprehensive ODC items covering all requested components:
    # Contactors, Brakes, VFDs, Soft Starters, Starters (DOL/Star-Delta/ATS), Breakers, Motors, Transformers, Pumps, Gearboxes, Valves, Cables, Instruments, Hydraulics
    odc_items = [
        # --- CONTACTORS (Power & Auxiliary) ---
        ("ODC-CON-01", "Electrical", "Contactor", "Main Power Contacts / Tips", "Contacts Welded / Fused Together", "High Inrush Current / Mechanical Jam in Load", "E-3.1", "Critical", "Replace contactor power pole kit; inspect motor load for locked rotor"),
        ("ODC-CON-02", "Electrical", "Contactor", "Main Power Contacts / Tips", "Severe Contact Pitting & Erosion", "Frequent Inching / Jogging Duty Cycle", "E-3.2", "High", "Replace contact tips; review operator inching practice; check arc chute"),
        ("ODC-CON-03", "Electrical", "Contactor", "Operating Solenoid Coil", "Coil Burnt / Open Circuit", "Sustained Control Overvoltage (>115% Vn)", "E-3.3", "Critical", "Replace 240VAC/110VDC coil; measure control transformer tap voltage"),
        ("ODC-CON-04", "Electrical", "Contactor", "Operating Solenoid Coil", "Continuous Loud Hum / Chattering", "Shading Ring Broken / Pole Face Rust", "E-3.4", "High", "Replace magnet core assembly or contactor; clean pole face with solvent"),
        ("ODC-CON-05", "Electrical", "Contactor", "Auxiliary Contact Block (NO/NC)", "Intermittent Contact / High Resistance", "Fine Abrasive Dust Ingress / Contact Oxidation", "E-3.5", "Medium", "Replace auxiliary snap-on block; spray contact cleaner; seal panel gasket"),
        ("ODC-CON-06", "Electrical", "Contactor", "Arc Chute Splitter Plates", "Burnt / Carbonized Plastic Enclosure", "Breaking Heavy Motor Stall Current", "E-3.6", "High", "Replace arc chute assembly; inspect thermal overload relay trip curve"),

        # --- INDUSTRIAL BRAKES (Thruster, Disc, Shoe) ---
        ("ODC-BRK-01", "Mechanical", "Industrial Brake", "Brake Shoe Friction Lining", "Lining Worn Out to Rivet Level", "Normal Friction Wear / High Braking Frequency", "M-3.1", "Critical", "Replace woven non-asbestos friction lining; adjust brake shoe clearance"),
        ("ODC-BRK-02", "Mechanical", "Industrial Brake", "Electro-Hydraulic Thruster", "Thruster Motor Fails to Lift Brake", "Thruster Hydraulic Oil Leakage / Low Oil", "M-3.2", "Critical", "Top up transformer oil in thruster; replace shaft seal; check motor winding"),
        ("ODC-BRK-03", "Mechanical", "Industrial Brake", "Brake Drum / Brake Disc", "Thermal Heat Cracks / Scoring Grooves", "Excessive Dragging / Over-tight Brake Gap", "M-3.3", "High", "Skim brake disc or replace drum; adjust equal shoe lift gap to 0.8 mm"),
        ("ODC-BRK-04", "Mechanical", "Industrial Brake", "Main Compression Torque Spring", "Spring Fatigue / Broken Coil", "Cyclic Dynamic Fatigue over Life Expiry", "M-3.4", "Critical", "Replace calibrated torque spring; measure braking torque with torque wrench"),
        ("ODC-BRK-05", "Electrical", "Industrial Brake", "Electromagnetic Brake Release Coil", "Coil Overheated & Shorted", "Rectifier Unit DC Voltage Ripple / Surge", "E-3.7", "High", "Replace 24VDC/190VDC brake coil; replace fast-excitation brake rectifier"),

        # --- VARIABLE FREQUENCY DRIVES (VFD) ---
        ("ODC-VFD-01", "Electrical", "Variable Frequency Drive (VFD)", "IGBT Power Inverter Module", "IGBT Collector-Emitter Short Circuit", "Output Phase-to-Ground Flash / High dV/dt", "E-7.1", "Critical", "Replace IGBT bridge; megger motor and power cable; install dV/dt choke filter"),
        ("ODC-VFD-02", "Electrical", "Variable Frequency Drive (VFD)", "DC Bus Smoothing Capacitors", "Capacitor Bulging / Electrolyte Leak", "Ambient High Temperature & High Harmonic Ripple", "E-7.2", "High", "Replace DC bus capacitor bank; check cabinet air conditioning & ventilation"),
        ("ODC-VFD-03", "Electrical", "Variable Frequency Drive (VFD)", "Cabinet Forced Cooling Fan", "Fan Seized / Bearing Rattle", "Fugitive Dust Caking on Fan Impeller", "E-7.3", "High", "Replace high-reliability 24VDC cooling fan; clean dust filter pads"),
        ("ODC-VFD-04", "Electrical", "Variable Frequency Drive (VFD)", "Gate Driver PCB Card", "Blown Optocoupler / Gate Resistor", "Flashover from Blown IGBT Power Module", "E-7.4", "Critical", "Replace gate driver card; check optical firing cable connections"),
        ("ODC-VFD-05", "Electrical", "Variable Frequency Drive (VFD)", "Dynamic Braking Chopper & Resistor", "Braking Resistor Overheated / Open", "Excessive Overhauling Load / Decel Ramp Too Fast", "E-7.5", "High", "Increase deceleration time; replace burnt ceramic resistor; verify chopper"),

        # --- SOFT STARTERS ---
        ("ODC-SFT-01", "Electrical", "Soft Starter", "Thyristor (SCR) Power Stack", "SCR Punctured / Forward Breakover Short", "Mains Transient Voltage Spike / Lightning Surge", "E-8.1", "Critical", "Replace paired antiparallel SCR module; check MOV surge suppressor"),
        ("ODC-SFT-02", "Electrical", "Soft Starter", "Internal Bypass Contactor", "Bypass Contactor Stuck / Fails to Close", "Auxiliary Control Relay Driver Failure on PCB", "E-8.2", "High", "Replace bypass contactor unit; check full-speed run transition signal"),
        ("ODC-SFT-03", "Electrical", "Soft Starter", "Control & Triggering PCB Card", "Loss of Firing Pulses / Phase Imbalance", "Control Power Supply DC Ripple / EMC Noise", "E-8.3", "Critical", "Replace control processor card; ensure proper shielded cable grounding"),
        ("ODC-SFT-04", "Electrical", "Soft Starter", "Heatsink Thermal Sensor (PTC)", "Overtemperature Trip at Normal Load", "Thermal Compound Dried Out / Cooling Duct Blocked", "E-8.4", "Medium", "Clean aluminum heatsink fins; reapply Dow Corning 340 thermal paste"),

        # --- STARTER PANELS (DOL, Star-Delta, Auto-Transformer) ---
        ("ODC-STR-01", "Electrical", "Starter Panel (DOL/Star-Delta)", "Star-to-Delta Transition Timer", "Timer Stuck in Star / No Transition", "Timer Pneumatic Diaphragm / Electronic Circuit Fault", "E-9.1", "High", "Replace 24-240V electronic star-delta timer; set transition time to 8-10s"),
        ("ODC-STR-02", "Electrical", "Starter Panel (DOL/Star-Delta)", "Star Contactor", "Contacts Welded on Transition", "Inrush Surge due to Premature Delta Closing", "E-9.2", "Critical", "Increase Star-to-Delta dwell time to 50ms; replace star contactor"),
        ("ODC-STR-03", "Electrical", "Starter Panel (DOL/Star-Delta)", "Thermal Bimetallic Overload Relay", "False Tripping at Nominal Full Load", "High Ambient Switchroom Temp / Loose Stud", "E-9.3", "High", "Calibrate relay with secondary injection kit; retorque bi-metal terminal lugs"),
        ("ODC-STR-04", "Electrical", "Starter Panel (DOL/Star-Delta)", "Auto-Transformer Unit (ATS Starter)", "Transformer Tap Overheated / Smoke", "Frequent Consecutive Starts Exceeding Rating", "E-9.4", "Critical", "Allow cooling; check 65%/80% tap terminal connections; enforce start interval"),
        ("ODC-STR-05", "Electrical", "Starter Panel (DOL/Star-Delta)", "Motor Protection Circuit Breaker (MPCB)", "MPCB Fails to Reset / Mechanism Trip", "Internal Bi-metal Latch Mechanism Worn Out", "E-9.5", "High", "Replace MPCB; verify short-circuit trip dial matches motor rating"),

        # --- CIRCUIT BREAKERS (VCB, ACB, MCCB) ---
        ("ODC-BRK-06", "Electrical", "Circuit Breaker (VCB/ACB)", "Vacuum Interrupter Bottle (VCB)", "Loss of Vacuum / Contact Arcing", "Bellows Micro-Leak after Electrical Life Expiry", "E-5.1", "Critical", "Perform 24kV AC high-pot vacuum integrity test; replace vacuum bottle"),
        ("ODC-BRK-07", "Electrical", "Circuit Breaker (VCB/ACB)", "Shunt Trip Coil", "Trip Coil Open Circuit / Burnt", "Auxiliary 52a Switch Stuck in Closed Position", "E-5.2", "Critical", "Replace 110VDC trip coil; replace auxiliary contact block assembly"),
        ("ODC-BRK-08", "Electrical", "Circuit Breaker (VCB/ACB)", "Spring Charging Motor Unit", "Motor Fails to Charge Spring", "Brushes Worn Out / Plastic Gearbox Stripped", "M-5.1", "High", "Replace DC charging motor; lubricate spring cam linkage with Kluber grease"),
        ("ODC-BRK-09", "Electrical", "Circuit Breaker (VCB/ACB)", "Busbar Tulip Jaw Contact (ACB/VCB)", "Severe Arcing / Silver Plating Burnt", "Misaligned Cradle Racking / Weak Finger Springs", "E-5.3", "Critical", "Replace racking cradle tulip cluster; apply contact grease; align busbar"),
        ("ODC-BRK-10", "Electrical", "Circuit Breaker (VCB/ACB)", "Microprocessor Trip Unit (ETU / OCR)", "Trip Unit Display Blank / No Protection", "Internal Control Power Transformer (PT) Blown", "E-5.5", "Critical", "Replace electronic trip unit; calibrate protection curves (LSI)"),

        # --- ELECTRIC MOTORS ---
        ("ODC-MOT-01", "Electrical", "Electric Motor", "Drive-End (DE) Bearing", "High Vibration & Rattling Noise", "Lack of Lubrication / Under-greasing", "M-1.1", "High", "Purge old grease, refill with Mobilgrease 28 to OEM spec, check vibration"),
        ("ODC-MOT-02", "Electrical", "Electric Motor", "Drive-End (DE) Bearing", "Overheating (>90°C)", "Over-Greasing / High Churning Friction", "M-1.2", "High", "Remove grease drain plug, run motor 30 mins to expel excess grease"),
        ("ODC-MOT-03", "Electrical", "Electric Motor", "Drive-End (DE) Bearing", "Bearing Seizure / Locked Rotor", "Spalling / Flaking Fatigue Due to Dynamic Misalignment", "M-1.3", "Critical", "Replace DE bearing (SKF/FAG), align shaft using laser alignment to <0.05mm"),
        ("ODC-MOT-04", "Electrical", "Electric Motor", "Stator Winding", "Burnt Winding / Insulation Breakdown", "Single Phasing / Supply Phase Loss", "E-2.1", "Critical", "Send for rewinding with Class H insulation; inspect upstream breaker & contactor"),
        ("ODC-MOT-05", "Electrical", "Electric Motor", "Stator Winding", "Earth Fault / Low IR (<1 MΩ)", "Moisture / Condensation Ingress", "E-2.2", "High", "Bake winding with halogen heater, apply anti-tracking varnish, check space heater"),
        ("ODC-MOT-06", "Electrical", "Electric Motor", "Terminal Box & Studs", "Flashover / Burnt Power Terminal", "Loose Cable Lug Termination / High Contact Resistance", "E-3.1", "Critical", "Cut burnt cable end, crimp bimetallic heavy-duty lugs, torque studs with torque wrench"),

        # --- POWER TRANSFORMERS ---
        ("ODC-TRF-01", "Electrical", "Power Transformer", "HV Bushing (11kV / 33kV)", "Hairline Crack / Tracking Flashover", "Surface Pollution / High Humidity Flashover", "E-4.1", "Critical", "De-energize, clean and dry bushing, replace cracked bushing, retest tan-delta"),
        ("ODC-TRF-02", "Electrical", "Power Transformer", "Transformer Mineral Oil", "Low Dielectric BDV (<30 kV)", "Moisture Absorption & Sludge Degradation", "E-4.3", "High", "Perform on-site vacuum oil filtration / dehydration until BDV > 60 kV"),
        ("ODC-TRF-03", "Electrical", "Power Transformer", "Buchholz Relay", "Gas Collection / Alarm Trip", "Internal Incipient Arcing / Hotspot Pyrolysis", "E-4.4", "Critical", "Collect gas sample for DGA (Dissolved Gas Analysis) to identify fault nature"),
        ("ODC-TRF-04", "Electrical", "Power Transformer", "Silica Gel Breather", "Silica Gel Pink (100% Saturated)", "Oil Cup Seal Empty / Atmospheric Moisture Leak", "M-4.1", "Medium", "Replace pink silica gel with fresh blue/orange beads, top up oil sealing cup"),
        ("ODC-TRF-05", "Electrical", "Power Transformer", "On-Load Tap Changer (OLTC)", "Tap Changer Stuck Between Steps", "Drive Motor Mechanism / Limit Switch Failure", "E-4.5", "High", "Manual hand-crank to safe tap step; overhaul OLTC gearbox and contact fingers"),

        # --- PUMPS (Centrifugal / Slurry) ---
        ("ODC-PMP-01", "Mechanical", "Centrifugal Pump", "Pump Impeller", "Vane Cavitation Pitting & Erosion", "Inadequate NPSH Available / Starved Suction", "M-6.1", "High", "Replace impeller (High Chrome); clean suction strainer; raise suction head"),
        ("ODC-PMP-02", "Mechanical", "Centrifugal Pump", "Mechanical Seal", "Continuous Slurry / Water Leakage", "Silicon Carbide Face Scored by Abrasive Fines", "M-6.2", "High", "Replace mechanical seal cartridge; flush quench seal water line"),
        ("ODC-PMP-03", "Mechanical", "Centrifugal Pump", "Shaft Sleeve", "Deep Grooving under Gland Packing", "Over-Tightened PTFE Packing without Leakage Droplets", "M-6.3", "Medium", "Replace ceramic-coated sleeve; repack with graphite packing rings"),
        ("ODC-PMP-04", "Mechanical", "Centrifugal Pump", "Pump Casing / Volute", "Severe Wall Thinning (<3mm residual)", "Erosive Slurry Velocity / Acidic Corrosion", "M-6.4", "Critical", "Perform ultrasonic thickness gauging (UTG); replace casing or coat with ceramic epoxy"),

        # --- INDUSTRIAL GEARBOXES ---
        ("ODC-GBX-01", "Mechanical", "Industrial Gearbox", "Input Pinion Gear", "Surface Pitting / Micropitting on Tooth Face", "Low Oil Viscosity / Degraded EP Additive", "M-7.1", "High", "Drain oil, flush housing, refill with ISO VG 320 synthetic gear oil; inspect mesh"),
        ("ODC-GBX-02", "Mechanical", "Industrial Gearbox", "Output Bull Gear", "Broken Tooth / Chipped Tip", "Heavy Shock Load / Crusher Feed Jam", "M-7.2", "Critical", "Replace matched gearset; inspect crusher toggle plate shear safety mechanism"),
        ("ODC-GBX-03", "Mechanical", "Industrial Gearbox", "Input / Output Oil Seal", "Heavy Oil Leakage around Shaft", "Viton Lip Seal Hardened by High Temperature", "M-7.3", "Medium", "Replace Viton double-lip oil seal; polish shaft seal running track"),

        # --- BELT CONVEYORS ---
        ("ODC-CNV-01", "Mechanical", "Belt Conveyor", "Conveyor Rubber Belt", "Longitudinal Belt Rip / Slit", "Sharp Tramp Iron / Steel Chute Liner Piercing Belt", "M-8.1", "Critical", "Emergency cold vulcanizing repair patch; inspect overband tramp magnet"),
        ("ODC-CNV-02", "Mechanical", "Belt Conveyor", "Idler Roller", "Roller Seized / Shell Cut Through", "Internal Bearing Seizure from Fine Material Ingress", "M-8.2", "High", "Replace seized idler roller immediately to prevent belt underside wear"),
        ("ODC-CNV-03", "Mechanical", "Belt Conveyor", "Drive Head Pulley", "Ceramic Lagging Debonded / Worn", "Severe Belt Slip under Wet Starting Conditions", "M-8.3", "High", "Re-lag drive pulley with cold-bonded ceramic diamond lagging"),

        # --- INSTRUMENTATION & CONTROL VALVES ---
        ("ODC-INS-01", "Instrumentation", "Field Transmitter", "Differential Pressure Transmitter", "Zero Shift / Unstable Reading", "Impulse Sensing Line Clogged with Slurry", "I-1.1", "Medium", "Blow down / purge impulse line with compressed air/water; recalibrate zero"),
        ("ODC-INS-02", "Instrumentation", "Temperature Sensor", "RTD Pt100 Sensor", "Open Loop / Showing 850°C Max", "Lead Wire Snapped Due to Heavy Machine Vibration", "I-1.2", "High", "Replace 3-wire mineral insulated RTD probe; damp conduit flex cable"),
        ("ODC-INS-03", "Instrumentation", "Control Valve", "Smart Valve Positioner", "Valve Hunting / Fails to Reach 100% Stroke", "Instrument Air Filter Regulator Contaminated", "I-2.1", "High", "Drain water from air filter regulator; clean positioner nozzle-flapper; autotune"),
        ("ODC-INS-04", "Instrumentation", "Control Valve", "Pneumatic Diaphragm Actuator", "Air Leaking from Actuator Bonnet", "Neoprene Diaphragm Ruptured / Ageing", "I-2.2", "Critical", "Replace fabric-reinforced rolling diaphragm kit; leak-test with soapy water"),
        ("ODC-INS-05", "Instrumentation", "Control Valve", "Solenoid Valve (SOV)", "SOV Fails to De-energize / Exhaust", "Core Plunger Stuck with Desiccant Dust", "I-2.3", "High", "Clean 3/2-way SOV valve core; replace plunger seal; inspect air dryer"),
        ("ODC-AUT-01", "Automation", "PLC & SCADA", "PLC Digital Input Card (24VDC)", "Channel Blown / LED Off during Sensor Signal", "Field 24VDC Short Circuit / Ground Surge", "I-3.1", "Critical", "Replace 16-channel DI module; verify field isolator barrier & fuse status")
    ]
    
    for row in odc_items:
        ws.append((*row, "GLOBAL", "GLOBAL"))
        
    # Create Excel Table
    tab_odc = Table(displayName="Table_ODC", ref=f"A1:K{len(odc_items)+1}")
    style = TableStyleInfo(name="TableStyleMedium9", showFirstColumn=False, showLastColumn=False, showRowStripes=True, showColumnStripes=False)
    tab_odc.tableStyleInfo = style
    ws.add_table(tab_odc)
    
    # Auto-adjust column widths
    for col in ws.columns:
        max_len = max(len(str(cell.value or '')) for cell in col)
        col_letter = get_column_letter(col[0].column)
        ws.column_dimensions[col_letter].width = min(max(max_len + 3, 14), 45)
    ws.row_dimensions[1].height = 26
    
    # ----------------------------------------------------
    # Sheet 2: Validation Reference Lists (Dropdown lookup tables)
    # ----------------------------------------------------
    ws_ref = wb.create_sheet(title="Lookup_Lists")
    ws_ref.views.sheetView[0].showGridLines = True
    
    disciplines = ["Electrical", "Mechanical", "Instrumentation", "Automation", "Operational"]
    severities = ["Critical", "High", "Medium", "Low"]
    equip_categories = [
        "Contactor", "Industrial Brake", "Variable Frequency Drive (VFD)", "Soft Starter",
        "Starter Panel (DOL/Star-Delta)", "Circuit Breaker (VCB/ACB)", "Electric Motor",
        "Power Transformer", "Centrifugal Pump", "Industrial Gearbox", "Belt Conveyor",
        "Field Transmitter", "Temperature Sensor", "Control Valve", "PLC & SCADA",
        "Overhead Crane", "Hydraulic Power Pack", "Compressor", "Vibrating Screen"
    ]
    
    ws_ref.append(["Disciplines", "Severities", "Equipment_Categories"])
    for r in range(len(disciplines)):
        ws_ref.cell(row=r + 2, column=1, value=disciplines[r])
    for r in range(len(severities)):
        ws_ref.cell(row=r + 2, column=2, value=severities[r])
    for r in range(len(equip_categories)):
        ws_ref.cell(row=r + 2, column=3, value=equip_categories[r])
    
    for col in ws_ref.columns:
        max_len = max(len(str(cell.value or '')) for cell in col)
        col_letter = get_column_letter(col[0].column)
        ws_ref.column_dimensions[col_letter].width = max(max_len + 4, 18)

    # Add Data Validations on Sheet 1 using direct range references
    dv_disc = DataValidation(type="list", formula1=f"Lookup_Lists!$A$2:$A${len(disciplines)+1}", allow_blank=True)
    ws.add_data_validation(dv_disc)
    dv_disc.add(f"B2:B{len(odc_items)+500}")

    dv_sev = DataValidation(type="list", formula1=f"Lookup_Lists!$B$2:$B${len(severities)+1}", allow_blank=True)
    ws.add_data_validation(dv_sev)
    dv_sev.add(f"H2:H{len(odc_items)+500}")

    dv_eq = DataValidation(type="list", formula1=f"Lookup_Lists!$C$2:$C${len(equip_categories)+1}", allow_blank=True)
    ws.add_data_validation(dv_eq)
    dv_eq.add(f"C2:C{len(odc_items)+500}")

    wb.save(filepath)
    print(f"Successfully generated Master ODC Catalog at: {filepath}")

def create_massive_fault_types_catalog(filepath):
    wb = openpyxl.Workbook()
    
    ws = wb.active
    ws.title = "Fault_Types_Master"
    ws.views.sheetView[0].showGridLines = True
    
    headers = [
        "Fault_Code",
        "Fault_Name",
        "Discipline",
        "Target_Equipment",
        "Default_Severity",
        "Target_SLA_Hours",
        "Diagnostic_Checks",
        "Corrective_Action",
        "Plant_ID",
        "Unit_ID"
    ]
    ws.append(headers)
    
    fault_items = [
        # Contactors & Starters
        ("FT-CON-01", "Contactor Welded / Pitted Contacts", "Electrical", "Contactors, Motor Feeders", "Critical", 1, "Measure contact continuity across poles; inspect for contact silver puddle", "Replace contact pole kit / contactor unit; check motor full-load amperes"),
        ("FT-CON-02", "Contactor Solenoid Coil Open / Burnt", "Electrical", "Contactors, Starters", "Critical", 1, "Multimeter coil resistance (infinite ohms = burnt coil); check coil voltage", "Replace operating coil; verify 110V/230V control circuit fuse"),
        ("FT-CON-03", "Contactor Severe Magnet Core Chattering", "Electrical", "Contactors", "High", 2, "Check AC coil voltage drop during inrush; inspect pole face shading ring", "Clean pole face; replace contactor if shading ring is fractured"),
        
        # Brakes
        ("FT-BRK-01", "Brake Thruster Fails to Lift / Motor Tripped", "Mechanical", "Electro-Hydraulic Thrusters, Cranes, Conveyors", "Critical", 1, "Check thruster terminal voltage, oil level, motor insulation resistance", "Top up transformer oil; replace thruster motor; check clearance"),
        ("FT-BRK-02", "Brake Lining Worn Out / Slipping Load", "Mechanical", "Disc Brakes, Shoe Brakes", "Critical", 0.5, "Measure brake lining thickness (<2mm = replace immediately); check torque", "Replace friction lining; adjust tie rod spring tension to calibrated torque"),
        ("FT-BRK-03", "Brake Overheating / Dragging Drum", "Mechanical", "Brakes, Cranes", "High", 1, "Measure shoe gap on both sides (should be equal ~0.8 mm)", "Equalize shoe travel with centering screws; check return spring"),

        # VFDs & Soft Starters
        ("FT-VFD-01", "VFD Inverter Fault / Overcurrent Trip (F001)", "Electrical", "Variable Frequency Drives (VFDs)", "Critical", 1, "Megger motor cable; inspect IGBT bridge module for collector-emitter short", "Replace faulty IGBT / VFD unit; verify motor insulation & dV/dt filter"),
        ("FT-VFD-02", "VFD DC Bus Overvoltage Trip (F002)", "Electrical", "VFDs, Hoists, Centrifuges", "High", 2, "Measure DC bus voltage during decel; inspect dynamic braking chopper", "Increase decel time; replace dynamic braking resistor; verify chopper fuse"),
        ("FT-VFD-03", "VFD Heatsink Over-Temperature Trip (F004)", "Electrical", "VFD Cabinets", "High", 2, "Check internal cabinet cooling fan, dust filter clogs, ambient temp", "Replace failed 24VDC cooling fan; clean dust filter pads"),
        ("FT-SFT-01", "Soft Starter SCR Overtemperature / Firing Fault", "Electrical", "Soft Starters", "High", 2, "Check bypass contactor operation; test SCR forward/reverse resistance", "Clean heatsink cooling ducts; replace faulty SCR stack; verify bypass"),
        ("FT-SFT-02", "Soft Starter Phase Loss / Trigger PCB Fault", "Electrical", "Soft Starters", "Critical", 1, "Check all 3 incoming phase voltages and trigger gate signals", "Replace trigger PCB card; verify supply phase symmetry"),

        # Starters
        ("FT-STR-01", "Star-to-Delta Transition Delay / Timer Stuck", "Electrical", "Star-Delta Starters", "High", 2, "Check electronic timer LED and star contactor drop-out timing", "Replace star-delta timer; set timing to reach 85% full speed"),
        ("FT-STR-02", "Thermal Overload Relay Trip (49)", "Electrical", "DOL / Star-Delta Starters", "High", 2, "Check motor line current with clamp meter vs nameplate FLC", "Check driven mechanical load for jamming; calibrate bi-metallic setting"),
        ("FT-STR-03", "Motor Protection Circuit Breaker (MPCB) Trip", "Electrical", "Motor Feeders", "High", 2, "Inspect terminal lugs for hot spots; measure winding resistance", "Recrimp loose cable terminals; reset MPCB after cool-down"),

        # Breakers & Switchgear
        ("FT-BRK-04", "Circuit Breaker Spring Charge Failure", "Electrical", "VCBs, ACBs", "High", 2, "Check 110VDC charging motor supply, microswitch contact, spring link", "Replace charging motor; lubricate spring charging mechanism"),
        ("FT-BRK-05", "Breaker Shunt Trip Coil Open Circuit", "Electrical", "VCBs, ACBs", "Critical", 1, "Multimeter continuity across trip coil; inspect auxiliary switch 52a", "Replace 110VDC trip coil; replace auxiliary switch contacts"),
        ("FT-BRK-06", "Switchgear Busbar Thermal Hotspot (>110°C)", "Electrical", "PCC/MCC Switchboards", "Critical", 1, "Infrared thermography scan; check Belleville spring washer torque", "De-energize, clean busbar contact face, apply silver grease, torque to 55Nm"),

        # Motors & Transformers
        ("FT-MOT-01", "Motor Single Phasing / Phase Imbalance", "Electrical", "Electric Motors", "Critical", 1, "Check supply line voltages and fuse continuity in all 3 phases", "Replace blown power fuse; inspect contactor tips; verify motor windings"),
        ("FT-MOT-02", "Motor Bearing High Vibration & Noise", "Mechanical", "Electric Motors", "High", 2, "FFT Vibration analyzer (look for BPFO/BPFI peaks and 1X/2X unbalance)", "Regrease with Mobilgrease 28; align shaft to <0.05 mm; replace bearing"),
        ("FT-MOT-03", "Motor Winding Low Insulation Resistance (<1 MΩ)", "Electrical", "Electric Motors", "High", 3, "1000V Megger test between phase-to-ground and phase-to-phase", "Bake winding with heat lamps; revarnish with Class H insulating varnish"),
        ("FT-TRF-01", "Transformer Buchholz Gas Alarm / Trip", "Electrical", "Power Transformers", "Critical", 1, "Inspect Buchholz sight glass; collect gas sample with syringe for DGA", "Conduct Dissolved Gas Analysis (DGA); SFRA test before re-energizing"),
        ("FT-TRF-02", "Transformer Silica Gel Saturated (Pink)", "Electrical", "Transformers", "Medium", 8, "Observe silica gel color in breather cup; check oil seal cup level", "Replace saturated pink beads with activated blue/orange silica gel"),

        # Mechanical Equipment
        ("FT-PMP-01", "Pump Mechanical Seal Heavy Slurry Leakage", "Mechanical", "Centrifugal & Slurry Pumps", "High", 3, "Check gland flush water pressure; observe droplet leakage rate", "Replace mechanical seal cartridge; clean flush water cyclone separator"),
        ("FT-PMP-02", "Pump Impeller Cavitation & Flow Loss", "Mechanical", "Pumps", "High", 4, "Acoustic check (gravel-like crackling sound); check suction gauge vacuum", "Clean suction strainer; raise suction head; replace eroded impeller"),
        ("FT-GBX-01", "Gearbox Oil Leakage & High Operating Temp", "Mechanical", "Industrial Gearboxes", "High", 3, "Inspect shaft oil seals, split casing flange, oil sight glass level", "Top up ISO VG 320 synthetic oil; replace Viton double-lip shaft seal"),
        ("FT-CNV-01", "Conveyor Belt Longitudinal Rip / Tear", "Mechanical", "Belt Conveyors", "Critical", 0.5, "Inspect transfer chute skirt boards for caught tramp iron debris", "Emergency cold-vulcanizing belt patch; clean tramp iron magnet"),
        ("FT-CNV-02", "Conveyor Sway / Mistracking Switch Trip", "Mechanical", "Belt Conveyors", "High", 1, "Check belt tracking idlers, material loading central chute, belt tension", "Re-center chute deflector; adjust training idlers; reset pull-cord switch"),

        # Instrumentation
        ("FT-INS-01", "Transmitter Signal Loss (4-20mA Open Loop)", "Instrumentation", "Transmitters, RTDs", "High", 2, "Measure mA loop current with multimeter; check 24VDC loop power supply", "Tighten terminal screws; replace damaged sensor head transmitter puck"),
        ("FT-INS-02", "Control Valve Position Deviation / Hunting", "Instrumentation", "Control Valves", "High", 2, "Check instrument air supply pressure (4-6 bar); check feedback linkage", "Clean air filter regulator; tighten linkage arm; autotune positioner"),
        ("FT-AUT-01", "PLC Remote I/O Communication Bus Failure", "Automation", "PLC Racks, Profinet/Profibus", "Critical", 1, "Check bus terminator switch resistance (220Ω); check fiber optic transceiver", "Replace damaged RJ45/Profibus connector; replace faulty I/O bus coupler")
    ]
    
    for row in fault_items:
        ws.append((*row, "GLOBAL", "GLOBAL"))
        
    tab_ft = Table(displayName="Table_FaultTypes", ref=f"A1:J{len(fault_items)+1}")
    tab_ft.tableStyleInfo = TableStyleInfo(name="TableStyleMedium2", showRowStripes=True)
    ws.add_table(tab_ft)
    
    for col in ws.columns:
        max_len = max(len(str(cell.value or '')) for cell in col)
        col_letter = get_column_letter(col[0].column)
        ws.column_dimensions[col_letter].width = min(max(max_len + 3, 14), 45)
    ws.row_dimensions[1].height = 26
    
    # Reference Sheet
    ws_ref = wb.create_sheet(title="Lookup_Lists")
    ws_ref.views.sheetView[0].showGridLines = True
    disciplines = ["Electrical", "Mechanical", "Instrumentation", "Automation", "Operational"]
    severities = ["Critical", "High", "Medium", "Low"]
    
    ws_ref.append(["Disciplines", "Severities"])
    for r in range(len(disciplines)):
        ws_ref.cell(row=r + 2, column=1, value=disciplines[r])
    for r in range(len(severities)):
        ws_ref.cell(row=r + 2, column=2, value=severities[r])
        
    for col in ws_ref.columns:
        max_len = max(len(str(cell.value or '')) for cell in col)
        col_letter = get_column_letter(col[0].column)
        ws_ref.column_dimensions[col_letter].width = max(max_len + 4, 18)

    # Add validation using direct range
    dv_d = DataValidation(type="list", formula1=f"Lookup_Lists!$A$2:$A${len(disciplines)+1}", allow_blank=True)
    ws.add_data_validation(dv_d)
    dv_d.add(f"C2:C{len(fault_items)+500}")

    dv_s = DataValidation(type="list", formula1=f"Lookup_Lists!$B$2:$B${len(severities)+1}", allow_blank=True)
    ws.add_data_validation(dv_s)
    dv_s.add(f"E2:E{len(fault_items)+500}")

    wb.save(filepath)
    print(f"Successfully generated Master Fault Types Catalog at: {filepath}")

if __name__ == '__main__':
    for path in [r"d:\AssetPulse-Pro\ODC_Master_Catalog.xlsx", r"d:\AssetPulse-Pro\ODC_Master_Catalog_Updated.xlsx"]:
        try:
            create_massive_odc_catalog(path)
            break
        except PermissionError:
            print(f"Warning: {path} is currently locked by Excel. Trying alternate path...")
            continue

    for path in [r"d:\AssetPulse-Pro\Fault_Types_Master_Catalog.xlsx", r"d:\AssetPulse-Pro\Fault_Types_Master_Catalog_Updated.xlsx"]:
        try:
            create_massive_fault_types_catalog(path)
            break
        except PermissionError:
            print(f"Warning: {path} is currently locked by Excel. Trying alternate path...")
            continue

