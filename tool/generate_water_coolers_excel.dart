import 'dart:io';
import 'package:excel/excel.dart';

void main() {
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
  excel.rename(defaultSheet, 'Template');
  final sheet = excel['Template'];

  final headers = [
    'coolerType',
    'location',
    'make',
    'capacityLiters',
    'seqNo',
  ];

  sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

  final data = [
    // 1 to 21: Hot & Cold Dispensers of make Aquaguard
    ['Hot & Cold Dispenser', 'BF 1 Cast House', 'Aquaguard', '40 L/hr', '001'],
    ['Hot & Cold Dispenser', 'BF 2 Cast House', 'Aquaguard', '40 L/hr', '002'],
    ['Hot & Cold Dispenser', 'Pig Shift Cabin', 'Aquaguard', '40 L/hr', '003'],
    ['Hot & Cold Dispenser', 'Electrical Workshop', 'Aquaguard', '40 L/hr', '004'],
    ['Hot & Cold Dispenser', 'Mechanical Workshop', 'Aquaguard', '40 L/hr', '005'],
    ['Hot & Cold Dispenser', 'Dispensary', 'Aquaguard', '40 L/hr', '006'],
    ['Hot & Cold Dispenser', 'Machine Shop', 'Aquaguard', '40 L/hr', '007'],
    ['Hot & Cold Dispenser', 'Dispatch Area', 'Aquaguard', '40 L/hr', '008'],
    ['Hot & Cold Dispenser', 'Laboratory', 'Aquaguard', '40 L/hr', '009'],
    ['Hot & Cold Dispenser', 'DNG Gate', 'Aquaguard', '40 L/hr', '010'],
    ['Hot & Cold Dispenser', 'Shared Services Department', 'Aquaguard', '40 L/hr', '011'],
    ['Hot & Cold Dispenser', 'Raw Material Dept', 'Aquaguard', '40 L/hr', '012'],
    ['Hot & Cold Dispenser', 'Admin HR Building', 'Aquaguard', '40 L/hr', '013'],
    ['Hot & Cold Dispenser', 'PCI Control Building', 'Aquaguard', '40 L/hr', '014'],
    ['Hot & Cold Dispenser', 'LC Gate', 'Aquaguard', '40 L/hr', '015'],
    ['Hot & Cold Dispenser', 'Plant 5 Area', 'Aquaguard', '40 L/hr', '016'],
    ['Hot & Cold Dispenser', 'Contractor Shed', 'Aquaguard', '40 L/hr', '017'],
    ['Hot & Cold Dispenser', 'Central Invoice Office', 'Aquaguard', '40 L/hr', '018'],
    ['Hot & Cold Dispenser', 'RMHS 27MT Level', 'Aquaguard', '40 L/hr', '019'],
    ['Hot & Cold Dispenser', 'Devika Shed', 'Aquaguard', '40 L/hr', '020'],
    ['Hot & Cold Dispenser', 'RK Electrical Bay', 'Aquaguard', '40 L/hr', '021'],

    // 22 to 28: Storage Water Coolers
    ['Storage Water Cooler', 'BF 2 Area (Unit No. 2)', 'Other', '300 L/hr', '001'],
    ['Storage Water Cooler', 'Main Canteen (Unit No. 3)', 'Other', '300 L/hr', '002'],
    ['Storage Water Cooler', 'Dispatch Area (Unit No. 7)', 'Other', '200 L/hr', '003'],
    ['Storage Water Cooler', 'Contractor Shed', 'Voltas', '150 L/hr', '004'],
    ['Storage Water Cooler', 'Dispatch New Office', 'Voltas', '150 L/hr', '005'],
    ['Storage Water Cooler', 'Security Barrack', 'Blue Star', '200 L/hr', '006'],
    ['Storage Water Cooler', 'Dispatch Centralised Office', 'Voltas', '120 L/hr', '007'],

    // 29: RO + UV Water Cooler / Canteen
    ['RO + UV Water Cooler', 'Main Canteen Dining Hall', 'Aquaguard', '50 L/hr', '001'],
  ];

  for (var row in data) {
    sheet.appendRow(row.map((val) => TextCellValue(val)).toList());
  }

  // Reference sheet
  final refSheet = excel['Available Reference Options'];
  refSheet.appendRow([TextCellValue('AVAILABLE WATER COOLER TYPES')]);
  refSheet.appendRow([TextCellValue('Hot & Cold Dispenser')]);
  refSheet.appendRow([TextCellValue('Storage Water Cooler')]);
  refSheet.appendRow([TextCellValue('RO + UV Water Cooler')]);
  refSheet.appendRow([TextCellValue('Commercial SS Water Cooler')]);
  refSheet.appendRow([TextCellValue('Wall Mounted Chiller')]);
  refSheet.appendRow([TextCellValue('Other Water Coolers')]);

  final bytes = excel.save();
  if (bytes != null) {
    File('water_coolers_ready_import.xlsx').writeAsBytesSync(bytes);
    print('Successfully re-generated water_coolers_ready_import.xlsx without plant/unit or owner/dept columns.');
  }
}
