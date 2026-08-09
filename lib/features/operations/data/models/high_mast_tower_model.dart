class HighMastTowerModel {
  final String id;
  final String plantId;
  final String unitId;
  final String tagId;
  final String location;
  final String status; // 'Certified', 'Not Certified', 'Expired', 'Never Tested'
  final DateTime? lastServicingDate;
  final DateTime? nextDueDate;
  final String currentQuarter;
  final String remarks;
  final DateTime createdAt;
  final DateTime updatedAt;

  HighMastTowerModel({
    required this.id,
    required this.plantId,
    required this.unitId,
    required this.tagId,
    required this.location,
    this.status = 'Never Tested',
    this.lastServicingDate,
    this.nextDueDate,
    this.currentQuarter = '',
    this.remarks = '',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'plantId': plantId,
      'unitId': unitId,
      'tagId': tagId,
      'location': location,
      'status': status,
      'lastServicingDate': lastServicingDate?.toIso8601String(),
      'nextDueDate': nextDueDate?.toIso8601String(),
      'currentQuarter': currentQuarter,
      'remarks': remarks,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory HighMastTowerModel.fromMap(Map<String, dynamic> map, String docId) {
    return HighMastTowerModel(
      id: docId,
      plantId: map['plantId'] ?? '',
      unitId: map['unitId'] ?? '',
      tagId: map['tagId'] ?? docId,
      location: map['location'] ?? map['area'] ?? map['areaName'] ?? '',
      status: map['status'] ?? 'Never Tested',
      lastServicingDate: map['lastServicingDate'] != null ? DateTime.tryParse(map['lastServicingDate']) : null,
      nextDueDate: map['nextDueDate'] != null ? DateTime.tryParse(map['nextDueDate']) : null,
      currentQuarter: map['currentQuarter'] ?? '',
      remarks: map['remarks'] ?? '',
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt']) ?? DateTime.now() : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt']) ?? DateTime.now() : DateTime.now(),
    );
  }
}

class HighMastReportModel {
  final String id;
  final String plantId;
  final String unitId;
  final String towerId;
  final String tagId;
  final String location;
  final String checkType; // 'Quarterly High Mast Servicing & Hoisting Safety Inspection'
  final DateTime testingDate;
  final DateTime nextDueDate;
  final String quarter;
  final String status; // 'Certified', 'Not Certified'
  final String servicedBy;
  final String gearboxOilStatus; // 'OK', 'Filling Done', 'Overhauled'
  final String bulldogClampRemarks; // e.g. '4 Piece Bulldog Replaced'
  final String panelCondition; // 'OK', 'NOT OK', 'DAMAGED'
  final Map<String, bool> checkpoints;
  final String actionTaken;
  final String remarks;

  HighMastReportModel({
    required this.id,
    required this.plantId,
    required this.unitId,
    required this.towerId,
    required this.tagId,
    required this.location,
    required this.checkType,
    required this.testingDate,
    required this.nextDueDate,
    required this.quarter,
    required this.status,
    required this.servicedBy,
    this.gearboxOilStatus = 'OK',
    this.bulldogClampRemarks = '',
    this.panelCondition = 'OK',
    required this.checkpoints,
    this.actionTaken = '',
    this.remarks = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'plantId': plantId,
      'unitId': unitId,
      'towerId': towerId,
      'tagId': tagId,
      'location': location,
      'checkType': checkType,
      'testingDate': testingDate.toIso8601String(),
      'nextDueDate': nextDueDate.toIso8601String(),
      'quarter': quarter,
      'status': status,
      'servicedBy': servicedBy,
      'gearboxOilStatus': gearboxOilStatus,
      'bulldogClampRemarks': bulldogClampRemarks,
      'panelCondition': panelCondition,
      'checkpoints': checkpoints,
      'actionTaken': actionTaken,
      'remarks': remarks,
    };
  }

  factory HighMastReportModel.fromMap(Map<String, dynamic> map, String docId) {
    Map<String, bool> cp = {};
    if (map['checkpoints'] != null && map['checkpoints'] is Map) {
      (map['checkpoints'] as Map).forEach((k, v) {
        cp[k.toString()] = v == true;
      });
    }

    return HighMastReportModel(
      id: docId,
      plantId: map['plantId'] ?? '',
      unitId: map['unitId'] ?? '',
      towerId: map['towerId'] ?? '',
      tagId: map['tagId'] ?? docId,
      location: map['location'] ?? '',
      checkType: map['checkType'] ?? 'Quarterly High Mast Servicing & Hoisting Safety Inspection',
      testingDate: map['testingDate'] != null ? DateTime.tryParse(map['testingDate']) ?? DateTime.now() : DateTime.now(),
      nextDueDate: map['nextDueDate'] != null ? DateTime.tryParse(map['nextDueDate']) ?? DateTime.now().add(const Duration(days: 90)) : DateTime.now().add(const Duration(days: 90)),
      quarter: map['quarter'] ?? '',
      status: map['status'] ?? 'Not Certified',
      servicedBy: map['servicedBy'] ?? map['testedBy'] ?? 'Technician',
      gearboxOilStatus: map['gearboxOilStatus'] ?? 'OK',
      bulldogClampRemarks: map['bulldogClampRemarks'] ?? '',
      panelCondition: map['panelCondition'] ?? 'OK',
      checkpoints: cp,
      actionTaken: map['actionTaken'] ?? '',
      remarks: map['remarks'] ?? '',
    );
  }
}
