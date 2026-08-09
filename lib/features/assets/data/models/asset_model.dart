// ignore_for_file: non_constant_identifier_names
import 'package:cloud_firestore/cloud_firestore.dart';

enum AssetStatus { active, spare, underMaintenance, scrapped }
enum AssetType { motor, gearbox, pump }
enum AssetHealthStatus { healthy, warning, critical, unknown } // NEW

class AssetModel {
  // Identity
  final String id;
  final String masterEquipmentId; // The single source of context (instead of Unit/Plant/Location)
  final String tagNo;
  final String name;
  final String make;
  final String model;
  final String serialNo;
  final String? rfidTag;
  final String? poNo; // NEW: Purchase Order No
  final int? manufacturingYear;
  final String imageUrl;
  final String description; // NEW: Standard Audit

  // Type & Status
  final AssetType type;
  final AssetStatus status;

  // Universal Specs (Dynamic Data for Gearboxes, Pumps etc)
  final Map<String, dynamic>? specs; // NEW

  // Technical Specs (Motor Specific - Kept for backward compat & strong typing)
  final double? powerKw;
  final double? voltage; // Input/Rated Voltage
  final double? fullLoadCurrent; // FLA / Output Current
  final double? noLoadCurrent;
  final double? speedRpm;
  final int? poles;
  final double? frequency;
  final double? efficiency;
  final double? powerFactor;
  final String? frameSize;
  final String? mountingType;

  // Diagnostics / Health
  final AssetHealthStatus healthStatus; // NEW
  final DateTime? lastPulseTime; // NEW
  final Map<String, dynamic>? windingResistance;
  final Map<String, dynamic>? insulationResistance; // Extended: R-Y, Y-B, B-R, R-E, Y-E, B-E
  final double? polarizationIndex;
  
  // Vibration
  final Map<String, dynamic>? vibration; // { "DE_H": 2.1, "DE_V": 1.5, "DE_A": 0.8, "NDE_H": 1.9 ... "G_Value": 0.5 }

  // Construction
  final String? bearingDE;
  final String? bearingNDE;

  // Operational Context
  final bool isCritical;
  final List<String>? applicableParentEquipmentIds; // Multiple parent equipments for spares
  final String? spareLocation; // Storage location when asset is a spare
  final String? seqNo;
  
  // Lifecycle
  final DateTime? installationDate;
  final DateTime? lastServiceDate;
  final DateTime? nextServiceDue;

  // Standard Audit Fields
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? modifiedAt;
  final String? modifiedBy;

  AssetModel({
    required this.id,
    required this.masterEquipmentId,
    required this.tagNo,
    required this.name,
    this.description = '',
    required this.make,
    required this.model,
    required this.serialNo,
    this.rfidTag,
    this.poNo,
    this.manufacturingYear,
    required this.imageUrl,
    
    required this.type,
    required this.status,
    
    this.specs, // NEW
    
    this.powerKw,
    this.voltage,
    this.fullLoadCurrent,
    this.noLoadCurrent,
    this.speedRpm,
    this.poles,
    this.frequency,
    this.efficiency,
    this.powerFactor,
    this.frameSize,
    this.mountingType,
    
    this.healthStatus = AssetHealthStatus.unknown, // NEW
    this.lastPulseTime, // NEW

    this.windingResistance,
    this.insulationResistance,
    this.polarizationIndex,
    this.vibration,
    
    this.bearingDE,
    this.bearingNDE,
    
    this.isCritical = false,
    this.applicableParentEquipmentIds,
    this.spareLocation,
    this.seqNo,
    
    this.installationDate,
    this.lastServiceDate,
    this.nextServiceDue,
    this.createdAt,
    this.createdBy,
    this.modifiedAt,
    this.modifiedBy,
  });

  // Factory to create AssetModel from Firestore Map
  factory AssetModel.fromMap(Map<String, dynamic> map, String docId) {
    final rawParents = map['applicableParentEquipmentIds'];
    List<String>? parents;
    if (rawParents is List) {
      parents = rawParents.map((e) => e.toString()).toList();
    }

    return AssetModel(
      id: docId,
      masterEquipmentId: map['masterEquipmentId'] ?? '',
      tagNo: map['tagNo'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      make: map['make'] ?? '',
      model: map['model'] ?? '',
      serialNo: map['serialNo'] ?? '',
      rfidTag: map['rfidTag'],
      poNo: map['poNo'],
      manufacturingYear: map['manufacturingYear'],
      imageUrl: map['imageUrl'] ?? '',
      
      type: AssetType.values.firstWhere(
        (e) => e.name == (map['type'] ?? 'motor'),
        orElse: () => AssetType.motor,
      ),
      status: AssetStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'spare'),
        orElse: () => AssetStatus.spare,
      ),
      
      specs: map['specs'] as Map<String, dynamic>?, // NEW
      
      powerKw: (map['powerKw'] as num?)?.toDouble(),
      voltage: (map['voltage'] as num?)?.toDouble(),
      fullLoadCurrent: (map['fullLoadCurrent'] as num?)?.toDouble(),
      noLoadCurrent: (map['noLoadCurrent'] as num?)?.toDouble(),
      speedRpm: (map['speedRpm'] as num?)?.toDouble(),
      poles: map['poles'] as int?,
      frequency: (map['frequency'] as num?)?.toDouble(),
      efficiency: (map['efficiency'] as num?)?.toDouble(),
      powerFactor: (map['powerFactor'] as num?)?.toDouble(),
      frameSize: map['frameSize'],
      mountingType: map['mountingType'],
      
      healthStatus: AssetHealthStatus.values.firstWhere( // NEW
        (e) => e.name == (map['healthStatus'] ?? 'unknown'),
        orElse: () => AssetHealthStatus.unknown,
      ),
      lastPulseTime: (map['lastPulseTime'] as dynamic)?.toDate(), // NEW

      windingResistance: map['windingResistance'] as Map<String, dynamic>?,
      insulationResistance: map['insulationResistance'] as Map<String, dynamic>?,
      polarizationIndex: (map['polarizationIndex'] as num?)?.toDouble(),
      vibration: map['vibration'] as Map<String, dynamic>?,
      
      bearingDE: map['bearingDE'],
      bearingNDE: map['bearingNDE'],
      
      isCritical: map['isCritical'] ?? false,
      applicableParentEquipmentIds: parents,
      spareLocation: map['spareLocation'] as String?,
      seqNo: map['seqNo']?.toString(),
      
      installationDate: (map['installationDate'] as dynamic)?.toDate(),
      lastServiceDate: (map['lastServiceDate'] as dynamic)?.toDate(),
      nextServiceDue: (map['nextServiceDue'] as dynamic)?.toDate(),
      createdAt: (map['createdAt'] as dynamic)?.toDate(),
      createdBy: map['createdBy'],
      modifiedAt: (map['modifiedAt'] as dynamic)?.toDate() ?? (map['updatedAt'] as dynamic)?.toDate(), // fallback to old updatedAt
      modifiedBy: map['modifiedBy'],
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'masterEquipmentId': masterEquipmentId,
      'tagNo': tagNo,
      'name': name,
      'type': type.name,
      'status': status.name,
      'isCritical': isCritical,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'modifiedAt': modifiedAt ?? FieldValue.serverTimestamp(),
    };

    if (make.isNotEmpty) map['make'] = make;
    if (model.isNotEmpty) map['model'] = model;
    if (serialNo.isNotEmpty) map['serialNo'] = serialNo;
    if (rfidTag != null && rfidTag!.isNotEmpty) map['rfidTag'] = rfidTag;
    if (poNo != null && poNo!.isNotEmpty) map['poNo'] = poNo;
    if (manufacturingYear != null) map['manufacturingYear'] = manufacturingYear;
    if (imageUrl.isNotEmpty) map['imageUrl'] = imageUrl;
    if (description.isNotEmpty) map['description'] = description;

    if (healthStatus != AssetHealthStatus.unknown) {
      map['healthStatus'] = healthStatus.name;
    }

    if (specs != null && specs!.isNotEmpty) map['specs'] = specs;
    if (powerKw != null) map['powerKw'] = powerKw;
    if (voltage != null) map['voltage'] = voltage;
    if (fullLoadCurrent != null) map['fullLoadCurrent'] = fullLoadCurrent;
    if (noLoadCurrent != null) map['noLoadCurrent'] = noLoadCurrent;
    if (speedRpm != null) map['speedRpm'] = speedRpm;
    if (poles != null) map['poles'] = poles;
    if (frequency != null) map['frequency'] = frequency;
    if (efficiency != null) map['efficiency'] = efficiency;
    if (powerFactor != null) map['powerFactor'] = powerFactor;
    if (frameSize != null && frameSize!.isNotEmpty) map['frameSize'] = frameSize;
    if (mountingType != null && mountingType!.isNotEmpty) map['mountingType'] = mountingType;

    if (bearingDE != null && bearingDE!.isNotEmpty) map['bearingDE'] = bearingDE;
    if (bearingNDE != null && bearingNDE!.isNotEmpty) map['bearingNDE'] = bearingNDE;

    if (applicableParentEquipmentIds != null && applicableParentEquipmentIds!.isNotEmpty) {
      map['applicableParentEquipmentIds'] = applicableParentEquipmentIds;
    }
    if (spareLocation != null && spareLocation!.isNotEmpty) {
      map['spareLocation'] = spareLocation;
    }
    if (seqNo != null && seqNo!.isNotEmpty) {
      map['seqNo'] = seqNo;
    }

    if (installationDate != null) map['installationDate'] = installationDate;
    if (lastServiceDate != null) map['lastServiceDate'] = lastServiceDate;
    if (nextServiceDue != null) map['nextServiceDue'] = nextServiceDue;
    if (createdBy != null && createdBy!.isNotEmpty) map['createdBy'] = createdBy;
    if (modifiedBy != null && modifiedBy!.isNotEmpty) map['modifiedBy'] = modifiedBy;

    return map;
  }
}
