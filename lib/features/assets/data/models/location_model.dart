import 'package:cloud_firestore/cloud_firestore.dart';

class LocationModel {
  final String id;
  final String unitId;
  final String plantId;
  final String name;
  final String type;
  final String description;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? modifiedAt;
  final String? modifiedBy;

  LocationModel({
    required this.id,
    required this.unitId,
    required this.plantId,
    required this.name,
    this.type = 'Area',
    this.description = '',
    this.createdAt,
    this.createdBy,
    this.modifiedAt,
    this.modifiedBy,
  });

  factory LocationModel.fromMap(Map<String, dynamic> map, String id) {
    return LocationModel(
      id: id,
      unitId: map['unitId'] ?? '',
      plantId: map['plantId'] ?? '',
      name: map['name'] ?? '',
      type: map['type'] ?? 'Area',
      description: map['description'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      createdBy: map['createdBy'],
      modifiedAt: (map['modifiedAt'] as Timestamp?)?.toDate(),
      modifiedBy: map['modifiedBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'unitId': unitId,
      'plantId': plantId,
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
