// ignore_for_file: non_constant_identifier_names
import 'package:cloud_firestore/cloud_firestore.dart';

enum AssetStatus { active, spare, underMaintenance, scrapped }
enum AssetType { motor, gearbox, pump }
enum AssetHealthStatus { healthy, warning, critical, unknown }

class AssetModel {
  // Identity
  final String id;
  final String masterEquipmentId;
  final String tagNo;
  final String name;
  final String make;
  final String model;
  final String serialNo;
  final String? rfidTag;
  final String? poNo;
  final int? manufacturingYear;
  final String imageUrl;
  final String description;

  // Type & Status
  final AssetType type;
  final AssetStatus status;

  // Universal Specs (Dynamic Data for Gearboxes, Pumps etc - kept for backward compatibility)
  final Map<String, dynamic>? specs;

  // Motor Technical Specs
  final String? motorType; // e.g. SCIM, SRIM, Synchronous, DC, PMSM
  final double? powerKw;
  final double? voltage;
  final double? fullLoadCurrent; // FLC (Amps)
  final double? noLoadCurrent;
  final double? speedRpm;
  final int? poles;
  final double? frequency;
  final double? efficiency;
  final double? powerFactor;
  final String? frameSize;
  final String? mountingType;
  final String? greaseType; // Direct top level
  final String? dutyCycle; // e.g. S1, S2, Continuous
  final String? insulationClass; // e.g. Class F, Class H
  final String? couplingAvailable; // e.g. YES / NO
  final String? couplingType; // e.g. Pin-Bush, Tyre, Fluid, Gear, Rigid
  final String? efficiencyClass; // e.g. IE1, IE2, IE3, IE4
  final String? ipRating; // e.g. IP55, IP56, IP65

  // Gearbox Dynamic Specs
  final String? gearRatio;
  final String? oilType;
  final double? oilCapacity;
  final double? inputSpeedRpm;
  final double? outputSpeedRpm;
  final double? inputShaftMm;
  final double? outputShaftMm;
  final String? lubricationMethod;
  final String? mountingOrientation;

  // Pump Dynamic Specs
  final double? flowRate;
  final double? head;
  final String? impellerSize;
  final double? pumpPower;
  final double? suctionFlangeMm;
  final double? dischargeFlangeMm;
  final String? sealType;
  final String? casingMaterial;

  // Diagnostics / Health (Derived from health_logs)
  final AssetHealthStatus healthStatus;
  final DateTime? lastPulseTime;
  final Map<String, dynamic>? windingResistance;
  final Map<String, dynamic>? insulationResistance;
  final double? polarizationIndex;
  final Map<String, dynamic>? vibration;

  // Construction
  final String? bearingDE;
  final String? bearingNDE;

  // Operational Context
  final bool isCritical;
  final List<String>? applicableParentEquipmentIds;
  final String? spareLocation;
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
    
    this.specs,
    
    this.motorType,
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
    this.greaseType,
    this.dutyCycle,
    this.insulationClass,
    this.couplingAvailable,
    this.couplingType,
    this.efficiencyClass,
    this.ipRating,
    
    this.gearRatio,
    this.oilType,
    this.oilCapacity,
    this.inputSpeedRpm,
    this.outputSpeedRpm,
    this.inputShaftMm,
    this.outputShaftMm,
    this.lubricationMethod,
    this.mountingOrientation,
    
    this.flowRate,
    this.head,
    this.impellerSize,
    this.pumpPower,
    this.suctionFlangeMm,
    this.dischargeFlangeMm,
    this.sealType,
    this.casingMaterial,
    
    this.healthStatus = AssetHealthStatus.unknown,
    this.lastPulseTime,

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

    final dynamic legacySpecs = map['specs'] is Map ? Map<String, dynamic>.from(map['specs'] as Map) : null;

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
      manufacturingYear: map['manufacturingYear'] is num ? (map['manufacturingYear'] as num).toInt() : int.tryParse(map['manufacturingYear']?.toString() ?? ''),
      imageUrl: map['imageUrl'] ?? '',
      
      type: AssetType.values.firstWhere(
        (e) => e.name == (map['type'] ?? 'motor'),
        orElse: () => AssetType.motor,
      ),
      status: AssetStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'spare'),
        orElse: () => AssetStatus.spare,
      ),
      
      specs: legacySpecs,
      
      motorType: map['motorType']?.toString() ?? legacySpecs?['motorType']?.toString(),
      powerKw: (map['powerKw'] as num?)?.toDouble() ?? (legacySpecs?['pumpPower'] as num?)?.toDouble() ?? (legacySpecs?['inputPowerKw'] as num?)?.toDouble(),
      voltage: (map['voltage'] as num?)?.toDouble(),
      fullLoadCurrent: (map['fullLoadCurrent'] as num?)?.toDouble(),
      noLoadCurrent: (map['noLoadCurrent'] as num?)?.toDouble(),
      speedRpm: (map['speedRpm'] as num?)?.toDouble() ?? (legacySpecs?['pumpSpeedRpm'] as num?)?.toDouble() ?? (legacySpecs?['inputSpeedRpm'] as num?)?.toDouble(),
      poles: (map['poles'] as num?)?.toInt(),
      frequency: (map['frequency'] as num?)?.toDouble(),
      efficiency: (map['efficiency'] as num?)?.toDouble(),
      powerFactor: (map['powerFactor'] as num?)?.toDouble(),
      frameSize: map['frameSize']?.toString(),
      mountingType: map['mountingType']?.toString(),
      greaseType: map['greaseType']?.toString() ?? legacySpecs?['greaseType']?.toString(),
      dutyCycle: map['dutyCycle']?.toString() ?? legacySpecs?['dutyCycle']?.toString(),
      insulationClass: map['insulationClass']?.toString() ?? legacySpecs?['insulationClass']?.toString(),
      couplingAvailable: map['couplingAvailable']?.toString() ?? (map['isCouplingAvailable'] == true ? 'YES' : (map['isCouplingAvailable'] == false ? 'NO' : null)),
      couplingType: map['couplingType']?.toString() ?? legacySpecs?['couplingType']?.toString(),
      efficiencyClass: map['efficiencyClass']?.toString() ?? legacySpecs?['efficiencyClass']?.toString(),
      ipRating: map['ipRating']?.toString() ?? legacySpecs?['ipRating']?.toString(),
      
      gearRatio: map['gearRatio']?.toString() ?? legacySpecs?['gearRatio']?.toString(),
      oilType: map['oilType']?.toString() ?? legacySpecs?['oilType']?.toString(),
      oilCapacity: (map['oilCapacity'] as num?)?.toDouble() ?? (legacySpecs?['oilCapacity'] as num?)?.toDouble(),
      inputSpeedRpm: (map['inputSpeedRpm'] as num?)?.toDouble() ?? (legacySpecs?['inputSpeedRpm'] as num?)?.toDouble(),
      outputSpeedRpm: (map['outputSpeedRpm'] as num?)?.toDouble() ?? (legacySpecs?['outputSpeedRpm'] as num?)?.toDouble(),
      inputShaftMm: (map['inputShaftMm'] as num?)?.toDouble() ?? (legacySpecs?['inputShaftMm'] as num?)?.toDouble(),
      outputShaftMm: (map['outputShaftMm'] as num?)?.toDouble() ?? (legacySpecs?['outputShaftMm'] as num?)?.toDouble(),
      lubricationMethod: map['lubricationMethod']?.toString() ?? legacySpecs?['lubricationMethod']?.toString(),
      mountingOrientation: map['mountingOrientation']?.toString() ?? legacySpecs?['mountingOrientation']?.toString(),
      
      flowRate: (map['flowRate'] as num?)?.toDouble() ?? (legacySpecs?['flowRate'] as num?)?.toDouble(),
      head: (map['head'] as num?)?.toDouble() ?? (legacySpecs?['head'] as num?)?.toDouble(),
      impellerSize: map['impellerSize']?.toString() ?? legacySpecs?['impellerSize']?.toString(),
      pumpPower: (map['pumpPower'] as num?)?.toDouble() ?? (legacySpecs?['pumpPower'] as num?)?.toDouble(),
      suctionFlangeMm: (map['suctionFlangeMm'] as num?)?.toDouble() ?? (legacySpecs?['suctionFlangeMm'] as num?)?.toDouble(),
      dischargeFlangeMm: (map['dischargeFlangeMm'] as num?)?.toDouble() ?? (legacySpecs?['dischargeFlangeMm'] as num?)?.toDouble(),
      sealType: map['sealType']?.toString() ?? legacySpecs?['sealType']?.toString(),
      casingMaterial: map['casingMaterial']?.toString() ?? legacySpecs?['casingMaterial']?.toString(),
      
      healthStatus: AssetHealthStatus.values.firstWhere(
        (e) => e.name == (map['healthStatus'] ?? 'unknown'),
        orElse: () => AssetHealthStatus.unknown,
      ),
      lastPulseTime: _parseDate(map['lastPulseTime']),

      windingResistance: map['windingResistance'] as Map<String, dynamic>?,
      insulationResistance: map['insulationResistance'] as Map<String, dynamic>?,
      polarizationIndex: (map['polarizationIndex'] as num?)?.toDouble(),
      vibration: map['vibration'] as Map<String, dynamic>?,
      
      bearingDE: map['bearingDE']?.toString(),
      bearingNDE: map['bearingNDE']?.toString(),
      
      isCritical: map['isCritical'] ?? false,
      applicableParentEquipmentIds: parents,
      spareLocation: map['spareLocation'] as String?,
      seqNo: map['seqNo']?.toString(),
      
      installationDate: _parseDate(map['installationDate']),
      lastServiceDate: _parseDate(map['lastServiceDate']),
      nextServiceDue: _parseDate(map['nextServiceDue']),
      createdAt: _parseDate(map['createdAt']),
      createdBy: map['createdBy'],
      modifiedAt: _parseDate(map['modifiedAt']) ?? _parseDate(map['updatedAt']),
      modifiedBy: map['modifiedBy'],
    );
  }

  static DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is String && val.isNotEmpty) return DateTime.tryParse(val);
    return null;
  }

  /// Dynamic display name derived from nameplate specs or tag if name is omitted
  String get displayName {
    if (name.trim().isNotEmpty && name.trim() != tagNo.trim()) {
      return name.trim();
    }
    if (type == AssetType.motor) {
      final pwr = powerKw != null ? '${powerKw}kW ' : '';
      final mType = (motorType != null && motorType!.isNotEmpty) ? motorType! : 'Induction Motor';
      final mk = make.isNotEmpty ? ' ($make)' : '';
      return '$pwr$mType$mk'.trim();
    } else if (type == AssetType.gearbox) {
      final ratio = (gearRatio != null && gearRatio!.isNotEmpty) ? ' (i=$gearRatio)' : '';
      final mk = make.isNotEmpty ? ' $make' : '';
      return 'Gearbox$mk$ratio'.trim();
    } else if (type == AssetType.pump) {
      final flw = flowRate != null ? ' (${flowRate}m³/h)' : '';
      final mk = make.isNotEmpty ? ' $make' : '';
      return 'Pump$mk$flw'.trim();
    }
    return tagNo;
  }

  /// Compact technical summary line for cards and listings
  String get technicalSummary {
    if (type == AssetType.motor) {
      final parts = <String>[];
      if (powerKw != null) parts.add('${powerKw}kW');
      if (speedRpm != null) parts.add('${speedRpm!.toStringAsFixed(0)} RPM');
      if (voltage != null) parts.add('${voltage!.toStringAsFixed(0)}V');
      if (frameSize != null && frameSize!.isNotEmpty) parts.add(frameSize!);
      if (dutyCycle != null && dutyCycle!.isNotEmpty) parts.add(dutyCycle!.split(' ').first);
      return parts.isNotEmpty ? parts.join(' • ') : 'Motor Specs Pending';
    } else if (type == AssetType.gearbox) {
      final parts = <String>[];
      if (gearRatio != null && gearRatio!.isNotEmpty) parts.add('Ratio $gearRatio');
      if (oilType != null && oilType!.isNotEmpty) parts.add(oilType!);
      if (inputSpeedRpm != null) parts.add('In: ${inputSpeedRpm!.toStringAsFixed(0)} RPM');
      return parts.isNotEmpty ? parts.join(' • ') : 'Gearbox Specs Pending';
    } else if (type == AssetType.pump) {
      final parts = <String>[];
      if (flowRate != null) parts.add('${flowRate}m³/h');
      if (head != null) parts.add('${head}m Head');
      if (casingMaterial != null && casingMaterial!.isNotEmpty) parts.add(casingMaterial!);
      return parts.isNotEmpty ? parts.join(' • ') : 'Pump Specs Pending';
    }
    return tagNo;
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'masterEquipmentId': masterEquipmentId,
      'tagNo': tagNo,
      'name': name.trim().isNotEmpty ? name.trim() : displayName,
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

    // Direct Motor Specs
    if (motorType != null && motorType!.isNotEmpty) map['motorType'] = motorType;
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
    if (greaseType != null && greaseType!.isNotEmpty) map['greaseType'] = greaseType;
    if (dutyCycle != null && dutyCycle!.isNotEmpty) map['dutyCycle'] = dutyCycle;
    if (insulationClass != null && insulationClass!.isNotEmpty) map['insulationClass'] = insulationClass;
    if (couplingAvailable != null && couplingAvailable!.isNotEmpty) map['couplingAvailable'] = couplingAvailable;
    if (couplingType != null && couplingType!.isNotEmpty) map['couplingType'] = couplingType;
    if (efficiencyClass != null && efficiencyClass!.isNotEmpty) map['efficiencyClass'] = efficiencyClass;
    if (ipRating != null && ipRating!.isNotEmpty) map['ipRating'] = ipRating;

    // Direct Gearbox Specs
    if (gearRatio != null && gearRatio!.isNotEmpty) map['gearRatio'] = gearRatio;
    if (oilType != null && oilType!.isNotEmpty) map['oilType'] = oilType;
    if (oilCapacity != null) map['oilCapacity'] = oilCapacity;
    if (inputSpeedRpm != null) map['inputSpeedRpm'] = inputSpeedRpm;
    if (outputSpeedRpm != null) map['outputSpeedRpm'] = outputSpeedRpm;
    if (inputShaftMm != null) map['inputShaftMm'] = inputShaftMm;
    if (outputShaftMm != null) map['outputShaftMm'] = outputShaftMm;
    if (lubricationMethod != null && lubricationMethod!.isNotEmpty) map['lubricationMethod'] = lubricationMethod;
    if (mountingOrientation != null && mountingOrientation!.isNotEmpty) map['mountingOrientation'] = mountingOrientation;

    // Direct Pump Specs
    if (flowRate != null) map['flowRate'] = flowRate;
    if (head != null) map['head'] = head;
    if (impellerSize != null && impellerSize!.isNotEmpty) map['impellerSize'] = impellerSize;
    if (pumpPower != null) map['pumpPower'] = pumpPower;
    if (suctionFlangeMm != null) map['suctionFlangeMm'] = suctionFlangeMm;
    if (dischargeFlangeMm != null) map['dischargeFlangeMm'] = dischargeFlangeMm;
    if (sealType != null && sealType!.isNotEmpty) map['sealType'] = sealType;
    if (casingMaterial != null && casingMaterial!.isNotEmpty) map['casingMaterial'] = casingMaterial;

    // Mechanical
    if (bearingDE != null && bearingDE!.isNotEmpty) map['bearingDE'] = bearingDE;
    if (bearingNDE != null && bearingNDE!.isNotEmpty) map['bearingNDE'] = bearingNDE;

    // Operational Context
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
