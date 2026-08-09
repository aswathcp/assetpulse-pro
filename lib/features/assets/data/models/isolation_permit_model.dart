import 'package:cloud_firestore/cloud_firestore.dart';

enum IsolationStatus { active, cleared, renewed }

class IsolationPermitModel {
  final String id;
  final String permitNo;
  
  // Hierarchy IDs
  final String businessId;
  final String plantId;
  final String unitId;
  final String locationId;
  final String panelId;
  final String feederId;

  // Details
  final String requestingDepartment;
  final String reason;
  final DateTime isolationDateTime;
  
  // Personnel (User UIDs)
  final String requestingOfficerId;
  final String isolationOfficerId;
  
  // Locks
  final String requesterLockNo;
  final String isolationOfficerLockNo;
  final int personalLocksCount;

  // Status
  final IsolationStatus status;
  
  // Clearance (Optional)
  final String? clearingOfficerId;
  final String? normalizingOfficerId;
  final DateTime? clearanceDateTime;
  
  // Renewal
  final List<Map<String, dynamic>> renewalHistory;

  IsolationPermitModel({
    required this.id,
    required this.permitNo,
    required this.businessId,
    required this.plantId,
    required this.unitId,
    required this.locationId,
    required this.panelId,
    required this.feederId,
    required this.requestingDepartment,
    required this.reason,
    required this.isolationDateTime,
    required this.requestingOfficerId,
    required this.isolationOfficerId,
    required this.requesterLockNo,
    required this.isolationOfficerLockNo,
    this.personalLocksCount = 0,
    this.status = IsolationStatus.active,
    this.clearingOfficerId,
    this.normalizingOfficerId,
    this.clearanceDateTime,
    this.renewalHistory = const [],
  });

  factory IsolationPermitModel.fromMap(Map<String, dynamic> map, String id) {
    return IsolationPermitModel(
      id: id,
      permitNo: map['permitNo'] ?? '',
      businessId: map['businessId'] ?? '',
      plantId: map['plantId'] ?? '',
      unitId: map['unitId'] ?? '',
      locationId: map['locationId'] ?? '',
      panelId: map['panelId'] ?? '',
      feederId: map['feederId'] ?? '',
      requestingDepartment: map['requestingDepartment'] ?? '',
      reason: map['reason'] ?? '',
      isolationDateTime: (map['isolationDateTime'] as Timestamp).toDate(),
      requestingOfficerId: map['requestingOfficerId'] ?? '',
      isolationOfficerId: map['isolationOfficerId'] ?? '',
      requesterLockNo: map['requesterLockNo'] ?? '',
      isolationOfficerLockNo: map['isolationOfficerLockNo'] ?? '',
      personalLocksCount: map['personalLocksCount'] ?? 0,
      status: IsolationStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'active'),
        orElse: () => IsolationStatus.active,
      ),
      clearingOfficerId: map['clearingOfficerId'],
      normalizingOfficerId: map['normalizingOfficerId'],
      clearanceDateTime: (map['clearanceDateTime'] as Timestamp?)?.toDate(),
      renewalHistory: List<Map<String, dynamic>>.from(map['renewalHistory'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'permitNo': permitNo,
      'plantId': plantId,
      'unitId': unitId,
      'locationId': locationId,
      'panelId': panelId,
      'feederId': feederId,
      'requestingDepartment': requestingDepartment,
      'reason': reason,
      'isolationDateTime': Timestamp.fromDate(isolationDateTime),
      'requestingOfficerId': requestingOfficerId,
      'isolationOfficerId': isolationOfficerId,
      'requesterLockNo': requesterLockNo,
      'isolationOfficerLockNo': isolationOfficerLockNo,
      'personalLocksCount': personalLocksCount,
      'status': status.name,
      'clearingOfficerId': clearingOfficerId,
      'normalizingOfficerId': normalizingOfficerId,
      'clearanceDateTime': clearanceDateTime != null ? Timestamp.fromDate(clearanceDateTime!) : null,
      'renewalHistory': renewalHistory,
    };
  }
}
