import 'dart:io';
import 'package:excel/excel.dart';

void main() {
  print('Generating clean Asset_Master_Sample_Medium.xlsx with isCritical, Motor/Gearbox/Pump Bearings, RFID, PO No, Installation Date, Image URL...');

  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';

  final commonPrefix = [
    'tagNo', 'name', 'type', 'status', 'parentEquipment',
    'applicableParentEquipmentIds', 'spareLocation', 'installationDate',
    'isCritical',
    'make', 'model', 'serialNo', 'manufacturingYear',
    'rfidTag', 'poNo', 'imageUrl', 'description',
  ];

  // -------------------------------------------------------------
  // Sheet 1: Motors (With DE/NDE Bearings)
  // -------------------------------------------------------------
  excel.rename(defaultSheet, 'Motors');
  Sheet motorSheet = excel['Motors'];

  final motorCols = [
    ...commonPrefix,
    'powerKw', 'voltage', 'fullLoadCurrent', 'noLoadCurrent', 'speedRpm',
    'poles', 'frequency', 'efficiency', 'powerFactor', 'frameSize',
    'mountingType', 'greaseType', 'motorType', 'dutyCycle', 'insulationClass',
    'couplingAvailable', 'couplingType', 'efficiencyClass', 'ipRating',
    'bearingDE', 'bearingNDE',
  ];
  motorSheet.appendRow(motorCols.map((e) => TextCellValue(e)).toList());

  final motors = [
    [
      'IOG-COD-MTR-001', '90kW 4P 415V Primary Sizer 1 Drive Motor', 'motor', 'active', 'IOG-COD-BF1-SIZER-01',
      'IOG-COD-BF1-SIZER-01, IOG-COD-BF1-SIZER-02', 'Bay-3 Shelf-B', '2022-04-15',
      'TRUE',
      'ABB', 'M3BP 280SMB 4', '3G13142001', '2022',
      'E280117000000201', 'PO-2022-8819', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=60', 'Heavy duty sizer main drive motor',
      '90', '415', '158', '45', '1485',
      '4', '50', '95.5', '0.87', '280S',
      'Foot Mounted (B3)', 'Mobil Polyrex EM', 'Induction Motor', 'S1 (Continuous)', 'Class F',
      'YES', 'Flexible Pin-Bush', 'IE3', 'IP55',
      '6317 C3', '6317 C3',
    ],
    [
      'IOG-COD-MTR-002', '90kW 4P 415V Primary Sizer 2 Standby Drive Motor', 'motor', 'active', 'IOG-COD-BF1-SIZER-02',
      'IOG-COD-BF1-SIZER-01, IOG-COD-BF1-SIZER-02', 'Bay-3 Shelf-B', '2022-04-18',
      'TRUE',
      'Siemens', '1LE1501-2DB23', 'SI-8829101', '2022',
      'E280117000000202', 'PO-2022-8819', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=60', 'Heavy duty sizer standby drive motor',
      '90', '415', '156', '44', '1485',
      '4', '50', '95.6', '0.88', '280S',
      'Foot Mounted (B3)', 'Mobil Polyrex EM', 'Induction Motor', 'S1 (Continuous)', 'Class H',
      'YES', 'Flexible Pin-Bush', 'IE3', 'IP56',
      '6317 C3', '6317 C3',
    ],
    [
      'IOG-COD-MTR-003', '22kW 6P 415V Grizzly Vibrating Screen Motor', 'motor', 'active', 'IOG-COD-BF1-VIB-SCREEN-01',
      'IOG-COD-BF1-VIB-SCREEN-01', 'Bay-2 Shelf-A', '2023-02-10',
      'TRUE',
      'Havells', 'IE3-180L-6', 'HV-2023-441', '2023',
      'E280117000000203', 'PO-2023-1104', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=60', 'Vibrating screen drive motor',
      '22', '415', '41', '12', '975',
      '6', '50', '93.0', '0.83', '180L',
      'Foot Mounted (B3)', 'Shell Gadus S2 V220', 'Vibrator Motor', 'S1 (Continuous)', 'Class F',
      'YES', 'Cardan Shaft', 'IE3', 'IP65',
      '6311 C3', '6311 C3',
    ],
    [
      'IOG-COD-MTR-004', '55kW 8P 415V Cast House Crane Main Hoist Motor', 'motor', 'active', 'IOG-COD-BF1-CH-CRANE-01',
      'IOG-COD-BF1-CH-CRANE-01', 'Crane Shed Bay-1', '2021-08-20',
      'TRUE',
      'BBL', 'MW 280M 8', 'BBL-77192', '2021',
      'E280117000000204', 'PO-2021-4901', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=60', 'Hot metal ladle crane main hoist slip ring motor',
      '55', '415', '108', '28', '730',
      '8', '50', '91.8', '0.79', '280M',
      'Foot Mounted (B3)', 'Kluberplex BEM 41-132', 'Slip Ring (Wound Rotor)', 'S4 40% CDF (Crane Duty)', 'Class F',
      'YES', 'Geared Coupling', 'IE2', 'IP55',
      '6317 C3', 'NU 317 C3',
    ],
    [
      'IOG-COD-MTR-005', '15kW 6P 415V Crane Long Travel Drive Motor', 'motor', 'active', 'IOG-COD-BF1-CH-CRANE-01',
      'IOG-COD-BF1-CH-CRANE-01, IOG-COD-BF1-AUX-CRANE-01', 'Crane Shed Bay-1', '2021-08-22',
      'FALSE',
      'BBL', 'MW 160L 6', 'BBL-88102', '2021',
      'E280117000000205', 'PO-2021-4901', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=60', 'Crane gantry long travel motor',
      '15', '415', '31', '9', '960',
      '6', '50', '90.2', '0.81', '160L',
      'Flange Mounted (B5)', 'Kluberplex BEM 41-132', 'Slip Ring (Wound Rotor)', 'S4 40% CDF (Crane Duty)', 'Class F',
      'YES', 'Brake-Wheel Coupling', 'IE2', 'IP55',
      '6309 C3', '6309 C3',
    ],
    [
      'IOG-COD-MTR-006', '45kW 2P 415V Runner Fume Exhaust Blower Motor', 'motor', 'active', 'IOG-COD-BF1-EXHAUST-FAN-01',
      'IOG-COD-BF1-EXHAUST-FAN-01', 'Bay-1 Shelf-C', '2022-09-15',
      'TRUE',
      'ABB', 'M3BP 225SMB 2', '3G-99120', '2022',
      'E280117000000206', 'PO-2022-6701', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=60', 'Cast house fume extraction fan motor',
      '45', '415', '76', '18', '2960',
      '2', '50', '94.2', '0.89', '225S',
      'Foot Mounted (B3)', 'Mobil Polyrex EM', 'Induction Motor', 'S1 (Continuous)', 'Class F',
      'YES', 'Spacer Tyre Coupling', 'IE3', 'IP55',
      '6313 C3', '6313 C3',
    ],
    [
      'IOG-COD-MTR-007', '75kW 4P 415V Cooling Water Pump 1 Drive Motor', 'motor', 'active', 'IOG-COD-BF1-CWP-01',
      'IOG-COD-BF1-CWP-01, IOG-COD-BF1-CWP-02', 'WTP Pump House Bay', '2021-11-20',
      'TRUE',
      'Kirloskar Brothers', 'KBL-280S-4', 'KBL-M-2021', '2021',
      'E280117000000207', 'PO-2021-9920', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=60', 'Tuyere cooling water circulation motor',
      '75', '415', '130', '35', '1480',
      '4', '50', '95.0', '0.86', '280S',
      'Foot Mounted (B3)', 'Mobil Polyrex EM', 'Induction Motor', 'S1 (Continuous)', 'Class F',
      'YES', 'Lovejoy Spider Coupling', 'IE3', 'IP55',
      '6317 C3', '6317 C3',
    ],
    [
      'IOG-COD-MTR-008', '75kW 4P 415V Cooling Water Pump 2 Drive Motor', 'motor', 'active', 'IOG-COD-BF1-CWP-02',
      'IOG-COD-BF1-CWP-01, IOG-COD-BF1-CWP-02', 'WTP Pump House Bay', '2021-11-20',
      'TRUE',
      'Kirloskar Brothers', 'KBL-280S-4', 'KBL-M-2022', '2021',
      'E280117000000208', 'PO-2021-9920', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=60', 'Stave cooling water circulation motor',
      '75', '415', '130', '35', '1480',
      '4', '50', '95.0', '0.86', '280S',
      'Foot Mounted (B3)', 'Mobil Polyrex EM', 'Induction Motor', 'S1 (Continuous)', 'Class F',
      'YES', 'Lovejoy Spider Coupling', 'IE3', 'IP55',
      '6317 C3', '6317 C3',
    ],
    [
      'IOG-COD-MTR-009', '90kW 2P 415V Rotary Screw Compressor Motor', 'motor', 'active', 'IOG-COD-BF1-HP-COMP-01',
      'IOG-COD-BF1-HP-COMP-01, IOG-COD-BF1-HP-COMP-02', 'Compressor Shed', '2023-06-05',
      'TRUE',
      'Siemens', '1LE1503-2BA23', 'SI-COMP-01', '2023',
      'E280117000000209', 'PO-2023-5501', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=60', 'Plant air compressor main drive motor',
      '90', '415', '152', '38', '2970',
      '2', '50', '95.8', '0.90', '280M',
      'Flange Mounted (B35)', 'Klüberquiet BQ 72-72', 'Induction Motor', 'S1 (Continuous)', 'Class H',
      'YES', 'Direct Flanged Gear', 'IE4', 'IP55',
      '6316 C3', '6316 C3',
    ],
    [
      'IOG-COD-MTR-010', '90kW 4P 415V Sizer Spare Induction Motor', 'motor', 'spare', '',
      'IOG-COD-BF1-SIZER-01, IOG-COD-BF1-SIZER-02', 'Warehouse Rack W-12', '2023-08-15',
      'TRUE',
      'ABB', 'M3BP 280SMB 4', '3G-SPARE-01', '2023',
      'E280117000000210', 'PO-2023-7711', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=60', 'Critical spare motor for primary sizers',
      '90', '415', '158', '45', '1485',
      '4', '50', '95.5', '0.87', '280S',
      'Foot Mounted (B3)', 'Mobil Polyrex EM', 'Induction Motor', 'S1 (Continuous)', 'Class F',
      'YES', 'Flexible Pin-Bush', 'IE3', 'IP55',
      '6317 C3', '6317 C3',
    ],
  ];

  for (final row in motors) {
    motorSheet.appendRow(row.map((e) => TextCellValue(e)).toList());
  }

  // -------------------------------------------------------------
  // Sheet 2: Brakes
  // -------------------------------------------------------------
  Sheet brakeSheet = excel['Brakes'];
  final brakeCols = [
    ...commonPrefix,
    'brakeType', 'thrusterCapacityKg', 'voltageType', 'voltageRating',
    'drumDiaMm', 'drumWidthMm', 'drumInstallation', 'mountingBoltSize',
    'mountingBoltCount', 'mountingLengthMm', 'mountingWidthMm',
    'brakingTorqueNm', 'brakeShoeLining',
  ];
  brakeSheet.appendRow(brakeCols.map((e) => TextCellValue(e)).toList());

  final brakes = [
    [
      'IOG-COD-BRK-001', 'EHT Thruster Brake 300mm Dia (Main Hoist)', 'brake', 'active', 'IOG-COD-BF1-CH-CRANE-01',
      'IOG-COD-BF1-CH-CRANE-01', 'Brake Yard Bay-1', '2023-01-20',
      'TRUE',
      'Electromag', 'EHT-300-50', 'BRK-9901', '2023',
      'E280117000000211', 'PO-2023-3301', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=60', '60T hot metal crane main hoist holding brake',
      'Electro-Hydraulic Thruster (EHT)', '50', 'AC', '415',
      '300', '125', 'Motor Shaft', 'M16',
      '4', '350', '250',
      '650', 'Asbestos-Free Molded Friction Material',
    ],
    [
      'IOG-COD-BRK-002', 'EHT Thruster Brake 250mm Dia (Aux Hoist)', 'brake', 'active', 'IOG-COD-BF1-CH-CRANE-01',
      'IOG-COD-BF1-CH-CRANE-01, IOG-COD-BF1-AUX-CRANE-01', 'Brake Yard Bay-1', '2023-01-22',
      'TRUE',
      'Electromag', 'EHT-250-30', 'BRK-9902', '2023',
      'E280117000000212', 'PO-2023-3301', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=60', '15T aux hoist holding brake',
      'Electro-Hydraulic Thruster (EHT)', '30', 'AC', '415',
      '250', '100', 'Motor Shaft', 'M12',
      '4', '300', '200',
      '350', 'Asbestos-Free Molded Friction Material',
    ],
    [
      'IOG-COD-BRK-003', 'DC Electromagnetic Disc Brake (Long Travel)', 'brake', 'active', 'IOG-COD-BF1-AUX-CRANE-01',
      'IOG-COD-BF1-AUX-CRANE-01', 'Brake Yard Bay-2', '2022-03-14',
      'FALSE',
      'Pintsch Bubenzer', 'KFB 16', 'PB-2022-108', '2022',
      'E280117000000213', 'PO-2022-4410', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=60', 'Auxiliary crane bridge motion brake',
      'DC Electromagnetic Solenoid', '16', 'DC', '24',
      '200', '80', 'Gearbox Input Shaft', 'M10',
      '4', '220', '160',
      '200', 'Organic Friction Lining',
    ],
    [
      'IOG-COD-BRK-004', 'Heavy Duty Hydraulic Caliper Disc Brake', 'brake', 'active', 'IOG-COD-BF1-SIZER-01',
      'IOG-COD-BF1-SIZER-01, IOG-COD-BF1-SIZER-02', 'Heavy Shed Rack 4', '2022-07-30',
      'TRUE',
      'Twiflex', 'GMR-SD', 'TW-99881', '2022',
      'E280117000000214', 'PO-2022-9011', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=60', 'Mineral sizer roll emergency brake',
      'Hydraulic Caliper Disc Brake', '120', 'Hydraulic', '160',
      '500', '30', 'Sizer Rotor Shaft', 'M20',
      '6', '400', '300',
      '1200', 'Sintered Metallic Bronze Lining',
    ],
    [
      'IOG-COD-BRK-005', 'EHT 300mm Dia Spare Thruster Brake', 'brake', 'spare', '',
      'IOG-COD-BF1-CH-CRANE-01', 'Warehouse Rack W-08', '2023-09-01',
      'TRUE',
      'Electromag', 'EHT-300-50', 'BRK-SP-01', '2023',
      'E280117000000215', 'PO-2023-8802', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=60', 'Warehouse spare crane thruster brake',
      'Electro-Hydraulic Thruster (EHT)', '50', 'AC', '415',
      '300', '125', 'Motor Shaft', 'M16',
      '4', '350', '250',
      '650', 'Asbestos-Free Molded Friction Material',
    ],
  ];

  for (final row in brakes) {
    brakeSheet.appendRow(row.map((e) => TextCellValue(e)).toList());
  }

  // -------------------------------------------------------------
  // Sheet 3: Actuators
  // -------------------------------------------------------------
  Sheet actSheet = excel['Actuators'];
  final actuatorCols = [
    ...commonPrefix,
    'actuatorType', 'torqueOrThrust', 'operatingTimeSeconds',
    'controlSignal', 'valveFlangeStandard', 'valveType', 'valveSize',
  ];
  actSheet.appendRow(actuatorCols.map((e) => TextCellValue(e)).toList());

  final actuators = [
    [
      'IOG-COD-ACT-001', 'Rotork IQ35 Pro Multi-Turn Actuator 4-20mA', 'actuator', 'active', 'IOG-COD-BF1-SNORT-VALVE',
      'IOG-COD-BF1-SNORT-VALVE', 'Actuator Rack Bay-2', '2023-03-10',
      'TRUE',
      'Rotork', 'IQ35 Pro', 'ACT-2023-01', '2023',
      'E280117000000221', 'PO-2023-4412', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=60', 'Cold blast snort valve regulating actuator',
      'Electric Multi-Turn', '600', '30',
      '4-20mA Modulating', 'ISO 5211 (F14)', 'Butterfly Valve', '12 Inch (DN300)',
    ],
    [
      'IOG-COD-ACT-002', 'Pneumatic Quarter-Turn Actuator (CWP 1 Discharge)', 'actuator', 'active', 'IOG-COD-BF1-CWP-01',
      'IOG-COD-BF1-CWP-01, IOG-COD-BF1-CWP-02', 'WTP Rack 1', '2022-06-15',
      'FALSE',
      'Auma', 'SQ 12.2', 'AUM-2022-901', '2022',
      'E280117000000222', 'PO-2022-5510', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=60', 'Pump 1 discharge isolating valve actuator',
      'Pneumatic Quarter-Turn', '350', '15',
      '24V DC ON-OFF', 'ISO 5211 (F10)', 'Butterfly Valve', '8 Inch (DN200)',
    ],
    [
      'IOG-COD-ACT-003', 'Pneumatic Quarter-Turn Actuator (CWP 2 Discharge)', 'actuator', 'active', 'IOG-COD-BF1-CWP-02',
      'IOG-COD-BF1-CWP-01, IOG-COD-BF1-CWP-02', 'WTP Rack 1', '2022-06-15',
      'FALSE',
      'Auma', 'SQ 12.2', 'AUM-2022-902', '2022',
      'E280117000000223', 'PO-2022-5510', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=60', 'Pump 2 discharge isolating valve actuator',
      'Pneumatic Quarter-Turn', '350', '15',
      '24V DC ON-OFF', 'ISO 5211 (F10)', 'Butterfly Valve', '8 Inch (DN200)',
    ],
    [
      'IOG-COD-ACT-004', 'Belimo Electric Linear Modulating Actuator', 'actuator', 'active', 'IOG-COD-BF1-HP-COMP-01',
      'IOG-COD-BF1-HP-COMP-01, IOG-COD-BF1-HP-COMP-02', 'Compressor Bay Rack 2', '2023-04-18',
      'FALSE',
      'Belimo', 'NVK24A-SZ-TPC', 'BEL-88210', '2023',
      'E280117000000224', 'PO-2023-6621', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=60', 'Compressor inlet air modulating control valve',
      'Electric Linear Modulating', '150', '35',
      '4-20mA Modulating', 'Direct Linear Yoke', 'Globe Control Valve', '4 Inch (DN100)',
    ],
    [
      'IOG-COD-ACT-005', 'Rotork IQ35 Pro Spare Actuator', 'actuator', 'spare', '',
      'IOG-COD-BF1-SNORT-VALVE', 'Warehouse Rack W-04', '2023-09-12',
      'TRUE',
      'Rotork', 'IQ35 Pro', 'ACT-SPARE-01', '2023',
      'E280117000000225', 'PO-2023-8820', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=60', 'Critical warehouse spare actuator for blast furnace',
      'Electric Multi-Turn', '600', '30',
      '4-20mA Modulating', 'ISO 5211 (F14)', 'Butterfly Valve', '12 Inch (DN300)',
    ],
  ];

  for (final row in actuators) {
    actSheet.appendRow(row.map((e) => TextCellValue(e)).toList());
  }

  // -------------------------------------------------------------
  // Sheet 4: Gearboxes (With DE/NDE Bearings)
  // -------------------------------------------------------------
  Sheet gbxSheet = excel['Gearboxes'];
  final gearboxCols = [
    ...commonPrefix,
    'powerKw', 'gearRatio', 'oilType', 'oilCapacity',
    'inputSpeedRpm', 'outputSpeedRpm', 'inputShaftMm', 'outputShaftMm',
    'lubricationMethod', 'mountingOrientation',
    'bearingDE', 'bearingNDE',
  ];
  gbxSheet.appendRow(gearboxCols.map((e) => TextCellValue(e)).toList());

  final gearboxes = [
    [
      'IOG-COD-GBX-001', 'Bevel Helical 3-Stage Primary Sizer 1 Gearbox', 'gearbox', 'active', 'IOG-COD-BF1-SIZER-01',
      'IOG-COD-BF1-SIZER-01, IOG-COD-BF1-SIZER-02', 'Heavy Storage Shed A', '2022-05-12',
      'TRUE',
      'Elecon', 'PBN 355-3', 'EL-2022-881', '2022',
      'E280117000000231', 'PO-2022-7721', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=60', 'Dual roll mineral sizer speed reduction gearbox',
      '90', '31.5 : 1', 'ISO VG 320', '65',
      '1480', '47', '75', '180',
      'Splash / Forced', 'Horizontal Foot',
      '22220 E', '23236 CC/W33',
    ],
    [
      'IOG-COD-GBX-002', 'Bevel Helical 3-Stage Primary Sizer 2 Gearbox', 'gearbox', 'active', 'IOG-COD-BF1-SIZER-02',
      'IOG-COD-BF1-SIZER-01, IOG-COD-BF1-SIZER-02', 'Heavy Storage Shed A', '2022-05-15',
      'TRUE',
      'Elecon', 'PBN 355-3', 'EL-2022-882', '2022',
      'E280117000000232', 'PO-2022-7721', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=60', 'Dual roll mineral sizer speed reduction gearbox',
      '90', '31.5 : 1', 'ISO VG 320', '65',
      '1480', '47', '75', '180',
      'Splash / Forced', 'Horizontal Foot',
      '22220 E', '23236 CC/W33',
    ],
    [
      'IOG-COD-GBX-003', 'Cast House Crane Main Hoist Gearbox', 'gearbox', 'active', 'IOG-COD-BF1-CH-CRANE-01',
      'IOG-COD-BF1-CH-CRANE-01', 'Crane Shed Bay-1', '2021-09-10',
      'TRUE',
      'Shanthi Gears', 'MHD 500', 'SG-2021-99', '2021',
      'E280117000000233', 'PO-2021-3810', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=60', '60T crane main hoist heavy reduction gearbox',
      '55', '40 : 1', 'ISO VG 460', '80',
      '730', '18.25', '65', '160',
      'Splash Lubrication', 'Foot Mounted',
      'NU 318 ECM', '23134 CC/W33',
    ],
    [
      'IOG-COD-GBX-004', 'Crane Long Travel Drive Helical Gearbox', 'gearbox', 'active', 'IOG-COD-BF1-AUX-CRANE-01',
      'IOG-COD-BF1-AUX-CRANE-01, IOG-COD-BF1-CH-CRANE-01', 'Crane Shed Bay-1', '2021-09-12',
      'FALSE',
      'Premium Transmission', 'AL-70', 'PT-2021-301', '2021',
      'E280117000000234', 'PO-2021-3810', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=60', 'Crane gantry long travel geared motor unit',
      '15', '25 : 1', 'ISO VG 220', '12',
      '960', '38.4', '38', '70',
      'Synthetic Oil Lube', 'Hollow Shaft Shaft-Mounted',
      '6308 2RS', '32212 Taper Roller',
    ],
    [
      'IOG-COD-GBX-005', 'Elecon PBN 355-3 Sizer Spare Gearbox', 'gearbox', 'spare', '',
      'IOG-COD-BF1-SIZER-01, IOG-COD-BF1-SIZER-02', 'Heavy Storage Bay 3', '2023-07-20',
      'TRUE',
      'Elecon', 'PBN 355-3', 'EL-SPARE-01', '2023',
      'E280117000000235', 'PO-2023-6620', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=60', 'Critical warehouse spare reduction gearbox for sizers',
      '90', '31.5 : 1', 'ISO VG 320', '65',
      '1480', '47', '75', '180',
      'Splash / Forced', 'Horizontal Foot',
      '22220 E', '23236 CC/W33',
    ],
  ];

  for (final row in gearboxes) {
    gbxSheet.appendRow(row.map((e) => TextCellValue(e)).toList());
  }

  // -------------------------------------------------------------
  // Sheet 5: Pumps (With DE/NDE Bearings)
  // -------------------------------------------------------------
  Sheet pmpSheet = excel['Pumps'];
  final pumpCols = [
    ...commonPrefix,
    'flowRate', 'head', 'speedRpm', 'pumpPower', 'impellerSize',
    'suctionFlangeMm', 'dischargeFlangeMm', 'sealType', 'casingMaterial', 'greaseType',
    'bearingDE', 'bearingNDE',
  ];
  pmpSheet.appendRow(pumpCols.map((e) => TextCellValue(e)).toList());

  final pumps = [
    [
      'IOG-COD-PMP-001', 'End Suction Cooling Water Pump 1 (350 m3/h)', 'pump', 'active', 'IOG-COD-BF1-CWP-01',
      'IOG-COD-BF1-CWP-01, IOG-COD-BF1-CWP-02', 'Pump Bay 2', '2021-11-25',
      'TRUE',
      'Kirloskar Brothers', 'DB 125-330', 'KBL-2021-009', '2021',
      'E280117000000241', 'PO-2021-9920', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=60', 'Tuyere cooling water circulation pump',
      '350', '65', '1480', '75', '330mm',
      '150', '125', 'Mechanical Seal', 'Cast Iron FG 260', 'ISO VG 68 Turbinol Oil',
      'NU 312', '7312 BECBP',
    ],
    [
      'IOG-COD-PMP-002', 'End Suction Cooling Water Pump 2 (350 m3/h)', 'pump', 'active', 'IOG-COD-BF1-CWP-02',
      'IOG-COD-BF1-CWP-01, IOG-COD-BF1-CWP-02', 'Pump Bay 2', '2021-11-25',
      'TRUE',
      'Kirloskar Brothers', 'DB 125-330', 'KBL-2021-010', '2021',
      'E280117000000242', 'PO-2021-9920', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=60', 'Stave cooling water circulation pump',
      '350', '65', '1480', '75', '330mm',
      '150', '125', 'Mechanical Seal', 'Cast Iron FG 260', 'ISO VG 68 Turbinol Oil',
      'NU 312', '7312 BECBP',
    ],
    [
      'IOG-COD-PMP-003', 'Slag Granulation Heavy Duty Slurry Pump', 'pump', 'active', 'IOG-COD-BF1-SLAG-PUMP-01',
      'IOG-COD-BF1-SLAG-PUMP-01', 'Slag Yard Bay-1', '2022-04-10',
      'TRUE',
      'Warman', '6/4 D-AH', 'WM-2022-77', '2022',
      'E280117000000243', 'PO-2022-8101', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=60', 'Slag slurry disposal pump with high chrome liner',
      '250', '45', '980', '55', '375mm',
      '150', '100', 'Gland Packing', 'High Chrome 27% (A05)', 'Mobilith SHC 220 Grease',
      'NU 318', '22318 Spherical Roller',
    ],
    [
      'IOG-COD-PMP-004', 'Axial Piston Mud Gun Hydraulic Pump (160 Bar)', 'pump', 'active', 'IOG-COD-BF1-MUDGUN-HYD-01',
      'IOG-COD-BF1-MUDGUN-HYD-01, IOG-COD-BF1-DRILL-HYD-01', 'Hydraulic Room Shed', '2022-08-20',
      'TRUE',
      'Rexroth Bosch', 'A10VSO 71 DFR', 'RX-2022-108', '2022',
      'E280117000000244', 'PO-2022-7703', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=60', 'Taphole mudgun hydraulic powerpack pump',
      '120', '160', '1480', '37', 'Swashplate Piston Block',
      '50', '32', 'Viton Shaft Seal', 'Cast Iron GGG-40', 'ISO VG 46 Anti-Wear Hydraulic Oil',
      'Taper Roller 30310', 'Taper Roller 30310',
    ],
    [
      'IOG-COD-PMP-005', 'Kirloskar DB 125-330 Bare Shaft Spare Pump', 'pump', 'spare', '',
      'IOG-COD-BF1-CWP-01, IOG-COD-BF1-CWP-02', 'Warehouse Rack W-02', '2023-05-18',
      'TRUE',
      'Kirloskar Brothers', 'DB 125-330', 'KBL-SPARE-01', '2023',
      'E280117000000245', 'PO-2023-5590', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=60', 'Critical warehouse bare shaft spare cooling pump',
      '350', '65', '1480', '75', '330mm',
      '150', '125', 'Mechanical Seal', 'Cast Iron FG 260', 'ISO VG 68 Turbinol Oil',
      'NU 312', '7312 BECBP',
    ],
  ];

  for (final row in pumps) {
    pmpSheet.appendRow(row.map((e) => TextCellValue(e)).toList());
  }

  // -------------------------------------------------------------
  // Sheet 6: Reference Guide
  // -------------------------------------------------------------
  Sheet refSheet = excel['Reference Guide'];
  refSheet.appendRow([TextCellValue('PLANT-UNIT "IOG-COD" MASTER EQUIPMENT LINKING REFERENCE')]);
  refSheet.appendRow([
    TextCellValue('Parent Machine ID (Use in parentEquipment column)'),
    TextCellValue('Full Document Key'),
    TextCellValue('Machine Name'),
    TextCellValue('Physical Area'),
    TextCellValue('Substation Room'),
    TextCellValue('Power Panel / MCC'),
    TextCellValue('Power Feeder ID'),
  ]);

  final parentEquipments = [
    ['IOG-COD-BF1-SIZER-01', 'IOG-COD-BF1-SIZER-01', 'Primary Mineral Sizer Machine 1', 'BF1-SIZER-AREA', 'MCC-ROOM-02', 'MCC-02', 'MCC02-SIZER-01'],
    ['IOG-COD-BF1-SIZER-02', 'IOG-COD-BF1-SIZER-02', 'Primary Mineral Sizer Machine 2', 'BF1-SIZER-AREA', 'MCC-ROOM-02', 'MCC-02', 'MCC02-SIZER-02'],
    ['IOG-COD-BF1-VIB-SCREEN-01', 'IOG-COD-BF1-VIB-SCREEN-01', 'Primary Grizzly Vibrating Screen', 'BF1-SIZER-AREA', 'MCC-ROOM-02', 'MCC-02', 'MCC02-SCREEN-01'],
    ['IOG-COD-BF1-CH-CRANE-01', 'IOG-COD-BF1-CH-CRANE-01', 'Cast House 60T Hot Metal Ladle Crane', 'BF1-CAST-HOUSE', 'MCC-ROOM-01', 'MCC-01', 'MCC01-CRANE-01'],
    ['IOG-COD-BF1-AUX-CRANE-01', 'IOG-COD-BF1-AUX-CRANE-01', 'Cast House 10T Maintenance Crane', 'BF1-CAST-HOUSE', 'MCC-ROOM-01', 'MCC-01', 'MCC01-CRANE-02'],
    ['IOG-COD-BF1-EXHAUST-FAN-01', 'IOG-COD-BF1-EXHAUST-FAN-01', 'Runner Fume Exhaust Fan 1', 'BF1-CAST-HOUSE', 'MCC-ROOM-01', 'MCC-01', 'MCC01-EXHAUST-01'],
    ['IOG-COD-BF1-MUDGUN-HYD-01', 'IOG-COD-BF1-MUDGUN-HYD-01', 'Taphole Mud Gun Hydraulic Powerpack', 'BF1-CAST-HOUSE', 'MCC-ROOM-01', 'MCC-01', 'MCC01-HYD-01'],
    ['IOG-COD-BF1-DRILL-HYD-01', 'IOG-COD-BF1-DRILL-HYD-01', 'Taphole Drill Machine Hydraulic Unit', 'BF1-CAST-HOUSE', 'MCC-ROOM-01', 'MCC-01', 'MCC01-HYD-01'],
    ['IOG-COD-BF1-CWP-01', 'IOG-COD-BF1-CWP-01', 'Cooling Water Circulating Pump 1', 'BF1-WTP', 'WTP-ELEC-ROOM', 'WTP-MCC-01', 'WTP-PUMP-FDR-01'],
    ['IOG-COD-BF1-CWP-02', 'IOG-COD-BF1-CWP-02', 'Cooling Water Circulating Pump 2', 'BF1-WTP', 'WTP-ELEC-ROOM', 'WTP-MCC-01', 'WTP-PUMP-FDR-02'],
    ['IOG-COD-BF1-HP-COMP-01', 'IOG-COD-BF1-HP-COMP-01', 'High Pressure Air Compressor 1', 'BF1-COMP-HOUSE', 'COMP-ELEC-ROOM', 'COMP-MCC-01', 'COMP-FDR-01'],
    ['IOG-COD-BF1-HP-COMP-02', 'IOG-COD-BF1-HP-COMP-02', 'High Pressure Air Compressor 2', 'BF1-COMP-HOUSE', 'COMP-ELEC-ROOM', 'COMP-MCC-01', 'COMP-FDR-02'],
    ['IOG-COD-BF1-SLAG-PUMP-01', 'IOG-COD-BF1-SLAG-PUMP-01', 'Slag Granulation Slurry Pump 1', 'BF1-SLAG-YARD', 'WTP-ELEC-ROOM', 'WTP-MCC-01', 'WTP-PUMP-FDR-01'],
    ['IOG-COD-BF1-SNORT-VALVE', 'IOG-COD-BF1-SNORT-VALVE', 'Cold Blast Snort Valve System', 'BF1-CAST-HOUSE', 'MCC-ROOM-01', 'MCC-01', 'MCC01-EXHAUST-01'],
  ];

  for (final row in parentEquipments) {
    refSheet.appendRow(row.map((e) => TextCellValue(e)).toList());
  }

  // Save File
  final fileBytes = excel.save();
  if (fileBytes != null) {
    final file = File('Asset_Master_Sample_Medium.xlsx');
    file.writeAsBytesSync(fileBytes);
    print('Successfully regenerated: ${file.absolute.path} (${fileBytes.length} bytes)');
  }
}
