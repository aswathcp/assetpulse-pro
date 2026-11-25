import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class ExcelService {
  /// Fixes Excel packages / openpyxl files that use absolute package paths
  /// (e.g. Target="/xl/worksheets/sheet1.xml") or contain empty inlineStr cells
  /// which crash package:excel.
  List<int> _sanitizeExcelBytes(List<int> bytes) {
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

        if (file.isFile && file.name.contains('worksheets/sheet') && file.name.endsWith('.xml')) {
          var content = utf8.decode(file.content as List<int>);
          bool sheetModified = false;
          try {
            final doc = XmlDocument.parse(content);
            for (var node in doc.findAllElements('c')) {
              if (node.getAttribute('t') == 'inlineStr' && node.findAllElements('t').isEmpty) {
                node.removeAttribute('t');
                sheetModified = true;
              }
              if (node.getAttribute('t') == 'str' && node.findElements('v').isEmpty) {
                node.removeAttribute('t');
                sheetModified = true;
              }
            }
            if (sheetModified) {
              content = doc.toXmlString();
              final fixedBytes = utf8.encode(content);
              newArchive.addFile(ArchiveFile(file.name, fixedBytes.length, fixedBytes));
              modified = true;
              continue;
            }
          } catch (_) {}
        }

        newArchive.addFile(file);
      }
      if (modified) {
        final encoded = ZipEncoder().encode(newArchive);
        if (encoded != null) return encoded;
      }
    } catch (e) {
      debugPrint('Warning: Excel byte sanitization skipped: $e');
    }
    return bytes;
  }

  // Parse Excel Bytes to List of Maps (First Sheet)
  // Returns: List<Map<ColumnName, PrimitiveValue>>
  List<Map<String, dynamic>> parseExcel(List<int> bytes) {
    try {
      final cleanBytes = _sanitizeExcelBytes(bytes);
      var excel = Excel.decodeBytes(cleanBytes);
      if (excel.tables.isEmpty) return [];

      // Prioritize the primary data sheet (skipping reference / lookup / guide tabs)
      Sheet? table;
      for (var key in excel.tables.keys) {
        final lower = key.toLowerCase();
        if (lower.contains('lookup') || lower.contains('reference') || lower.contains('guide') || lower.contains('list')) {
          continue;
        }
        final candidate = excel.tables[key];
        if (candidate != null && candidate.maxRows > 1) {
          table = candidate;
          break;
        }
      }
      table ??= excel.tables[excel.tables.keys.first];
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
          if (headers[j].isEmpty) continue;
          if (j < row.length) {
            final primitive = _extractValue(row[j]?.value);
            rowMap[headers[j]] = primitive;
            if (primitive != null && primitive.toString().trim().isNotEmpty) isEmpty = false;
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
      final cleanBytes = _sanitizeExcelBytes(bytes);
      var excel = Excel.decodeBytes(cleanBytes);
      if (excel.tables.isEmpty) return [];

      List<Map<String, dynamic>> results = [];

      for (var tableName in excel.tables.keys) {
        try {
          // Skip reference guide, readme, instructions and config sheets
          final lowerSheet = tableName.toLowerCase();
          if (lowerSheet.contains('reference') ||
              lowerSheet.contains('guide') ||
              lowerSheet.contains('option') ||
              lowerSheet.contains('readme') ||
              lowerSheet.contains('config') ||
              lowerSheet.contains('instruction') ||
              lowerSheet.contains('help') ||
              lowerSheet.contains('notes')) {
            continue;
          }

          final table = excel.tables[tableName];
          if (table == null || table.rows.isEmpty || table.maxRows < 2) continue;

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
              rowMap['_sheetName'] = tableName;

              // Auto-infer hierarchy target collection from sheet name
              if (lowerSheet.contains('location') || lowerSheet.contains('area') || lowerSheet.contains('physical')) {
                rowMap['_collection'] = 'locations';
              } else if (lowerSheet.contains('room') || lowerSheet.contains('substation')) {
                rowMap['_collection'] = 'panel_rooms';
              } else if (lowerSheet.contains('panel') || lowerSheet.contains('mcc') || lowerSheet.contains('pcc')) {
                rowMap['_collection'] = 'panels';
              } else if (lowerSheet.contains('feeder')) {
                rowMap['_collection'] = 'feeders';
              } else if (lowerSheet.contains('transformer')) {
                rowMap['_collection'] = 'transformers';
              } else if (lowerSheet.contains('fault') || lowerSheet.contains('failure')) {
                rowMap['_collection'] = 'fault_types';
              } else if (lowerSheet.contains('odc') || lowerSheet.contains('damage') || lowerSheet.contains('cause')) {
                rowMap['_collection'] = 'odc';
              } else if (lowerSheet.contains('equipment') || lowerSheet.contains('machin') || lowerSheet.contains('master')) {
                rowMap['_collection'] = 'master_equipments';
              }

              // Auto-infer asset type from sheet name if type column is missing or empty
              if (rowMap['type'] == null || rowMap['type'].toString().isEmpty) {
                if (lowerSheet.contains('motor')) {
                  rowMap['type'] = 'motor';
                } else if (lowerSheet.contains('gear')) {
                  rowMap['type'] = 'gearbox';
                } else if (lowerSheet.contains('pump')) {
                  rowMap['type'] = 'pump';
                } else if (lowerSheet.contains('brake')) {
                  rowMap['type'] = 'brake';
                } else if (lowerSheet.contains('actuat')) {
                  rowMap['type'] = 'actuator';
                }
              }
              results.add(rowMap);
            }
          }
        } catch (sheetError) {
          debugPrint('Error parsing sheet "$tableName": $sheetError');
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
