import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:asset_pulse_pro/core/services/hierarchy_service.dart';

class PanelModel {
  final String id;
  final String plantId;
  final String unitId;
  final String locationId;  // Physical Area / Location ID
  final String panelRoomId; // Panel room (if inside a room) or location reference
  final String name;
  final String type;
  final String description;
  final String voltageLevel;
  final List<String> busSections;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? modifiedAt;
  final String? modifiedBy;

  PanelModel({
    required this.id,
    required this.plantId,
    required this.unitId,
    String? locationId,
    String? panelRoomId,
    required this.name,
    this.type = 'MCC',
    this.description = '',
    this.voltageLevel = '415V',
    this.busSections = const ['MAIN'],
    this.createdAt,
    this.createdBy,
    this.modifiedAt,
    this.modifiedBy,
  })  : locationId = locationId ?? panelRoomId ?? '',
        panelRoomId = panelRoomId ?? locationId ?? '';

  factory PanelModel.fromMap(Map<String, dynamic> map, String id) {
    final locId = map['locationId'] ?? map['panelRoomId'] ?? '';
    final prId = map['panelRoomId'] ?? map['locationId'] ?? '';
    return PanelModel(
      id: id,
      plantId: map['plantId'] ?? '',
      unitId: map['unitId'] ?? '',
      locationId: locId,
      panelRoomId: prId,
      name: map['name'] ?? '',
      type: map['type'] ?? 'MCC',
      description: map['description'] ?? '',
      voltageLevel: map['voltageLevel'] ?? map['voltage'] ?? '415V',
      busSections: HierarchyService.parseBusSections(map['busSections']),
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
      'panelRoomId': panelRoomId,
      'name': name,
      'type': type,
      'description': description,
      'voltageLevel': voltageLevel,
      'busSections': busSections,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'modifiedAt': modifiedAt ?? FieldValue.serverTimestamp(),
      'modifiedBy': modifiedBy,
    };
  }
}
