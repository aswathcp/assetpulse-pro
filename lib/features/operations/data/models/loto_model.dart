enum LotoStatus {
  requested, // User requested isolation
  active,    // Isolated and Locked
  rejected,  // Rejected by approver
  completed  // De-isolated and Closed
}

class LotoModel {
  final String id;
  final String assetId;
  final String assetName; // Denormalized for list display
  final String assetTag;  // Denormalized
  
  final String requesterId;
  final String requesterName;
  
  final String? approverId;
  final String? approverName;
  
  final String isolationPoint;
  final String reason;
  
  final LotoStatus status;
  
  final DateTime createdAt;
  final DateTime? activeAt;   // Time when isolation was applied
  final DateTime? completedAt; // Time when de-isolated

  LotoModel({
    required this.id,
    required this.assetId,
    required this.assetName,
    required this.assetTag,
    required this.requesterId,
    required this.requesterName,
    this.approverId,
    this.approverName,
    required this.isolationPoint,
    required this.reason,
    this.status = LotoStatus.requested,
    required this.createdAt,
    this.activeAt,
    this.completedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'assetId': assetId,
      'assetName': assetName,
      'assetTag': assetTag,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'approverId': approverId,
      'approverName': approverName,
      'isolationPoint': isolationPoint,
      'reason': reason,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'activeAt': activeAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory LotoModel.fromMap(Map<String, dynamic> map, String id) {
    return LotoModel(
      id: id,
      assetId: map['assetId'] ?? '',
      assetName: map['assetName'] ?? 'Unknown Asset',
      assetTag: map['assetTag'] ?? 'Unknown Tag',
      requesterId: map['requesterId'] ?? '',
      requesterName: map['requesterName'] ?? 'Unknown User',
      approverId: map['approverId'],
      approverName: map['approverName'],
      isolationPoint: map['isolationPoint'] ?? '',
      reason: map['reason'] ?? '',
      status: LotoStatus.values.firstWhere(
          (e) => e.name == map['status'], orElse: () => LotoStatus.requested),
      createdAt: DateTime.parse(map['createdAt']),
      activeAt: map['activeAt'] != null ? DateTime.parse(map['activeAt']) : null,
      completedAt: map['completedAt'] != null ? DateTime.parse(map['completedAt']) : null,
    );
  }
}
