import 'dart:io';
import 'package:excel/excel.dart';

void main() {
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
  excel.rename(defaultSheet, 'Template');
  final sheet = excel['Template'];

  final headers = [
    'location',
    'seqNo',
  ];

  sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

  final data = [
    ['BF 1 Sizer', '001'],
    ['BF 2 Sizer', '002'],
    ['Contractor Shed', '003'],
    ['Dispatch', '004'],
    ['Plant 5', '005'],
    ['Jayanti Yard', '006'],
    ['27MTR Level', '007'],
    ['Plant 8', '008'],
  ];

  for (var row in data) {
    sheet.appendRow(row.map((val) => TextCellValue(val)).toList());
  }

  final bytes = excel.save();
  if (bytes != null) {
    File('high_mast_ready_import.xlsx').writeAsBytesSync(bytes);
    print('Successfully re-generated high_mast_ready_import.xlsx with only location and seqNo.');
  }
}
