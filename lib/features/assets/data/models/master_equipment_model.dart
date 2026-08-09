import 'package:cloud_firestore/cloud_firestore.dart';

class MasterEquipmentModel {
  final String id; // This is the TagNo (e.g., BF1-CV-01)
  final String unitId;
  final String plantId;
  final String name;
  final String area;
  final String type;
  final String locationId;    // Physical Area / Location reference
  final String? panelRoomId; // Optional Panel Room reference
  final String? panelId;     // Optional, mechanical assets might not have a panel
  final String? feederId;    // Optional, mechanical assets might not have a feeder
  final String description;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? modifiedAt;
  final String? modifiedBy;

  MasterEquipmentModel({
    required this.id,
    required this.unitId,
    required this.plantId,
    required this.name,
    required this.area,
    required this.type,
    required this.locationId,
    this.panelRoomId,
    this.panelId,
    this.feederId,
    this.description = '',
    this.createdAt,
    this.createdBy,
    this.modifiedAt,
    this.modifiedBy,
  });

  factory MasterEquipmentModel.fromMap(Map<String, dynamic> map, String id) {
    return MasterEquipmentModel(
      id: id,
      unitId: map['unitId'] ?? '',
      plantId: map['plantId'] ?? '',
      name: map['name'] ?? '',
      area: map['area'] ?? '',
      type: map['type'] ?? '',
      locationId: map['locationId'] ?? '',
      panelRoomId: map['panelRoomId'],
      panelId: map['panelId'] ?? '',
      feederId: map['feederId'],
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
      'area': area,
      'type': type,
      'locationId': locationId,
      'panelRoomId': panelRoomId,
      'panelId': panelId,
      'feederId': feederId,
      'description': description,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'modifiedAt': modifiedAt ?? FieldValue.serverTimestamp(),
      'modifiedBy': modifiedBy,
    };
  }
}
