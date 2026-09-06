// ignore_for_file: non_constant_identifier_names
import 'package:cloud_firestore/cloud_firestore.dart';

enum AssetStatus { active, spare, underMaintenance, scrapped }
enum AssetType { motor, gearbox, pump, brake, actuator }
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

  // Brake Technical Specs (Electromagnetic DC / Electro-Hydraulic AC Thruster EHT)
  final String? brakeType; // e.g. Electromagnetic (DC), Thruster (AC) / EHT
  final double? thrusterCapacityKg; // e.g. 18kg, 34kg, 50kg
  final String? voltageType; // AC / DC
  final double? voltageRating; // e.g. 110, 415, 190
  final double? drumDiaMm; // e.g. 100, 160, 200, 250, 300, 400
  final double? drumWidthMm; // e.g. 80, 100, 120, 130, 150, 190
  final String? drumInstallation; // e.g. 1-M 1-GB, GB, M, Motor Shaft
  final String? mountingBoltSize; // e.g. M10, M12, M16
  final int? mountingBoltCount; // e.g. 4, 6, 8
  final double? mountingLengthMm; // e.g. 210, 350, 490, 680, 855
  final double? mountingWidthMm; // e.g. 60, 65, 68, 100, 120, 165
  final double? brakingTorqueNm;
  final String? brakeShoeLining;

  // Actuator Technical Specs (Electric / Pneumatic / Hydraulic)
  final String? actuatorType; // e.g. Electric Multi-Turn, Electric Quarter-Turn, Pneumatic Cylinder, Hydraulic Actuator
  final double? torqueOrThrust; // Output Torque (Nm) or Thrust (kN)
  final double? operatingTimeSeconds;
  final String? controlSignal; // e.g. 4-20mA Modulating, ON-OFF (24VDC), Profibus DP
  final String? valveFlangeStandard; // e.g. ISO 5211 (F10/F12), ISO 5210
  final String? valveType; // e.g. Butterfly, Gate, Ball, Damper
  final String? valveSize; // e.g. DN 200 / 8"

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

    this.brakeType,
    this.thrusterCapacityKg,
    this.voltageType,
    this.voltageRating,
    this.drumDiaMm,
    this.drumWidthMm,
    this.drumInstallation,
    this.mountingBoltSize,
    this.mountingBoltCount,
    this.mountingLengthMm,
    this.mountingWidthMm,
    this.brakingTorqueNm,
    this.brakeShoeLining,

    this.actuatorType,
    this.torqueOrThrust,
    this.operatingTimeSeconds,
    this.controlSignal,
    this.valveFlangeStandard,
    this.valveType,
    this.valveSize,
    
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
    final rawParents = map['applicableParentEquipmentIds'] ?? map['compatibleEquipments'];
    List<String>? parents;
    if (rawParents is List) {
      parents = rawParents.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    } else if (rawParents is String && rawParents.isNotEmpty) {
      parents = rawParents.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    final dynamic legacySpecs = map['specs'] is Map ? Map<String, dynamic>.from(map['specs'] as Map) : null;

    final parentEq = map['masterEquipmentId']?.toString() ??
        map['parentEquipment']?.toString() ??
        map['installedMachine']?.toString() ?? '';

    final tag = map['tagNo']?.toString() ?? map['tagId']?.toString() ?? docId;

    return AssetModel(
      id: docId,
      masterEquipmentId: parentEq,
      tagNo: tag,
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      make: map['make']?.toString() ?? '',
      model: map['model']?.toString() ?? '',
      serialNo: map['serialNo']?.toString() ?? '',
      rfidTag: map['rfidTag']?.toString(),
      poNo: map['poNo']?.toString(),
      manufacturingYear: _parseInt(map['manufacturingYear']) ?? _parseInt(map['yearOfManufacture']),
      imageUrl: map['imageUrl']?.toString() ?? '',
      
      type: () {
        final t = (map['type'] ?? 'motor').toString().toLowerCase().trim();
        if (t.contains('gear')) return AssetType.gearbox;
        if (t.contains('pump')) return AssetType.pump;
        if (t.contains('brake')) return AssetType.brake;
        if (t.contains('actuat')) return AssetType.actuator;
        return AssetType.motor;
      }(),
      status: () {
        final s = (map['status'] ?? 'active').toString().toLowerCase().trim();
        if (s.contains('active')) return AssetStatus.active;
        if (s.contains('maint')) return AssetStatus.underMaintenance;
        if (s.contains('scrap')) return AssetStatus.scrapped;
        return AssetStatus.spare;
      }(),
      
      specs: legacySpecs,
      
      // Motor Specs
      motorType: map['motorType']?.toString() ?? legacySpecs?['motorType']?.toString(),
      powerKw: _parseDouble(map['powerKw']) ?? _parseDouble(legacySpecs?['pumpPower']) ?? _parseDouble(legacySpecs?['inputPowerKw']),
      voltage: _parseDouble(map['voltage']) ?? _parseDouble(map['supplyVoltage']),
      fullLoadCurrent: _parseDouble(map['fullLoadCurrent']) ?? _parseDouble(map['ratedCurrent']),
      noLoadCurrent: _parseDouble(map['noLoadCurrent']),
      speedRpm: _parseDouble(map['speedRpm']) ?? _parseDouble(legacySpecs?['pumpSpeedRpm']) ?? _parseDouble(legacySpecs?['inputSpeedRpm']),
      poles: _parseInt(map['poles']),
      frequency: _parseDouble(map['frequency']),
      efficiency: _parseDouble(map['efficiency']),
      powerFactor: _parseDouble(map['powerFactor']),
      frameSize: map['frameSize']?.toString(),
      mountingType: map['mountingType']?.toString(),
      greaseType: map['greaseType']?.toString() ?? map['greaseGrade']?.toString() ?? map['oilGreaseGrade']?.toString() ?? legacySpecs?['greaseType']?.toString(),
      dutyCycle: map['dutyCycle']?.toString() ?? legacySpecs?['dutyCycle']?.toString(),
      insulationClass: map['insulationClass']?.toString() ?? legacySpecs?['insulationClass']?.toString(),
      couplingAvailable: map['couplingAvailable']?.toString() ?? (map['isCouplingAvailable'] == true ? 'YES' : (map['isCouplingAvailable'] == false ? 'NO' : null)),
      couplingType: map['couplingType']?.toString() ?? legacySpecs?['couplingType']?.toString(),
      efficiencyClass: map['efficiencyClass']?.toString() ?? legacySpecs?['efficiencyClass']?.toString(),
      ipRating: map['ipRating']?.toString() ?? map['enclosureRating']?.toString() ?? legacySpecs?['ipRating']?.toString(),
      
      // Gearbox Specs
      gearRatio: map['gearRatio']?.toString() ?? map['ratio']?.toString() ?? legacySpecs?['gearRatio']?.toString(),
      oilType: map['oilType']?.toString() ?? map['oilGrade']?.toString() ?? legacySpecs?['oilType']?.toString(),
      oilCapacity: _parseDouble(map['oilCapacity']) ?? _parseDouble(map['oilCapacityLiters']) ?? _parseDouble(legacySpecs?['oilCapacity']),
      inputSpeedRpm: _parseDouble(map['inputSpeedRpm']) ?? _parseDouble(legacySpecs?['inputSpeedRpm']),
      outputSpeedRpm: _parseDouble(map['outputSpeedRpm']) ?? _parseDouble(legacySpecs?['outputSpeedRpm']),
      inputShaftMm: _parseDouble(map['inputShaftMm']) ?? _parseDouble(map['inputShaftDiameterMm']) ?? _parseDouble(legacySpecs?['inputShaftMm']),
      outputShaftMm: _parseDouble(map['outputShaftMm']) ?? _parseDouble(map['outputShaftDiameterMm']) ?? _parseDouble(legacySpecs?['outputShaftMm']),
      lubricationMethod: map['lubricationMethod']?.toString() ?? map['lubricationType']?.toString() ?? legacySpecs?['lubricationMethod']?.toString(),
      mountingOrientation: map['mountingOrientation']?.toString() ?? legacySpecs?['mountingOrientation']?.toString(),
      
      // Pump Specs
      flowRate: _parseDouble(map['flowRate']) ?? _parseDouble(map['flowRateM3Hr']) ?? _parseDouble(legacySpecs?['flowRate']),
      head: _parseDouble(map['head']) ?? _parseDouble(map['headMeters']) ?? _parseDouble(legacySpecs?['head']),
      impellerSize: map['impellerSize']?.toString() ?? map['impellerDiameterMm']?.toString() ?? legacySpecs?['impellerSize']?.toString(),
      pumpPower: _parseDouble(map['pumpPower']) ?? _parseDouble(map['powerKw']) ?? _parseDouble(legacySpecs?['pumpPower']),
      suctionFlangeMm: _parseDouble(map['suctionFlangeMm']) ?? _parseDouble(map['suctionSizeMm']) ?? _parseDouble(legacySpecs?['suctionFlangeMm']),
      dischargeFlangeMm: _parseDouble(map['dischargeFlangeMm']) ?? _parseDouble(map['dischargeSizeMm']) ?? _parseDouble(legacySpecs?['dischargeFlangeMm']),
      sealType: map['sealType']?.toString() ?? legacySpecs?['sealType']?.toString(),
      casingMaterial: map['casingMaterial']?.toString() ?? legacySpecs?['casingMaterial']?.toString(),
      
      // Brake Direct Specs
      brakeType: map['brakeType']?.toString() ?? legacySpecs?['brakeType']?.toString(),
      thrusterCapacityKg: _parseDouble(map['thrusterCapacityKg']) ?? _parseDouble(map['thrusterLiftingForceN']) ?? _parseDouble(legacySpecs?['thrusterCapacityKg']),
      voltageType: map['voltageType']?.toString() ?? legacySpecs?['voltageType']?.toString(),
      voltageRating: _parseDouble(map['voltageRating']) ?? _parseDouble(map['supplyVoltage']) ?? _parseDouble(legacySpecs?['voltageRating']),
      drumDiaMm: _parseDouble(map['drumDiaMm']) ?? _parseDouble(map['drumDiameterMm']) ?? _parseDouble(legacySpecs?['drumDiaMm']),
      drumWidthMm: _parseDouble(map['drumWidthMm']) ?? _parseDouble(legacySpecs?['drumWidthMm']),
      drumInstallation: map['drumInstallation']?.toString() ?? legacySpecs?['drumInstallation']?.toString(),
      mountingBoltSize: map['mountingBoltSize']?.toString() ?? map['mountingHolePitch']?.toString() ?? legacySpecs?['mountingBoltSize']?.toString(),
      mountingBoltCount: _parseInt(map['mountingBoltCount']) ?? _parseInt(legacySpecs?['mountingBoltCount']),
      mountingLengthMm: _parseDouble(map['mountingLengthMm']) ?? _parseDouble(legacySpecs?['mountingLengthMm']),
      mountingWidthMm: _parseDouble(map['mountingWidthMm']) ?? _parseDouble(legacySpecs?['mountingWidthMm']),
      brakingTorqueNm: _parseDouble(map['brakingTorqueNm']) ?? _parseDouble(map['ratedTorqueNm']) ?? _parseDouble(legacySpecs?['brakingTorqueNm']),
      brakeShoeLining: map['brakeShoeLining']?.toString() ?? map['liningMaterial']?.toString() ?? legacySpecs?['brakeShoeLining']?.toString(),

      // Actuator Direct Specs
      actuatorType: map['actuatorType']?.toString() ?? legacySpecs?['actuatorType']?.toString(),
      torqueOrThrust: _parseDouble(map['torqueOrThrust']) ?? _parseDouble(map['operatingTorqueNm']) ?? _parseDouble(legacySpecs?['torqueOrThrust']),
      operatingTimeSeconds: _parseDouble(map['operatingTimeSeconds']) ?? _parseDouble(legacySpecs?['operatingTimeSeconds']),
      controlSignal: map['controlSignal']?.toString() ?? map['inputControlSignal']?.toString() ?? legacySpecs?['controlSignal']?.toString(),
      valveFlangeStandard: map['valveFlangeStandard']?.toString() ?? map['isoFlangeSize']?.toString() ?? legacySpecs?['valveFlangeStandard']?.toString(),
      valveType: map['valveType']?.toString() ?? legacySpecs?['valveType']?.toString(),
      valveSize: map['valveSize']?.toString() ?? map['valveSizeInch']?.toString() ?? legacySpecs?['valveSize']?.toString(),
      
      healthStatus: AssetHealthStatus.values.firstWhere(
        (e) => e.name == (map['healthStatus'] ?? 'unknown'),
        orElse: () => AssetHealthStatus.unknown,
      ),
      lastPulseTime: _parseDate(map['lastPulseTime']),

      windingResistance: map['windingResistance'] as Map<String, dynamic>?,
      insulationResistance: map['insulationResistance'] as Map<String, dynamic>?,
      polarizationIndex: _parseDouble(map['polarizationIndex']),
      vibration: map['vibration'] as Map<String, dynamic>?,
      
      bearingDE: map['bearingDE']?.toString() ?? map['driveEndBearing']?.toString() ?? map['bearingDriveEnd']?.toString(),
      bearingNDE: map['bearingNDE']?.toString() ?? map['nonDriveEndBearing']?.toString() ?? map['bearingNonDriveEnd']?.toString(),
      
      isCritical: map['isCritical'] == true || map['isCritical']?.toString().toLowerCase() == 'true',
      applicableParentEquipmentIds: parents,
      spareLocation: map['spareLocation']?.toString() ?? map['locationInWarehouse']?.toString(),
      seqNo: map['seqNo']?.toString(),
      
      installationDate: _parseDate(map['installationDate']),
      lastServiceDate: _parseDate(map['lastServiceDate']),
      nextServiceDue: _parseDate(map['nextServiceDue']),
      createdAt: _parseDate(map['createdAt']),
      createdBy: map['createdBy']?.toString(),
      modifiedAt: _parseDate(map['modifiedAt']) ?? _parseDate(map['updatedAt']),
      modifiedBy: map['modifiedBy']?.toString(),
    );
  }

  static double? _parseDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    if (val is String) {
      final trimmed = val.trim();
      if (trimmed.isEmpty || trimmed.toLowerCase() == 'n/a' || trimmed == '-') return null;
      // If it contains letters/units like "415V", "130A", "50Hz", "1480 RPM", clean and extract first number
      final direct = double.tryParse(trimmed);
      if (direct != null) return direct;
      final match = RegExp(r'[-+]?\d*\.?\d+').firstMatch(trimmed);
      if (match != null) {
        return double.tryParse(match.group(0)!);
      }
    }
    return null;
  }

  static int? _parseInt(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toInt();
    if (val is String) {
      final trimmed = val.trim();
      if (trimmed.isEmpty || trimmed.toLowerCase() == 'n/a' || trimmed == '-') return null;
      final direct = int.tryParse(trimmed);
      if (direct != null) return direct;
      final match = RegExp(r'[-+]?\d+').firstMatch(trimmed);
      if (match != null) {
        return int.tryParse(match.group(0)!);
      }
    }
    return null;
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
    } else if (type == AssetType.brake) {
      final dia = drumDiaMm != null ? 'Ø${drumDiaMm!.toStringAsFixed(0)}mm ' : '';
      final bType = (brakeType != null && brakeType!.isNotEmpty) ? brakeType! : 'Brake';
      final mk = make.isNotEmpty ? ' ($make)' : '';
      return '$dia$bType$mk'.trim();
    } else if (type == AssetType.actuator) {
      final aType = (actuatorType != null && actuatorType!.isNotEmpty) ? actuatorType! : 'Actuator';
      final vT = (valveType != null && valveType!.isNotEmpty) ? ' for $valveType' : '';
      final mk = make.isNotEmpty ? ' ($make)' : '';
      return '$aType$vT$mk'.trim();
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
    } else if (type == AssetType.brake) {
      final parts = <String>[];
      if (drumDiaMm != null) parts.add('Drum Ø${drumDiaMm!.toStringAsFixed(0)}mm');
      if (voltageRating != null) parts.add('${voltageType ?? ''} ${voltageRating!.toStringAsFixed(0)}V'.trim());
      if (thrusterCapacityKg != null) parts.add('${thrusterCapacityKg!.toStringAsFixed(0)}kg Thruster');
      if (mountingBoltSize != null && mountingBoltSize!.isNotEmpty) parts.add(mountingBoltSize!);
      return parts.isNotEmpty ? parts.join(' • ') : 'Brake Specs Pending';
    } else if (type == AssetType.actuator) {
      final parts = <String>[];
      if (torqueOrThrust != null) parts.add('${torqueOrThrust}Nm');
      if (controlSignal != null && controlSignal!.isNotEmpty) parts.add(controlSignal!);
      if (valveSize != null && valveSize!.isNotEmpty) parts.add(valveSize!);
      return parts.isNotEmpty ? parts.join(' • ') : 'Actuator Specs Pending';
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

    // Direct Brake Specs
    if (brakeType != null && brakeType!.isNotEmpty) map['brakeType'] = brakeType;
    if (thrusterCapacityKg != null) map['thrusterCapacityKg'] = thrusterCapacityKg;
    if (voltageType != null && voltageType!.isNotEmpty) map['voltageType'] = voltageType;
    if (voltageRating != null) map['voltageRating'] = voltageRating;
    if (drumDiaMm != null) map['drumDiaMm'] = drumDiaMm;
    if (drumWidthMm != null) map['drumWidthMm'] = drumWidthMm;
    if (drumInstallation != null && drumInstallation!.isNotEmpty) map['drumInstallation'] = drumInstallation;
    if (mountingBoltSize != null && mountingBoltSize!.isNotEmpty) map['mountingBoltSize'] = mountingBoltSize;
    if (mountingBoltCount != null) map['mountingBoltCount'] = mountingBoltCount;
    if (mountingLengthMm != null) map['mountingLengthMm'] = mountingLengthMm;
    if (mountingWidthMm != null) map['mountingWidthMm'] = mountingWidthMm;
    if (brakingTorqueNm != null) map['brakingTorqueNm'] = brakingTorqueNm;
    if (brakeShoeLining != null && brakeShoeLining!.isNotEmpty) map['brakeShoeLining'] = brakeShoeLining;

    // Direct Actuator Specs
    if (actuatorType != null && actuatorType!.isNotEmpty) map['actuatorType'] = actuatorType;
    if (torqueOrThrust != null) map['torqueOrThrust'] = torqueOrThrust;
    if (operatingTimeSeconds != null) map['operatingTimeSeconds'] = operatingTimeSeconds;
    if (controlSignal != null && controlSignal!.isNotEmpty) map['controlSignal'] = controlSignal;
    if (valveFlangeStandard != null && valveFlangeStandard!.isNotEmpty) map['valveFlangeStandard'] = valveFlangeStandard;
    if (valveType != null && valveType!.isNotEmpty) map['valveType'] = valveType;
    if (valveSize != null && valveSize!.isNotEmpty) map['valveSize'] = valveSize;

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
