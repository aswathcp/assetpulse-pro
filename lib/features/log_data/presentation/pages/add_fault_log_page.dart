import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/ai_fault_log_service.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../../core/widgets/searchable_selection_field.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_roles.dart';
import '../../../home/presentation/widgets/custom_app_bar.dart';
import '../../../assets/data/models/fault_log_model.dart';
import '../../../assets/data/models/master_equipment_model.dart';
import '../../../assets/data/models/asset_model.dart';
import '../../../../core/services/hierarchy_service.dart';
import '../../../../core/utils/permission_helper.dart';

class AddFaultLogPage extends StatefulWidget {
  final String? masterEquipmentId;
  final String? masterEquipmentName;
  final String? assetId; // Optional asset context
  final String? plantId; // Active Plant Scope
  final String? unitId;  // Active Unit Scope

  const AddFaultLogPage({
    super.key,
    this.masterEquipmentId,
    this.masterEquipmentName,
    this.assetId,
    this.plantId,
    this.unitId,
  });

  @override
  State<AddFaultLogPage> createState() => _AddFaultLogPageState();
}

class _AddFaultLogPageState extends State<AddFaultLogPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isLoading = true;

  // Scope State (Plant & Unit)
  UserScope? _userScope;
  String? _activePlant;
  String? _activeUnit;
  List<String> _plants = [];
  List<String> _units = [];
  bool _isPlantLocked = false;
  bool _isUnitLocked = false;

  // AI Assistant State
  bool _showAiCard = true;
  bool _isAiParsing = false;
  bool _hasGeminiApiKey = false;
  final _aiPromptController = TextEditingController();
  ParsedFaultLogDraft? _lastAiDraft;
  String? _aiFeedbackMessage;

  // Primary Fields
  FaultCategory _selectedCategory = FaultCategory.electrical;
  FaultPriority _selectedPriority = FaultPriority.medium;
  FaultStatus _selectedStatus = FaultStatus.pending;
  WorkShift _selectedShift = WorkShift.as;

  final _causeController = TextEditingController();
  final _odcController = TextEditingController();
  final _actionController = TextEditingController();
  final _downtimeController = TextEditingController();

  // Equipment & Sub-Asset State
  String? _selectedEquipmentId;
  List<MasterEquipmentModel> _allEquipments = [];

  String? _selectedAssetId;
  List<AssetModel> _equipmentSubAssets = [];
  bool _isLoadingSubAssets = false;

  // Catalogs
  List<Map<String, dynamic>> _allFaultTypes = [];
  List<Map<String, dynamic>> _allOdcCauses = [];
  String? _selectedFaultTypeId;
  String? _selectedOdcId;

  // Personnel State
  List<Map<String, dynamic>> _availableUsers = [];
  List<String> _assignedPersonnelNames = [];

  // ODC State
  bool _isOdcApplicable = false;
  bool _isOdcClosed = false;

  // Tri-Axial ODC State (ISO 14224: Component Part, Defect Mode, Root Cause)
  String? _selectedOdcObject;
  String? _selectedOdcDamage;
  String? _selectedOdcCause;
  List<String> _selectedOdcDamages = [];
  List<String> _selectedOdcCauses = [];

  void _updateOdcSummaryText() {
    final effectiveDamages = _selectedOdcDamages.isNotEmpty
        ? _selectedOdcDamages.join(', ')
        : (_selectedOdcDamage ?? '');
    final effectiveCauses = _selectedOdcCauses.isNotEmpty
        ? _selectedOdcCauses.join(', ')
        : (_selectedOdcCause ?? '');

    final parts = [
      if (_selectedOdcObject != null && _selectedOdcObject!.isNotEmpty) 'Object: $_selectedOdcObject',
      if (effectiveDamages.isNotEmpty) 'Damage: $effectiveDamages',
      if (effectiveCauses.isNotEmpty) 'Cause: $effectiveCauses',
    ];
    if (parts.isNotEmpty) {
      _odcController.text = parts.join(' | ');
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedEquipmentId = (widget.masterEquipmentId != null && widget.masterEquipmentId!.isNotEmpty)
        ? widget.masterEquipmentId
        : null;
    _selectedAssetId = (widget.assetId != null && widget.assetId!.isNotEmpty) ? widget.assetId : null;
    _activePlant = widget.plantId;
    _activeUnit = widget.unitId;
    _loadAllInitialData();
  }

  @override
  void dispose() {
    _aiPromptController.dispose();
    _causeController.dispose();
    _odcController.dispose();
    _actionController.dispose();
    _downtimeController.dispose();
    super.dispose();
  }

  Future<void> _loadAllInitialData() async {
    setState(() => _isLoading = true);
    try {
      await _loadScope();
      await _checkApiKey();
      await Future.wait([
        if (_selectedEquipmentId == null) _fetchEquipments(),
        _fetchUsers(),
        _fetchCatalogs(),
      ]);
      if (_selectedEquipmentId != null) {
        await _fetchSubAssets(_selectedEquipmentId!);
      }
    } catch (e) {
      debugPrint('Error loading initial data for fault logging: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkApiKey() async {
    final key = await AiFaultLogService().getApiKey();
    if (mounted) {
      setState(() {
        _hasGeminiApiKey = key != null && key.trim().isNotEmpty;
      });
    }
  }

  Future<void> _loadScope() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final profile = await FirestoreService().getUserProfile(user.uid);
    if (profile == null) return;

    final userBusinessId = profile['businessId'] as String? ?? 'VISL';
    await HierarchyService().init(businessId: userBusinessId);

    final userScope = PermissionHelper.resolveUserScope(profile);
    _userScope = userScope;

    final allPlants = HierarchyService().getPlants();
    _plants = userScope.getAvailablePlants(allPlants);
    _isPlantLocked = userScope.isPlantLocked;
    _isUnitLocked = userScope.isUnitLocked;

    _activePlant = userScope.getInitialPlant(widget.plantId, _plants);
    _updateUnitList();
  }

  void _updateUnitList() {
    if (_activePlant == null) {
      _units = [];
      _activeUnit = null;
    } else {
      final allUnits = HierarchyService().getUnitsForPlant(_activePlant!);
      if (_userScope != null) {
        _units = _userScope!.getAvailableUnits(_activePlant, allUnits);
        _activeUnit = _userScope!.getInitialUnit(_activePlant, widget.unitId, _units);
      } else {
        _units = allUnits.isNotEmpty ? allUnits : ['PID1', 'MCD'];
        if (!_units.contains(_activeUnit)) {
          _activeUnit = _units.isNotEmpty ? _units.first : null;
        }
      }
    }
  }

  void _onPlantChanged(String? newPlant) {
    if (newPlant == null || newPlant == _activePlant) return;
    setState(() {
      _activePlant = newPlant;
      _updateUnitList();
      _selectedEquipmentId = null;
      _selectedAssetId = null;
    });
    _fetchEquipments();
  }

  void _onUnitChanged(String? newUnit) {
    if (newUnit == null || newUnit == _activeUnit) return;
    setState(() {
      _activeUnit = newUnit;
      _selectedEquipmentId = null;
      _selectedAssetId = null;
    });
    _fetchEquipments();
  }


  Future<void> _fetchEquipments() async {
    Query query = FirebaseFirestore.instance.collection('master_equipments');
    if (_activePlant != null && _activePlant!.isNotEmpty && _activePlant != 'ALL' && _activePlant != 'GLOBAL') {
      query = query.where('plantId', isEqualTo: _activePlant);
    }
    if (_activeUnit != null && _activeUnit!.isNotEmpty && _activeUnit != 'ALL' && _activeUnit != 'GLOBAL') {
      query = query.where('unitId', isEqualTo: _activeUnit);
    }

    var snapshot = await query.get();
    // Fallback: If no equipments found for this unit/plant, fetch all so technician is never blocked
    if (snapshot.docs.isEmpty) {
      snapshot = await FirebaseFirestore.instance.collection('master_equipments').get();
    }

    if (mounted) {
      setState(() {
        _allEquipments = snapshot.docs
            .map((doc) => MasterEquipmentModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList();
      });
    }
  }

  Future<void> _fetchSubAssets(String equipmentId) async {
    setState(() => _isLoadingSubAssets = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('assets')
          .where('masterEquipmentId', isEqualTo: equipmentId)
          .get();

      List<AssetModel> subAssets = snap.docs.map((d) => AssetModel.fromMap(d.data(), d.id)).toList();

      if (mounted) {
        setState(() {
          _equipmentSubAssets = subAssets;
          if (_selectedAssetId != null && !_equipmentSubAssets.any((a) => a.id == _selectedAssetId)) {
            _selectedAssetId = null;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching sub-assets: $e');
    } finally {
      if (mounted) setState(() => _isLoadingSubAssets = false);
    }
  }

  Future<void> _fetchCatalogs() async {
    try {
      final ftSnap = await FirebaseFirestore.instance.collection('fault_types').get();
      var odcSnap = await FirebaseFirestore.instance.collection('odc').get();
      if (odcSnap.docs.isEmpty) {
        odcSnap = await FirebaseFirestore.instance.collection('odc_causes').get();
      }
      if (mounted) {
        setState(() {
          _allFaultTypes = ftSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
          _allOdcCauses = odcSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching fault types and ODC causes: $e');
    }
  }

  Future<void> _fetchUsers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final profile = await FirestoreService().getUserProfile(user.uid);
      final String? businessId = profile?['businessId'];
      final String? plantId = profile?['plantId'];
      final String? unitId = profile?['unitId'];
      final String role = profile?['role'] ?? AppRoles.guest;
      final bool isAdmin = profile?['isAdmin'] == true;

      List<Map<String, dynamic>> users = [];
      if (role == AppRoles.developer || (isAdmin && plantId == null)) {
        users = await FirestoreService().getAllUsers();
      } else if (role == AppRoles.businessAdmin && businessId != null) {
        users = await FirestoreService().getAllUsers(businessId: businessId);
      } else if ((isAdmin || role == AppRoles.plantAdmin) && plantId != null) {
        users = await FirestoreService().getAllUsers(plantId: plantId);
      } else if (plantId != null && unitId != null) {
        users = await FirestoreService().getAllUsers(plantId: plantId, unitId: unitId);
      }

      if (mounted) {
        setState(() {
          _availableUsers = users;
        });
      }
    }
  }

  // --- AI LOGIC ---

  Future<void> _runAiAutoFill() async {
    final text = _aiPromptController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please speak or type a brief maintenance observation first.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _isAiParsing = true;
      _aiFeedbackMessage = null;
    });

    try {
      final draft = await AiFaultLogService().parseMaintenanceLog(
        rawPrompt: text,
        availableEquipments: _allEquipments,
        availableSubAssets: _equipmentSubAssets,
        availableFaultTypes: _allFaultTypes,
        availableOdcCauses: _allOdcCauses,
      );

      setState(() {
        _lastAiDraft = draft;
        _isAiParsing = false;

        // Auto-populate form
        _causeController.text = draft.problemDescription;
        _actionController.text = draft.actionTaken;
        _selectedCategory = draft.category;
        _selectedPriority = draft.priority;
        _selectedShift = draft.shift;
        _selectedStatus = draft.status;

        if (draft.equipmentId != null) {
          _selectedEquipmentId = draft.equipmentId;
          _fetchSubAssets(draft.equipmentId!);
        }

        if (draft.subAssetId != null) {
          _selectedAssetId = draft.subAssetId;
        }

        if (draft.faultTypeId != null) {
          _selectedFaultTypeId = draft.faultTypeId;
        }

        if (draft.isOdcApplicable || draft.odcObject != null || draft.odcCause != null || draft.odcDamages.isNotEmpty) {
          _isOdcApplicable = true;
          _isOdcClosed = draft.isOdcClosed;
          if (draft.odcObject != null && draft.odcObject!.isNotEmpty) {
            _selectedOdcObject = draft.odcObject;
          }
          if (draft.odcDamages.isNotEmpty) {
            _selectedOdcDamages = List.from(draft.odcDamages);
            _selectedOdcDamage = _selectedOdcDamages.first;
          } else if (draft.odcDamage != null && draft.odcDamage!.isNotEmpty) {
            _selectedOdcDamages = [draft.odcDamage!];
            _selectedOdcDamage = draft.odcDamage;
          }
          if (draft.odcCauses.isNotEmpty) {
            _selectedOdcCauses = List.from(draft.odcCauses);
            _selectedOdcCause = _selectedOdcCauses.first;
          } else if (draft.odcCause != null && draft.odcCause!.isNotEmpty) {
            _selectedOdcCauses = [draft.odcCause!];
            _selectedOdcCause = draft.odcCause;
          }
          _updateOdcSummaryText();
        }

        if (draft.downtimeMinutes != null && draft.downtimeMinutes! > 0) {
          _downtimeController.text = draft.downtimeMinutes.toString();
        }

        _aiFeedbackMessage = 'AI Formulated: ${draft.aiSummary}';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _hasGeminiApiKey
                        ? 'Gemini Cloud AI Formulated & Spell-Corrected fields!'
                        : 'Offline Smart NLP Engine Auto-Filled fields!',
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E1B4B),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() => _isAiParsing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI parse error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showApiKeyDialog() async {
    final aiService = AiFaultLogService();
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString('gemini_ai_api_key') ?? '';
    final isDevKey = savedKey.isEmpty;
    final devEnabled = await aiService.getDeveloperKeyEnabled();

    final controller = TextEditingController(text: savedKey);
    bool localDevEnabled = devEnabled;

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Row(
            children: [
              Icon(Icons.psychology_rounded, color: Colors.purpleAccent, size: 22),
              SizedBox(width: 8),
              Text('AI Engine Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Developer key status card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDevKey
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDevKey ? Colors.green.withValues(alpha: 0.3) : Colors.blue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isDevKey ? Icons.developer_mode_rounded : Icons.vpn_key_rounded,
                            size: 16,
                            color: isDevKey ? Colors.greenAccent : Colors.blueAccent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isDevKey ? 'Using Developer Key (Shared)' : 'Using Your Personal API Key',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isDevKey ? Colors.greenAccent : Colors.blueAccent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isDevKey
                            ? 'The developer key is shared & rate-limited. For unlimited usage, get your free personal key from aistudio.google.com'
                            : 'You have configured your own Gemini API key. Full AI capabilities enabled.',
                        style: const TextStyle(fontSize: 11, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (isDevKey) ...[
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Use Developer Shared Key', style: TextStyle(fontSize: 13)),
                    subtitle: const Text('Enable Gemini AI without a personal key', style: TextStyle(fontSize: 11)),
                    value: localDevEnabled,
                    activeColor: Colors.greenAccent,
                    onChanged: (v) => setDialogState(() => localDevEnabled = v),
                  ),
                  const Divider(),
                ],
                const Text(
                  'Your Personal API Key (optional)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: controller,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Google Gemini API Key',
                    hintText: 'AIzaSy... (leave blank to use developer key)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    // ignore: deprecated_member_use
                    // Launch aistudio.google.com
                  },
                  child: const Text(
                    '🔗 Get free key at aistudio.google.com',
                    style: TextStyle(fontSize: 11, color: Colors.blueAccent, decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (savedKey.isNotEmpty)
              TextButton(
                onPressed: () async {
                  await aiService.saveApiKey('');
                  await aiService.setDeveloperKeyEnabled(true);
                  await _checkApiKey();
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Personal key cleared. Switched to developer key.'), backgroundColor: Colors.orange),
                    );
                  }
                },
                child: const Text('Clear Key', style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newKey = controller.text.trim();
                await aiService.saveApiKey(newKey);
                await aiService.setDeveloperKeyEnabled(localDevEnabled);
                await _checkApiKey();
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  final msg = newKey.isNotEmpty
                      ? 'Personal Gemini API Key saved. Full Cloud AI activated!'
                      : localDevEnabled
                          ? 'Using shared Developer Key. Cloud AI enabled!'
                          : 'AI key cleared. Using Offline NLP mode.';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(msg), backgroundColor: Colors.green),
                  );
                }
              },
              child: const Text('Save & Apply'),
            ),
          ],
        ),
      ),
    );
  }



  // --- SAVE ACTION ---

  Future<void> _save() async {
    if (_selectedEquipmentId == null || _selectedEquipmentId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select target equipment.'), backgroundColor: AppColors.error),
      );
      return;
    }
    if (_selectedStatus == FaultStatus.closed &&
        _isOdcApplicable &&
        !_isOdcClosed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot resolve fault while ODC is still unresolved! Please resolve or close ODC first.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      final matchedEq = _allEquipments.where((e) => e.id == _selectedEquipmentId).firstOrNull;
      
      // Determine effective scope: Use active user scope, fall back to equipment scope, then defaults
      final effectivePlant = (_activePlant != null && _activePlant!.isNotEmpty && _activePlant != 'ALL')
          ? _activePlant!
          : (matchedEq?.plantId ?? 'PLANT');
      final effectiveUnit = (_activeUnit != null && _activeUnit!.isNotEmpty && _activeUnit != 'ALL')
          ? _activeUnit!
          : (matchedEq?.unitId ?? 'UNIT');

      // Requirement: ID should start with plant-unit-faultid so no duplicate ID saves
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final rawLogId = 'FL-$timestamp';
      final logUniqueId = HierarchyService.prefixId(rawLogId, effectivePlant, effectiveUnit);

      final combinedDamage = _selectedOdcDamages.isNotEmpty
          ? _selectedOdcDamages.join(', ')
          : _selectedOdcDamage;
      final combinedCause = _selectedOdcCauses.isNotEmpty
          ? _selectedOdcCauses.join(', ')
          : _selectedOdcCause;

      final log = FaultLogModel(
        id: logUniqueId,
        masterEquipmentId: _selectedEquipmentId!,
        assetId: _selectedAssetId ?? widget.assetId,
        plantId: effectivePlant,
        unitId: effectiveUnit,
        reportedByUserId: userId,
        reportedAt: DateTime.now(),
        category: _selectedCategory,
        priority: _selectedPriority,
        faultTypeId: _selectedFaultTypeId,
        cause: _causeController.text.trim(),
        odcId: _isOdcApplicable ? _selectedOdcId : null,
        odc: _isOdcApplicable
            ? (_odcController.text.isNotEmpty
                ? _odcController.text.trim()
                : [_selectedOdcObject, combinedDamage, combinedCause]
                    .where((e) => e != null && e.isNotEmpty)
                    .join(' • '))
            : '',
        odcObject: _isOdcApplicable ? _selectedOdcObject : null,
        odcDamage: _isOdcApplicable ? combinedDamage : null,
        odcCause: _isOdcApplicable ? combinedCause : null,
        odcDamages: _isOdcApplicable ? _selectedOdcDamages : [],
        odcCauses: _isOdcApplicable ? _selectedOdcCauses : [],
        actionTaken: _actionController.text.trim(),
        status: _selectedStatus,
        shift: _selectedShift,
        assignedEngineers: _assignedPersonnelNames,
        assignedTechnicians: _assignedPersonnelNames,
        isOdcApplicable: _isOdcApplicable,
        isOdcClosed: _isOdcClosed,
        downtimeMinutes: int.tryParse(_downtimeController.text.trim()),
      );

      await FirestoreService().saveFaultLog(log);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.greenAccent),
                const SizedBox(width: 8),
                Expanded(child: Text('Fault Log Saved! (ID: $logUniqueId Scope: $effectivePlant-$effectiveUnit)')),
              ],
            ),
            backgroundColor: const Color(0xFF064E3B),
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving fault log: $e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  List<Map<String, dynamic>> _getFilteredFaultTypes() {
    final curCat = _selectedCategory.name.toLowerCase().trim();
    // Strictly live Firestore data - no hardcoded fallbacks!
    return _allFaultTypes.where((ft) {
      final cat = (ft['category'] ?? ft['discipline'] ?? '').toString().toLowerCase().trim();
      if (cat.isEmpty || cat == 'all' || cat == 'generic') return true;
      if (cat == curCat) return true;
      if (curCat == 'instrumentation' && (cat == 'automation' || cat == 'inst')) return true;
      if (curCat == 'electrical' && cat == 'electrical') return true;
      if (curCat == 'mechanical' && cat == 'mechanical') return true;
      return false;
    }).toList();
  }

  // --- Dynamic ODC Extraction from live Firestore odc_causes collection ---

  List<Map<String, dynamic>> _getFilteredOdcList() {
    final curCat = _selectedCategory.name.toLowerCase().trim();
    return _allOdcCauses.where((odc) {
      final cat = (odc['discipline'] ?? odc['category'] ?? '').toString().toLowerCase().trim();
      if (cat.isEmpty || cat == 'all' || cat == 'generic') return true;
      if (cat == curCat) return true;
      if (curCat == 'instrumentation' && (cat == 'automation' || cat == 'inst')) return true;
      if (curCat == 'electrical' && cat == 'electrical') return true;
      if (curCat == 'mechanical' && cat == 'mechanical') return true;
      return false;
    }).toList();
  }

  List<String> _getAvailableOdcObjects() {
    final list = _getFilteredOdcList();
    final objects = <String>{};
    for (var item in list) {
      final obj = (item['objectPart'] ?? item['Object_Part'] ?? item['object'])?.toString().trim();
      if (obj != null && obj.isNotEmpty) objects.add(obj);
    }
    return objects.toList()..sort();
  }

  List<String> _getAvailableOdcDamages() {
    final list = _getFilteredOdcList();
    final damages = <String>{};
    for (var item in list) {
      final obj = (item['objectPart'] ?? item['Object_Part'] ?? item['object'])?.toString().trim();
      if (_selectedOdcObject == null || _selectedOdcObject!.isEmpty || obj == _selectedOdcObject) {
        final dmg = (item['damage'] ?? item['Damage_Mode'] ?? item['damageMode'])?.toString().trim();
        if (dmg != null && dmg.isNotEmpty) damages.add(dmg);
      }
    }
    return damages.toList()..sort();
  }

  List<String> _getAvailableOdcCauses() {
    final list = _getFilteredOdcList();
    final causes = <String>{};
    for (var item in list) {
      final dmg = (item['damage'] ?? item['Damage_Mode'] ?? item['damageMode'])?.toString().trim();
      if (_selectedOdcDamage == null || _selectedOdcDamage!.isEmpty || dmg == _selectedOdcDamage) {
        final cau = (item['cause'] ?? item['Root_Cause'] ?? item['rootCause'] ?? item['name'])?.toString().trim();
        if (cau != null && cau.isNotEmpty) causes.add(cau);
      }
    }
    return causes.toList()..sort();
  }

  // --- BUILD METHOD ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: CustomAppBar(
        title: (widget.masterEquipmentId == null || widget.masterEquipmentId!.isEmpty)
            ? 'New Fault Notification'
            : 'Log Equipment Fault',
      ),
      body: AnimatedGradientBackground(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _isLoading
              ? _buildSkeletonForm(isDark)
              : SingleChildScrollView(
                  key: const ValueKey('loaded_form'),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // --- 0. ACTIVE SCOPE (PLANT & UNIT) ---
                        _buildScopeCard(theme, isDark),
                        const SizedBox(height: 14),

                        // --- 1. AI SMART ASSISTANT CARD ---
                        _buildAiAssistantCard(theme, isDark),
                        const SizedBox(height: 16),

                        // --- 2. TARGET EQUIPMENT & ASSET ---
                        _buildEquipmentSection(theme),
                        const SizedBox(height: 14),

                        // --- 3. SHIFT, PRIORITY & CATEGORY (CORE FOR NOTIFICATION MONITORING) ---
                        _buildShiftPriorityCategorySection(theme),
                        const SizedBox(height: 14),

                        // --- 4. PROBLEM DESCRIPTION & FAILURE MODE ---
                        _buildProblemClassificationSection(theme),
                        const SizedBox(height: 14),

                        // --- 5. ACTION TAKEN & ATTENDED PERSONNEL ---
                        _buildActionAndPersonnelSection(theme),
                        const SizedBox(height: 14),

                        // --- 6. ODC (ORIGIN-DEFECT-CAUSE) ANALYSIS ---
                        _buildOdcSection(theme),
                        const SizedBox(height: 14),

                        // --- 7. RESOLUTION STATUS & DOWNTIME ---
                        _buildStatusDowntimeSection(theme),
                        const SizedBox(height: 24),

                        // --- 8. SUBMIT ACTION BUTTON ---
                        ElevatedButton(
                          onPressed: _isSaving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.save_rounded, size: 20),
                                    SizedBox(width: 8),
                                    Text('Save Fault Log', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  // --- 1. AI ASSISTANT CARD ---

  Widget _buildAiAssistantCard(ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF1E1B4B).withValues(alpha: 0.8),
                  const Color(0xFF312E81).withValues(alpha: 0.5),
                  const Color(0xFF0F172A).withValues(alpha: 0.9),
                ]
              : [
                  const Color(0xFFEEF2FF),
                  const Color(0xFFE0E7FF),
                  Colors.white,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF818CF8).withValues(alpha: isDark ? 0.4 : 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          const Text(
                            'AI Smart Assistant',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                          InkWell(
                            onTap: _showApiKeyDialog,
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _hasGeminiApiKey
                                    ? Colors.green.withValues(alpha: 0.2)
                                    : Colors.amber.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: _hasGeminiApiKey
                                      ? Colors.green.withValues(alpha: 0.4)
                                      : Colors.amber.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _hasGeminiApiKey ? Icons.cloud_done_rounded : Icons.offline_bolt_rounded,
                                    size: 10,
                                    color: _hasGeminiApiKey ? Colors.greenAccent : Colors.amberAccent,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    _hasGeminiApiKey ? 'GEMINI CLOUD AI' : 'OFFLINE SMART NLP',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: _hasGeminiApiKey ? Colors.greenAccent : Colors.amberAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Speak or type observation to auto-fill',
                        style: TextStyle(fontSize: 10.5, color: theme.colorScheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  tooltip: 'AI Settings',
                  onPressed: _showApiKeyDialog,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: Icon(_showAiCard ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 20),
                  onPressed: () => setState(() => _showAiCard = !_showAiCard),
                ),
              ],
            ),

            if (_showAiCard) ...[
              const SizedBox(height: 12),
              // Dictation / Prompt Input Field
              TextField(
                controller: _aiPromptController,
                maxLines: 3,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Tap keyboard mic 🎙️ or type freely... e.g. "Shift B Crusher 1 motor tripped on overload due to loose lug, retorqued bolts, downtime 30 mins, closed"',
                  hintStyle: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                  filled: true,
                  fillColor: theme.colorScheme.surface.withValues(alpha: isDark ? 0.6 : 0.8),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: const Color(0xFF818CF8).withValues(alpha: 0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: const Color(0xFF818CF8).withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                  ),
                  suffixIcon: _aiPromptController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() => _aiPromptController.clear()),
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 8),

              // Suggestion Quick Pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildQuickChip('⚡ Motor Overload Trip', 'Motor stopped suddenly on thermal overload trip, checked terminal box and reset.'),
                    const SizedBox(width: 6),
                    _buildQuickChip('⚙️ Bearing Vibration', 'Heavy rattling noise and high vibration on drive-end bearing, greased with Mobilgrease.'),
                    const SizedBox(width: 6),
                    _buildQuickChip('🔌 Cable Flashover', 'Breaker tripped on earth fault, found burnt cable termination lug, replaced lug.'),
                    const SizedBox(width: 6),
                    _buildQuickChip('💧 Seal Leak', 'Centrifugal pump mechanical seal leaking slurry, replaced gland packing.'),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Action Auto-Fill Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isAiParsing ? null : _runAiAutoFill,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  child: _isAiParsing
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                            SizedBox(width: 10),
                            Text('AI is classifying & formulating fields...', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.auto_awesome, size: 18, color: Colors.amberAccent),
                            SizedBox(width: 8),
                            Text('Auto-Fill Fields with AI', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                ),
              ),

              if (_aiFeedbackMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _aiFeedbackMessage!,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.greenAccent),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
              ],

              if (_lastAiDraft != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (_lastAiDraft!.equipmentName != null)
                      _buildAiTagChip(Icons.precision_manufacturing, _lastAiDraft!.equipmentName!, Colors.tealAccent),
                    _buildAiTagChip(Icons.flash_on, _lastAiDraft!.category.name.toUpperCase(), Colors.amberAccent),
                    _buildAiTagChip(Icons.notification_important, _lastAiDraft!.priority.name.toUpperCase(), Colors.orangeAccent),
                    if (_lastAiDraft!.downtimeMinutes != null)
                      _buildAiTagChip(Icons.timer, '${_lastAiDraft!.downtimeMinutes}m DT', Colors.lightBlueAccent),
                    _buildAiTagChip(Icons.check_circle, _lastAiDraft!.status.name.toUpperCase(), Colors.greenAccent),
                  ],
                ).animate().fadeIn(duration: 300.ms),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAiTagChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String label, String prompt) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      onPressed: () {
        setState(() {
          _aiPromptController.text = prompt;
        });
      },
    );
  }

  // --- 2. TARGET EQUIPMENT & SUB-ASSET ---

  Widget _buildEquipmentSection(ThemeData theme) {
    return GlassContainer(
      borderRadius: 16,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              title: '1. Plant Target Asset',
              icon: Icons.precision_manufacturing_rounded,
              theme: theme,
              color: Colors.tealAccent,
            ),
            const SizedBox(height: 14),

            // Master Equipment Picker
            if (widget.masterEquipmentId != null && widget.masterEquipmentId!.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.build_circle, color: AppColors.accent, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.masterEquipmentName ?? widget.masterEquipmentId!,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            'Tag: ${widget.masterEquipmentId}',
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              SearchableSelectionField<String>(
                label: 'Master Equipment *',
                hintText: 'Search Equipment (e.g. Jaw Crusher 1)...',
                selectedValue: _selectedEquipmentId,
                items: _allEquipments
                    .map((e) => SearchableItem<String>(
                          value: e.id,
                          label: '${e.name} (${e.id})',
                          subtitle: e.type,
                        ))
                    .toList(),
                onChanged: (id) {
                  setState(() {
                    _selectedEquipmentId = id;
                  });
                  if (id != null) _fetchSubAssets(id);
                },
                validator: (val) => val == null || val.isEmpty ? 'Please select equipment' : null,
              ),

            // Sub-Asset Tag (Only shown if available or already tagged)
            if (_isLoadingSubAssets) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 2),
            ] else if (_equipmentSubAssets.isNotEmpty || widget.assetId != null) ...[
              const SizedBox(height: 12),
              _buildDropdown<String?>(
                label: 'Specific Sub-Asset / Component (Optional)',
                value: _selectedAssetId,
                items: [null, ..._equipmentSubAssets.map((a) => a.id)],
                onChanged: (v) => setState(() => _selectedAssetId = v),
                itemLabel: (v) {
                  if (v == null) return 'General Equipment (No Specific Sub-Asset)';
                  final ast = _equipmentSubAssets.firstWhere(
                    (a) => a.id == v,
                    orElse: () => AssetModel.fromMap({'tagNo': v, 'type': 'motor'}, v),
                  );
                  return '${ast.tagNo} (${ast.type.name.toUpperCase()})';
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- 3. SHIFT, PRIORITY & CATEGORY (CRITICAL FOR NOTIFICATION MONITORING) ---

  Widget _buildShiftPriorityCategorySection(ThemeData theme) {
    return GlassContainer(
      borderRadius: 16,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              title: '2. Triage & Notification Severity',
              icon: Icons.notification_important_rounded,
              theme: theme,
              color: Colors.amberAccent,
            ),
            const SizedBox(height: 14),

            // Priority Selector
            const Text('Priority / Severity *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(
              children: FaultPriority.values.map((prio) {
                final isSelected = _selectedPriority == prio;
                Color prioColor;
                switch (prio) {
                  case FaultPriority.critical:
                    prioColor = Colors.red;
                    break;
                  case FaultPriority.high:
                    prioColor = Colors.orange;
                    break;
                  case FaultPriority.medium:
                    prioColor = Colors.blue;
                    break;
                  case FaultPriority.low:
                    prioColor = Colors.green;
                    break;
                }

                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedPriority = prio),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? prioColor.withValues(alpha: 0.25) : theme.colorScheme.surface.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? prioColor : theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                          width: isSelected ? 1.8 : 1.0,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          prio.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? prioColor : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 14),

            // Shift & Category Row
            Row(
              children: [
                Expanded(
                  child: _buildDropdown<WorkShift>(
                    label: 'Operational Shift *',
                    value: _selectedShift,
                    items: WorkShift.values,
                    onChanged: (v) => setState(() => _selectedShift = v!),
                    itemLabel: (v) {
                      switch (v) {
                        case WorkShift.as:
                          return 'Shift A (Morning)';
                        case WorkShift.bs:
                          return 'Shift B (Evening)';
                        case WorkShift.cs:
                          return 'Shift C (Night)';
                        case WorkShift.gs:
                          return 'General Shift';
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildDropdown<FaultCategory>(
                    label: 'Discipline *',
                    value: _selectedCategory,
                    items: FaultCategory.values,
                    onChanged: (v) {
                      setState(() {
                        _selectedCategory = v!;
                        _selectedFaultTypeId = null;
                      });
                    },
                    itemLabel: (v) => v.name.toUpperCase(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- 4. PROBLEM DESCRIPTION & FAILURE MODE ---

  Widget _buildProblemClassificationSection(ThemeData theme) {
    final filteredFaultTypes = _getFilteredFaultTypes();

    return GlassContainer(
      borderRadius: 16,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              title: '3. Problem Statement & Failure Mode',
              icon: Icons.troubleshoot_rounded,
              theme: theme,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 14),

            if (_allFaultTypes.isEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.amber),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No fault catalog found in database. Enter details manually below or import the Fault Types Catalog in Admin > Database Management.',
                        style: TextStyle(fontSize: 11.5, color: Colors.amber),
                      ),
                    ),
                  ],
                ),
              ),

            // Fault Classification Catalog via SearchableSelectionField
            SearchableSelectionField<String>(
              label: 'Catalog Fault Classification (Optional)',
              hintText: 'Search Fault Type (e.g. Overload Trip, Earth Fault)...',
              selectedValue: _selectedFaultTypeId,
              items: [
                const SearchableItem<String>(
                  value: '',
                  label: 'Custom / Uncataloged Fault',
                  subtitle: 'Describe failure symptom manually below',
                ),
                ...filteredFaultTypes.map((ft) => SearchableItem<String>(
                      value: ft['id'].toString(),
                      label: (ft['name'] ?? ft['faultTypeName'] ?? ft['id']).toString(),
                      subtitle: (ft['category'] ?? ft['discipline'] ?? _selectedCategory.name).toString().toUpperCase(),
                    )),
              ],
              onChanged: (v) {
                setState(() {
                  _selectedFaultTypeId = (v != null && v.isNotEmpty) ? v : null;
                  if (_selectedFaultTypeId != null) {
                    final found = filteredFaultTypes.firstWhere(
                      (f) => f['id'].toString() == _selectedFaultTypeId,
                      orElse: () => {},
                    );
                    if (found['name'] != null && _causeController.text.isEmpty) {
                      _causeController.text = found['name'].toString();
                    }
                  }
                });
              },
            ),
            const SizedBox(height: 12),

            // Problem Description / Root Cause Field
            _buildGlassField(
              controller: _causeController,
              label: 'Observed Problem / Symptom *',
              icon: Icons.error_outline_rounded,
              maxLines: 3,
              validator: (val) => val == null || val.trim().isEmpty ? 'Please describe the problem' : null,
            ),
          ],
        ),
      ),
    );
  }

  // --- 5. ACTION TAKEN & PERSONNEL ---

  Widget _buildActionAndPersonnelSection(ThemeData theme) {
    return GlassContainer(
      borderRadius: 16,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              title: '4. Remedial Action & Attended Personnel',
              icon: Icons.handyman_rounded,
              theme: theme,
              color: Colors.blueAccent,
            ),
            const SizedBox(height: 14),

            _buildGlassField(
              controller: _actionController,
              label: 'Action Taken / Remedial Work Done *',
              icon: Icons.build_rounded,
              maxLines: 3,
              validator: (val) => val == null || val.trim().isEmpty ? 'Please describe action taken or pending action' : null,
            ),

            const SizedBox(height: 12),

            // Clean Personnel Multi-Select
            _buildPersonnelSelector(
              title: 'Attended Personnel / Assigned Technicians',
              count: _assignedPersonnelNames.length,
              icon: Icons.people_outline_rounded,
              onTap: () => _openPersonnelSelectionModal(),
            ),
            if (_assignedPersonnelNames.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _assignedPersonnelNames.map((name) {
                  return Chip(
                    label: Text(name, style: const TextStyle(fontSize: 11)),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () => setState(() => _assignedPersonnelNames.remove(name)),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openPersonnelSelectionModal() {
    final theme = Theme.of(context);
    final tempSelected = List<String>.from(_assignedPersonnelNames);
    String searchFilter = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredUsers = _availableUsers.where((u) {
              if (searchFilter.isNotEmpty) {
                final query = searchFilter.toLowerCase();
                final name = (u['name'] ?? u['displayName'] ?? '').toString().toLowerCase();
                final role = (u['role'] ?? '').toString().toLowerCase();
                final dept = (u['department'] ?? '').toString().toLowerCase();
                return name.contains(query) || role.contains(query) || dept.contains(query);
              }
              return true;
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.group_add, color: Colors.indigoAccent),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text('Assign Technicians & Engineers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search name, department, role...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                      ),
                      onChanged: (v) => setModalState(() => searchFilter = v.trim()),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredUsers.length,
                      itemBuilder: (context, idx) {
                        final u = filteredUsers[idx];
                        final name = u['name'] ?? u['displayName'] ?? 'Unknown User';
                        final role = u['role'] ?? 'Technician';
                        final dept = u['department'] ?? '';
                        final isChecked = tempSelected.contains(name);

                        return CheckboxListTile(
                          value: isChecked,
                          title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Text('$role • $dept', style: const TextStyle(fontSize: 11)),
                          onChanged: (val) {
                            setModalState(() {
                              if (val == true) {
                                tempSelected.add(name);
                              } else {
                                tempSelected.remove(name);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      setState(() => _assignedPersonnelNames = tempSelected);
    });
  }

  // --- 6. ODC (ORIGIN-DEFECT-CAUSE) ANALYSIS ---

  Widget _buildOdcSection(ThemeData theme) {
    return GlassContainer(
      borderRadius: 16,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildSectionHeader(
                  title: '5. ODC Root-Cause Analysis',
                  icon: Icons.find_in_page_rounded,
                  theme: theme,
                  color: Colors.purpleAccent,
                ),
                const Spacer(),
                Switch.adaptive(
                  value: _isOdcApplicable,
                  activeTrackColor: theme.colorScheme.primary,
                  onChanged: (val) => setState(() => _isOdcApplicable = val),
                ),
              ],
            ),
            if (!_isOdcApplicable)
              Text(
                'Enable if ISO 14224 / SAP PM Root-Cause Failure Mode analysis (Object Part, Damage, Cause) is required for Pareto audit.',
                style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
              )
            else ...[
              if (_allOdcCauses.isEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.amber),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No ODC catalog found in database. Enter details manually below or import ODC Master Catalog in Admin > Database Management.',
                          style: TextStyle(fontSize: 11.5, color: Colors.amber),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),

              // 1. ODC Object Part (Component)
              SearchableSelectionField<String>(
                label: 'ODC Component / Object Part *',
                hintText: 'Select or Search Component (e.g. DE Bearing, Impeller)...',
                selectedValue: _selectedOdcObject,
                items: _getAvailableOdcObjects()
                    .map((obj) => SearchableItem<String>(
                          value: obj,
                          label: obj,
                          subtitle: 'Component Part • ${_selectedCategory.name.toUpperCase()}',
                        ))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedOdcObject = val;
                    _updateOdcSummaryText();
                  });
                },
              ),

              const SizedBox(height: 12),

              // 2. ODC Defect / Damage Mode(s) (Multi-Select)
              _buildMultiSelectTrigger(
                theme: theme,
                title: 'ODC Defect / Damage Mode(s) *',
                subtitle: _selectedOdcObject != null ? 'Damage typical to $_selectedOdcObject' : 'Failure Symptom(s)',
                icon: Icons.warning_amber_rounded,
                selectedItems: _selectedOdcDamages,
                onTap: () {
                  _openMultiSelectSheet(
                    title: 'Select Defect / Damage Modes',
                    hint: 'Search failure modes (e.g. Earth Fault, Overheating)...',
                    availableItems: _getAvailableOdcDamages(),
                    currentSelected: _selectedOdcDamages,
                    onConfirm: (selected) {
                      setState(() {
                        _selectedOdcDamages = selected;
                        _selectedOdcDamage = selected.isNotEmpty ? selected.first : null;
                        _updateOdcSummaryText();
                      });
                    },
                  );
                },
                onRemove: (item) {
                  setState(() {
                    _selectedOdcDamages.remove(item);
                    _selectedOdcDamage = _selectedOdcDamages.isNotEmpty ? _selectedOdcDamages.first : null;
                    _updateOdcSummaryText();
                  });
                },
              ),

              const SizedBox(height: 12),

              // 3. ODC Root Cause(s) / Mechanism(s) (Multi-Select)
              _buildMultiSelectTrigger(
                theme: theme,
                title: 'ODC Failure Mechanism / Root Cause(s) *',
                subtitle: _selectedOdcDamages.isNotEmpty
                    ? 'Root causes related to ${_selectedOdcDamages.join(", ")}'
                    : 'Failure Mechanism(s)',
                icon: Icons.psychology_alt_rounded,
                selectedItems: _selectedOdcCauses,
                onTap: () {
                  _openMultiSelectSheet(
                    title: 'Select Root Causes',
                    hint: 'Search root causes (e.g. Insulation Breakdown, Winding Short)...',
                    availableItems: _getAvailableOdcCauses(),
                    currentSelected: _selectedOdcCauses,
                    onConfirm: (selected) {
                      setState(() {
                        _selectedOdcCauses = selected;
                        _selectedOdcCause = selected.isNotEmpty ? selected.first : null;
                        _updateOdcSummaryText();
                      });
                    },
                  );
                },
                onRemove: (item) {
                  setState(() {
                    _selectedOdcCauses.remove(item);
                    _selectedOdcCause = _selectedOdcCauses.isNotEmpty ? _selectedOdcCauses.first : null;
                    _updateOdcSummaryText();
                  });
                },
              ),


              const SizedBox(height: 12),

              _buildGlassField(
                controller: _odcController,
                label: 'Specific Defect / Observation (ODC Details)',
                icon: Icons.analytics_outlined,
                maxLines: 2,
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Checkbox(
                    value: _isOdcClosed,
                    activeColor: Colors.green,
                    onChanged: (val) => setState(() => _isOdcClosed = val ?? false),
                  ),
                  const Text('ODC Root Cause Resolved / Closed', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- 7. RESOLUTION STATUS & DOWNTIME ---

  Widget _buildStatusDowntimeSection(ThemeData theme) {
    return GlassContainer(
      borderRadius: 16,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              title: '6. Notification Status & Downtime Impact',
              icon: Icons.timelapse_rounded,
              theme: theme,
              color: Colors.greenAccent,
            ),
            const SizedBox(height: 14),

            // Simplified 2 Industrial Statuses (PENDING, CLOSED) - Action Required vs Rectified
            Row(
              children: [
                _buildStatusOption(
                  theme: theme,
                  status: FaultStatus.pending,
                  label: 'PENDING',
                  color: Colors.amber,
                  icon: Icons.pending_actions_rounded,
                ),
                const SizedBox(width: 12),
                _buildStatusOption(
                  theme: theme,
                  status: FaultStatus.closed,
                  label: 'CLOSED',
                  color: Colors.green,
                  icon: Icons.check_circle_rounded,
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Downtime Minutes with +/- quick buttons
            Row(
              children: [
                Expanded(
                  child: _buildGlassField(
                    controller: _downtimeController,
                    label: 'Downtime Duration (Minutes)',
                    icon: Icons.timer_outlined,
                    isNumber: true,
                  ),
                ),
                const SizedBox(width: 8),
                _buildQuickTimeBtn('+15m', 15),
                const SizedBox(width: 4),
                _buildQuickTimeBtn('+30m', 30),
                const SizedBox(width: 4),
                _buildQuickTimeBtn('+1h', 60),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTimeBtn(String label, int minutesToAdd) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        minimumSize: Size.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: () {
        final cur = int.tryParse(_downtimeController.text.trim()) ?? 0;
        setState(() {
          _downtimeController.text = (cur + minutesToAdd).toString();
        });
      },
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStatusOption({
    required ThemeData theme,
    required FaultStatus status,
    required String label,
    required Color color,
    required IconData icon,
  }) {
    final isSelected = _selectedStatus == status;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedStatus = status),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.22) : theme.colorScheme.surface.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: isSelected ? color : theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? color : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- SECTION HEADERS & WIDGET HELPERS ---

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required ThemeData theme,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildPersonnelSelector({
    required String title,
    required int count,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 55,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    count == 0 ? 'Select attending staff...' : '$count Personnel Assigned',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: count == 0 ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    bool isNumber = false,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.multiline,
      style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13.5),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12.5),
        prefixIcon: Icon(icon, color: theme.colorScheme.primary, size: 19),
        filled: true,
        fillColor: theme.colorScheme.surface.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        errorStyle: TextStyle(color: theme.colorScheme.error, fontSize: 11),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required void Function(T?) onChanged,
    required String Function(T) itemLabel,
  }) {
    final theme = Theme.of(context);
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      items: items
          .map((e) => DropdownMenuItem<T>(
                value: e,
                child: Text(
                  itemLabel(e),
                  style: const TextStyle(fontSize: 12.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ))
          .toList(),
      onChanged: onChanged,
      dropdownColor: theme.colorScheme.surface,
      style: TextStyle(color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12.5),
        filled: true,
        fillColor: theme.colorScheme.surface.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _buildSkeletonForm(bool isDark) {
    final shimmerColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03);
    final highlightColor = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSkeletonCard(height: 120, shimmerColor: shimmerColor, highlightColor: highlightColor),
          const SizedBox(height: 14),
          _buildSkeletonCard(height: 80, shimmerColor: shimmerColor, highlightColor: highlightColor),
          const SizedBox(height: 14),
          _buildSkeletonCard(height: 90, shimmerColor: shimmerColor, highlightColor: highlightColor),
          const SizedBox(height: 14),
          _buildSkeletonCard(height: 140, shimmerColor: shimmerColor, highlightColor: highlightColor),
        ],
      ),
    );
  }

  Widget _buildSkeletonCard({required double height, required Color shimmerColor, required Color highlightColor}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: shimmerColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: highlightColor.withValues(alpha: 0.2)),
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(
          duration: 1000.ms,
          color: highlightColor,
          angle: 0.8,
        );
  }

  // --- 0. SCOPE CARD ---

  Widget _buildScopeCard(ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF064E3B).withValues(alpha: 0.6), const Color(0xFF065F46).withValues(alpha: 0.4)]
              : [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.green.withValues(alpha: isDark ? 0.3 : 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.location_on_rounded, color: Colors.greenAccent, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Active Scope',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Plant Selector or Locked Display
                      _isPlantLocked
                          ? _buildScopeChip(
                              Icons.factory_rounded,
                              _activePlant ?? 'ALL',
                              Colors.teal,
                              locked: true,
                            )
                          : DropdownButton<String>(
                              value: _activePlant,
                              isDense: true,
                              underline: const SizedBox(),
                              items: _plants.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 12)))).toList(),
                              onChanged: _onPlantChanged,
                              hint: const Text('Plant', style: TextStyle(fontSize: 12)),
                            ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.grey),
                      const SizedBox(width: 6),
                      // Unit Selector or Locked Display
                      _isUnitLocked
                          ? _buildScopeChip(
                              Icons.precision_manufacturing_rounded,
                              _activeUnit ?? 'ALL',
                              Colors.indigo,
                              locked: true,
                            )
                          : DropdownButton<String>(
                              value: _activeUnit,
                              isDense: true,
                              underline: const SizedBox(),
                              items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 12)))).toList(),
                              onChanged: _onUnitChanged,
                              hint: const Text('Unit', style: TextStyle(fontSize: 12)),
                            ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.info_outline_rounded, size: 14, color: Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeChip(IconData icon, String label, Color color, {bool locked = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (locked) Icon(Icons.lock_rounded, size: 10, color: color),
          if (locked) const SizedBox(width: 3),
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  // --- ODC MULTI-SELECT HELPERS ---

  Widget _buildMultiSelectTrigger({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<String> selectedItems,
    required VoidCallback onTap,
    required void Function(String) onRemove,
  }) {
    final hasItems = selectedItems.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasItems
                    ? theme.colorScheme.primary.withValues(alpha: 0.5)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 19, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: hasItems ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      if (!hasItems)
                        Text(
                          subtitle,
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                        ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    if (hasItems)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${selectedItems.length} selected',
                          style: TextStyle(fontSize: 10, color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    const SizedBox(width: 6),
                    Icon(Icons.add_circle_outline_rounded, size: 18, color: theme.colorScheme.primary),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (hasItems) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: selectedItems.map((item) => Chip(
              label: Text(item, style: const TextStyle(fontSize: 11)),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              deleteIcon: const Icon(Icons.close, size: 14),
              onDeleted: () => onRemove(item),
            )).toList(),
          ),
        ],
      ],
    );
  }

  void _openMultiSelectSheet({
    required String title,
    required String hint,
    required List<String> availableItems,
    required List<String> currentSelected,
    required void Function(List<String>) onConfirm,
  }) {
    final theme = Theme.of(context);
    final tempSelected = List<String>.from(currentSelected);
    String searchFilter = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final filtered = availableItems.where((item) {
            if (searchFilter.isNotEmpty) {
              return item.toLowerCase().contains(searchFilter.toLowerCase());
            }
            return true;
          }).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.checklist_rounded, color: Colors.purpleAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          onConfirm(tempSelected);
                          Navigator.pop(context);
                        },
                        child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: hint,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                    ),
                    onChanged: (v) => setModalState(() => searchFilter = v.trim()),
                  ),
                ),
                if (tempSelected.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: tempSelected.map((s) => Chip(
                        label: Text(s, style: const TextStyle(fontSize: 11)),
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        deleteIcon: const Icon(Icons.close, size: 13),
                        onDeleted: () => setModalState(() => tempSelected.remove(s)),
                      )).toList(),
                    ),
                  ),
                const Divider(height: 1),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            availableItems.isEmpty
                                ? 'No catalog items found. Import ODC Master Catalog first.'
                                : 'No results for "$searchFilter"',
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, idx) {
                            final item = filtered[idx];
                            final isChecked = tempSelected.contains(item);
                            return CheckboxListTile(
                              value: isChecked,
                              title: Text(item, style: const TextStyle(fontSize: 13)),
                              activeColor: Colors.purpleAccent,
                              onChanged: (val) {
                                setModalState(() {
                                  if (val == true) {
                                    tempSelected.add(item);
                                  } else {
                                    tempSelected.remove(item);
                                  }
                                });
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

