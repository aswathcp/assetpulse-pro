// ignore_for_file: constant_identifier_names

import 'package:cloud_firestore/cloud_firestore.dart';

enum FaultCategory { electrical, mechanical, instrumentation, operational, generic }
enum FaultStatus { pending, closed }
enum FaultPriority { critical, high, medium, low }
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
  final FaultPriority priority;
  final String? faultTypeId; // Reference to fault_types catalog ID
  final String cause;     // E.g., "Bearing Seizure"
  final String? odcId;    // Reference to odc_causes catalog ID
  final String odc;       // Observation/Defect/Condition
  final String actionTaken; // "Replaced DE Bearing"
  // Tracking Logistics
  final WorkShift shift;
  final List<String> assignedEngineers; // User IDs
  final List<String> assignedTechnicians; // User IDs

  // ODC Logic
  final bool isOdcApplicable;
  final bool isOdcClosed;
  final String? odcObject; // Component / Object Part (e.g., "DE Bearing", "Stator Winding")
  final String? odcDamage; // Damage / Defect Mode (e.g., "High Vibration", "Insulation Breakdown")
  final String? odcCause;  // Root Cause / Failure Mechanism (e.g., "Grease Starvation", "Overload")
  final List<String> odcDamages; // Multi-select support for Defect Modes
  final List<String> odcCauses;  // Multi-select support for Root Causes

  // Plant & Unit Scope
  final String? plantId;
  final String? unitId;

  // Resolution Tracking
  final FaultStatus status;
  final int? downtimeMinutes;
  final String? rectifiedBy; // External/Contractor Name if not in assigned lists

  FaultLogModel({
    required this.id,
    required this.masterEquipmentId,
    this.assetId,
    this.plantId,
    this.unitId,
    required this.reportedByUserId,
    required this.reportedAt,
    this.category = FaultCategory.generic,
    this.priority = FaultPriority.medium,
    this.faultTypeId,
    required this.cause,
    this.odcId,
    required this.odc,
    this.actionTaken = '',
    this.shift = WorkShift.as,
    this.assignedEngineers = const [],
    this.assignedTechnicians = const [],
    this.isOdcApplicable = false,
    this.isOdcClosed = false,
    this.odcObject,
    this.odcDamage,
    this.odcCause,
    this.odcDamages = const [],
    this.odcCauses = const [],
    this.status = FaultStatus.pending,
    this.downtimeMinutes,
    this.rectifiedBy,
  });

  factory FaultLogModel.fromMap(Map<String, dynamic> map, String id) {
    final rawDamages = map['odcDamages'] != null ? List<String>.from(map['odcDamages']) : <String>[];
    final rawCauses = map['odcCauses'] != null ? List<String>.from(map['odcCauses']) : <String>[];
    final singleDamage = map['odcDamage']?.toString();
    final singleCause = map['odcCause']?.toString();

    if (rawDamages.isEmpty && singleDamage != null && singleDamage.isNotEmpty) {
      rawDamages.addAll(singleDamage.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
    }
    if (rawCauses.isEmpty && singleCause != null && singleCause.isNotEmpty) {
      rawCauses.addAll(singleCause.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
    }

    return FaultLogModel(
      id: id,
      masterEquipmentId: map['masterEquipmentId'] ?? '',
      assetId: map['assetId'],
      plantId: map['plantId']?.toString(),
      unitId: map['unitId']?.toString(),
      reportedByUserId: map['reportedByUserId'] ?? '',
      reportedAt: (map['reportedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      category: FaultCategory.values.firstWhere(
        (e) => e.name == (map['category'] ?? 'generic'),
        orElse: () => FaultCategory.generic,
      ),
      priority: FaultPriority.values.firstWhere(
        (e) => e.name == (map['priority'] ?? 'medium'),
        orElse: () => FaultPriority.medium,
      ),
      faultTypeId: map['faultTypeId'],
      cause: map['cause'] ?? '',
      odcId: map['odcId'],
      odc: map['odc'] ?? '',
      actionTaken: map['actionTaken'] ?? '',
      status: (map['status'] == 'closed' || map['status'] == 'resolved')
          ? FaultStatus.closed
          : FaultStatus.pending,
      shift: WorkShift.values.firstWhere(
        (e) => e.name == (map['shift'] ?? 'as'),
        orElse: () => WorkShift.as,
      ),
      assignedEngineers: List<String>.from(map['assignedEngineers'] ?? []),
      assignedTechnicians: List<String>.from(map['assignedTechnicians'] ?? []),
      isOdcApplicable: map['isOdcApplicable'] ?? false,
      isOdcClosed: map['isOdcClosed'] ?? false,
      odcObject: map['odcObject']?.toString(),
      odcDamage: singleDamage ?? (rawDamages.isNotEmpty ? rawDamages.join(', ') : null),
      odcCause: singleCause ?? (rawCauses.isNotEmpty ? rawCauses.join(', ') : null),
      odcDamages: rawDamages,
      odcCauses: rawCauses,
      downtimeMinutes: map['downtimeMinutes'] as int?,
      rectifiedBy: map['rectifiedBy'],
    );
  }

  Map<String, dynamic> toMap() {
    final effectiveDamage = odcDamage ?? (odcDamages.isNotEmpty ? odcDamages.join(', ') : null);
    final effectiveCause = odcCause ?? (odcCauses.isNotEmpty ? odcCauses.join(', ') : null);

    return {
      'masterEquipmentId': masterEquipmentId,
      'assetId': assetId,
      'plantId': plantId,
      'unitId': unitId,
      'reportedByUserId': reportedByUserId,
      'reportedAt': reportedAt,
      'category': category.name,
      'priority': priority.name,
      'faultTypeId': faultTypeId,
      'cause': cause,
      'odcId': odcId,
      'odc': odc,
      'odcObject': odcObject,
      'odcDamage': effectiveDamage,
      'odcCause': effectiveCause,
      'odcDamages': odcDamages.isNotEmpty ? odcDamages : (effectiveDamage != null ? [effectiveDamage] : []),
      'odcCauses': odcCauses.isNotEmpty ? odcCauses : (effectiveCause != null ? [effectiveCause] : []),
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
