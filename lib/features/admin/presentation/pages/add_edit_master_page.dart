
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/hierarchy_service.dart';
import '../../../../core/constants/app_roles.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/utils/permission_helper.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/pulse_loading.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../home/presentation/widgets/custom_app_bar.dart';
import '../../../assets/data/models/master_equipment_model.dart';
import '../../../assets/data/models/location_model.dart';
import '../../../assets/data/models/panel_model.dart';
import '../../../assets/data/models/feeder_model.dart';
import '../../../assets/data/models/panel_room_model.dart';

class AddEditMasterPage extends StatefulWidget {
  final String unitId;
  final String plantId;
  final String? userRole; // Optional role for RBAC
  final MasterEquipmentModel? existingItem;

  const AddEditMasterPage({
    super.key,
    required this.unitId,
    required this.plantId,
    this.userRole,
    this.existingItem,
  });

  @override
  State<AddEditMasterPage> createState() => _AddEditMasterPageState();
}

class _AddEditMasterPageState extends State<AddEditMasterPage> {
  final _formKey = GlobalKey<FormState>();
  final _tagController = TextEditingController();
  final _nameController = TextEditingController();
  final _areaController = TextEditingController();
  final _descController = TextEditingController();
  
  String? _selectedType;
  final List<String> _equipmentTypes = List<String>.from(HierarchyService.equipmentTypes);
  
  bool _isSaving = false;
  bool _isLoadingRef = true;

  // Hierarchical Data
  List<LocationModel> _locations = [];
  List<PanelRoomModel> _panelRooms = [];
  List<PanelModel> _panels = [];
  List<FeederModel> _feeders = [];


  String? _selectedLocationId;
  String? _selectedPanelRoomId;
  String? _selectedPanelId;
  String? _selectedFeederId;

  // RBAC Scope overrides (if Developer)
  String? _currentPlantId;
  String? _currentUnitId;
  List<String> _availablePlants = [];
  List<String> _availableUnits = [];

  @override
  void initState() {
    super.initState();
    _currentPlantId = widget.plantId;
    _currentUnitId = widget.unitId;

    if (widget.userRole == AppRoles.developer) {
      _availablePlants = HierarchyService().getPlants();
      if (_currentPlantId != null) {
        _availableUnits = HierarchyService().getUnitsForPlant(_currentPlantId!);
      }
    }

    _loadReferenceData();

    if (widget.existingItem != null) {

      _tagController.text = HierarchyService.stripPrefix(widget.existingItem!.id, _currentPlantId ?? '', _currentUnitId ?? '');
      _nameController.text = widget.existingItem!.name;
      _descController.text = widget.existingItem!.description;
      
      final currentType = widget.existingItem!.type;
      if (currentType.isNotEmpty && !_equipmentTypes.contains(currentType)) {
        _equipmentTypes.add(currentType);
      }
      _selectedType = currentType.isNotEmpty ? currentType : null;
      
      _selectedLocationId = widget.existingItem!.locationId;
      _selectedPanelRoomId = widget.existingItem!.panelRoomId;
      _selectedPanelId = widget.existingItem!.panelId;
      _selectedFeederId = widget.existingItem!.feederId;

      if (_selectedPanelRoomId != null && _selectedPanelRoomId!.isNotEmpty) {
         _loadPanels(_selectedPanelRoomId!);
      }
      if (_selectedPanelId != null && _selectedPanelId!.isNotEmpty) {
         _loadFeeders(_selectedPanelId!);
      }
    } else {
      _tagController.text = '';
    }
  }

  Future<void> _loadReferenceData() async {
    setState(() => _isLoadingRef = true);
    try {
      final unitId = _currentUnitId ?? widget.unitId;
      final plantId = _currentPlantId ?? widget.plantId;

      final results = await Future.wait([
        FirestoreService().getLocationsStream(unitId, plantId).first,
        FirestoreService().getPanelRoomsStream(unitId, plantId).first,
      ]);
      _locations = results[0] as List<LocationModel>;
      _panelRooms = results[1] as List<PanelRoomModel>;

      if (widget.existingItem != null) {
        final prId = widget.existingItem!.panelRoomId;
        if (prId != null && prId.isNotEmpty) {
          _panels = await FirestoreService().getPanelsStream(prId).first;
        }
        final pId = widget.existingItem!.panelId;
        if (pId != null && pId.isNotEmpty) {
          _feeders = await FirestoreService().getFeedersStream(pId).first;
        }
      }
    } catch (e) {
      debugPrint("Error loading reference data: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingRef = false);
      }
    }
  }

  void _loadPanels(String panelRoomId) {
    FirestoreService().getPanelsStream(panelRoomId).listen((data) {
      if (mounted) setState(() => _panels = data);
    });
  }

  void _loadFeeders(String panelId) {
    FirestoreService().getFeedersStream(panelId).listen((data) {
      if (mounted) setState(() => _feeders = data);
    });
  }

  @override
  void dispose() {
    _tagController.dispose();
    _nameController.dispose();
    _areaController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final currentUser = AuthService().currentUser;
      if (currentUser == null) throw Exception("Not logged in");
      final profile = await FirestoreService().getUserProfile(currentUser.uid);
      if (profile == null) throw Exception("User profile not found");
      
      final bool canEdit = PermissionHelper.canEditDatabaseItem(
        userRole: profile['role'] ?? 'Guest',
        isAdmin: profile['isAdmin'] == true,
        userPlantId: profile['plantId'] as String?,
        userUnitId: profile['unitId'] as String?,
        itemPlantId: _currentPlantId,
        itemUnitId: _currentUnitId,
      );

      if (!canEdit) {
        throw Exception("You do not have permission to modify database items in this scope.");
      }
      if (_currentPlantId == null || _currentUnitId == null) throw Exception("Scope (Plant/Unit) missing.");
      if (_currentPlantId == null || _currentUnitId == null) throw Exception("Scope (Plant/Unit) missing.");
      if (_selectedLocationId == null) throw Exception("Please select a Physical Area.");
      if (_selectedType == null) throw Exception("Please select an Equipment Type.");

      // For backward compatibility, save area name too
      final locName = _locations.firstWhere((l) => l.id == _selectedLocationId, orElse: () => LocationModel(id: '', unitId: '', plantId: '', name: 'Unknown')).name;

      final fullTagId = HierarchyService.prefixId(
        _tagController.text,
        _currentPlantId!,
        _currentUnitId!,
      );

      final item = MasterEquipmentModel(
        id: fullTagId,
        unitId: _currentUnitId!,
        plantId: _currentPlantId!,
        name: _nameController.text.trim(),
        area: locName,
        locationId: _selectedLocationId!,
        panelRoomId: _selectedPanelRoomId,
        panelId: _selectedPanelId,
        feederId: _selectedFeederId,
        type: _selectedType!,
        description: _descController.text.trim(),
        createdAt: widget.existingItem?.createdAt,
        createdBy: widget.existingItem?.createdBy ?? AuthService().currentUser?.uid,
        modifiedBy: AuthService().currentUser?.uid,
      );

      await FirestoreService().saveMasterEquipment(item);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Equipment Saved!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // If editing, TagNo cannot be changed (primary key in Firestore)
    final isEditing = widget.existingItem != null;

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: CustomAppBar(title: isEditing ? 'Edit Equipment' : 'Add Equipment'),
      body: AnimatedGradientBackground(
        child: Stack(
          children: [
            if (_isLoadingRef)
              const Center(child: PulseLoading(size: 40))
            else
              SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // RBAC Scope Selection (For Developer)
                    if (widget.userRole == AppRoles.developer) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _buildGlassDropdown<String>(
                              label: 'Plant',
                              value: _currentPlantId,
                              items: _availablePlants.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                              onChanged: (v) {
                                setState(() {
                                  _currentPlantId = v;
                                  if (v != null) _availableUnits = HierarchyService().getUnitsForPlant(v);
                                  _currentUnitId = _availableUnits.isNotEmpty ? _availableUnits.first : null;
                                  _selectedLocationId = null;
                                  _selectedPanelId = null;
                                });
                                  _loadReferenceData();
                                },
                              ),
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildGlassDropdown<String>(
                              label: 'Unit',
                              value: _currentUnitId,
                              items: _availableUnits.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                              onChanged: (v) {
                                setState(() {
                                  _currentUnitId = v;
                                  _selectedLocationId = null;
                                  _selectedPanelId = null;
                                });
                                  _loadReferenceData();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      // For non-developers, show read-only scope info
                      Row(
                        children: [
                          Expanded(child: _buildScopeInfo('PLANT', _currentPlantId ?? '-')),
                          const SizedBox(width: 8),
                          Expanded(child: _buildScopeInfo('UNIT', _currentUnitId ?? '-')),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                       _buildGlassField(
                        controller: _tagController,
                        label: 'Tag No (Unique ID) (Prefix auto-added)',
                        icon: Icons.tag,
                        enabled: !isEditing, // Lock ID on edit
                        validator: (v) => v == null || v.isEmpty ? 'Tag No is required' : null,
                      ),
                    const SizedBox(height: 16),
                    _buildGlassField(
                      controller: _nameController,
                      label: 'Equipment Name',
                      icon: Icons.title,
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    // Cascading Dropdowns for Context
                    _buildGlassDropdown<String>(
                      label: 'Physical Area',
                      value: _locations.any((e) => e.id == _selectedLocationId) ? _selectedLocationId : null,
                      items: _locations
                          .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
                          .toList(),
                      onChanged: (val) {
                         setState(() {
                           _selectedLocationId = val;
                         });
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildGlassDropdown<String>(
                      label: 'Panel Room / Substation',
                      value: _panelRooms.any((e) => e.id == _selectedPanelRoomId) ? _selectedPanelRoomId : null,
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('None / Mechanical Only', style: TextStyle(fontStyle: FontStyle.italic)),
                        ),
                        ..._panelRooms.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))),
                      ],
                      onChanged: (val) {
                          setState(() {
                            _selectedPanelRoomId = val;
                            _selectedPanelId = null;
                            _selectedFeederId = null;
                            _panels = [];
                            _feeders = [];
                          });
                          if (val != null) _loadPanels(val);
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildGlassDropdown<String>(
                      label: 'Panel / MCC (Optional for Mechanical)',
                      value: _selectedPanelId,
                      items: [
                        const DropdownMenuItem<String>(
                          value: null, 
                          child: Text('None (Optional)', style: TextStyle(fontStyle: FontStyle.italic))
                        ),
                        ..._panels.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))),
                      ],
                      onChanged: (val) {
                         setState(() {
                           _selectedPanelId = val;
                           _selectedFeederId = null;
                           _feeders = [];
                         });
                         if (val != null) _loadFeeders(val);
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildGlassDropdown<String>(
                      label: 'Feeder / Source (Optional)',
                      value: _selectedFeederId,
                      items: [
                        const DropdownMenuItem<String>(
                          value: null, 
                          child: Text('None (Optional)', style: TextStyle(fontStyle: FontStyle.italic))
                        ),
                        ..._feeders.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))),
                      ],
                      onChanged: (val) {
                         setState(() { _selectedFeederId = val; });
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildGlassDropdown<String>(
                      label: 'Equipment Type',
                      value: _selectedType,
                      items: _equipmentTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) {
                         setState(() { _selectedType = val; });
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildGlassField(
                      controller: _descController,
                      label: 'Description',
                      icon: Icons.description,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving 
                        ? const SizedBox(width: 20, height: 20, child: PulseLoading(size: 20))
                        : Text(isEditing ? 'Update Equipment' : 'Create Equipment', style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onPrimary)),
                    ),
                  ],
                ),
              ),
            ),
            if (_isSaving) const Positioned.fill(child: Center(child: PulseLoading(size: 60))),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return GlassContainer(
      width: double.infinity,
      height: null,
      borderRadius: 12,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: TextFormField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,

          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          validator: validator,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorStyle: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return GlassContainer(
      width: double.infinity,
      height: null,
      borderRadius: 12,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          dropdownColor: Theme.of(context).colorScheme.surface,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          icon: Icon(Icons.arrow_drop_down, color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }

  Widget _buildScopeInfo(String label, String value) {
    return GlassContainer(
      borderRadius: 12,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.accent)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
