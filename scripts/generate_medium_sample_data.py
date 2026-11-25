import os
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

def create_hierarchy_excel(output_path):
    wb = openpyxl.Workbook()
    wb.remove(wb.active)  # remove default Sheet

    # Colors & Fonts
    c_navy = "0F172A"       # Headers
    c_blue = "1E3A8A"       # Accent headers
    c_teal = "0D9488"
    c_purple = "6D28D9"
    c_amber = "D97706"
    c_border = "CBD5E1"
    c_zebra = "F8FAFC"

    font_header = Font(name="Calibri", size=11, bold=True, color="FFFFFF")
    font_cell = Font(name="Calibri", size=10, color="1E293B")
    thin_border = Border(
        left=Side(style='thin', color=c_border),
        right=Side(style='thin', color=c_border),
        top=Side(style='thin', color=c_border),
        bottom=Side(style='thin', color=c_border)
    )

    def write_sheet(title, headers, rows, header_color=c_navy):
        ws = wb.create_sheet(title=title)
        # Write headers
        for col_idx, h in enumerate(headers, 1):
            cell = ws.cell(row=1, column=col_idx, value=h)
            cell.font = font_header
            cell.fill = PatternFill(start_color=header_color, end_color=header_color, fill_type="solid")
            cell.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
            cell.border = thin_border
        ws.row_dimensions[1].height = 28

        # Write data rows
        for r_idx, row_data in enumerate(rows, 2):
            bg = c_zebra if (r_idx % 2 == 0) else "FFFFFF"
            for col_idx, raw_val in enumerate(row_data, 1):
                val = None if (raw_val == "" or raw_val is None) else raw_val
                cell = ws.cell(row=r_idx, column=col_idx, value=val)
                cell.font = font_cell
                cell.fill = PatternFill(start_color=bg, end_color=bg, fill_type="solid")
                cell.border = thin_border
                if isinstance(val, (int, float)):
                    cell.alignment = Alignment(horizontal="right", vertical="center")
                elif col_idx in [1, 3, 5]:
                    cell.alignment = Alignment(horizontal="center", vertical="center")
                else:
                    cell.alignment = Alignment(horizontal="left", vertical="center")
            ws.row_dimensions[r_idx].height = 20

        # Auto-adjust column widths
        for col_idx, h in enumerate(headers, 1):
            max_len = len(str(h))
            for row_data in rows:
                if col_idx - 1 < len(row_data) and row_data[col_idx - 1] is not None:
                    max_len = max(max_len, len(str(row_data[col_idx - 1])))
            col_letter = get_column_letter(col_idx)
            ws.column_dimensions[col_letter].width = min(max(max_len + 3, 14), 45)

        return ws

    # 1. Physical Areas
    areas_headers = ['id', 'name', 'description']
    areas_data = [
        ['PRIMARY-SUBSTATION', 'Primary 33kV/11kV Substation & Switchyard', 'Central utility receiving substation, transformer yard, and HT switchgear rooms'],
        ['CRUSHING-BENEF', 'Primary Crushing & Beneficiation Plant Area', 'Primary jaw crushers, mineral sizers, ball mills, and spiral separation units'],
        ['SCREENING-PLANT', 'Secondary Screening & Sizing Station', 'Multi-deck vibrating banana screens, sizing screens, and product surge bins'],
        ['TAILINGS-DISPOSAL', 'Tailings Thickening & Dewatering Plant', 'High-rate slurry thickeners, membrane filter presses, and dry tailings cakes'],
        ['WATER-TREATMENT', 'Raw Water & Process Water Pump House', 'Main reservoir intake, water circulation pump house, and clarifier tanks'],
        ['DISPATCH-AREA', 'Ore Dispatch & Rapid Wagon Loading Terminal', 'Finished ore reclaim conveyors, shuttle boom, and rapid train loading terminal'],
        ['YARD-AREA', 'Outdoor Transformer & Switchyard Yard', 'Outdoor plinths housing step-down power transformers, bay isolators, and earthing'],
    ]
    write_sheet('Physical Areas', areas_headers, areas_data, c_navy)

    # 2. Panel Rooms
    rooms_headers = ['id', 'name', 'description', 'locationId']
    rooms_data = [
        ['SUB-ROOM-01', 'Main 11kV HT Substation Room', 'Houses 11kV VCB switchgear panels, incomers, bus couplers, and metering cubicles', 'PRIMARY-SUBSTATION'],
        ['LT-ROOM-01', 'Central LT Switchgear Room 1', 'Houses 415V LT PCC-1 split-bus switchboard, LDB, and APFC capacitor panels', 'PRIMARY-SUBSTATION'],
        ['BATT-ROOM-01', 'Substation Battery & DC Control Room', 'Houses 110V DC battery bank, dual float-cum-boost chargers, and DC tripping boards', 'PRIMARY-SUBSTATION'],
        ['MV-ROOM-01', 'Beneficiation 3.3kV MV Compressor & Mill Room', 'Houses 3.3kV VCB switchgear panels powering primary jaw crushers and ball mills', 'CRUSHING-BENEF'],
        ['MCC-ROOM-01', 'Crushing Substation MCC Room 1', 'Houses 415V MCC-01 powering apron feeders, primary conveyors, and secondary sizers', 'CRUSHING-BENEF'],
        ['ECR-ROOM-02', 'Beneficiation Electrical Control Room (ECR-2)', 'Houses 415V LT PCC-2, APFC bank, and plant DCS / PLC remote I/O racks', 'CRUSHING-BENEF'],
        ['MCC-ROOM-02', 'Screen House Electrical Substation 2', 'Houses 415V MCC-02 powering vibrating screens, product conveyors, and outgoers', 'SCREENING-PLANT'],
        ['MCC-ROOM-03', 'Spiral Plant Substation Room 3', 'Houses 415V MCC-03 powering heavy slurry feed pumps, cyclones, and magnetic separators', 'CRUSHING-BENEF'],
        ['MCC-ROOM-04', 'Tailings Filtration MCC Room 4', 'Houses 415V MCC-04 powering filter press hydraulic packs and thickener drives', 'TAILINGS-DISPOSAL'],
        ['WTP-PUMP-ROOM', 'Water Treatment Electrical Control Room', 'Houses 415V LT WTP-PCC and dual-sourced MCC-05 process water pump station', 'WATER-TREATMENT'],
        ['DISPATCH-ROOM', 'Wagon Loading Electrical Cabin', 'Houses cascaded 415V MCC-06 controlling train loading boom and chute positioners', 'DISPATCH-AREA'],
    ]
    write_sheet('Panel Rooms', rooms_headers, rooms_data, c_blue)

    # 3. Panels
    panels_headers = ['id', 'name', 'type', 'description', 'panelRoomId', 'voltageLevel', 'busSections']
    panels_data = [
        ['11KV-HT-SWG', '11kV Primary HT Switchgear Panel', 'PCC', 'Dual 11kV grid incomers, dual DG backup incomers, bus coupler & transformer feeders', 'SUB-ROOM-01', '11kV', 'SEC-1, SEC-2'],
        ['3.3KV-MV-SWG', '3.3kV Medium Voltage Motor Control Switchgear', 'PCC', 'Heavy drive switchgear fed from TR-01 & TR-02 secondary windings with bus coupler', 'MV-ROOM-01', '3.3kV', 'SEC-1, SEC-2'],
        ['415V-LT-PCC1', '415V Main Plant Power Control Center 1', 'PCC', 'Split-bus switchboard fed from TR-01 & TR-02 tertiary windings with bus coupler & emergency DG', 'LT-ROOM-01', '415V', 'SEC-1, SEC-2'],
        ['415V-LT-PCC2', '415V Beneficiation & Dewatering Power Control Center 2', 'PCC', 'Split-bus switchboard fed from TR-03 & TR-04 with bus coupler and inter-PCC tie feed from PCC-1', 'ECR-ROOM-02', '415V', 'SEC-1, SEC-2'],
        ['415V-LT-WTP-PCC', '415V Water Treatment & Pumping PCC', 'PCC', 'Single bus switchboard fed from 1.0MVA Transformer TR-05', 'WTP-PUMP-ROOM', '415V', 'MAIN'],
        ['MCC-01-CRUSH', 'Primary Crushing & Conveying 415V MCC', 'MCC', 'Fed from PCC-1 SEC-1 with bidirectional tie breaker to MCC-02 for back charging redundancy', 'MCC-ROOM-01', '415V', 'MAIN'],
        ['MCC-02-SCREEN', 'Secondary Screening & Sizing 415V MCC', 'MCC', 'Fed from PCC-1 SEC-2 with bidirectional tie breaker to MCC-01 and cascading outgoer to MCC-06', 'MCC-ROOM-02', '415V', 'MAIN'],
        ['MCC-03-BENEF', 'Spiral Beneficiation & Slurry 415V MCC', 'MCC', 'Fed from PCC-2 SEC-1 powering heavy slurry pumps, cyclones, and wet magnetic separators', 'MCC-ROOM-03', '415V', 'MAIN'],
        ['MCC-04-TAIL', 'Tailings Filtration & Dewatering 415V MCC', 'MCC', 'Fed from PCC-2 SEC-2 powering filter presses with auxiliary emergency tie outgoer to MCC-05', 'MCC-ROOM-04', '415V', 'MAIN'],
        ['MCC-05-PUMP', 'Main Process Water Pumping Station 415V MCC', 'MCC', 'Dual-sourced MCC: primary feed from WTP-PCC and alternate emergency feed from MCC-04', 'WTP-PUMP-ROOM', '415V', 'MAIN'],
        ['MCC-06-DISP', 'Wagon Loading Terminal 415V MCC', 'MCC', 'Cascaded sub-MCC fed directly from upstream feeder of MCC-02-SCREEN', 'DISPATCH-ROOM', '415V', 'MAIN'],
        ['110V-DC-CHG-PNL', '110V DC Float-cum-Boost Battery Charger Panel', 'Control Panel', 'Dual thyristor charger with 415V AC input from PCC-1 SEC-2 and DC output to distribution board', 'BATT-ROOM-01', '415V', 'MAIN'],
        ['110V-DC-DIST-BD', '110V DC Switchgear Protection & Tripping Distribution Board', 'Control Panel', 'Dual-incomer DC switchboard fed from charger and battery bank supplying breaker trip coils', 'BATT-ROOM-01', '110V DC', 'MAIN'],
        ['LDB-01-SUB', 'Substation Main Lighting Distribution Board', 'LDB', '415V/230V lighting board fed from PCC-1 SEC-1 supplying control room and high mast yard lights', 'LT-ROOM-01', '415V', 'MAIN'],
    ]
    write_sheet('Panels', panels_headers, panels_data, c_teal)

    # 4. Feeders
    feeders_headers = ['id', 'name', 'type', 'description', 'panelId', 'busSection', 'operatingState', 'upstreamFeederId']
    feeders_data = [
        # 11kV HT Switchgear
        ['11KV-INC-01', '2000A Incomer 1 from GEPL 33/11kV Grid Line 1', 'Incomer', '11kV 25kA VCB breaker incomer on Section 1', '11KV-HT-SWG', 'SEC-1', 'CLOSED', 'GRID-LINE-01'],
        ['11KV-INC-02', '2000A Incomer 2 from State Grid 33/11kV Line 2', 'Incomer', '11kV 25kA VCB breaker incomer on Section 2', '11KV-HT-SWG', 'SEC-2', 'CLOSED', 'GRID-LINE-02'],
        ['11KV-BC-01', '11kV Bus Coupler Breaker BC-01', 'Bus Coupler', 'Couples 11kV Section 1 and Section 2 busbars', '11KV-HT-SWG', 'SEC-1, SEC-2', 'OPEN', ''],
        ['11KV-DG-INC-01', '1250A Emergency Standby Incomer from DG-1 (2MVA)', 'Incomer', '11kV emergency VCB incomer from CAT DG-1', '11KV-HT-SWG', 'SEC-1', 'OPEN', 'DG-SET-01'],
        ['11KV-DG-INC-02', '1250A Emergency Standby Incomer from DG-2 (2MVA)', 'Incomer', '11kV emergency VCB incomer from CAT DG-2', '11KV-HT-SWG', 'SEC-2', 'OPEN', 'DG-SET-02'],
        ['11KV-OG-TR-01', '630A Outgoing Feeder to Transformer TR-01 (5MVA)', 'Feeder', 'Feeds primary winding of 5MVA 11kV/3.3kV/415V Transformer 1', '11KV-HT-SWG', 'SEC-1', 'CLOSED', ''],
        ['11KV-OG-TR-02', '630A Outgoing Feeder to Transformer TR-02 (5MVA)', 'Feeder', 'Feeds primary winding of 5MVA 11kV/3.3kV/415V Transformer 2', '11KV-HT-SWG', 'SEC-2', 'CLOSED', ''],
        ['11KV-OG-TR-03', '630A Outgoing Feeder to Transformer TR-03 (2.5MVA)', 'Feeder', 'Feeds primary winding of 2.5MVA 11kV/415V Transformer 3', '11KV-HT-SWG', 'SEC-1', 'CLOSED', ''],
        ['11KV-OG-TR-04', '630A Outgoing Feeder to Transformer TR-04 (2.5MVA)', 'Feeder', 'Feeds primary winding of 2.5MVA 11kV/415V Transformer 4', '11KV-HT-SWG', 'SEC-2', 'CLOSED', ''],
        ['11KV-OG-TR-05', '630A Outgoing Feeder to Transformer TR-05 (1MVA)', 'Feeder', 'Feeds primary winding of 1MVA 11kV/415V Transformer 5', '11KV-HT-SWG', 'SEC-1', 'CLOSED', ''],
        ['11KV-SPARE-01', '630A Spare HT Breaker Cubicle', 'Spare', 'Fully equipped spare 11kV VCB cubicle', '11KV-HT-SWG', 'SEC-2', 'OPEN', ''],

        # 3.3kV MV Switchgear
        ['3.3KV-INC-01', '1250A Incomer 1 from TR-01 Secondary Winding', 'Incomer', '3.3kV VCB Incomer 1 fed from TR-01', '3.3KV-MV-SWG', 'SEC-1', 'CLOSED', 'TR-01-5MVA'],
        ['3.3KV-INC-02', '1250A Incomer 2 from TR-02 Secondary Winding', 'Incomer', '3.3kV VCB Incomer 2 fed from TR-02', '3.3KV-MV-SWG', 'SEC-2', 'CLOSED', 'TR-02-5MVA'],
        ['3.3KV-BC-01', '3.3kV Bus Coupler Breaker BC-01', 'Bus Coupler', 'Couples 3.3kV Section 1 and Section 2 busbars', '3.3KV-MV-SWG', 'SEC-1, SEC-2', 'OPEN', ''],
        ['3.3KV-FDR-JAW-CRUSH', '630A Motor Feeder - 450kW Primary Jaw Crusher', 'Feeder', 'VCB with soft starter bypass for 450kW 3.3kV Slip Ring Motor', '3.3KV-MV-SWG', 'SEC-1', 'CLOSED', ''],
        ['3.3KV-FDR-BALL-MILL', '630A Motor Feeder - 630kW Beneficiation Ball Mill', 'Feeder', 'VCB with LRS liquid resistance starter for 630kW 3.3kV Motor', '3.3KV-MV-SWG', 'SEC-2', 'CLOSED', ''],
        ['3.3KV-FDR-MINE-PUMP', '630A Motor Feeder - 350kW Mine Pit Dewatering Pump', 'Feeder', 'Direct-on-line 3.3kV VCB feeder for multi-stage dewatering pump', '3.3KV-MV-SWG', 'SEC-1', 'CLOSED', ''],
        ['3.3KV-FDR-COMP-01', '630A Motor Feeder - 250kW Plant Air Compressor 1', 'Feeder', '3.3kV VCB feeder for central plant centrifugal compressor', '3.3KV-MV-SWG', 'SEC-2', 'CLOSED', ''],

        # 415V LT PCC-1
        ['PCC1-INC-01', '3200A Incomer 1 from TR-01 Tertiary Winding', 'Incomer', '4P 3200A 50kA ACB Incomer 1 on Section 1', '415V-LT-PCC1', 'SEC-1', 'CLOSED', 'TR-01-5MVA'],
        ['PCC1-INC-02', '3200A Incomer 2 from TR-02 Tertiary Winding', 'Incomer', '4P 3200A 50kA ACB Incomer 2 on Section 2', '415V-LT-PCC1', 'SEC-2', 'CLOSED', 'TR-02-5MVA'],
        ['PCC1-BC-01', '3200A LT Bus Coupler Breaker BC-01', 'Bus Coupler', '4P 3200A 50kA ACB bridging PCC-1 Section 1 and Section 2', '415V-LT-PCC1', 'SEC-1, SEC-2', 'OPEN', ''],
        ['PCC1-DG-INC', '1250A Emergency Standby Incomer from 750kVA LT DG', 'Incomer', 'Emergency standby ACB incomer on Section 2', '415V-LT-PCC1', 'SEC-2', 'OPEN', 'LT-DG-SET-01'],
        ['PCC1-OG-MCC-01', '1000A Outgoing Feeder to MCC-01-CRUSH', 'Feeder', '3P 1000A ACB feeder supplying Crushing Substation MCC-01', '415V-LT-PCC1', 'SEC-1', 'CLOSED', ''],
        ['PCC1-OG-MCC-02', '1000A Outgoing Feeder to MCC-02-SCREEN', 'Feeder', '3P 1000A ACB feeder supplying Screen House MCC-02', '415V-LT-PCC1', 'SEC-2', 'CLOSED', ''],
        ['PCC1-OG-PCC2-TIE', '1600A Inter-PCC Tie Outgoing Feeder to PCC-2', 'Tie', 'Provides cross-substation redundancy tie to 415V-LT-PCC2', '415V-LT-PCC1', 'SEC-1', 'CLOSED', ''],
        ['PCC1-OG-DC-CHG', '160A Feeder to 110V DC Battery Charger Panel', 'Feeder', '3P 160A MCCB supplying dual battery charger unit', '415V-LT-PCC1', 'SEC-2', 'CLOSED', ''],
        ['PCC1-OG-LDB-01', '250A Feeder to Substation Lighting Board LDB-01', 'Feeder', '3P 250A MCCB supplying central substation lighting board', '415V-LT-PCC1', 'SEC-1', 'CLOSED', ''],

        # 415V LT PCC-2
        ['PCC2-INC-01', '2500A Incomer 1 from Transformer TR-03', 'Incomer', '4P 2500A 50kA ACB Incomer 1 on Section 1', '415V-LT-PCC2', 'SEC-1', 'CLOSED', 'TR-03-2.5MVA'],
        ['PCC2-INC-02', '2500A Incomer 2 from Transformer TR-04', 'Incomer', '4P 2500A 50kA ACB Incomer 2 on Section 2', '415V-LT-PCC2', 'SEC-2', 'CLOSED', 'TR-04-2.5MVA'],
        ['PCC2-BC-01', '2500A LT Bus Coupler Breaker BC-01', 'Bus Coupler', '4P 2500A 50kA ACB bridging PCC-2 Section 1 and Section 2', '415V-LT-PCC2', 'SEC-1, SEC-2', 'OPEN', ''],
        ['PCC2-TIE-INC', '1600A Alternate Incomer / Tie from PCC-1', 'Tie', '4P 1600A ACB alternate incomer fed from PCC1-OG-PCC2-TIE', '415V-LT-PCC2', 'SEC-1', 'CLOSED', 'PCC1-OG-PCC2-TIE'],
        ['PCC2-OG-MCC-03', '1000A Outgoing Feeder to MCC-03-BENEF', 'Feeder', '3P 1000A ACB feeder supplying Spiral Beneficiation MCC-03', '415V-LT-PCC2', 'SEC-1', 'CLOSED', ''],
        ['PCC2-OG-MCC-04', '1000A Outgoing Feeder to MCC-04-TAIL', 'Feeder', '3P 1000A ACB feeder supplying Tailings Dewatering MCC-04', '415V-LT-PCC2', 'SEC-2', 'CLOSED', ''],
        ['PCC2-OG-CAP-BANK', '630A Feeder to 400kVAR Automatic APFC Capacitor Bank', 'Feeder', '3P 630A MCCB controlling microprocessor switched capacitor steps', '415V-LT-PCC2', 'SEC-2', 'CLOSED', ''],

        # 415V LT WTP PCC
        ['WTP-PCC-INC-01', '1600A Incomer from Transformer TR-05', 'Incomer', '3P 1600A 50kA ACB Incomer from 1.0MVA Transformer 5', '415V-LT-WTP-PCC', 'MAIN', 'CLOSED', 'TR-05-1MVA'],
        ['WTP-OG-MCC-05', '800A Outgoing Feeder to Water Pumping Station MCC-05', 'Feeder', '3P 800A MCCB supplying raw & process water pump station', '415V-LT-WTP-PCC', 'MAIN', 'CLOSED', ''],
        ['WTP-OG-CLARIFIER', '250A Outgoing Feeder to Clarifier Thickener Drives', 'Feeder', '3P 250A MCCB supplying clarifier bridge and chemical dosing', '415V-LT-WTP-PCC', 'MAIN', 'CLOSED', ''],

        # MCC-01-CRUSH
        ['MCC01-INC-01', '1000A Normal Incomer from 415V-LT-PCC1', 'Incomer', '3P 1000A Incomer ACB from PCC1-OG-MCC-01', 'MCC-01-CRUSH', 'MAIN', 'CLOSED', 'PCC1-OG-MCC-01'],
        ['MCC01-TIE-FDR', '630A Bidirectional Tie Breaker to MCC-02-SCREEN', 'Tie', 'Provides back-charging tie redundancy to MCC-02-SCREEN', 'MCC-01-CRUSH', 'MAIN', 'OPEN', 'MCC02-TIE-FDR'],
        ['MCC01-FDR-APRON-FDR', '250A Feeder - 90kW Heavy Duty Ore Apron Feeder', 'Feeder', 'VFD inverter drive starter feeder for variable speed apron feeder', 'MCC-01-CRUSH', 'MAIN', 'CLOSED', ''],
        ['MCC01-FDR-CV-01', '250A Feeder - 110kW Primary Overland Conveyor 1', 'Feeder', 'Soft-starter feeder with contactor bypass for overland belt', 'MCC-01-CRUSH', 'MAIN', 'CLOSED', ''],
        ['MCC01-FDR-SIZER-01', '315A Feeder - 132kW Secondary Mineral Sizer 1', 'Feeder', 'Heavy-duty reversible DOL starter with electronic overload', 'MCC-01-CRUSH', 'MAIN', 'CLOSED', ''],
        ['MCC01-FDR-CRANE-01', '100A Feeder - 40/10T Maintenance EOT Crane', 'Feeder', 'Crane DSL busbar power feeder with isolating switch', 'MCC-01-CRUSH', 'MAIN', 'CLOSED', ''],

        # MCC-02-SCREEN
        ['MCC02-INC-01', '1000A Normal Incomer from 415V-LT-PCC1', 'Incomer', '3P 1000A Incomer ACB from PCC1-OG-MCC-02', 'MCC-02-SCREEN', 'MAIN', 'CLOSED', 'PCC1-OG-MCC-02'],
        ['MCC02-TIE-FDR', '630A Bidirectional Tie Breaker to MCC-01-CRUSH', 'Tie', 'Provides back-charging tie redundancy to MCC-01-CRUSH', 'MCC-02-SCREEN', 'MAIN', 'OPEN', 'MCC01-TIE-FDR'],
        ['MCC02-FDR-SCR-01', '125A Feeder - 55kW Double Deck Banana Screen 1', 'Feeder', 'DOL starter feeder for vibrating screen exciter motors', 'MCC-02-SCREEN', 'MAIN', 'CLOSED', ''],
        ['MCC02-FDR-SCR-02', '125A Feeder - 55kW Double Deck Banana Screen 2', 'Feeder', 'DOL starter feeder for vibrating screen exciter motors', 'MCC-02-SCREEN', 'MAIN', 'CLOSED', ''],
        ['MCC02-FDR-CV-02', '160A Feeder - 75kW Sized Ore Product Conveyor 2', 'Feeder', 'Soft starter feeder with pull-cord & belt-sway interlocks', 'MCC-02-SCREEN', 'MAIN', 'CLOSED', ''],
        ['MCC02-OG-MCC-06', '400A Outgoing Feeder Cascading Power to MCC-06-DISP', 'Feeder', '3P 400A MCCB supplying downstream wagon loading MCC-06', 'MCC-02-SCREEN', 'MAIN', 'CLOSED', ''],

        # MCC-03-BENEF
        ['MCC03-INC-01', '1000A Incomer from 415V-LT-PCC2', 'Incomer', '3P 1000A Incomer ACB from PCC2-OG-MCC-03', 'MCC-03-BENEF', 'MAIN', 'CLOSED', 'PCC2-OG-MCC-03'],
        ['MCC03-FDR-SLURRY-PMP-01', '200A Feeder - 90kW Spiral Feed Slurry Pump 1', 'Feeder', 'VFD controlled slurry pump feeder for constant cyclone pressure', 'MCC-03-BENEF', 'MAIN', 'CLOSED', ''],
        ['MCC03-FDR-SLURRY-PMP-02', '200A Feeder - 90kW Spiral Feed Slurry Pump 2', 'Feeder', 'Standby VFD slurry pump feeder with auto-changeover interlock', 'MCC-03-BENEF', 'MAIN', 'CLOSED', ''],
        ['MCC03-FDR-CYCLONE-FDR', '160A Feeder - 75kW Hydrocyclone Booster Pump', 'Feeder', 'DOL starter feeder with thermal overload protection', 'MCC-03-BENEF', 'MAIN', 'CLOSED', ''],
        ['MCC03-FDR-MAG-SEP', '100A Feeder - 45kW High Gradient Magnetic Separator', 'Feeder', 'Feeder supplying drum drive and rectifier excitation power', 'MCC-03-BENEF', 'MAIN', 'CLOSED', ''],

        # MCC-04-TAIL
        ['MCC04-INC-01', '1000A Incomer from 415V-LT-PCC2', 'Incomer', '3P 1000A Incomer ACB from PCC2-OG-MCC-04', 'MCC-04-TAIL', 'MAIN', 'CLOSED', 'PCC2-OG-MCC-04'],
        ['MCC04-FDR-PRESS-HYD-01', '160A Feeder - 75kW Filter Press 1 Hydraulic Power Pack', 'Feeder', 'Star-Delta starter feeder for high pressure hydraulic pack', 'MCC-04-TAIL', 'MAIN', 'CLOSED', ''],
        ['MCC04-FDR-PRESS-HYD-02', '160A Feeder - 75kW Filter Press 2 Hydraulic Power Pack', 'Feeder', 'Star-Delta starter feeder for high pressure hydraulic pack', 'MCC-04-TAIL', 'MAIN', 'CLOSED', ''],
        ['MCC04-FDR-THICKENER', '63A Feeder - 30kW Tailings Thickener Rake Drive', 'Feeder', 'Bi-directional VFD drive with automatic torque-lift interlock', 'MCC-04-TAIL', 'MAIN', 'CLOSED', ''],
        ['MCC04-OG-MCC-05-EMERG', '250A Emergency Auxiliary Tie Feeder to MCC-05-PUMP', 'Tie', 'Provides alternate emergency supply to water pumping station', 'MCC-04-TAIL', 'MAIN', 'OPEN', ''],

        # MCC-05-PUMP (Dual source)
        ['MCC05-INC-01', '800A Normal Incomer from 415V-LT-WTP-PCC', 'Incomer', '3P 800A Incomer ACB from WTP-OG-MCC-05', 'MCC-05-PUMP', 'MAIN', 'CLOSED', 'WTP-OG-MCC-05'],
        ['MCC05-INC-02-EMERG', '250A Alternate Emergency Incomer from MCC-04-TAIL', 'Tie', '3P 250A MCCB alternate supply from MCC04-OG-MCC-05-EMERG', 'MCC-05-PUMP', 'MAIN', 'OPEN', 'MCC04-OG-MCC-05-EMERG'],
        ['MCC05-FDR-PMP-01', '250A Feeder - 110kW High-Lift Process Water Pump 1', 'Feeder', 'Soft-starter feeder with bypass contactor and dry-run trip', 'MCC-05-PUMP', 'MAIN', 'CLOSED', ''],
        ['MCC05-FDR-PMP-02', '250A Feeder - 110kW High-Lift Process Water Pump 2', 'Feeder', 'Soft-starter feeder with bypass contactor and dry-run trip', 'MCC-05-PUMP', 'MAIN', 'CLOSED', ''],

        # MCC-06-DISP (Cascaded from MCC-02)
        ['MCC06-INC-01', '400A Cascaded Incomer from MCC-02-SCREEN', 'Incomer', '3P 400A Incomer MCCB fed from MCC02-OG-MCC-06', 'MCC-06-DISP', 'MAIN', 'CLOSED', 'MCC02-OG-MCC-06'],
        ['MCC06-FDR-BOOM-CV', '100A Feeder - 45kW Train Loading Shuttle Boom Conveyor', 'Feeder', 'Reversible soft starter feeder for shuttle loading conveyor', 'MCC-06-DISP', 'MAIN', 'CLOSED', ''],
        ['MCC06-FDR-TELESCOPE', '32A Feeder - 15kW Telescopic Chute Positioner Actuator', 'Feeder', 'Reversible motorized actuator positioning feed chute into wagons', 'MCC-06-DISP', 'MAIN', 'CLOSED', ''],

        # DC Battery System
        ['DC-CHG-AC-INC', '160A 415V AC Incomer from PCC-1', 'Incomer', '415V AC 3P input to dual thyristor bridge charger', '110V-DC-CHG-PNL', 'MAIN', 'CLOSED', 'PCC1-OG-DC-CHG'],
        ['DC-CHG-DC-OG', '200A 110V DC Rectifier Output Feeder', 'Feeder', '110V DC output to distribution switchboard', '110V-DC-CHG-PNL', 'MAIN', 'CLOSED', ''],
        ['DC-DIST-INC-01', '200A 110V DC Incomer from Charger', 'Incomer', 'Main DC input from battery charger panel', '110V-DC-DIST-BD', 'MAIN', 'CLOSED', 'DC-CHG-DC-OG'],
        ['DC-DIST-INC-BATT', '200A 110V DC Incomer from 110V Battery Bank', 'Incomer', 'Direct DC bus feed from 9 x 12V 180Ah series battery bank', '110V-DC-DIST-BD', 'MAIN', 'CLOSED', 'BATTERY-BANK-01'],
        ['DC-FDR-11KV-TRIP', '32A 110V DC Breaker Tripping Bus for 11kV HT Switchgear', 'Feeder', 'Supplies 110V DC shunt trip coils and VCB protection relays', '110V-DC-DIST-BD', 'MAIN', 'CLOSED', ''],
        ['DC-FDR-3.3KV-TRIP', '32A 110V DC Breaker Tripping Bus for 3.3kV MV Switchgear', 'Feeder', 'Supplies 110V DC shunt trip coils and VCB protection relays', '110V-DC-DIST-BD', 'MAIN', 'CLOSED', ''],
        ['DC-FDR-PCC1-TRIP', '32A 110V DC Breaker Tripping Bus for 415V LT PCC-1', 'Feeder', 'Supplies 110V DC under-voltage & shunt trip coils for ACBs', '110V-DC-DIST-BD', 'MAIN', 'CLOSED', ''],
        ['DC-FDR-PCC2-TRIP', '32A 110V DC Breaker Tripping Bus for 415V LT PCC-2', 'Feeder', 'Supplies 110V DC under-voltage & shunt trip coils for ACBs', '110V-DC-DIST-BD', 'MAIN', 'CLOSED', ''],

        # Lighting Board
        ['LDB01-INC', '250A Incomer from 415V-LT-PCC1', 'Incomer', 'Main lighting incomer from PCC1-OG-LDB-01', 'LDB-01-SUB', 'MAIN', 'CLOSED', 'PCC1-OG-LDB-01'],
        ['LDB01-CKT-01', '63A Substation Yard High Mast Lighting Circuit', 'Feeder', 'Timer & photocell controlled LED high mast floodlights', 'LDB-01-SUB', 'MAIN', 'CLOSED', ''],
    ]
    write_sheet('Feeders', feeders_headers, feeders_data, c_purple)

    # 5. Transformers
    tr_headers = ['id', 'name', 'windingType', 'ratingKva', 'primaryVoltage', 'secondaryVoltage', 'tertiaryVoltage', 'primarySourceFeederId', 'secondaryTargetPanelId', 'tertiaryTargetPanelId', 'locationId']
    tr_data = [
        ['TR-01-5MVA', '5.0MVA Step-Down Transformer 1 (11kV / 3.3kV / 415V)', 'three_winding', 5000, '11kV', '3.3kV', '415V', '11KV-OG-TR-01', '3.3KV-MV-SWG', '415V-LT-PCC1', 'YARD-AREA'],
        ['TR-02-5MVA', '5.0MVA Step-Down Transformer 2 (11kV / 3.3kV / 415V)', 'three_winding', 5000, '11kV', '3.3kV', '415V', '11KV-OG-TR-02', '3.3KV-MV-SWG', '415V-LT-PCC1', 'YARD-AREA'],
        ['TR-03-2.5MVA', '2.5MVA Distribution Transformer 3 (11kV / 415V)', 'two_winding', 2500, '11kV', '415V', '', '11KV-OG-TR-03', '415V-LT-PCC2', '', 'YARD-AREA'],
        ['TR-04-2.5MVA', '2.5MVA Distribution Transformer 4 (11kV / 415V)', 'two_winding', 2500, '11kV', '415V', '', '11KV-OG-TR-04', '415V-LT-PCC2', '', 'YARD-AREA'],
        ['TR-05-1MVA', '1.0MVA Water Treatment & Auxiliary Transformer 5 (11kV / 415V)', 'two_winding', 1000, '11kV', '415V', '', '11KV-OG-TR-05', '415V-LT-WTP-PCC', '', 'YARD-AREA'],
    ]
    write_sheet('Transformers', tr_headers, tr_data, c_amber)

    # 6. Master Equipment
    me_headers = ['id', 'name', 'type', 'description', 'locationId', 'panelRoomId', 'panelId', 'feederId']
    me_data = [
        ['COD-JAW-CRUSH-01', 'Primary Jaw Crusher Station 1', 'Crushing & Sizing', 'Heavy-duty 450kW toggle jaw crusher reducing ROM ore from 800mm to 150mm', 'CRUSHING-BENEF', 'MV-ROOM-01', '3.3KV-MV-SWG', '3.3KV-FDR-JAW-CRUSH'],
        ['COD-BALL-MILL-01', 'Beneficiation Grinding Ball Mill 1', 'Grinding Mill', '630kW 3.3kV overflow discharge grinding ball mill for iron ore beneficiation', 'CRUSHING-BENEF', 'MV-ROOM-01', '3.3KV-MV-SWG', '3.3KV-FDR-BALL-MILL'],
        ['COD-MINE-PUMP-01', 'Mine Pit High-Head Dewatering Pump 1', 'Pumping System', '350kW 3.3kV multi-stage centrifugal mine pit flood evacuation pump', 'CRUSHING-BENEF', 'MV-ROOM-01', '3.3KV-MV-SWG', '3.3KV-FDR-MINE-PUMP'],
        ['COD-CENT-COMP-01', 'Main Plant Centrifugal Air Compressor 1', 'Compressor', '250kW 3.3kV multi-stage centrifugal instrument air compressor', 'CRUSHING-BENEF', 'MV-ROOM-01', '3.3KV-MV-SWG', '3.3KV-FDR-COMP-01'],
        ['COD-APRON-FDR-01', 'Heavy Duty Dump Hopper Apron Feeder 1', 'Feeder', '90kW heavy duty manganese steel flight apron feeder under ROM dump hopper', 'CRUSHING-BENEF', 'MCC-ROOM-01', 'MCC-01-CRUSH', 'MCC01-FDR-APRON-FDR'],
        ['COD-OVERLAND-CV-01', 'Primary Overland Ore Conveyor 1', 'Conveyor', '110kW 1200mm wide overland troughing belt conveyor from primary crusher', 'CRUSHING-BENEF', 'MCC-ROOM-01', 'MCC-01-CRUSH', 'MCC01-FDR-CV-01'],
        ['COD-MINERAL-SIZER-01', 'Secondary Twin-Roll Mineral Sizer 1', 'Crushing & Sizing', '132kW heavy duty mineral sizer for secondary ore crushing to -40mm', 'CRUSHING-BENEF', 'MCC-ROOM-01', 'MCC-01-CRUSH', 'MCC01-FDR-SIZER-01'],
        ['COD-CRANE-01', 'Crusher Bay Maintenance EOT Crane 40/10T', 'Crane', '40T Main / 10T Aux double girder overhead traveling crane for crusher maintenance', 'CRUSHING-BENEF', 'MCC-ROOM-01', 'MCC-01-CRUSH', 'MCC01-FDR-CRANE-01'],
        ['COD-BANANA-SCR-01', 'Double Deck Vibrating Banana Screen 1', 'Screening', '55kW multi-slope banana screen sizing high-grade ore into lump and fines', 'SCREENING-PLANT', 'MCC-ROOM-02', 'MCC-02-SCREEN', 'MCC02-FDR-SCR-01'],
        ['COD-BANANA-SCR-02', 'Double Deck Vibrating Banana Screen 2', 'Screening', '55kW multi-slope banana screen sizing high-grade ore into lump and fines', 'SCREENING-PLANT', 'MCC-ROOM-02', 'MCC-02-SCREEN', 'MCC02-FDR-SCR-02'],
        ['COD-PRODUCT-CV-02', 'Sized Ore Finished Product Conveyor 2', 'Conveyor', '75kW 1000mm belt conveyor transferring sized lump ore to product surge silo', 'SCREENING-PLANT', 'MCC-ROOM-02', 'MCC-02-SCREEN', 'MCC02-FDR-CV-02'],
        ['COD-SLURRY-PMP-01', 'Spiral Feed Slurry Pump 1', 'Pump', '90kW heavy duty 8x6 rubber-lined centrifugal pump feeding spiral separator bank', 'CRUSHING-BENEF', 'MCC-ROOM-03', 'MCC-03-BENEF', 'MCC03-FDR-SLURRY-PMP-01'],
        ['COD-SLURRY-PMP-02', 'Spiral Feed Slurry Pump 2 (Standby)', 'Pump', '90kW heavy duty 8x6 rubber-lined centrifugal pump standby unit with auto switch', 'CRUSHING-BENEF', 'MCC-ROOM-03', 'MCC-03-BENEF', 'MCC03-FDR-SLURRY-PMP-02'],
        ['COD-HYDROCYCLONE-01', 'Primary Desliming Hydrocyclone Cluster', 'Beneficiation', '75kW booster pump feeding 12-cyclone desliming cluster removing -20 micron slimes', 'CRUSHING-BENEF', 'MCC-ROOM-03', 'MCC-03-BENEF', 'MCC03-FDR-CYCLONE-FDR'],
        ['COD-FILTER-PRESS-01', 'Tailings Membrane Chamber Filter Press 1', 'Filter Press', '75kW 1500x1500mm 120-chamber recessed membrane filter press for dry tailings cake', 'TAILINGS-DISPOSAL', 'MCC-ROOM-04', 'MCC-04-TAIL', 'MCC04-FDR-PRESS-HYD-01'],
        ['COD-FILTER-PRESS-02', 'Tailings Membrane Chamber Filter Press 2', 'Filter Press', '75kW 1500x1500mm 120-chamber recessed membrane filter press for dry tailings cake', 'TAILINGS-DISPOSAL', 'MCC-ROOM-04', 'MCC-04-TAIL', 'MCC04-FDR-PRESS-HYD-02'],
        ['COD-THICKENER-01', 'Tailings High-Rate Slurry Thickener 1', 'Thickener', '30kW 35-meter diameter high-rate thickener with central torque-lift rake drive', 'TAILINGS-DISPOSAL', 'MCC-ROOM-04', 'MCC-04-TAIL', 'MCC04-FDR-THICKENER'],
        ['COD-PROCESS-PMP-01', 'High-Lift Process Water Circulation Pump 1', 'Pump', '110kW end-suction 450 m3/h circulation pump supplying washing screens and spirals', 'WATER-TREATMENT', 'WTP-PUMP-ROOM', 'MCC-05-PUMP', 'MCC05-FDR-PMP-01'],
        ['COD-PROCESS-PMP-02', 'High-Lift Process Water Circulation Pump 2', 'Pump', '110kW end-suction 450 m3/h circulation pump supplying washing screens and spirals', 'WATER-TREATMENT', 'WTP-PUMP-ROOM', 'MCC-05-PUMP', 'MCC05-FDR-PMP-02'],
        ['COD-WAGON-LOADER-01', 'Rapid Train Loading Shuttle Boom System', 'Loading System', '45kW reversible shuttle boom conveyor for high-speed railway rake loading', 'DISPATCH-AREA', 'DISPATCH-ROOM', 'MCC-06-DISP', 'MCC06-FDR-BOOM-CV'],
        ['COD-BATT-SYSTEM-01', 'Substation 110V DC Battery Tripping Power Bank', 'DC Power System', '110V DC 180Ah Ni-Cd battery bank and dual charger powering all switchgear protection', 'PRIMARY-SUBSTATION', 'BATT-ROOM-01', '110V-DC-DIST-BD', 'DC-DIST-INC-01'],
    ]
    write_sheet('Master Equipment', me_headers, me_data, c_navy)

    # 7. Fault Types
    ft_headers = ['id', 'name', 'category', 'equipmentType']
    ft_data = [
        ['FT-ELEC-01', 'Overload Tripping (O/L)', 'Electrical', 'Motor'],
        ['FT-ELEC-02', 'Single Phasing / Phase Unbalance', 'Electrical', 'Motor'],
        ['FT-ELEC-03', 'Earth Fault / Winding Insulation Breakdown', 'Electrical', 'All'],
        ['FT-ELEC-04', 'Transformer Buchholz Relay Gas Alarm / Trip', 'Electrical', 'Transformer'],
        ['FT-ELEC-05', 'Transformer Winding Temperature High (WTG)', 'Electrical', 'Transformer'],
        ['FT-ELEC-06', 'Vacuum Bottle Flashover / Interrupter Failure', 'Electrical', 'Switchgear'],
        ['FT-ELEC-07', '110V DC Tripping Bus Voltage Failure', 'Electrical', 'Control Panel'],
        ['FT-MECH-01', 'Drive End Bearing Overheating / Seizure', 'Mechanical', 'Motor'],
        ['FT-MECH-02', 'Gearbox High Temperature / Tooth Pitting', 'Mechanical', 'Gearbox'],
        ['FT-MECH-03', 'Pump Mechanical Seal Leakage / Slurry Ingress', 'Mechanical', 'Pump'],
        ['FT-MECH-04', 'Conveyor Belt Misalignment / Sway Trip', 'Mechanical', 'Conveyor'],
        ['FT-MECH-05', 'Exciter Body Structural Crack / High Vibration', 'Mechanical', 'Screening'],
        ['FT-INST-01', 'PT100 Bearing RTD Open / Short Circuit', 'Instrumentation', 'Motor'],
        ['FT-INST-02', 'Pressure Transmitter 4-20mA Signal Drift', 'Instrumentation', 'Sensor'],
        ['FT-AUTO-01', 'Remote I/O Drop Communication Loss (Modbus/Ethernet)', 'Automation', 'Panel'],
    ]
    write_sheet('Fault Types', ft_headers, ft_data, c_purple)

    # 8. ODC Causes
    odc_headers = ['id', 'name', 'category']
    odc_data = [
        ['ODC-01', 'Normal Operational Wear & Tear', 'Wear & Tear'],
        ['ODC-02', 'Lubrication Starvation / Greasing Depletion', 'Mechanical Overload'],
        ['ODC-03', 'Slurry & Foreign Solid Particle Ingress', 'Contamination'],
        ['ODC-04', 'Monsoon Water Seepage / Moisture Condensation', 'Environmental'],
        ['ODC-05', 'Terminal Loose Connection / High Contact Resistance', 'Electrical Stress'],
        ['ODC-06', 'Mechanical Chute Jamming / Tramp Iron Ingress', 'Operational Overload'],
        ['ODC-07', 'Vibration Loosening / Foundation Bolt Failure', 'Structural Fatigue'],
        ['ODC-08', 'Operator Over-throttling / Rapid Restart Duty', 'Human Factor'],
    ]
    write_sheet('ODC Causes', odc_headers, odc_data, c_teal)

    # 9. Reference Guide
    ref_headers = ['Tier / Category', 'Sheet Name', 'ID Tag Examples', 'Parent Link Column', 'Operational Description & Powerflow Role']
    ref_data = [
        ['Tier 1', 'Physical Areas', 'PRIMARY-SUBSTATION, CRUSHING-BENEF', 'N/A (Root)', 'Geographical plant zone housing electrical substations and machinery'],
        ['Tier 2', 'Panel Rooms', 'SUB-ROOM-01, LT-ROOM-01, MV-ROOM-01', 'locationId', 'Substation building or control room housing power switchgear & MCCs'],
        ['Tier 3', 'Panels', '11KV-HT-SWG, 415V-LT-PCC1, MCC-01-CRUSH', 'panelRoomId', 'Switchboards, PCCs, MCCs with voltageLevel (11kV, 3.3kV, 415V, 110V DC) and busSections'],
        ['Tier 4', 'Feeders', '11KV-INC-01, PCC1-BC-01, MCC01-FDR-01', 'panelId', 'VCBs, ACBs, Starters with busSection, operatingState (CLOSED/OPEN), upstreamFeederId'],
        ['Tier 5', 'Transformers', 'TR-01-5MVA, TR-03-2.5MVA', 'primarySourceFeederId', 'Step-down distribution transformers linking HT feeders to secondary/tertiary PCCs'],
        ['Tier 6', 'Master Equipment', 'COD-JAW-CRUSH-01, COD-BALL-MILL-01', 'feederId, panelId, panelRoomId, locationId', 'Physical machine tags holding electrical & mechanical assets'],
        ['Catalog', 'Fault Types', 'FT-ELEC-01, FT-MECH-01', 'N/A (Catalog)', 'Standard plant fault catalog across Electrical, Mechanical, Instrumentation'],
        ['Catalog', 'ODC Causes', 'ODC-01, ODC-02', 'N/A (Catalog)', 'Object Damage Cause defect library for root cause analysis'],
    ]
    write_sheet('Reference Guide', ref_headers, ref_data, c_navy)

    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    wb.save(output_path)
    print(f"Saved Hierarchy Master Excel to: {output_path}")

def create_asset_excel(output_path):
    wb = openpyxl.Workbook()
    wb.remove(wb.active)

    c_navy = "0F172A"
    c_amber = "D97706"
    c_purple = "6D28D9"
    c_teal = "0D9488"
    c_orange = "EA580C"
    c_blue = "2563EB"
    c_border = "CBD5E1"
    c_zebra = "F8FAFC"

    font_header = Font(name="Calibri", size=11, bold=True, color="FFFFFF")
    font_cell = Font(name="Calibri", size=10, color="1E293B")
    thin_border = Border(
        left=Side(style='thin', color=c_border),
        right=Side(style='thin', color=c_border),
        top=Side(style='thin', color=c_border),
        bottom=Side(style='thin', color=c_border)
    )

    def write_sheet(title, headers, rows, header_color):
        ws = wb.create_sheet(title=title)
        for col_idx, h in enumerate(headers, 1):
            cell = ws.cell(row=1, column=col_idx, value=h)
            cell.font = font_header
            cell.fill = PatternFill(start_color=header_color, end_color=header_color, fill_type="solid")
            cell.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
            cell.border = thin_border
        ws.row_dimensions[1].height = 28

        for r_idx, row_data in enumerate(rows, 2):
            bg = c_zebra if (r_idx % 2 == 0) else "FFFFFF"
            for col_idx, raw_val in enumerate(row_data, 1):
                val = None if (raw_val == "" or raw_val is None) else raw_val
                cell = ws.cell(row=r_idx, column=col_idx, value=val)
                cell.font = font_cell
                cell.fill = PatternFill(start_color=bg, end_color=bg, fill_type="solid")
                cell.border = thin_border
                if isinstance(val, (int, float)):
                    cell.alignment = Alignment(horizontal="right", vertical="center")
                elif col_idx in [1, 3, 4, 8, 9]:
                    cell.alignment = Alignment(horizontal="center", vertical="center")
                else:
                    cell.alignment = Alignment(horizontal="left", vertical="center")
            ws.row_dimensions[r_idx].height = 20

        for col_idx, h in enumerate(headers, 1):
            max_len = len(str(h))
            for row_data in rows:
                if col_idx - 1 < len(row_data) and row_data[col_idx - 1] is not None:
                    max_len = max(max_len, len(str(row_data[col_idx - 1])))
            col_letter = get_column_letter(col_idx)
            ws.column_dimensions[col_letter].width = min(max(max_len + 3, 14), 45)

        return ws

    common_cols = [
        'tagNo', 'name', 'type', 'status', 'parentEquipment',
        'applicableParentEquipmentIds', 'spareLocation', 'installationDate',
        'isCritical', 'make', 'model', 'serialNo', 'manufacturingYear',
        'rfidTag', 'poNo', 'imageUrl', 'description',
    ]

    # 1. Motors
    motor_cols = common_cols + [
        'powerKw', 'voltage', 'fullLoadCurrent', 'noLoadCurrent', 'speedRpm',
        'poles', 'frequency', 'efficiency', 'powerFactor', 'frameSize',
        'mountingType', 'greaseType', 'motorType', 'dutyCycle', 'insulationClass',
        'couplingAvailable', 'couplingType', 'efficiencyClass', 'ipRating',
        'bearingDE', 'bearingNDE',
    ]
    motor_data = [
        [
            'IOG-COD-MTR-001', '450kW 8P 3.3kV Slip Ring Motor (Primary Jaw Crusher)', 'motor', 'active', 'COD-JAW-CRUSH-01',
            'COD-JAW-CRUSH-01', 'Bay-1 Substation Standby Plinth', '2022-03-15',
            'TRUE', 'BHEL', 'AWS 560-8', 'BH-2022-9011', 2022,
            'RF-MTR-001', 'PO-2022-5501', '', 'Heavy duty wound rotor slip ring motor with brush-lifting mechanism',
            450, 3300, 98.5, 28.0, 742, 8, 50, 94.8, 0.85, '560',
            'Foot Mounted (B3)', 'Mobil Polyrex EM', 'Slip Ring Induction', 'S1 (Continuous)', 'Class F',
            'YES', 'Flexible Geared Coupling', 'IE2', 'IP55', 'NU 330 ECM', '6330 C3'
        ],
        [
            'IOG-COD-MTR-002', '630kW 6P 3.3kV Squirrel Cage Motor (Beneficiation Ball Mill)', 'motor', 'active', 'COD-BALL-MILL-01',
            'COD-BALL-MILL-01', 'Mill Bay Standby Pad', '2021-11-20',
            'TRUE', 'Siemens', '1LA4 500-6', 'SM-2021-4412', 2021,
            'RF-MTR-002', 'PO-2021-8820', '', 'High torque squirrel cage induction motor for continuous grinding ball mill',
            630, 3300, 134.0, 38.0, 990, 6, 50, 95.6, 0.87, '500',
            'Foot Mounted (B3)', 'Mobil Polyrex EM', 'Squirrel Cage Induction', 'S1 (Continuous)', 'Class H',
            'YES', 'Torque-Limiting Fluid Coupling', 'IE3', 'IP55', '6332 C3', '6332 C3'
        ],
        [
            'IOG-COD-MTR-003', '350kW 2P 3.3kV High Speed Motor (Mine Pit Dewatering Pump)', 'motor', 'active', 'COD-MINE-PUMP-01',
            'COD-MINE-PUMP-01', 'Mine Pump House Store', '2023-01-10',
            'TRUE', 'ABB', 'HXR 400LA 2', 'ABB-2023-0091', 2023,
            'RF-MTR-003', 'PO-2023-1102', '', 'High speed heavy dewatering pump drive motor',
            350, 3300, 74.0, 19.5, 2980, 2, 50, 96.0, 0.89, '400',
            'Foot Mounted (B3)', 'Mobil Polyrex EM', 'Squirrel Cage Induction', 'S1 (Continuous)', 'Class F',
            'YES', 'Spacer Type Flexible Membrane Coupling', 'IE3', 'IP55', '6319 C3', '6319 C3'
        ],
        [
            'IOG-COD-MTR-004', '250kW 2P 3.3kV Centrifugal Compressor Motor', 'motor', 'active', 'COD-CENT-COMP-01',
            'COD-CENT-COMP-01', 'Compressor Bay Shed', '2022-08-14',
            'TRUE', 'Siemens', '1LA8 357-2', 'SM-2022-7719', 2022,
            'RF-MTR-004', 'PO-2022-4490', '', 'Instrument air central compressor drive motor',
            250, 3300, 52.5, 14.0, 2975, 2, 50, 95.8, 0.88, '355',
            'Foot Mounted (B3)', 'Mobil Polyrex EM', 'Squirrel Cage Induction', 'S1 (Continuous)', 'Class F',
            'YES', 'Diaphragm Metallic Coupling', 'IE3', 'IP55', '6318 C3', '6318 C3'
        ],
        [
            'IOG-COD-MTR-005', '90kW 6P 415V IE3 VFD Inverter Duty Motor (Apron Feeder)', 'motor', 'active', 'COD-APRON-FDR-01',
            'COD-APRON-FDR-01', 'Crusher Store Bay-2', '2022-04-18',
            'TRUE', 'Bharat Bijlee', '315M 6P', 'BB-2022-5510', 2022,
            'RF-MTR-005', 'PO-2022-3320', '', 'Inverter duty motor with forced cooling fan for apron feeder',
            90, 415, 158.0, 48.0, 985, 6, 50, 94.6, 0.83, '315M',
            'Foot Mounted (B3)', 'Shell Gadus S3', 'Inverter Duty Induction', 'S1 (Continuous)', 'Class H',
            'YES', 'Pin Bush Flexible Coupling', 'IE3', 'IP55', '6319 C3', '6319 C3 Insulated'
        ],
        [
            'IOG-COD-MTR-006', '110kW 4P 415V IE3 Motor (Primary Overland Conveyor 1)', 'motor', 'active', 'COD-OVERLAND-CV-01',
            'COD-OVERLAND-CV-01', 'Conveyor Drive Shed 1', '2021-09-25',
            'TRUE', 'ABB', 'M3BP 315SMA 4', 'ABB-2021-9982', 2021,
            'RF-MTR-006', 'PO-2021-6651', '', 'Severe duty cast iron overland conveyor motor',
            110, 415, 188.0, 54.0, 1485, 4, 50, 95.8, 0.86, '315S',
            'Foot Mounted (B3)', 'Mobil Polyrex EM', 'Severe Duty Induction', 'S1 (Continuous)', 'Class F',
            'YES', 'Fluid Coupling', 'IE3', 'IP66', '6319 C3', '6319 C3'
        ],
        [
            'IOG-COD-MTR-007', '132kW 4P 415V IE3 Reversible Motor (Mineral Sizer 1)', 'motor', 'active', 'COD-MINERAL-SIZER-01',
            'COD-MINERAL-SIZER-01', 'Sizer House Bay 1', '2022-06-10',
            'TRUE', 'ABB', 'M3BP 315MB 4', 'ABB-2022-8114', 2022,
            'RF-MTR-007', 'PO-2022-7729', '', 'High starting torque reversible mineral sizer motor',
            132, 415, 224.0, 62.0, 1488, 4, 50, 96.0, 0.87, '315M',
            'Foot Mounted (B3)', 'Mobil Polyrex EM', 'Cast Iron Induction', 'S1 (Continuous)', 'Class F',
            'YES', 'Flexible Pin-Bush', 'IE3', 'IP55', '6319 C3', '6319 C3'
        ],
        [
            'IOG-COD-MTR-008', '55kW 4P 415V Vibrator Duty Motor (Banana Screen 1)', 'motor', 'active', 'COD-BANANA-SCR-01',
            'COD-BANANA-SCR-01, COD-BANANA-SCR-02', 'Screen House Shelf-C', '2022-10-05',
            'TRUE', 'Crompton Greaves', 'ND 250M 4', 'CG-2022-3341', 2022,
            'RF-MTR-008', 'PO-2022-2219', '', 'High-vibration reinforced frame motor for banana screen exciter box',
            55, 415, 96.0, 29.0, 1480, 4, 50, 94.5, 0.85, '250M',
            'Foot Mounted (B3)', 'Mobilith SHC 220', 'Vibrator Duty Induction', 'S1 (Continuous)', 'Class H',
            'YES', 'Cardan Shaft Universal Joint', 'IE3', 'IP66', 'NU 315 ECM', '6315 C3'
        ],
        [
            'IOG-COD-MTR-009', '55kW 4P 415V Vibrator Duty Motor (Banana Screen 2)', 'motor', 'active', 'COD-BANANA-SCR-02',
            'COD-BANANA-SCR-01, COD-BANANA-SCR-02', 'Screen House Shelf-C', '2022-10-05',
            'TRUE', 'Crompton Greaves', 'ND 250M 4', 'CG-2022-3342', 2022,
            'RF-MTR-009', 'PO-2022-2219', '', 'High-vibration reinforced frame motor for banana screen exciter box',
            55, 415, 96.0, 29.0, 1480, 4, 50, 94.5, 0.85, '250M',
            'Foot Mounted (B3)', 'Mobilith SHC 220', 'Vibrator Duty Induction', 'S1 (Continuous)', 'Class H',
            'YES', 'Cardan Shaft Universal Joint', 'IE3', 'IP66', 'NU 315 ECM', '6315 C3'
        ],
        [
            'IOG-COD-MTR-010', '90kW 6P 415V IE3 Slurry Duty Motor (Spiral Feed Pump 1)', 'motor', 'active', 'COD-SLURRY-PMP-01',
            'COD-SLURRY-PMP-01, COD-SLURRY-PMP-02', 'Pump Store Shelf-A', '2023-02-14',
            'TRUE', 'ABB', 'M3BP 315SMC 6', 'ABB-2023-6601', 2023,
            'RF-MTR-010', 'PO-2023-8822', '', 'Severe slurry duty motor with insulated non-drive bearing',
            90, 415, 158.0, 46.0, 988, 6, 50, 94.9, 0.84, '315S',
            'Foot Mounted (B3)', 'Mobil Polyrex EM', 'Inverter Duty Slurry Motor', 'S1 (Continuous)', 'Class F',
            'YES', 'Tyre Type Flexible Coupling', 'IE3', 'IP66', '6319 C3', '6319 C3 Insulated'
        ],
        [
            'IOG-COD-MTR-011', '90kW 6P 415V IE3 Slurry Duty Motor (Spiral Feed Pump 2)', 'motor', 'active', 'COD-SLURRY-PMP-02',
            'COD-SLURRY-PMP-01, COD-SLURRY-PMP-02', 'Pump Store Shelf-A', '2023-02-14',
            'TRUE', 'ABB', 'M3BP 315SMC 6', 'ABB-2023-6602', 2023,
            'RF-MTR-011', 'PO-2023-8822', '', 'Standby severe slurry duty motor with insulated non-drive bearing',
            90, 415, 158.0, 46.0, 988, 6, 50, 94.9, 0.84, '315S',
            'Foot Mounted (B3)', 'Mobil Polyrex EM', 'Inverter Duty Slurry Motor', 'S1 (Continuous)', 'Class F',
            'YES', 'Tyre Type Flexible Coupling', 'IE3', 'IP66', '6319 C3', '6319 C3 Insulated'
        ],
        [
            'IOG-COD-MTR-012', '110kW 2P 415V IE3 Motor (High-Lift Water Pump 1)', 'motor', 'active', 'COD-PROCESS-PMP-01',
            'COD-PROCESS-PMP-01, COD-PROCESS-PMP-02', 'WTP Pump Shed Bay-1', '2021-12-05',
            'TRUE', 'Siemens', '1LE7 315S-2', 'SM-2021-9019', 2021,
            'RF-MTR-012', 'PO-2021-5541', '', 'High speed process water circulation pump motor',
            110, 415, 186.0, 48.0, 2975, 2, 50, 95.8, 0.88, '315S',
            'Foot Mounted (B3)', 'Mobil Polyrex EM', 'Squirrel Cage Induction', 'S1 (Continuous)', 'Class F',
            'YES', 'Pin Bush Flexible Coupling', 'IE3', 'IP55', '6317 C3', '6317 C3'
        ],
        # Spares in warehouse
        [
            'IOG-COD-MTR-SPARE-01', 'Spare 90kW 6P 415V IE3 Slurry Duty Motor', 'motor', 'spare', '',
            'COD-SLURRY-PMP-01, COD-SLURRY-PMP-02, COD-APRON-FDR-01', 'Central Electrical Warehouse Rack-E1', '2023-05-10',
            'TRUE', 'ABB', 'M3BP 315SMC 6', 'ABB-2023-7711', 2023,
            'RF-MTR-SP-01', 'PO-2023-9930', '', 'Preserved ready-to-install spare slurry motor on anti-vibration mount',
            90, 415, 158.0, 46.0, 988, 6, 50, 94.9, 0.84, '315S',
            'Foot Mounted (B3)', 'Mobil Polyrex EM', 'Inverter Duty Slurry Motor', 'S1 (Continuous)', 'Class F',
            'YES', 'Bare Shaft with Key', 'IE3', 'IP66', '6319 C3', '6319 C3 Insulated'
        ],
        [
            'IOG-COD-MTR-SPARE-02', 'Spare 55kW 4P 415V Vibrator Duty Motor', 'motor', 'spare', '',
            'COD-BANANA-SCR-01, COD-BANANA-SCR-02', 'Central Electrical Warehouse Rack-E2', '2023-05-10',
            'TRUE', 'Crompton Greaves', 'ND 250M 4', 'CG-2023-1190', 2023,
            'TRUE', 'Crompton Greaves', 'ND 250M 4', 'CG-2023-1190', 2023,
            'RF-MTR-SP-02', 'PO-2023-9931', '', 'Preserved ready-to-install spare vibrator motor with space heaters on',
            55, 415, 96.0, 29.0, 1480, 4, 50, 94.5, 0.85, '250M',
            'Foot Mounted (B3)', 'Mobilith SHC 220', 'Vibrator Duty Induction', 'S1 (Continuous)', 'Class H',
            'YES', 'Bare Shaft with Key', 'IE3', 'IP66', 'NU 315 ECM', '6315 C3'
        ],
    ]
    write_sheet('Motors', motor_cols, motor_data, c_amber)

    # 2. Brakes
    brake_cols = common_cols + [
        'brakeType', 'thrusterCapacityKg', 'voltageType', 'voltageRating',
        'drumDiaMm', 'drumWidthMm', 'drumInstallation', 'mountingBoltSize',
        'mountingBoltCount', 'mountingLengthMm', 'mountingWidthMm',
        'brakingTorqueNm', 'brakeShoeLining',
    ]
    brake_data = [
        [
            'IOG-COD-BRK-001', 'EHT Thruster Brake 400mm Dia (Overland Conveyor 1)', 'brake', 'active', 'COD-OVERLAND-CV-01',
            'COD-OVERLAND-CV-01', 'Conveyor Drive Shed 1', '2021-09-25',
            'TRUE', 'Electromag', 'EHT-400-80', 'EM-2021-7781', 2021,
            'RF-BRK-001', 'PO-2021-6652', '', 'Electro-hydraulic thruster holdback brake on conveyor high speed shaft',
            'Electro-Hydraulic Thruster (EHT)', 80, 'AC', 415,
            400, 150, 'Gearbox High Speed Shaft', 'M20', 4, 450, 300, 1250, 'Asbestos-Free Molded Friction Composite'
        ],
        [
            'IOG-COD-BRK-002', 'EHT Thruster Brake 300mm Dia (Crusher Crane Main Hoist)', 'brake', 'active', 'COD-CRANE-01',
            'COD-CRANE-01', 'Crane Maintenance Platform', '2022-04-10',
            'TRUE', 'Electromag', 'EHT-300-50', 'EM-2022-4410', 2022,
            'RF-BRK-002', 'PO-2022-3315', '', 'Fail-safe gravity fallback hoist brake on 40T main hoist',
            'Electro-Hydraulic Thruster (EHT)', 50, 'AC', 415,
            300, 125, 'Hoist Motor Drive End', 'M16', 4, 350, 250, 650, 'Heavy Duty Sintered Metallic Lining'
        ],
        [
            'IOG-COD-BRK-003', 'Electromagnetic Disc Brake 250mm (Apron Feeder Safety)', 'brake', 'active', 'COD-APRON-FDR-01',
            'COD-APRON-FDR-01', 'Crusher Hopper Lower Gallery', '2022-04-18',
            'TRUE', 'Stromag', '2BA-250', 'STR-2022-0991', 2022,
            'RF-BRK-003', 'PO-2022-3321', '', 'Electromagnetic fail-safe caliper disc brake for dump hopper holdback',
            'Electromagnetic Caliper Disc', 40, 'DC', 110,
            250, 100, 'Bevel Planetary Reducer Shaft', 'M16', 4, 280, 220, 850, 'Organic Kevlar Composite'
        ],
        [
            'IOG-COD-BRK-004', 'EHT Thruster Brake 300mm Dia (Wagon Loader Boom)', 'brake', 'active', 'COD-WAGON-LOADER-01',
            'COD-WAGON-LOADER-01', 'Dispatch Control Platform', '2022-09-12',
            'TRUE', 'Electromag', 'EHT-300-50', 'EM-2022-8110', 2022,
            'RF-BRK-004', 'PO-2022-7740', '', 'Shuttle boom travel and locking safety brake',
            'Electro-Hydraulic Thruster (EHT)', 50, 'AC', 415,
            300, 125, 'Shuttle Drive Reducer Shaft', 'M16', 4, 350, 250, 600, 'Molded Asbestos-Free Lining'
        ],
        [
            'IOG-COD-BRK-005', 'EHT Thruster Brake 300mm Dia (Product Conveyor 2)', 'brake', 'active', 'COD-PRODUCT-CV-02',
            'COD-PRODUCT-CV-02', 'Screen House Conveyor Drive', '2022-10-05',
            'TRUE', 'Electromag', 'EHT-300-50', 'EM-2022-9905', 2022,
            'RF-BRK-005', 'PO-2022-2225', '', 'High speed drive holdback brake on sized product conveyor',
            'Electro-Hydraulic Thruster (EHT)', 50, 'AC', 415,
            300, 125, 'Conveyor Reducer High Speed Shaft', 'M16', 4, 350, 250, 620, 'Asbestos-Free Molded Composite'
        ],
        # Spare in warehouse
        [
            'IOG-COD-BRK-SPARE-01', 'Spare EHT Thruster Brake Assembly 400mm Dia', 'brake', 'spare', '',
            'COD-OVERLAND-CV-01', 'Central Mechanical Warehouse Rack-B1', '2023-04-12',
            'TRUE', 'Electromag', 'EHT-400-80', 'EM-2023-1109', 2023,
            'RF-BRK-SP-01', 'PO-2023-9940', '', 'Complete crated spare brake shoe, thruster cylinder, and linkage set',
            'Electro-Hydraulic Thruster (EHT)', 80, 'AC', 415,
            400, 150, 'High Speed Shaft', 'M20', 4, 450, 300, 1250, 'Asbestos-Free Molded Friction Composite'
        ],
    ]
    write_sheet('Brakes', brake_cols, brake_data, c_purple)

    # 3. Actuators
    actuator_cols = common_cols + [
        'actuatorType', 'torqueOrThrust', 'operatingTimeSeconds',
        'controlSignal', 'valveFlangeStandard', 'valveType', 'valveSize',
    ]
    actuator_data = [
        [
            'IOG-COD-ACT-001', 'Rotork IQ35 Multi-Turn 4-20mA Actuator (Cyclone Feed)', 'actuator', 'active', 'COD-HYDROCYCLONE-01',
            'COD-HYDROCYCLONE-01', 'Spiral Plant Valve Stand', '2022-07-15',
            'TRUE', 'Rotork', 'IQ35 Pro', 'RT-2022-0914', 2022,
            'RF-ACT-001', 'PO-2022-4419', '', 'Intelligent non-intrusive electric actuator modulating slurry feed pressure',
            'Electric Multi-Turn', 650, 25, '4-20mA Modulating', 'ISO 5211 (F14)', 'Knife Gate Valve', '10 Inch (DN250)'
        ],
        [
            'IOG-COD-ACT-002', 'Auma SA07.6 Quarter-Turn Actuator (Ball Mill Discharge)', 'actuator', 'active', 'COD-BALL-MILL-01',
            'COD-BALL-MILL-01', 'Mill Sump Isolation Gallery', '2021-11-20',
            'TRUE', 'Auma', 'SA 07.6 / GS 50', 'AU-2021-6671', 2021,
            'RF-ACT-002', 'PO-2021-8825', '', 'High torque quarter turn actuator with position feedback transmitter',
            'Electric Quarter-Turn', 1200, 18, '4-20mA Modulating / Open-Close', 'ISO 5211 (F12)', 'Slurry Butterfly Valve', '12 Inch (DN300)'
        ],
        [
            'IOG-COD-ACT-003', 'Rotork IQ25 Multi-Turn Actuator (Thickener Underflow)', 'actuator', 'active', 'COD-THICKENER-01',
            'COD-THICKENER-01', 'Thickener Tunnel Valve Manifold', '2022-05-18',
            'TRUE', 'Rotork', 'IQ25 Pro', 'RT-2022-7711', 2022,
            'RF-ACT-003', 'PO-2022-5561', '', 'Modulating underflow density control valve actuator',
            'Electric Multi-Turn', 450, 30, '4-20mA Modulating', 'ISO 5211 (F10)', 'Pinch Valve', '8 Inch (DN200)'
        ],
        [
            'IOG-COD-ACT-004', 'Limitorque MX05 Actuator (Process Water Pump 1 Bypass)', 'actuator', 'active', 'COD-PROCESS-PMP-01',
            'COD-PROCESS-PMP-01, COD-PROCESS-PMP-02', 'WTP Pump Header Platform', '2021-12-05',
            'TRUE', 'Flowserve Limitorque', 'MX05', 'LT-2021-4409', 2021,
            'RF-ACT-004', 'PO-2021-5545', '', 'High speed pump minimum-flow bypass regulating valve actuator',
            'Electric Quarter-Turn', 350, 12, '4-20mA Modulating', 'ISO 5211 (F10)', 'Globe Valve', '6 Inch (DN150)'
        ],
        [
            'IOG-COD-ACT-005', 'Rotork IQ12 Actuator (Wagon Loading Telescopic Chute)', 'actuator', 'active', 'COD-WAGON-LOADER-01',
            'COD-WAGON-LOADER-01', 'Loading Chute Operator Platform', '2022-09-12',
            'TRUE', 'Rotork', 'IQ12 Pro', 'RT-2022-8802', 2022,
            'RF-ACT-005', 'PO-2022-7745', '', 'Positions dust-suppression telescopic chute inside wagon wagons',
            'Electric Multi-Turn', 180, 20, '4-20mA Positioning', 'ISO 5211 (F07)', 'Telescopic Positioner', '4 Inch (DN100)'
        ],
        # Spare in warehouse
        [
            'IOG-COD-ACT-SPARE-01', 'Spare Rotork IQ35 Multi-Turn 4-20mA Actuator', 'actuator', 'spare', '',
            'COD-HYDROCYCLONE-01, COD-BALL-MILL-01', 'Central Electrical Warehouse Rack-A1', '2023-03-20',
            'TRUE', 'Rotork', 'IQ35 Pro', 'RT-2023-0099', 2023,
            'RF-ACT-SP-01', 'PO-2023-9950', '', 'Factory sealed tropicalized spare electric multi-turn actuator',
            'Electric Multi-Turn', 650, 25, '4-20mA Modulating', 'ISO 5211 (F14)', 'Multi-Purpose', '8-12 Inch'
        ],
    ]
    write_sheet('Actuators', actuator_cols, actuator_data, c_teal)

    # 4. Gearboxes
    gearbox_cols = common_cols + [
        'powerKw', 'gearRatio', 'oilType', 'oilCapacity',
        'inputSpeedRpm', 'outputSpeedRpm', 'inputShaftMm', 'outputShaftMm',
        'lubricationMethod', 'mountingOrientation',
        'bearingDE', 'bearingNDE',
    ]
    gearbox_data = [
        [
            'IOG-COD-GBX-001', 'Bevel Helical 3-Stage Heavy Duty Gearbox (Mineral Sizer 1)', 'gearbox', 'active', 'COD-MINERAL-SIZER-01',
            'COD-MINERAL-SIZER-01', 'Crusher Heavy Spares Yard', '2022-06-10',
            'TRUE', 'Elecon', 'PBN 355-3', 'EL-2022-5501', 2022,
            'RF-GBX-001', 'PO-2022-7730', '', 'Heavy mineral sizer roll speed reduction gearbox with dual output shafts',
            132, '31.5 : 1', 'ISO VG 320 Synthetic Gear Oil', 68.0,
            1488, 47.2, 75, 180, 'Splash & Forced Oil Circulation', 'Horizontal Foot Mounted',
            '22222 EK', '23238 CC/W33'
        ],
        [
            'IOG-COD-GBX-002', 'Bevel Helical Reducer Gearbox (Overland Conveyor 1)', 'gearbox', 'active', 'COD-OVERLAND-CV-01',
            'COD-OVERLAND-CV-01', 'Conveyor Drive Shed 1', '2021-09-25',
            'TRUE', 'Flender (Siemens)', 'B3SH 11', 'FL-2021-8890', 2021,
            'RF-GBX-002', 'PO-2021-6653', '', 'Severe conveyor main drive speed reducer with integrated backstop',
            110, '22.4 : 1', 'ISO VG 320 Industrial Gear Oil', 55.0,
            1485, 66.3, 70, 160, 'Splash Lubrication with Cooling Fan', 'Horizontal Foot Mounted',
            '22220 E', '22324 CC/W33'
        ],
        [
            'IOG-COD-GBX-003', 'Planetary Bevel Reducer (Apron Feeder Drive)', 'gearbox', 'active', 'COD-APRON-FDR-01',
            'COD-APRON-FDR-01', 'Crusher Dump Gallery Pad', '2022-04-18',
            'TRUE', 'Bonfiglioli', '315 L3 / Bevel', 'BF-2022-3349', 2022,
            'RF-GBX-003', 'PO-2022-3322', '', 'Ultra high torque planetary speed reducer for heavy ore apron feeder',
            90, '125.0 : 1', 'ISO VG 460 Synthetic Oil', 42.0,
            985, 7.88, 65, 220, 'Forced Lubrication with Pressure Switch', 'Shaft Mounted with Torque Arm',
            'Spherical Roller 24132', 'Taper Roller 32230'
        ],
        [
            'IOG-COD-GBX-004', 'Shaft-Mounted Helical Gearbox (Product Conveyor 2)', 'gearbox', 'active', 'COD-PRODUCT-CV-02',
            'COD-PRODUCT-CV-02', 'Screen House Head Pulley Frame', '2022-10-05',
            'TRUE', 'PBL (Premium)', 'SMSR H-13', 'PB-2022-2291', 2022,
            'RF-GBX-004', 'PO-2022-2226', '', 'Compact shaft-mounted speed reducer on conveyor drive pulley shaft',
            75, '20.0 : 1', 'ISO VG 320 Gear Oil', 28.0,
            1480, 74.0, 55, 125, 'Splash Lubrication', 'Shaft Mounted with Torque Arm',
            '22216 E', '22218 E'
        ],
        [
            'IOG-COD-GBX-005', 'Heavy Planetary Central Drive (Tailings Thickener Rake)', 'gearbox', 'active', 'COD-THICKENER-01',
            'COD-THICKENER-01', 'Thickener Central Bridge', '2022-05-18',
            'TRUE', 'Brevini', 'SLW 4003', 'BV-2022-0041', 2022,
            'RF-GBX-005', 'PO-2022-5562', '', 'Extreme high ratio planetary central drive with hydraulic rake lift mechanism',
            30, '480.0 : 1', 'ISO VG 460 Synthetic Gear Oil', 120.0,
            1450, 3.02, 45, 320, 'Circulation with External Oil Cooler', 'Vertical Flange Mounted',
            'Taper Roller 32044', 'Heavy Thrust Bearing 29440'
        ],
        # Spares in warehouse
        [
            'IOG-COD-GBX-SPARE-01', 'Spare Bevel Helical Reducer Gearbox 110kW', 'gearbox', 'spare', '',
            'COD-OVERLAND-CV-01, COD-PRODUCT-CV-02', 'Central Mechanical Warehouse Heavy Bay-1', '2023-04-15',
            'TRUE', 'Flender (Siemens)', 'B3SH 11', 'FL-2023-1120', 2023,
            'RF-GBX-SP-01', 'PO-2023-9960', '', 'Preserved spare gearbox filled with vapor-phase rust inhibitor',
            110, '22.4 : 1', 'ISO VG 320 Industrial Gear Oil', 55.0,
            1485, 66.3, 70, 160, 'Splash Lubrication with Cooling Fan', 'Horizontal Foot Mounted',
            '22220 E', '22324 CC/W33'
        ],
        [
            'IOG-COD-GBX-SPARE-02', 'Spare Shaft-Mounted Helical Gearbox 75kW', 'gearbox', 'spare', '',
            'COD-PRODUCT-CV-02', 'Central Mechanical Warehouse Heavy Bay-2', '2023-04-15',
            'TRUE', 'PBL (Premium)', 'SMSR H-13', 'PB-2023-4410', 2023,
            'RF-GBX-SP-02', 'PO-2023-9961', '', 'Preserved shaft-mounted speed reducer ready for immediate conveyor mounting',
            75, '20.0 : 1', 'ISO VG 320 Gear Oil', 28.0,
            1480, 74.0, 55, 125, 'Splash Lubrication', 'Shaft Mounted with Torque Arm',
            '22216 E', '22218 E'
        ],
    ]
    write_sheet('Gearboxes', gearbox_cols, gearbox_data, c_orange)

    # 5. Pumps
    pump_cols = common_cols + [
        'flowRate', 'head', 'speedRpm', 'pumpPower', 'impellerSize',
        'suctionFlangeMm', 'dischargeFlangeMm', 'sealType', 'casingMaterial', 'greaseType',
        'bearingDE', 'bearingNDE',
    ]
    pump_data = [
        [
            'IOG-COD-PMP-001', 'Heavy Duty Rubber-Lined Slurry Pump 1 (350 m3/h)', 'pump', 'active', 'COD-SLURRY-PMP-01',
            'COD-SLURRY-PMP-01, COD-SLURRY-PMP-02', 'Spiral Sump Plinth 1', '2023-02-14',
            'TRUE', 'Warman (Weir Minerals)', '8/6 E-AH Rubber', 'WM-2023-8810', 2023,
            'RF-PMP-001', 'PO-2023-8823', '', 'Severe abrasive iron ore slurry feed pump with natural rubber liners',
            350.0, 45.0, 988, 90.0, '380mm 4-Vane Closed',
            200, 150, 'Dynamic Expeller with Gland Packing', 'Ductile Iron with Natural Rubber', 'ISO VG 68 Bearing Oil',
            'NU 319 ECM', '7319 BECBM'
        ],
        [
            'IOG-COD-PMP-002', 'Heavy Duty Rubber-Lined Slurry Pump 2 (350 m3/h)', 'pump', 'active', 'COD-SLURRY-PMP-02',
            'COD-SLURRY-PMP-01, COD-SLURRY-PMP-02', 'Spiral Sump Plinth 2', '2023-02-14',
            'TRUE', 'Warman (Weir Minerals)', '8/6 E-AH Rubber', 'WM-2023-8811', 2023,
            'RF-PMP-002', 'PO-2023-8823', '', 'Standby severe abrasive slurry pump with automatic isolation changeover',
            350.0, 45.0, 988, 90.0, '380mm 4-Vane Closed',
            200, 150, 'Dynamic Expeller with Gland Packing', 'Ductile Iron with Natural Rubber', 'ISO VG 68 Bearing Oil',
            'NU 319 ECM', '7319 BECBM'
        ],
        [
            'IOG-COD-PMP-003', 'Mine Pit High-Head Multi-Stage Dewatering Pump 1', 'pump', 'active', 'COD-MINE-PUMP-01',
            'COD-MINE-PUMP-01', 'Mine Sump Deep Well Station', '2023-01-10',
            'TRUE', 'KSB', 'Multitec MTC A 100/6', 'KS-2023-0092', 2023,
            'RF-PMP-003', 'PO-2023-1103', '', '6-stage high head mine flood dewatering multi-stage centrifugal pump',
            250.0, 180.0, 2980, 350.0, '265mm Stainless Steel Impellers',
            150, 100, 'Dual Cartridge Mechanical Seal', 'Cast Steel GP240GH / SS 316', 'ISO VG 46 Turbine Oil',
            'NU 316 ECM', '7316 BGM'
        ],
        [
            'IOG-COD-PMP-004', 'End-Suction High-Lift Process Water Pump 1 (450 m3/h)', 'pump', 'active', 'COD-PROCESS-PMP-01',
            'COD-PROCESS-PMP-01, COD-PROCESS-PMP-02', 'WTP Pump Shed Bay-1', '2021-12-05',
            'TRUE', 'Kirloskar Brothers', 'DB 150-400', 'KB-2021-9941', 2021,
            'RF-PMP-004', 'PO-2021-5542', '', 'Process water circulation pump supplying beneficiation wash headers',
            450.0, 60.0, 2975, 110.0, '390mm Cast Bronze',
            200, 150, 'Single Balanced Mechanical Seal', 'Cast Iron FG 260', 'Shell Gadus S2',
            '6317 C3', '7317 BECBM'
        ],
        [
            'IOG-COD-PMP-005', 'End-Suction High-Lift Process Water Pump 2 (450 m3/h)', 'pump', 'active', 'COD-PROCESS-PMP-02',
            'COD-PROCESS-PMP-01, COD-PROCESS-PMP-02', 'WTP Pump Shed Bay-2', '2021-12-05',
            'TRUE', 'Kirloskar Brothers', 'DB 150-400', 'KB-2021-9942', 2021,
            'RF-PMP-005', 'PO-2021-5542', '', 'Standby process water circulation pump with automated discharge valve',
            450.0, 60.0, 2975, 110.0, '390mm Cast Bronze',
            200, 150, 'Single Balanced Mechanical Seal', 'Cast Iron FG 260', 'Shell Gadus S2',
            '6317 C3', '7317 BECBM'
        ],
        [
            'IOG-COD-PMP-006', 'Hydrocyclone Booster Feed Pump 1 (280 m3/h)', 'pump', 'active', 'COD-HYDROCYCLONE-01',
            'COD-HYDROCYCLONE-01', 'Spiral Plant Pump Gallery', '2022-07-15',
            'TRUE', 'Warman (Weir Minerals)', '6/4 D-AH Metal', 'WM-2022-4419', 2022,
            'RF-PMP-006', 'PO-2022-4420', '', 'High chrome hard alloy slurry pump feeding desliming hydrocyclone cluster',
            280.0, 42.0, 1150, 75.0, '320mm Ultrachrome A05',
            150, 100, 'Expeller with PTFE Gland Packing', 'High Chrome White Iron (27% Cr)', 'ISO VG 68 Oil',
            'NU 316 ECM', '7316 BECBM'
        ],
        # Spares in warehouse
        [
            'IOG-COD-PMP-SPARE-01', 'Spare Wet-End Assembly for 8/6 Slurry Pump', 'pump', 'spare', '',
            'COD-SLURRY-PMP-01, COD-SLURRY-PMP-02', 'Central Mechanical Warehouse Rack-P1', '2023-04-18',
            'TRUE', 'Warman (Weir Minerals)', '8/6 E-AH Wet End', 'WM-2023-9901', 2023,
            'RF-PMP-SP-01', 'PO-2023-9970', '', 'Pre-assembled spare wet-end (volute liner, throatbush, impeller, frame plate liner)',
            350.0, 45.0, 988, 90.0, '380mm 4-Vane Closed',
            200, 150, 'Expeller Assembly Included', 'Ductile Iron with Natural Rubber', 'N/A (Wet End Assembly)',
            'N/A', 'N/A'
        ],
        [
            'IOG-COD-PMP-SPARE-02', 'Spare Bearing Cartridge Assembly for 8/6 Slurry Pump', 'pump', 'spare', '',
            'COD-SLURRY-PMP-01, COD-SLURRY-PMP-02', 'Central Mechanical Warehouse Rack-P2', '2023-04-18',
            'TRUE', 'Warman (Weir Minerals)', 'E-Frame Bearing Housing', 'WM-2023-9902', 2023,
            'RF-PMP-SP-02', 'PO-2023-9971', '', 'Complete pre-greased bearing housing cartridge with shaft and labyrinth seals',
            350.0, 45.0, 988, 90.0, 'N/A (Bearing Assembly)',
            0, 0, 'Labyrinth Oil Seals', 'Cast Iron Grade 250', 'ISO VG 68 Lubricating Oil',
            'NU 319 ECM', '7319 BECBM'
        ],
    ]
    write_sheet('Pumps', pump_cols, pump_data, c_blue)

    # 6. Reference Guide
    ref_headers = ['Target Equipment ID', 'Parent Machine Name', 'Physical Area', 'Panel Room', 'Power Panel', 'Feeder Cubicle', 'Installed Assets Breakdown']
    ref_data = [
        ['COD-JAW-CRUSH-01', 'Primary Jaw Crusher Station 1', 'CRUSHING-BENEF', 'MV-ROOM-01', '3.3KV-MV-SWG', '3.3KV-FDR-JAW-CRUSH', '1 x 450kW 3.3kV Motor (IOG-COD-MTR-001)'],
        ['COD-BALL-MILL-01', 'Beneficiation Grinding Ball Mill 1', 'CRUSHING-BENEF', 'MV-ROOM-01', '3.3KV-MV-SWG', '3.3KV-FDR-BALL-MILL', '1 x 630kW 3.3kV Motor (IOG-COD-MTR-002), 1 x Quarter-Turn Actuator (IOG-COD-ACT-002)'],
        ['COD-MINE-PUMP-01', 'Mine Pit High-Head Dewatering Pump 1', 'CRUSHING-BENEF', 'MV-ROOM-01', '3.3KV-MV-SWG', '3.3KV-FDR-MINE-PUMP', '1 x 350kW 3.3kV Motor (IOG-COD-MTR-003), 1 x Multi-Stage Dewatering Pump (IOG-COD-PMP-003)'],
        ['COD-CENT-COMP-01', 'Main Plant Centrifugal Air Compressor 1', 'CRUSHING-BENEF', 'MV-ROOM-01', '3.3KV-MV-SWG', '3.3KV-FDR-COMP-01', '1 x 250kW 3.3kV Motor (IOG-COD-MTR-004)'],
        ['COD-APRON-FDR-01', 'Heavy Duty Dump Hopper Apron Feeder 1', 'CRUSHING-BENEF', 'MCC-ROOM-01', 'MCC-01-CRUSH', 'MCC01-FDR-APRON-FDR', '1 x 90kW VFD Motor (IOG-COD-MTR-005), 1 x Planetary Gearbox (IOG-COD-GBX-003), 1 x Brake (IOG-COD-BRK-003)'],
        ['COD-OVERLAND-CV-01', 'Primary Overland Ore Conveyor 1', 'CRUSHING-BENEF', 'MCC-ROOM-01', 'MCC-01-CRUSH', 'MCC01-FDR-CV-01', '1 x 110kW Motor (IOG-COD-MTR-006), 1 x Bevel Gearbox (IOG-COD-GBX-002), 1 x EHT Thruster Brake (IOG-COD-BRK-001)'],
        ['COD-MINERAL-SIZER-01', 'Secondary Twin-Roll Mineral Sizer 1', 'CRUSHING-BENEF', 'MCC-ROOM-01', 'MCC-01-CRUSH', 'MCC01-FDR-SIZER-01', '1 x 132kW Motor (IOG-COD-MTR-007), 1 x Heavy Bevel-Helical Gearbox (IOG-COD-GBX-001)'],
        ['COD-CRANE-01', 'Crusher Bay Maintenance EOT Crane 40/10T', 'CRUSHING-BENEF', 'MCC-ROOM-01', 'MCC-01-CRUSH', 'MCC01-FDR-CRANE-01', '1 x 415V Crane Hoist Brake (IOG-COD-BRK-002)'],
        ['COD-BANANA-SCR-01', 'Double Deck Vibrating Banana Screen 1', 'SCREENING-PLANT', 'MCC-ROOM-02', 'MCC-02-SCREEN', 'MCC02-FDR-SCR-01', '1 x 55kW Vibrator Duty Motor (IOG-COD-MTR-008)'],
        ['COD-BANANA-SCR-02', 'Double Deck Vibrating Banana Screen 2', 'SCREENING-PLANT', 'MCC-ROOM-02', 'MCC-02-SCREEN', 'MCC02-FDR-SCR-02', '1 x 55kW Vibrator Duty Motor (IOG-COD-MTR-009)'],
        ['COD-PRODUCT-CV-02', 'Sized Ore Finished Product Conveyor 2', 'SCREENING-PLANT', 'MCC-ROOM-02', 'MCC-02-SCREEN', 'MCC02-FDR-CV-02', '1 x Shaft Gearbox (IOG-COD-GBX-004), 1 x EHT Brake (IOG-COD-BRK-005)'],
        ['COD-SLURRY-PMP-01', 'Spiral Feed Slurry Pump 1', 'CRUSHING-BENEF', 'MCC-ROOM-03', 'MCC-03-BENEF', 'MCC03-FDR-SLURRY-PMP-01', '1 x 90kW Slurry Motor (IOG-COD-MTR-010), 1 x Heavy Slurry Pump (IOG-COD-PMP-001)'],
        ['COD-SLURRY-PMP-02', 'Spiral Feed Slurry Pump 2 (Standby)', 'CRUSHING-BENEF', 'MCC-ROOM-03', 'MCC-03-BENEF', 'MCC03-FDR-SLURRY-PMP-02', '1 x 90kW Slurry Motor (IOG-COD-MTR-011), 1 x Heavy Slurry Pump (IOG-COD-PMP-002)'],
        ['COD-HYDROCYCLONE-01', 'Primary Desliming Hydrocyclone Cluster', 'CRUSHING-BENEF', 'MCC-ROOM-03', 'MCC-03-BENEF', 'MCC03-FDR-CYCLONE-FDR', '1 x Rotork IQ35 Modulating Actuator (IOG-COD-ACT-001), 1 x Booster Slurry Pump (IOG-COD-PMP-006)'],
        ['COD-THICKENER-01', 'Tailings High-Rate Slurry Thickener 1', 'TAILINGS-DISPOSAL', 'MCC-ROOM-04', 'MCC-04-TAIL', 'MCC04-FDR-THICKENER', '1 x Planetary Rake Gearbox (IOG-COD-GBX-005), 1 x Rotork IQ25 Underflow Actuator (IOG-COD-ACT-003)'],
        ['COD-PROCESS-PMP-01', 'High-Lift Process Water Circulation Pump 1', 'WATER-TREATMENT', 'WTP-PUMP-ROOM', 'MCC-05-PUMP', 'MCC05-FDR-PMP-01', '1 x 110kW Motor (IOG-COD-MTR-012), 1 x Water Pump (IOG-COD-PMP-004), 1 x Bypass Actuator (IOG-COD-ACT-004)'],
        ['COD-PROCESS-PMP-02', 'High-Lift Process Water Circulation Pump 2', 'WATER-TREATMENT', 'WTP-PUMP-ROOM', 'MCC-05-PUMP', 'MCC05-FDR-PMP-02', '1 x End-Suction Water Pump (IOG-COD-PMP-005)'],
        ['COD-WAGON-LOADER-01', 'Rapid Train Loading Shuttle Boom System', 'DISPATCH-AREA', 'DISPATCH-ROOM', 'MCC-06-DISP', 'MCC06-FDR-BOOM-CV', '1 x Shuttle Brake (IOG-COD-BRK-004), 1 x Telescopic Actuator (IOG-COD-ACT-005)'],
    ]
    write_sheet('Reference Guide', ref_headers, ref_data, c_navy)

    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    wb.save(output_path)
    print(f"Saved Asset Master Excel to: {output_path}")

if __name__ == '__main__':
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    h_path = os.path.join(base_dir, 'Hierarchy_Master_Sample_Medium.xlsx')
    a_path = os.path.join(base_dir, 'Asset_Master_Sample_Medium.xlsx')
    create_hierarchy_excel(h_path)
    create_asset_excel(a_path)

    # Also copy to Excel Import and Excel Import/SAMPLE/
    for sub in ['Excel Import', os.path.join('Excel Import', 'SAMPLE')]:
        target_h = os.path.join(base_dir, sub, 'Hierarchy_Master_Sample_Medium.xlsx')
        target_a = os.path.join(base_dir, sub, 'Asset_Master_Sample_Medium.xlsx')
        create_hierarchy_excel(target_h)
        create_asset_excel(target_a)
