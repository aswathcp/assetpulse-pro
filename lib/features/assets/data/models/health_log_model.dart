import 'package:cloud_firestore/cloud_firestore.dart';

class HealthLogModel {
  final String id;
  final String assetId;
  final DateTime testDate;
  final String testedBy;
  final double? noLoadCurrent;
  final Map<String, dynamic>? windingResistance; // {'R-Y': 1.2, 'Y-B': 1.2, ...}
  final Map<String, dynamic>? insulationResistance; // {'R-Y': 100, 'Y-E': 500, ...}
  final double? polarizationIndex;
  final Map<String, dynamic>? vibration; // {'DE_H': 1.5, 'DE_V': 2.0, ...}
  final String remarks;
  final String healthStatus; // healthy, warning, critical

  HealthLogModel({
    required this.id,
    required this.assetId,
    required this.testDate,
    required this.testedBy,
    this.noLoadCurrent,
    this.windingResistance,
    this.insulationResistance,
    this.polarizationIndex,
    this.vibration,
    required this.remarks,
    required this.healthStatus,
  });

  Map<String, dynamic> toMap() {
    return {
      'assetId': assetId,
      'testDate': Timestamp.fromDate(testDate),
      'testedBy': testedBy,
      'noLoadCurrent': noLoadCurrent,
      'windingResistance': windingResistance,
      'insulationResistance': insulationResistance,
      'polarizationIndex': polarizationIndex,
      'vibration': vibration,
      'remarks': remarks,
      'healthStatus': healthStatus,
    };
  }

  factory HealthLogModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parsedDate = DateTime.now();
    final rawDate = map['testDate'];
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is DateTime) {
      parsedDate = rawDate;
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    }

    return HealthLogModel(
      id: docId,
      assetId: map['assetId']?.toString() ?? '',
      testDate: parsedDate,
      testedBy: map['testedBy']?.toString() ?? '',
      noLoadCurrent: (map['noLoadCurrent'] as num?)?.toDouble(),
      windingResistance: map['windingResistance'] is Map ? Map<String, dynamic>.from(map['windingResistance'] as Map) : null,
      insulationResistance: map['insulationResistance'] is Map ? Map<String, dynamic>.from(map['insulationResistance'] as Map) : null,
      polarizationIndex: (map['polarizationIndex'] as num?)?.toDouble(),
      vibration: map['vibration'] is Map ? Map<String, dynamic>.from(map['vibration'] as Map) : null,
      remarks: map['remarks']?.toString() ?? '',
      healthStatus: map['healthStatus']?.toString() ?? 'healthy',
    );
  }
}
