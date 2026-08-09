class WaterCoolerModel {
  final String id;
  final String plantId;
  final String unitId;
  final String tagId;
  final String coolerType;
  final String make;
  final String modelNumber;
  final String capacityLiters;
  final String owner;
  final String department;
  final String location;
  final String status; // 'Certified', 'Not Certified', 'Expired', 'Never Tested'
  final DateTime? lastServicingDate;
  final DateTime? nextDueDate;
  final String currentQuarter;
  final String remarks;
  final DateTime createdAt;
  final DateTime updatedAt;

  WaterCoolerModel({
    required this.id,
    required this.plantId,
    required this.unitId,
    required this.tagId,
    required this.coolerType,
    this.make = '',
    this.modelNumber = '',
    this.capacityLiters = '40 L/hr',
    this.owner = 'Vedanta',
    this.department = 'Administration',
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
      'coolerType': coolerType,
      'make': make,
      'modelNumber': modelNumber,
      'capacityLiters': capacityLiters,
      'owner': owner,
      'department': department,
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

  factory WaterCoolerModel.fromMap(Map<String, dynamic> map, String docId) {
    return WaterCoolerModel(
      id: docId,
      plantId: map['plantId'] ?? '',
      unitId: map['unitId'] ?? '',
      tagId: map['tagId'] ?? docId,
      coolerType: map['coolerType'] ?? map['type'] ?? 'Hot & Cold Dispenser',
      make: map['make'] ?? '',
      modelNumber: map['modelNumber'] ?? map['model'] ?? '',
      capacityLiters: map['capacityLiters'] ?? map['capacity'] ?? '40 L/hr',
      owner: map['owner'] ?? map['contractorName'] ?? 'Vedanta',
      department: map['department'] ?? 'Administration',
      location: map['location'] ?? '',
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

class WaterCoolerReportModel {
  final String id;
  final String plantId;
  final String unitId;
  final String coolerId;
  final String tagId;
  final String coolerType;
  final String owner;
  final String department;
  final String location;
  final String checkType; // 'Quarterly Servicing & Certification'
  final DateTime testingDate;
  final DateTime nextDueDate;
  final String quarter;
  final String status; // 'Certified', 'Not Certified'
  final String servicedBy;
  final String vendorName;
  final double? measuredTds; // in ppm (IS 10500 <= 500 ppm standard)
  final double? coldTemperature; // in Celsius (IS 14724 10-15 C)
  final double? hotTemperature; // in Celsius (80-90 C)
  final Map<String, bool> checkpoints;
  final String actionTaken;
  final String remarks;

  WaterCoolerReportModel({
    required this.id,
    required this.plantId,
    required this.unitId,
    required this.coolerId,
    required this.tagId,
    required this.coolerType,
    required this.owner,
    required this.department,
    required this.location,
    required this.checkType,
    required this.testingDate,
    required this.nextDueDate,
    required this.quarter,
    required this.status,
    required this.servicedBy,
    required this.vendorName,
    this.measuredTds,
    this.coldTemperature,
    this.hotTemperature,
    required this.checkpoints,
    this.actionTaken = '',
    this.remarks = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'plantId': plantId,
      'unitId': unitId,
      'coolerId': coolerId,
      'tagId': tagId,
      'coolerType': coolerType,
      'owner': owner,
      'department': department,
      'location': location,
      'checkType': checkType,
      'testingDate': testingDate.toIso8601String(),
      'nextDueDate': nextDueDate.toIso8601String(),
      'quarter': quarter,
      'status': status,
      'servicedBy': servicedBy,
      'vendorName': vendorName,
      'measuredTds': measuredTds,
      'coldTemperature': coldTemperature,
      'hotTemperature': hotTemperature,
      'checkpoints': checkpoints,
      'actionTaken': actionTaken,
      'remarks': remarks,
    };
  }

  factory WaterCoolerReportModel.fromMap(Map<String, dynamic> map, String docId) {
    Map<String, bool> cp = {};
    if (map['checkpoints'] != null && map['checkpoints'] is Map) {
      (map['checkpoints'] as Map).forEach((k, v) {
        cp[k.toString()] = v == true;
      });
    }

    return WaterCoolerReportModel(
      id: docId,
      plantId: map['plantId'] ?? '',
      unitId: map['unitId'] ?? '',
      coolerId: map['coolerId'] ?? '',
      tagId: map['tagId'] ?? docId,
      coolerType: map['coolerType'] ?? 'Hot & Cold Dispenser',
      owner: map['owner'] ?? 'Vedanta',
      department: map['department'] ?? 'Administration',
      location: map['location'] ?? '',
      checkType: map['checkType'] ?? 'Quarterly Servicing & Certification',
      testingDate: map['testingDate'] != null ? DateTime.tryParse(map['testingDate']) ?? DateTime.now() : DateTime.now(),
      nextDueDate: map['nextDueDate'] != null ? DateTime.tryParse(map['nextDueDate']) ?? DateTime.now().add(const Duration(days: 90)) : DateTime.now().add(const Duration(days: 90)),
      quarter: map['quarter'] ?? '',
      status: map['status'] ?? 'Not Certified',
      servicedBy: map['servicedBy'] ?? map['testedBy'] ?? 'Inspector',
      vendorName: map['vendorName'] ?? map['owner'] ?? 'Vedanta',
      measuredTds: map['measuredTds'] != null ? (map['measuredTds'] as num).toDouble() : null,
      coldTemperature: map['coldTemperature'] != null ? (map['coldTemperature'] as num).toDouble() : null,
      hotTemperature: map['hotTemperature'] != null ? (map['hotTemperature'] as num).toDouble() : null,
      checkpoints: cp,
      actionTaken: map['actionTaken'] ?? '',
      remarks: map['remarks'] ?? '',
    );
  }
}
