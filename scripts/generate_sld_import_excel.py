import os
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.table import Table, TableStyleInfo
from openpyxl.worksheet.datavalidation import DataValidation
from openpyxl.formatting.rule import FormulaRule
from openpyxl.workbook.defined_name import DefinedName

def build_excel_workbook(file_path):
    wb = openpyxl.Workbook()
    wb.remove(wb.active)  # Remove default sheet

    navy_dark = "0F172A"
    slate_sub = "334155"
    border_light = "CBD5E1"

    font_title = Font(name="Calibri", size=15, bold=True, color="FFFFFF")
    font_section = Font(name="Calibri", size=12, bold=True, color="FFFFFF")
    font_header = Font(name="Calibri", size=11, bold=True, color="FFFFFF")
    font_normal = Font(name="Calibri", size=10, color="1E293B")
    font_italic = Font(name="Calibri", size=9, italic=True, color="64748B")

    thin_border = Border(
        left=Side(style='thin', color=border_light),
        right=Side(style='thin', color=border_light),
        top=Side(style='thin', color=border_light),
        bottom=Side(style='thin', color=border_light)
    )

    red_fill = PatternFill(start_color="FEE2E2", end_color="FEE2E2", fill_type="solid")
    red_font = Font(name="Calibri", size=10, bold=True, color="991B1B")

    # =========================================================================
    # 0. CONFIG SHEET (HIDDEN) FOR PLANT & UNIT DEPENDENT DROPDOWNS
    # =========================================================================
    ws_cfg = wb.create_sheet(title="_Config")
    ws_cfg.sheet_state = 'hidden'

    plant_units = {
        'IOG': ['COD', 'BCM', 'SON'],
        'IOK': ['CHD'],
        'IOO': ['OIO'],
        'VAB': ['PIPL', 'PIEP', 'DIP', 'MCD', 'PP1', 'PP2'],
        'ESL': ['SMS', 'BF', 'SP', 'COP', 'CPP', 'RM', 'WRM', 'OXY'],
        'WCL': ['CM1', 'CM2', 'CHP', 'WKS'],
    }
    plants_list = list(plant_units.keys())

    # Column A: All Plants
    ws_cfg.cell(row=1, column=1, value="Plants")
    for r_idx, p in enumerate(plants_list, 2):
        ws_cfg.cell(row=r_idx, column=1, value=p)

    # Defined Name for PlantsList
    wb.defined_names.add(DefinedName('PlantsList', attr_text=f"'_Config'!$A$2:$A${len(plants_list)+1}"))

    # Columns B onwards: Units per plant
    for col_idx, (p, u_list) in enumerate(plant_units.items(), 2):
        col_letter = get_column_letter(col_idx)
        ws_cfg.cell(row=1, column=col_idx, value=p)
        for r_idx, u in enumerate(u_list, 2):
            ws_cfg.cell(row=r_idx, column=col_idx, value=u)
        
        # Add named range for each plant matching its exact name (e.g. VAB, ESL, etc.)
        dn = DefinedName(p, attr_text=f"'_Config'!${col_letter}$2:${col_letter}${len(u_list)+1}")
        wb.defined_names.add(dn)

    # =========================================================================
    # HELPER FUNCTIONS FOR CLEAN TABLES & VALIDATIONS (FRESH PER SHEET!)
    # =========================================================================
    def apply_unique_id_rules(ws, max_rows=1000):
        """Enforces unique ID validation in Column A and highlights duplicates in red."""
        dv_id = DataValidation(
            type="custom",
            formula1=f"=COUNTIF($A$2:$A${max_rows}, A2)<=1",
            allow_blank=False
        )
        dv_id.errorStyle = "stop"
        dv_id.errorTitle = "Duplicate ID Error"
        dv_id.error = "This ID already exists in this sheet! IDs must be strictly unique."
        dv_id.promptTitle = "Unique ID"
        dv_id.prompt = "Enter a unique ID. Duplicates are rejected."
        ws.add_data_validation(dv_id)
        dv_id.add(f"A2:A{max_rows}")

        dup_rule = FormulaRule(
            formula=[f"COUNTIF($A$2:$A${max_rows}, A2)>1"],
            fill=red_fill,
            font=red_font
        )
        ws.conditional_formatting.add(f"A2:A{max_rows}", dup_rule)

    def add_list_validation(ws, cell_range, formula_str, title="Select Option", prompt="Choose a value from dropdown."):
        """Adds a clean, dedicated DataValidation dropdown to the specified range."""
        dv = DataValidation(type="list", formula1=formula_str, allow_blank=True)
        dv.promptTitle = title
        dv.prompt = prompt
        ws.add_data_validation(dv)
        dv.add(cell_range)
        return dv

    def style_table(ws, start_row, header_bg, headers, data, table_name, column_widths=None):
        # Header Row
        for col_idx, header in enumerate(headers, 1):
            cell = ws.cell(row=start_row, column=col_idx, value=header)
            cell.font = font_header
            cell.fill = PatternFill(start_color=header_bg, end_color=header_bg, fill_type="solid")
            cell.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
            cell.border = thin_border
        ws.row_dimensions[start_row].height = 28

        # Data Rows
        curr_row = start_row + 1
        for row_data in data:
            bg_color = "F8FAFC" if (curr_row % 2 == 0) else "FFFFFF"
            for col_idx, raw_val in enumerate(row_data, 1):
                val = None if (raw_val == "" or raw_val is None) else raw_val
                cell = ws.cell(row=curr_row, column=col_idx, value=val)
                cell.font = font_normal
                cell.fill = PatternFill(start_color=bg_color, end_color=bg_color, fill_type="solid")
                cell.border = thin_border
                
                if isinstance(val, (int, float)):
                    cell.alignment = Alignment(horizontal="right", vertical="center")
                elif col_idx in [1, 3, 5]:
                    cell.alignment = Alignment(horizontal="center", vertical="center")
                else:
                    cell.alignment = Alignment(horizontal="left", vertical="center")
            ws.row_dimensions[curr_row].height = 20
            curr_row += 1

        if column_widths:
            for col_idx, width in enumerate(column_widths, 1):
                ws.column_dimensions[get_column_letter(col_idx)].width = width
        else:
            for col_idx in range(1, len(headers) + 1):
                ws.column_dimensions[get_column_letter(col_idx)].width = 22

        last_row = max(curr_row - 1, start_row + 1)
        last_col_letter = get_column_letter(len(headers))
        tab = Table(
            displayName=table_name,
            ref=f"A{start_row}:{last_col_letter}{last_row}"
        )
        tab.tableStyleInfo = TableStyleInfo(
            name="TableStyleMedium9",
            showFirstColumn=False,
            showLastColumn=False,
            showRowStripes=True,
            showColumnStripes=False
        )
        ws.add_table(tab)

        apply_unique_id_rules(ws, max_rows=1000)
        return curr_row

    # =========================================================================
    # SHEET 1: Locations (Physical Areas)
    # =========================================================================
    ws_loc = wb.create_sheet(title="Locations")
    ws_loc.views.sheetView[0].showGridLines = True
    loc_headers = ["id", "name", "description", "plantId", "unitId"]
    loc_data = [
        ["SUBSTATION-YARD", "Central HT Substation & Captive DG Yard", "11kV main grid incomers, CAT DG generators, 5.5MVA/4MVA/1MVA transformers", "VAB", "PIPL"],
        ["BF1-BLOWER-AREA", "Blast Furnace 1 Blower Station & Air Supply", "Medium voltage 3.3kV blower house, MCC7, MCC10, MDC1 panels", "VAB", "PIPL"],
        ["BF2-BLOWER-AREA", "Blast Furnace 2 Blower House & Battery Station", "3.3kV BF2 blowers, BF2 110V DC battery room, control transformers", "VAB", "PIPL"],
        ["BF1-CAST-HOUSE", "Blast Furnace 1 Cast House & Gas Cleaning", "Cast house equipment, flarestack, baghouse, cooling tower MCC1", "VAB", "PIPL"],
        ["BF2-CAST-HOUSE", "Blast Furnace 2 Cast House & Slag Granulation", "Cast house drives, slag granulator, cooling tower MCC, MDC2 panel", "VAB", "PIPL"],
        ["PCI-PLANT-AREA", "Pulverized Coal Injection (PCI) Plant", "Rotary feeders, coal pulverizers, process compressors 1 to 4 and driers", "VAB", "PIPL"],
        ["TG-ROOM-AREA", "Turbo Generator (TG) & Power Center Building", "415V LT PCC2 switchboard, lighting distribution, mechanical workshop ties", "VAB", "PIPL"],
        ["WORKSHOP-AREA", "Central Mechanical & Electrical Workshop", "Maintenance shop, overhaul bays, motor testing MCC", "VAB", "PIPL"],
        ["WATER-PUMP-HOUSE", "Blast Furnace Recirculating Water Pump House", "RWP pumps 1 & 2 Star-Delta, RWP VFDs, cooling loop pumps", "VAB", "PIPL"],
        ["JETTY-RAW-MATERIAL", "Raw Material Handling Port Jetty", "Conveyors, ship unloaders, stacker-reclaimers fed from 11kV HT PCC", "VAB", "PIPL"],
        ["PIEP-EXPANSION", "Pig Iron Expansion Plant Facility", "Expansion plant units fed directly via 11kV HT PCC PIEP feeder", "VAB", "PIPL"]
    ]
    style_table(ws_loc, start_row=1, header_bg=navy_dark, headers=loc_headers, data=loc_data,
                table_name="Locations", column_widths=[24, 45, 60, 12, 12])

    # Col D (4): plantId -> PlantsList dropdown
    add_list_validation(ws_loc, "D2:D1000", "=PlantsList", "Plant", "Select Operating Plant")
    # Col E (5): unitId -> Dependent on Col D (plantId)
    add_list_validation(ws_loc, "E2:E1000", "=INDIRECT(D2)", "Unit", "Select Unit under Plant")

    # =========================================================================
    # SHEET 2: Panel_Rooms (Substations / Electrical Rooms)
    # =========================================================================
    ws_pr = wb.create_sheet(title="Panel_Rooms")
    ws_pr.views.sheetView[0].showGridLines = True
    pr_headers = ["id", "name", "description", "locationId", "plantId", "unitId"]
    pr_data = [
        ["11KV-HT-SUBSTATION", "11kV HT PCC & DG Switchgear Room", "Hosts 11kV CAT DG Panel, transformer breaker cells", "SUBSTATION-YARD", "VAB", "PIPL"],
        ["BF1-BLOWER-ROOM", "BF1 Blower Substation & MCC Center", "Hosts 3.3kV BF1 blower board, MCC7, MCC10, MDC1, Harmonic filter panel", "BF1-BLOWER-AREA", "VAB", "PIPL"],
        ["BF2-BLOWER-ROOM", "BF2 Blower Substation & Switchgear", "Hosts 3.3kV BF2 blower switchboard, inter-room 3.3kV tie cubicles", "BF2-BLOWER-AREA", "VAB", "PIPL"],
        ["LT-PCC-ROOM-1", "415V LT PCC1 Main Substation Room", "Hosts 415V LT PCC1 with split bus SEC-1, SEC-2, Bus Coupler BC-01", "BF1-BLOWER-AREA", "VAB", "PIPL"],
        ["LT-PCC-ROOM-2", "415V LT PCC2 Electrical Room (TG Building)", "Hosts 415V LT PCC2 switchboard, fed from 4MVA T/F and PCC1 tie", "TG-ROOM-AREA", "VAB", "PIPL"],
        ["PCI-ELECTRICAL-ROOM", "PCI Plant Electrical Control Room", "Hosts PCI MCC feeding rotary feeders and compressors 1-4", "PCI-PLANT-AREA", "VAB", "PIPL"],
        ["BF2-BATTERY-ROOM", "BF2 110V DC Battery Room", "Hosts 9x12V 180Ah battery bank (19.8kWh) & 110V DC charger panel", "BF2-BLOWER-AREA", "VAB", "PIPL"],
        ["BF1-BATTERY-ROOM", "BF1 110V DC Battery Charger Room", "Hosts 110V DC charger panel fed from LT PCC2 for BF1 protection circuits", "BF1-BLOWER-AREA", "VAB", "PIPL"],
        ["MDC2-SUBSTATION", "MDC2 Distribution Substation Room", "Hosts MDC2 LT Panel with dual incomers from PCC1 Sec 1 and Sec 2", "BF2-CAST-HOUSE", "VAB", "PIPL"],
        ["MECH-WORKSHOP-ROOM", "Mechanical Workshop Electrical Room", "Hosts Mechanical Workshop MCC fed from LT PCC2", "WORKSHOP-AREA", "VAB", "PIPL"]
    ]
    style_table(ws_pr, start_row=1, header_bg=navy_dark, headers=pr_headers, data=pr_data,
                table_name="Panel_Rooms", column_widths=[24, 42, 60, 24, 12, 12])

    # Col D (4): locationId -> =INDIRECT("Locations[id]")
    add_list_validation(ws_pr, "D2:D1000", '=INDIRECT("Locations[id]")', "Physical Area", "Select parent Physical Area (locationId)")
    # Col E (5): plantId -> PlantsList dropdown
    add_list_validation(ws_pr, "E2:E1000", "=PlantsList", "Plant", "Select Operating Plant")
    # Col F (6): unitId -> Dependent on Col E (plantId)
    add_list_validation(ws_pr, "F2:F1000", "=INDIRECT(E2)", "Unit", "Select Unit under Plant")

    # =========================================================================
    # SHEET 3: Panels (Clean Normalized: panelRoomId ONLY, NO locationId!)
    # =========================================================================
    ws_pnl = wb.create_sheet(title="Panels")
    ws_pnl.views.sheetView[0].showGridLines = True
    pnl_headers = ["id", "name", "type", "description", "panelRoomId", "voltageLevel", "busSections", "plantId", "unitId"]
    pnl_data = [
        ["11KV-HT-PCC", "11kV HT PCC CAT DG Panel", "PCC", "Main plant 11kV distribution board with grid & DG incomers", "11KV-HT-SUBSTATION", "11kV", "MAIN", "VAB", "PIPL"],
        ["33KV-BF1-BLOWER", "3.3kV BF1 Blower Room Panel", "PCC", "Medium voltage blower drives with split bus & bus coupler", "BF1-BLOWER-ROOM", "3.3kV", "SEC-1 & 2", "VAB", "PIPL"],
        ["33KV-BF2-BLOWER", "3.3kV BF2 Blower Room Panel", "PCC", "Medium voltage blower drives with split bus & bus coupler", "BF2-BLOWER-ROOM", "3.3kV", "SEC-1 & 2", "VAB", "PIPL"],
        ["415V-LT-PCC1", "415V LT PCC1 Main Power Panel", "PCC", "415V Main PCC with Section 1, Section 2 and Bus Coupler BC-01", "LT-PCC-ROOM-1", "415V", "SEC-1 & 2", "VAB", "PIPL"],
        ["415V-LT-PCC2", "415V LT PCC2 (TG Room)", "PCC", "415V Distribution PCC fed from 4MVA T/F and PCC1 tie", "LT-PCC-ROOM-2", "415V", "MAIN", "VAB", "PIPL"],
        ["MDC2-LT-PANEL", "MDC2 LT Panel", "PCC", "Dual-incomer main distribution center fed from PCC1 Sec 1 and Sec 2", "MDC2-SUBSTATION", "415V", "MAIN", "VAB", "PIPL"],
        ["MDC1-LT-PANEL", "MDC 1 LT Panel", "PCC", "Dual-incomer distribution center fed from PCC1 Sec 1 and MCC10", "BF1-BLOWER-ROOM", "415V", "MAIN", "VAB", "PIPL"],
        ["MCC7", "MCC7 (BF1 Blower Room)", "MCC", "Motor control center with bidirectional tie feeder to MCC10", "BF1-BLOWER-ROOM", "415V", "MAIN", "VAB", "PIPL"],
        ["MCC10", "MCC 10 (BF1 Blower Room)", "MCC", "Motor control center with bidirectional tie feeder to MCC7", "BF1-BLOWER-ROOM", "415V", "MAIN", "VAB", "PIPL"],
        ["PCI-MCC", "PCI MCC (Coal Injection)", "MCC", "Dedicated MCC for coal injection compressors and rotary feeders", "PCI-ELECTRICAL-ROOM", "415V", "MAIN", "VAB", "PIPL"],
        ["BF2-110V-DC-BATT-PANEL", "BF2 110V DC Battery Charger Panel", "Control Panel", "110V DC protection/tripping supply fed from MCC9N cubicle 11F5", "BF2-BATTERY-ROOM", "415V", "MAIN", "VAB", "PIPL"],
        ["MDC1-HARM-FILTER", "MDC-1 Harmonic Filter Panel", "Control Panel", "Power factor and harmonic compensation (4x50kVAR capacitor banks)", "BF1-BLOWER-ROOM", "415V", "MAIN", "VAB", "PIPL"],
        ["BF1-CT-MCC1", "BF1 Cooling Tower MCC1", "MCC", "Cooling tower fan and pump starters for BF1 loop", "BF1-BLOWER-ROOM", "415V", "MAIN", "VAB", "PIPL"],
        ["BF1-BAGHOUSE-MCC", "BF1 BagHouse MCC", "MCC", "Bag filter pulsing, ID fans and dust handling MCC", "BF1-BLOWER-ROOM", "415V", "MAIN", "VAB", "PIPL"],
        ["GCS-SEC2-MCC", "GCS Section 2 MCC", "MCC", "Gas Cleaning Plant Section 2 + Project Building + BF Comp 3", "BF1-BLOWER-ROOM", "415V", "MAIN", "VAB", "PIPL"],
        ["BF2-CT-MCC", "BF2 Cooling Tower MCC", "MCC", "Cooling tower distribution center for BF2 unit", "MDC2-SUBSTATION", "415V", "MAIN", "VAB", "PIPL"],
        ["MCC9N", "MCC 9N (Unit BF2)", "MCC", "Motor control center feeding BF2 loads and 110V DC Battery Charger", "MDC2-SUBSTATION", "415V", "MAIN", "VAB", "PIPL"],
        ["MCC2N", "MCC 2N (Unit BF2)", "MCC", "Low voltage motor control center for BF2 auxiliaries", "MDC2-SUBSTATION", "415V", "MAIN", "VAB", "PIPL"],
        ["MCC12", "MCC 12 (Project Bldg + Jayanti Yard)", "MCC", "Project building and yard power distribution", "MDC2-SUBSTATION", "415V", "MAIN", "VAB", "PIPL"],
        ["SLAG-LADLE-MCC", "Slag Dryer + Ladle Dumping MCC", "MCC", "Slag handling and ladle dumping equipment MCC", "MDC2-SUBSTATION", "415V", "MAIN", "VAB", "PIPL"],
        ["MCC8-GCS1", "MCC 8 GCS Section 1", "MCC", "Gas cleaning plant section 1 MCC", "MDC2-SUBSTATION", "415V", "MAIN", "VAB", "PIPL"],
        ["MECH-WS-MCC", "Mechanical Workshop MCC", "MCC", "Machine tools, lathes, cranes and maintenance workshop drives", "MECH-WORKSHOP-ROOM", "415V", "MAIN", "VAB", "PIPL"],
        ["TG-ROOM-LDB", "Lighting Distribution Board at TG Room", "LDB", "Station lighting and auxiliary power distribution board", "LT-PCC-ROOM-2", "415V", "MAIN", "VAB", "PIPL"],
        ["BF1-110V-BATT-CHG", "BF1 110V Battery Charger Panel", "Control Panel", "110V DC battery charger and tripping board for BF1", "BF1-BATTERY-ROOM", "415V", "MAIN", "VAB", "PIPL"],
        ["BF1-HBS-MCC", "BF1 HBS MCC", "MCC", "Hot blast stove auxiliary machinery MCC", "BF1-BLOWER-ROOM", "415V", "MAIN", "VAB", "PIPL"],
        ["MCC2", "MCC 2", "MCC", "Secondary motor control center in blower area", "BF1-BLOWER-ROOM", "415V", "MAIN", "VAB", "PIPL"],
        ["MCC1", "MCC 1", "MCC", "Primary motor control center fed from MCC7", "BF1-BLOWER-ROOM", "415V", "MAIN", "VAB", "PIPL"],
        ["MCC9-SEC2", "MCC 9 Section 2", "MCC", "Auxiliary motor control section 2 fed from MCC10", "BF1-BLOWER-ROOM", "415V", "MAIN", "VAB", "PIPL"],
        ["MCC10N", "MCC-10N", "MCC", "Sub-distribution motor control center fed from MCC10", "BF1-BLOWER-ROOM", "415V", "MAIN", "VAB", "PIPL"],
        ["DS-MCC2", "DS MCC 2 (Desulphurization)", "MCC", "Desulphurization plant auxiliary MCC 2", "BF1-BLOWER-ROOM", "415V", "MAIN", "VAB", "PIPL"]
    ]
    style_table(ws_pnl, start_row=1, header_bg=navy_dark, headers=pnl_headers, data=pnl_data,
                table_name="Panels", column_widths=[24, 38, 14, 52, 22, 14, 15, 12, 12])

    # Col C (3): type -> Panel classification dropdown
    add_list_validation(ws_pnl, "C2:C1000", '"MCC,PCC,LDB,Control Panel,Distribution Board,VFD Panel,Soft Starter Panel,Switchboard,Other"', "Panel Type", "Select Panel Type")
    # Col E (5): panelRoomId -> =INDIRECT("Panel_Rooms[id]")
    add_list_validation(ws_pnl, "E2:E1000", '=INDIRECT("Panel_Rooms[id]")', "Panel Room", "Select parent Panel Room (panelRoomId)")
    # Col F (6): voltageLevel -> Voltage levels list
    add_list_validation(ws_pnl, "F2:F1000", '"415V,3.3kV,6.6kV,11kV,22kV,33kV,66kV,110kV,132kV,220kV"', "Voltage Level", "Select operating voltage")
    # Col G (7): busSections -> MAIN vs SEC-1 & 2
    add_list_validation(ws_pnl, "G2:G1000", '"MAIN,SEC-1 & 2"', "Bus Sections", "Select bus section configuration")
    # Col H (8): plantId -> PlantsList dropdown
    add_list_validation(ws_pnl, "H2:H1000", "=PlantsList", "Plant", "Select Operating Plant")
    # Col I (9): unitId -> Dependent on Col H (plantId)
    add_list_validation(ws_pnl, "I2:I1000", "=INDIRECT(H2)", "Unit", "Select Unit under Plant")

    # =========================================================================
    # SHEET 4: Feeders
    # =========================================================================
    ws_fdr = wb.create_sheet(title="Feeders")
    ws_fdr.views.sheetView[0].showGridLines = True
    fdr_headers = [
        "id", "name", "type", "description", "panelId", 
        "busSection", "operatingState", "upstreamFeederId", "plantId", "unitId"
    ]
    fdr_data = [
        # 11KV HT PCC
        ["HTPCC-IC-GEPL", "11KV GEPL I/C", "Incomer", "Main Grid Incomer from GEPL grid substation", "11KV-HT-PCC", "MAIN", "CLOSED", "GRID-GEPL-11KV", "VAB", "PIPL"],
        ["HTPCC-IC-CAT-DG", "3 * 1944KVA CAT DG I/C", "Incomer", "Captive generation incomer from 3x CAT DG sets", "11KV-HT-PCC", "MAIN", "CLOSED", "CAT-DG-1-2-3", "VAB", "PIPL"],
        ["HTPCC-OG-TR-BF2-BH", "1MVA T/F BF2 Bag House", "Feeder", "HT Outgoing feeder to 1MVA step-down transformer", "11KV-HT-PCC", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["HTPCC-OG-PIEP", "PIEP OUTGOING", "Feeder", "Direct 11kV cross-unit feeder to Pig Iron Expansion Plant", "11KV-HT-PCC", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["HTPCC-OG-JETTY", "JETTY FEEDER", "Feeder", "Direct 11kV feeder to raw material jetty switchboard", "11KV-HT-PCC", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["HTPCC-OG-TR-4MVA", "4MVA T/F Feeder", "Feeder", "HT Feeder to 4MVA 3-winding transformer", "11KV-HT-PCC", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["HTPCC-OG-TR-55-2", "5.5MVA T/F 2 Feeder", "Feeder", "HT Feeder to 5.5MVA transformer 2", "11KV-HT-PCC", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["HTPCC-OG-TR-55-1", "5.5MVA T/F 1 Feeder", "Feeder", "HT Feeder to 5.5MVA transformer 1", "11KV-HT-PCC", "MAIN", "CLOSED", "", "VAB", "PIPL"],

        # 3.3KV BF1 BLOWER
        ["BF1-33KV-IC-TR1", "3.3kV I/C 1 From TR-5.5MVA-1", "Incomer", "3.3kV secondary incomer from 5.5MVA Transformer 1 into Section 1", "33KV-BF1-BLOWER", "SEC-1", "CLOSED", "TR-5.5MVA-1", "VAB", "PIPL"],
        ["BF1-33KV-FDR-B6", "BF1 Blower B6 Feeder", "Feeder", "3.3kV Feeder to 800kW cold blast blower B6 with PFC capacitor", "33KV-BF1-BLOWER", "SEC-1", "CLOSED", "", "VAB", "PIPL"],
        ["BF1-33KV-FDR-B3", "BF1 Blower B3 Feeder", "Feeder", "3.3kV Feeder to 800kW cold blast blower B3 with PFC capacitor", "33KV-BF1-BLOWER", "SEC-1", "CLOSED", "", "VAB", "PIPL"],
        ["BF1-33KV-FDR-B5", "BF1 Blower B5 Feeder", "Feeder", "3.3kV Feeder to 800kW cold blast blower B5 with PFC capacitor", "33KV-BF1-BLOWER", "SEC-1", "CLOSED", "", "VAB", "PIPL"],
        ["BF1-33KV-FDR-B1", "BF1 Blower B1 Feeder", "Feeder", "3.3kV Feeder to auxiliary blast blower B1 with PFC capacitor", "33KV-BF1-BLOWER", "SEC-1", "CLOSED", "", "VAB", "PIPL"],
        ["BF1-33KV-BUS-COUPLER", "3.3kV Bus Coupler BC-01", "Bus Coupler", "Bus coupler breaker bridging BF1 Blower 3.3kV Section 1 and Section 2", "33KV-BF1-BLOWER", "SEC-1 & 2", "OPEN", "", "VAB", "PIPL"],
        ["BF1-33KV-FDR-B4", "BF1 Blower B4 Feeder", "Feeder", "3.3kV Feeder to 800kW cold blast blower B4 on Section 2", "33KV-BF1-BLOWER", "SEC-2", "CLOSED", "", "VAB", "PIPL"],
        ["BF1-33KV-FDR-B2", "BF1 Blower B2 Feeder", "Feeder", "3.3kV Feeder to 800kW cold blast blower B2 on Section 2", "33KV-BF1-BLOWER", "SEC-2", "CLOSED", "", "VAB", "PIPL"],
        ["BF1-33KV-TIE-BF2", "3.3kV Inter-Room Tie to BF2", "Tie", "Inter-room 3.3kV tie cable feeder to BF2 Blower switchboard", "33KV-BF1-BLOWER", "SEC-2", "OPEN", "BF2-33KV-TIE-BF1", "VAB", "PIPL"],

        # 3.3KV BF2 BLOWER
        ["BF2-33KV-IC-TR2", "3.3kV I/C 1 From TR-5.5MVA-2", "Incomer", "3.3kV secondary incomer from 5.5MVA Transformer 2 into Section 2", "33KV-BF2-BLOWER", "SEC-2", "CLOSED", "TR-5.5MVA-2", "VAB", "PIPL"],
        ["BF2-33KV-FDR-B6", "BF2 Blower B6 Feeder", "Feeder", "3.3kV Feeder to BF2 cold blast blower B6 with PFC capacitor", "33KV-BF2-BLOWER", "SEC-2", "CLOSED", "", "VAB", "PIPL"],
        ["BF2-33KV-FDR-B3", "BF2 Blower B3 Feeder", "Feeder", "3.3kV Feeder to BF2 cold blast blower B3 with PFC capacitor", "33KV-BF2-BLOWER", "SEC-2", "CLOSED", "", "VAB", "PIPL"],
        ["BF2-33KV-FDR-B2", "BF2 Blower B2 Feeder", "Feeder", "3.3kV Feeder to BF2 cold blast blower B2 with PFC capacitor", "33KV-BF2-BLOWER", "SEC-2", "CLOSED", "", "VAB", "PIPL"],
        ["BF2-33KV-FDR-B1", "BF2 Blower B1 Feeder", "Feeder", "3.3kV Feeder to BF2 auxiliary blast blower B1 with PFC capacitor", "33KV-BF2-BLOWER", "SEC-2", "CLOSED", "", "VAB", "PIPL"],
        ["BF2-33KV-BUS-COUPLER", "3.3kV Bus Coupler BC-02", "Bus Coupler", "Bus coupler breaker bridging BF2 Blower 3.3kV Section 1 and Section 2", "33KV-BF2-BLOWER", "SEC-1 & 2", "OPEN", "", "VAB", "PIPL"],
        ["BF2-33KV-FDR-B5", "BF2 Blower B5 Feeder", "Feeder", "3.3kV Feeder to BF2 cold blast blower B5 with PFC capacitor", "33KV-BF2-BLOWER", "SEC-1", "CLOSED", "", "VAB", "PIPL"],
        ["BF2-33KV-FDR-B4", "BF2 Blower B4 Feeder", "Feeder", "3.3kV Feeder to BF2 cold blast blower B4 with PFC capacitor", "33KV-BF2-BLOWER", "SEC-1", "CLOSED", "", "VAB", "PIPL"],
        ["BF2-33KV-TIE-BF1", "3.3kV Inter-Room Tie to BF1", "Tie", "Inter-room 3.3kV tie cable feeder connecting to BF1 Blower switchboard", "33KV-BF2-BLOWER", "SEC-1", "OPEN", "BF1-33KV-TIE-BF2", "VAB", "PIPL"],

        # 415V LT PCC1
        ["PCC1-IC-TR1", "5.5MVA T/F 1 I/C", "Incomer", "415V Tertiary incomer from 5.5MVA Transformer 1", "415V-LT-PCC1", "SEC-1", "CLOSED", "TR-5.5MVA-1", "VAB", "PIPL"],
        ["PCC1-OG-MDC2-IC1", "O/G to MDC2 I/C 1", "Feeder", "Feeder from Section 1 to MDC2 Dual Incomer 1", "415V-LT-PCC1", "SEC-1", "CLOSED", "", "VAB", "PIPL"],
        ["PCC1-OG-BF1-CT1", "O/G to BF1 Cooling Tower MCC1", "Feeder", "Feeder supplying cooling tower MCC1 in BF1", "415V-LT-PCC1", "SEC-1", "CLOSED", "", "VAB", "PIPL"],
        ["PCC1-OG-GCS2", "O/G to GCS Section 2 + Project Building + BF Comp No.3", "Feeder", "Composite distribution feeder to GCS-2 and compressor 3", "415V-LT-PCC1", "SEC-1", "CLOSED", "", "VAB", "PIPL"],
        ["PCC1-OG-MCC7-IC1", "O/G to MCC7 I/C 1", "Feeder", "Feeder supplying primary incomer 1 on MCC7", "415V-LT-PCC1", "SEC-1", "CLOSED", "", "VAB", "PIPL"],
        ["PCC1-OG-LT-PCC2", "O/G to LT PCC2", "Feeder", "Interconnector feeder supplying secondary incomer on LT PCC2", "415V-LT-PCC1", "SEC-1", "CLOSED", "", "VAB", "PIPL"],
        ["PCC1-OG-BF1-BH", "O/G to BF1 BagHouse MCC", "Feeder", "Feeder supplying BF1 baghouse dust extraction MCC", "415V-LT-PCC1", "SEC-1", "CLOSED", "", "VAB", "PIPL"],
        ["PCC1-OG-MDC1-IC1", "O/G to MDC1 I/C 1", "Feeder", "Feeder supplying primary incomer 1 on MDC1 LT Panel", "415V-LT-PCC1", "SEC-1", "CLOSED", "", "VAB", "PIPL"],
        ["PCC1-BUS-COUPLER", "Bus Coupler BC-01", "Bus Coupler", "Bus coupler breaker bridging Section 1 and Section 2", "415V-LT-PCC1", "SEC-1 & 2", "OPEN", "", "VAB", "PIPL"],
        ["PCC1-IC-DG", "INTAC DG 1 & 4 I/C", "Incomer", "Emergency standby diesel generator incomer into Section 2", "415V-LT-PCC1", "SEC-2", "CLOSED", "INTAC-DG-1-4", "VAB", "PIPL"],
        ["PCC1-IC-TR2", "5.5MVA T/F 2 I/C", "Incomer", "415V Tertiary incomer from 5.5MVA Transformer 2 into Section 2", "415V-LT-PCC1", "SEC-2", "CLOSED", "TR-5.5MVA-2", "VAB", "PIPL"],
        ["PCC1-OG-MCC10-IC1", "O/G to MCC10 I/C 1", "Feeder", "Feeder from Section 2 supplying primary incomer on MCC10", "415V-LT-PCC1", "SEC-2", "CLOSED", "", "VAB", "PIPL"],
        ["PCC1-OG-MDC2-IC2", "O/G to MDC2 I/C 2", "Feeder", "Feeder from Section 2 to MDC2 Dual Incomer 2", "415V-LT-PCC1", "SEC-2", "CLOSED", "", "VAB", "PIPL"],

        # 415V LT PCC2
        ["PCC2-IC-TR4", "4MVA T/F I/C", "Incomer", "Primary 415V incomer from 4MVA Transformer", "415V-LT-PCC2", "MAIN", "CLOSED", "TR-4MVA", "VAB", "PIPL"],
        ["PCC2-IC-PCC1", "LT PCC1 I/C", "Incomer", "Secondary tie incomer from 415V LT PCC1 Section 1", "415V-LT-PCC2", "MAIN", "CLOSED", "PCC1-OG-LT-PCC2", "VAB", "PIPL"],
        ["PCC2-OG-PCI-MCC", "O/G to PCI MCC", "Feeder", "Feeder supplying PCI MCC for coal injection machinery", "415V-LT-PCC2", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["PCC2-VACANT-1", "VECANT Feeder", "Spare", "Spare / vacant breaker cubicle for future expansion", "415V-LT-PCC2", "MAIN", "OPEN", "", "VAB", "PIPL"],
        ["PCC2-OG-MECH-WS", "O/G to Mechanical Workshop MCC", "Feeder", "Feeder supplying central mechanical workshop MCC", "415V-LT-PCC2", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["PCC2-OG-KESAR-COMP", "KESAR Compressor 3 Drier", "Feeder", "Feeder powering plant instrument air compressor & drier 3", "415V-LT-PCC2", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["PCC2-OG-BF1-BATT", "O/G to BF1 110V Battery Charger Panel", "Feeder", "415V Supply to BF1 DC battery charger panel", "415V-LT-PCC2", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["PCC2-OG-TG-LDB", "Lighting Distribution Board(LDB) at TG Room", "Feeder", "Feeder to TG building lighting and socket distribution board", "415V-LT-PCC2", "MAIN", "CLOSED", "", "VAB", "PIPL"],

        # PCI MCC
        ["PCI-MCC-IC", "I/C From LT PCC2", "Incomer", "Incoming feeder from 415V LT PCC2", "PCI-MCC", "MAIN", "CLOSED", "PCC2-OG-PCI-MCC", "VAB", "PIPL"],
        ["PCI-OG-ROTARY-3-4", "Rotary Feeder 3,4", "Feeder", "Power supply to coal injection rotary feeder pair 3 & 4", "PCI-MCC", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["PCI-OG-ROTARY-1-2", "Rotary Feeder 1,2", "Feeder", "Power supply to coal injection rotary feeder pair 1 & 2", "PCI-MCC", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["PCI-OG-COMP4-DRIERS", "PCI Compressor 4 & Driers 1,2,3,4", "Feeder", "Feeder powering compressor 4 and drying skid line", "PCI-MCC", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["PCI-OG-COMP-1-2-3", "PCI Compressor 1,2,3", "Feeder", "Feeder powering main PCI process air compressors 1, 2, 3", "PCI-MCC", "MAIN", "CLOSED", "", "VAB", "PIPL"],

        # MDC2 LT PANEL
        ["MDC2-IC-1", "I/C From LT PCC1 Section A", "Incomer", "Primary incoming feeder from LT PCC1 Section 1", "MDC2-LT-PANEL", "MAIN", "CLOSED", "PCC1-OG-MDC2-IC1", "VAB", "PIPL"],
        ["MDC2-IC-2", "I/C From LT PCC1 Section B", "Incomer", "Secondary incoming feeder from LT PCC1 Section 2", "MDC2-LT-PANEL", "MAIN", "CLOSED", "PCC1-OG-MDC2-IC2", "VAB", "PIPL"],
        ["MDC2-OG-MCC12-PROJ", "O/G to MCC12 + Project Building + Jayanti Yard", "Feeder", "Feeder to project expansion and raw material yard", "MDC2-LT-PANEL", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["MDC2-OG-SLAG-DRYER", "O/G to Slag Dryer + Ladle Dumping MCC", "Feeder", "Feeder to slag treatment plant and ladle dumping stations", "MDC2-LT-PANEL", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["MDC2-OG-MCC8-GCS1", "O/G to MCC8 GCS Section 1", "Feeder", "Feeder to Gas Cleaning Plant section 1 MCC", "MDC2-LT-PANEL", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["MDC2-OG-BF2-CT-MCC", "O/G to BF2 Cooling Tower MCC", "Feeder", "Feeder to BF2 cooling tower pump and fan motors", "MDC2-LT-PANEL", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["MDC2-OG-MCC9N", "O/G to MCC9N", "Feeder", "Feeder to MCC9N (supplies BF2 110V DC battery charger)", "MDC2-LT-PANEL", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["MDC2-OG-MCC2N", "O/G to MCC2N", "Feeder", "Feeder to MCC2N motor control center in BF2", "MDC2-LT-PANEL", "MAIN", "CLOSED", "", "VAB", "PIPL"],

        # BF2 110V DC BATTERY
        ["BF2-BATT-IC", "415V I/C From LT MCC 9N (11F5)", "Incomer", "415V AC supply from MCC9N cubicle 11F5 into battery charger", "BF2-110V-DC-BATT-PANEL", "MAIN", "CLOSED", "MCC9N-FDR-11F5", "VAB", "PIPL"],
        ["BF2-BATT-SPARE-1", "Spare Cubicle 1", "Spare", "Spare DC output feeder", "BF2-110V-DC-BATT-PANEL", "MAIN", "OPEN", "", "VAB", "PIPL"],
        ["BF2-BATT-SPARE-2", "Spare Cubicle 2", "Spare", "Spare DC output feeder", "BF2-110V-DC-BATT-PANEL", "MAIN", "OPEN", "", "VAB", "PIPL"],
        ["BF2-BATT-OG-1MVA-TR", "1MVA Transformer Tripping Supply", "Feeder", "110V DC protection and breaker trip coil supply for 1MVA T/F", "BF2-110V-DC-BATT-PANEL", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["BF2-BATT-OG-BLOWER-OCS", "BF2 Blower OCS Control Supply", "Feeder", "110V DC operational control supply for BF2 blowers", "BF2-110V-DC-BATT-PANEL", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["BF2-BATT-OG-BLOWER-PNL", "BF2 Blower Panel Supply", "Feeder", "110V DC control supply for 3.3kV BF2 blower switchboard", "BF2-110V-DC-BATT-PANEL", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["BF2-BATT-SPARE-3", "Spare Cubicle 3", "Spare", "Spare DC output feeder", "BF2-110V-DC-BATT-PANEL", "MAIN", "OPEN", "", "VAB", "PIPL"],
        ["BF2-BATT-SPARE-4", "Spare Cubicle 4", "Spare", "Spare DC output feeder", "BF2-110V-DC-BATT-PANEL", "MAIN", "OPEN", "", "VAB", "PIPL"],
        ["BF2-BATT-SPARE-5", "Spare Cubicle 5", "Spare", "Spare DC output feeder", "BF2-110V-DC-BATT-PANEL", "MAIN", "OPEN", "", "VAB", "PIPL"],

        # MCC7
        ["MCC7-IC-1", "I/C 1 From PCC1 Section A", "Incomer", "Primary incomer from 415V LT PCC1 Section 1", "MCC7", "MAIN", "CLOSED", "PCC1-OG-MCC7-IC1", "VAB", "PIPL"],
        ["MCC7-TIE-MCC10", "I/C 2 From MCC 10 Or O/G to MCC 10", "Tie", "Bidirectional inter-MCC tie line bridging MCC7 and MCC10", "MCC7", "MAIN", "OPEN", "MCC10-TIE-MCC7", "VAB", "PIPL"],
        ["MCC7-OG-LIGHTING-TR", "Lighting T/F", "Feeder", "Supply to blower house lighting step-down transformer", "MCC7", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["MCC7-OG-FLARESTACK", "GEPL & BF1 Flarestack Supply", "Feeder", "Emergency flarestack pilot ignition & blower feed", "MCC7", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["MCC7-OG-BF-COMP", "O/G to BF Compressor MCC", "Feeder", "Feeder to BF auxiliary air compressor panel", "MCC7", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["MCC7-SPARE-1", "Spare Feeder 1", "Spare", "Spare breaker cubicle", "MCC7", "MAIN", "OPEN", "", "VAB", "PIPL"],
        ["MCC7-OG-BLOWER-LDB", "O/G to BF1 Blower House LDB", "Feeder", "Lighting and auxiliary distribution board for blower building", "MCC7", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["MCC7-OG-230V-BLOWER", "230V AC Supply for BF1 3.3KV Blower Panel", "Feeder", "Auxiliary 230V AC control power for 3.3kV blower control circuits", "MCC7", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["MCC7-OG-MCC1", "O/G to MCC1", "Feeder", "Sub-distribution feeder to MCC 1", "MCC7", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["MCC7-SPARE-2", "Spare Feeder 2", "Spare", "Spare breaker cubicle", "MCC7", "MAIN", "OPEN", "", "VAB", "PIPL"],
        ["MCC7-OG-BLOWER-DAMPER", "O/G to BF1 Blower Damper MCC", "Feeder", "Motorized damper actuator control MCC", "MCC7", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["MCC7-OG-BF1-IVC", "O/G to BF1 IVC (Inlet Valve Control) Panel", "Feeder", "Variable inlet guide vane (IVC) motorized actuator power", "MCC7", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["MCC7-OG-CAT-DG-ACC", "O/G to CAT DG ACC MCC", "Feeder", "Auxiliary radiator fan and lube pump MCC for CAT DG sets", "MCC7", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["MCC7-OG-RWP-STAR-DELTA", "O/G to BF1 RWP 1 & 2 Star Delta Panel", "Feeder", "Feeder to star-delta starters for water pumps 1 & 2", "MCC7", "MAIN", "CLOSED", "", "VAB", "PIPL"],

        # MCC10
        ["MCC10-IC-1", "I/C 1 From PCC1 Section B", "Incomer", "Primary incomer from 415V LT PCC1 Section 2", "MCC10", "MAIN", "CLOSED", "PCC1-OG-MCC10-IC1", "VAB", "PIPL"],
        ["MCC10-TIE-MCC7", "I/C 2 From MCC 7 Or O/G to MCC 10", "Tie", "Counterpart bidirectional tie line connecting to MCC7", "MCC10", "MAIN", "OPEN", "MCC7-TIE-MCC10", "VAB", "PIPL"],
        ["MCC10-OG-MDC1-IC2", "O/G to MDC1 I/C 2", "Feeder", "Feeder supplying secondary incomer 2 on MDC1 LT Panel", "MCC10", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["MCC10-OG-FIRE-HYDRANT", "O/G to Fire Hydrant MCC", "Feeder", "Main fire water jockey pump and diesel engine auxiliary MCC", "MCC10", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["MCC10-SPARE-1", "Spare Feeder 1", "Spare", "Spare breaker cubicle", "MCC10", "MAIN", "OPEN", "", "VAB", "PIPL"],
        ["MCC10-SPARE-2", "Spare Feeder 2", "Spare", "Spare breaker cubicle", "MCC10", "MAIN", "OPEN", "", "VAB", "PIPL"],
        ["MCC10-OG-KAESSER-COMP", "KAESSER Compressor 2 Air Dryer", "Feeder", "Power supply to Kaesser compressor and refrigerant dryer 2", "MCC10", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["MCC10-OG-BF1-OCS", "O/G to BF1 OCS Panel", "Feeder", "Operator control station and SCADA telemetry panel", "MCC10", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["MCC10-OG-PLANT5-SLAG", "O/G to Plant-5 + Slag Granulation C/O Switch", "Feeder", "Power supply to Plant 5 and slag granulation changeover switch", "MCC10", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["MCC10-OG-MCC9-SEC2", "O/G to MCC9 Section 2", "Feeder", "Sub-distribution feeder to MCC9 section 2", "MCC10", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["MCC10-OG-MCC10N", "O/G to MCC-10N", "Feeder", "Sub-distribution feeder to MCC-10N", "MCC10", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["MCC10-OG-MUDGUN-DRILL", "O/G to BF1 Mudgun/Drill Machine", "Feeder", "Taphole closing mudgun and pneumatic opening drill hydraulic power unit", "MCC10", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["MCC10-OG-DS-MCC2", "O/G to DS MCC 2", "Feeder", "Desulphurization plant auxiliary MCC 2", "MCC10", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["MCC10-OG-DIESEL-UNLOAD", "O/G to Diesel unloading Pump1 & 2", "Feeder", "Fuel unloading pumps 1 & 2 for captive DG fuel tank farm", "MCC10", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["MCC10-OG-BF1-RWP2", "O/G to BF1 RWP2 (MCC10 - 2F1)", "Feeder", "Direct motor feed to recirculating water pump 2", "MCC10", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["MCC10-SPARE-3", "Spare Feeder 3", "Spare", "Spare breaker cubicle", "MCC10", "MAIN", "OPEN", "", "VAB", "PIPL"],

        # MDC 1 LT PANEL
        ["MDC1-IC-1", "I/C 1 From LT PCC1 Section A", "Incomer", "Primary incoming feeder from PCC1 Section 1", "MDC1-LT-PANEL", "MAIN", "CLOSED", "PCC1-OG-MDC1-IC1", "VAB", "PIPL"],
        ["MDC1-IC-2", "I/C 2 From MCC 10", "Incomer", "Secondary incoming feeder from MCC10", "MDC1-LT-PANEL", "MAIN", "CLOSED", "MCC10-OG-MDC1-IC2", "VAB", "PIPL"],
        ["MDC1-OG-MCC9-SEC1", "O/G to MCC9 Section 1", "Feeder", "Feeder to MCC9 section 1", "MDC1-LT-PANEL", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["MDC1-OG-BF1-HBS", "O/G to BF1 HBS MCC", "Feeder", "Hot blast stove auxiliary machinery MCC", "MDC1-LT-PANEL", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["MDC1-OG-MCC2", "O/G to MCC 2", "Feeder", "Sub-distribution feeder to MCC 2", "MDC1-LT-PANEL", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["MDC1-OG-HARM-FILTER", "O/G to 200KVAR Harmonic Filter + SGP C/O", "Feeder", "Feeder to 200kVAR capacitor filter panel with SGP changeover", "MDC1-LT-PANEL", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["MDC1-OG-BF1-RWP-VFD", "O/G to BF1 RWP VFD", "Feeder", "Variable frequency drive for recirculating water pump 1", "MDC1-LT-PANEL", "MAIN", "CLOSED", "", "VAB", "PIPL"],

        # MDC-1 HARMONIC FILTER
        ["MDC1-HARM-IC", "I/C From MDC-1", "Incomer", "Incoming power from MDC1", "MDC1-HARM-FILTER", "MAIN", "CLOSED", "MDC1-OG-HARM-FILTER", "VAB", "PIPL"],
        ["HARM-CAP-1", "Capacitor Bank 1 (50kVAR)", "Feeder", "50kVAR capacitor step with detuning reactor", "MDC1-HARM-FILTER", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["HARM-CAP-2", "Capacitor Bank 2 (50kVAR)", "Feeder", "50kVAR capacitor step with detuning reactor", "MDC1-HARM-FILTER", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["HARM-CAP-3", "Capacitor Bank 3 (50kVAR)", "Feeder", "50kVAR capacitor step with detuning reactor", "MDC1-HARM-FILTER", "MAIN", "CLOSED", "", "VAB", "PIPL"],
        ["HARM-CAP-4", "Capacitor Bank 4 (50kVAR)", "Feeder", "50kVAR capacitor step with detuning reactor", "MDC1-HARM-FILTER", "MAIN", "CLOSED", "", "VAB", "PIPL"]
    ]
    style_table(ws_fdr, start_row=1, header_bg=navy_dark, headers=fdr_headers, data=fdr_data,
                table_name="Feeders", column_widths=[22, 35, 14, 45, 20, 12, 14, 24, 12, 12])

    # Col C (3): type -> Feeder Type dropdown
    add_list_validation(ws_fdr, "C2:C1000", '"Incomer,Feeder,Bus Coupler,Tie,Spare"', "Feeder Type", "Select Feeder Type")
    # Col E (5): panelId -> =INDIRECT("Panels[id]")
    add_list_validation(ws_fdr, "E2:E1000", '=INDIRECT("Panels[id]")', "Panel", "Select hosting Panel (panelId)")
    # Col F (6): busSection -> MAIN, SEC-1, SEC-2, SEC-1 & 2
    add_list_validation(ws_fdr, "F2:F1000", '"MAIN,SEC-1,SEC-2,SEC-1 & 2"', "Bus Section", "Select Bus Section")
    # Col G (7): operatingState -> CLOSED vs OPEN vs TRIPPED
    add_list_validation(ws_fdr, "G2:G1000", '"CLOSED,OPEN,TRIPPED"', "State", "Select Operating State")
    # Col H (8): upstreamFeederId -> =INDIRECT("Feeders[id]")
    add_list_validation(ws_fdr, "H2:H1000", '=INDIRECT("Feeders[id]")', "Upstream Source Feeder", "Select Upstream Feeder ID")
    # Col I (9): plantId -> PlantsList dropdown
    add_list_validation(ws_fdr, "I2:I1000", "=PlantsList", "Plant", "Select Operating Plant")
    # Col J (10): unitId -> Dependent on Col I (plantId)
    add_list_validation(ws_fdr, "J2:J1000", "=INDIRECT(I2)", "Unit", "Select Unit under Plant")

    # =========================================================================
    # SHEET 5: Transformers
    # =========================================================================
    ws_tr = wb.create_sheet(title="Transformers")
    ws_tr.views.sheetView[0].showGridLines = True
    tr_headers = [
        "id", "name", "windingType", "ratingKva", 
        "primaryVoltage", "secondaryVoltage", "tertiaryVoltage", 
        "primarySourceFeederId", "secondaryTargetPanelId", "tertiaryTargetPanelId", "locationId", "plantId", "unitId"
    ]
    tr_data = [
        ["TR-5.5MVA-1", "5.5MVA Transformer 1", "three_winding", 5500, "11kV", "3.3kV", "415V", "HTPCC-OG-TR-55-1", "33KV-BF1-BLOWER", "415V-LT-PCC1", "SUBSTATION-YARD", "VAB", "PIPL"],
        ["TR-5.5MVA-2", "5.5MVA Transformer 2", "three_winding", 5500, "11kV", "3.3kV", "415V", "HTPCC-OG-TR-55-2", "33KV-BF2-BLOWER", "415V-LT-PCC1", "SUBSTATION-YARD", "VAB", "PIPL"],
        ["TR-4MVA", "4MVA Transformer", "three_winding", 4000, "11kV", "415V", "3.3kV", "HTPCC-OG-TR-4MVA", "415V-LT-PCC2", "", "SUBSTATION-YARD", "VAB", "PIPL"],
        ["TR-1MVA-BH", "1MVA Transformer (BF2 Bag House)", "two_winding", 1000, "11kV", "415V", "", "HTPCC-OG-TR-BF2-BH", "BF2-CT-MCC", "", "SUBSTATION-YARD", "VAB", "PIPL"]
    ]
    style_table(ws_tr, start_row=1, header_bg=navy_dark, headers=tr_headers, data=tr_data,
                table_name="Transformers", column_widths=[18, 35, 15, 12, 14, 14, 14, 24, 24, 24, 22, 12, 12])

    # Col C (3): windingType
    add_list_validation(ws_tr, "C2:C1000", '"two_winding,three_winding"', "Winding Type", "Select Transformer Winding Type")
    # Col E (5): primaryVoltage
    add_list_validation(ws_tr, "E2:E1000", '"11kV,22kV,33kV,66kV,110kV,132kV,220kV,6.6kV,3.3kV,415V"', "Primary Voltage", "Select Primary Voltage")
    # Col F (6): secondaryVoltage
    add_list_validation(ws_tr, "F2:F1000", '"3.3kV,415V,6.6kV,11kV,22kV,33kV"', "Secondary Voltage", "Select Secondary Voltage")
    # Col G (7): tertiaryVoltage
    add_list_validation(ws_tr, "G2:G1000", '"None,415V,3.3kV,6.6kV,11kV"', "Tertiary Voltage", "Select Tertiary Voltage or None")
    # Col H (8): primarySourceFeederId -> =INDIRECT("Feeders[id]")
    add_list_validation(ws_tr, "H2:H1000", '=INDIRECT("Feeders[id]")', "Primary Feeder", "Select Upstream HT Feeder")
    # Col I (9): secondaryTargetPanelId -> =INDIRECT("Panels[id]")
    add_list_validation(ws_tr, "I2:I1000", '=INDIRECT("Panels[id]")', "Secondary Target Panel", "Select Secondary Switchboard")
    # Col J (10): tertiaryTargetPanelId -> =INDIRECT("Panels[id]")
    add_list_validation(ws_tr, "J2:J1000", '=INDIRECT("Panels[id]")', "Tertiary Target Panel", "Select Tertiary Switchboard")
    # Col K (11): locationId -> =INDIRECT("Locations[id]")
    add_list_validation(ws_tr, "K2:K1000", '=INDIRECT("Locations[id]")', "Switchyard Location", "Select outdoor Switchyard Area")
    # Col L (12): plantId -> PlantsList dropdown
    add_list_validation(ws_tr, "L2:L1000", "=PlantsList", "Plant", "Select Operating Plant")
    # Col M (13): unitId -> Dependent on Col L (plantId)
    add_list_validation(ws_tr, "M2:M1000", "=INDIRECT(L2)", "Unit", "Select Unit under Plant")

    # =========================================================================
    # SHEET 6: Master_Equipment
    # =========================================================================
    ws_me = wb.create_sheet(title="Master_Equipment")
    ws_me.views.sheetView[0].showGridLines = True
    me_headers = ["id", "name", "type", "description", "locationId", "panelRoomId", "panelId", "feederId", "plantId", "unitId"]
    me_data = [
        # BF1 3.3kV Blowers
        ["BF1-BLOWER-B6", "BF1 Main Air Blower B6", "Blower", "High pressure cold blast blower B6 with PFC capacitor", "BF1-BLOWER-AREA", "BF1-BLOWER-ROOM", "33KV-BF1-BLOWER", "BF1-33KV-FDR-B6", "VAB", "PIPL"],
        ["BF1-BLOWER-B3", "BF1 Main Air Blower B3", "Blower", "High pressure cold blast blower B3 with PFC capacitor", "BF1-BLOWER-AREA", "BF1-BLOWER-ROOM", "33KV-BF1-BLOWER", "BF1-33KV-FDR-B3", "VAB", "PIPL"],
        ["BF1-BLOWER-B5", "BF1 Main Air Blower B5", "Blower", "High pressure cold blast blower B5 with PFC capacitor", "BF1-BLOWER-AREA", "BF1-BLOWER-ROOM", "33KV-BF1-BLOWER", "BF1-33KV-FDR-B5", "VAB", "PIPL"],
        ["BF1-BLOWER-B1", "BF1 Auxiliary Air Blower B1", "Blower", "Auxiliary blast blower B1 with PFC capacitor", "BF1-BLOWER-AREA", "BF1-BLOWER-ROOM", "33KV-BF1-BLOWER", "BF1-33KV-FDR-B1", "VAB", "PIPL"],
        ["BF1-BLOWER-B4", "BF1 Main Air Blower B4", "Blower", "High pressure cold blast blower B4 on Section 2", "BF1-BLOWER-AREA", "BF1-BLOWER-ROOM", "33KV-BF1-BLOWER", "BF1-33KV-FDR-B4", "VAB", "PIPL"],
        ["BF1-BLOWER-B2", "BF1 Main Air Blower B2", "Blower", "High pressure cold blast blower B2 on Section 2", "BF1-BLOWER-AREA", "BF1-BLOWER-ROOM", "33KV-BF1-BLOWER", "BF1-33KV-FDR-B2", "VAB", "PIPL"],

        # BF2 3.3kV Blowers
        ["BF2-BLOWER-B5", "BF2 Main Air Blower B5", "Blower", "BF2 Cold blast blower B5 with PFC capacitor", "BF2-BLOWER-AREA", "BF2-BLOWER-ROOM", "33KV-BF2-BLOWER", "BF2-33KV-FDR-B5", "VAB", "PIPL"],
        ["BF2-BLOWER-B4", "BF2 Main Air Blower B4", "Blower", "BF2 Cold blast blower B4 with PFC capacitor", "BF2-BLOWER-AREA", "BF2-BLOWER-ROOM", "33KV-BF2-BLOWER", "BF2-33KV-FDR-B4", "VAB", "PIPL"],
        ["BF2-BLOWER-B6", "BF2 Main Air Blower B6", "Blower", "BF2 Cold blast blower B6 on Section 2", "BF2-BLOWER-AREA", "BF2-BLOWER-ROOM", "33KV-BF2-BLOWER", "BF2-33KV-FDR-B6", "VAB", "PIPL"],
        ["BF2-BLOWER-B3", "BF2 Main Air Blower B3", "Blower", "BF2 Cold blast blower B3 on Section 2", "BF2-BLOWER-AREA", "BF2-BLOWER-ROOM", "33KV-BF2-BLOWER", "BF2-33KV-FDR-B3", "VAB", "PIPL"],
        ["BF2-BLOWER-B2", "BF2 Main Air Blower B2", "Blower", "BF2 Cold blast blower B2 on Section 2", "BF2-BLOWER-AREA", "BF2-BLOWER-ROOM", "33KV-BF2-BLOWER", "BF2-33KV-FDR-B2", "VAB", "PIPL"],
        ["BF2-BLOWER-B1", "BF2 Auxiliary Air Blower B1", "Blower", "BF2 Auxiliary blast blower B1 on Section 2", "BF2-BLOWER-AREA", "BF2-BLOWER-ROOM", "33KV-BF2-BLOWER", "BF2-33KV-FDR-B1", "VAB", "PIPL"],

        # PCI Machinery
        ["PCI-ROTARY-3-4", "PCI Rotary Feeder Drive Pair 3 & 4", "Motor", "Dual variable speed pulverized coal injection rotary feeders", "PCI-PLANT-AREA", "PCI-ELECTRICAL-ROOM", "PCI-MCC", "PCI-OG-ROTARY-3-4", "VAB", "PIPL"],
        ["PCI-ROTARY-1-2", "PCI Rotary Feeder Drive Pair 1 & 2", "Motor", "Dual variable speed pulverized coal injection rotary feeders", "PCI-PLANT-AREA", "PCI-ELECTRICAL-ROOM", "PCI-MCC", "PCI-OG-ROTARY-1-2", "VAB", "PIPL"],
        ["PCI-COMP4-DRIERS", "PCI Screw Compressor 4 & Air Driers 1-4", "Compressor", "High pressure screw compressor 4 and desiccant dryers", "PCI-PLANT-AREA", "PCI-ELECTRICAL-ROOM", "PCI-MCC", "PCI-OG-COMP4-DRIERS", "VAB", "PIPL"],
        ["PCI-COMP-1-2-3", "PCI Main Process Compressors 1, 2, 3", "Compressor", "Main process carrier gas compressors for coal injection skid", "PCI-PLANT-AREA", "PCI-ELECTRICAL-ROOM", "PCI-MCC", "PCI-OG-COMP-1-2-3", "VAB", "PIPL"],

        # Plant Auxiliary Machines
        ["KESAR-COMP-3-DRIER", "KESAR Plant Air Compressor 3 & Drier", "Compressor", "Heavy duty rotary screw plant air compressor 3", "TG-ROOM-AREA", "LT-PCC-ROOM-2", "415V-LT-PCC2", "PCC2-OG-KESAR-COMP", "VAB", "PIPL"],
        ["KAESSER-COMP-2", "KAESSER Compressor 2 & Air Dryer", "Compressor", "Instrument air compressor package with refrigerant dryer", "BF1-BLOWER-AREA", "BF1-BLOWER-ROOM", "MCC10", "MCC10-OG-KAESSER-COMP", "VAB", "PIPL"],
        ["BF1-RWP-PUMP-2", "BF1 Recirculating Water Pump 2 (MCC10-2F1)", "Pump", "Heavy duty cooling loop recirculating water pump 2", "WATER-PUMP-HOUSE", "BF1-BLOWER-ROOM", "MCC10", "MCC10-OG-BF1-RWP2", "VAB", "PIPL"],
        ["BF1-RWP-VFD-DRIVE", "BF1 Recirculating Water Pump 1 VFD", "Pump", "Variable frequency driven main recirculating water pump 1", "WATER-PUMP-HOUSE", "BF1-BLOWER-ROOM", "MDC1-LT-PANEL", "MDC1-OG-BF1-RWP-VFD", "VAB", "PIPL"],
        ["BF1-MUDGUN-DRILL", "BF1 Taphole Mudgun & Drill Machine", "Machinery", "Cast house electro-hydraulic taphole mudgun and tapping drill", "BF1-CAST-HOUSE", "BF1-BLOWER-ROOM", "MCC10", "MCC10-OG-MUDGUN-DRILL", "VAB", "PIPL"],
        ["DIESEL-UNLOAD-PUMPS", "Fuel Farm Diesel Unloading Pumps 1 & 2", "Pump", "Bulk fuel delivery unloading transfer pumps for CAT DG day tanks", "SUBSTATION-YARD", "BF1-BLOWER-ROOM", "MCC10", "MCC10-OG-DIESEL-UNLOAD", "VAB", "PIPL"],
        ["BF1-IVC-PANEL", "BF1 Blower Inlet Valve Control (IVC) Actuator", "Valve", "Motorized inlet guide vane precision positioning actuator", "BF1-BLOWER-AREA", "BF1-BLOWER-ROOM", "MCC7", "MCC7-OG-BF1-IVC", "VAB", "PIPL"],
        ["BF1-FLARESTACK", "GEPL & BF1 Flarestack Ignition Skid", "Other", "Emergency flarestack continuous pilot gas system and blowers", "BF1-CAST-HOUSE", "BF1-BLOWER-ROOM", "MCC7", "MCC7-OG-FLARESTACK", "VAB", "PIPL"],
        ["BF2-BLOWER-OCS", "BF2 Blower Operator Control Station", "Control Panel", "Central DCS/SCADA console and telemetry rack for BF2 blowers", "BF2-BLOWER-AREA", "BF2-BATTERY-ROOM", "BF2-110V-DC-BATT-PANEL", "BF2-BATT-OG-BLOWER-OCS", "VAB", "PIPL"]
    ]
    style_table(ws_me, start_row=1, header_bg=navy_dark, headers=me_headers, data=me_data,
                table_name="Master_Equipment", column_widths=[22, 38, 14, 52, 20, 20, 22, 24, 12, 12])

    # Col C (3): type -> Equipment Type dropdown
    add_list_validation(ws_me, "C2:C1000", '"Conveyor,Pump,Compressor,Drier,Fan,Blower,Motor,Valve,Sensor,Transformer,Switchgear,Crane,Hoist,Heater,Cooler,Chiller,Mixer,Agitator,Boiler,Turbine,Generator,Separator,Filter,Extruder,Press,Lathe,Mill,Robot,Control Panel,Machinery,Other"', "Equipment Type", "Select Equipment Classification")
    # Col E (5): locationId -> =INDIRECT("Locations[id]")
    add_list_validation(ws_me, "E2:E1000", '=INDIRECT("Locations[id]")', "Physical Area", "Select Location (locationId)")
    # Col F (6): panelRoomId -> =INDIRECT("Panel_Rooms[id]")
    add_list_validation(ws_me, "F2:F1000", '=INDIRECT("Panel_Rooms[id]")', "Panel Room", "Select Substation (panelRoomId)")
    # Col G (7): panelId -> =INDIRECT("Panels[id]")
    add_list_validation(ws_me, "G2:G1000", '=INDIRECT("Panels[id]")', "Panel", "Select Panel (panelId)")
    # Col H (8): feederId -> =INDIRECT("Feeders[id]")
    add_list_validation(ws_me, "H2:H1000", '=INDIRECT("Feeders[id]")', "Feeder", "Select Feeder (feederId)")
    # Col I (9): plantId -> PlantsList dropdown
    add_list_validation(ws_me, "I2:I1000", "=PlantsList", "Plant", "Select Operating Plant")
    # Col J (10): unitId -> Dependent on Col I (plantId)
    add_list_validation(ws_me, "J2:J1000", "=INDIRECT(I2)", "Unit", "Select Unit under Plant")

    # Reorder sheets: 6 Pure Hierarchy Data sheets + hidden _Config
    wb._sheets = [ws_loc, ws_pr, ws_pnl, ws_fdr, ws_tr, ws_me, ws_cfg]
    wb.active = ws_loc

    # Save workbook
    wb.save(file_path)
    _post_process_excel_zip(file_path)
    print(f"Excel workbook successfully regenerated and optimized at: {file_path}")

def _post_process_excel_zip(path):
    import zipfile, io, re
    with open(path, "rb") as f:
        in_bytes = f.read()
    zin = zipfile.ZipFile(io.BytesIO(in_bytes), "r")
    out_buf = io.BytesIO()
    with zipfile.ZipFile(out_buf, "w", zipfile.ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            data = zin.read(item.filename)
            if item.filename == "xl/_rels/workbook.xml.rels":
                text = data.decode("utf-8")
                text = text.replace('Target="/xl/worksheets/', 'Target="worksheets/')
                text = text.replace("Target='/xl/worksheets/", "Target='worksheets/")
                data = text.encode("utf-8")
            elif item.filename.startswith("xl/worksheets/sheet") and item.filename.endswith(".xml"):
                text = data.decode("utf-8")
                text = re.sub(r'(<c\b[^>]*?)\s+t="inlineStr"([^>]*?/>)', r'\1\2', text)
                text = re.sub(r'(<c\b[^>]*?)\s+t="inlineStr"([^>]*?>)<is/></c>', r'\1\2</c>', text)
                text = re.sub(r'(<c\b[^>]*?)\s+t="inlineStr"([^>]*?>)<is><t/></is></c>', r'\1\2</c>', text)
                text = re.sub(r'(<c\b[^>]*?)\s+t="inlineStr"([^>]*?>)<is><t></t></is></c>', r'\1\2</c>', text)
                data = text.encode("utf-8")
            zout.writestr(item, data)
    with open(path, "wb") as f:
        f.write(out_buf.getvalue())

if __name__ == "__main__":
    out_path = os.path.abspath("AssetPulse_Electrical_Hierarchy_Import.xlsx")
    try:
        build_excel_workbook(out_path)
    except PermissionError:
        fallback_path = os.path.abspath("AssetPulse_Electrical_Hierarchy_Import_Clean.xlsx")
        build_excel_workbook(fallback_path)
