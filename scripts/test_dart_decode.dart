import 'dart:io';
import 'dart:convert';
import 'package:excel/excel.dart';
import 'package:archive/archive.dart';

List<int> sanitizeExcelBytes(List<int> bytes) {
  try {
    final archive = ZipDecoder().decodeBytes(bytes);
    final newArchive = Archive();
    bool modified = false;

    for (var file in archive) {
      if (file.isFile && file.name.endsWith('workbook.xml.rels')) {
        final content = utf8.decode(file.content as List<int>);
        if (content.contains('Target="/xl/')) {
          final fixed = content.replaceAll('Target="/xl/', 'Target="');
          final fixedBytes = utf8.encode(fixed);
          newArchive.addFile(ArchiveFile(file.name, fixedBytes.length, fixedBytes));
          modified = true;
          continue;
        }
      }
      newArchive.addFile(file);
    }
    if (modified) {
      final encoded = ZipEncoder().encode(newArchive);
      if (encoded != null) return encoded;
    }
  } catch (e) {
    print('Warning: Excel byte sanitization skipped: $e');
  }
  return bytes;
}

void main() {
  for (final filename in [
    'Hierarchy_Master_Sample_Medium.xlsx',
    'Asset_Master_Sample_Medium.xlsx'
  ]) {
    final file = File(filename);
    if (!file.existsSync()) {
      print('File not found: $filename');
      exit(1);
    }
    final rawBytes = file.readAsBytesSync();
    final cleanBytes = sanitizeExcelBytes(rawBytes);
    final excel = Excel.decodeBytes(cleanBytes);
    print('=== $filename ===');
    print('Sheets decoded: ${excel.tables.keys.toList()}');
    for (final table in excel.tables.keys) {
      final t = excel.tables[table]!;
      print('  Sheet "$table": ${t.maxRows} rows, ${t.maxColumns} cols');
    }
  }
  print('\n[DART DECODE SUCCESS] Both Excel workbooks decoded perfectly by package:excel!');
}
