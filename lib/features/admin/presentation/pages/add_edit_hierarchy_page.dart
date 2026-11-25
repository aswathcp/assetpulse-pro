import 'package:material_ui/material_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:asset_pulse_pro/core/constants/app_colors.dart';
import 'package:asset_pulse_pro/core/services/auth_service.dart';
import 'package:asset_pulse_pro/core/services/firestore_service.dart';
import 'package:asset_pulse_pro/core/services/hierarchy_service.dart';
import 'package:asset_pulse_pro/core/widgets/searchable_selection_field.dart';
import 'package:asset_pulse_pro/features/assets/data/models/location_model.dart';
import 'package:asset_pulse_pro/features/assets/data/models/panel_room_model.dart';
import 'package:asset_pulse_pro/features/assets/data/models/panel_model.dart';
import 'package:asset_pulse_pro/features/assets/data/models/feeder_model.dart';
import 'package:asset_pulse_pro/features/assets/data/models/transformer_model.dart';
import 'package:asset_pulse_pro/features/assets/data/models/master_equipment_model.dart';

class AddEditHierarchyItemPage extends StatefulWidget {
  final String collection;
  final String title;
  final Map<String, dynamic> baseData;
  final String userRole;
  final bool isEditing;
  final Function(Map<String, dynamic>)? onSave;

  const AddEditHierarchyItemPage({
    super.key,
    required this.collection,
    required this.title,
    required this.baseData,
    required this.userRole,
    this.isEditing = false,
    this.onSave,
  });

  @override
  State<AddEditHierarchyItemPage> createState() => _AddEditHierarchyItemPageState();
}

class _AddEditHierarchyItemPageState extends State<AddEditHierarchyItemPage> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _formData = {};
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _ratingController = TextEditingController();

  bool _isSaving = false;
  bool _isLoadingRef = true;

  // Reference Data
  List<LocationModel> _refLocations = [];
  List<PanelRoomModel> _refPanelRooms = [];
  List<PanelModel> _refPanels = [];
  List<FeederModel> _refFeeders = [];

  @override
  void initState() {
    super.initState();
    _formData.addAll(widget.baseData);
    final user = AuthService().currentUser;
    _formData['businessId'] = widget.baseData['businessId'] ?? HierarchyService().currentBusinessId;
    if (!widget.isEditing) {
      _formData['createdBy'] = user?.uid;
    }
    _formData['modifiedBy'] = user?.uid;

    final rawId = (_formData['id'] ?? 
        _formData['Fault_Code'] ?? 
        _formData['faultCode'] ?? 
        _formData['ODC_ID'] ?? 
        _formData['odcId'] ?? '').toString();
    final isCatalog = widget.collection == 'fault_types' || widget.collection == 'odc' || widget.collection == 'odc_causes';
    _idController.text = widget.isEditing
        ? HierarchyService.stripPrefix(rawId, _formData['plantId'] ?? (isCatalog ? 'GLOBAL' : ''), _formData['unitId'] ?? (isCatalog ? 'ALL' : ''))
        : '';
    _nameController.text = (_formData['name'] ?? 
        _formData['Fault_Name'] ?? 
        _formData['faultName'] ?? 
        _formData['Root_Cause'] ?? 
        _formData['cause'] ?? '').toString();
    _descController.text = _formData['description']?.toString() ?? '';
    if (_formData['ratingKva'] != null) {
      _ratingController.text = _formData['ratingKva'].toString();
    }

    _loadReferenceData();
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _ratingController.dispose();
    super.dispose();
  }

  Future<void> _loadReferenceData() async {
    setState(() => _isLoadingRef = true);
    try {
      final plantId = _formData['plantId'] as String?;
      final unitId = _formData['unitId'] as String?;

      final db = FirebaseFirestore.instance;
      if (unitId != null && plantId != null) {
        if (['panel_rooms', 'panels', 'transformers', 'master_equipments'].contains(widget.collection)) {
          final locs = await db.collection('locations')
              .where('unitId', isEqualTo: unitId)
              .where('plantId', isEqualTo: plantId)
              .get();
          _refLocations = locs.docs.map((e) => LocationModel.fromMap(e.data(), e.id)).toList();
        }

        if (['panels', 'master_equipments'].contains(widget.collection)) {
          final rooms = await db.collection('panel_rooms')
              .where('unitId', isEqualTo: unitId)
              .where('plantId', isEqualTo: plantId)
              .get();
          _refPanelRooms = rooms.docs.map((e) => PanelRoomModel.fromMap(e.data(), e.id)).toList();
        }

        if (['feeders', 'transformers', 'master_equipments'].contains(widget.collection)) {
          final pnlSnapshot = await db.collection('panels')
              .where('unitId', isEqualTo: unitId)
              .where('plantId', isEqualTo: plantId)
              .get();
          _refPanels = pnlSnapshot.docs.map((e) => PanelModel.fromMap(e.data(), e.id)).toList();
        }

        if (['feeders', 'transformers', 'master_equipments'].contains(widget.collection)) {
          final fdrSnapshot = await db.collection('feeders')
              .where('unitId', isEqualTo: unitId)
              .where('plantId', isEqualTo: plantId)
              .get();
          _refFeeders = fdrSnapshot.docs.map((e) => FeederModel.fromMap(e.data(), e.id)).toList();
        }
      }
    } catch (e) {
      debugPrint('Error loading references: $e');
    } finally {
      if (mounted) setState(() => _isLoadingRef = false);
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final enteredId = _idController.text.trim();
    if (enteredId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID is required.')),
      );
      return;
    }

    final plantId = _formData['plantId']?.toString().trim() ?? '';
    final unitId = _formData['unitId']?.toString().trim() ?? '';
    final isCatalog = widget.collection == 'fault_types' || widget.collection == 'odc' || widget.collection == 'odc_causes';

    // Enforce plant/unit prefix for both catalogs and hierarchy items
    final resolvedP = (plantId.isNotEmpty && plantId != 'GLOBAL') ? plantId : 'GLOBAL';
    final resolvedU = (unitId.isNotEmpty && unitId != 'GLOBAL' && unitId != 'ALL') ? unitId : 'ALL';
    final fullId = isCatalog
        ? HierarchyService.prefixId(enteredId, resolvedP, resolvedU)
        : HierarchyService.prefixId(enteredId, plantId, unitId);
    _formData['id'] = fullId;
    _formData['name'] = _nameController.text.trim();
    _formData['description'] = _descController.text.trim();
    if (plantId.isNotEmpty) _formData['plantId'] = plantId;
    if (unitId.isNotEmpty) _formData['unitId'] = unitId;

    setState(() => _isSaving = true);

    try {
      final currentUserUid = AuthService().currentUser?.uid;
      final dtCreatedAt = _formData['createdAt'] != null
          ? (_formData['createdAt'] is Timestamp
              ? (_formData['createdAt'] as Timestamp).toDate()
              : (_formData['createdAt'] as DateTime))
          : DateTime.now();

      final createdBy = _formData['createdBy'] ?? currentUserUid;

      if (widget.collection == 'locations') {
        final loc = LocationModel(
          id: _formData['id'],
          unitId: unitId,
          plantId: plantId,
          name: _formData['name'],
          description: _formData['description'] ?? '',
          createdAt: dtCreatedAt,
          createdBy: createdBy,
          modifiedBy: currentUserUid,
        );
        await FirestoreService().saveLocation(loc);
      } else if (widget.collection == 'panel_rooms') {
        final rawLoc = _formData['locationId']?.toString().trim() ?? '';
        final room = PanelRoomModel(
          id: _formData['id'],
          unitId: unitId,
          plantId: plantId,
          locationId: rawLoc.isNotEmpty ? HierarchyService.prefixId(rawLoc, plantId, unitId) : '',
          name: _formData['name'],
          description: _formData['description'] ?? '',
          createdAt: dtCreatedAt,
          createdBy: createdBy,
          modifiedBy: currentUserUid,
        );
        await FirestoreService().savePanelRoom(room);
      } else if (widget.collection == 'panels') {
        final rawRoom = _formData['panelRoomId']?.toString().trim() ?? '';
        final fullRoom = rawRoom.isNotEmpty ? HierarchyService.prefixId(rawRoom, plantId, unitId) : '';

        // Auto-resolve locationId from parent panel room
        String resolvedLoc = '';
        if (fullRoom.isNotEmpty) {
          final matchedRoom = _refPanelRooms.firstWhere(
            (r) => r.id == fullRoom || r.id == rawRoom,
            orElse: () => PanelRoomModel(id: '', unitId: '', plantId: '', name: ''),
          );
          if (matchedRoom.locationId.isNotEmpty) {
            resolvedLoc = matchedRoom.locationId;
          }
        }

        final busSecRaw = _formData['busSections'];
        final List<String> parsedBusSecs = HierarchyService.parseBusSections(busSecRaw);

        final panel = PanelModel(
          id: _formData['id'],
          plantId: plantId,
          unitId: unitId,
          locationId: resolvedLoc.isNotEmpty ? resolvedLoc : fullRoom,
          panelRoomId: fullRoom,
          name: _formData['name'],
          type: _formData['type'] ?? 'MCC',
          description: _formData['description'] ?? '',
          voltageLevel: _formData['voltageLevel'] ?? '415V',
          busSections: parsedBusSecs,
          createdAt: dtCreatedAt,
          createdBy: createdBy,
          modifiedBy: currentUserUid,
        );
        await FirestoreService().savePanel(panel);
      } else if (widget.collection == 'feeders') {
        final rawUpstream = _formData['upstreamFeederId']?.toString().trim();
        final rawPanel = _formData['panelId']?.toString().trim() ?? '';
        final fullPanel = rawPanel.isNotEmpty ? HierarchyService.prefixId(rawPanel, plantId, unitId) : '';

        final feeder = FeederModel(
          id: _formData['id'],
          plantId: plantId,
          unitId: unitId,
          panelId: fullPanel,
          name: _formData['name'],
          type: _formData['type'] ?? 'Feeder',
          description: _formData['description'] ?? '',
          busSection: HierarchyService.normalizeFeederBusSection(_formData['busSection']),
          operatingState: _formData['operatingState'] ?? 'CLOSED',
          upstreamFeederId: (rawUpstream != null && rawUpstream.isNotEmpty && rawUpstream != 'None')
              ? HierarchyService.prefixId(rawUpstream, plantId, unitId)
              : null,
          createdAt: dtCreatedAt,
          createdBy: createdBy,
          modifiedBy: currentUserUid,
        );
        await FirestoreService().saveFeeder(feeder);
      } else if (widget.collection == 'transformers') {
        final tertVolt = _formData['tertiaryVoltage']?.toString().trim();
        final cleanTertVolt = (tertVolt == null || tertVolt.isEmpty || tertVolt == 'None') ? null : tertVolt;
        final secTarget = _formData['secondaryTargetPanelId']?.toString().trim();
        final cleanSecTarget = (secTarget == null || secTarget.isEmpty || secTarget == 'None')
            ? null
            : HierarchyService.prefixId(secTarget, plantId, unitId);
        final tertTarget = _formData['tertiaryTargetPanelId']?.toString().trim();
        final cleanTertTarget = (tertTarget == null || tertTarget.isEmpty || tertTarget == 'None')
            ? null
            : HierarchyService.prefixId(tertTarget, plantId, unitId);
        final srcFeeder = _formData['primarySourceFeederId']?.toString().trim();
        final cleanSrcFeeder = (srcFeeder == null || srcFeeder.isEmpty || srcFeeder == 'None')
            ? null
            : HierarchyService.prefixId(srcFeeder, plantId, unitId);
        final rawLoc = _formData['locationId']?.toString().trim() ?? '';

        final transformer = TransformerModel(
          id: _formData['id'],
          name: _formData['name'] ?? '',
          windingType: _formData['windingType'] ?? 'two_winding',
          ratingKva: double.tryParse(_ratingController.text.trim()) ?? 1000.0,
          primaryVoltage: _formData['primaryVoltage'] ?? '11kV',
          secondaryVoltage: _formData['secondaryVoltage'] ?? '415V',
          tertiaryVoltage: cleanTertVolt,
          primarySourceFeederId: cleanSrcFeeder,
          secondaryTargetPanelId: cleanSecTarget,
          tertiaryTargetPanelId: cleanTertTarget,
          locationId: rawLoc.isNotEmpty ? HierarchyService.prefixId(rawLoc, plantId, unitId) : '',
          plantId: plantId,
          unitId: unitId,
          createdAt: dtCreatedAt,
          createdBy: createdBy,
          modifiedBy: currentUserUid,
        );
        await FirestoreService().saveTransformer(transformer);
      } else if (widget.collection == 'master_equipments') {
        final rawLoc = _formData['locationId']?.toString().trim() ?? '';
        final rawRoom = _formData['panelRoomId']?.toString().trim() ?? '';
        final rawPanel = _formData['panelId']?.toString().trim() ?? '';
        final rawFeeder = _formData['feederId']?.toString().trim() ?? '';

        final me = MasterEquipmentModel(
          id: _formData['id'],
          unitId: unitId,
          plantId: plantId,
          name: _formData['name'] ?? '',
          area: _formData['area'] ?? rawLoc,
          type: _formData['type'] ?? 'Motor',
          locationId: rawLoc.isNotEmpty ? HierarchyService.prefixId(rawLoc, plantId, unitId) : '',
          panelRoomId: (rawRoom.isNotEmpty && rawRoom != 'None') ? HierarchyService.prefixId(rawRoom, plantId, unitId) : null,
          panelId: (rawPanel.isNotEmpty && rawPanel != 'None') ? HierarchyService.prefixId(rawPanel, plantId, unitId) : null,
          feederId: (rawFeeder.isNotEmpty && rawFeeder != 'None') ? HierarchyService.prefixId(rawFeeder, plantId, unitId) : null,
          description: _formData['description'] ?? '',
          createdAt: dtCreatedAt,
          createdBy: createdBy,
          modifiedAt: DateTime.now(),
          modifiedBy: currentUserUid,
        );
        await FirebaseFirestore.instance
            .collection('master_equipments')
            .doc(me.id)
            .set(me.toMap(), SetOptions(merge: true));
      } else if (widget.collection == 'fault_types') {
        _formData['id'] = fullId;
        _formData['faultCode'] = fullId;
        _formData['Fault_Code'] = fullId;
        _formData['name'] = _nameController.text.trim();
        _formData['Fault_Name'] = _nameController.text.trim();
        _formData['category'] = _formData['discipline'] ?? _formData['category'] ?? 'Electrical';
        _formData['discipline'] = _formData['category'];
        _formData['Discipline'] = _formData['category'];
        _formData['targetEquipment'] = _formData['targetEquipment'] ?? _formData['Target_Equipment'] ?? _formData['equipmentType'] ?? '';
        _formData['equipmentType'] = _formData['targetEquipment'];
        _formData['Target_Equipment'] = _formData['targetEquipment'];
        _formData['severity'] = _formData['severity'] ?? _formData['Default_Severity'] ?? 'Critical';
        _formData['Default_Severity'] = _formData['severity'];
        _formData['targetSlaHours'] = _formData['targetSlaHours'] ?? _formData['Target_SLA_Hours'] ?? 2;
        _formData['Target_SLA_Hours'] = _formData['targetSlaHours'];
        _formData['diagnosticChecks'] = _formData['diagnosticChecks'] ?? _formData['Diagnostic_Checks'] ?? '';
        _formData['Diagnostic_Checks'] = _formData['diagnosticChecks'];
        _formData['correctiveAction'] = _formData['correctiveAction'] ?? _formData['Corrective_Action'] ?? '';
        _formData['Corrective_Action'] = _formData['correctiveAction'];
        _formData['plantId'] = plantId.isNotEmpty ? plantId : 'GLOBAL';
        _formData['unitId'] = unitId.isNotEmpty ? unitId : 'GLOBAL';
        _formData['Plant_ID'] = _formData['plantId'];
        _formData['Unit_ID'] = _formData['unitId'];
        _formData['modifiedBy'] = currentUserUid;
        _formData['updatedAt'] = DateTime.now();
        if (!widget.isEditing) {
          _formData['createdBy'] = currentUserUid;
          _formData['createdAt'] = dtCreatedAt;
        }
        await FirestoreService().batchSave(widget.collection, [_formData]);
      } else if (widget.collection == 'odc' || widget.collection == 'odc_causes') {
        _formData['id'] = fullId;
        _formData['odcId'] = fullId;
        _formData['ODC_ID'] = fullId;
        _formData['discipline'] = _formData['discipline'] ?? _formData['category'] ?? 'Electrical';
        _formData['Discipline'] = _formData['discipline'];
        _formData['category'] = _formData['discipline'];
        _formData['equipmentCategory'] = _formData['equipmentCategory'] ?? _formData['Equipment_Category'] ?? '';
        _formData['Equipment_Category'] = _formData['equipmentCategory'];
        _formData['objectPart'] = _formData['objectPart'] ?? _formData['Object_Part'] ?? '';
        _formData['Object_Part'] = _formData['objectPart'];
        _formData['damage'] = _formData['damage'] ?? _formData['damageMode'] ?? _formData['Damage_Mode'] ?? '';
        _formData['damageMode'] = _formData['damage'];
        _formData['Damage_Mode'] = _formData['damage'];
        _formData['cause'] = _formData['cause'] ?? _formData['rootCause'] ?? _formData['Root_Cause'] ?? _nameController.text.trim();
        _formData['rootCause'] = _formData['cause'];
        _formData['Root_Cause'] = _formData['cause'];
        _formData['name'] = _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : _formData['cause'];
        _formData['isoCode'] = _formData['isoCode'] ?? _formData['ISO_14224_Code'] ?? '';
        _formData['ISO_14224_Code'] = _formData['isoCode'];
        _formData['severity'] = _formData['severity'] ?? _formData['Severity'] ?? 'Critical';
        _formData['Severity'] = _formData['severity'];
        _formData['recommendedAction'] = _formData['recommendedAction'] ?? _formData['Recommended_Action'] ?? '';
        _formData['Recommended_Action'] = _formData['recommendedAction'];
        _formData['plantId'] = plantId.isNotEmpty ? plantId : 'GLOBAL';
        _formData['unitId'] = unitId.isNotEmpty ? unitId : 'GLOBAL';
        _formData['Plant_ID'] = _formData['plantId'];
        _formData['Unit_ID'] = _formData['unitId'];
        _formData['modifiedBy'] = currentUserUid;
        _formData['updatedAt'] = DateTime.now();
        if (!widget.isEditing) {
          _formData['createdBy'] = currentUserUid;
          _formData['createdAt'] = dtCreatedAt;
        }
        final saveColl = widget.collection == 'odc_causes' ? 'odc' : widget.collection;
        await FirestoreService().batchSave(saveColl, [_formData]);
      } else {
        _formData['modifiedBy'] = currentUserUid;
        _formData['updatedAt'] = DateTime.now();
        if (!widget.isEditing) {
          _formData['createdBy'] = currentUserUid;
          _formData['createdAt'] = dtCreatedAt;
        }
        await FirestoreService().batchSave(widget.collection, [_formData]);
      }

      if (widget.onSave != null) {
        widget.onSave!(_formData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.title} saved successfully!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final actionLabel = widget.isEditing ? 'Edit ${widget.title}' : 'Add New ${widget.title}';

    return Scaffold(
      appBar: AppBar(
        title: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _handleSave,
              icon: _isSaving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check, size: 18),
              label: Text(_isSaving ? 'Saving...' : 'Save', style: const TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: _isLoadingRef
          ? _buildSkeletonForm(isDark)
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Scope indicator card
                      _buildScopeCard(isDark)
                          .animate()
                          .fadeIn(duration: 300.ms)
                          .slideY(begin: 0.03, end: 0, curve: Curves.easeOutQuad),
                      const SizedBox(height: 16),

                      // Primary Identification Card
                      _buildCard(
                        title: 'Identification',
                        icon: Icons.badge,
                        children: [
                          TextFormField(
                            controller: _idController,
                            enabled: !widget.isEditing,
                            decoration: InputDecoration(
                              labelText: 'ID / Code (Unique)',
                              hintText: 'e.g. ${widget.collection == "panels" ? "MCC-01" : widget.collection == "feeders" ? "INC-01" : widget.collection == "fault_types" ? "FT-ELEC-01" : (widget.collection == "odc" || widget.collection == "odc_causes") ? "ODC-01" : "TAG-01"}',
                              helperText: (widget.collection == 'fault_types' || widget.collection == 'odc' || widget.collection == 'odc_causes')
                                  ? 'Standard unique code'
                                  : 'System auto-prefixes plant and unit code',
                              prefixIcon: const Icon(Icons.qr_code, size: 20),
                              border: const OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'ID is required' : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: '${widget.title} Name',
                              hintText: widget.collection == 'fault_types'
                                  ? 'e.g. Overload Tripping, Bearing Seizure'
                                  : (widget.collection == 'odc' || widget.collection == 'odc_causes')
                                      ? 'e.g. Normal Wear & Tear, Moisture Ingress'
                                      : 'Descriptive title',
                              prefixIcon: const Icon(Icons.title, size: 20),
                              border: const OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                          ),
                        ],
                      )
                          .animate()
                          .fadeIn(duration: 350.ms, delay: 50.ms)
                          .slideY(begin: 0.03, end: 0, curve: Curves.easeOutQuad),
                      const SizedBox(height: 16),

                      // Collection-specific Configuration Card
                      _buildCard(
                        title: 'Configuration & Details',
                        icon: Icons.tune,
                        children: _buildCollectionSpecificFields(),
                      )
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 100.ms)
                          .slideY(begin: 0.03, end: 0, curve: Curves.easeOutQuad),
                      const SizedBox(height: 16),

                      // Description / Notes Card (Only for hierarchy, hidden for simple Fault Types / ODC)
                      if (widget.collection != 'fault_types' && widget.collection != 'odc' && widget.collection != 'odc_causes') ...[
                        _buildCard(
                          title: 'Notes & Description',
                          icon: Icons.notes,
                          children: [
                            TextFormField(
                              controller: _descController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Description / Purpose',
                                hintText: 'Enter functional operational notes or area details...',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        )
                            .animate()
                            .fadeIn(duration: 450.ms, delay: 150.ms)
                            .slideY(begin: 0.03, end: 0, curve: Curves.easeOutQuad),
                        const SizedBox(height: 16),
                      ],
                      const SizedBox(height: 12),

                      // Bottom Save Button
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _handleSave,
                        icon: _isSaving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save, size: 20),
                        label: Text(_isSaving ? 'Saving...' : 'Save ${widget.title}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 500.ms, delay: 200.ms)
                          .slideY(begin: 0.03, end: 0, curve: Curves.easeOutQuad),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSkeletonForm(bool isDark) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildSkeletonCard(height: 72, isDark: isDark),
            const SizedBox(height: 16),
            _buildSkeletonCard(height: 180, isDark: isDark),
            const SizedBox(height: 16),
            _buildSkeletonCard(height: 240, isDark: isDark),
            const SizedBox(height: 16),
            _buildSkeletonCard(height: 110, isDark: isDark),
            const SizedBox(height: 24),
            _buildSkeletonCard(height: 52, isDark: isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonCard({required double height, required bool isDark}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 140,
            height: 14,
            decoration: BoxDecoration(
              color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          if (height > 90) ...[
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ],
      ),
    )
    .animate(onPlay: (c) => c.repeat())
    .shimmer(duration: 1200.ms, color: isDark ? Colors.white12 : Colors.black12);
  }

  Widget _buildScopeCard(bool isDark) {
    final plant = _formData['plantId']?.toString().trim() ?? '';
    final unit = _formData['unitId']?.toString().trim() ?? '';
    final isCatalog = widget.collection == 'fault_types' || widget.collection == 'odc' || widget.collection == 'odc_causes';
    final isGlobal = plant.isEmpty || plant == '-' || plant == 'GLOBAL' || plant == 'ALL' || plant == 'null';

    final plantName = HierarchyService().getPlantNames()[plant] ?? plant;
    final unitName = HierarchyService().getUnitNamesForPlant(plant)[unit] ?? unit;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(isGlobal ? Icons.public : Icons.corporate_fare, size: 22, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ORGANIZATIONAL SCOPE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: AppColors.accent)),
                const SizedBox(height: 2),
                Text(
                  isGlobal
                      ? (isCatalog ? 'Global Master Catalog • Enterprise Wide (All Plants & Units)' : 'Global Enterprise Scope')
                      : '$plant ($plantName) • $unit ($unitName)',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required IconData icon, required List<Widget> children}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 20),
          ...children,
        ],
      ),
    );
  }

  List<Widget> _buildCollectionSpecificFields() {
    final plantId = _formData['plantId']?.toString() ?? '';
    final unitId = _formData['unitId']?.toString() ?? '';

    if (widget.collection == 'locations') {
      return [
        const Text('Physical Plant Area boundaries. Electrical panel rooms and equipment are housed within physical areas.',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
      ];
    } else if (widget.collection == 'panel_rooms') {
      final safeLoc = _refLocations.any((e) => e.id == _formData['locationId'])
          ? _formData['locationId']
          : (_refLocations.isNotEmpty ? _refLocations.first.id : null);

      return [
        SearchableSelectionField<String>(
          label: 'Physical Area',
          hintText: 'Select parent location',
          helperText: 'Physical plant zone housing this electrical room',
          selectedValue: safeLoc,
          prefixIcon: Icons.map,
          items: _refLocations.map((e) => SearchableItem<String>(
            value: e.id,
            label: e.name,
            subtitle: 'ID: ${HierarchyService.stripPrefix(e.id, plantId, unitId)}',
            leading: const Icon(Icons.location_on, size: 20, color: AppColors.accent),
          )).toList(),
          onChanged: (v) => setState(() => _formData['locationId'] = v),
          validator: (v) => v == null || v.isEmpty ? 'Location area is required' : null,
        ),
      ];
    } else if (widget.collection == 'panels') {
      final safeRoom = _refPanelRooms.any((e) => e.id == _formData['panelRoomId'])
          ? _formData['panelRoomId']
          : (_refPanelRooms.isNotEmpty ? _refPanelRooms.first.id : null);

      final safeBusSec = HierarchyService.formatBusSectionsForDisplay(_formData['busSections']);

      return [
        SearchableSelectionField<String>(
          label: 'Panel Room / Substation',
          hintText: 'Select electrical room',
          helperText: 'Switchgear / control room housing this panel',
          selectedValue: safeRoom,
          prefixIcon: Icons.room_preferences,
          items: _refPanelRooms.map((e) => SearchableItem<String>(
            value: e.id,
            label: e.name,
            subtitle: 'ID: ${HierarchyService.stripPrefix(e.id, plantId, unitId)}',
            leading: const Icon(Icons.meeting_room, size: 20, color: AppColors.accent),
          )).toList(),
          onChanged: (v) => setState(() => _formData['panelRoomId'] = v),
          validator: (v) => v == null || v.isEmpty ? 'Panel Room is required' : null,
        ),
        const SizedBox(height: 14),

        SearchableSelectionField<String>(
          label: 'Panel Category',
          hintText: 'Select category',
          selectedValue: _formData['type'] ?? 'MCC',
          prefixIcon: Icons.category,
          items: HierarchyService.panelTypes.map((t) => SearchableItem<String>(
            value: t,
            label: t,
          )).toList(),
          onChanged: (v) => setState(() => _formData['type'] = v ?? 'MCC'),
        ),
        const SizedBox(height: 14),

        SearchableSelectionField<String>(
          label: 'Voltage Level',
          hintText: 'Select operating voltage',
          selectedValue: _formData['voltageLevel'] ?? '415V',
          prefixIcon: Icons.bolt,
          items: HierarchyService.voltageLevels.map((v) => SearchableItem<String>(
            value: v,
            label: v,
          )).toList(),
          onChanged: (v) => setState(() => _formData['voltageLevel'] = v ?? '415V'),
        ),
        const SizedBox(height: 14),

        SearchableSelectionField<String>(
          label: 'Bus Section Configuration',
          hintText: 'Select bus arrangement',
          helperText: 'Split bus enables dual-section SLD rendering with bus coupler',
          selectedValue: safeBusSec,
          prefixIcon: Icons.power_input,
          items: HierarchyService.busSectionOptions.map((b) => SearchableItem<String>(
            value: b,
            label: b,
            subtitle: b == 'SEC-1 & 2' ? 'Split bus (Section 1 and Section 2)' : 'Single unified busbar',
          )).toList(),
          onChanged: (v) => setState(() => _formData['busSections'] = v ?? 'MAIN'),
        ),
      ];
    } else if (widget.collection == 'feeders') {
      final safePanel = _refPanels.any((e) => e.id == _formData['panelId'])
          ? _formData['panelId']
          : (_refPanels.isNotEmpty ? _refPanels.first.id : null);

      final safeBusSec = HierarchyService.normalizeFeederBusSection(_formData['busSection']);

      final currentUpstream = _formData['upstreamFeederId']?.toString() ?? '';
      final List<SearchableItem<String>> upstreamItems = [
        const SearchableItem<String>(value: '', label: 'None (Root Source / Grid)'),
        ..._refFeeders.where((f) => f.id != _formData['id']).map((f) => SearchableItem<String>(
          value: f.id,
          label: f.name,
          subtitle: 'ID: ${HierarchyService.stripPrefix(f.id, plantId, unitId)} • ${f.type}',
          leading: const Icon(Icons.alt_route, size: 20, color: AppColors.accent),
        )),
      ];

      return [
        SearchableSelectionField<String>(
          label: 'Parent Panel',
          hintText: 'Select hosting switchboard',
          helperText: 'Panel housing this feeder breaker',
          selectedValue: safePanel,
          prefixIcon: Icons.electric_bolt,
          items: _refPanels.map((e) => SearchableItem<String>(
            value: e.id,
            label: e.name,
            subtitle: 'ID: ${HierarchyService.stripPrefix(e.id, plantId, unitId)} • ${e.voltageLevel} • ${e.type}',
            leading: const Icon(Icons.electric_bolt, size: 20, color: AppColors.accent),
          )).toList(),
          onChanged: (v) => setState(() => _formData['panelId'] = v),
          validator: (v) => v == null || v.isEmpty ? 'Parent panel is required' : null,
        ),
        const SizedBox(height: 14),

        SearchableSelectionField<String>(
          label: 'Feeder Function Type',
          hintText: 'Select type',
          selectedValue: _formData['type'] ?? 'Feeder',
          prefixIcon: Icons.category,
          items: HierarchyService.feederTypes.map((t) => SearchableItem<String>(
            value: t,
            label: t,
          )).toList(),
          onChanged: (v) => setState(() => _formData['type'] = v ?? 'Feeder'),
        ),
        const SizedBox(height: 14),

        SearchableSelectionField<String>(
          label: 'Bus Section Connection',
          hintText: 'Select connected bus section',
          selectedValue: safeBusSec,
          prefixIcon: Icons.linear_scale,
          items: HierarchyService.feederBusSectionOptions.map((b) => SearchableItem<String>(
            value: b,
            label: b,
            subtitle: b == 'SEC-1 & 2' ? 'Bridging Section 1 and 2 (Bus Coupler)' : null,
          )).toList(),
          onChanged: (v) => setState(() => _formData['busSection'] = v ?? 'MAIN'),
        ),
        const SizedBox(height: 14),

        SearchableSelectionField<String>(
          label: 'Operating Breaker State',
          hintText: 'Select state',
          selectedValue: _formData['operatingState'] ?? 'CLOSED',
          prefixIcon: Icons.toggle_on,
          items: HierarchyService.feederOperatingStates.map((s) => SearchableItem<String>(
            value: s,
            label: s,
          )).toList(),
          onChanged: (v) => setState(() => _formData['operatingState'] = v ?? 'CLOSED'),
        ),
        const SizedBox(height: 14),

        SearchableSelectionField<String>(
          label: 'Upstream Power Source',
          hintText: 'Select upstream source',
          helperText: 'For Incomers/Ties: upstream feeder supplying this circuit',
          selectedValue: currentUpstream,
          prefixIcon: Icons.call_split,
          items: upstreamItems,
          onChanged: (v) => setState(() => _formData['upstreamFeederId'] = v ?? ''),
        ),
      ];
    } else if (widget.collection == 'transformers') {
      final safeLoc = _refLocations.any((e) => e.id == _formData['locationId'])
          ? _formData['locationId']
          : (_refLocations.isNotEmpty ? _refLocations.first.id : null);

      final winding = _formData['windingType'] ?? 'two_winding';

      return [
        SearchableSelectionField<String>(
          label: 'Transformer Winding Type',
          hintText: 'Select winding',
          selectedValue: winding,
          prefixIcon: Icons.account_tree,
          items: HierarchyService.transformerWindingTypes.map((w) => SearchableItem<String>(
            value: w,
            label: w == 'two_winding' ? 'Two Winding (Primary + Secondary)' : 'Three Winding (Primary + Secondary + Tertiary)',
          )).toList(),
          onChanged: (v) => setState(() => _formData['windingType'] = v ?? 'two_winding'),
        ),
        const SizedBox(height: 14),

        TextFormField(
          controller: _ratingController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Rating (kVA)',
            hintText: 'e.g. 5500',
            prefixIcon: Icon(Icons.flash_on, size: 20),
            border: OutlineInputBorder(),
          ),
          validator: (v) => (v == null || double.tryParse(v.trim()) == null) ? 'Enter valid kVA rating' : null,
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: SearchableSelectionField<String>(
                label: 'Primary Voltage',
                selectedValue: _formData['primaryVoltage'] ?? '11kV',
                prefixIcon: Icons.bolt,
                items: HierarchyService.voltageLevels.map((v) => SearchableItem<String>(value: v, label: v)).toList(),
                onChanged: (v) => setState(() => _formData['primaryVoltage'] = v ?? '11kV'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SearchableSelectionField<String>(
                label: 'Secondary Voltage',
                selectedValue: _formData['secondaryVoltage'] ?? '415V',
                prefixIcon: Icons.bolt,
                items: HierarchyService.voltageLevels.map((v) => SearchableItem<String>(value: v, label: v)).toList(),
                onChanged: (v) => setState(() => _formData['secondaryVoltage'] = v ?? '415V'),
              ),
            ),
          ],
        ),

        if (winding == 'three_winding') ...[
          const SizedBox(height: 14),
          SearchableSelectionField<String>(
            label: 'Tertiary Voltage',
            selectedValue: _formData['tertiaryVoltage'] ?? '415V',
            prefixIcon: Icons.bolt,
            items: HierarchyService.tertiaryVoltageLevels.map((v) => SearchableItem<String>(value: v, label: v)).toList(),
            onChanged: (v) => setState(() => _formData['tertiaryVoltage'] = v),
          ),
        ],

        const SizedBox(height: 14),
        SearchableSelectionField<String>(
          label: 'Primary Source Feeder',
          hintText: 'Feeder supplying primary winding',
          selectedValue: _formData['primarySourceFeederId']?.toString() ?? '',
          prefixIcon: Icons.arrow_downward,
          items: [
            const SearchableItem<String>(value: '', label: 'None (Grid / Switchyard direct)'),
            ..._refFeeders.map((f) => SearchableItem<String>(
              value: f.id,
              label: f.name,
              subtitle: 'ID: ${HierarchyService.stripPrefix(f.id, plantId, unitId)}',
            )),
          ],
          onChanged: (v) => setState(() => _formData['primarySourceFeederId'] = v ?? ''),
        ),

        const SizedBox(height: 14),
        SearchableSelectionField<String>(
          label: 'Secondary Target Panel',
          hintText: 'Switchboard fed by secondary winding',
          selectedValue: _formData['secondaryTargetPanelId']?.toString() ?? '',
          prefixIcon: Icons.arrow_upward,
          items: [
            const SearchableItem<String>(value: '', label: 'None'),
            ..._refPanels.map((p) => SearchableItem<String>(
              value: p.id,
              label: p.name,
              subtitle: 'ID: ${HierarchyService.stripPrefix(p.id, plantId, unitId)} • ${p.voltageLevel}',
            )),
          ],
          onChanged: (v) => setState(() => _formData['secondaryTargetPanelId'] = v ?? ''),
        ),

        if (winding == 'three_winding') ...[
          const SizedBox(height: 14),
          SearchableSelectionField<String>(
            label: 'Tertiary Target Panel',
            hintText: 'Switchboard fed by tertiary winding',
            selectedValue: _formData['tertiaryTargetPanelId']?.toString() ?? '',
            prefixIcon: Icons.arrow_upward,
            items: [
              const SearchableItem<String>(value: '', label: 'None'),
              ..._refPanels.map((p) => SearchableItem<String>(
                value: p.id,
                label: p.name,
                subtitle: 'ID: ${HierarchyService.stripPrefix(p.id, plantId, unitId)} • ${p.voltageLevel}',
              )),
            ],
            onChanged: (v) => setState(() => _formData['tertiaryTargetPanelId'] = v ?? ''),
          ),
        ],

        const SizedBox(height: 14),
        SearchableSelectionField<String>(
          label: 'Physical Area / Yard',
          hintText: 'Select transformer yard area',
          selectedValue: safeLoc,
          prefixIcon: Icons.place,
          items: _refLocations.map((l) => SearchableItem<String>(
            value: l.id,
            label: l.name,
            subtitle: 'ID: ${HierarchyService.stripPrefix(l.id, plantId, unitId)}',
          )).toList(),
          onChanged: (v) => setState(() => _formData['locationId'] = v),
        ),
      ];
    } else if (widget.collection == 'master_equipments') {
      final safeLoc = _refLocations.any((e) => e.id == _formData['locationId'])
          ? _formData['locationId']
          : (_refLocations.isNotEmpty ? _refLocations.first.id : null);
      final safeRoom = _refPanelRooms.any((e) => e.id == _formData['panelRoomId'])
          ? _formData['panelRoomId']
          : null;
      final safePanel = _refPanels.any((e) => e.id == _formData['panelId'])
          ? _formData['panelId']
          : null;
      final safeFeeder = _refFeeders.any((e) => e.id == _formData['feederId'])
          ? _formData['feederId']
          : null;

      final currentType = _formData['type']?.toString() ?? 'Motor';

      return [
        SearchableSelectionField<String>(
          label: 'Equipment Machinery Type',
          hintText: 'Select equipment type',
          selectedValue: currentType,
          prefixIcon: Icons.precision_manufacturing,
          items: HierarchyService.equipmentTypes.map((t) => SearchableItem<String>(value: t, label: t)).toList(),
          onChanged: (v) => setState(() => _formData['type'] = v ?? 'Motor'),
        ),
        const SizedBox(height: 14),

        SearchableSelectionField<String>(
          label: 'Physical Plant Area',
          hintText: 'Select location area',
          selectedValue: safeLoc,
          prefixIcon: Icons.place,
          items: _refLocations.map((l) => SearchableItem<String>(
            value: l.id,
            label: l.name,
            subtitle: 'ID: ${HierarchyService.stripPrefix(l.id, plantId, unitId)}',
          )).toList(),
          onChanged: (v) => setState(() => _formData['locationId'] = v),
          validator: (v) => v == null || v.isEmpty ? 'Physical Area is required' : null,
        ),
        const SizedBox(height: 14),

        SearchableSelectionField<String>(
          label: 'Panel Room / Substation (Optional)',
          hintText: 'Select power source room',
          selectedValue: safeRoom,
          prefixIcon: Icons.room_preferences,
          items: [
            const SearchableItem<String>(value: '', label: 'None (Standalone / Direct Area)'),
            ..._refPanelRooms.map((r) => SearchableItem<String>(
              value: r.id,
              label: r.name,
              subtitle: 'ID: ${HierarchyService.stripPrefix(r.id, plantId, unitId)}',
            )),
          ],
          onChanged: (v) => setState(() => _formData['panelRoomId'] = v ?? ''),
        ),
        const SizedBox(height: 14),

        SearchableSelectionField<String>(
          label: 'Switchboard / Panel / MCC (Optional)',
          hintText: 'Select source panel',
          selectedValue: safePanel,
          prefixIcon: Icons.electric_bolt,
          items: [
            const SearchableItem<String>(value: '', label: 'None (Unassigned)'),
            ..._refPanels.map((p) => SearchableItem<String>(
              value: p.id,
              label: p.name,
              subtitle: 'ID: ${HierarchyService.stripPrefix(p.id, plantId, unitId)} • ${p.voltageLevel}',
            )),
          ],
          onChanged: (v) => setState(() => _formData['panelId'] = v ?? ''),
        ),
        const SizedBox(height: 14),

        SearchableSelectionField<String>(
          label: 'Power Feeder Breaker (Optional)',
          hintText: 'Select circuit feeder',
          selectedValue: safeFeeder,
          prefixIcon: Icons.alt_route,
          items: [
            const SearchableItem<String>(value: '', label: 'None (Unassigned)'),
            ..._refFeeders.map((f) => SearchableItem<String>(
              value: f.id,
              label: f.name,
              subtitle: 'ID: ${HierarchyService.stripPrefix(f.id, plantId, unitId)} • ${f.type}',
            )),
          ],
          onChanged: (v) => setState(() => _formData['feederId'] = v ?? ''),
        ),
      ];
    } else if (widget.collection == 'fault_types') {
      final currentDiscipline = _formData['discipline'] ?? _formData['Discipline'] ?? _formData['category'] ?? 'Electrical';
      final currentEqType = _formData['targetEquipment'] ?? _formData['Target_Equipment'] ?? _formData['equipmentType'] ?? 'Contactor / Starter';
      final currentSev = _formData['severity'] ?? _formData['Default_Severity'] ?? _formData['Severity'] ?? 'Critical';
      final currentSla = _formData['targetSlaHours'] ?? _formData['Target_SLA_Hours'] ?? 2;
      final currentDiag = _formData['diagnosticChecks'] ?? _formData['Diagnostic_Checks'] ?? '';
      final currentAction = _formData['correctiveAction'] ?? _formData['Corrective_Action'] ?? '';

      final eqTypesSet = <String>{
        'Electric Motors', 'Electric Motor', 'Contactors, Motor Feeders', 'Contactor / Starter',
        'Brakes & Thrusters', 'Electro-Hydraulic Thrusters, Cranes, Conveyors', 'Disc Brakes, Shoe Brakes',
        'Variable Frequency Drives (VFDs)', 'VFD / Variable Speed Drive', 'Soft Starters', 'Soft Starter',
        'DOL / Star-Delta Starters', 'DOL / Star-Delta Starter', 'Star-Delta Starters',
        'VCBs, ACBs', 'Air Circuit Breaker (ACB)', 'PCC/MCC Switchboards', 'MCCB / Switchgear',
        'Power Transformers', 'Power / Distribution Transformer', 'Transformers',
        'Centrifugal & Slurry Pumps', 'Centrifugal / Slurry Pump', 'Pumps',
        'Industrial Gearboxes', 'Industrial Gearbox', 'Belt Conveyors', 'Belt Conveyor / Drive',
        'Control Valves', 'Control Valve / Actuator', 'Transmitters, RTDs', 'Transmitter / Sensor',
        'PLC Racks, Profinet/Profibus', 'PLC / Controller', 'Other'
      };
      if (currentEqType.toString().trim().isNotEmpty) {
        eqTypesSet.add(currentEqType.toString().trim());
      }
      final eqTypes = eqTypesSet.toList()..sort();
      const severities = ['Critical', 'Major', 'Moderate', 'Minor'];

      return [
        SearchableSelectionField<String>(
          label: 'Engineering Discipline',
          selectedValue: currentDiscipline,
          prefixIcon: Icons.engineering,
          items: ['Electrical', 'Mechanical', 'Instrumentation', 'Automation'].map((c) => SearchableItem<String>(value: c, label: c)).toList(),
          onChanged: (v) => setState(() {
            _formData['discipline'] = v ?? 'Electrical';
            _formData['category'] = v ?? 'Electrical';
            _formData['Discipline'] = v ?? 'Electrical';
          }),
        ),
        const SizedBox(height: 14),
        SearchableSelectionField<String>(
          label: 'Target Equipment Component',
          selectedValue: currentEqType,
          prefixIcon: Icons.precision_manufacturing,
          items: eqTypes.map((t) => SearchableItem<String>(value: t, label: t)).toList(),
          onChanged: (v) => setState(() {
            _formData['targetEquipment'] = v ?? 'Contactor / Starter';
            _formData['equipmentType'] = v ?? 'Contactor / Starter';
            _formData['Target_Equipment'] = v ?? 'Contactor / Starter';
          }),
        ),
        const SizedBox(height: 14),
        SearchableSelectionField<String>(
          label: 'Default Severity',
          selectedValue: currentSev,
          prefixIcon: Icons.warning_amber_rounded,
          items: severities.map((s) => SearchableItem<String>(value: s, label: s)).toList(),
          onChanged: (v) => setState(() {
            _formData['severity'] = v ?? 'Critical';
            _formData['Default_Severity'] = v ?? 'Critical';
          }),
        ),
        const SizedBox(height: 14),
        TextFormField(
          initialValue: currentSla.toString(),
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Target Resolution SLA (Hours)',
            prefixIcon: Icon(Icons.timer_outlined, size: 20),
            border: OutlineInputBorder(),
          ),
          onChanged: (v) {
            final val = int.tryParse(v.trim()) ?? 2;
            _formData['targetSlaHours'] = val;
            _formData['Target_SLA_Hours'] = val;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          initialValue: currentDiag.toString(),
          decoration: const InputDecoration(
            labelText: 'Diagnostic Checks / Testing Guide',
            hintText: 'e.g. Check coil resistance, verify auxiliary contact closure...',
            prefixIcon: Icon(Icons.troubleshoot, size: 20),
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
          onChanged: (v) {
            _formData['diagnosticChecks'] = v.trim();
            _formData['Diagnostic_Checks'] = v.trim();
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          initialValue: currentAction.toString(),
          decoration: const InputDecoration(
            labelText: 'Standard Corrective Action',
            hintText: 'e.g. Clean contact surfaces, replace burnt coil assembly...',
            prefixIcon: Icon(Icons.build_circle_outlined, size: 20),
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
          onChanged: (v) {
            _formData['correctiveAction'] = v.trim();
            _formData['Corrective_Action'] = v.trim();
          },
        ),
      ];
    } else if (widget.collection == 'odc' || widget.collection == 'odc_causes') {
      final currentDiscipline = _formData['discipline'] ?? _formData['Discipline'] ?? _formData['category'] ?? 'Electrical';
      final currentEq = _formData['equipmentCategory'] ?? _formData['Equipment_Category'] ?? 'Contactor';
      final currentPart = _formData['objectPart'] ?? _formData['Object_Part'] ?? '';
      final currentDamage = _formData['damage'] ?? _formData['damageMode'] ?? _formData['Damage_Mode'] ?? '';
      final currentCause = _formData['cause'] ?? _formData['rootCause'] ?? _formData['Root_Cause'] ?? _formData['name'] ?? '';
      final currentIso = _formData['isoCode'] ?? _formData['ISO_14224_Code'] ?? '';
      final currentSev = _formData['severity'] ?? _formData['Severity'] ?? _formData['Default_Severity'] ?? 'Critical';
      final currentAction = _formData['recommendedAction'] ?? _formData['Recommended_Action'] ?? '';

      final commonEqsSet = <String>{
        'Contactor', 'Industrial Brake', 'Variable Frequency Drive (VFD)', 'Soft Starter',
        'Starter Panel (DOL/Star-Delta)', 'Circuit Breaker (VCB/ACB)', 'Electric Motor',
        'Power Transformer', 'Centrifugal Pump', 'Industrial Gearbox', 'Belt Conveyor',
        'Field Transmitter', 'Temperature Sensor', 'Control Valve', 'PLC & SCADA',
        'Overhead Crane', 'Hydraulic Power Pack', 'Compressor', 'Vibrating Screen', 'Other'
      };
      if (currentEq.toString().trim().isNotEmpty) {
        commonEqsSet.add(currentEq.toString().trim());
      }
      final commonEqs = commonEqsSet.toList()..sort();
      const severities = ['Critical', 'Major', 'Moderate', 'Minor'];

      return [
        SearchableSelectionField<String>(
          label: 'Engineering Discipline',
          selectedValue: currentDiscipline,
          prefixIcon: Icons.engineering,
          items: ['Electrical', 'Mechanical', 'Instrumentation', 'Automation'].map((c) => SearchableItem<String>(value: c, label: c)).toList(),
          onChanged: (v) => setState(() {
            _formData['discipline'] = v ?? 'Electrical';
            _formData['category'] = v ?? 'Electrical';
            _formData['Discipline'] = v ?? 'Electrical';
          }),
        ),
        const SizedBox(height: 14),
        SearchableSelectionField<String>(
          label: 'Equipment Category',
          selectedValue: currentEq,
          prefixIcon: Icons.precision_manufacturing,
          items: commonEqs.map((e) => SearchableItem<String>(value: e, label: e)).toList(),
          onChanged: (v) => setState(() {
            _formData['equipmentCategory'] = v ?? 'Contactor';
            _formData['Equipment_Category'] = v ?? 'Contactor';
          }),
        ),
        const SizedBox(height: 14),
        TextFormField(
          initialValue: currentPart.toString(),
          decoration: const InputDecoration(
            labelText: 'Component / Object Part *',
            hintText: 'e.g. Main Contacts, Brake Lining, IGBT Module, DE Bearing...',
            prefixIcon: Icon(Icons.extension_outlined, size: 20),
            border: OutlineInputBorder(),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Object Part is required' : null,
          onChanged: (v) {
            _formData['objectPart'] = v.trim();
            _formData['Object_Part'] = v.trim();
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          initialValue: currentDamage.toString(),
          decoration: const InputDecoration(
            labelText: 'Defect / Damage Mode *',
            hintText: 'e.g. Pitting & Carbonisation, Lining Wear, High Vibration...',
            prefixIcon: Icon(Icons.broken_image_outlined, size: 20),
            border: OutlineInputBorder(),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Damage Mode is required' : null,
          onChanged: (v) {
            _formData['damage'] = v.trim();
            _formData['damageMode'] = v.trim();
            _formData['Damage_Mode'] = v.trim();
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          initialValue: currentCause.toString(),
          decoration: const InputDecoration(
            labelText: 'Root Cause / Failure Mechanism *',
            hintText: 'e.g. Heavy Inrush Current Arcing, Overload, Moisture Ingress...',
            prefixIcon: Icon(Icons.psychology_outlined, size: 20),
            border: OutlineInputBorder(),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Root Cause is required' : null,
          onChanged: (v) {
            _formData['cause'] = v.trim();
            _formData['rootCause'] = v.trim();
            _formData['Root_Cause'] = v.trim();
          },
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: currentIso.toString(),
                decoration: const InputDecoration(
                  labelText: 'ISO 14224 Code',
                  hintText: 'e.g. EL-CON-01',
                  prefixIcon: Icon(Icons.confirmation_number_outlined, size: 20),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  _formData['isoCode'] = v.trim();
                  _formData['ISO_14224_Code'] = v.trim();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SearchableSelectionField<String>(
                label: 'Severity Level',
                selectedValue: currentSev,
                prefixIcon: Icons.warning_amber_rounded,
                items: severities.map((s) => SearchableItem<String>(value: s, label: s)).toList(),
                onChanged: (v) => setState(() {
                  _formData['severity'] = v ?? 'Critical';
                  _formData['Severity'] = v ?? 'Critical';
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextFormField(
          initialValue: currentAction.toString(),
          decoration: const InputDecoration(
            labelText: 'Recommended Action / Maintenance Remedy',
            hintText: 'e.g. Clean contact surfaces, replace brake pads, torque bolts...',
            prefixIcon: Icon(Icons.handyman_outlined, size: 20),
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
          onChanged: (v) {
            _formData['recommendedAction'] = v.trim();
            _formData['Recommended_Action'] = v.trim();
          },
        ),
      ];
    }

    return [];
  }
}
