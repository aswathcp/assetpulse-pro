import 'package:cloud_firestore/cloud_firestore.dart';

class WorkmanModel {
  final String id;
  final String name;
  final String trade; // e.g. Electrician, Fitter, Welder, Helper, Contractor, Apprentice, Rigger
  final String contractor; // e.g. "In-House", "Monomark", "Apex", etc.
  final String? employeeId;
  final String? plantId;
  final String? unitId;
  final String? phone;
  final bool isActive;
  final DateTime createdAt;
  final String? createdBy;

  WorkmanModel({
    required this.id,
    required this.name,
    this.trade = 'Electrician',
    this.contractor = 'In-House',
    this.employeeId,
    this.plantId,
    this.unitId,
    this.phone,
    this.isActive = true,
    required this.createdAt,
    this.createdBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'trade': trade,
      'contractor': contractor,
      'employeeId': employeeId,
      'plantId': plantId,
      'unitId': unitId,
      'phone': phone,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }

  factory WorkmanModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parsedCreatedAt = DateTime.now();
    if (map['createdAt'] is Timestamp) {
      parsedCreatedAt = (map['createdAt'] as Timestamp).toDate();
    }

    return WorkmanModel(
      id: docId,
      name: map['name']?.toString() ?? '',
      trade: map['trade']?.toString() ?? 'Electrician',
      contractor: map['contractor']?.toString() ?? 'In-House',
      employeeId: map['employeeId']?.toString(),
      plantId: map['plantId']?.toString(),
      unitId: map['unitId']?.toString(),
      phone: map['phone']?.toString(),
      isActive: map['isActive'] != false,
      createdAt: parsedCreatedAt,
      createdBy: map['createdBy']?.toString(),
    );
  }

  WorkmanModel copyWith({
    String? id,
    String? name,
    String? trade,
    String? contractor,
    String? employeeId,
    String? plantId,
    String? unitId,
    String? phone,
    bool? isActive,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return WorkmanModel(
      id: id ?? this.id,
      name: name ?? this.name,
      trade: trade ?? this.trade,
      contractor: contractor ?? this.contractor,
      employeeId: employeeId ?? this.employeeId,
      plantId: plantId ?? this.plantId,
      unitId: unitId ?? this.unitId,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
