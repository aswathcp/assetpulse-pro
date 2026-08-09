import 'package:cloud_firestore/cloud_firestore.dart';

class FeederModel {
  final String id;
  final String plantId;
  final String unitId;
  final String panelId; // Context reference
  final String name;
  final String type;
  final String description;
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
    this.createdAt,
    this.createdBy,
    this.modifiedAt,
    this.modifiedBy,
  });

  factory FeederModel.fromMap(Map<String, dynamic> map, String id) {
    return FeederModel(
      id: id,
      plantId: map['plantId'] ?? '',
      unitId: map['unitId'] ?? '',
      panelId: map['panelId'] ?? '',
      name: map['name'] ?? '',
      type: map['type'] ?? 'Feeder',
      description: map['description'] ?? '',
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
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'modifiedAt': modifiedAt ?? FieldValue.serverTimestamp(),
      'modifiedBy': modifiedBy,
    };
  }
}
