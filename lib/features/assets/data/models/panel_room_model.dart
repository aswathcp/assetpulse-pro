import 'package:cloud_firestore/cloud_firestore.dart';

class PanelRoomModel {
  final String id;
  final String plantId;
  final String unitId;
  final String locationId;
  final String name;
  final String description;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? modifiedAt;
  final String? modifiedBy;

  PanelRoomModel({
    required this.id,
    required this.plantId,
    required this.unitId,
    this.locationId = '',
    required this.name,
    this.description = '',
    this.createdAt,
    this.createdBy,
    this.modifiedAt,
    this.modifiedBy,
  });

  factory PanelRoomModel.fromMap(Map<String, dynamic> map, String id) {
    return PanelRoomModel(
      id: id,
      plantId: map['plantId'] ?? '',
      unitId: map['unitId'] ?? '',
      locationId: map['locationId'] ?? '',
      name: map['name'] ?? '',
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
      'locationId': locationId,
      'name': name,
      'description': description,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'modifiedAt': modifiedAt ?? FieldValue.serverTimestamp(),
      'modifiedBy': modifiedBy,
    };
  }
}
