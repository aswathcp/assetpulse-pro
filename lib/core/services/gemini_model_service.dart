import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GeminiModelInfo {
  final String id;
  final String displayName;
  final String description;
  final int inputTokenLimit;
  final int outputTokenLimit;
  final int suitabilityScore;
  final String tierNote;

  const GeminiModelInfo({
    required this.id,
    required this.displayName,
    required this.description,
    required this.inputTokenLimit,
    required this.outputTokenLimit,
    required this.suitabilityScore,
    required this.tierNote,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'description': description,
        'inputTokenLimit': inputTokenLimit,
        'outputTokenLimit': outputTokenLimit,
        'suitabilityScore': suitabilityScore,
        'tierNote': tierNote,
      };

  factory GeminiModelInfo.fromJson(Map<String, dynamic> json) => GeminiModelInfo(
        id: json['id']?.toString() ?? '',
        displayName: json['displayName']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        inputTokenLimit: (json['inputTokenLimit'] as num?)?.toInt() ?? 0,
        outputTokenLimit: (json['outputTokenLimit'] as num?)?.toInt() ?? 0,
        suitabilityScore: (json['suitabilityScore'] as num?)?.toInt() ?? 0,
        tierNote: json['tierNote']?.toString() ?? '',
      );
}

/// Discovers, scores, and caches the best suitable free-tier Gemini model
/// available for the active API key via Google's `v1beta/models` endpoint.
class GeminiModelService {
  static final GeminiModelService _instance = GeminiModelService._internal();
  factory GeminiModelService() => _instance;
  GeminiModelService._internal();

  static const String _prefCachedModels = 'gemini_cached_models_v1';
  static const String _prefCachedAt = 'gemini_cached_models_ts_v1';
  static const String _prefManualModel = 'gemini_manual_model_v1';
  static const String _prefLastWorkingModel = 'gemini_last_working_model_v1';

  static const List<String> fallbackFreeModels = [
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemini-2.0-flash',
    'gemini-2.0-flash-lite',
  ];

  List<GeminiModelInfo>? _memoryModels;

  /// Scores a Gemini model ID for free-tier suitability (higher is better).
  /// Prefers stable Flash / Flash-Lite models with strong JSON support and
  /// generous free-tier RPM/RPD quotas over Pro/Experimental models.
  static GeminiModelInfo? scoreModel(Map<String, dynamic> raw) {
    final fullName = raw['name']?.toString() ?? '';
    final id = fullName.startsWith('models/') ? fullName.substring(7) : fullName;
    if (id.isEmpty) return null;

    final methods = (raw['supportedGenerationMethods'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const [];
    if (!methods.contains('generateContent')) return null;

    final lower = id.toLowerCase();
    // Exclude non-text/specialized/retired models
    const excluded = [
      'embedding',
      'aqa',
      'imagen',
      'veo',
      'tts',
      'audio',
      'robotics',
      'computer-use',
      'deep-research',
      'lyria',
      'gemma',
      'gemini-1.0',
      'gemini-1.5',
      'nano-banana',
    ];
    for (final bad in excluded) {
      if (lower.contains(bad)) return null;
    }

    int score = 100;
    String tierNote = 'Standard';

    // Extract major.minor version (e.g. 2.5, 2.0, 3.0)
    final verMatch = RegExp(r'gemini-(\d+)(?:\.(\d+))?').firstMatch(lower);
    if (verMatch != null) {
      final major = int.tryParse(verMatch.group(1) ?? '0') ?? 0;
      final minor = int.tryParse(verMatch.group(2) ?? '0') ?? 0;
      score += major * 40 + minor * 5;
    }

    // Tier suitability for free-tier structured JSON extraction
    if (lower.contains('flash-lite')) {
      score += 55;
      tierNote = 'Fastest • High Free Quota';
    } else if (lower.contains('flash')) {
      score += 70;
      tierNote = 'Best Balance • Free Tier';
    } else if (lower.contains('pro')) {
      score += 20;
      tierNote = 'High Reasoning • Lower Free Quota';
    }

    // Prefer stable GA models over preview/experimental/dated snapshots
    if (lower.contains('exp') || lower.contains('experimental')) {
      score -= 35;
      tierNote = 'Experimental • Unstable Quota';
    } else if (lower.contains('preview')) {
      score -= 15;
    }
    if (RegExp(r'-\d{3,}$').hasMatch(lower) || lower.contains('latest')) {
      score -= 5;
    }

    return GeminiModelInfo(
      id: id,
      displayName: raw['displayName']?.toString() ?? id,
      description: raw['description']?.toString() ?? '',
      inputTokenLimit: (raw['inputTokenLimit'] as num?)?.toInt() ?? 0,
      outputTokenLimit: (raw['outputTokenLimit'] as num?)?.toInt() ?? 0,
      suitabilityScore: score,
      tierNote: tierNote,
    );
  }

  /// Queries `v1beta/models` for the given API key, ranks suitable free models,
  /// and caches the result for 24 hours.
  Future<List<GeminiModelInfo>> discoverBestFreeModels(
    String apiKey, {
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (!forceRefresh) {
      if (_memoryModels != null && _memoryModels!.isNotEmpty) {
        return _memoryModels!;
      }
      final ts = prefs.getInt(_prefCachedAt) ?? 0;
      final ageMs = DateTime.now().millisecondsSinceEpoch - ts;
      final cachedRaw = prefs.getString(_prefCachedModels);
      if (cachedRaw != null && cachedRaw.isNotEmpty && ageMs < 86400000) {
        try {
          final list = (jsonDecode(cachedRaw) as List)
              .map((e) => GeminiModelInfo.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          if (list.isNotEmpty) {
            _memoryModels = list;
            return list;
          }
        } catch (_) {}
      }
    }

    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final rawModels = body['models'] as List? ?? [];
        final scored = <GeminiModelInfo>[];
        for (final m in rawModels) {
          if (m is Map<String, dynamic>) {
            final info = scoreModel(m);
            if (info != null) scored.add(info);
          }
        }
        scored.sort((a, b) => b.suitabilityScore.compareTo(a.suitabilityScore));

        if (scored.isNotEmpty) {
          _memoryModels = scored;
          await prefs.setString(
            _prefCachedModels,
            jsonEncode(scored.map((e) => e.toJson()).toList()),
          );
          await prefs.setInt(_prefCachedAt, DateTime.now().millisecondsSinceEpoch);
          return scored;
        }
      } else {
        debugPrint('Gemini model discovery HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('Gemini model discovery error: $e');
    }

    return fallbackFreeModels
        .map((id) => GeminiModelInfo(
              id: id,
              displayName: id,
              description: 'Default fallback free-tier model',
              inputTokenLimit: 1048576,
              outputTokenLimit: 8192,
              suitabilityScore: 100,
              tierNote: 'Default Free Tier',
            ))
        .toList();
  }

  Future<String?> getManualModel() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_prefManualModel);
    return (val != null && val.isNotEmpty) ? val : null;
  }

  Future<void> setManualModel(String? modelId) async {
    final prefs = await SharedPreferences.getInstance();
    if (modelId == null || modelId.trim().isEmpty) {
      await prefs.remove(_prefManualModel);
    } else {
      await prefs.setString(_prefManualModel, modelId.trim());
    }
  }

  Future<String?> getLastWorkingModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefLastWorkingModel);
  }

  Future<void> markModelWorking(String modelId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefLastWorkingModel, modelId);
  }

  /// Returns an ordered list of candidate model IDs to try, starting with
  /// any user-pinned model, then the best auto-discovered free-tier models.
  Future<List<String>> getCandidateModelIds(String apiKey) async {
    final manual = await getManualModel();
    final discovered = await discoverBestFreeModels(apiKey);
    final ids = <String>[];

    if (manual != null) ids.add(manual);
    for (final m in discovered) {
      if (!ids.contains(m.id)) ids.add(m.id);
    }
    for (final f in fallbackFreeModels) {
      if (!ids.contains(f)) ids.add(f);
    }
    return ids.take(5).toList();
  }
}
