// ignore_for_file: constant_identifier_names

import 'package:cloud_firestore/cloud_firestore.dart';

enum FaultCategory { electrical, mechanical, instrumentation, operational, generic }
enum FaultStatus { open, in_progress, pending, resolved, closed }
enum WorkShift { as, bs, cs, gs }

class FaultLogModel {
  final String id;
  // Relationships
  final String masterEquipmentId;
  final String? assetId; // Optional, if a specific sub-asset failed

  // Identity / Audit
  final String reportedByUserId; // Who logged the fault
  final DateTime reportedAt;

  // Specifics
  final FaultCategory category;
  final String cause;     // E.g., "Bearing Seizure"
  final String odc;       // Observation/Defect/Condition
  final String actionTaken; // "Replaced DE Bearing"
  // Tracking Logistics
  final WorkShift shift;
  final List<String> assignedEngineers; // User IDs
  final List<String> assignedTechnicians; // User IDs

  // ODC Logic
  final bool isOdcApplicable;
  final bool isOdcClosed;

  // Resolution Tracking
  final FaultStatus status;
  final int? downtimeMinutes;
  final String? rectifiedBy; // External/Contractor Name if not in assigned lists

  FaultLogModel({
    required this.id,
    required this.masterEquipmentId,
    this.assetId,
    required this.reportedByUserId,
    required this.reportedAt,
    this.category = FaultCategory.generic,
    required this.cause,
    required this.odc,
    this.actionTaken = '',
    this.shift = WorkShift.as,
    this.assignedEngineers = const [],
    this.assignedTechnicians = const [],
    this.isOdcApplicable = false,
    this.isOdcClosed = false,
    this.status = FaultStatus.open,
    this.downtimeMinutes,
    this.rectifiedBy,
  });

  factory FaultLogModel.fromMap(Map<String, dynamic> map, String id) {
    return FaultLogModel(
      id: id,
      masterEquipmentId: map['masterEquipmentId'] ?? '',
      assetId: map['assetId'],
      reportedByUserId: map['reportedByUserId'] ?? '',
      reportedAt: (map['reportedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      category: FaultCategory.values.firstWhere(
        (e) => e.name == (map['category'] ?? 'generic'),
        orElse: () => FaultCategory.generic,
      ),
      cause: map['cause'] ?? '',
      odc: map['odc'] ?? '',
      actionTaken: map['actionTaken'] ?? '',
      status: FaultStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'open'),
        orElse: () => FaultStatus.open,
      ),
      shift: WorkShift.values.firstWhere(
        (e) => e.name == (map['shift'] ?? 'as'),
        orElse: () => WorkShift.as,
      ),
      assignedEngineers: List<String>.from(map['assignedEngineers'] ?? []),
      assignedTechnicians: List<String>.from(map['assignedTechnicians'] ?? []),
      isOdcApplicable: map['isOdcApplicable'] ?? false,
      isOdcClosed: map['isOdcClosed'] ?? false,
      downtimeMinutes: map['downtimeMinutes'] as int?,
      rectifiedBy: map['rectifiedBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'masterEquipmentId': masterEquipmentId,
      'assetId': assetId,
      'reportedByUserId': reportedByUserId,
      'reportedAt': reportedAt,
      'category': category.name,
      'cause': cause,
      'odc': odc,
      'actionTaken': actionTaken,
      'status': status.name,
      'shift': shift.name,
      'assignedEngineers': assignedEngineers,
      'assignedTechnicians': assignedTechnicians,
      'isOdcApplicable': isOdcApplicable,
      'isOdcClosed': isOdcClosed,
      'downtimeMinutes': downtimeMinutes,
      'rectifiedBy': rectifiedBy,
    };
  }
}
