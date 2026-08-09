// Manual CSV parsing - no external package needed

class CsvService {
  // Convert CSV String to List of Maps (Header based)
  List<Map<String, dynamic>> parseCsvToMap(String csvData) {
    final lines = csvData.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return [];

    final headers = lines.first.split(',').map((e) => e.trim()).toList();
    final result = <Map<String, dynamic>>[];

    for (int i = 1; i < lines.length; i++) {
      final values = lines[i].split(',');
      if (values.isEmpty) continue;

      final map = <String, dynamic>{};
      for (int j = 0; j < headers.length; j++) {
        map[headers[j]] = j < values.length ? values[j].trim() : '';
      }
      result.add(map);
    }

    return result;
  }

  // Generate CSV String from List of Maps
  String generateCsvFromMap(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return '';

    final headers = data.first.keys.toList();
    final buffer = StringBuffer();

    buffer.writeln(headers.join(','));

    for (var map in data) {
      buffer.writeln(headers.map((h) => '${map[h] ?? ''}').join(','));
    }

    return buffer.toString();
  }
}
