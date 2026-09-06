import 'dart:io';
import 'package:excel/excel.dart';

void main() {
  print('Generating Hierarchy_Master_Sample_Medium.xlsx...');

  var excel = Excel.createExcel();
  String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';

  // -------------------------------------------------------------
  // Sheet 1: Physical Areas
  // -------------------------------------------------------------
  excel.rename(defaultSheet, 'Physical Areas');
  Sheet locSheet = excel['Physical Areas'];
  locSheet.appendRow([
    TextCellValue('id'),
    TextCellValue('name'),
    TextCellValue('description'),
  ]);

  final locations = [
    ['BF1-CAST-HOUSE', 'Blast Furnace Cast House Floor', 'Primary hot metal tapping, trough & runner floor'],
    ['BF1-SIZER-AREA', 'Primary Mineral Sizer & Screening Area', 'Raw ore screening, sizing and crushing station'],
    ['BF1-WTP', 'Water Treatment Plant & Cooling Towers', 'Cooling water pump house and filtration yard'],
    ['BF1-SUBSTATION', '33kV/6.6kV Main Substation Yard', 'Step-down transformer yard and main switchgear'],
    ['BF1-COMP-HOUSE', 'Compressed Air & Blower House', 'High pressure utility and instrument air compressor house'],
    ['BF1-RMHS', 'Raw Material Handling System & Hoppers', 'Conveyor junction houses and batching bins'],
    ['BF1-SLAG-YARD', 'Slag Granulation & Cooling Yard', 'Slag water quenching pit, dewatering and conveyor yard'],
    ['BF1-CONTROL-ROOM', 'Main Blast Furnace Automation Control Room', 'Central DCS, PLC panels and SCADA operator desks'],
  ];

  for (final row in locations) {
    locSheet.appendRow(row.map((e) => TextCellValue(e)).toList());
  }

  // -------------------------------------------------------------
  // Sheet 2: Panel Rooms
  // -------------------------------------------------------------
  Sheet prSheet = excel['Panel Rooms'];
  prSheet.appendRow([
    TextCellValue('id'),
    TextCellValue('name'),
    TextCellValue('description'),
    TextCellValue('locationId'),
  ]);

  final panelRooms = [
    ['MCC-ROOM-01', 'Cast House Main Substation Room 1', 'Primary 415V switchgear room for cast house drives', 'BF1-CAST-HOUSE'],
    ['MCC-ROOM-02', 'Sizer & Screening Substation Room 2', '415V MCC room powering crushers, sizers & screen drives', 'BF1-SIZER-AREA'],
    ['WTP-ELEC-ROOM', 'WTP Electrical Control Substation', 'Substation for cooling water circulating pumps and filters', 'BF1-WTP'],
    ['MAIN-SUBSTATION-01', 'Central Power Substation Room', '6.6kV & 415V primary power distribution switchboards', 'BF1-SUBSTATION'],
    ['COMP-ELEC-ROOM', 'Compressor House Electrical Room', 'Substation housing high capacity compressor motor starters', 'BF1-COMP-HOUSE'],
  ];

  for (final row in panelRooms) {
    prSheet.appendRow(row.map((e) => TextCellValue(e)).toList());
  }

  // -------------------------------------------------------------
  // Sheet 3: Panels / MCCs
  // -------------------------------------------------------------
  Sheet pnlSheet = excel['Panels'];
  pnlSheet.appendRow([
    TextCellValue('id'),
    TextCellValue('name'),
    TextCellValue('type'),
    TextCellValue('description'),
    TextCellValue('panelRoomId'),
  ]);

  final panels = [
    ['MCC-01', 'Cast House Main 415V MCC Panel', 'MCC', '415V 50kA MCC fed from Cast House TR-1', 'MCC-ROOM-01'],
    ['MCC-02', 'Sizer Drives & Screens 415V MCC', 'MCC', 'Sizer and conveyor starter MCC panel', 'MCC-ROOM-02'],
    ['PCC-01', 'Main Power Control Center 1 (Incomers)', 'PCC', '415V 3200A 65kA Power Control Center', 'MAIN-SUBSTATION-01'],
    ['PCC-02', 'Auxiliary Power Control Center 2', 'PCC', '415V 2000A auxiliary distribution board', 'MAIN-SUBSTATION-01'],
    ['WTP-MCC-01', 'Water Treatment Plant 415V MCC', 'MCC', 'Cooling pump motor starters and VFD modules', 'WTP-ELEC-ROOM'],
    ['COMP-MCC-01', 'Compressor House 415V MCC', 'MCC', 'High pressure compressor starter panel', 'COMP-ELEC-ROOM'],
    ['LDB-01', 'Cast House Lighting Distribution Board', 'LDB', '415V/240V lighting & small power DB', 'MCC-ROOM-01'],
    ['MLDB-01', 'Sizer Area Master Lighting DB', 'LDB', 'Yard floodlight & high mast distribution panel', 'MCC-ROOM-02'],
  ];

  for (final row in panels) {
    pnlSheet.appendRow(row.map((e) => TextCellValue(e)).toList());
  }

  // -------------------------------------------------------------
  // Sheet 4: Feeders
  // -------------------------------------------------------------
  Sheet fdrSheet = excel['Feeders'];
  fdrSheet.appendRow([
    TextCellValue('id'),
    TextCellValue('name'),
    TextCellValue('type'),
    TextCellValue('description'),
    TextCellValue('panelId'),
  ]);

  final feeders = [
    ['PCC01-INC-01', '3200A Incomer 1 from 2.5MVA TR-1', 'Incomer', 'ACB 3200A 4P Microprocessor Release', 'PCC-01'],
    ['PCC01-INC-02', '3200A Incomer 2 from 2.5MVA TR-2', 'Incomer', 'ACB 3200A 4P Microprocessor Release', 'PCC-01'],
    ['PCC01-BUS-COUPLER', '3200A Bus Coupler ACB', 'Bus Coupler', 'Tie breaker between Bus-A and Bus-B', 'PCC-01'],
    ['MCC01-INC-01', '1600A Incomer to Cast House MCC', 'Incomer', 'Fed from PCC-01 Bus-A', 'MCC-01'],
    ['MCC01-CRANE-01', '250A Hot Metal Crane Power Feeder', 'Feeder', 'DSL Busbar power supply feeder', 'MCC-01'],
    ['MCC01-CRANE-02', '160A Auxiliary Crane Power Feeder', 'Feeder', 'Aux Crane DSL power feed', 'MCC-01'],
    ['MCC01-EXHAUST-01', '100A Runner Exhaust Blower Feeder', 'Feeder', 'DOL Starter with MPMR relay', 'MCC-01'],
    ['MCC01-HYD-01', '63A Mud Gun Hydraulic Powerpack Feeder', 'Feeder', 'Starter module with MPCB protection', 'MCC-01'],
    ['MCC02-INC-01', '1250A Incomer to Sizer MCC-02', 'Incomer', 'Fed from PCC-01 Bus-B', 'MCC-02'],
    ['MCC02-SIZER-01', '250A Primary Sizer Motor 1 Feeder', 'Feeder', 'VFD Feeder with bypass contactor', 'MCC-02'],
    ['MCC02-SIZER-02', '250A Primary Sizer Motor 2 Feeder', 'Feeder', 'VFD Feeder with bypass contactor', 'MCC-02'],
    ['MCC02-SCREEN-01', '100A Vibrating Screen Feeder', 'Feeder', 'DOL Starter with electronic overload', 'MCC-02'],
    ['WTP-PUMP-FDR-01', '160A Cooling Water Pump 1 Feeder', 'Feeder', 'Soft Starter module with bypass', 'WTP-MCC-01'],
    ['WTP-PUMP-FDR-02', '160A Cooling Water Pump 2 Feeder', 'Feeder', 'Soft Starter module with bypass', 'WTP-MCC-01'],
    ['COMP-FDR-01', '200A HP Air Compressor 1 Feeder', 'Feeder', 'Star-Delta starter module', 'COMP-MCC-01'],
    ['COMP-FDR-02', '200A HP Air Compressor 2 Feeder', 'Feeder', 'Star-Delta starter module', 'COMP-MCC-01'],
  ];

  for (final row in feeders) {
    fdrSheet.appendRow(row.map((e) => TextCellValue(e)).toList());
  }

  // -------------------------------------------------------------
  // Sheet 5: Master Equipment
  // -------------------------------------------------------------
  Sheet meSheet = excel['Master Equipment'];
  meSheet.appendRow([
    TextCellValue('id'),
    TextCellValue('name'),
    TextCellValue('type'),
    TextCellValue('description'),
    TextCellValue('locationId'),
    TextCellValue('panelRoomId'),
    TextCellValue('panelId'),
    TextCellValue('feederId'),
  ]);

  final equipment = [
    ['BF1-SIZER-01', 'Primary Mineral Sizer Machine 1', 'Crushing & Sizing', 'Heavy-duty dual-roll mineral sizer', 'BF1-SIZER-AREA', 'MCC-ROOM-02', 'MCC-02', 'MCC02-SIZER-01'],
    ['BF1-SIZER-02', 'Primary Mineral Sizer Machine 2', 'Crushing & Sizing', 'Standby dual-roll mineral sizer', 'BF1-SIZER-AREA', 'MCC-ROOM-02', 'MCC-02', 'MCC02-SIZER-02'],
    ['BF1-VIB-SCREEN-01', 'Primary Grizzly Vibrating Screen', 'Screening', 'Heavy duty double-deck vibrating screen', 'BF1-SIZER-AREA', 'MCC-ROOM-02', 'MCC-02', 'MCC02-SCREEN-01'],
    ['BF1-CH-CRANE-01', 'Cast House 60T Hot Metal Ladle Crane', 'EOT Crane', '60T/15T EOT Crane for molten iron handling', 'BF1-CAST-HOUSE', 'MCC-ROOM-01', 'MCC-01', 'MCC01-CRANE-01'],
    ['BF1-AUX-CRANE-01', 'Cast House 10T Maintenance Crane', 'EOT Crane', '10T Maintenance EOT crane over trough', 'BF1-CAST-HOUSE', 'MCC-ROOM-01', 'MCC-01', 'MCC01-CRANE-02'],
    ['BF1-EXHAUST-FAN-01', 'Runner Fume Exhaust Fan 1', 'Industrial Fan', 'High-volume centrifugal exhaust blower', 'BF1-CAST-HOUSE', 'MCC-ROOM-01', 'MCC-01', 'MCC01-EXHAUST-01'],
    ['BF1-MUDGUN-HYD-01', 'Taphole Mud Gun Hydraulic Powerpack', 'Hydraulic Unit', '160 Bar hydraulic power unit for mudgun', 'BF1-CAST-HOUSE', 'MCC-ROOM-01', 'MCC-01', 'MCC01-HYD-01'],
    ['BF1-DRILL-HYD-01', 'Taphole Drill Machine Hydraulic Unit', 'Hydraulic Unit', 'Hydraulic drill pack for taphole opening', 'BF1-CAST-HOUSE', 'MCC-ROOM-01', 'MCC-01', 'MCC01-HYD-01'],
    ['BF1-CWP-01', 'Cooling Water Circulating Pump 1', 'Centrifugal Pump', '350 m3/hr Tuyere cooling water pump', 'BF1-WTP', 'WTP-ELEC-ROOM', 'WTP-MCC-01', 'WTP-PUMP-FDR-01'],
    ['BF1-CWP-02', 'Cooling Water Circulating Pump 2', 'Centrifugal Pump', '350 m3/hr Stave cooling water pump', 'BF1-WTP', 'WTP-ELEC-ROOM', 'WTP-MCC-01', 'WTP-PUMP-FDR-02'],
    ['BF1-HP-COMP-01', 'High Pressure Air Compressor 1', 'Air Compressor', 'Rotary screw compressor 12 Bar 850 CFM', 'BF1-COMP-HOUSE', 'COMP-ELEC-ROOM', 'COMP-MCC-01', 'COMP-FDR-01'],
    ['BF1-HP-COMP-02', 'High Pressure Air Compressor 2', 'Air Compressor', 'Rotary screw compressor 12 Bar 850 CFM', 'BF1-COMP-HOUSE', 'COMP-ELEC-ROOM', 'COMP-MCC-01', 'COMP-FDR-02'],
    ['BF1-SLAG-PUMP-01', 'Slag Granulation Slurry Pump 1', 'Slurry Pump', 'Heavy duty wear-resistant slurry pump', 'BF1-SLAG-YARD', 'WTP-ELEC-ROOM', 'WTP-MCC-01', 'WTP-PUMP-FDR-01'],
    ['BF1-SNORT-VALVE', 'Cold Blast Snort Valve System', 'Actuated Valve', 'Pneumatic & electric actuated relief valve', 'BF1-CAST-HOUSE', 'MCC-ROOM-01', 'MCC-01', 'MCC01-EXHAUST-01'],
  ];

  for (final row in equipment) {
    meSheet.appendRow(row.map((e) => TextCellValue(e)).toList());
  }

  // -------------------------------------------------------------
  // Sheet 6: Reference Guide
  // -------------------------------------------------------------
  Sheet refSheet = excel['Reference Guide'];
  refSheet.appendRow([TextCellValue('HIERARCHY MASTER DATA STRUCTURE & LINKING GUIDE')]);
  refSheet.appendRow([
    TextCellValue('Tier'),
    TextCellValue('Sheet Name'),
    TextCellValue('ID Tag Format'),
    TextCellValue('Parent Link Column'),
    TextCellValue('Description'),
  ]);
  refSheet.appendRow([
    TextCellValue('Tier 1'),
    TextCellValue('Physical Areas'),
    TextCellValue('BF1-CAST-HOUSE, BF1-SIZER-AREA'),
    TextCellValue('N/A (Root)'),
    TextCellValue('Geographical or functional plant zone in the unit'),
  ]);
  refSheet.appendRow([
    TextCellValue('Tier 2'),
    TextCellValue('Panel Rooms'),
    TextCellValue('MCC-ROOM-01, WTP-ELEC-ROOM'),
    TextCellValue('locationId (Optional)'),
    TextCellValue('Substation, Switchgear or MCC electrical room'),
  ]);
  refSheet.appendRow([
    TextCellValue('Tier 3'),
    TextCellValue('Panels'),
    TextCellValue('MCC-01, PCC-01, LDB-01'),
    TextCellValue('panelRoomId'),
    TextCellValue('Switchboard, MCC or PCC distribution panel'),
  ]);
  refSheet.appendRow([
    TextCellValue('Tier 4'),
    TextCellValue('Feeders'),
    TextCellValue('MCC01-CRANE-01, MCC02-SIZER-01'),
    TextCellValue('panelId'),
    TextCellValue('Breaker, starter module or power feeder module'),
  ]);
  refSheet.appendRow([
    TextCellValue('Tier 5'),
    TextCellValue('Master Equipment'),
    TextCellValue('BF1-SIZER-01, BF1-CH-CRANE-01'),
    TextCellValue('locationId, panelRoomId, panelId, feederId'),
    TextCellValue('Physical machine tag holding electrical/mechanical assets'),
  ]);

  final bytes = excel.save();
  if (bytes != null) {
    final file = File('Hierarchy_Master_Sample_Medium.xlsx');
    file.writeAsBytesSync(bytes);
    print('Successfully generated: ${file.absolute.path} (${bytes.length} bytes)');
  }
}
