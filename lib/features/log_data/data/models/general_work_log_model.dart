import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../assets/data/models/fault_log_model.dart';

class EquipmentWorkBlock {
  final String id;
  final String? masterEquipmentId;
  final String equipmentName;
  final String? assetId;
  final String? assetName;
  final String? feederId;
  final String? feederName;
  final String? location;
  final String? locationId;
  final String category;
  final List<String> tasks;
  final String? pendingFollowUp;
  final String status; // 'completed' or 'pending'

  EquipmentWorkBlock({
    required this.id,
    this.masterEquipmentId,
    required this.equipmentName,
    this.assetId,
    this.assetName,
    this.feederId,
    this.feederName,
    this.location,
    this.locationId,
    this.category = 'General Maintenance',
    this.tasks = const [],
    this.pendingFollowUp,
    this.status = 'completed',
  });

  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get hasPending => pendingFollowUp != null && pendingFollowUp!.trim().isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'masterEquipmentId': masterEquipmentId,
      'equipmentName': equipmentName,
      'assetId': assetId,
      'assetName': assetName,
      'feederId': feederId,
      'feederName': feederName,
      'location': location,
      'locationId': locationId,
      'category': category,
      'tasks': tasks,
      'pendingFollowUp': pendingFollowUp,
      'status': status,
    };
  }

  factory EquipmentWorkBlock.fromMap(Map<String, dynamic> map) {
    List<String> parsedTasks = [];
    if (map['tasks'] is List) {
      parsedTasks = (map['tasks'] as List).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }

    return EquipmentWorkBlock(
      id: map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      masterEquipmentId: map['masterEquipmentId']?.toString(),
      equipmentName: map['equipmentName']?.toString() ?? 'Equipment',
      assetId: map['assetId']?.toString(),
      assetName: map['assetName']?.toString(),
      feederId: map['feederId']?.toString(),
      feederName: map['feederName']?.toString(),
      location: map['location']?.toString(),
      locationId: map['locationId']?.toString(),
      category: map['category']?.toString() ?? 'General Maintenance',
      tasks: parsedTasks,
      pendingFollowUp: map['pendingFollowUp']?.toString(),
      status: map['status']?.toString() ?? 'completed',
    );
  }

  EquipmentWorkBlock copyWith({
    String? id,
    String? masterEquipmentId,
    String? equipmentName,
    String? assetId,
    String? assetName,
    String? feederId,
    String? feederName,
    String? location,
    String? locationId,
    String? category,
    List<String>? tasks,
    String? pendingFollowUp,
    String? status,
  }) {
    return EquipmentWorkBlock(
      id: id ?? this.id,
      masterEquipmentId: masterEquipmentId ?? this.masterEquipmentId,
      equipmentName: equipmentName ?? this.equipmentName,
      assetId: assetId ?? this.assetId,
      assetName: assetName ?? this.assetName,
      feederId: feederId ?? this.feederId,
      feederName: feederName ?? this.feederName,
      location: location ?? this.location,
      locationId: locationId ?? this.locationId,
      category: category ?? this.category,
      tasks: tasks ?? this.tasks,
      pendingFollowUp: pendingFollowUp ?? this.pendingFollowUp,
      status: status ?? this.status,
    );
  }
}

class GeneralWorkLogModel {
  final String id;
  final DateTime date;
  final WorkShift shift;
  final String? plantId;
  final String? unitId;
  final String? location;
  final List<String> engineerUserIds;
  final List<String> engineerNames;
  final List<String> workmenIds;
  final List<String> workmenNames;
  final List<EquipmentWorkBlock> equipmentWorks;
  final String status; // 'completed' or 'pending'
  final String reportedByUserId;
  final String reportedByName;
  final DateTime reportedAt;
  final String? rawAiInput;

  GeneralWorkLogModel({
    required this.id,
    required this.date,
    this.shift = WorkShift.as,
    this.plantId,
    this.unitId,
    this.location,
    this.engineerUserIds = const [],
    this.engineerNames = const [],
    this.workmenIds = const [],
    this.workmenNames = const [],
    this.equipmentWorks = const [],
    this.status = 'completed',
    required this.reportedByUserId,
    required this.reportedByName,
    required this.reportedAt,
    this.rawAiInput,
  });

  bool get isCompleted => status.toLowerCase() == 'completed';
  int get totalTasksCount => equipmentWorks.fold(0, (acc, item) => acc + item.tasks.length);
  bool get hasPendingFollowUp => equipmentWorks.any((ew) => ew.hasPending);

  // Backward compatibility getters
  List<String> get team => [...engineerNames, ...workmenNames];
  String get equipmentOrArea => equipmentWorks.isNotEmpty
      ? equipmentWorks.map((e) => e.equipmentName).join(', ')
      : (location ?? '');
  String get category => equipmentWorks.isNotEmpty ? equipmentWorks.first.category : 'General Maintenance';
  List<String> get items => equipmentWorks.expand((e) => e.tasks).toList();
  String get description => equipmentWorks.map((e) => '${e.equipmentName}:\n${e.tasks.map((t) => "• $t").join("\n")}').join('\n\n');
  String? get pendingFollowUp {
    final list = equipmentWorks.where((e) => e.hasPending).map((e) => '${e.equipmentName}: ${e.pendingFollowUp}').toList();
    return list.isNotEmpty ? list.join('\n') : null;
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'shift': shift.name,
      'plantId': plantId,
      'unitId': unitId,
      'location': location,
      'engineerUserIds': engineerUserIds,
      'engineerNames': engineerNames,
      'workmenIds': workmenIds,
      'workmenNames': workmenNames,
      'equipmentWorks': equipmentWorks.map((e) => e.toMap()).toList(),
      'status': status,
      'reportedByUserId': reportedByUserId,
      'reportedByName': reportedByName,
      'reportedAt': Timestamp.fromDate(reportedAt),
      'rawAiInput': rawAiInput,
      // Legacy compatibility fields
      'equipmentOrArea': equipmentOrArea,
      'team': team,
      'category': category,
      'items': items,
      'description': description,
      'pendingFollowUp': pendingFollowUp,
    };
  }

  factory GeneralWorkLogModel.fromMap(Map<String, dynamic> map, String docId) {
    WorkShift parsedShift = WorkShift.as;
    final shiftStr = (map['shift'] ?? '').toString().toLowerCase();
    for (final s in WorkShift.values) {
      if (s.name.toLowerCase() == shiftStr) {
        parsedShift = s;
        break;
      }
    }

    DateTime parsedDate = DateTime.now();
    if (map['date'] is Timestamp) {
      parsedDate = (map['date'] as Timestamp).toDate();
    } else if (map['date'] is String) {
      parsedDate = DateTime.tryParse(map['date']) ?? DateTime.now();
    }

    DateTime parsedReportedAt = DateTime.now();
    if (map['reportedAt'] is Timestamp) {
      parsedReportedAt = (map['reportedAt'] as Timestamp).toDate();
    }

    List<String> parsedEngIds = [];
    if (map['engineerUserIds'] is List) {
      parsedEngIds = (map['engineerUserIds'] as List).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }

    List<String> parsedEngNames = [];
    if (map['engineerNames'] is List) {
      parsedEngNames = (map['engineerNames'] as List).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }

    List<String> parsedWorkmenIds = [];
    if (map['workmenIds'] is List) {
      parsedWorkmenIds = (map['workmenIds'] as List).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }

    List<String> parsedWorkmenNames = [];
    if (map['workmenNames'] is List) {
      parsedWorkmenNames = (map['workmenNames'] as List).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }

    // Fallback: If legacy 'team' exists and engineerNames is empty
    if (parsedEngNames.isEmpty && parsedWorkmenNames.isEmpty) {
      if (map['team'] is List) {
        parsedEngNames = (map['team'] as List).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      } else if (map['team'] is String && (map['team'] as String).isNotEmpty) {
        parsedEngNames = (map['team'] as String).split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
    }

    List<EquipmentWorkBlock> parsedBlocks = [];
    if (map['equipmentWorks'] is List && (map['equipmentWorks'] as List).isNotEmpty) {
      parsedBlocks = (map['equipmentWorks'] as List)
          .map((e) => EquipmentWorkBlock.fromMap(e as Map<String, dynamic>))
          .toList();
    } else {
      // Legacy conversion
      List<String> legacyItems = [];
      if (map['items'] is List) {
        legacyItems = (map['items'] as List).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      }
      parsedBlocks = [
        EquipmentWorkBlock(
          id: '1',
          equipmentName: map['equipmentOrArea']?.toString() ?? 'Plant Maintenance',
          location: map['location']?.toString() ?? map['equipmentOrArea']?.toString(),
          category: map['category']?.toString() ?? 'General Maintenance',
          tasks: legacyItems,
          pendingFollowUp: map['pendingFollowUp']?.toString(),
          status: map['status']?.toString() ?? 'completed',
        ),
      ];
    }

    return GeneralWorkLogModel(
      id: docId,
      date: parsedDate,
      shift: parsedShift,
      plantId: map['plantId']?.toString(),
      unitId: map['unitId']?.toString(),
      location: map['location']?.toString() ?? map['equipmentOrArea']?.toString(),
      engineerUserIds: parsedEngIds,
      engineerNames: parsedEngNames,
      workmenIds: parsedWorkmenIds,
      workmenNames: parsedWorkmenNames,
      equipmentWorks: parsedBlocks,
      status: map['status']?.toString() ?? 'completed',
      reportedByUserId: map['reportedByUserId']?.toString() ?? '',
      reportedByName: map['reportedByName']?.toString() ?? 'Engineer',
      reportedAt: parsedReportedAt,
      rawAiInput: map['rawAiInput']?.toString() ?? map['rawText']?.toString(),
    );
  }

  GeneralWorkLogModel copyWith({
    String? id,
    DateTime? date,
    WorkShift? shift,
    String? plantId,
    String? unitId,
    String? location,
    List<String>? engineerUserIds,
    List<String>? engineerNames,
    List<String>? workmenIds,
    List<String>? workmenNames,
    List<EquipmentWorkBlock>? equipmentWorks,
    String? status,
    String? reportedByUserId,
    String? reportedByName,
    DateTime? reportedAt,
    String? rawAiInput,
  }) {
    return GeneralWorkLogModel(
      id: id ?? this.id,
      date: date ?? this.date,
      shift: shift ?? this.shift,
      plantId: plantId ?? this.plantId,
      unitId: unitId ?? this.unitId,
      location: location ?? this.location,
      engineerUserIds: engineerUserIds ?? this.engineerUserIds,
      engineerNames: engineerNames ?? this.engineerNames,
      workmenIds: workmenIds ?? this.workmenIds,
      workmenNames: workmenNames ?? this.workmenNames,
      equipmentWorks: equipmentWorks ?? this.equipmentWorks,
      status: status ?? this.status,
      reportedByUserId: reportedByUserId ?? this.reportedByUserId,
      reportedByName: reportedByName ?? this.reportedByName,
      reportedAt: reportedAt ?? this.reportedAt,
      rawAiInput: rawAiInput ?? this.rawAiInput,
    );
  }
}
