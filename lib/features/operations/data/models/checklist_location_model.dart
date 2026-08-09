class ChecklistLocationModel {
  final String id;
  final String locationTargetId; // Linked identifier e.g., "BF1 Battery Room"
  final String checklistType; // e.g., "Shift Checklist - Battery Room"
  final double latitude;
  final double longitude;
  final String businessId;
  final String plantId;
  final String unitId;

  ChecklistLocationModel({
    required this.id,
    required this.locationTargetId,
    required this.checklistType,
    required this.latitude,
    required this.longitude,
    required this.businessId,
    required this.plantId,
    required this.unitId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'locationTargetId': locationTargetId,
      'checklistType': checklistType,
      'latitude': latitude,
      'longitude': longitude,
      'businessId': businessId,
      'plantId': plantId,
      'unitId': unitId,
    };
  }

  factory ChecklistLocationModel.fromMap(Map<String, dynamic> map, String docId) {
    return ChecklistLocationModel(
      id: docId,
      locationTargetId: map['locationTargetId'] ?? '',
      checklistType: map['checklistType'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      businessId: map['businessId'] ?? '',
      plantId: map['plantId'] ?? '',
      unitId: map['unitId'] ?? '',
    );
  }
}
