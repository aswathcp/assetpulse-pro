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
import '../../features/assets/data/models/transformer_model.dart';
import '../../features/assets/data/models/fault_log_model.dart';
import '../../features/assets/data/models/isolation_permit_model.dart';
import '../../features/log_data/data/models/general_work_log_model.dart';
import '../../features/admin/data/models/workman_model.dart';
import '../constants/app_roles.dart';
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
        'businessId': businessId,
        'unitId': unit,
        'plantId': plant,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'isValidated': false, // Pending Approval
        'isRejected': false,
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
    final clean = tagNo.trim();
    if (clean.isEmpty) return null;

    // 1. Exact match on tagNo
    var query = await _db.collection('assets')
        .where('tagNo', isEqualTo: clean)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      return AssetModel.fromMap(query.docs.first.data(), query.docs.first.id);
    }

    // 2. Uppercase match on tagNo
    if (clean != clean.toUpperCase()) {
      query = await _db.collection('assets')
          .where('tagNo', isEqualTo: clean.toUpperCase())
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return AssetModel.fromMap(query.docs.first.data(), query.docs.first.id);
      }
    }

    // 3. Match on serialNo
    query = await _db.collection('assets')
        .where('serialNo', isEqualTo: clean)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      return AssetModel.fromMap(query.docs.first.data(), query.docs.first.id);
    }

    // 4. Match on masterEquipmentId
    query = await _db.collection('assets')
        .where('masterEquipmentId', isEqualTo: clean)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      return AssetModel.fromMap(query.docs.first.data(), query.docs.first.id);
    }

    // 5. Match by Document ID
    try {
      final doc = await _db.collection('assets').doc(clean).get();
      if (doc.exists && doc.data() != null) {
        return AssetModel.fromMap(doc.data()!, doc.id);
      }
    } catch (_) {}

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

  // Transformers
  Future<void> saveTransformer(TransformerModel transformer) async {
    await _db.collection('transformers').doc(transformer.id).set(transformer.toMap(), SetOptions(merge: true));
  }

  Stream<List<TransformerModel>> getTransformersStream(String unitId, String plantId) {
    Query query = _db.collection('transformers');
    if (plantId.isNotEmpty) {
      query = query.where('plantId', isEqualTo: plantId);
    }
    if (unitId.isNotEmpty) {
      query = query.where('unitId', isEqualTo: unitId);
    }
    return query.snapshots().map((s) => s.docs.map((d) => TransformerModel.fromMap(d.data() as Map<String, dynamic>, d.id)).toList());
  }

  // Activity Logs Stream (Sorted by timestamp descending)
  Stream<List<Map<String, dynamic>>> getActivityLogsStream({int limit = 20}) {
    return _db.collection('activity_logs')
        .snapshots()
        .map((s) {
          final list = s.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          }).toList();
          list.sort((a, b) {
            final aTime = (a['timestamp'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = (b['timestamp'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });
          return list.take(limit).toList();
        });
  }

  // Open Faults Stream (status not resolved or closed)
  Stream<List<FaultLogModel>> getOpenFaultLogsStream() {
    return _db.collection('fault_logs')
        .snapshots()
        .map((s) {
          final list = s.docs
              .map((d) => FaultLogModel.fromMap(d.data(), d.id))
              .where((f) => f.status == FaultStatus.pending)
              .toList();
          list.sort((a, b) => b.reportedAt.compareTo(a.reportedAt));
          return list;
        });
  }

  // --- FAULT LOG CRUDS ---
  Future<void> saveFaultLog(FaultLogModel log) async {
    await _db.collection('fault_logs').doc(log.id).set(log.toMap(), SetOptions(merge: true));
  }

  Stream<List<FaultLogModel>> getFaultLogsStream(String masterEquipmentId) {
    if (masterEquipmentId.isEmpty) return const Stream.empty();
    return _db.collection('fault_logs')
        .where('masterEquipmentId', isEqualTo: masterEquipmentId)
        .snapshots()
        .map((s) {
          final list = s.docs.map((d) => FaultLogModel.fromMap(d.data(), d.id)).toList();
          list.sort((a, b) => b.reportedAt.compareTo(a.reportedAt));
          return list;
        });
  }

  Stream<List<FaultLogModel>> getAllFaultLogsStream() {
    return _db.collection('fault_logs')
        .snapshots()
        .map((s) {
          final list = s.docs.map((d) => FaultLogModel.fromMap(d.data(), d.id)).toList();
          list.sort((a, b) => b.reportedAt.compareTo(a.reportedAt));
          return list;
        });
  }

  // Generic Batch Save for Bulk Upload
  Future<void> batchSave(String collection, List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    WriteBatch batch = _db.batch();
    int count = 0;
    
    for (var rawItem in items) {
       final item = Map<String, dynamic>.from(rawItem);
       // Remove internal/helper keys
       item.remove('Validation');
       item.remove('_sheetName');
       item.remove('_collection');
       
       // Remove nulls and empty keys
       item.removeWhere((k, v) => k.isEmpty || v == null);

       final docId = item['id']?.toString().trim() ?? item['tagNo']?.toString().trim();
       if (docId == null || docId.isEmpty) continue;
       
       final ref = _db.collection(collection).doc(docId);
       batch.set(ref, item, SetOptions(merge: true));
       
       count++;
       if (count >= 400) { 
         try {
           await batch.commit().timeout(const Duration(seconds: 15));
         } catch (e) {
           debugPrint('Batch commit timed out or failed: $e, falling back to document writes');
         }
         batch = _db.batch();
         count = 0;
       }
    }
    if (count > 0) {
      try {
        await batch.commit().timeout(const Duration(seconds: 15));
      } catch (e) {
        debugPrint('Final batch commit timed out or failed: $e');
      }
    }
  }
  
  // Generic collection stream 
  Stream<List<Map<String, dynamic>>> getCollectionStream(String collection, String? unitId, String? plantId) {
    Query query = _db.collection(collection);
    
    // Fault types and ODC causes are master catalogs that apply broadly
    if (collection != 'fault_types' && collection != 'odc' && collection != 'odc_causes') {
      if (unitId != null && unitId.isNotEmpty) query = query.where('unitId', isEqualTo: unitId);
      if (plantId != null && plantId.isNotEmpty) query = query.where('plantId', isEqualTo: plantId);
    }
    
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

  // Clear entire collection in batches (for clean re-importing)
  Future<int> clearCollection(String collection, {String? unitId, String? plantId}) async {
    Query query = _db.collection(collection);
    if (collection != 'fault_types' && collection != 'odc' && collection != 'odc_causes') {
      if (unitId != null && unitId.isNotEmpty) query = query.where('unitId', isEqualTo: unitId);
      if (plantId != null && plantId.isNotEmpty) query = query.where('plantId', isEqualTo: plantId);
    }

    final snapshot = await query.get();
    if (snapshot.docs.isEmpty) return 0;

    int deleted = 0;
    WriteBatch batch = _db.batch();
    int count = 0;
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
      count++;
      deleted++;
      if (count >= 400) {
        await batch.commit();
        batch = _db.batch();
        count = 0;
      }
    }
    if (count > 0) {
      await batch.commit();
    }
    return deleted;
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
    final docRef = permit.id.isEmpty 
        ? _db.collection('isolation_permits').doc() 
        : _db.collection('isolation_permits').doc(permit.id);
    await docRef.set(permit.toMap(), SetOptions(merge: true));
  }

  Stream<List<IsolationPermitModel>> getActiveIsolationsStream({String? businessId, String? plantId, String? unitId}) {
    Query query = _db.collection('isolation_permits').where('status', isEqualTo: 'active');
    
    return query.snapshots().map((s) {
      final list = s.docs
          .map((d) => IsolationPermitModel.fromMap(d.data() as Map<String, dynamic>, d.id))
          .where((p) {
            final matchesBusiness = businessId == null || businessId.isEmpty || p.businessId.isEmpty || p.businessId == businessId;
            final matchesPlant = plantId == null || plantId.isEmpty || p.plantId.isEmpty || p.plantId.toLowerCase() == plantId.toLowerCase();
            final matchesUnit = unitId == null || unitId.isEmpty || p.unitId.isEmpty || p.unitId.toLowerCase() == unitId.toLowerCase();
            return matchesBusiness && matchesPlant && matchesUnit;
          })
          .toList();
      list.sort((a, b) => b.isolationDateTime.compareTo(a.isolationDateTime));
      return list;
    });
  }

  Stream<List<IsolationPermitModel>> getIsolationRecordsStream({String? businessId, String? plantId, String? unitId}) {
    Query query = _db.collection('isolation_permits');
    
    return query.snapshots().map((s) {
      final list = s.docs
          .map((d) => IsolationPermitModel.fromMap(d.data() as Map<String, dynamic>, d.id))
          .where((p) {
            final matchesBusiness = businessId == null || businessId.isEmpty || p.businessId.isEmpty || p.businessId == businessId;
            final matchesPlant = plantId == null || plantId.isEmpty || p.plantId.isEmpty || p.plantId.toLowerCase() == plantId.toLowerCase();
            final matchesUnit = unitId == null || unitId.isEmpty || p.unitId.isEmpty || p.unitId.toLowerCase() == unitId.toLowerCase();
            return matchesBusiness && matchesPlant && matchesUnit;
          })
          .toList();
      list.sort((a, b) => b.isolationDateTime.compareTo(a.isolationDateTime));
      return list;
    });
  }

  // Get Users with specific LOTO rights
  Future<List<Map<String, dynamic>>> getLotoAuthorizedUsers({
    String? businessId,
    String? plantId,
    String? unitId,
    bool isRequestingAuth = false,
    bool isIsolationAuth = false,
    String? department,
  }) async {
    try {
      final snapshot = await _db.collection('users').get();

      final higherAuthorityRoles = {
        AppRoles.developer.toLowerCase(),
        AppRoles.businessAdmin.toLowerCase(),
        'admin',
        AppRoles.plantAdmin.toLowerCase(),
        AppRoles.plantHod.toLowerCase(),
        AppRoles.unitAdmin.toLowerCase(),
        AppRoles.unitHod.toLowerCase(),
        AppRoles.manager.toLowerCase(),
        AppRoles.deputyManager.toLowerCase(),
        AppRoles.associateManager.toLowerCase(),
        AppRoles.assistantManager.toLowerCase(),
      };

      final List<Map<String, dynamic>> results = [];

      for (final doc in snapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        final uid = (data['uid'] ?? doc.id).toString();
        data['uid'] = uid;

        final displayName = (data['displayName'] ?? data['name'] ?? data['email'] ?? 'User').toString();
        data['displayName'] = displayName;

        final employeeId = (data['employeeId'] ?? '').toString();
        data['employeeId'] = employeeId;

        final role = (data['role'] ?? AppRoles.guest).toString().trim();
        data['role'] = role;

        final userDept = (data['department'] ?? '').toString().trim();
        data['department'] = userDept;

        final userPlant = (data['plantId'] ?? '').toString().trim();
        final userUnit = (data['unitId'] ?? '').toString().trim();

        final isHigherAuthority = higherAuthorityRoles.contains(role.toLowerCase()) || data['isAdmin'] == true;
        final explicitReqAuth = data['isRequestingAuth'] == true;
        final explicitIsoAuth = data['isIsolationAuth'] == true;

        // Scope match: does user belong to the selected plant & unit?
        final matchesPlant = plantId == null || plantId.isEmpty || userPlant.isEmpty || userPlant == plantId;
        final matchesUnit = unitId == null || unitId.isEmpty || userUnit.isEmpty || userUnit == unitId;
        final matchesScope = matchesPlant && matchesUnit;

        if (isIsolationAuth) {
          // Higher authority can give isolation across different plants & units
          // OR user explicitly flagged with isIsolationAuth
          // OR user is in 'Electrical' department AND assigned to the selected plant and unit
          final isElectricalInScope = userDept.toLowerCase() == 'electrical' && matchesScope;
          if (isHigherAuthority || explicitIsoAuth || isElectricalInScope) {
            results.add(data);
          }
        } else if (isRequestingAuth) {
          // Requesting Officer:
          // Higher authority (cross-plant/unit allowed)
          // OR user explicitly flagged with isRequestingAuth
          // OR user belongs to the requesting department AND assigned to the selected plant and unit
          final targetDept = department?.trim().toLowerCase() ?? '';
          final deptMatches = targetDept.isEmpty || userDept.toLowerCase() == targetDept;
          final isDeptInScope = deptMatches && matchesScope;
          if (isHigherAuthority || explicitReqAuth || isDeptInScope) {
            results.add(data);
          }
        } else {
          results.add(data);
        }
      }

      return results;
    } catch (e) {
      debugPrint('Error in getLotoAuthorizedUsers: $e');
      return [];
    }
  }

  // --- GENERAL WORK LOGS ---
  Stream<List<GeneralWorkLogModel>> getGeneralWorkLogsStream({String? plantId, String? unitId, String? status}) {
    return _db.collection('general_work_logs')
        .snapshots()
        .map((snapshot) {
          var list = snapshot.docs.map((doc) => GeneralWorkLogModel.fromMap(doc.data(), doc.id)).toList();
          list.sort((a, b) => b.date.compareTo(a.date));

          if (plantId != null && plantId.isNotEmpty && plantId != 'ALL') {
            list = list.where((l) => l.plantId == null || l.plantId!.isEmpty || l.plantId!.toLowerCase() == plantId.toLowerCase()).toList();
          }
          if (unitId != null && unitId.isNotEmpty && unitId != 'ALL') {
            list = list.where((l) => l.unitId == null || l.unitId!.isEmpty || l.unitId!.toLowerCase() == unitId.toLowerCase()).toList();
          }
          if (status != null && status.isNotEmpty && status != 'All') {
            list = list.where((l) => l.status.toLowerCase() == status.toLowerCase()).toList();
          }
          return list;
        });
  }

  Future<void> addGeneralWorkLog(GeneralWorkLogModel log) async {
    await _db.collection('general_work_logs').add(log.toMap());
    await logActivity(
      userId: log.reportedByUserId,
      action: 'General Work Logged',
      details: '${log.items.length} tasks by ${log.reportedByName} for ${log.equipmentOrArea.isNotEmpty ? log.equipmentOrArea : (log.unitId ?? "Plant")}',
    );
  }

  Future<void> updateGeneralWorkLog(GeneralWorkLogModel log) async {
    await _db.collection('general_work_logs').doc(log.id).update(log.toMap());
  }

  Future<void> deleteGeneralWorkLog(String logId) async {
    await _db.collection('general_work_logs').doc(logId).delete();
  }

  // --- WORKMEN & CONTRACTORS ---
  Stream<List<WorkmanModel>> getWorkmenStream({String? plantId, String? unitId, bool? activeOnly}) {
    return _db.collection('workmen')
        .snapshots()
        .map((snapshot) {
          var list = snapshot.docs.map((doc) => WorkmanModel.fromMap(doc.data(), doc.id)).toList();
          list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          if (activeOnly == true) {
            list = list.where((w) => w.isActive).toList();
          }
          if (plantId != null && plantId.isNotEmpty && plantId != 'ALL') {
            list = list.where((w) => w.plantId == null || w.plantId!.isEmpty || w.plantId!.toLowerCase() == plantId.toLowerCase()).toList();
          }
          if (unitId != null && unitId.isNotEmpty && unitId != 'ALL') {
            list = list.where((w) => w.unitId == null || w.unitId!.isEmpty || w.unitId!.toLowerCase() == unitId.toLowerCase()).toList();
          }
          return list;
        });
  }

  Future<void> addWorkman(WorkmanModel workman) async {
    await _db.collection('workmen').add(workman.toMap());
  }

  Future<void> updateWorkman(WorkmanModel workman) async {
    await _db.collection('workmen').doc(workman.id).update(workman.toMap());
  }

  Future<void> deleteWorkman(String workmanId) async {
    await _db.collection('workmen').doc(workmanId).delete();
  }
}


