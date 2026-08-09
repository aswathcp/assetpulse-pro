import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/assets/data/models/asset_model.dart';
import '../../features/assets/data/models/health_log_model.dart';
import '../../features/assets/data/models/master_equipment_model.dart';
import '../../features/assets/data/models/location_model.dart';
import '../../features/assets/data/models/panel_model.dart';
import '../../features/assets/data/models/feeder_model.dart';
import '../../features/assets/data/models/panel_room_model.dart';
import '../../features/assets/data/models/fault_log_model.dart';
import '../../features/assets/data/models/isolation_permit_model.dart';
import 'hierarchy_service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // New getter
  User? get currentUser => FirebaseAuth.instance.currentUser;

  // Save User Profile
  Future<void> saveUserProfile({
    required User user,
    required String name,
    required String employeeId,
    required String role,
    required String department, // NEW
    required String businessId, // NEW
    required String unit,
    required String plant,
  }) async {
    debugPrint('DEBUG: FirestoreService: Writing to users/${user.uid}...');
    try {
      await _db.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'displayName': name,
        'employeeId': employeeId,
        'role': role,
        'department': department, // NEW
        'unitId': unit,
        'plantId': plant,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'isValidated': false, // Pending Approval
        'isRequestingAuth': false, // Default Grid LOTO
        'isIsolationAuth': false, // Default Grid LOTO
      });
      debugPrint('DEBUG: FirestoreService: Write Complete.');
    } catch (e) {
      debugPrint('DEBUG: FirestoreService Error: $e');
      rethrow;
    }
  }

  // Update User LOTO Rights
  Future<void> updateUserLotoRights(String uid, {required bool isRequestingAuth, required bool isIsolationAuth}) async {
    await _db.collection('users').doc(uid).update({
      'isRequestingAuth': isRequestingAuth,
      'isIsolationAuth': isIsolationAuth,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  // Get User Profile
  Future<Map<String, dynamic>?> getUserProfile(String uid, {bool fromServer = false}) async {
    final doc = await _db.collection('users').doc(uid).get(
      GetOptions(source: fromServer ? Source.server : Source.serverAndCache),
    );
    return doc.data();
  }

  // Log Activity
  Future<void> logActivity({required String userId, required String action, required String details}) async {
    await _db.collection('activity_logs').add({
      'userId': userId,
      'action': action,
      'details': details,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // --- ASSET MANAGEMENT (HIERARCHICAL) ---
  
  // Get User Unit and Plant IDs
  Future<Map<String, String>?> getUserUnitAndPlant() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    
    final doc = await _db.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (data == null) return null;
    
    final unitId = data['unitId'] as String?;
    final plantId = data['plantId'] as String?;
    
    if (unitId == null || plantId == null) return null;
    
    return {'unitId': unitId, 'plantId': plantId};
  }
  
  // Get User Plant ID Helper (legacy compatibility)
  Future<String?> getUserPlantId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    
    final doc = await _db.collection('users').doc(user.uid).get();
    return doc.data()?['plantId'];
  }
  
  // Get User Unit ID Helper
  Future<String?> getUserUnitId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    
    final doc = await _db.collection('users').doc(user.uid).get();
    return doc.data()?['unitId'];
  }

  // HELPER: Known Units and Plants (Single Source of Truth)
  // --- Hierarchy Management (Delegated to HierarchyService) ---

  // Legacy Compatibility: "Units" in code = "Plants" in V4 Schema (VAB, IOK)
  static List<String> get knownUnits => HierarchyService().getPlants(); 

  // Legacy Compatibility: "Plants" in code = "Units" in V4 Schema (PID1, MCD)
  // This gets all units for a given plant (legacy 'unitId' -> V4 'plantId')
  static List<String> getPlantsForUnit(String unitId) {
    return HierarchyService().getUnitsForPlant(unitId);
  }

  // Get all leaf nodes (all units across all plants)
  static List<String> get knownPlants {
    final plants = HierarchyService().getPlants();
    final allUnits = <String>[];
    for (var p in plants) {
      allUnits.addAll(HierarchyService().getUnitsForPlant(p));
    }
    return allUnits;
  }

  // Get All Assets Stream (Flattened)
  Stream<List<AssetModel>> getAssetsStream(String? unitId, String? plantId) {
    Query query = _db.collection('assets');
    // If we want to filter by unit/plant, we would query the parent master equipments first
    // but for simplicity in this industrial app, we fetch all or filter by ID prefix if tags are hierarchical.
    return query.snapshots().map((s) => s.docs.map((d) => AssetModel.fromMap(d.data() as Map<String, dynamic>, d.id)).toList());
  }

  // Get All Assets List (One-time fetch)
  Future<List<AssetModel>> getAssetsList(String? unitId, String? plantId) async {
    final snapshot = await _db.collection('assets').get();
    return snapshot.docs.map((doc) => AssetModel.fromMap(doc.data(), doc.id)).toList();
  }

  // Save Asset (Create or Update)
  Future<void> saveAsset(AssetModel asset) async {
    final assetsRef = _db.collection('assets');
    if (asset.id.isEmpty || asset.id == 'new') {
      await assetsRef.add(asset.toMap());
    } else {
      await assetsRef.doc(asset.id).set(asset.toMap(), SetOptions(merge: true));
    }
  }

  // --- HEALTH LOGS ---
  
  // Save Health Log
  Future<void> saveHealthLog(HealthLogModel log) async {
    final ref = _db.collection('health_logs');
    if (log.id.isEmpty || log.id == 'new') {
      await ref.add(log.toMap());
    } else {
      await ref.doc(log.id).set(log.toMap(), SetOptions(merge: true));
    }
  }

  // Get Health Logs Stream for an Asset
  Stream<List<HealthLogModel>> getHealthLogsStream(String assetId, {String? tagNo}) {
    final Set<String> targetIds = {assetId};
    if (tagNo != null && tagNo.isNotEmpty) {
      targetIds.add(tagNo);
    }

    Query query = _db.collection('health_logs');
    if (targetIds.length == 1) {
      query = query.where('assetId', isEqualTo: targetIds.first);
    } else {
      query = query.where('assetId', whereIn: targetIds.toList());
    }

    return query.snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) => HealthLogModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
      list.sort((a, b) => b.testDate.compareTo(a.testDate));
      return list;
    });
  }

  // Get Single Asset
  Future<AssetModel?> getAsset(String assetId) async {
    final doc = await _db.collection('assets').doc(assetId).get();
    if (doc.exists && doc.data() != null) {
      return AssetModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  // Find Asset by Tag Number (Top Level)
  Future<AssetModel?> getAssetByTagNo(String tagNo) async {
    final query = await _db.collection('assets')
        .where('tagNo', isEqualTo: tagNo)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      return AssetModel.fromMap(query.docs.first.data(), query.docs.first.id);
    }
    return null;
  }

  // Find Asset by RFID Tag (Top Level)
  Future<AssetModel?> getAssetByRfid(String rfidTag) async {
    final query = await _db.collection('assets')
        .where('rfidTag', isEqualTo: rfidTag)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      return AssetModel.fromMap(query.docs.first.data(), query.docs.first.id);
    }
    return null;
  }

  // --- USER MANAGEMENT ---

  Future<List<Map<String, dynamic>>> getAllUsers({String? businessId, String? unitId, String? plantId}) async {
    Query query = _db.collection('users');
    if (businessId != null && businessId.isNotEmpty) query = query.where('businessId', isEqualTo: businessId);
    if (plantId != null && plantId.isNotEmpty) query = query.where('plantId', isEqualTo: plantId);
    if (unitId != null && unitId.isNotEmpty) query = query.where('unitId', isEqualTo: unitId);
    final snapshot = await query.get();
    return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
  }

  Future<void> updateUserRole(String targetUserId, String newRole) async {
    await _db.collection('users').doc(targetUserId).update({
      'role': newRole,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  // --- MASTER EQUIPMENT (FUNCTIONAL LOCATION) ---

  Stream<List<MasterEquipmentModel>> getMasterEquipmentsStream(String unitId, String plantId) {
    return _db.collection('master_equipments')
        .where('unitId', isEqualTo: unitId)
        .where('plantId', isEqualTo: plantId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => MasterEquipmentModel.fromMap(doc.data(), doc.id)).toList());
  }

  Stream<List<MasterEquipmentModel>> getAllMasterEquipmentsStream(String? unitId, String? plantId) {
    Query query = _db.collection('master_equipments');
    if (unitId != null && unitId.isNotEmpty) query = query.where('unitId', isEqualTo: unitId);
    if (plantId != null && plantId.isNotEmpty) query = query.where('plantId', isEqualTo: plantId);
    return query.snapshots().map((snapshot) => snapshot.docs.map((doc) => MasterEquipmentModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList());
  }

  Future<void> saveMasterEquipment(MasterEquipmentModel equipment) async {
    await _db.collection('master_equipments')
        .doc(equipment.id)
        .set(equipment.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteMasterEquipment(String id) async {
    await _db.collection('master_equipments').doc(id).delete();
  }




  // --- INFRASTRUCTURE CRUDS ---
  
  // Locations (Areas)
  Future<void> saveLocation(LocationModel location) async {
    await _db.collection('locations').doc(location.id).set(location.toMap(), SetOptions(merge: true));
  }

  Stream<List<LocationModel>> getLocationsStream(String unitId, String plantId) {
    if (unitId.isEmpty || plantId.isEmpty) return const Stream.empty();
    return _db.collection('locations')
        .where('unitId', isEqualTo: unitId)
        .where('plantId', isEqualTo: plantId)
        .snapshots()
        .map((s) => s.docs.map((d) => LocationModel.fromMap(d.data(), d.id)).toList());
  }

  // Panel Rooms
  Future<void> savePanelRoom(PanelRoomModel panelRoom) async {
    await _db.collection('panel_rooms').doc(panelRoom.id).set(panelRoom.toMap(), SetOptions(merge: true));
  }

  Stream<List<PanelRoomModel>> getPanelRoomsStream(String unitId, String plantId) {
    if (unitId.isEmpty || plantId.isEmpty) return const Stream.empty();
    return _db.collection('panel_rooms')
        .where('unitId', isEqualTo: unitId)
        .where('plantId', isEqualTo: plantId)
        .snapshots()
        .map((s) => s.docs.map((d) => PanelRoomModel.fromMap(d.data(), d.id)).toList());
  }

  // Panels
  Future<void> savePanel(PanelModel panel) async {
    await _db.collection('panels').doc(panel.id).set(panel.toMap(), SetOptions(merge: true));
  }

  Stream<List<PanelModel>> getPanelsStream(String panelRoomId) {
    if (panelRoomId.isEmpty) return const Stream.empty();
    return _db.collection('panels')
        .where('panelRoomId', isEqualTo: panelRoomId)
        .snapshots()
        .map((s) => s.docs.map((d) => PanelModel.fromMap(d.data(), d.id)).toList());
  }

  // Feeders
  Future<void> saveFeeder(FeederModel feeder) async {
    await _db.collection('feeders').doc(feeder.id).set(feeder.toMap(), SetOptions(merge: true));
  }

  Stream<List<FeederModel>> getFeedersStream(String panelId) {
    if (panelId.isEmpty) return const Stream.empty();
    return _db.collection('feeders')
        .where('panelId', isEqualTo: panelId)
        .snapshots()
        .map((s) => s.docs.map((d) => FeederModel.fromMap(d.data(), d.id)).toList());
  }

  // --- FAULT LOG CRUDS ---
  Future<void> saveFaultLog(FaultLogModel log) async {
    await _db.collection('fault_logs').doc(log.id).set(log.toMap(), SetOptions(merge: true));
  }

  Stream<List<FaultLogModel>> getFaultLogsStream(String masterEquipmentId) {
    if (masterEquipmentId.isEmpty) return const Stream.empty();
    return _db.collection('fault_logs')
        .where('masterEquipmentId', isEqualTo: masterEquipmentId)
        .orderBy('reportedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => FaultLogModel.fromMap(d.data(), d.id)).toList());
  }

  Stream<List<FaultLogModel>> getAllFaultLogsStream() {
    return _db.collection('fault_logs')
        .orderBy('reportedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => FaultLogModel.fromMap(d.data(), d.id)).toList());
  }

  // Generic Batch Save for Bulk Upload
  Future<void> batchSave(String collection, List<Map<String, dynamic>> items) async {
    final batch = _db.batch();
    int count = 0;
    
    for (var item in items) {
       if (item['id'] == null) continue;
       final ref = _db.collection(collection).doc(item['id'].toString());
       batch.set(ref, item, SetOptions(merge: true));
       
       count++;
       if (count >= 490) { 
         await batch.commit();
       }
    }
    await batch.commit();
  }
  
  // Generic collection stream 
  Stream<List<Map<String, dynamic>>> getCollectionStream(String collection, String? unitId, String? plantId) {
    Query query = _db.collection(collection);
    
    if (unitId != null && unitId.isNotEmpty) query = query.where('unitId', isEqualTo: unitId);
    if (plantId != null && plantId.isNotEmpty) query = query.where('plantId', isEqualTo: plantId);
    
    return query.snapshots().map((s) => s.docs.map((d) {
      final data = Map<String, dynamic>.from(d.data() as Map<String, dynamic>);
      data['id'] = d.id;
      return data;
    }).toList());
  }

  // Delete Doc
  Future<void> deleteDocument(String collection, String id) async {
    await _db.collection(collection).doc(id).delete();
  }
  // Save Hierarchy Config
  Future<void> saveHierarchyConfig(String businessId, Map<String, dynamic> data) async {
    await _db.collection('hierarchy_config').doc(businessId).set(data);
  }

  Future<Map<String, String>> getHierarchyConfigs() async {
    final snapshot = await _db.collection('hierarchy_config').get();
    final Map<String, String> map = {};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      map[doc.id] = data['businessName'] ?? doc.id;
    }
    return map;
  }
  // --- ISOLATION PERMIT (DIGITAL LOTO) ---

  Future<void> saveIsolationPermit(IsolationPermitModel permit) async {
    await _db.collection('isolation_permits').doc(permit.id.isEmpty ? null : permit.id).set(permit.toMap(), SetOptions(merge: true));
  }

  Stream<List<IsolationPermitModel>> getActiveIsolationsStream({String? businessId, String? plantId, String? unitId}) {
    Query query = _db.collection('isolation_permits').where('status', isEqualTo: 'active');
    if (businessId != null && businessId.isNotEmpty) query = query.where('businessId', isEqualTo: businessId);
    if (plantId != null && plantId.isNotEmpty) query = query.where('plantId', isEqualTo: plantId);
    if (unitId != null && unitId.isNotEmpty) query = query.where('unitId', isEqualTo: unitId);
    
    return query.snapshots().map((s) => s.docs.map((d) => IsolationPermitModel.fromMap(d.data() as Map<String, dynamic>, d.id)).toList());
  }

  Stream<List<IsolationPermitModel>> getIsolationRecordsStream({String? businessId, String? plantId, String? unitId}) {
    Query query = _db.collection('isolation_permits');
    if (businessId != null && businessId.isNotEmpty) query = query.where('businessId', isEqualTo: businessId);
    if (plantId != null && plantId.isNotEmpty) query = query.where('plantId', isEqualTo: plantId);
    if (unitId != null && unitId.isNotEmpty) query = query.where('unitId', isEqualTo: unitId);
    
    return query.orderBy('isolationDateTime', descending: true).snapshots()
      .map((s) => s.docs.map((d) => IsolationPermitModel.fromMap(d.data() as Map<String, dynamic>, d.id)).toList());
  }

  // Get Users with specific LOTO rights
  Future<List<Map<String, dynamic>>> getLotoAuthorizedUsers({
    required String businessId,
    required bool isRequestingAuth,
    required bool isIsolationAuth,
    String? department,
  }) async {
    Query query = _db.collection('users').where('businessId', isEqualTo: businessId);
    
    if (isRequestingAuth) query = query.where('isRequestingAuth', isEqualTo: true);
    if (isIsolationAuth) query = query.where('isIsolationAuth', isEqualTo: true);
    if (department != null && department.isNotEmpty) query = query.where('department', isEqualTo: department);

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
  }
}
