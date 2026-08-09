import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart';

class ExcelService {
  // Parse Excel Bytes to List of Maps (First Sheet)
  // Returns: List<Map<ColumnName, PrimitiveValue>>
  List<Map<String, dynamic>> parseExcel(List<int> bytes) {
    try {
      var excel = Excel.decodeBytes(bytes);
      if (excel.tables.isEmpty) return [];

      // Use the first table found
      final table = excel.tables[excel.tables.keys.first];
      if (table == null || table.maxRows == 0) return [];

      List<Map<String, dynamic>> results = [];
      List<String> headers = [];

      // Get headers from first row
      final headerRow = table.rows.first;
      for (var cell in headerRow) {
        headers.add(_extractValue(cell?.value)?.toString().trim() ?? ''); 
      }

      // Read Data Rows
      for (int i = 1; i < table.rows.length; i++) {
        final row = table.rows[i];
        Map<String, dynamic> rowMap = {};
        bool isEmpty = true;
        
        for (int j = 0; j < headers.length; j++) {
          // Always include all header keys — default to null for blank/missing cells
          // Extract primitive values so Firestore can serialize them
          if (j < row.length) {
            final primitive = _extractValue(row[j]?.value);
            rowMap[headers[j]] = primitive;
            if (primitive != null) isEmpty = false;
          } else {
            rowMap[headers[j]] = null; // Pad missing trailing columns
          }
        }
        
        if (!isEmpty) {
          results.add(rowMap);
        }
      }
      
      return results;
    } catch (e) {
      debugPrint('Excel Parse Error: $e');
      return [];
    }
  }

  // Parse All Sheets in Excel Bytes (e.g. Multi-Tab Asset Master Templates)
  List<Map<String, dynamic>> parseAllSheets(List<int> bytes) {
    try {
      var excel = Excel.decodeBytes(bytes);
      if (excel.tables.isEmpty) return [];

      List<Map<String, dynamic>> results = [];

      for (var tableName in excel.tables.keys) {
        // Skip reference guide sheets
        final lowerSheet = tableName.toLowerCase();
        if (lowerSheet.contains('reference') || lowerSheet.contains('guide') || lowerSheet.contains('option')) {
          continue;
        }

        final table = excel.tables[tableName];
        if (table == null || table.maxRows < 2) continue;

        List<String> headers = [];
        final headerRow = table.rows.first;
        for (var cell in headerRow) {
          headers.add(_extractValue(cell?.value)?.toString().trim() ?? '');
        }

        for (int i = 1; i < table.rows.length; i++) {
          final row = table.rows[i];
          Map<String, dynamic> rowMap = {};
          bool isEmpty = true;

          for (int j = 0; j < headers.length; j++) {
            if (headers[j].isEmpty) continue;
            if (j < row.length) {
              final primitive = _extractValue(row[j]?.value);
              rowMap[headers[j]] = primitive;
              if (primitive != null) isEmpty = false;
            } else {
              rowMap[headers[j]] = null;
            }
          }

          if (!isEmpty) {
            // Auto-infer type from sheet name if type column is missing or empty
            if (rowMap['type'] == null || rowMap['type'].toString().isEmpty) {
              if (lowerSheet.contains('motor')) {
                rowMap['type'] = 'motor';
              } else if (lowerSheet.contains('gear')) {
                rowMap['type'] = 'gearbox';
              } else if (lowerSheet.contains('pump')) {
                rowMap['type'] = 'pump';
              }
            }
            results.add(rowMap);
          }
        }
      }

      return results;
    } catch (e) {
      debugPrint('Excel Multi-Sheet Parse Error: $e');
      return [];
    }
  }

  /// Extracts a plain Dart primitive from excel 4.x CellValue sealed types.
  /// This is required because Firestore cannot serialize CellValue objects.
  dynamic _extractValue(CellValue? cellValue) {
    if (cellValue == null) return null;
    if (cellValue is TextCellValue) {
      // In excel 4.x, TextCellValue.value is a TextSpan with a .text property
      final text = cellValue.value.text ?? '';
      return text.isEmpty ? null : text;
    }
    if (cellValue is IntCellValue) return cellValue.value;
    if (cellValue is DoubleCellValue) return cellValue.value;
    if (cellValue is BoolCellValue) return cellValue.value;
    if (cellValue is DateCellValue) return cellValue.asDateTimeLocal().toIso8601String();
    if (cellValue is DateTimeCellValue) return cellValue.asDateTimeLocal().toIso8601String();
    if (cellValue is TimeCellValue) return cellValue.toString();
    // Fallback for any unrecognised types
    final str = cellValue.toString();
    return str.isEmpty ? null : str;
  }

  // Generate Excel Bytes from List of Maps
  List<int>? generateExcel(List<Map<String, dynamic>> data, String sheetName) {
    if (data.isEmpty) return null;

    var excel = Excel.createExcel();
    // Rename default sheet
    String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheet, sheetName);
    
    Sheet sheetObject = excel[sheetName];
    
    // Headers
    List<String> headers = data.first.keys.toList();
    sheetObject.appendRow(headers.map((e) => TextCellValue(e)).toList());
    
    // Data
    for (var map in data) {
      List<CellValue> row = [];
      for (var h in headers) {
         final val = map[h];
         if (val == null) {
           row.add(TextCellValue(''));
         } else if (val is num) {
           row.add(DoubleCellValue(val.toDouble())); // or IntCellValue check
         } else {
           row.add(TextCellValue(val.toString()));
         }
      }
      sheetObject.appendRow(row);
    }
    
    return excel.save();
  }
}
