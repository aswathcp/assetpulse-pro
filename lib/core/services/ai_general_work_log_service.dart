import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'ai_fault_log_service.dart';
import '../../features/log_data/data/models/general_work_log_model.dart';
import '../../features/assets/data/models/master_equipment_model.dart';

class ParsedGeneralWorkAiDraft {
  final DateTime? date;
  final String shift;
  final String? location;
  final List<String> detectedEngineers;
  final List<String> detectedWorkmen;
  final List<EquipmentWorkBlock> equipmentWorks;

  ParsedGeneralWorkAiDraft({
    this.date,
    this.shift = 'as',
    this.location,
    this.detectedEngineers = const [],
    this.detectedWorkmen = const [],
    this.equipmentWorks = const [],
  });
}

class AiGeneralWorkLogService {
  static final AiGeneralWorkLogService _instance = AiGeneralWorkLogService._internal();
  factory AiGeneralWorkLogService() => _instance;
  AiGeneralWorkLogService._internal();

  Future<ParsedGeneralWorkAiDraft> extractGeneralWorkFromText({
    required String rawText,
    List<MasterEquipmentModel> availableEquipments = const [],
    List<String> registeredUserNames = const [],
    List<String> registeredWorkmenNames = const [],
  }) async {
    final cleanText = rawText.trim();
    if (cleanText.isEmpty) {
      throw Exception('Please provide shift notes or dictation text first.');
    }

    final apiKey = await AiFaultLogService().getApiKey();

    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final draft = await _callGeminiApi(
          rawText: cleanText,
          apiKey: apiKey,
          availableEquipments: availableEquipments,
          registeredUserNames: registeredUserNames,
          registeredWorkmenNames: registeredWorkmenNames,
        );
        if (draft != null) return draft;
      } catch (e) {
        debugPrint('Gemini Cloud General Work AI parse error: $e');
      }
    }

    // High performance offline fallback
    return _parseWithLocalRules(
      rawText: cleanText,
      availableEquipments: availableEquipments,
      registeredUserNames: registeredUserNames,
      registeredWorkmenNames: registeredWorkmenNames,
    );
  }

  Future<ParsedGeneralWorkAiDraft?> _callGeminiApi({
    required String rawText,
    required String apiKey,
    required List<MasterEquipmentModel> availableEquipments,
    required List<String> registeredUserNames,
    required List<String> registeredWorkmenNames,
  }) async {
    final models = ['gemini-1.5-flash', 'gemini-2.0-flash', 'gemini-1.5-pro'];

    final equipmentCatalog = availableEquipments
        .take(50)
        .map((e) => '{"id": "${e.id}", "name": "${e.name}"}')
        .join(',\n');

    final systemInstruction = """
You are an expert Industrial Reliability & Plant Maintenance AI.
The shift engineer has provided freeform shift notes/observations.
Extract and structure the data into JSON.
Critically: group the tasks by equipment/machinery/area. If multiple works are done on one equipment, group those tasks under that single equipment, then start the next equipment.

RAW SHIFT NOTES:
\"\"\"
$rawText
\"\"\"

ACTIVE EQUIPMENT CATALOG (MATCH IF POSSIBLE):
[$equipmentCatalog]

REGISTERED USERS/ENGINEERS:
${jsonEncode(registeredUserNames.take(40).toList())}

WORKMEN/TECHNICIANS:
${jsonEncode(registeredWorkmenNames.take(40).toList())}

RETURN ONLY PURE JSON with this EXACT structure (no markdown wrappers):
{
  "date": "YYYY-MM-DD",
  "shift": "as" or "bs" or "cs" or "gs",
  "location": "General plant area (e.g. Blast Furnace 2)",
  "detectedEngineers": ["Name1", "Name2"],
  "detectedWorkmen": ["Name1", "Name2"],
  "equipmentWorks": [
    {
      "equipmentName": "Name of Equipment",
      "matchedEquipmentId": "ID from catalog if matched or null",
      "subAssetName": "Motor / Pump / Cable / Valve if any or null",
      "feederName": "Feeder or Panel name if any or null",
      "location": "Specific area if any",
      "category": "Motors & Drives" or "Cabling & Power Distribution" or "Lighting & Illumination" or "Cranes & Material Handling" or "Preventive Maintenance (PM)" or "Instrumentation & Automation" or "Plant Facilities & Utilities" or "General Maintenance",
      "tasks": [
        "Task 1 description",
        "Task 2 description"
      ],
      "pendingFollowUp": "Any unfinished job or note for next shift (or null)",
      "status": "completed" or "pending"
    }
  ]
}
""";

    for (final model in models) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
        );

        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': [
                  {
                    'parts': [{'text': systemInstruction}]
                  }
                ],
                'generationConfig': {
                  'temperature': 0.1,
                  'responseMimeType': 'application/json',
                },
              }),
            )
            .timeout(const Duration(seconds: 14));

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          final candidates = body['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final partText = candidates[0]['content']['parts'][0]['text']?.toString() ?? '';
            final cleanJson = partText.replaceAll('```json', '').replaceAll('```', '').trim();
            final Map<String, dynamic> data = jsonDecode(cleanJson);

            DateTime? parsedDate;
            if (data['date'] != null) {
              parsedDate = DateTime.tryParse(data['date'].toString());
            }

            final engineers = (data['detectedEngineers'] as List?)?.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList() ?? [];
            final workmen = (data['detectedWorkmen'] as List?)?.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList() ?? [];

            final rawWorks = data['equipmentWorks'] as List? ?? [];
            final List<EquipmentWorkBlock> blocks = [];

            for (int i = 0; i < rawWorks.length; i++) {
              final w = rawWorks[i];
              final tasks = (w['tasks'] as List?)?.map((t) => t.toString().trim()).where((t) => t.isNotEmpty).toList() ?? [];
              if (tasks.isEmpty && w['equipmentName'] == null) continue;

              blocks.add(
                EquipmentWorkBlock(
                  id: (i + 1).toString(),
                  masterEquipmentId: w['matchedEquipmentId']?.toString(),
                  equipmentName: w['equipmentName']?.toString() ?? 'Equipment ${i + 1}',
                  assetName: w['subAssetName']?.toString(),
                  feederName: w['feederName']?.toString(),
                  location: w['location']?.toString(),
                  category: w['category']?.toString() ?? 'General Maintenance',
                  tasks: tasks,
                  pendingFollowUp: w['pendingFollowUp']?.toString(),
                  status: (w['status'] ?? 'completed').toString(),
                ),
              );
            }

            return ParsedGeneralWorkAiDraft(
              date: parsedDate,
              shift: data['shift']?.toString().toLowerCase() ?? 'as',
              location: data['location']?.toString(),
              detectedEngineers: engineers,
              detectedWorkmen: workmen,
              equipmentWorks: blocks,
            );
          }
        }
      } catch (e) {
        debugPrint('Error with $model in AiGeneralWorkLogService: $e');
      }
    }
    return null;
  }

  ParsedGeneralWorkAiDraft _parseWithLocalRules({
    required String rawText,
    required List<MasterEquipmentModel> availableEquipments,
    required List<String> registeredUserNames,
    required List<String> registeredWorkmenNames,
  }) {
    // Regex for date
    DateTime? detectedDate;
    final dateReg = RegExp(r'(?:date\s*[:\-\–]?\s*)?(\b\d{1,2})[\.\-\/](\d{1,2})[\.\-\/](\d{2,4})\b', caseSensitive: false);
    final match = dateReg.firstMatch(rawText);
    if (match != null) {
      final day = int.tryParse(match.group(1)!) ?? 1;
      final month = int.tryParse(match.group(2)!) ?? 1;
      var year = int.tryParse(match.group(3)!) ?? DateTime.now().year;
      if (year < 100) year += 2000;
      try {
        detectedDate = DateTime(year, month, day);
      } catch (_) {}
    }

    final lower = rawText.toLowerCase();
    final List<String> foundEngineers = [];
    final List<String> foundWorkmen = [];

    for (final eng in registeredUserNames) {
      if (lower.contains(eng.toLowerCase()) && !foundEngineers.contains(eng)) {
        foundEngineers.add(eng);
      }
    }

    for (final w in registeredWorkmenNames) {
      if (lower.contains(w.toLowerCase()) && !foundWorkmen.contains(w)) {
        foundWorkmen.add(w);
      }
    }

    // Split lines
    final lines = rawText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final List<String> tasks = [];
    final numberedReg = RegExp(r'^(\*?\d+[\.\)\-]\*?)\s*(.+)$');
    final bulletReg = RegExp(r'^[\*\-\•]\s*(.+)$');

    for (final line in lines) {
      if (dateReg.hasMatch(line) && line.length < 15) continue;
      final numMatch = numberedReg.firstMatch(line);
      if (numMatch != null) {
        tasks.add(numMatch.group(2)!.trim());
        continue;
      }
      final bulletMatch = bulletReg.firstMatch(line);
      if (bulletMatch != null) {
        tasks.add(bulletMatch.group(1)!.trim());
        continue;
      }
      if (line.length > 20 && !line.toLowerCase().contains('team:')) {
        tasks.add(line);
      }
    }

    // Group tasks into blocks by equipment mentions
    final List<EquipmentWorkBlock> blocks = [];
    final Map<String, List<String>> equipMap = {};

    for (final task in tasks) {
      String equip = 'Plant Maintenance';
      for (final e in availableEquipments) {
        if (task.toUpperCase().contains(e.name.toUpperCase()) || task.toUpperCase().contains(e.id.toUpperCase())) {
          equip = e.name;
          break;
        }
      }
      if (equip == 'Plant Maintenance') {
        // Check keywords
        final keywords = ['BF1', 'BF2', 'GCS', 'MCD', 'CB5', 'CB4', 'HMC', 'SGC', 'MAN COOLER', 'CANTEEN', 'ADMIN', 'PANEL ROOM', 'TRANSFORMER', 'DG'];
        for (final k in keywords) {
          if (task.toUpperCase().contains(k)) {
            equip = k;
            break;
          }
        }
      }
      equipMap.putIfAbsent(equip, () => []).add(task);
    }

    int blockIdx = 1;
    equipMap.forEach((equipName, equipTasks) {
      String? pending;
      for (final t in equipTasks) {
        final tl = t.toLowerCase();
        if (tl.contains('tobe') || tl.contains('to be') || tl.contains('pending') || tl.contains('tmro') || tl.contains('observation')) {
          pending = t;
          break;
        }
      }

      blocks.add(
        EquipmentWorkBlock(
          id: blockIdx.toString(),
          equipmentName: equipName,
          tasks: equipTasks,
          pendingFollowUp: pending,
          status: pending != null ? 'pending' : 'completed',
        ),
      );
      blockIdx++;
    });

    if (blocks.isEmpty) {
      blocks.add(
        EquipmentWorkBlock(
          id: '1',
          equipmentName: 'General Work',
          tasks: tasks.isNotEmpty ? tasks : ['General Shift Work / Non-Breakdown Jobs'],
          status: 'completed',
        ),
      );
    }

    return ParsedGeneralWorkAiDraft(
      date: detectedDate ?? DateTime.now(),
      shift: 'as',
      detectedEngineers: foundEngineers,
      detectedWorkmen: foundWorkmen,
      equipmentWorks: blocks,
    );
  }
}
