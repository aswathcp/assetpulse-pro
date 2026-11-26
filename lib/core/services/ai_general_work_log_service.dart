import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'ai_fault_log_service.dart';
import 'gemini_model_service.dart';
import '../../features/log_data/data/models/general_work_log_model.dart';
import '../../features/assets/data/models/master_equipment_model.dart';

class ParsedGeneralWorkAiDraft {
  final DateTime? date;
  final String shift;
  final String? location;
  final List<String> detectedEngineers;
  final List<String> detectedWorkmen;
  final List<EquipmentWorkBlock> equipmentWorks;
  final String? usedModel;

  ParsedGeneralWorkAiDraft({
    this.date,
    this.shift = 'as',
    this.location,
    this.detectedEngineers = const [],
    this.detectedWorkmen = const [],
    this.equipmentWorks = const [],
    this.usedModel,
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
    final models = await GeminiModelService().getCandidateModelIds(apiKey);

    final equipmentCatalog = availableEquipments
        .take(150)
        .map((e) => '{"id": "${e.id}", "name": "${e.name}", "type": "${e.type}"}')
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

              final rawEqName = w['equipmentName']?.toString() ?? 'Equipment ${i + 1}';
              final matchedEq = AiFaultLogService.matchBestEquipment(
                '$rawEqName ${tasks.join(' ')}'.toLowerCase(),
                availableEquipments,
                preferredId: w['matchedEquipmentId']?.toString(),
              );
              final rawCat = w['category']?.toString() ?? '';
              final resolvedCat = allowedCategories.contains(rawCat)
                  ? rawCat
                  : classifyWorkCategory('$rawEqName ${tasks.join(' ')}');

              blocks.add(
                EquipmentWorkBlock(
                  id: (i + 1).toString(),
                  masterEquipmentId: matchedEq?.id ?? w['matchedEquipmentId']?.toString(),
                  equipmentName: matchedEq?.name ?? rawEqName,
                  assetName: w['subAssetName']?.toString(),
                  feederName: w['feederName']?.toString(),
                  location: w['location']?.toString(),
                  category: resolvedCat,
                  tasks: tasks,
                  pendingFollowUp: w['pendingFollowUp']?.toString(),
                  status: (w['status'] ?? 'completed').toString(),
                ),
              );
            }

            await GeminiModelService().markModelWorking(model);
            return ParsedGeneralWorkAiDraft(
              date: parsedDate,
              shift: data['shift']?.toString().toLowerCase() ?? 'as',
              location: data['location']?.toString(),
              detectedEngineers: engineers,
              detectedWorkmen: workmen,
              equipmentWorks: blocks,
              usedModel: model,
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
    final Map<String, ({MasterEquipmentModel? eq, List<String> tasks})> equipMap = {};

    for (final rawTask in tasks) {
      final task = AiFaultLogService.normalizeIndustrialText(rawTask);
      final matchedEq = AiFaultLogService.matchBestEquipment(task.toLowerCase(), availableEquipments);
      String equip = matchedEq?.name ?? 'Plant Maintenance';
      if (matchedEq == null) {
        final keywords = ['BF1', 'BF2', 'GCS', 'MCD', 'CB5', 'CB4', 'HMC', 'SGC', 'MAN COOLER', 'CANTEEN', 'ADMIN', 'PANEL ROOM', 'TRANSFORMER', 'DG'];
        for (final k in keywords) {
          if (task.toUpperCase().contains(k)) {
            equip = k;
            break;
          }
        }
      }
      final existing = equipMap[equip];
      if (existing != null) {
        existing.tasks.add(task);
      } else {
        equipMap[equip] = (eq: matchedEq, tasks: [task]);
      }
    }

    int blockIdx = 1;
    equipMap.forEach((equipName, entry) {
      final equipTasks = entry.tasks;
      String? pending;
      for (final t in equipTasks) {
        final tl = t.toLowerCase();
        if (tl.contains('tobe') || tl.contains('to be') || tl.contains('pending') || tl.contains('tmro') || tl.contains('tomorrow') || tl.contains('observation') || tl.contains('follow')) {
          pending = t;
          break;
        }
      }
      final combinedText = '$equipName ${equipTasks.join(' ')}';

      blocks.add(
        EquipmentWorkBlock(
          id: blockIdx.toString(),
          masterEquipmentId: entry.eq?.id,
          equipmentName: equipName,
          assetName: _detectSubAssetLabel(combinedText),
          category: classifyWorkCategory(combinedText),
          tasks: equipTasks,
          pendingFollowUp: pending,
          status: pending != null ? 'pending' : 'completed',
        ),
      );
      blockIdx++;
    });

    if (blocks.isEmpty) {
      final normalizedRaw = AiFaultLogService.normalizeIndustrialText(rawText);
      blocks.add(
        EquipmentWorkBlock(
          id: '1',
          equipmentName: 'General Work',
          category: classifyWorkCategory(normalizedRaw),
          tasks: tasks.isNotEmpty ? tasks : ['General Shift Work / Non-Breakdown Jobs'],
          status: 'completed',
        ),
      );
    }

    String detectedShift = 'as';
    if (lower.contains('b shift') || lower.contains('shift b') || lower.contains('shift-b')) {
      detectedShift = 'bs';
    } else if (lower.contains('c shift') || lower.contains('shift c') || lower.contains('shift-c')) {
      detectedShift = 'cs';
    } else if (lower.contains('g shift') || lower.contains('general shift')) {
      detectedShift = 'gs';
    }

    return ParsedGeneralWorkAiDraft(
      date: detectedDate ?? DateTime.now(),
      shift: detectedShift,
      detectedEngineers: foundEngineers,
      detectedWorkmen: foundWorkmen,
      equipmentWorks: blocks,
    );
  }

  static const List<String> allowedCategories = [
    'Motors & Drives',
    'Cabling & Power Distribution',
    'Lighting & Illumination',
    'Cranes & Material Handling',
    'Preventive Maintenance (PM)',
    'Instrumentation & Automation',
    'Plant Facilities & Utilities',
    'General Maintenance',
  ];

  /// Classifies freeform maintenance text into one of the standard 8 work categories.
  static String classifyWorkCategory(String text) {
    final l = text.toLowerCase();
    if (l.contains('motor') || l.contains('vfd') || l.contains('drive') || l.contains('starter') || l.contains('dol') || l.contains('contactor')) {
      return 'Motors & Drives';
    }
    if (l.contains('cable') || l.contains('feeder') || l.contains('breaker') || l.contains('mcc') || l.contains('pcc') || l.contains('switchgear') || l.contains('transformer') || l.contains('termination') || l.contains('megger') || l.contains('ir ')) {
      return 'Cabling & Power Distribution';
    }
    if (l.contains('light') || l.contains('lamp') || l.contains('lux') || l.contains('flood') || l.contains('high mast') || l.contains('illumination')) {
      return 'Lighting & Illumination';
    }
    if (l.contains('crane') || l.contains('hoist') || l.contains('eot') || l.contains('conveyor') || l.contains('dsl') || l.contains('festoon') || l.contains('brake')) {
      return 'Cranes & Material Handling';
    }
    if (l.contains('pm') || l.contains('preventive') || l.contains('inspection') || l.contains('checklist') || l.contains('cleaning') || l.contains('greasing') || l.contains('tightening')) {
      return 'Preventive Maintenance (PM)';
    }
    if (l.contains('plc') || l.contains('scada') || l.contains('sensor') || l.contains('transmitter') || l.contains('limit switch') || l.contains('rtd') || l.contains('thermocouple') || l.contains('interlock') || l.contains('instrumentation')) {
      return 'Instrumentation & Automation';
    }
    if (l.contains('ac ') || l.contains('air conditioner') || l.contains('fan') || l.contains('cooler') || l.contains('canteen') || l.contains('admin') || l.contains('water') || l.contains('utility')) {
      return 'Plant Facilities & Utilities';
    }
    return 'General Maintenance';
  }

  static String? _detectSubAssetLabel(String text) {
    final l = text.toLowerCase();
    if (l.contains('motor')) return 'Motor';
    if (l.contains('pump')) return 'Pump';
    if (l.contains('gearbox')) return 'Gearbox';
    if (l.contains('brake')) return 'Brake';
    if (l.contains('actuator')) return 'Actuator';
    if (l.contains('vfd') || l.contains('drive')) return 'VFD / Drive';
    if (l.contains('breaker') || l.contains('vcb') || l.contains('acb')) return 'Breaker';
    if (l.contains('cable')) return 'Cable';
    return null;
  }
}
