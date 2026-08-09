import 'package:cloud_firestore/cloud_firestore.dart';

class JointIlluminationAuditModel {
  final String id;
  final String plantId;
  final String unitId;
  final String businessId;
  final String locationId;
  final String locationName;
  final String category;
  final String locationType;
  final String auditQuarter; // e.g. "Q1 2026", "Q2 2026"
  final DateTime auditDate;
  final String auditedByTech;
  final String jointDeptName; // e.g. "Production", "Safety", "Mechanical"
  final String jointAuditorName;
  final int totalLuminairesCount;
  final bool hasFaultyLights;
  final int faultyCount;
  final bool needsReplacement;
  final String replacementDetails;
  final bool needsAdditionalLight;
  final String additionalLightDetails;
  final String status; // "Open" or "Closed"
  final String? rectifiedBy;
  final DateTime? rectificationDate;
  final String? rectificationAction;
  final String remarks;

  JointIlluminationAuditModel({
    required this.id,
    required this.plantId,
    required this.unitId,
    required this.businessId,
    required this.locationId,
    required this.locationName,
    required this.category,
    required this.locationType,
    required this.auditQuarter,
    required this.auditDate,
    required this.auditedByTech,
    required this.jointDeptName,
    required this.jointAuditorName,
    this.totalLuminairesCount = 0,
    required this.hasFaultyLights,
    this.faultyCount = 0,
    required this.needsReplacement,
    this.replacementDetails = '',
    required this.needsAdditionalLight,
    this.additionalLightDetails = '',
    required this.status,
    this.rectifiedBy,
    this.rectificationDate,
    this.rectificationAction,
    this.remarks = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'plantId': plantId,
      'unitId': unitId,
      'businessId': businessId,
      'locationId': locationId,
      'locationName': locationName,
      'category': category,
      'locationType': locationType,
      'auditQuarter': auditQuarter,
      'auditDate': auditDate.toIso8601String(),
      'auditedByTech': auditedByTech,
      'jointDeptName': jointDeptName,
      'jointAuditorName': jointAuditorName,
      'totalLuminairesCount': totalLuminairesCount,
      'hasFaultyLights': hasFaultyLights,
      'faultyCount': faultyCount,
      'needsReplacement': needsReplacement,
      'replacementDetails': replacementDetails,
      'needsAdditionalLight': needsAdditionalLight,
      'additionalLightDetails': additionalLightDetails,
      'status': status,
      'rectifiedBy': rectifiedBy,
      'rectificationDate': rectificationDate?.toIso8601String(),
      'rectificationAction': rectificationAction,
      'remarks': remarks,
    };
  }

  factory JointIlluminationAuditModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return JointIlluminationAuditModel(
      id: docId,
      plantId: map['plantId'] ?? '',
      unitId: map['unitId'] ?? '',
      businessId: map['businessId'] ?? 'VISL',
      locationId: map['locationId'] ?? '',
      locationName: map['locationName'] ?? '',
      category: map['category'] ?? '',
      locationType: map['locationType'] ?? '',
      auditQuarter: map['auditQuarter'] ?? 'Q1 2026',
      auditDate: parseDate(map['auditDate']),
      auditedByTech: map['auditedByTech'] ?? '',
      jointDeptName: map['jointDeptName'] ?? 'Production',
      jointAuditorName: map['jointAuditorName'] ?? '',
      totalLuminairesCount: (map['totalLuminairesCount'] as num?)?.toInt() ?? 0,
      hasFaultyLights: map['hasFaultyLights'] == true,
      faultyCount: (map['faultyCount'] as num?)?.toInt() ?? 0,
      needsReplacement: map['needsReplacement'] == true,
      replacementDetails: map['replacementDetails'] ?? '',
      needsAdditionalLight: map['needsAdditionalLight'] == true,
      additionalLightDetails: map['additionalLightDetails'] ?? '',
      status: map['status'] ?? 'Open',
      rectifiedBy: map['rectifiedBy'],
      rectificationDate: map['rectificationDate'] != null ? parseDate(map['rectificationDate']) : null,
      rectificationAction: map['rectificationAction'],
      remarks: map['remarks'] ?? '',
    );
  }
}
