import 'package:cloud_firestore/cloud_firestore.dart';

class TransformerModel {
  final String id;
  final String name;
  final String windingType; // 'two_winding' | 'three_winding'
  final double ratingKva;
  final String primaryVoltage; // e.g. '11kV'
  final String secondaryVoltage; // e.g. '3.3kV' or '415V'
  final String? tertiaryVoltage; // e.g. '415V' for three-winding
  final String? primarySourceFeederId; // HT Feeder feeding this transformer
  final String? secondaryTargetPanelId; // Panel fed by secondary (e.g. PCC-01)
  final String? tertiaryTargetPanelId;  // Panel fed by tertiary (e.g. 3.3kV Switchgear)
  final String locationId; // Physical area / yard (e.g. SUBSTATION-YARD)
  final String plantId;
  final String unitId;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? modifiedAt;
  final String? modifiedBy;

  TransformerModel({
    required this.id,
    required this.name,
    this.windingType = 'two_winding',
    required this.ratingKva,
    required this.primaryVoltage,
    required this.secondaryVoltage,
    this.tertiaryVoltage,
    this.primarySourceFeederId,
    this.secondaryTargetPanelId,
    this.tertiaryTargetPanelId,
    required this.locationId,
    required this.plantId,
    required this.unitId,
    this.createdAt,
    this.createdBy,
    this.modifiedAt,
    this.modifiedBy,
  });

  bool get isThreeWinding => windingType.toLowerCase().contains('three');

  factory TransformerModel.fromMap(Map<String, dynamic> map, String id) {
    return TransformerModel(
      id: id,
      name: map['name'] ?? '',
      windingType: map['windingType'] ?? 'two_winding',
      ratingKva: (map['ratingKva'] is num)
          ? (map['ratingKva'] as num).toDouble()
          : double.tryParse(map['ratingKva']?.toString() ?? '0') ?? 0.0,
      primaryVoltage: map['primaryVoltage'] ?? '11kV',
      secondaryVoltage: map['secondaryVoltage'] ?? '415V',
      tertiaryVoltage: map['tertiaryVoltage'],
      primarySourceFeederId: map['primarySourceFeederId'],
      secondaryTargetPanelId: map['secondaryTargetPanelId'],
      tertiaryTargetPanelId: map['tertiaryTargetPanelId'],
      locationId: map['locationId'] ?? '',
      plantId: map['plantId'] ?? '',
      unitId: map['unitId'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      createdBy: map['createdBy'],
      modifiedAt: (map['modifiedAt'] as Timestamp?)?.toDate(),
      modifiedBy: map['modifiedBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'windingType': windingType,
      'ratingKva': ratingKva,
      'primaryVoltage': primaryVoltage,
      'secondaryVoltage': secondaryVoltage,
      'tertiaryVoltage': tertiaryVoltage,
      'primarySourceFeederId': primarySourceFeederId,
      'secondaryTargetPanelId': secondaryTargetPanelId,
      'tertiaryTargetPanelId': tertiaryTargetPanelId,
      'locationId': locationId,
      'plantId': plantId,
      'unitId': unitId,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'modifiedAt': modifiedAt ?? FieldValue.serverTimestamp(),
      'modifiedBy': modifiedBy,
    };
  }
}
