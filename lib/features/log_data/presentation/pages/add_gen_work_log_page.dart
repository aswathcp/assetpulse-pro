import 'package:material_ui/material_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_roles.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/hierarchy_service.dart';
import '../../../../core/services/ai_fault_log_service.dart';
import '../../../../core/services/ai_general_work_log_service.dart';
import '../../../../core/services/others_suggestion_service.dart';
import '../../../../core/utils/permission_helper.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../../core/widgets/searchable_picker_sheet.dart';
import '../../../home/presentation/widgets/custom_app_bar.dart';
import '../../../assets/data/models/asset_model.dart';
import '../../../assets/data/models/fault_log_model.dart';
import '../../../assets/data/models/master_equipment_model.dart';
import '../../../assets/data/models/location_model.dart';
import '../../../assets/data/models/feeder_model.dart';
import '../../../admin/data/models/workman_model.dart';
import '../../data/models/general_work_log_model.dart';

class AddGenWorkLogPage extends StatefulWidget {
  final GeneralWorkLogModel? existingLog;
  final String? plantId;
  final String? unitId;

  const AddGenWorkLogPage({
    super.key,
    this.existingLog,
    this.plantId,
    this.unitId,
  });

  @override
  State<AddGenWorkLogPage> createState() => _AddGenWorkLogPageState();
}

class _AddGenWorkLogPageState extends State<AddGenWorkLogPage> {
  final _formKey = GlobalKey<FormState>();
  final FirestoreService _firestoreService = FirestoreService();

  bool _isSaving = false;
  bool _isLoading = true;
  bool _isAiExtracting = false;
  bool _showAiCard = true;
  bool _hasGeminiApiKey = false;

  // AI Prompt Controller
  final TextEditingController _aiPromptController = TextEditingController();

  // Primary Fields
  DateTime _selectedDate = DateTime.now();
  WorkShift _selectedShift = WorkShift.as;
  String _selectedStatus = 'completed'; // 'completed' or 'pending'

  // Team Selection State
  List<Map<String, dynamic>> _registeredUsers = [];
  List<WorkmanModel> _registeredWorkmen = [];
  final List<String> _selectedEngineerUserIds = [];
  final List<String> _selectedEngineerNames = [];
  final List<String> _selectedWorkmenIds = [];
  final List<String> _selectedWorkmenNames = [];

  // Multi-Equipment Work Blocks
  List<EquipmentWorkBlock> _equipmentBlocks = [];
  final Map<String, List<AssetModel>> _blockSubAssets = {};
  final Set<String> _loadingSubAssetsForEquip = {};

  // Equipment & Asset Catalog
  List<MasterEquipmentModel> _allEquipments = [];
  List<LocationModel> _allLocations = [];
  List<FeederModel> _allFeeders = [];

  // Scope State
  String? _activePlant;
  String? _activeUnit;
  List<String> _plants = [];
  List<String> _units = [];
  bool _isPlantLocked = false;
  bool _isUnitLocked = false;
  String _userRole = '';
  Map<String, dynamic>? _userProfile;

  final List<String> _categories = const [
    'Motors & Drives',
    'Cabling & Power Distribution',
    'Lighting & Illumination',
    'Cranes & Material Handling',
    'Preventive Maintenance (PM)',
    'Instrumentation & Automation',
    'Plant Facilities & Utilities',
    'General Maintenance',
  ];

  @override
  void initState() {
    super.initState();
    _activePlant = widget.plantId;
    _activeUnit = widget.unitId;

    if (widget.existingLog != null) {
      _showAiCard = false;
      _populateFromExisting(widget.existingLog!);
    } else {
      // Default to 1 empty equipment block to start easily
      _equipmentBlocks.add(
        EquipmentWorkBlock(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          equipmentName: '',
          category: 'General Maintenance',
          tasks: [],
          status: 'completed',
        ),
      );
    }

    _loadInitialData();
  }

  @override
  void dispose() {
    _aiPromptController.dispose();
    super.dispose();
  }

  void _populateFromExisting(GeneralWorkLogModel log) {
    _selectedDate = log.date;
    _selectedShift = log.shift;
    _selectedStatus = log.status;
    _activePlant = log.plantId;
    _activeUnit = log.unitId;

    _selectedEngineerUserIds.addAll(log.engineerUserIds);
    _selectedEngineerNames.addAll(log.engineerNames);
    _selectedWorkmenIds.addAll(log.workmenIds);
    _selectedWorkmenNames.addAll(log.workmenNames);

    _equipmentBlocks = log.equipmentWorks.map((e) => e.copyWith()).toList();
    if (_equipmentBlocks.isEmpty) {
      _equipmentBlocks.add(
        EquipmentWorkBlock(
          id: '1',
          equipmentName: log.equipmentOrArea,
          category: log.category,
          tasks: List.from(log.items),
          pendingFollowUp: log.pendingFollowUp,
          status: log.status,
          location: log.location,
        ),
      );
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final user = AuthService().currentUser;
      if (user != null) {
        final profile = await _firestoreService.getUserProfile(user.uid);
        if (profile != null) {
          _userProfile = profile;
          _userRole = profile['role'] ?? AppRoles.guest;
          final userBusinessId = profile['businessId'] as String? ?? 'VISL';
          await HierarchyService().init(businessId: userBusinessId);

          final userScope = PermissionHelper.resolveUserScope(profile);
          _isPlantLocked = userScope.isPlantLocked;
          _isUnitLocked = userScope.isUnitLocked;

          _plants = userScope.getAvailablePlants();
          _activePlant ??= userScope.getInitialPlant(_plants);
          if (_activePlant != null) {
            _units = userScope.getAvailableUnits(_activePlant!);
            _activeUnit ??= userScope.getInitialUnit(_units);
          }

          // Pre-select current user as attending engineer if empty
          if (_selectedEngineerUserIds.isEmpty) {
            final myName = profile['displayName'] ?? user.displayName ?? 'Engineer';
            _selectedEngineerUserIds.add(user.uid);
            _selectedEngineerNames.add(myName);
          }
        }
      }

      await Future.wait([
        _fetchUsers(),
        _fetchWorkmen(),
        _fetchEquipments(),
        _fetchLocations(),
        _fetchFeeders(),
        _checkApiKey(),
      ]);

      // Pre-load sub-assets for existing equipment blocks
      for (final b in _equipmentBlocks) {
        if (b.masterEquipmentId != null && b.masterEquipmentId!.isNotEmpty) {
          _fetchSubAssetsForEquipment(b.masterEquipmentId!);
        }
      }
    } catch (e) {
      debugPrint('Error loading initial data in AddGenWorkLogPage: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkApiKey() async {
    final aiService = AiFaultLogService();
    final key = await aiService.getApiKey();
    if (mounted) {
      setState(() {
        _hasGeminiApiKey = key != null && key.trim().isNotEmpty;
      });
    }
  }

  Future<void> _fetchSubAssetsForEquipment(String equipmentId) async {
    if (_blockSubAssets.containsKey(equipmentId)) return;
    setState(() => _loadingSubAssetsForEquip.add(equipmentId));
    try {
      final snap = await FirebaseFirestore.instance
          .collection('assets')
          .where('masterEquipmentId', isEqualTo: equipmentId)
          .get();
      final subAssets = snap.docs.map((d) => AssetModel.fromMap(d.data(), d.id)).toList();
      if (mounted) {
        setState(() {
          _blockSubAssets[equipmentId] = subAssets;
        });
      }
    } catch (e) {
      debugPrint('Error fetching sub-assets for $equipmentId: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingSubAssetsForEquip.remove(equipmentId));
      }
    }
  }

  Future<void> _fetchUsers() async {
    final users = await _firestoreService.getAllUsers();
    if (mounted) setState(() => _registeredUsers = users);
  }

  Future<void> _fetchWorkmen() async {
    _firestoreService.getWorkmenStream(activeOnly: true).listen((workmen) {
      if (mounted) setState(() => _registeredWorkmen = workmen);
    });
  }

  Future<void> _fetchEquipments() async {
    Query q = FirebaseFirestore.instance.collection('master_equipments');
    if (_activePlant != null && _activePlant!.isNotEmpty && _activePlant != 'ALL') {
      q = q.where('plantId', isEqualTo: _activePlant);
    }
    if (_activeUnit != null && _activeUnit!.isNotEmpty && _activeUnit != 'ALL') {
      q = q.where('unitId', isEqualTo: _activeUnit);
    }
    final snap = await q.get();
    if (mounted) {
      setState(() {
        _allEquipments = snap.docs.map((d) => MasterEquipmentModel.fromMap(d.data() as Map<String, dynamic>, d.id)).toList();
      });
    }
  }

  Future<void> _fetchLocations() async {
    Query q = FirebaseFirestore.instance.collection('locations');
    if (_activePlant != null && _activePlant!.isNotEmpty && _activePlant != 'ALL') {
      q = q.where('plantId', isEqualTo: _activePlant);
    }
    if (_activeUnit != null && _activeUnit!.isNotEmpty && _activeUnit != 'ALL') {
      q = q.where('unitId', isEqualTo: _activeUnit);
    }
    final snap = await q.get();
    if (mounted) {
      setState(() {
        _allLocations = snap.docs.map((d) => LocationModel.fromMap(d.data() as Map<String, dynamic>, d.id)).toList();
      });
    }
  }

  Future<void> _fetchFeeders() async {
    Query q = FirebaseFirestore.instance.collection('feeders');
    if (_activePlant != null && _activePlant!.isNotEmpty && _activePlant != 'ALL') {
      q = q.where('plantId', isEqualTo: _activePlant);
    }
    if (_activeUnit != null && _activeUnit!.isNotEmpty && _activeUnit != 'ALL') {
      q = q.where('unitId', isEqualTo: _activeUnit);
    }
    final snap = await q.get();
    if (mounted) {
      setState(() {
        _allFeeders = snap.docs.map((d) => FeederModel.fromMap(d.data() as Map<String, dynamic>, d.id)).toList();
      });
    }
  }

  // --- SMART PICKER: EQUIPMENT ---
  Future<void> _pickEquipment(int blockIndex) async {
    final block = _equipmentBlocks[blockIndex];
    final items = [
      ..._allEquipments.map((e) => PickerItem(
            id: e.id,
            label: e.name,
            subtitle: '${e.type} • ${e.area} • ${e.id}',
            icon: Icons.precision_manufacturing_outlined,
          )),
    ];
    final picked = await showSearchablePicker(
      context: context,
      title: 'Select Equipment',
      items: items,
      currentId: block.masterEquipmentId,
      allowOthers: true,
      othersHint: 'e.g. BF2 Man Cooler, Old Cooling Tower...',
    );
    if (picked == null || !mounted) return;

    if (picked.isOthers) {
      // Submit Others suggestion
      final user = AuthService().currentUser;
      await OthersSuggestionService.submit(
        collection: 'master_equipments',
        suggestedName: picked.label,
        context: 'General Work Log - Equipment field',
        submittedByUserId: user?.uid,
        submittedByName: _userProfile?['displayName'] ?? user?.displayName,
        plantId: _activePlant,
        unitId: _activeUnit,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.pending_actions, color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('"${picked.label}" submitted for admin review!')),
            ],
          ),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _equipmentBlocks[blockIndex] = block.copyWith(
          equipmentName: picked.label,
          masterEquipmentId: null,
          assetId: null,
          assetName: null,
          location: null,
          locationId: null,
          feederName: null,
          feederId: null,
        );
      });
      return;
    }

    // Auto-link location & feeder from equipment master data
    final matchedEquipment = _allEquipments.firstWhere((e) => e.id == picked.id, orElse: () => _allEquipments.first);
    final linkedLocation = _allLocations.firstWhere(
      (l) => l.id == matchedEquipment.locationId,
      orElse: () => LocationModel(id: '', unitId: '', plantId: '', name: ''),
    );
    final linkedFeeder = matchedEquipment.feederId != null && matchedEquipment.feederId!.isNotEmpty
        ? _allFeeders.firstWhere((f) => f.id == matchedEquipment.feederId, orElse: () => FeederModel(id: '', plantId: '', unitId: '', panelId: '', name: ''))
        : null;

    setState(() {
      _equipmentBlocks[blockIndex] = block.copyWith(
        equipmentName: picked.label,
        masterEquipmentId: picked.id,
        // Clear sub-asset on equipment change
        assetId: null,
        assetName: null,
        location: linkedLocation.name.isNotEmpty ? linkedLocation.name : null,
        locationId: linkedLocation.id.isNotEmpty ? linkedLocation.id : null,
        feederName: linkedFeeder != null && linkedFeeder.name.isNotEmpty ? linkedFeeder.name : null,
        feederId: linkedFeeder != null && linkedFeeder.id.isNotEmpty ? linkedFeeder.id : null,
      );
    });

    _fetchSubAssetsForEquipment(picked.id);
  }

  // --- SMART PICKER: SUB-ASSET (OPTIONAL) ---
  Future<void> _pickSubAsset(int blockIndex) async {
    final block = _equipmentBlocks[blockIndex];
    if (block.masterEquipmentId == null) return;
    final subAssets = _blockSubAssets[block.masterEquipmentId] ?? [];
    if (subAssets.isEmpty) return;

    final items = [
      ...subAssets.map((a) => PickerItem(
            id: a.id,
            label: '${a.tagNo} (${a.type.name.toUpperCase()})',
            subtitle: a.name.isNotEmpty ? a.name : '${a.make} ${a.model}'.trim(),
            icon: Icons.hub_outlined,
          )),
    ];

    final picked = await showSearchablePicker(
      context: context,
      title: 'Select Sub-Asset / Component (Optional)',
      items: items,
      currentId: block.assetId,
      allowOthers: false,
    );
    if (picked == null || !mounted) return;

    final matched = subAssets.firstWhere((a) => a.id == picked.id, orElse: () => subAssets.first);
    setState(() {
      _equipmentBlocks[blockIndex] = block.copyWith(
        assetId: matched.id,
        assetName: matched.tagNo,
      );
    });
  }

  // --- SMART PICKER: LOCATION ---
  Future<void> _pickLocation(int blockIndex) async {
    final block = _equipmentBlocks[blockIndex];
    final items = [
      ..._allLocations.map((l) => PickerItem(
            id: l.id,
            label: l.name,
            subtitle: l.type,
            icon: Icons.place_outlined,
          )),
    ];
    final picked = await showSearchablePicker(
      context: context,
      title: 'Select Location / Area',
      items: items,
      currentId: block.locationId,
      allowOthers: true,
      othersHint: 'e.g. BF2 Cast House, Substation 2, Store Yard...',
    );
    if (picked == null || !mounted) return;

    final hadEquipment = block.equipmentName.isNotEmpty || block.masterEquipmentId != null;

    if (picked.isOthers) {
      final user = AuthService().currentUser;
      await OthersSuggestionService.submit(
        collection: 'locations',
        suggestedName: picked.label,
        context: 'General Work Log - Location field',
        submittedByUserId: user?.uid,
        submittedByName: _userProfile?['displayName'] ?? user?.displayName,
        plantId: _activePlant,
        unitId: _activeUnit,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${picked.label}" submitted for admin review!'),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _equipmentBlocks[blockIndex] = block.copyWith(
          location: picked.label,
          locationId: null,
          // Unlink previous equipment & sub-asset on location change
          equipmentName: '',
          masterEquipmentId: null,
          assetId: null,
          assetName: null,
          feederName: null,
          feederId: null,
        );
      });
      if (hadEquipment && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location changed: previous equipment and feeder unlinked.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() {
      _equipmentBlocks[blockIndex] = block.copyWith(
        location: picked.label,
        locationId: picked.id,
        // Unlink previous equipment & sub-asset on location change
        equipmentName: '',
        masterEquipmentId: null,
        assetId: null,
        assetName: null,
        feederName: null,
        feederId: null,
      );
    });

    if (hadEquipment && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location changed: previous equipment and feeder unlinked.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // --- SMART PICKER: FEEDER ---
  Future<void> _pickFeeder(int blockIndex) async {
    final block = _equipmentBlocks[blockIndex];
    final items = [
      ..._allFeeders.map((f) => PickerItem(
            id: f.id,
            label: f.name,
            subtitle: '${f.type} • ${f.panelId}',
            icon: Icons.electrical_services_outlined,
          )),
    ];
    final picked = await showSearchablePicker(
      context: context,
      title: 'Select Feeder / Panel',
      items: items,
      currentId: block.feederId,
      allowOthers: true,
      othersHint: 'e.g. MCC 2N9, MCCB-1, Feeder A4...',
    );
    if (picked == null || !mounted) return;

    final hadEquipment = block.equipmentName.isNotEmpty || block.masterEquipmentId != null;

    if (picked.isOthers) {
      final user = AuthService().currentUser;
      await OthersSuggestionService.submit(
        collection: 'feeders',
        suggestedName: picked.label,
        context: 'General Work Log - Feeder field',
        submittedByUserId: user?.uid,
        submittedByName: _userProfile?['displayName'] ?? user?.displayName,
        plantId: _activePlant,
        unitId: _activeUnit,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${picked.label}" submitted for admin review!'),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _equipmentBlocks[blockIndex] = block.copyWith(
          feederName: picked.label,
          feederId: null,
          // Unlink previous equipment & sub-asset on feeder change
          equipmentName: '',
          masterEquipmentId: null,
          assetId: null,
          assetName: null,
        );
      });
      if (hadEquipment && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feeder changed: previous equipment unlinked.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() {
      _equipmentBlocks[blockIndex] = block.copyWith(
        feederName: picked.label,
        feederId: picked.id,
        // Unlink previous equipment & sub-asset on feeder change
        equipmentName: '',
        masterEquipmentId: null,
        assetId: null,
        assetName: null,
      );
    });

    if (hadEquipment && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feeder changed: previous equipment unlinked.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _updateUnitList() {
    if (_activePlant == null) {
      _units = [];
      _activeUnit = null;
    } else {
      _units = HierarchyService().getUnitsForPlant(_activePlant!);
      if (_units.isEmpty) _units = ['PID1', 'MCD'];
      if (!_units.contains(_activeUnit)) {
        _activeUnit = _units.isNotEmpty ? _units.first : null;
      }
    }
    _fetchEquipments();
    _fetchLocations();
    _fetchFeeders();
  }

  // --- GEMINI AI EXTRACTOR ---
  Future<void> _runAiExtraction() async {
    final text = _aiPromptController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter or paste your shift notes first.')),
      );
      return;
    }

    setState(() => _isAiExtracting = true);

    try {
      final userNames = _registeredUsers.map((u) => u['displayName']?.toString() ?? '').where((n) => n.isNotEmpty).toList();
      final workmenNames = _registeredWorkmen.map((w) => w.name).toList();

      final draft = await AiGeneralWorkLogService().extractGeneralWorkFromText(
        rawText: text,
        availableEquipments: _allEquipments,
        registeredUserNames: userNames,
        registeredWorkmenNames: workmenNames,
      );

      setState(() {
        if (draft.date != null) _selectedDate = draft.date!;

        if (draft.shift == 'bs') {
          _selectedShift = WorkShift.bs;
        } else if (draft.shift == 'cs') {
          _selectedShift = WorkShift.cs;
        } else if (draft.shift == 'gs') {
          _selectedShift = WorkShift.gs;
        } else {
          _selectedShift = WorkShift.as;
        }

        // Match Engineers
        for (final eng in draft.detectedEngineers) {
          final match = _registeredUsers.firstWhere(
            (u) => (u['displayName']?.toString() ?? '').toLowerCase().contains(eng.toLowerCase()),
            orElse: () => {},
          );
          if (match.isNotEmpty) {
            final uid = match['uid']?.toString() ?? '';
            final name = match['displayName']?.toString() ?? eng;
            if (!_selectedEngineerUserIds.contains(uid)) {
              _selectedEngineerUserIds.add(uid);
              _selectedEngineerNames.add(name);
            }
          }
        }

        // Match Workmen (strictly registered workmen in database)
        for (final wName in draft.detectedWorkmen) {
          final match = _registeredWorkmen.firstWhere(
            (w) => w.name.toLowerCase().contains(wName.toLowerCase()) || wName.toLowerCase().contains(w.name.toLowerCase()),
            orElse: () => WorkmanModel(id: '', name: '', createdAt: DateTime.now()),
          );
          if (match.name.isNotEmpty) {
            if (!_selectedWorkmenIds.contains(match.id)) {
              _selectedWorkmenIds.add(match.id);
              _selectedWorkmenNames.add(match.name);
            }
          }
        }

        // Replace or add parsed equipment blocks
        if (draft.equipmentWorks.isNotEmpty) {
          _equipmentBlocks = draft.equipmentWorks;
          for (final b in _equipmentBlocks) {
            if (b.masterEquipmentId != null && b.masterEquipmentId!.isNotEmpty) {
              _fetchSubAssetsForEquipment(b.masterEquipmentId!);
            }
          }
        }

        // Check if any block has pending
        if (_equipmentBlocks.any((b) => b.status == 'pending')) {
          _selectedStatus = 'pending';
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 20),
              const SizedBox(width: 8),
              Text('AI successfully extracted ${_equipmentBlocks.length} equipment work blocks!'),
            ],
          ),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI Extraction failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isAiExtracting = false);
    }
  }

  // --- GEMINI API KEY SETTINGS DIALOG ---
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
                    activeThumbColor: Colors.greenAccent,
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
                const Text(
                  '🔗 Get free key at aistudio.google.com',
                  style: TextStyle(fontSize: 11, color: Colors.blueAccent, decoration: TextDecoration.underline),
                ),
              ],
            ),
          ),
          actions: [
            if (savedKey.isNotEmpty)
              TextButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await aiService.saveApiKey('');
                  await aiService.setDeveloperKeyEnabled(true);
                  await _checkApiKey();
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    messenger.showSnackBar(
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
                final messenger = ScaffoldMessenger.of(context);
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
                  messenger.showSnackBar(
                    SnackBar(content: Text(msg), backgroundColor: Colors.green),
                  );
                }
              },
              child: const Text('Save Settings'),
            ),
          ],
        ),
      ),
    );
  }

  // --- SELECTION MODAL: ENGINEERS ---
  void _openEngineerSelectionModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String searchFilter = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredUsers = _registeredUsers.where((u) {
              if (searchFilter.isNotEmpty) {
                final query = searchFilter.toLowerCase();
                final name = (u['displayName'] ?? u['name'] ?? '').toString().toLowerCase();
                final dept = (u['department'] ?? '').toString().toLowerCase();
                final empId = (u['employeeId'] ?? '').toString().toLowerCase();
                return name.contains(query) || dept.contains(query) || empId.contains(query);
              }
              return true;
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.72,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.engineering_outlined, color: Color(0xFF2563EB), size: 22),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Select Attending Engineers',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search registered engineers...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      style: const TextStyle(fontSize: 13),
                      onChanged: (val) => setModalState(() => searchFilter = val.trim()),
                    ),
                  ),
                  Expanded(
                    child: filteredUsers.isEmpty
                        ? const Center(child: Text('No engineers found', style: TextStyle(color: Colors.grey)))
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            itemCount: filteredUsers.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final u = filteredUsers[idx];
                              final uid = u['uid']?.toString() ?? '';
                              final name = u['displayName']?.toString() ?? u['name']?.toString() ?? 'Engineer';
                              final dept = u['department']?.toString() ?? 'Operations';
                              final empId = u['employeeId']?.toString();
                              final isSelected = _selectedEngineerUserIds.contains(uid);

                              return ListTile(
                                dense: true,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                tileColor: isSelected
                                    ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                                    : null,
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.2),
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'E',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                  ),
                                ),
                                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                subtitle: Text(
                                  empId != null && empId.isNotEmpty ? '$dept • ID: $empId' : dept,
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle, color: Color(0xFF2563EB), size: 20)
                                    : const Icon(Icons.circle_outlined, color: Colors.grey, size: 20),
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      final i = _selectedEngineerUserIds.indexOf(uid);
                                      if (i != -1) {
                                        _selectedEngineerUserIds.removeAt(i);
                                        if (i < _selectedEngineerNames.length) {
                                          _selectedEngineerNames.removeAt(i);
                                        }
                                      }
                                    } else {
                                      _selectedEngineerUserIds.add(uid);
                                      _selectedEngineerNames.add(name);
                                    }
                                  });
                                  setModalState(() {});
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
    );
  }

  // --- SELECTION MODAL: WORKMEN (NO ADD OPTION - ADMIN ONLY) ---
  void _openWorkmanSelectionModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String searchFilter = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredWorkmen = _registeredWorkmen.where((w) {
              if (searchFilter.isNotEmpty) {
                final query = searchFilter.toLowerCase();
                return w.name.toLowerCase().contains(query) ||
                    w.trade.toLowerCase().contains(query) ||
                    w.contractor.toLowerCase().contains(query);
              }
              return true;
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.72,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.handyman_outlined, color: Colors.orange, size: 22),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Select Workmen / Contractors',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search registered workmen...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      style: const TextStyle(fontSize: 13),
                      onChanged: (val) => setModalState(() => searchFilter = val.trim()),
                    ),
                  ),
                  Expanded(
                    child: filteredWorkmen.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Text(
                                'No registered workmen found in database.\nNew workmen can only be registered by Admin in Database Management.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            itemCount: filteredWorkmen.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final w = filteredWorkmen[idx];
                              final isSelected = _selectedWorkmenIds.contains(w.id);

                              return ListTile(
                                dense: true,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                tileColor: isSelected ? Colors.orange.withValues(alpha: 0.1) : null,
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.orange.withValues(alpha: 0.2),
                                  child: Text(
                                    w.name.isNotEmpty ? w.name[0].toUpperCase() : 'W',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                                  ),
                                ),
                                title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                subtitle: Text(
                                  '${w.trade} • ${w.contractor}',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle, color: Colors.orange, size: 20)
                                    : const Icon(Icons.circle_outlined, color: Colors.grey, size: 20),
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      final i = _selectedWorkmenIds.indexOf(w.id);
                                      if (i != -1) {
                                        _selectedWorkmenIds.removeAt(i);
                                        if (i < _selectedWorkmenNames.length) {
                                          _selectedWorkmenNames.removeAt(i);
                                        }
                                      }
                                    } else {
                                      _selectedWorkmenIds.add(w.id);
                                      _selectedWorkmenNames.add(w.name);
                                    }
                                  });
                                  setModalState(() {});
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
    );
  }

  // --- SAVE LOG: SAVE EACH EQUIPMENT/ASSET SEPARATELY ---
  Future<void> _saveLog() async {
    final canEdit = PermissionHelper.canEditDatabase(_userRole);
    if (!canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('View-only users (HOD / Guest / Auditor) cannot create or modify work logs.')),
      );
      return;
    }

    // Filter out blocks that have zero tasks, empty equipment, empty location, and empty feeder
    final validBlocks = _equipmentBlocks.where((b) =>
      b.tasks.isNotEmpty ||
      b.equipmentName.trim().isNotEmpty ||
      (b.location?.trim().isNotEmpty == true) ||
      (b.feederName?.trim().isNotEmpty == true)
    ).toList();

    if (validBlocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one entry with an equipment, location, feeder, or tasks.')),
      );
      return;
    }

    // Normalize each block so equipmentName is populated even if user only selected location or feeder
    final normalizedBlocks = validBlocks.map((b) {
      final effectiveName = b.equipmentName.trim().isNotEmpty
          ? b.equipmentName.trim()
          : (b.location?.trim().isNotEmpty == true
              ? b.location!.trim()
              : (b.feederName?.trim().isNotEmpty == true
                  ? b.feederName!.trim()
                  : 'General Maintenance'));
      return b.copyWith(equipmentName: effectiveName);
    }).toList();

    setState(() => _isSaving = true);
    final user = AuthService().currentUser;
    final userName = _userProfile?['displayName'] ?? user?.displayName ?? 'Duty Engineer';
    final userId = user?.uid ?? 'unknown';

    try {
      if (widget.existingLog != null) {
        // Editing existing log
        final isOverallPending = normalizedBlocks.any((b) => b.status == 'pending');
        final updatedLog = widget.existingLog!.copyWith(
          date: _selectedDate,
          shift: _selectedShift,
          plantId: _activePlant,
          unitId: _activeUnit,
          location: normalizedBlocks.first.location,
          engineerUserIds: _selectedEngineerUserIds,
          engineerNames: _selectedEngineerNames,
          workmenIds: _selectedWorkmenIds,
          workmenNames: _selectedWorkmenNames,
          equipmentWorks: normalizedBlocks,
          status: isOverallPending ? 'pending' : _selectedStatus,
        );
        await _firestoreService.updateGeneralWorkLog(updatedLog);
      } else {
        // Creating new logs: save different equipment/asset/location data separately with same date, shift, users, etc.
        for (final block in normalizedBlocks) {
          final log = GeneralWorkLogModel(
            id: '',
            date: _selectedDate,
            shift: _selectedShift,
            plantId: _activePlant,
            unitId: _activeUnit,
            location: block.location,
            engineerUserIds: List.from(_selectedEngineerUserIds),
            engineerNames: List.from(_selectedEngineerNames),
            workmenIds: List.from(_selectedWorkmenIds),
            workmenNames: List.from(_selectedWorkmenNames),
            equipmentWorks: [block],
            status: block.status,
            reportedByUserId: userId,
            reportedByName: userName,
            reportedAt: DateTime.now(),
            rawAiInput: _aiPromptController.text.trim().isNotEmpty ? _aiPromptController.text.trim() : null,
          );
          await _firestoreService.addGeneralWorkLog(log);
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
        final count = normalizedBlocks.length;
        final msg = widget.existingLog != null
            ? 'General log updated successfully!'
            : count > 1
                ? '$count work logs saved separately successfully!'
                : 'General work log saved successfully!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving work log: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: CustomAppBar(
        title: widget.existingLog != null ? 'Edit General Work Log' : 'Log General Work',
      ),
      body: AnimatedGradientBackground(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _isLoading
              ? _buildSkeletonForm(isDark)
              : SingleChildScrollView(
                  key: const ValueKey('loaded_form'),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Plant Scope at Top (matching Log Fault page)
                        _buildScopeCard(isDark),
                        const SizedBox(height: 14),

                        // 2. AI Assistant Hero Card (Gemini Cloud AI / Offline NLP with settings key toggle)
                        _buildAiExtractionCard(isDark),
                        const SizedBox(height: 14),

                        // 3. Timing & Shift
                        _buildTimingSection(isDark),
                        const SizedBox(height: 14),

                        // 4. Team Selection (Registered Engineers & Workmen - No inline add, Admin database only)
                        _buildTeamSelectionSection(isDark),
                        const SizedBox(height: 20),

                        // 5. Multi-Equipment Work Entries
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 3.5,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Equipment Work Entries',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                            Text(
                              '${_equipmentBlocks.length} Equipment',
                              style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        ...List.generate(_equipmentBlocks.length, (idx) {
                          return _buildEquipmentWorkCard(idx, isDark);
                        }),

                        const SizedBox(height: 12),

                        // Button to Add Another Equipment Block
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _equipmentBlocks.add(
                                EquipmentWorkBlock(
                                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                                  equipmentName: '',
                                  category: 'General Maintenance',
                                  tasks: [],
                                  status: 'completed',
                                ),
                              );
                            });
                          },
                          icon: const Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF2563EB)),
                          label: const Text(
                            '+ Add Another Equipment Work Entry',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2563EB)),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.2))),
        ),
        child: SafeArea(
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveLog,
            icon: _isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle, color: Colors.white),
            label: Text(
              _isSaving ? 'Saving...' : (widget.existingLog != null ? 'Update Log' : 'Save General Work Log'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ),
    );
  }

  // --- SKELETON LOADING (MATCHING LOG FAULT) ---
  Widget _buildSkeletonForm(bool isDark) {
    final shimmerColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03);
    final highlightColor = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSkeletonCard(height: 70, shimmerColor: shimmerColor, highlightColor: highlightColor),
          const SizedBox(height: 14),
          _buildSkeletonCard(height: 100, shimmerColor: shimmerColor, highlightColor: highlightColor),
          const SizedBox(height: 14),
          _buildSkeletonCard(height: 60, shimmerColor: shimmerColor, highlightColor: highlightColor),
          const SizedBox(height: 14),
          _buildSkeletonCard(height: 110, shimmerColor: shimmerColor, highlightColor: highlightColor),
          const SizedBox(height: 14),
          _buildSkeletonCard(height: 180, shimmerColor: shimmerColor, highlightColor: highlightColor),
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

  // --- 1. ACTIVE SCOPE (PLANT & UNIT) AT TOP ---
  Widget _buildScopeCard(bool isDark) {
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
                              value: _plants.contains(_activePlant) ? _activePlant : (_plants.isNotEmpty ? _plants.first : null),
                              isDense: true,
                              underline: const SizedBox(),
                              items: _plants.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 12)))).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _activePlant = val;
                                    _updateUnitList();
                                  });
                                }
                              },
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
                              value: _units.contains(_activeUnit) ? _activeUnit : (_units.isNotEmpty ? _units.first : null),
                              isDense: true,
                              underline: const SizedBox(),
                              items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 12)))).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _activeUnit = val);
                                  _fetchEquipments();
                                  _fetchLocations();
                                  _fetchFeeders();
                                }
                              },
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

  // --- 2. AI ASSISTANT HERO CARD ---
  Widget _buildAiExtractionCard(bool isDark) {
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
        borderRadius: BorderRadius.circular(16),
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
                                    _hasGeminiApiKey ? Icons.cloud_done : Icons.cloud_off,
                                    size: 11,
                                    color: _hasGeminiApiKey ? Colors.green : Colors.amber.shade700,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    _hasGeminiApiKey ? 'GEMINI CLOUD AI' : 'OFFLINE NLP',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: _hasGeminiApiKey ? Colors.green : Colors.amber.shade700,
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
                        'Speak or paste shift notes to auto-extract logs',
                        style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
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
              TextField(
                controller: _aiPromptController,
                maxLines: 3,
                style: const TextStyle(fontSize: 12.5),
                decoration: InputDecoration(
                  hintText: 'e.g. "Shift B Sachin, Shantaram. Jaw Crusher 1 motor lug fixed and torqued. Next: Old cooling tower yellow boundary painting done."',
                  hintStyle: TextStyle(fontSize: 11.5, color: isDark ? Colors.white30 : const Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
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
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isAiExtracting ? null : _runAiExtraction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  child: _isAiExtracting
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                            SizedBox(width: 10),
                            Text('AI is parsing equipment & tasks...', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                          ],
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.auto_awesome, size: 17, color: Colors.amberAccent),
                            SizedBox(width: 8),
                            Text('✨ AI Extract & Auto-Fill All', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- 3. TIMING & SHIFT SECTION ---
  Widget _buildTimingSection(bool isDark) {
    final dateStr = '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}';

    return GlassContainer(
      borderRadius: 16,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
                    border: Border.all(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Work Date', style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : const Color(0xFF64748B))),
                          Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
                  border: Border.all(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<WorkShift>(
                    value: _selectedShift,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: WorkShift.as, child: Text('A-Shift (07:00–15:00)', style: TextStyle(fontSize: 11))),
                      DropdownMenuItem(value: WorkShift.bs, child: Text('B-Shift (15:00–23:00)', style: TextStyle(fontSize: 11))),
                      DropdownMenuItem(value: WorkShift.cs, child: Text('C-Shift (23:00–07:00)', style: TextStyle(fontSize: 11))),
                      DropdownMenuItem(value: WorkShift.gs, child: Text('General Shift (GS)', style: TextStyle(fontSize: 11))),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedShift = val);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 4. TEAM SELECTION SECTION ---
  Widget _buildTeamSelectionSection(bool isDark) {
    return GlassContainer(
      borderRadius: 16,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A. Registered App Engineers Trigger
            _buildPersonnelTrigger(
              title: 'Attending Engineers (Registered Users)',
              subtitle: 'Select engineers attending this shift...',
              icon: Icons.engineering_rounded,
              accentColor: const Color(0xFF2563EB),
              selectedCount: _selectedEngineerUserIds.length,
              onTap: _openEngineerSelectionModal,
              isDark: isDark,
            ),
            if (_selectedEngineerNames.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _selectedEngineerNames.map((name) {
                  return Chip(
                    avatar: const Icon(Icons.person, size: 14, color: Color(0xFF2563EB)),
                    label: Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () {
                      setState(() {
                        final idx = _selectedEngineerNames.indexOf(name);
                        if (idx != -1) {
                          _selectedEngineerNames.removeAt(idx);
                          if (idx < _selectedEngineerUserIds.length) {
                            _selectedEngineerUserIds.removeAt(idx);
                          }
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // B. Workmen / Contractors Trigger (NO ADD OPTION - Admin database only)
            _buildPersonnelTrigger(
              title: 'Workmen / Technicians / Contractors',
              subtitle: 'Select registered workmen from database...',
              icon: Icons.handyman_rounded,
              accentColor: Colors.orange,
              selectedCount: _selectedWorkmenIds.length,
              onTap: _openWorkmanSelectionModal,
              isDark: isDark,
            ),
            if (_selectedWorkmenNames.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _selectedWorkmenNames.map((wName) {
                  return Chip(
                    avatar: const Icon(Icons.build_circle_outlined, size: 14, color: Colors.orange),
                    label: Text(wName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () {
                      setState(() {
                        final idx = _selectedWorkmenNames.indexOf(wName);
                        if (idx != -1) {
                          _selectedWorkmenNames.removeAt(idx);
                          if (idx < _selectedWorkmenIds.length) {
                            _selectedWorkmenIds.removeAt(idx);
                          }
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPersonnelTrigger({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required int selectedCount,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final hasItems = selectedCount > 0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: hasItems
              ? accentColor.withValues(alpha: isDark ? 0.12 : 0.06)
              : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasItems
                ? accentColor.withValues(alpha: 0.5)
                : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: hasItems ? accentColor : Colors.grey),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: hasItems ? accentColor : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white38 : Colors.grey),
                  ),
                ],
              ),
            ),
            if (hasItems)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$selectedCount selected',
                  style: TextStyle(fontSize: 10, color: accentColor, fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, color: hasItems ? accentColor : Colors.grey),
          ],
        ),
      ),
    );
  }

  // --- 5. MULTI-EQUIPMENT WORK CARD ---
  Widget _buildEquipmentWorkCard(int index, bool isDark) {
    final block = _equipmentBlocks[index];
    final taskInputCtrl = TextEditingController();

    final hasMasterEquip = block.masterEquipmentId != null && block.masterEquipmentId!.isNotEmpty;
    final subAssets = hasMasterEquip ? (_blockSubAssets[block.masterEquipmentId!] ?? []) : <AssetModel>[];
    final isSubAssetsLoading = hasMasterEquip && _loadingSubAssetsForEquip.contains(block.masterEquipmentId!);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: block.isCompleted
              ? (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0))
              : Colors.amber.withValues(alpha: 0.4),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Block Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF2563EB)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    block.equipmentName.isNotEmpty
                        ? block.equipmentName
                        : (block.location?.isNotEmpty == true
                            ? block.location!
                            : (block.feederName?.isNotEmpty == true
                                ? block.feederName!
                                : 'Target Asset / Area')),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_equipmentBlocks.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                    onPressed: () {
                      setState(() => _equipmentBlocks.removeAt(index));
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // 1. Target Equipment Picker (Optional)
            _buildPickerTile(
              label: '1. Target Equipment (Optional)',
              value: block.equipmentName.isNotEmpty ? block.equipmentName : null,
              hint: 'Search Equipment (e.g. Jaw Crusher 1)...',
              icon: Icons.precision_manufacturing_rounded,
              accentColor: Colors.teal,
              isRequired: false,
              onTap: () => _pickEquipment(index),
              onClear: block.equipmentName.isNotEmpty
                  ? () {
                      setState(() {
                        _equipmentBlocks[index] = block.copyWith(
                          equipmentName: '',
                          masterEquipmentId: null,
                          assetId: null,
                          assetName: null,
                          location: null,
                          locationId: null,
                          feederName: null,
                          feederId: null,
                        );
                      });
                    }
                  : null,
              isDark: isDark,
            ),
            const SizedBox(height: 8),

            // 2. Component / Sub-Asset Picker (Optional)
            if (isSubAssetsLoading)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('Loading sub-assets / components...', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              )
            else
              _buildPickerTile(
                label: '2. Component / Sub-Asset (Optional)',
                value: block.assetName?.isNotEmpty == true ? block.assetName : null,
                hint: hasMasterEquip
                    ? (subAssets.isEmpty ? 'No sub-assets registered' : 'Select Sub-Asset / Component (Optional)...')
                    : 'Select equipment first to view sub-assets',
                icon: Icons.hub_outlined,
                accentColor: const Color(0xFF6366F1),
                isRequired: false,
                onTap: hasMasterEquip && subAssets.isNotEmpty ? () => _pickSubAsset(index) : () {},
                onClear: block.assetName?.isNotEmpty == true
                    ? () {
                        setState(() {
                          _equipmentBlocks[index] = block.copyWith(
                            assetId: null,
                            assetName: null,
                          );
                        });
                      }
                    : null,
                isDark: isDark,
              ),
            const SizedBox(height: 8),

            // 3. Location & Feeder (Auto-filled or selectable, with clean clear buttons)
            Row(
              children: [
                Expanded(
                  child: _buildPickerTile(
                    label: 'Location',
                    value: block.location?.isNotEmpty == true ? block.location : null,
                    hint: 'Select location',
                    icon: Icons.place_outlined,
                    accentColor: Colors.teal,
                    isRequired: false,
                    isAutoFilled: block.masterEquipmentId != null && block.location != null,
                    onTap: () => _pickLocation(index),
                    onClear: block.location?.isNotEmpty == true
                        ? () {
                            setState(() {
                              _equipmentBlocks[index] = block.copyWith(
                                location: null,
                                locationId: null,
                                // Also unlink equipment and sub-asset since location is removed
                                equipmentName: '',
                                masterEquipmentId: null,
                                assetId: null,
                                assetName: null,
                                feederName: null,
                                feederId: null,
                              );
                            });
                          }
                        : null,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPickerTile(
                    label: 'Feeder',
                    value: block.feederName?.isNotEmpty == true ? block.feederName : null,
                    hint: 'Select feeder',
                    icon: Icons.electrical_services_outlined,
                    accentColor: Colors.orange,
                    isRequired: false,
                    isAutoFilled: block.masterEquipmentId != null && block.feederName != null,
                    onTap: () => _pickFeeder(index),
                    onClear: block.feederName?.isNotEmpty == true
                        ? () {
                            setState(() {
                              _equipmentBlocks[index] = block.copyWith(
                                feederName: null,
                                feederId: null,
                                // Also unlink equipment and sub-asset since feeder is removed
                                equipmentName: '',
                                masterEquipmentId: null,
                                assetId: null,
                                assetName: null,
                              );
                            });
                          }
                        : null,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 4. Category & Status
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _categories.contains(block.category) ? block.category : _categories.first,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 11)))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _equipmentBlocks[index] = block.copyWith(category: val));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(block.isCompleted ? 'Completed' : 'Pending'),
                  selected: block.isCompleted,
                  selectedColor: Colors.green.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: block.isCompleted ? Colors.greenAccent : Colors.amber,
                  ),
                  onSelected: (val) {
                    setState(() {
                      _equipmentBlocks[index] = block.copyWith(status: val ? 'completed' : 'pending');
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 5. Tasks performed on this equipment
            const Text(
              'Tasks / Jobs performed on this equipment:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 6),

            ...List.generate(block.tasks.length, (tIdx) {
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Text('${tIdx + 1}. ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF2563EB))),
                    Expanded(child: Text(block.tasks[tIdx], style: const TextStyle(fontSize: 11.5))),
                    IconButton(
                      icon: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() {
                          final newTasks = List<String>.from(block.tasks)..removeAt(tIdx);
                          _equipmentBlocks[index] = block.copyWith(tasks: newTasks);
                        });
                      },
                    ),
                  ],
                ),
              );
            }),

            // Add Task input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: taskInputCtrl,
                    decoration: InputDecoration(
                      hintText: '+ Add task on ${block.equipmentName.isNotEmpty ? block.equipmentName : (block.location?.isNotEmpty == true ? block.location! : "this asset")}...',
                      hintStyle: const TextStyle(fontSize: 11),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    style: const TextStyle(fontSize: 11),
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) {
                        setState(() {
                          final newTasks = List<String>.from(block.tasks)..add(val.trim());
                          _equipmentBlocks[index] = block.copyWith(tasks: newTasks);
                        });
                        taskInputCtrl.clear();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  icon: const Icon(Icons.add, size: 16),
                  onPressed: () {
                    final val = taskInputCtrl.text.trim();
                    if (val.isNotEmpty) {
                      setState(() {
                        final newTasks = List<String>.from(block.tasks)..add(val);
                        _equipmentBlocks[index] = block.copyWith(tasks: newTasks);
                      });
                      taskInputCtrl.clear();
                    }
                  },
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Handover / Pending note
            TextFormField(
              initialValue: block.pendingFollowUp ?? '',
              decoration: InputDecoration(
                labelText: 'Handover / Pending job on this equipment (Optional)',
                hintText: 'e.g. Welder needed tomorrow for front frame, motor trial pending',
                prefixIcon: const Icon(Icons.assignment_late_outlined, size: 16, color: Colors.amber),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              style: const TextStyle(fontSize: 11),
              onChanged: (val) {
                _equipmentBlocks[index] = block.copyWith(
                  pendingFollowUp: val.trim().isNotEmpty ? val.trim() : null,
                  status: val.trim().isNotEmpty ? 'pending' : block.status,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable picker tile with overflow prevention and clean clear button.
Widget _buildPickerTile({
  required String label,
  String? value,
  required String hint,
  required IconData icon,
  required Color accentColor,
  bool isRequired = false,
  bool isAutoFilled = false,
  VoidCallback? onClear,
  required VoidCallback onTap,
  required bool isDark,
}) {
  final hasValue = value != null && value.trim().isNotEmpty;
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: hasValue
            ? accentColor.withValues(alpha: isDark ? 0.1 : 0.06)
            : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasValue
              ? accentColor.withValues(alpha: 0.4)
              : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: hasValue ? accentColor : Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          color: hasValue ? accentColor : (isDark ? Colors.white38 : Colors.grey),
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (isAutoFilled) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Auto',
                          style: TextStyle(fontSize: 8.5, color: accentColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  hasValue ? value : hint,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: hasValue ? FontWeight.w600 : FontWeight.normal,
                    color: hasValue ? null : Colors.grey,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          if (hasValue && onClear != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClear,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 13, color: Colors.grey),
              ),
            )
          else
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: hasValue ? accentColor : Colors.grey,
            ),
        ],
      ),
    ),
  );
}
