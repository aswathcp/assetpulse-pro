import 'package:cloud_firestore/cloud_firestore.dart';

class FeederModel {
  final String id;
  final String plantId;
  final String unitId;
  final String panelId; // Context reference
  final String name;
  final String type;
  final String description;
  final String busSection;
  final String operatingState;
  final String? upstreamFeederId;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? modifiedAt;
  final String? modifiedBy;

  FeederModel({
    required this.id,
    required this.plantId,
    required this.unitId,
    required this.panelId,
    required this.name,
    this.type = 'Feeder',
    this.description = '',
    this.busSection = 'MAIN',
    this.operatingState = 'CLOSED',
    this.upstreamFeederId,
    this.createdAt,
    this.createdBy,
    this.modifiedAt,
    this.modifiedBy,
  });

  bool get isClosed => operatingState.toUpperCase() == 'CLOSED';

  factory FeederModel.fromMap(Map<String, dynamic> map, String id) {
    return FeederModel(
      id: id,
      plantId: map['plantId'] ?? '',
      unitId: map['unitId'] ?? '',
      panelId: map['panelId'] ?? '',
      name: map['name'] ?? '',
      type: map['type'] ?? 'Feeder',
      description: map['description'] ?? '',
      busSection: map['busSection'] ?? 'MAIN',
      operatingState: map['operatingState'] ?? 'CLOSED',
      upstreamFeederId: map['upstreamFeederId'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      createdBy: map['createdBy'],
      modifiedAt: (map['modifiedAt'] as Timestamp?)?.toDate(),
      modifiedBy: map['modifiedBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'plantId': plantId,
      'unitId': unitId,
      'panelId': panelId,
      'name': name,
      'type': type,
      'description': description,
      'busSection': busSection,
      'operatingState': operatingState,
      'upstreamFeederId': upstreamFeederId,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'modifiedAt': modifiedAt ?? FieldValue.serverTimestamp(),
      'modifiedBy': modifiedBy,
    };
  }
}
