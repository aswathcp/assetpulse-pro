import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/assets/data/models/fault_log_model.dart';
import '../../features/assets/data/models/master_equipment_model.dart';
import '../../features/assets/data/models/asset_model.dart';
import '../constants/odc_catalog_data.dart';
import 'gemini_model_service.dart';

class ParsedFaultLogDraft {
  final String? equipmentId;
  final String? equipmentName;
  final String? subAssetId;
  final String? subAssetName;
  final FaultCategory category;
  final FaultPriority priority;
  final WorkShift shift;
  final String problemDescription;
  final String actionTaken;
  final String? faultTypeId;
  final String? faultTypeName;
  final String? odcId;
  final String? odcObject;
  final String? odcDamage;
  final String? odcCause;
  final List<String> odcDamages;
  final List<String> odcCauses;
  final bool isOdcApplicable;
  final bool isOdcClosed;
  final FaultStatus status;
  final int? downtimeMinutes;
  final String aiSummary;
  final String? usedModel;

  ParsedFaultLogDraft({
    this.equipmentId,
    this.equipmentName,
    this.subAssetId,
    this.subAssetName,
    this.category = FaultCategory.electrical,
    this.priority = FaultPriority.medium,
    this.shift = WorkShift.as,
    required this.problemDescription,
    required this.actionTaken,
    this.faultTypeId,
    this.faultTypeName,
    this.odcId,
    this.odcObject,
    this.odcDamage,
    this.odcCause,
    this.odcDamages = const [],
    this.odcCauses = const [],
    this.isOdcApplicable = false,
    this.isOdcClosed = false,
    this.status = FaultStatus.pending,
    this.downtimeMinutes,
    required this.aiSummary,
    this.usedModel,
  });
}

class AiFaultLogService {
  static final AiFaultLogService _instance = AiFaultLogService._internal();
  factory AiFaultLogService() => _instance;
  AiFaultLogService._internal();

  static const String _prefApiKey = 'gemini_ai_api_key';
  static const String _prefUseDeveloperKey = 'use_developer_gemini_key';

  /// Developer fallback key — allows users to try AI without their own key.
  /// This is rate-limited and shared. Users with heavy usage should get their own
  /// free key from aistudio.google.com
  static const String _developerKey = 'AQ.Ab8RN6KPy5flcaO9nkfRox18rgZ54u4iIre_48_vmA-it_AG1A';

  String? _customApiKey;

  Future<String?> getApiKey() async {
    // 1. In-memory custom key (user's own)
    if (_customApiKey != null && _customApiKey!.isNotEmpty) {
      return _customApiKey;
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefApiKey);
    if (saved != null && saved.isNotEmpty) {
      _customApiKey = saved;
      return _customApiKey;
    }
    // 2. Developer key fallback — shared, rate-limited
    final useDev = prefs.getBool(_prefUseDeveloperKey) ?? true; // on by default
    if (useDev) return _developerKey;
    return null;
  }

  Future<bool> isUsingDeveloperKey() async {
    final prefs = await SharedPreferences.getInstance();
    final userKey = prefs.getString(_prefApiKey) ?? '';
    return userKey.isEmpty;
  }

  Future<bool> getDeveloperKeyEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefUseDeveloperKey) ?? true;
  }

  Future<void> setDeveloperKeyEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefUseDeveloperKey, enabled);
  }

  Future<void> saveApiKey(String key) async {
    _customApiKey = key.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefApiKey, _customApiKey!);
  }


  /// Industrial Terminology Normalizer & Spell Checker
  /// Corrects frequent voice transcription errors and hasty typing
  static String normalizeIndustrialText(String input) {
    if (input.trim().isEmpty) return input;
    String text = ' $input ';

    final Map<String, String> replacements = {
      r'\bmotr\b': 'motor',
      r'\bmotrs\b': 'motors',
      r'\bcircuittted\b': 'circuited',
      r'\bshortcircuittted\b': 'short circuited',
      r'\bshortcircuit\b': 'short circuit',
      r'\bearthfault\b': 'earth fault',
      r'\berth fault\b': 'earth fault',
      r'\berth\b': 'earth',
      r'\bisolaton\b': 'isolation',
      r'\bisloation\b': 'isolation',
      r'\btermintion\b': 'termination',
      r'\bterminashon\b': 'termination',
      r'\btermnation\b': 'termination',
      r'\bvibrashon\b': 'vibration',
      r'\bvibraiton\b': 'vibration',
      r'\bvib\b': 'vibration',
      r'\btransmiter\b': 'transmitter',
      r'\bpressur\b': 'pressure',
      r'\bpresure\b': 'pressure',
      r'\btemprature\b': 'temperature',
      r'\btempature\b': 'temperature',
      r'\bbeering\b': 'bearing',
      r'\bbaring\b': 'bearing',
      r'\bbeerings\b': 'bearings',
      r'\bgeerbox\b': 'gearbox',
      r'\bgerbox\b': 'gearbox',
      r'\bbraker\b': 'breaker',
      r'\bbrakers\b': 'breakers',
      r'\bcontecter\b': 'contactor',
      r'\bcontactr\b': 'contactor',
      r'\btriped\b': 'tripped',
      r'\btrippd\b': 'tripped',
      r'\breplased\b': 'replaced',
      r'\breplacedd\b': 'replaced',
      r'\brepaird\b': 'repaired',
      r'\boverlode\b': 'overload',
      r'\bovld\b': 'overload',
      r'\bleakege\b': 'leakage',
      r'\binturrupt\b': 'interrupt',
      r'\bstater\b': 'stator',
      r'\brotar\b': 'rotor',
    };

    replacements.forEach((pattern, replacement) {
      text = text.replaceAll(RegExp(pattern, caseSensitive: false), replacement);
    });

    return text.trim();
  }

  /// Parse technician voice transcript or typed text into structured maintenance fields
  Future<ParsedFaultLogDraft> parseMaintenanceLog({
    required String rawPrompt,
    required List<MasterEquipmentModel> availableEquipments,
    required List<AssetModel> availableSubAssets,
    required List<Map<String, dynamic>> availableFaultTypes,
    required List<Map<String, dynamic>> availableOdcCauses,
  }) async {
    final cleanPrompt = rawPrompt.trim();
    if (cleanPrompt.isEmpty) {
      throw Exception('Please provide a fault description or voice dictation.');
    }

    final apiKey = await getApiKey();

    // 1. Try Google Gemini Generative AI if API key is provided
    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final cloudDraft = await _callGeminiApi(
          rawPrompt: cleanPrompt,
          apiKey: apiKey,
          availableEquipments: availableEquipments,
          availableSubAssets: availableSubAssets,
          availableFaultTypes: availableFaultTypes,
          availableOdcCauses: availableOdcCauses,
        );
        if (cloudDraft != null) {
          return cloudDraft;
        }
      } catch (e) {
        debugPrint('Gemini Cloud AI parse error: $e');
      }
    }

    // 2. High-performance offline NLP Heuristic & Spell-Correction Engine
    return _parseWithLocalNlp(
      rawPrompt: cleanPrompt,
      availableEquipments: availableEquipments,
      availableSubAssets: availableSubAssets,
      availableFaultTypes: availableFaultTypes,
      availableOdcCauses: availableOdcCauses,
    );
  }

  /// Cloud Gemini parser using auto-discovered best free-tier model & `package:http`
  Future<ParsedFaultLogDraft?> _callGeminiApi({
    required String rawPrompt,
    required String apiKey,
    required List<MasterEquipmentModel> availableEquipments,
    required List<AssetModel> availableSubAssets,
    required List<Map<String, dynamic>> availableFaultTypes,
    required List<Map<String, dynamic>> availableOdcCauses,
  }) async {
    final models = await GeminiModelService().getCandidateModelIds(apiKey);

    final equipmentCatalog = availableEquipments
        .take(150)
        .map((e) => '{"id": "${e.id}", "name": "${e.name}", "type": "${e.type}"}')
        .join(',\n');

    final subAssetCatalog = availableSubAssets
        .take(60)
        .map((a) => '{"id": "${a.id}", "tagNo": "${a.tagNo}", "type": "${a.type.name}"}')
        .join(',\n');

    final faultTypeCatalog = availableFaultTypes
        .take(80)
        .map((f) => '{"id": "${f['id']}", "name": "${f['name'] ?? f['faultTypeName'] ?? f['id']}", "category": "${f['category'] ?? f['discipline'] ?? ''}"}')
        .join(',\n');

    final odcCatalog = availableOdcCauses.isNotEmpty
        ? availableOdcCauses.take(100).map((o) {
            final obj = o['objectPart'] ?? o['Object_Part'] ?? o['object'] ?? '';
            final dmg = o['damage'] ?? o['Damage_Mode'] ?? o['damageMode'] ?? '';
            final cau = o['cause'] ?? o['Root_Cause'] ?? o['rootCause'] ?? o['name'] ?? '';
            final disc = o['discipline'] ?? o['category'] ?? '';
            return '{"object": "$obj", "damage": "$dmg", "cause": "$cau", "discipline": "$disc"}';
          }).join(',\n')
        : OdcCatalogData.allCatalog
            .take(60)
            .map((o) => '{"object": "${o.objectName}", "damage": "${o.damageName}", "cause": "${o.causeName}"}')
            .join(',\n');

    final systemInstruction = """
You are an expert Industrial Reliability & Plant Maintenance AI for an industrial facility.
A technician dictation/observation is provided below. It may contain typos, misspellings, or phonetic voice-to-text errors (e.g. "motr" for motor, "circuittted" for circuited, "earthfault" for earth fault).

TECHNICIAN OBSERVATION:
\"\"\"
$rawPrompt
\"\"\"

ACTIVE EQUIPMENT DATABASE:
[$equipmentCatalog]

SUB-ASSETS FOR SELECTED EQUIPMENT:
[$subAssetCatalog]

FAULT TYPES CATALOG:
[$faultTypeCatalog]

ODC ISO 14224 CATALOG (Object, Damage, Cause):
[$odcCatalog]

CRITICAL RULES:
1. SPELLING & GRAMMAR: Fix all typos and phonetic errors. Produce polished, professional engineering English.
2. "problemDescription": Concise, professional engineering statement of the failure/symptom.
3. "actionTaken": Clear summary of remedial action taken.
4. "status": strictly one of ["pending", "closed"]. If trial was taken and found OK / normal / restored, or repair complete, status MUST be "closed". Otherwise "pending".
5. "category": strictly one of ["electrical", "mechanical", "instrumentation", "operational"].
6. "priority": strictly one of ["critical", "high", "medium", "low"].
7. "shift": strictly one of ["as", "bs", "cs", "gs"] (Default "as").
8. "matchedEquipmentId": EXACT "id" from ACTIVE EQUIPMENT DATABASE if matched, otherwise null.
9. "matchedSubAssetId": EXACT "id" from SUB-ASSETS if matched, otherwise null.
10. "matchedFaultTypeId": EXACT "id" from FAULT TYPES CATALOG if matched, otherwise null.
11. "odcObject", "odcDamages", "odcCauses": MUST prefer EXACT strings from ODC ISO 14224 CATALOG when available.
12. "isOdcApplicable": true if root defect identified.
13. "isOdcClosed": true if action resolved the defect.
14. "aiSummary": 1-line bullet summary of findings.

OUTPUT MUST BE VALID JSON ONLY:
{
  "matchedEquipmentId": "ID or null",
  "matchedSubAssetId": "ID or null",
  "category": "electrical | mechanical | instrumentation | operational",
  "priority": "critical | high | medium | low",
  "shift": "as | bs | cs | gs",
  "problemDescription": "...",
  "actionTaken": "...",
  "matchedFaultTypeId": "ID or null",
  "odcObject": "Component or null",
  "odcDamage": "Primary damage mode or null",
  "odcCause": "Primary root cause or null",
  "odcDamages": ["Damage 1"],
  "odcCauses": ["Cause 1"],
  "isOdcApplicable": true,
  "isOdcClosed": true,
  "status": "pending | closed",
  "downtimeMinutes": 30,
  "aiSummary": "..."
}
""";

    for (final model in models) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
        );

        final payload = {
          'contents': [
            {
              'parts': [
                {'text': systemInstruction}
              ]
            }
          ],
          'generationConfig': {
            'responseMimeType': 'application/json',
            'temperature': 0.1,
          }
        };

        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
          if (text != null) {
            final cleanJson = text.toString().replaceAll('```json', '').replaceAll('```', '').trim();
            final parsed = jsonDecode(cleanJson) as Map<String, dynamic>;
            await GeminiModelService().markModelWorking(model);
            return _buildDraftFromMap(
              rawPrompt: rawPrompt,
              map: parsed,
              availableEquipments: availableEquipments,
              availableSubAssets: availableSubAssets,
              availableFaultTypes: availableFaultTypes,
              availableOdcCauses: availableOdcCauses,
              usedModel: model,
            );
          }
        } else {
          debugPrint('Gemini Model $model HTTP ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        debugPrint('Gemini Model $model Exception: $e');
      }
    }
    return null;
  }

  /// High-Speed Offline NLP & Terminology Corrector Engine
  ParsedFaultLogDraft _parseWithLocalNlp({
    required String rawPrompt,
    required List<MasterEquipmentModel> availableEquipments,
    required List<AssetModel> availableSubAssets,
    required List<Map<String, dynamic>> availableFaultTypes,
    required List<Map<String, dynamic>> availableOdcCauses,
  }) {
    // 1. Spell Check & Normalization
    final normalized = normalizeIndustrialText(rawPrompt);
    final lower = normalized.toLowerCase();

    // 2. Identify Shift
    WorkShift shift = WorkShift.as;
    if (lower.contains('shift b') || lower.contains(' b shift') || lower.contains('shift-b') || lower.contains('bs')) {
      shift = WorkShift.bs;
    } else if (lower.contains('shift c') || lower.contains(' c shift') || lower.contains('shift-c') || lower.contains('cs')) {
      shift = WorkShift.cs;
    } else if (lower.contains('general shift') || lower.contains(' gs ') || lower.contains('g shift')) {
      shift = WorkShift.gs;
    }

    // 3. Identify Category
    FaultCategory category = FaultCategory.electrical;
    final elecKeywords = [
      'motor', 'winding', 'breaker', 'trip', 'tripped', 'vcb', 'acb', 'mccb', 'cable', 'flash',
      'spark', 'fuse', 'contactor', 'relay', 'earth fault', 'earthfault', 'overload', 'short circuit',
      'short circuited', 'transformer', 'switchgear', '415v', '11kv', '3.3kv', 'lt', 'ht', 'power', 'coil', 'voltage'
    ];
    final instKeywords = [
      'sensor', 'transmitter', 'plc', 'scada', 'rtd', 'thermocouple', 'pressure switch',
      '4-20ma', 'interlock', 'limit switch', 'solenoid', 'encoder'
    ];
    final mechKeywords = [
      'bearing', 'vibration', 'rattling', 'gearbox', 'leak', 'seal', 'pump', 'belt',
      'conveyor', 'coupling', 'roller', 'pulley', 'chute', 'jam', 'wear', 'grease', 'lubrication', 'noise'
    ];

    int elecScore = elecKeywords.where((k) => lower.contains(k)).length;
    int instScore = instKeywords.where((k) => lower.contains(k)).length;
    int mechScore = mechKeywords.where((k) => lower.contains(k)).length;

    if (instScore > elecScore && instScore > mechScore) {
      category = FaultCategory.instrumentation;
    } else if (elecScore >= mechScore && elecScore > 0) {
      category = FaultCategory.electrical;
    } else {
      category = FaultCategory.mechanical;
    }

    // 4. Identify Priority
    FaultPriority priority = FaultPriority.medium;
    if (lower.contains('emergency') || lower.contains('critical') || lower.contains('blackout') || lower.contains('fire') || lower.contains('breakdown') || lower.contains('short circuit')) {
      priority = FaultPriority.critical;
    } else if (lower.contains('trip') || lower.contains('tripped') || lower.contains('earth fault') || lower.contains('high temp') || lower.contains('heavy') || lower.contains('urgent')) {
      priority = FaultPriority.high;
    } else if (lower.contains('minor') || lower.contains('routine') || lower.contains('preventive') || lower.contains('slight')) {
      priority = FaultPriority.low;
    }

    // 5. Identify Status
    FaultStatus status = FaultStatus.pending;
    if (lower.contains('trial taken and found ok') ||
        lower.contains('trial taken ok') ||
        lower.contains('found ok') ||
        lower.contains('running normal') ||
        lower.contains('running fine') ||
        lower.contains('rectified') ||
        lower.contains('resolved') ||
        lower.contains('closed') ||
        lower.contains('restored') ||
        lower.contains('replaced termination done and trial taken and found ok')) {
      status = FaultStatus.closed;
    } else {
      status = FaultStatus.pending;
    }

    // 6. Downtime Calculation
    int? downtime;
    final dtRegex = RegExp(r'(\d+)\s*(?:min|mins|minute|minutes|m\b)');
    final hrRegex = RegExp(r'(\d+(?:\.\d+)?)\s*(?:hr|hrs|hour|hours|h\b)');

    final dtMatch = dtRegex.firstMatch(lower);
    if (dtMatch != null) {
      downtime = int.tryParse(dtMatch.group(1) ?? '');
    } else {
      final hrMatch = hrRegex.firstMatch(lower);
      if (hrMatch != null) {
        final hours = double.tryParse(hrMatch.group(1) ?? '') ?? 0;
        downtime = (hours * 60).round();
      }
    }

    // 7. Equipment Matching
    final matchedEq = matchBestEquipment(lower, availableEquipments);

    // 8. Sub-Asset Matching
    final matchedAsset = matchBestSubAsset(lower, availableSubAssets);

    // 9. Fault Type Matching (preferring matching category)
    final matchedFt = matchBestFaultType(lower, availableFaultTypes, category);

    // 10. Tri-axial ODC (snapped to live Firestore availableOdcCauses when present)
    final odcMatch = matchBestOdc(
      lower,
      availableOdcCauses,
      category,
      preferredObject: (lower.contains('motor') && (lower.contains('earth fault') || lower.contains('short circuit') || lower.contains('winding')))
          ? 'Stator Winding'
          : null,
      preferredDamages: (lower.contains('motor') && (lower.contains('earth fault') || lower.contains('short circuit') || lower.contains('winding')))
          ? ['Insulation Breakdown', 'Earth Fault']
          : const [],
      preferredCauses: (lower.contains('motor') && (lower.contains('earth fault') || lower.contains('short circuit') || lower.contains('winding')))
          ? ['Short Circuit', 'Moisture', 'Insulation Degradation']
          : const [],
    );
    final matchedOdcObject = odcMatch.objectPart;
    final matchedOdcDamage = odcMatch.damages.isNotEmpty ? odcMatch.damages.first : null;
    final matchedOdcCause = odcMatch.causes.isNotEmpty ? odcMatch.causes.first : null;
    final List<String> matchedOdcDamages = odcMatch.damages;
    final List<String> matchedOdcCauses = odcMatch.causes;

    // 11. Intelligent Problem vs Action Separation
    String problemDesc = normalized;
    String actionTaken = 'Inspected and verified on site.';

    final actionSeparators = [
      'self isolation taken',
      'isolation taken',
      'permit taken',
      'rectified by',
      'action taken:',
      'action:',
      'repaired by',
      'motor replaced',
      'replaced',
      'termination done',
      'trial taken',
      'tightened',
      'greased',
      'cleaned and tested',
      'cleaned',
      'adjusted',
      'retorqued',
      'attended by'
    ];

    for (final sep in actionSeparators) {
      final idx = lower.indexOf(sep);
      if (idx != -1) {
        problemDesc = normalized.substring(0, idx).trim();
        actionTaken = normalized.substring(idx).trim();
        if (actionTaken.isNotEmpty) {
          actionTaken = actionTaken[0].toUpperCase() + actionTaken.substring(1);
        }
        break;
      }
    }

    if (problemDesc.endsWith(',') || problemDesc.endsWith('.')) {
      problemDesc = problemDesc.substring(0, problemDesc.length - 1).trim();
    }
    if (problemDesc.isNotEmpty) {
      problemDesc = problemDesc[0].toUpperCase() + problemDesc.substring(1);
    }

    // Polish Problem Description & Action
    if (problemDesc.contains('IR shows')) {
      problemDesc = problemDesc.replaceAll('IR shows', 'Insulation Resistance (IR) test shows');
    }
    if (actionTaken.contains('termination done and trial taken and found OK')) {
      actionTaken = actionTaken.replaceAll('termination done and trial taken and found OK', 'cable termination completed, trial taken and found OK.');
    }

    // Build summary
    final eqSummary = matchedEq != null ? matchedEq.name : (lower.contains('motor') ? 'Electric Motor' : 'Target Equipment');
    final actionSummary = actionTaken.length > 30 ? '${actionTaken.substring(0, 30)}...' : actionTaken;
    final aiSummary = '$eqSummary • ${category.name.toUpperCase()} • ${priority.name.toUpperCase()} • $actionSummary';

    return ParsedFaultLogDraft(
      equipmentId: matchedEq?.id,
      equipmentName: matchedEq?.name,
      subAssetId: matchedAsset?.id,
      subAssetName: matchedAsset?.tagNo,
      category: category,
      priority: priority,
      shift: shift,
      problemDescription: problemDesc,
      actionTaken: actionTaken,
      faultTypeId: matchedFt?['id'],
      faultTypeName: matchedFt?['name'] ?? matchedFt?['faultTypeName'],
      odcObject: matchedOdcObject,
      odcDamage: matchedOdcDamage,
      odcCause: matchedOdcCause,
      odcDamages: matchedOdcDamages,
      odcCauses: matchedOdcCauses,
      isOdcApplicable: matchedOdcObject != null || matchedOdcCause != null,
      isOdcClosed: status == FaultStatus.closed,
      status: status,
      downtimeMinutes: downtime,
      aiSummary: aiSummary,
    );
  }

  ParsedFaultLogDraft _buildDraftFromMap({
    required String rawPrompt,
    required Map<String, dynamic> map,
    required List<MasterEquipmentModel> availableEquipments,
    required List<AssetModel> availableSubAssets,
    required List<Map<String, dynamic>> availableFaultTypes,
    required List<Map<String, dynamic>> availableOdcCauses,
    String? usedModel,
  }) {
    final normalizedLower = normalizeIndustrialText(rawPrompt).toLowerCase();

    final matchedEq = matchBestEquipment(
      normalizedLower,
      availableEquipments,
      preferredId: map['matchedEquipmentId']?.toString(),
    );

    final matchedAsset = matchBestSubAsset(
      normalizedLower,
      availableSubAssets,
      preferredId: map['matchedSubAssetId']?.toString(),
    );

    final catStr = (map['category'] ?? 'electrical').toString().toLowerCase();
    final cat = FaultCategory.values.firstWhere(
      (c) => c.name == catStr,
      orElse: () => FaultCategory.electrical,
    );

    final prioStr = (map['priority'] ?? 'medium').toString().toLowerCase();
    final prio = FaultPriority.values.firstWhere(
      (p) => p.name == prioStr,
      orElse: () => FaultPriority.medium,
    );

    final shiftStr = (map['shift'] ?? 'as').toString().toLowerCase();
    final shift = WorkShift.values.firstWhere(
      (s) => s.name == shiftStr,
      orElse: () => WorkShift.as,
    );

    final statusStr = (map['status'] ?? 'pending').toString().toLowerCase();
    final status = statusStr.contains('close') || statusStr.contains('resolv')
        ? FaultStatus.closed
        : FaultStatus.pending;

    final matchedFt = matchBestFaultType(
      normalizedLower,
      availableFaultTypes,
      cat,
      preferredId: map['matchedFaultTypeId']?.toString(),
    );

    final odcObj = map['odcObject']?.toString();
    final odcDam = map['odcDamage']?.toString();
    final odcCas = map['odcCause']?.toString();
    final rawDamages = map['odcDamages'] != null ? List<String>.from(map['odcDamages']) : <String>[];
    final rawCauses = map['odcCauses'] != null ? List<String>.from(map['odcCauses']) : <String>[];
    if (rawDamages.isEmpty && odcDam != null && odcDam.isNotEmpty) rawDamages.add(odcDam);
    if (rawCauses.isEmpty && odcCas != null && odcCas.isNotEmpty) rawCauses.add(odcCas);

    final snappedOdc = matchBestOdc(
      normalizedLower,
      availableOdcCauses,
      cat,
      preferredObject: odcObj,
      preferredDamages: rawDamages,
      preferredCauses: rawCauses,
    );

    final finalDamages = snappedOdc.damages.isNotEmpty ? snappedOdc.damages : rawDamages;
    final finalCauses = snappedOdc.causes.isNotEmpty ? snappedOdc.causes : rawCauses;
    final finalObj = snappedOdc.objectPart ?? odcObj;

    return ParsedFaultLogDraft(
      equipmentId: matchedEq?.id,
      equipmentName: matchedEq?.name,
      subAssetId: matchedAsset?.id,
      subAssetName: matchedAsset?.tagNo,
      category: cat,
      priority: prio,
      shift: shift,
      problemDescription: map['problemDescription']?.toString() ?? '',
      actionTaken: map['actionTaken']?.toString() ?? '',
      faultTypeId: matchedFt?['id']?.toString(),
      faultTypeName: (matchedFt?['name'] ?? matchedFt?['faultTypeName'])?.toString(),
      odcObject: finalObj,
      odcDamage: finalDamages.isNotEmpty ? finalDamages.first : odcDam,
      odcCause: finalCauses.isNotEmpty ? finalCauses.first : odcCas,
      odcDamages: finalDamages,
      odcCauses: finalCauses,
      isOdcApplicable: map['isOdcApplicable'] == true || finalObj != null || finalCauses.isNotEmpty || finalDamages.isNotEmpty,
      isOdcClosed: map['isOdcClosed'] == true || status == FaultStatus.closed,
      status: status,
      downtimeMinutes: (map['downtimeMinutes'] as num?)?.toInt(),
      aiSummary: map['aiSummary']?.toString() ?? 'Auto-classified by AI Assistant',
      usedModel: usedModel,
    );
  }

  static bool _matchesCategory(String rawCat, FaultCategory target) {
    final cat = rawCat.toLowerCase().trim();
    if (cat.isEmpty || cat == 'all' || cat == 'generic') return true;
    final cur = target.name.toLowerCase();
    if (cat == cur) return true;
    if (cur == 'instrumentation' && (cat == 'automation' || cat == 'inst')) return true;
    return false;
  }

  static int _tokenOverlapScore(String textLower, String candidate) {
    final tokens = candidate.toLowerCase().split(RegExp(r'[\s\-_/().,]+'));
    int score = 0;
    for (final t in tokens) {
      if (t.length >= 3 && textLower.contains(t)) {
        score += (t.length >= 5 ? 3 : 1);
      }
    }
    return score;
  }

  static MasterEquipmentModel? matchBestEquipment(
    String textLower,
    List<MasterEquipmentModel> equipments, {
    String? preferredId,
  }) {
    if (preferredId != null && preferredId.isNotEmpty && preferredId != 'null') {
      final pLow = preferredId.toLowerCase();
      for (final e in equipments) {
        if (e.id == preferredId || e.id.toLowerCase() == pLow || e.name.toLowerCase() == pLow) {
          return e;
        }
      }
      for (final e in equipments) {
        if (e.name.toLowerCase().contains(pLow) || pLow.contains(e.name.toLowerCase())) {
          return e;
        }
      }
    }
    MasterEquipmentModel? best;
    int bestScore = 0;
    for (final eq in equipments) {
      final score = _tokenOverlapScore(textLower, '${eq.name} ${eq.id}');
      if (score > bestScore) {
        bestScore = score;
        best = eq;
      }
    }
    return best;
  }

  static AssetModel? matchBestSubAsset(
    String textLower,
    List<AssetModel> subAssets, {
    String? preferredId,
  }) {
    if (subAssets.isEmpty) return null;
    if (preferredId != null && preferredId.isNotEmpty && preferredId != 'null') {
      final pLow = preferredId.toLowerCase();
      for (final a in subAssets) {
        if (a.id == preferredId || a.id.toLowerCase() == pLow || a.tagNo.toLowerCase() == pLow) {
          return a;
        }
      }
    }
    AssetModel? best;
    int bestScore = 0;
    for (final ast in subAssets) {
      int score = 0;
      final tag = ast.tagNo.toLowerCase();
      final name = ast.name.toLowerCase();
      final type = ast.type.name.toLowerCase();
      if (tag.isNotEmpty && textLower.contains(tag)) score += 6;
      if (name.isNotEmpty) score += _tokenOverlapScore(textLower, name);
      if (textLower.contains(type)) score += 3;
      if (score > bestScore) {
        bestScore = score;
        best = ast;
      }
    }
    return best;
  }

  static Map<String, dynamic>? matchBestFaultType(
    String textLower,
    List<Map<String, dynamic>> faultTypes,
    FaultCategory category, {
    String? preferredId,
  }) {
    if (faultTypes.isEmpty) return null;
    final filtered = faultTypes.where((f) {
      final c = (f['category'] ?? f['discipline'] ?? '').toString();
      return _matchesCategory(c, category);
    }).toList();
    final pool = filtered.isNotEmpty ? filtered : faultTypes;

    if (preferredId != null && preferredId.isNotEmpty && preferredId != 'null') {
      final pLow = preferredId.toLowerCase();
      for (final f in pool) {
        final id = (f['id'] ?? '').toString();
        final name = (f['name'] ?? f['faultTypeName'] ?? '').toString().toLowerCase();
        if (id == preferredId || id.toLowerCase() == pLow || name == pLow) {
          return f;
        }
      }
    }

    Map<String, dynamic>? best;
    int bestScore = 0;
    for (final f in pool) {
      final name = (f['name'] ?? f['faultTypeName'] ?? f['id'] ?? '').toString();
      final score = _tokenOverlapScore(textLower, name);
      if (score > bestScore) {
        bestScore = score;
        best = f;
      }
    }
    return best;
  }

  static ({String? objectPart, List<String> damages, List<String> causes}) matchBestOdc(
    String textLower,
    List<Map<String, dynamic>> availableOdcCauses,
    FaultCategory category, {
    String? preferredObject,
    List<String> preferredDamages = const [],
    List<String> preferredCauses = const [],
  }) {
    if (availableOdcCauses.isNotEmpty) {
      final filtered = availableOdcCauses.where((o) {
        final c = (o['discipline'] ?? o['category'] ?? '').toString();
        return _matchesCategory(c, category);
      }).toList();
      final pool = filtered.isNotEmpty ? filtered : availableOdcCauses;

      final searchText = [
        textLower,
        if (preferredObject != null) preferredObject.toLowerCase(),
        ...preferredDamages.map((e) => e.toLowerCase()),
        ...preferredCauses.map((e) => e.toLowerCase()),
      ].join(' ');

      String? bestObj;
      int bestObjScore = 0;
      for (final item in pool) {
        final obj = (item['objectPart'] ?? item['Object_Part'] ?? item['object'])?.toString().trim();
        if (obj == null || obj.isEmpty) continue;
        int score = _tokenOverlapScore(searchText, obj);
        if (preferredObject != null && obj.toLowerCase() == preferredObject.toLowerCase()) {
          score += 10;
        }
        if (score > bestObjScore) {
          bestObjScore = score;
          bestObj = obj;
        }
      }

      final objPool = bestObj != null
          ? pool.where((o) => (o['objectPart'] ?? o['Object_Part'] ?? o['object'])?.toString().trim() == bestObj).toList()
          : pool;

      String? bestDmg;
      int bestDmgScore = 0;
      for (final item in objPool) {
        final dmg = (item['damage'] ?? item['Damage_Mode'] ?? item['damageMode'])?.toString().trim();
        if (dmg == null || dmg.isEmpty) continue;
        int score = _tokenOverlapScore(searchText, dmg);
        for (final p in preferredDamages) {
          if (dmg.toLowerCase() == p.toLowerCase()) score += 10;
        }
        if (score > bestDmgScore) {
          bestDmgScore = score;
          bestDmg = dmg;
        }
      }

      final cauPool = bestDmg != null
          ? objPool.where((o) => (o['damage'] ?? o['Damage_Mode'] ?? o['damageMode'])?.toString().trim() == bestDmg).toList()
          : objPool;

      String? bestCau;
      int bestCauScore = 0;
      for (final item in cauPool) {
        final cau = (item['cause'] ?? item['Root_Cause'] ?? item['rootCause'] ?? item['name'])?.toString().trim();
        if (cau == null || cau.isEmpty) continue;
        int score = _tokenOverlapScore(searchText, cau);
        for (final p in preferredCauses) {
          if (cau.toLowerCase() == p.toLowerCase()) score += 10;
        }
        if (score > bestCauScore) {
          bestCauScore = score;
          bestCau = cau;
        }
      }

      return (
        objectPart: bestObj,
        damages: bestDmg != null ? [bestDmg] : <String>[],
        causes: bestCau != null ? [bestCau] : <String>[],
      );
    }

    // Fallback to static OdcCatalogData if Firestore ODC catalog is empty
    String? bestObj;
    String? bestDmg;
    String? bestCau;
    int bestScore = 0;
    for (final item in OdcCatalogData.allCatalog) {
      final score = _tokenOverlapScore(textLower, '${item.objectName} ${item.damageName} ${item.causeName}');
      if (score > bestScore) {
        bestScore = score;
        bestObj = item.objectName;
        bestDmg = item.damageName;
        bestCau = item.causeName;
      }
    }
    return (
      objectPart: bestObj ?? preferredObject,
      damages: bestDmg != null ? [bestDmg] : preferredDamages,
      causes: bestCau != null ? [bestCau] : preferredCauses,
    );
  }
}
