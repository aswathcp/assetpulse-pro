class ChecklistSubmissionModel {
  final String id;
  final String checklistType; // e.g., 'Battery Room'
  final String locationTargetId; // Linked to specific equipment or location
  final Map<String, double>? startCoordinates; // {'lat': x, 'lng': y}
  final Map<String, double>? endCoordinates; // {'lat': x, 'lng': y}
  final DateTime timestampStart;
  final DateTime? timestampEnd;
  final String submittedBy;
  final String? submittedByName;
  final Map<String, dynamic> fields;
  final bool isVerifiedLocation;
  final String businessId;
  final String plantId;
  final String unitId;
  final String? shift;
  final bool? deleted;
  final String? deletedBy;
  final String? deletedAt;
  final String? lastModifiedBy;
  final String? lastModifiedAt;

  ChecklistSubmissionModel({
    required this.id,
    required this.checklistType,
    required this.locationTargetId,
    this.startCoordinates,
    this.endCoordinates,
    required this.timestampStart,
    this.timestampEnd,
    required this.submittedBy,
    this.submittedByName,
    required this.fields,
    required this.isVerifiedLocation,
    required this.businessId,
    required this.plantId,
    required this.unitId,
    this.shift,
    this.deleted,
    this.deletedBy,
    this.deletedAt,
    this.lastModifiedBy,
    this.lastModifiedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'checklistType': checklistType,
      'locationTargetId': locationTargetId,
      'startCoordinates': startCoordinates,
      'endCoordinates': endCoordinates,
      'timestampStart': timestampStart.toIso8601String(),
      'timestampEnd': timestampEnd?.toIso8601String(),
      'submittedBy': submittedBy,
      'submittedByName': submittedByName,
      'fields': fields,
      'isVerifiedLocation': isVerifiedLocation,
      'plantId': plantId,
      'unitId': unitId,
      'shift': shift,
      'deleted': deleted,
      'deletedBy': deletedBy,
      'deletedAt': deletedAt,
      'lastModifiedBy': lastModifiedBy,
      'lastModifiedAt': lastModifiedAt,
    };
  }

  factory ChecklistSubmissionModel.fromMap(Map<String, dynamic> map, String docId) {
    return ChecklistSubmissionModel(
      id: docId,
      checklistType: map['checklistType'] ?? '',
      locationTargetId: map['locationTargetId'] ?? '',
      startCoordinates: map['startCoordinates'] != null ? Map<String, double>.from(map['startCoordinates']) : null,
      endCoordinates: map['endCoordinates'] != null ? Map<String, double>.from(map['endCoordinates']) : null,
      timestampStart: map['timestampStart'] != null ? DateTime.parse(map['timestampStart']) : DateTime.now(),
      timestampEnd: map['timestampEnd'] != null ? DateTime.parse(map['timestampEnd']) : null,
      submittedBy: map['submittedBy'] ?? '',
      submittedByName: map['submittedByName'],
      fields: map['fields'] != null ? Map<String, dynamic>.from(map['fields']) : {},
      isVerifiedLocation: map['isVerifiedLocation'] ?? false,
      businessId: map['businessId'] ?? '',
      plantId: map['plantId'] ?? '',
      unitId: map['unitId'] ?? '',
      shift: map['shift'],
      deleted: map['deleted'],
      deletedBy: map['deletedBy'],
      deletedAt: map['deletedAt'],
      lastModifiedBy: map['lastModifiedBy'],
      lastModifiedAt: map['lastModifiedAt'],
    );
  }
}
