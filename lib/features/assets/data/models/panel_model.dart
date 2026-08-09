import 'package:cloud_firestore/cloud_firestore.dart';

class PanelModel {
  final String id;
  final String plantId;
  final String unitId;
  final String panelRoomId; // Context reference (renamed from locationId)
  final String name;
  final String type;
  final String description;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? modifiedAt;
  final String? modifiedBy;

  PanelModel({
    required this.id,
    required this.plantId,
    required this.unitId,
    required this.panelRoomId,
    required this.name,
    this.type = 'MCC',
    this.description = '',
    this.createdAt,
    this.createdBy,
    this.modifiedAt,
    this.modifiedBy,
  });

  factory PanelModel.fromMap(Map<String, dynamic> map, String id) {
    return PanelModel(
      id: id,
      plantId: map['plantId'] ?? '',
      unitId: map['unitId'] ?? '',
      panelRoomId: map['panelRoomId'] ?? map['locationId'] ?? '', // support legacy locationId field
      name: map['name'] ?? '',
      type: map['type'] ?? 'MCC',
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
      'panelRoomId': panelRoomId,
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
