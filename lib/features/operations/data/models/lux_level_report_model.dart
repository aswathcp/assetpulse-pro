class LuxLevelReportModel {
  final String id;
  final String plantId;
  final String unitId;
  final String locationId; // ID from lux_locations collection
  final String locationName;
  final String locationType;
  final String category; // Category 1 to 8
  final String tableRef; // e.g. 'IS 3646 Table 30.2'
  final int lowLux;
  final int midLux;
  final int highLux;
  final double targetUniformity;
  final int benchmarkRa;
  final int benchmarkRUG;
  final String planeHeight;
  final int referenceLux; // Base Target Lux (midLux)
  final int measuredLux; // Average Lux rounded to nearest int
  final String status; // 'Pass' or 'Fail'
  final String rangeTag; // 'High Range (Superior)', 'Mid Range (Optimal)', 'Low Range (Acceptable)', 'Below Standard'
  final String testedBy;
  final DateTime testingDate;
  final String remarks;

  // Visual Inspection Checkpoints
  final bool isLuminaireClean;
  final bool isGlareShielded;
  final bool isFlickerFree;

  // Grid & Uniformity Fields
  final List<int> gridReadings; // 9 readings in 3x3 layout
  final double averageLux;
  final double uniformityRatio;
  final String compassOrientation; // 'North-Up', 'East-Up', etc.

  // Retest & Closed-Loop Corrective Action Fields
  final String checkType; // 'Routine' or 'Retest'
  final String actionTaken; // Corrective action taken before retest

  LuxLevelReportModel({
    required this.id,
    required this.plantId,
    required this.unitId,
    required this.locationId,
    required this.locationName,
    required this.locationType,
    this.category = 'General Industrial',
    this.tableRef = 'IS 3646',
    this.lowLux = 100,
    this.midLux = 150,
    this.highLux = 200,
    this.targetUniformity = 0.40,
    this.benchmarkRa = 70,
    this.benchmarkRUG = 25,
    this.planeHeight = 'Floor level (0.0 m)',
    required this.referenceLux,
    required this.measuredLux,
    required this.status,
    this.rangeTag = 'Mid Range (Optimal)',
    required this.testedBy,
    required this.testingDate,
    required this.remarks,
    this.isLuminaireClean = true,
    this.isGlareShielded = true,
    this.isFlickerFree = true,
    required this.gridReadings,
    required this.averageLux,
    required this.uniformityRatio,
    required this.compassOrientation,
    this.checkType = 'Routine',
    this.actionTaken = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'plantId': plantId,
      'unitId': unitId,
      'locationId': locationId,
      'locationName': locationName,
      'locationType': locationType,
      'category': category,
      'tableRef': tableRef,
      'lowLux': lowLux,
      'midLux': midLux,
      'highLux': highLux,
      'targetUniformity': targetUniformity,
      'benchmarkRa': benchmarkRa,
      'benchmarkRUG': benchmarkRUG,
      'planeHeight': planeHeight,
      'referenceLux': referenceLux,
      'measuredLux': measuredLux,
      'status': status,
      'rangeTag': rangeTag,
      'testedBy': testedBy,
      'testingDate': testingDate.toIso8601String(),
      'remarks': remarks,
      'isLuminaireClean': isLuminaireClean,
      'isGlareShielded': isGlareShielded,
      'isFlickerFree': isFlickerFree,
      'gridReadings': gridReadings,
      'averageLux': averageLux,
      'uniformityRatio': uniformityRatio,
      'compassOrientation': compassOrientation,
      'checkType': checkType,
      'actionTaken': actionTaken,
    };
  }

  factory LuxLevelReportModel.fromMap(Map<String, dynamic> map, String docId) {
    // Safely parse gridReadings
    List<int> readings = [];
    if (map['gridReadings'] != null) {
      readings = List<num>.from(map['gridReadings']).map((e) => e.toInt()).toList();
    } else {
      final singleMeas = (map['measuredLux'] as num? ?? 0).toInt();
      readings = List<int>.filled(9, singleMeas);
    }

    final double avg = (map['averageLux'] as num? ?? (map['measuredLux'] as num? ?? 0.0)).toDouble();
    final double unif = (map['uniformityRatio'] as num? ?? 1.0).toDouble();

    return LuxLevelReportModel(
      id: docId,
      plantId: map['plantId'] ?? '',
      unitId: map['unitId'] ?? '',
      locationId: map['locationId'] ?? '',
      locationName: map['locationName'] ?? '',
      locationType: map['locationType'] ?? '',
      category: map['category'] ?? 'General Industrial',
      tableRef: map['tableRef'] ?? 'IS 3646',
      lowLux: (map['lowLux'] as num? ?? 100).toInt(),
      midLux: (map['midLux'] as num? ?? 150).toInt(),
      highLux: (map['highLux'] as num? ?? 200).toInt(),
      targetUniformity: (map['targetUniformity'] as num? ?? 0.40).toDouble(),
      benchmarkRa: (map['benchmarkRa'] as num? ?? 70).toInt(),
      benchmarkRUG: (map['benchmarkRUG'] as num? ?? 25).toInt(),
      planeHeight: map['planeHeight'] ?? 'Floor level (0.0 m)',
      referenceLux: (map['referenceLux'] as num? ?? 150).toInt(),
      measuredLux: (map['measuredLux'] as num? ?? 0).toInt(),
      status: map['status'] ?? 'Fail',
      rangeTag: map['rangeTag'] ?? 'Mid Range (Optimal)',
      testedBy: map['testedBy'] ?? '',
      testingDate: map['testingDate'] != null
          ? DateTime.parse(map['testingDate'])
          : DateTime.now(),
      remarks: map['remarks'] ?? '',
      isLuminaireClean: map['isLuminaireClean'] ?? true,
      isGlareShielded: map['isGlareShielded'] ?? true,
      isFlickerFree: map['isFlickerFree'] ?? true,
      gridReadings: readings,
      averageLux: avg,
      uniformityRatio: unif,
      compassOrientation: map['compassOrientation'] ?? 'North-Up',
      checkType: map['checkType'] ?? 'Routine',
      actionTaken: map['actionTaken'] ?? '',
    );
  }
}
