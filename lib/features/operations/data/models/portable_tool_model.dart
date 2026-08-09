class PortableToolModel {
  final String id;
  final String plantId;
  final String unitId;
  final String tagId; // PLANT-UNIT-EQ-OWN-DPT-NO e.g. IOG-COD-WM-VED-ELE-001
  final String equipmentType;
  final String owner;
  final String department;
  final String seqNo;
  final String location;
  final String status; // 'Certified', 'Not Certified', 'Expired', 'Never Tested'
  final DateTime? lastTestingDate;
  final DateTime? nextDueDate;
  final String currentQuarter;
  final String remarks;
  final DateTime createdAt;
  final DateTime updatedAt;

  PortableToolModel({
    required this.id,
    required this.plantId,
    required this.unitId,
    required this.tagId,
    required this.equipmentType,
    required this.owner,
    required this.department,
    this.seqNo = '001',
    this.location = '',
    this.status = 'Never Tested',
    this.lastTestingDate,
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
      'equipmentType': equipmentType,
      'owner': owner,
      'department': department,
      'seqNo': seqNo,
      'location': location,
      'status': status,
      'lastTestingDate': lastTestingDate?.toIso8601String(),
      'nextDueDate': nextDueDate?.toIso8601String(),
      'currentQuarter': currentQuarter,
      'remarks': remarks,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory PortableToolModel.fromMap(Map<String, dynamic> map, String docId) {
    return PortableToolModel(
      id: docId,
      plantId: map['plantId'] ?? '',
      unitId: map['unitId'] ?? '',
      tagId: map['tagId'] ?? docId,
      equipmentType: map['equipmentType'] ?? '',
      owner: map['owner'] ?? '',
      department: map['department'] ?? '',
      seqNo: map['seqNo'] ?? '001',
      location: map['location'] ?? '',
      status: map['status'] ?? 'Never Tested',
      lastTestingDate: map['lastTestingDate'] != null
          ? DateTime.tryParse(map['lastTestingDate'])
          : null,
      nextDueDate: map['nextDueDate'] != null
          ? DateTime.tryParse(map['nextDueDate'])
          : null,
      currentQuarter: map['currentQuarter'] ?? '',
      remarks: map['remarks'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
    );
  }
}

class PortableToolChecklistReportModel {
  final String id;
  final String plantId;
  final String unitId;
  final String toolId;
  final String tagId;
  final String equipmentType;
  final String owner;
  final String department;
  final String location;
  final String checkType; // 'Quarterly Certification', 'Routine', 'Re-certification'
  final DateTime testingDate; // Checklist done date
  final DateTime nextDueDate; // testingDate + 90 days
  final String quarter; // For quarter e.g. '2026-Q3'
  final String status; // 'Certified' or 'Not Certified'
  final String testedBy; // Checklist done by
  final String contractorName;
  final double? leakageVoltage;
  final Map<String, bool> checkpoints;
  final String actionTaken;
  final String remarks;

  PortableToolChecklistReportModel({
    required this.id,
    required this.plantId,
    required this.unitId,
    required this.toolId,
    required this.tagId,
    required this.equipmentType,
    required this.owner,
    required this.department,
    this.location = '',
    this.checkType = 'Quarterly Certification',
    required this.testingDate,
    required this.nextDueDate,
    required this.quarter,
    required this.status,
    required this.testedBy,
    required this.contractorName,
    this.leakageVoltage,
    required this.checkpoints,
    this.actionTaken = '',
    this.remarks = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'plantId': plantId,
      'unitId': unitId,
      'toolId': toolId,
      'tagId': tagId,
      'equipmentType': equipmentType,
      'owner': owner,
      'department': department,
      'location': location,
      'checkType': checkType,
      'testingDate': testingDate.toIso8601String(),
      'nextDueDate': nextDueDate.toIso8601String(),
      'quarter': quarter,
      'status': status,
      'testedBy': testedBy,
      'contractorName': contractorName,
      'leakageVoltage': leakageVoltage,
      'checkpoints': checkpoints,
      'actionTaken': actionTaken,
      'remarks': remarks,
    };
  }

  factory PortableToolChecklistReportModel.fromMap(
      Map<String, dynamic> map, String docId) {
    Map<String, bool> parsedCheckpoints = {};
    if (map['checkpoints'] != null && map['checkpoints'] is Map) {
      (map['checkpoints'] as Map).forEach((key, value) {
        parsedCheckpoints[key.toString()] = value == true;
      });
    }

    return PortableToolChecklistReportModel(
      id: docId,
      plantId: map['plantId'] ?? '',
      unitId: map['unitId'] ?? '',
      toolId: map['toolId'] ?? '',
      tagId: map['tagId'] ?? '',
      equipmentType: map['equipmentType'] ?? '',
      owner: map['owner'] ?? '',
      department: map['department'] ?? '',
      location: map['location'] ?? '',
      checkType: map['checkType'] ?? 'Quarterly Certification',
      testingDate: map['testingDate'] != null
          ? DateTime.parse(map['testingDate'])
          : DateTime.now(),
      nextDueDate: map['nextDueDate'] != null
          ? DateTime.parse(map['nextDueDate'])
          : DateTime.now().add(const Duration(days: 90)),
      quarter: map['quarter'] ?? '',
      status: map['status'] ?? 'Not Certified',
      testedBy: map['testedBy'] ?? '',
      contractorName: map['contractorName'] ?? '',
      leakageVoltage: map['leakageVoltage'] != null
          ? (map['leakageVoltage'] as num).toDouble()
          : null,
      checkpoints: parsedCheckpoints,
      actionTaken: map['actionTaken'] ?? '',
      remarks: map['remarks'] ?? '',
    );
  }
}
