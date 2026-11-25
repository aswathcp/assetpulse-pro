import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

def build_excel_catalog(filepath):
    wb = openpyxl.Workbook()
    
    # Define styles
    header_fill = PatternFill(start_color="1F2937", end_color="1F2937", fill_type="solid")
    header_font = Font(name="Calibri", size=11, bold=True, color="FFFFFF")
    subhead_fill = PatternFill(start_color="374151", end_color="374151", fill_type="solid")
    
    border_thin = Border(
        left=Side(style='thin', color="E5E7EB"),
        right=Side(style='thin', color="E5E7EB"),
        top=Side(style='thin', color="E5E7EB"),
        bottom=Side(style='thin', color="E5E7EB")
    )
    
    # ----------------------------------------------------
    # SHEET 1: ODC Hierarchical Catalog (Object-Damage-Cause)
    # ----------------------------------------------------
    ws_odc = wb.active
    ws_odc.title = "ODC_Catalog_ISO14224"
    ws_odc.views.sheetView[0].showGridLines = True
    
    headers_odc = [
        "Discipline",
        "Equipment Category",
        "Object Part Code",
        "Object Part (Component)",
        "Damage Code",
        "Damage / Defect Mode",
        "Cause Code",
        "Root Cause / Mechanism",
        "ISO 14224 Failure Code",
        "Typical Severity",
        "Recommended Standard Action"
    ]
    
    ws_odc.append(headers_odc)
    
    odc_data = [
        # --- ELECTRICAL: ELECTRIC MOTORS ---
        ("Electrical", "Electric Motor", "MOT-BRG-DE", "Drive-End (DE) Bearing", "DMG-VIB", "High Vibration & Abnormal Noise", "CAU-LUB-STARV", "Lack of Lubrication / Grease Starvation", "M-1.1", "High", "Purge old grease, refill with OEM spec Mobilgrease 28, re-check vibration spectrum"),
        ("Electrical", "Electric Motor", "MOT-BRG-DE", "Drive-End (DE) Bearing", "DMG-TEMP", "Overheating (>90°C)", "CAU-LUB-OVER", "Over-Greasing / High Churning Friction", "M-1.2", "High", "Remove grease drain plug, run motor 30 mins to expel excess grease"),
        ("Electrical", "Electric Motor", "MOT-BRG-DE", "Drive-End (DE) Bearing", "DMG-SZ", "Bearing Seizure / Locked Rotor", "CAU-BRG-FATG", "Spalling / Flaking Fatigue Due to Dynamic Misalignment", "M-1.3", "Critical", "Replace DE bearing (SKF/FAG), align shaft using laser alignment to <0.05mm"),
        ("Electrical", "Electric Motor", "MOT-BRG-NDE", "Non-Drive-End (NDE) Bearing", "DMG-VIB", "Abnormal Squealing & Cage Rattle", "CAU-LUB-CONTAM", "Contamination (Dust / Moisture Ingress)", "M-1.4", "Medium", "Replace NDE bearing, renew V-ring/labyrinth dust seal"),
        ("Electrical", "Electric Motor", "MOT-WND-ST", "Stator Winding", "DMG-BRN", "Burnt Winding / Insulation Breakdown", "CAU-ELEC-SPH", "Single Phasing / Supply Phase Loss", "E-2.1", "Critical", "Send for rewinding with Class H insulation; inspect upstream breaker & contactor"),
        ("Electrical", "Electric Motor", "MOT-WND-ST", "Stator Winding", "DMG-EF", "Earth Fault / Low IR (<1 MΩ)", "CAU-ENV-MOIST", "Moisture / Condensation Ingress", "E-2.2", "High", "Bake winding with halogen heater, apply anti-tracking varnish, check space heater"),
        ("Electrical", "Electric Motor", "MOT-WND-ST", "Stator Winding", "DMG-OVL", "Thermal Overload Trip", "CAU-MECH-JAM", "Driven Machine Jam / Excessive Mechanical Load", "E-2.3", "High", "Inspect mechanical load / crusher chute for foreign tramp iron; verify trip curve"),
        ("Electrical", "Electric Motor", "MOT-TB-LUG", "Terminal Box & Studs", "DMG-FLSH", "Flashover / Burnt Power Terminal", "CAU-ELEC-LOOS", "Loose Cable Lug Termination / High Contact Resistance", "E-3.1", "Critical", "Cut burnt cable end, crimp bimetallic heavy-duty lugs, torque studs with torque wrench"),
        ("Electrical", "Electric Motor", "MOT-FAN", "Cooling Fan & Cowl", "DMG-BRK", "Fan Blade Broken / Damaged", "CAU-EXT-IMPT", "Foreign Object Ingress / Impact", "M-2.1", "Medium", "Replace cooling fan blade and reinstall secure cowl guard"),
        ("Electrical", "Electric Motor", "MOT-RTR-BAR", "Rotor / Squirrel Cage", "DMG-CRK", "Broken Rotor Bar / High Slip", "CAU-CYC-DUTY", "Frequent Direct-On-Line (DOL) Starting Stress", "E-2.4", "High", "Dynamic flux test; replace rotor or adjust VFD soft-start ramp profile"),

        # --- ELECTRICAL: POWER TRANSFORMERS ---
        ("Electrical", "Power Transformer", "TRF-BSH-HV", "HV Bushing (11kV / 33kV)", "DMG-CRK", "Hairline Crack / Tracking Flashover", "CAU-ENV-POLL", "Surface Pollution / High Humidity Flashover", "E-4.1", "Critical", "De-energize, clean and dry bushing, replace cracked bushing, retest tan-delta"),
        ("Electrical", "Power Transformer", "TRF-WND-PR", "Primary Winding", "DMG-SHORT", "Inter-turn Short Circuit / Diff Trip", "CAU-ELEC-SRG", "Lightning / Switching Voltage Surge", "E-4.2", "Critical", "Conduct SFRA & turns ratio test; overhaul winding; verify surge arrester discharge"),
        ("Electrical", "Power Transformer", "TRF-OIL-DK", "Transformer Mineral Oil", "DMG-BDV", "Low Dielectric BDV (<30 kV)", "CAU-OIL-MOIST", "Moisture Absorption & Sludge Degradation", "E-4.3", "High", "Perform on-site vacuum oil filtration / dehydration until BDV > 60 kV"),
        ("Electrical", "Power Transformer", "TRF-BCH-RL", "Buchholz Relay", "DMG-GAS", "Gas Collection / Alarm Trip", "CAU-INT-ARC", "Internal Incipient Arcing / Hotspot Pyrolysis", "E-4.4", "Critical", "Collect gas sample for DGA (Dissolved Gas Analysis) to identify fault nature"),
        ("Electrical", "Power Transformer", "TRF-OLTC", "On-Load Tap Changer", "DMG-MECH", "Tap Changer Stuck Between Steps", "CAU-DRV-JAM", "Drive Motor Mechanism / Limit Switch Failure", "E-4.5", "High", "Manual hand-crank to safe tap step; overhaul OLTC gearbox and contact fingers"),
        ("Electrical", "Power Transformer", "TRF-BRTH-SL", "Silica Gel Breather", "DMG-SAT", "Silica Gel Pink (100% Saturated)", "CAU-OIL-SEAL", "Oil Cup Seal Empty / Atmospheric Moisture Leak", "M-4.1", "Medium", "Replace pink silica gel with fresh blue/orange beads, top up oil sealing cup"),
        ("Electrical", "Power Transformer", "TRF-GSK-RAD", "Radiator Flange Gasket", "DMG-LEAK", "Active Oil Seepage / Drop Formation", "CAU-GSK-AGE", "NBR Gasket Hardening / Loose Flange Bolts", "M-4.2", "Medium", "Retorque flange bolts; replace with cork-neoprene gasket during planned outage"),

        # --- ELECTRICAL: SWITCHGEAR & BREAKERS (VCB/ACB/MCCB) ---
        ("Electrical", "Switchgear & VCB", "SWG-VCB-BOT", "Vacuum Interrupter Bottle", "DMG-VAC", "Loss of Vacuum / Contact Arcing", "CAU-CYC-LIFE", "Vacuum Bellows Micro-Leak after Life Expiry", "E-5.1", "Critical", "Perform high-pot vacuum integrity test (24kV AC for 1 min); replace vacuum bottle"),
        ("Electrical", "Switchgear & VCB", "SWG-TRP-CL", "Trip Coil / Shunt Release", "DMG-OPEN", "Trip Coil Open Circuit / Burnt", "CAU-COIL-CONT", "Continuous DC Energization due to Stuck Aux Switch", "E-5.2", "Critical", "Replace 110V DC trip coil; replace 52a/52b auxiliary switch assembly"),
        ("Electrical", "Switchgear & VCB", "SWG-SPR-MTR", "Spring Charging Motor", "DMG-JAM", "Motor Fails to Charge Spring", "CAU-MTR-GEAR", "Stripped Plastic Gear / Burnt DC Motor Brushes", "M-5.1", "High", "Replace charging motor unit; lubricate spring linkage with Kluber Isoflex"),
        ("Electrical", "Switchgear & VCB", "SWG-BUS-JNT", "Busbar Joint (PCC/MCC)", "DMG-HOT", "Thermal Hotspot (>110°C on Thermography)", "CAU-TORQ-LOSS", "Loose Belleville Washer / Oxidation of Contact Plating", "E-5.3", "Critical", "De-energize, wire-brush joint, apply silver contact grease, retorque to 55 Nm"),
        ("Electrical", "Switchgear & VCB", "SWG-ARC-CHT", "Arc Chute (Air Circuit Breaker)", "DMG-EROS", "Burnt De-ion Splitter Plates", "CAU-FLT-INTR", "Interruption of High Fault Current (Short Circuit)", "E-5.4", "High", "Clean soot deposits; replace eroded arc chute assembly"),

        # --- MECHANICAL: CENTRIFUGAL & SLURRY PUMPS ---
        ("Mechanical", "Centrifugal Pump", "PMP-IMP-SL", "Impeller", "DMG-CAV", "Impeller Vane Cavitation Pitting", "CAU-HYD-NPSH", "Inadequate NPSH Available / Starved Suction Strainer", "M-6.1", "High", "Replace impeller (High Chrome / Duplex); clean suction strainer; check tank level"),
        ("Mechanical", "Centrifugal Pump", "PMP-SEAL-MC", "Mechanical Seal", "DMG-LEAK", "Continuous Slurry / Water Leakage", "CAU-SEAL-FACE", "Silicon Carbide Face Scored by Abrasive Slurry Fines", "M-6.2", "High", "Replace mechanical seal cartridge; flush quench seal water line"),
        ("Mechanical", "Centrifugal Pump", "PMP-SLV-SFT", "Shaft Sleeve", "DMG-WEAR", "Deep Grooving under Gland Packing", "CAU-PCK-TIGHT", "Over-Tightened PTFE Packing without Leakage Droplets", "M-6.3", "Medium", "Replace hardened ceramic-coated sleeve; repack with graphite packing"),
        ("Mechanical", "Centrifugal Pump", "PMP-CAS-VOL", "Pump Casing / Volute", "DMG-THIN", "Severe Wall Thinning (<3mm residual)", "CAU-ABR-WEAR", "Erosive Slurry Velocity / Acidic Corrosion", "M-6.4", "Critical", "Perform ultrasonic thickness gauging (UTG); replace casing or apply ceramic epoxy"),
        ("Mechanical", "Centrifugal Pump", "PMP-CPL-EL", "Flexible Coupling", "DMG-SHR", "Coupling Spider Element Sheared / Broken", "CAU-MISALIGN", "Excessive Angular Misalignment with Drive Motor", "M-6.5", "High", "Install new polyurethane spider insert; laser-align pump to motor"),

        # --- MECHANICAL: INDUSTRIAL GEARBOXES ---
        ("Mechanical", "Industrial Gearbox", "GBX-PIN-IN", "Input Pinion Gear", "DMG-PITT", "Surface Pitting / Micropitting on Tooth Face", "CAU-OIL-VISC", "Low Oil Viscosity / Degraded EP Additive", "M-7.1", "High", "Drain oil, flush housing, refill with ISO VG 320 synthetic gear oil; inspect mesh"),
        ("Mechanical", "Industrial Gearbox", "GBX-WHL-OUT", "Output Bull Gear", "DMG-TOOTH", "Broken Tooth / Chipped Tip", "CAU-SHK-LOAD", "Heavy Shock Load / Crusher Feed Jam", "M-7.2", "Critical", "Replace matched gearset; inspect crusher toggle plate shear safety mechanism"),
        ("Mechanical", "Industrial Gearbox", "GBX-SEAL-OIL", "Input / Output Oil Seal", "DMG-LEAK", "Heavy Oil Leakage around Shaft", "CAU-SEAL-HARD", "Viton Lip Seal Hardened by High Temperature", "M-7.3", "Medium", "Replace Viton double-lip oil seal; polish shaft seal running track"),
        ("Mechanical", "Industrial Gearbox", "GBX-BRG-SPH", "Spherical Roller Bearing", "DMG-FLAK", "Flaking on Outer Raceway", "CAU-AXL-LOAD", "Heavy Axial Thrust from Helical Gear Mesh", "M-7.4", "High", "Replace bearing pair; set backlash and axial end-play to manufacturer clearance"),
        ("Mechanical", "Industrial Gearbox", "GBX-BRTH", "Gearbox Breather Plug", "DMG-CHOK", "Breather Clogged with Dust Cake", "CAU-ENV-DUST", "Severe Plant Fugitive Dust Accumulation", "M-7.5", "Low", "Wash breather with solvent or replace with desiccant breather"),

        # --- MECHANICAL: BELT CONVEYORS ---
        ("Mechanical", "Belt Conveyor", "CNV-BLT-RUB", "Conveyor Rubber Belt", "DMG-TEAR", "Longitudinal Belt Rip / Slit", "CAU-TRP-IRON", "Sharp Tramp Iron / Steel Chute Liner Piercing Belt", "M-8.1", "Critical", "Emergency cold vulcanizing repair patch / mechanical fasteners; inspect tramp magnet"),
        ("Mechanical", "Belt Conveyor", "CNV-IDL-ROL", "Troughing / Return Idler Roller", "DMG-SZ", "Roller Seized / Shell Cut Through Like Knife", "CAU-IDL-BRG", "Internal Bearing Seizure from Fine Material Ingress", "M-8.2", "High", "Replace seized idler roller immediately to prevent belt underside wear"),
        ("Mechanical", "Belt Conveyor", "CNV-PLY-DRV", "Drive Head Pulley", "DMG-LAG", "Rubber / Ceramic Lagging Debonded", "CAU-LAG-WEAR", "Severe Belt Slip under Wet Starting Conditions", "M-8.3", "High", "Re-lag drive pulley with cold-bonded ceramic diamond lagging"),
        ("Mechanical", "Belt Conveyor", "CNV-SCR-PRI", "Primary Belt Scraper", "DMG-WORN", "Carbide Blade Worn Out / Material Carryback", "CAU-BLD-ABR", "Continuous Contact with Abrasive Ore / Aggregate", "M-8.4", "Medium", "Adjust tension spring; replace tungsten carbide scraper tips"),
        ("Mechanical", "Belt Conveyor", "CNV-SWT-PC", "Pull Cord Emergency Switch", "DMG-STUK", "Trip Microswitch Stuck / Cord Snapped", "CAU-SWT-CORR", "Outdoor Weather Ingress / Corrosion of Mechanism", "E-6.1", "High", "Free mechanism, spray CRC 2-26, replace switch cord and verify interlock trip test"),

        # --- INSTRUMENTATION & AUTOMATION ---
        ("Instrumentation", "Field Transmitter", "INS-XMT-DPS", "Differential Pressure Transmitter", "DMG-ZERO", "Zero Shift / Unstable Reading", "CAU-IMP-CHOK", "Impulse Sensing Line Clogged with Slurry / Sludge", "I-1.1", "Medium", "Blow down / purge impulse line with compressed air/water; recalibrate zero/span"),
        ("Instrumentation", "Field Transmitter", "INS-RTD-EL", "RTD Pt100 Temperature Sensor", "DMG-OPEN", "Open Loop / Showing 850°C Max", "CAU-WIR-VIB", "Lead Wire Snapped Due to Heavy Machine Vibration", "I-1.2", "High", "Replace 3-wire mineral insulated RTD probe; damp conduit flex cable"),
        ("Instrumentation", "Control Valve", "INS-POS-ELP", "Smart Valve Positioner", "DMG-CAL", "Valve Hunting / Fails to Reach 100% Stroke", "CAU-AIR-DIRT", "Instrument Air Filter Regulator Contaminated with Water/Oil", "I-2.1", "High", "Drain water from air filter regulator; clean positioner nozzle-flapper; autotune"),
        ("Instrumentation", "Control Valve", "INS-ACT-DIA", "Pneumatic Diaphragm Actuator", "DMG-LEAK", "Air Leaking from Actuator Bonnet", "CAU-DIA-RUPT", "Neoprene Diaphragm Ruptured / Ageing", "I-2.2", "Critical", "Replace fabric-reinforced rolling diaphragm kit; leak-test with soapy water"),
        ("Instrumentation", "PLC & SCADA", "AUT-PLC-DI", "PLC Digital Input Card (24VDC)", "DMG-CHN", "Channel Blown / LED Off during Sensor Signal", "CAU-24V-SURG", "Field 24VDC Short Circuit / Ground Surge", "I-3.1", "Critical", "Replace 16-channel DI module; verify field isolator barrier & fuse status"),
        ("Instrumentation", "Flowmeter", "INS-FLW-MAG", "Electromagnetic Flowmeter", "DMG-NOISE", "Erratic Flow Signal Fluctuations", "CAU-EARTH-REF", "Loss of Grounding Ring / Poor Earthing Reference", "I-1.3", "Medium", "Verify earth grounding rings between non-conductive pipe flanges (<5 Ohms)"),

        # --- PIPING, VALVES & HYDRAULICS ---
        ("Mechanical", "Hydraulic Power Pack", "HYD-PMP-PST", "Variable Axial Piston Pump", "DMG-PRSS", "Loss of System Pressure (<50 bar)", "CAU-OIL-CONT", "Hydraulic Oil Contaminated (ISO Code > 21/18/15)", "M-9.1", "Critical", "Replace pump cartridge; replace 10-micron pressure return filters; flush tank"),
        ("Mechanical", "Hydraulic Power Pack", "HYD-HOS-HP", "High Pressure Hydraulic Hose", "DMG-BURST", "Hose Burst / High Velocity Spray", "CAU-HOS-FLEX", "Impulse Pressure Fatigue & Rubbing against Chassis", "M-9.2", "Critical", "Emergency stop; replace 4-spiral wire hose assembly; fit protective burst sleeve"),
        ("Mechanical", "Process Valve", "VLV-GAT-SL", "Knife Gate Slurry Valve", "DMG-LEAK", "External Packing Leakage / Gate Jammed", "CAU-SLR-BLD", "Dry Slurry Solidified in Valve Seat Bottom Pocket", "M-9.3", "Medium", "Flush bottom purge ports with high pressure water; retorque gland packing bolts")
    ]
    
    for row in odc_data:
        ws_odc.append(row)
        
    # Styling Sheet 1
    for col_num, col_title in enumerate(headers_odc, 1):
        cell = ws_odc.cell(row=1, column=col_num)
        cell.fill = header_fill
        cell.font = header_font
        cell.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        
    for row in ws_odc.iter_rows(min_row=2, max_row=len(odc_data)+1, min_col=1, max_col=len(headers_odc)):
        for cell in row:
            cell.border = border_thin
            cell.alignment = Alignment(vertical="center")
            
    # Auto column widths
    for col in ws_odc.columns:
        max_len = max(len(str(cell.value or '')) for cell in col)
        col_letter = get_column_letter(col[0].column)
        ws_odc.column_dimensions[col_letter].width = min(max(max_len + 3, 12), 40)
    ws_odc.row_dimensions[1].height = 28

    # ----------------------------------------------------
    # SHEET 2: Standard Industrial Fault Types Catalog
    # ----------------------------------------------------
    ws_ft = wb.create_sheet(title="Fault_Types_Catalog")
    ws_ft.views.sheetView[0].showGridLines = True
    
    headers_ft = [
        "Fault Type Code",
        "Standard Fault Name",
        "Discipline",
        "Target Equipment Scope",
        "Default Severity",
        "Target SLA (Hours)",
        "Key Diagnostic Checks",
        "Typical Corrective Action"
    ]
    ws_ft.append(headers_ft)
    
    fault_types_data = [
        ("FT-ELEC-01", "Motor Overload Trip", "Electrical", "Motors, Feeders, MCC", "High", 2, "Check running current, bimetallic relay setting, motor temperature", "Inspect load jam, check relay setting, test insulation resistance"),
        ("FT-ELEC-02", "Earth Fault / Zero Sequence Trip", "Electrical", "Transformers, Switchgear, Cables", "Critical", 1, "Megger test (IR value), check cable terminations & water ingress", "Locate punctured cable/winding, rectify ground fault, dry moisture"),
        ("FT-ELEC-03", "Single Phasing / Phase Loss", "Electrical", "Motors, Starters, Power Supply", "Critical", 1, "Check all 3 phase line-to-line voltages and control fuses", "Replace blown power fuse, inspect MCCB contact fingers, verify supply"),
        ("FT-ELEC-04", "Short Circuit / Instantaneous Overcurrent", "Electrical", "Busbars, Breakers, Cables", "Critical", 0.5, "Inspect arc chutes, busbars, inspect for burnt flash traces", "Clear fault origin, megger system, reset and test trip curve"),
        ("FT-ELEC-05", "Under-Voltage / Voltage Surge", "Electrical", "Substations, Incomers, UPS", "High", 2, "Check incoming grid voltage, surge arrester health, tap changer", "Coordinate with grid utility, adjust transformer tap, check surge arrester"),
        ("FT-ELEC-06", "Terminal Box Hotspot / Loose Connection", "Electrical", "Motors, Transformers, Panels", "High", 4, "Thermography thermal camera check (>85°C indicates loose contact)", "De-energize, recrimp lugs, clean contact face, retorque with torque wrench"),
        ("FT-ELEC-07", "Transformer High Oil/Winding Temp", "Electrical", "Power Transformers", "Critical", 1, "Check cooling fans, radiator oil valves, check oil level in conservator", "Start auxiliary cooling fans, clean radiator dust, reduce feeder load"),
        ("FT-ELEC-08", "Breaker Spring Charge Failure", "Electrical", "VCBs, ACBs", "High", 4, "Check 110V/220V DC supply, charging motor limit switch & fuse", "Replace charging motor / microswitch, manual hand-charge in emergency"),
        ("FT-ELEC-09", "Battery Bank / Charger DC Low Voltage", "Electrical", "DC UPS, Switchgear Battery Rooms", "Critical", 1, "Measure individual cell float voltages (ideal ~2.25V/cell), float charger", "Equalize charge bank, replace failed dead cell, inspect charger bridge"),
        ("FT-ELEC-10", "VFD Inverter Fault / DC Bus Overvoltage", "Electrical", "VFDs, Soft Starters", "High", 2, "Check braking resistor, deceleration ramp time, mains harmonics", "Increase decel time, inspect dynamic brake chopper, clean cooling heatsink"),
        
        ("FT-MECH-01", "Bearing High Vibration & Noise", "Mechanical", "Motors, Pumps, Fans, Gearboxes", "High", 2, "FFT Vibration analyzer (look for 1X, 2X, BPFO, BPFI peaks)", "Grease with OEM grease, check alignment, replace bearing if spalled"),
        ("FT-MECH-02", "Bearing High Temperature (>90°C)", "Mechanical", "Bearings, Plummer Blocks", "High", 2, "Contact pyrometer / RTD reading, check grease quantity", "Expel excess grease or top up grease, verify shaft alignment & axial play"),
        ("FT-MECH-03", "Pump Mechanical Seal Slurry Leakage", "Mechanical", "Centrifugal & Slurry Pumps", "High", 4, "Check seal buffer water pressure, observe droplet rate", "Flush seal lines, adjust gland or replace mechanical seal cartridge"),
        ("FT-MECH-04", "Gearbox Oil Leakage / Low Oil Level", "Mechanical", "Gearboxes, Reducers", "Medium", 6, "Sight glass level, inspect shaft seals and split line casing", "Top up with ISO VG 220/320 oil, replace worn lip seal, tighten bolts"),
        ("FT-MECH-05", "Coupling Shear / Element Damage", "Mechanical", "Drive Trains, Couplings", "High", 3, "Check spider element / grid springs, check angular misalignment", "Install new polyurethane element, laser-align drive train to <0.05 mm"),
        ("FT-MECH-06", "Conveyor Belt Tracking Misalignment / Sway", "Mechanical", "Belt Conveyors", "High", 2, "Inspect self-aligning tracking idlers, material off-center loading", "Adjust tracking idlers, re-center chute transfer point, inspect sway switch"),
        ("FT-MECH-07", "Conveyor Belt Longitudinal Rip / Puncture", "Mechanical", "Conveyor Belts", "Critical", 1, "Inspect chute liners for wedged tramp steel, check belt rip detector", "Apply rapid vulcanizing cold compound, remove caught metal debris"),
        ("FT-MECH-08", "Idler Roller Seizure / Jam", "Mechanical", "Belt Conveyors", "Medium", 8, "Audible squeal check, infrared scan of idler shell", "Replace seized roller to prevent belt friction burn"),
        ("FT-MECH-09", "Hydraulic Pressure Drop / Hose Rupture", "Mechanical", "Hydraulic Units, Cylinders", "Critical", 1, "Check pump relief valve setting, inspect hose runs for leaks", "Isolate pressure, replace hydraulic hose with 4-spiral hose, bleed air"),
        ("FT-MECH-10", "Impeller Cavitation / Erosion Wear", "Mechanical", "Pumps, Blowers", "High", 8, "Listen for gravel-like cavitation noise, check suction vacuum", "Clean suction strainer, raise suction tank head, replace worn impeller"),

        ("FT-INST-01", "Sensor Transmitter Signal Loss (4-20mA)", "Instrumentation", "Transmitters, Probes", "High", 2, "Multimeter mA loop test, check 24VDC loop power supply and wiring", "Rewire terminal screws, replace damaged transmitter electronic puck"),
        ("FT-INST-02", "Temperature RTD/Thermocouple Open", "Instrumentation", "RTDs, Bearing Temp Sensors", "Medium", 4, "Measure sensor resistance with DMM (Pt100 should be ~109Ω at 25°C)", "Replace probe, verify cable shield grounded at PLC panel only"),
        ("FT-INST-03", "Control Valve Position Deviation / Hunting", "Instrumentation", "Pneumatic & Electric Valves", "High", 3, "Check instrument air supply (4-6 bar), calibrate positioner zero/span", "Clean air filter regulator, tighten feedback linkage arm, autotune"),
        ("FT-INST-04", "PLC Digital/Analog Input Card Blown", "Automation", "PLC Racks, Remote I/O", "Critical", 2, "Check I/O rack status LED, check 24V field fuse, check diagnostic buffer", "Replace faulty I/O module, test field device for ground fault"),
        ("FT-INST-05", "Flowmeter Erratic / Spurious Pulse", "Instrumentation", "Magmeters, Vortex, Coriolis", "Medium", 4, "Check grounding ring resistance, check pipe fullness, check coil resistance", "Clean electrode deposits, restore pipe grounding bonds"),

        ("FT-OPER-01", "Chute Blockage / Material Jam", "Operational", "Transfer Chutes, Hoppers", "High", 1, "Check tilt switch / microwave level sensor, check moisture content", "Poke clear blockage with air lance / poke hole, verify hopper vibrator"),
        ("FT-OPER-02", "Emergency Pull-Cord / Push-Button Trip", "Operational", "Field Safety Switches", "High", 0.5, "Check physical pull-cord line, inspect which field station tripped", "Inspect belt area for hazards, reset field pull-cord switch, acknowledge interlock")
    ]
    
    for row in fault_types_data:
        ws_ft.append(row)
        
    for col_num, col_title in enumerate(headers_ft, 1):
        cell = ws_ft.cell(row=1, column=col_num)
        cell.fill = header_fill
        cell.font = header_font
        cell.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        
    for row in ws_ft.iter_rows(min_row=2, max_row=len(fault_types_data)+1, min_col=1, max_col=len(headers_ft)):
        for cell in row:
            cell.border = border_thin
            cell.alignment = Alignment(vertical="center")
            
    for col in ws_ft.columns:
        max_len = max(len(str(cell.value or '')) for cell in col)
        col_letter = get_column_letter(col[0].column)
        ws_ft.column_dimensions[col_letter].width = min(max(max_len + 3, 12), 42)
    ws_ft.row_dimensions[1].height = 28

    # ----------------------------------------------------
    # SHEET 3: Engineering Architecture Guide
    # ----------------------------------------------------
    ws_g = wb.create_sheet(title="ODC_Engineering_Guide")
    ws_g.views.sheetView[0].showGridLines = True
    
    guide_lines = [
        ("AssetPulse-Pro Industrial Reliability Framework: ODC & Fault Taxonomy Guide", ""),
        ("Standard Compliance", "Aligned with ISO 14224 (Petroleum, petrochemical & industrial reliability data exchange) and SAP PM Catalog Standard."),
        ("", ""),
        ("1. What is ODC?", "An exact tri-axial taxonomy to eliminate vague maintenance complaints like 'Machine stopped':"),
        ("• O = Object Part", "The specific maintainable sub-component that failed (e.g. DE Bearing, HV Bushing, Impeller, Stator Winding)."),
        ("• D = Damage / Defect Mode", "The observable physical manifestation or failure symptom (e.g. High Vibration, Overheating, Seized, Flashover, Slurry Leakage)."),
        ("• C = Root Cause / Failure Mechanism", "The underlying engineering reason for the failure (e.g. Grease Starvation, Single Phasing, Dynamic Misalignment, Acidic Corrosion)."),
        ("", ""),
        ("2. How the App's AI Uses This Catalog", "• Grounded Entity Extraction: When a technician dictates 'Shift A Crusher 1 motor DE bearing vibrated due to grease lack', the AI maps:"),
        ("  - Object: Drive-End (DE) Bearing", ""),
        ("  - Damage: High Vibration & Abnormal Noise", ""),
        ("  - Cause: Lack of Lubrication / Grease Starvation", ""),
        ("• Cascading Fallback: If AI is not used, selecting 'Electric Motor' filters Object Parts; selecting an Object Part presents the most probable Damage modes; and selecting a Damage mode highlights the primary Root Causes.", ""),
        ("", ""),
        ("3. Open Notification & Pareto Analytics", "• Pareto Charts: Classify plant downtime by Object Part and Root Cause to identify bad-actor equipment."),
        ("• MTBF / MTTR: Accurate calculation because repairs are linked to specific components rather than generic machine IDs.", "")
    ]
    
    for row in guide_lines:
        ws_g.append(row)
        
    ws_g.cell(row=1, column=1).font = Font(name="Calibri", size=14, bold=True, color="1E3A8A")
    for r in range(2, len(guide_lines)+1):
        c1 = ws_g.cell(row=r, column=1)
        c2 = ws_g.cell(row=r, column=2)
        c1.font = Font(name="Calibri", size=11, bold=True)
        c2.font = Font(name="Calibri", size=11)
        
    ws_g.column_dimensions['A'].width = 38
    ws_g.column_dimensions['B'].width = 95
    
    wb.save(filepath)
    print(f"Successfully generated comprehensive ODC & Fault Types Excel catalog at: {filepath}")

if __name__ == '__main__':
    build_excel_catalog(r"d:\AssetPulse-Pro\odc_and_fault_types_catalog.xlsx")
