import 'package:cloud_firestore/cloud_firestore.dart';

class PanelRoomAuditItem {
  final String panelRoomId;
  final String panelRoomName;
  final String rubberMat;
  final String illumination;
  final String ventilation;
  final String sealing;
  final String cleaning;
  final String dangerBoard;
  final String feederNaming;
  final String pprSld;
  final String fireExtinguisher;
  final String accessControl;
  final String emergencyExit;
  final String doorInterlock;
  final String authorisedPeopleList;
  final String shockTreatmentChart;
  final String remarks;
  final Map<String, String> paramRemarks;

  PanelRoomAuditItem({
    required this.panelRoomId,
    required this.panelRoomName,
    this.rubberMat = 'OK',
    this.illumination = 'OK',
    this.ventilation = 'OK',
    this.sealing = 'OK',
    this.cleaning = 'OK',
    this.dangerBoard = 'OK',
    this.feederNaming = 'OK',
    this.pprSld = 'OK',
    this.fireExtinguisher = 'OK',
    this.accessControl = 'OK',
    this.emergencyExit = 'OK',
    this.doorInterlock = 'OK',
    this.authorisedPeopleList = 'OK',
    this.shockTreatmentChart = 'OK',
    this.remarks = '',
    this.paramRemarks = const {},
  });

  bool get isAllOk =>
      rubberMat == 'OK' &&
      illumination == 'OK' &&
      ventilation == 'OK' &&
      sealing == 'OK' &&
      cleaning == 'OK' &&
      dangerBoard == 'OK' &&
      feederNaming == 'OK' &&
      pprSld == 'OK' &&
      fireExtinguisher == 'OK' &&
      accessControl == 'OK' &&
      emergencyExit == 'OK' &&
      doorInterlock == 'OK' &&
      authorisedPeopleList == 'OK' &&
      shockTreatmentChart == 'OK';

  bool get hasDefect =>
      rubberMat == 'Not OK' ||
      illumination == 'Not OK' ||
      ventilation == 'Not OK' ||
      sealing == 'Not OK' ||
      cleaning == 'Not OK' ||
      dangerBoard == 'Not OK' ||
      feederNaming == 'Not OK' ||
      pprSld == 'Not OK' ||
      fireExtinguisher == 'Not OK' ||
      accessControl == 'Not OK' ||
      emergencyExit == 'Not OK' ||
      doorInterlock == 'Not OK' ||
      authorisedPeopleList == 'Not OK' ||
      shockTreatmentChart == 'Not OK';

  Map<String, dynamic> toMap() {
    return {
      'panelRoomId': panelRoomId,
      'panelRoomName': panelRoomName,
      'rubberMat': rubberMat,
      'illumination': illumination,
      'ventilation': ventilation,
      'sealing': sealing,
      'cleaning': cleaning,
      'dangerBoard': dangerBoard,
      'feederNaming': feederNaming,
      'pprSld': pprSld,
      'fireExtinguisher': fireExtinguisher,
      'accessControl': accessControl,
      'emergencyExit': emergencyExit,
      'doorInterlock': doorInterlock,
      'authorisedPeopleList': authorisedPeopleList,
      'shockTreatmentChart': shockTreatmentChart,
      'remarks': remarks,
      'paramRemarks': paramRemarks,
    };
  }

  factory PanelRoomAuditItem.fromMap(Map<String, dynamic> map) {
    return PanelRoomAuditItem(
      panelRoomId: map['panelRoomId'] ?? '',
      panelRoomName: map['panelRoomName'] ?? '',
      rubberMat: map['rubberMat'] ?? 'OK',
      illumination: map['illumination'] ?? 'OK',
      ventilation: map['ventilation'] ?? 'OK',
      sealing: map['sealing'] ?? 'OK',
      cleaning: map['cleaning'] ?? 'OK',
      dangerBoard: map['dangerBoard'] ?? 'OK',
      feederNaming: map['feederNaming'] ?? 'OK',
      pprSld: map['pprSld'] ?? 'OK',
      fireExtinguisher: map['fireExtinguisher'] ?? 'OK',
      accessControl: map['accessControl'] ?? 'OK',
      emergencyExit: map['emergencyExit'] ?? 'OK',
      doorInterlock: map['doorInterlock'] ?? 'OK',
      authorisedPeopleList: map['authorisedPeopleList'] ?? 'OK',
      shockTreatmentChart: map['shockTreatmentChart'] ?? 'OK',
      remarks: map['remarks'] ?? '',
      paramRemarks: Map<String, String>.from(map['paramRemarks'] ?? {}),
    );
  }

  PanelRoomAuditItem copyWith({
    String? panelRoomId,
    String? panelRoomName,
    String? rubberMat,
    String? illumination,
    String? ventilation,
    String? sealing,
    String? cleaning,
    String? dangerBoard,
    String? feederNaming,
    String? pprSld,
    String? fireExtinguisher,
    String? accessControl,
    String? emergencyExit,
    String? doorInterlock,
    String? authorisedPeopleList,
    String? shockTreatmentChart,
    String? remarks,
    Map<String, String>? paramRemarks,
  }) {
    return PanelRoomAuditItem(
      panelRoomId: panelRoomId ?? this.panelRoomId,
      panelRoomName: panelRoomName ?? this.panelRoomName,
      rubberMat: rubberMat ?? this.rubberMat,
      illumination: illumination ?? this.illumination,
      ventilation: ventilation ?? this.ventilation,
      sealing: sealing ?? this.sealing,
      cleaning: cleaning ?? this.cleaning,
      dangerBoard: dangerBoard ?? this.dangerBoard,
      feederNaming: feederNaming ?? this.feederNaming,
      pprSld: pprSld ?? this.pprSld,
      fireExtinguisher: fireExtinguisher ?? this.fireExtinguisher,
      accessControl: accessControl ?? this.accessControl,
      emergencyExit: emergencyExit ?? this.emergencyExit,
      doorInterlock: doorInterlock ?? this.doorInterlock,
      authorisedPeopleList: authorisedPeopleList ?? this.authorisedPeopleList,
      shockTreatmentChart: shockTreatmentChart ?? this.shockTreatmentChart,
      remarks: remarks ?? this.remarks,
      paramRemarks: paramRemarks ?? this.paramRemarks,
    );
  }
}

class PanelRoomChecklistReportModel {
  final String id;
  final String unitId;
  final String plantId;
  final String monthYear;
  final DateTime inspectionDate;
  final String inspectorId;
  final String inspectorName;
  final String overallStatus; // 'Pass' or 'Action Required'
  final String overallRemarks;
  final List<PanelRoomAuditItem> roomAudits;
  final DateTime createdAt;
  final String createdBy;
  final DateTime? modifiedAt;
  final String? modifiedBy;

  PanelRoomChecklistReportModel({
    required this.id,
    required this.unitId,
    required this.plantId,
    required this.monthYear,
    required this.inspectionDate,
    required this.inspectorId,
    required this.inspectorName,
    required this.overallStatus,
    this.overallRemarks = '',
    required this.roomAudits,
    required this.createdAt,
    required this.createdBy,
    this.modifiedAt,
    this.modifiedBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'unitId': unitId,
      'plantId': plantId,
      'monthYear': monthYear,
      'inspectionDate': Timestamp.fromDate(inspectionDate),
      'inspectorId': inspectorId,
      'inspectorName': inspectorName,
      'overallStatus': overallStatus,
      'overallRemarks': overallRemarks,
      'roomAudits': roomAudits.map((x) => x.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'modifiedAt': modifiedAt != null ? Timestamp.fromDate(modifiedAt!) : null,
      'modifiedBy': modifiedBy,
    };
  }

  factory PanelRoomChecklistReportModel.fromMap(Map<String, dynamic> map, String docId) {
    return PanelRoomChecklistReportModel(
      id: docId,
      unitId: map['unitId'] ?? '',
      plantId: map['plantId'] ?? '',
      monthYear: map['monthYear'] ?? '',
      inspectionDate: (map['inspectionDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      inspectorId: map['inspectorId'] ?? '',
      inspectorName: map['inspectorName'] ?? '',
      overallStatus: map['overallStatus'] ?? 'Pass',
      overallRemarks: map['overallRemarks'] ?? '',
      roomAudits: (map['roomAudits'] as List<dynamic>?)
              ?.map((e) => PanelRoomAuditItem.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['createdBy'] ?? '',
      modifiedAt: (map['modifiedAt'] as Timestamp?)?.toDate(),
      modifiedBy: map['modifiedBy'],
    );
  }
}
