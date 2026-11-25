import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../../core/widgets/pulse_loading.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/hierarchy_service.dart';
import '../../../home/presentation/widgets/custom_app_bar.dart';
import 'package:asset_pulse_pro/features/assets/data/models/panel_model.dart';
import 'package:asset_pulse_pro/features/assets/data/models/feeder_model.dart';
import 'package:asset_pulse_pro/features/assets/data/models/isolation_permit_model.dart';

class AddIsolationPermitPage extends StatefulWidget {
  final IsolationPermitModel? renewFrom;
  final String? plantId;
  final String? unitId;

  const AddIsolationPermitPage({
    super.key,
    this.renewFrom,
    this.plantId,
    this.unitId,
  });

  @override
  State<AddIsolationPermitPage> createState() => _AddIsolationPermitPageState();
}

class _AddIsolationPermitPageState extends State<AddIsolationPermitPage> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();
  final _hierarchyService = HierarchyService();

  // Step state
  int _currentStep = 0;
  bool _isLoading = false;

  // Controllers
  final _permitNoController = TextEditingController();
  final _reasonController = TextEditingController();
  final _requesterLockNoController = TextEditingController();
  final _isolationOfficerLockNoController = TextEditingController();
  final _personalLocksCountController = TextEditingController(text: '0');

  // Scope state
  String? _selectedPlantId;
  String? _selectedUnitId;
  List<String> _plants = [];
  List<String> _units = [];

  // Multi-step form values
  String? _selectedLocationId;
  String? _selectedPanelId;
  String? _selectedFeederId;

  String? _selectedDept;
  String? _requestingOfficerId;
  String? _isolationOfficerId;
  DateTime _selectedDateTime = DateTime.now();

  // Dropdown lists
  List<PanelModel> _panels = [];
  List<FeederModel> _feeders = [];
  List<Map<String, dynamic>> _reqOfficers = [];
  List<Map<String, dynamic>> _isoOfficers = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    if (widget.renewFrom != null) {
      _prepopulateForRenewal();
    }
  }

  void _prepopulateForRenewal() {
    final p = widget.renewFrom!;
    _permitNoController.text = p.permitNo;
    _reasonController.text = p.reason;
    _selectedDept = p.requestingDepartment;
    _selectedPlantId = p.plantId;
    _selectedUnitId = p.unitId;
    _selectedLocationId = p.locationId;
    _selectedPanelId = p.panelId;
    _selectedFeederId = p.feederId;
    _loadHierarchyDetails();
  }

  Future<void> _loadHierarchyDetails() async {
    if (_selectedPlantId != null && _selectedUnitId != null) {
      await _loadPanels();
      if (_selectedPanelId != null) {
        await _loadFeedersForPanel(_selectedPanelId!);
      }
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final authUser = _firestoreService.currentUser;
      _plants = _hierarchyService.getPlants();

      if (authUser != null) {
        final user = await _firestoreService.getUserProfile(authUser.uid);
        if (user != null) {
          final userPlant = user['plantId'] as String?;
          final userUnit = user['unitId'] as String?;
          final businessId = user['businessId'] as String? ?? 'VISL';

          await _hierarchyService.init(businessId: businessId);
          _plants = _hierarchyService.getPlants();

          // Inherit scope from parent widget if provided, otherwise fallback to user profile
          if (widget.plantId != null && widget.plantId!.isNotEmpty) {
            _selectedPlantId = widget.plantId;
          } else if (userPlant != null && userPlant.isNotEmpty && userPlant != 'Unknown') {
            _selectedPlantId = userPlant;
          }

          if (widget.unitId != null && widget.unitId!.isNotEmpty) {
            _selectedUnitId = widget.unitId;
          } else if (userUnit != null && userUnit.isNotEmpty && userUnit != 'Unknown') {
            _selectedUnitId = userUnit;
          }

          _selectedDept = user['department'];
        }
      }

      _selectedPlantId ??= widget.plantId ?? (_plants.isNotEmpty ? _plants.first : null);
      if (_selectedPlantId != null) {
        _units = _hierarchyService.getUnitsForPlant(_selectedPlantId!);
        if (_selectedUnitId == null || !_units.contains(_selectedUnitId)) {
          _selectedUnitId = widget.unitId ?? (_units.isNotEmpty ? _units.first : null);
        }
      }

      await _loadPanels();
      await _fetchAuthorizedPersonnel();
    } catch (e) {
      debugPrint('Error loading initial data in AddIsolationPermit: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPanels() async {
    if (_selectedPlantId == null || _selectedUnitId == null) {
      setState(() {
        _panels = [];
        _selectedPanelId = null;
        _feeders = [];
        _selectedFeederId = null;
      });
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('panels')
          .where('plantId', isEqualTo: _selectedPlantId)
          .where('unitId', isEqualTo: _selectedUnitId)
          .get();

      final pList = snap.docs.map((d) => PanelModel.fromMap(d.data(), d.id)).toList();

      setState(() {
        _panels = pList;
        if (!_panels.any((p) => p.id == _selectedPanelId)) {
          _selectedPanelId = null;
          _feeders = [];
          _selectedFeederId = null;
        }
      });
    } catch (e) {
      debugPrint('Error loading panels: $e');
    }
  }

  Future<void> _loadFeedersForPanel(String panelId) async {
    try {
      final rawId = HierarchyService.stripPrefix(panelId, _selectedPlantId ?? '', _selectedUnitId ?? '');
      final fullId = HierarchyService.prefixId(panelId, _selectedPlantId ?? '', _selectedUnitId ?? '');
      final possibleKeys = {panelId, rawId, fullId}.where((e) => e.isNotEmpty).toList();

      final snap = await FirebaseFirestore.instance
          .collection('feeders')
          .where('panelId', whereIn: possibleKeys)
          .get();

      final fList = snap.docs.map((d) => FeederModel.fromMap(d.data(), d.id)).toList();

      setState(() {
        _feeders = fList;
        if (!_feeders.any((f) => f.id == _selectedFeederId)) {
          _selectedFeederId = null;
        }
      });
    } catch (e) {
      debugPrint('Error loading feeders: $e');
    }
  }


  Future<void> _fetchAuthorizedPersonnel() async {
    final businessId = _hierarchyService.currentBusinessId;
    
    // Requesting Officers (same department or higher authority, or isRequestingAuth)
    final req = await _firestoreService.getLotoAuthorizedUsers(
      businessId: businessId,
      plantId: _selectedPlantId,
      unitId: _selectedUnitId,
      isRequestingAuth: true,
      isIsolationAuth: false,
      department: _selectedDept,
    );

    // Isolation Officers (Electrical dept in scope, or higher authority, or isIsolationAuth)
    final iso = await _firestoreService.getLotoAuthorizedUsers(
      businessId: businessId,
      plantId: _selectedPlantId,
      unitId: _selectedUnitId,
      isRequestingAuth: false,
      isIsolationAuth: true,
    );

    if (mounted) {
      setState(() {
        _reqOfficers = req;
        _isoOfficers = iso;
        if (_requestingOfficerId != null && !_reqOfficers.any((u) => u['uid'] == _requestingOfficerId)) {
          _requestingOfficerId = null;
        }
        if (_isolationOfficerId != null && !_isoOfficers.any((u) => u['uid'] == _isolationOfficerId)) {
          _isolationOfficerId = null;
        }
      });
    }
  }

  Future<void> _savePermit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final authUser = _firestoreService.currentUser;
      if (authUser == null) throw 'Not logged in';

      final user = await _firestoreService.getUserProfile(authUser.uid);
      final businessId = user?['businessId'] ?? _hierarchyService.currentBusinessId;
      final plantId = _selectedPlantId ?? user?['plantId'] ?? '';
      final unitId = _selectedUnitId ?? user?['unitId'] ?? '';

      String panelDisplayName = _selectedPanelId!;
      final matchingPanel = _panels.where((p) => p.id == _selectedPanelId).firstOrNull;
      if (matchingPanel != null) {
        final raw = HierarchyService.stripPrefix(matchingPanel.id, plantId, unitId);
        panelDisplayName = matchingPanel.name.isNotEmpty && matchingPanel.name != raw 
            ? '$raw (${matchingPanel.name})' 
            : raw;
      }

      String feederDisplayName = _selectedFeederId!;
      final matchingFeeder = _feeders.where((f) => f.id == _selectedFeederId).firstOrNull;
      if (matchingFeeder != null) {
        final raw = HierarchyService.stripPrefix(matchingFeeder.id, plantId, unitId);
        feederDisplayName = matchingFeeder.name.isNotEmpty && matchingFeeder.name != raw 
            ? '$raw (${matchingFeeder.name})' 
            : raw;
      }

      final reqUser = _reqOfficers.where((u) => u['uid'] == _requestingOfficerId).firstOrNull;
      final reqName = (reqUser?['displayName'] ?? reqUser?['name'] ?? '').toString();

      final isoUser = _isoOfficers.where((u) => u['uid'] == _isolationOfficerId).firstOrNull;
      final isoName = (isoUser?['displayName'] ?? isoUser?['name'] ?? '').toString();

      final permit = IsolationPermitModel(
        id: '', // Firestore will generate
        permitNo: _permitNoController.text,
        businessId: businessId,
        plantId: plantId,
        unitId: unitId,
        locationId: _selectedLocationId ?? unitId,
        panelId: _selectedPanelId!,
        feederId: _selectedFeederId!,
        panelName: panelDisplayName,
        feederName: feederDisplayName,
        requestingDepartment: _selectedDept!,
        reason: _reasonController.text,
        isolationDateTime: _selectedDateTime,
        requestingOfficerId: _requestingOfficerId!,
        isolationOfficerId: _isolationOfficerId!,
        requestingOfficerName: reqName.isNotEmpty ? reqName : null,
        isolationOfficerName: isoName.isNotEmpty ? isoName : null,
        requesterLockNo: _requesterLockNoController.text,
        isolationOfficerLockNo: _isolationOfficerLockNoController.text,
        personalLocksCount: int.tryParse(_personalLocksCountController.text) ?? 0,
        status: IsolationStatus.active,
        renewalHistory: widget.renewFrom != null 
          ? [...widget.renewFrom!.renewalHistory, {'renewedFrom': widget.renewFrom!.id, 'timestamp': DateTime.now().toIso8601String()}]
          : [],
      );

      await _firestoreService.saveIsolationPermit(permit);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Isolation Permit Issued Successfully'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: widget.renewFrom != null ? 'Renew Isolation Permit' : 'Issue Isolation Permit'),
      body: AnimatedGradientBackground(
        child: _isLoading 
          ? const Center(child: PulseLoading(size: 50))
          : Form(
              key: _formKey,
              child: Stepper(
                type: StepperType.vertical,
                currentStep: _currentStep,
                onStepContinue: () {
                  if (_currentStep < 2) {
                    setState(() => _currentStep += 1);
                  } else {
                    _savePermit();
                  }
                },
                onStepCancel: () {
                  if (_currentStep > 0) {
                    setState(() => _currentStep -= 1);
                  }
                },
                steps: [
                  Step(
                    title: const Text('Target Equipment'),
                    isActive: _currentStep >= 0,
                    content: _buildHierarchyStep(),
                  ),
                  Step(
                    title: const Text('Permit Details'),
                    isActive: _currentStep >= 1,
                    content: _buildDetailStep(),
                  ),
                  Step(
                    title: const Text('Personnel & Locking'),
                    isActive: _currentStep >= 2,
                    content: _buildPersonnelStep(),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildHierarchyStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Inherited Scope Indicator Banner (selected from dashboard)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.hub_outlined, color: Theme.of(context).colorScheme.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Target Equipment Scope',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_selectedPlantId ?? "Plant"} • ${_selectedUnitId ?? "Unit"}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                ),
                child: const Text('FROM DASHBOARD', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Panel Dropdown
        DropdownButtonFormField<String>(
          key: ValueKey('panel_${_selectedUnitId}_$_selectedPanelId'),
          initialValue: _selectedPanelId,
          decoration: const InputDecoration(
            labelText: 'Panel (MCC / PCC / LDB)',
            prefixIcon: Icon(Icons.developer_board_outlined),
            helperText: 'Select the electrical switchboard',
          ),
          isExpanded: true,
          items: _panels.map((p) {
            final raw = HierarchyService.stripPrefix(p.id, _selectedPlantId ?? '', _selectedUnitId ?? '');
            final display = p.name.isNotEmpty && p.name != raw ? '$raw (${p.name})' : raw;
            return DropdownMenuItem(
              value: p.id,
              child: Text('$display • ${p.type}', overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              _selectedPanelId = val;
              if (val != null) {
                final p = _panels.firstWhere((item) => item.id == val, orElse: () => _panels.first);
                _selectedLocationId = p.panelRoomId.isNotEmpty ? p.panelRoomId : _selectedUnitId;
              }
            });
            if (val != null) {
              _loadFeedersForPanel(val);
            }
          },
          validator: (v) => v == null ? 'Panel is mandatory for isolation' : null,
        ),
        const SizedBox(height: 16),

        // Feeder Dropdown
        DropdownButtonFormField<String>(
          key: ValueKey('feeder_${_selectedPanelId}_$_selectedFeederId'),
          initialValue: _selectedFeederId,
          decoration: InputDecoration(
            labelText: 'Feeder / Circuit Breaker',
            prefixIcon: const Icon(Icons.electric_bolt_outlined),
            helperText: _selectedPanelId == null
                ? 'Select a panel first to load feeders'
                : (_feeders.isEmpty ? 'No feeders found under this panel' : 'Select outgoing or incoming feeder to isolate'),
          ),
          isExpanded: true,
          items: _feeders.map((f) {
            final raw = HierarchyService.stripPrefix(f.id, _selectedPlantId ?? '', _selectedUnitId ?? '');
            final display = f.name.isNotEmpty && f.name != raw ? '$raw (${f.name})' : raw;
            return DropdownMenuItem(
              value: f.id,
              child: Text('$display • ${f.type}', overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: _selectedPanelId == null ? null : (val) => setState(() => _selectedFeederId = val),
          validator: (v) => v == null ? 'Feeder mandatory for isolation' : null,
        ),
      ],
    );
  }

  Widget _buildDetailStep() {
    return Column(
      children: [
        TextFormField(
          controller: _permitNoController,
          decoration: const InputDecoration(labelText: 'Permit Number', prefixIcon: Icon(Icons.numbers)),
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _selectedDept,
          decoration: const InputDecoration(labelText: 'Requesting Department', prefixIcon: Icon(Icons.business_outlined)),
          items: ['Electrical', 'Mechanical', 'Instrumentation', 'Production', 'Utility']
              .map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
          onChanged: (val) {
            setState(() => _selectedDept = val);
            _fetchAuthorizedPersonnel();
          },
          validator: (v) => v == null ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _reasonController,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Reason for Isolation', prefixIcon: Icon(Icons.notes)),
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        ListTile(
          title: const Text('Isolation Date & Time'),
          subtitle: Text('${_selectedDateTime.day}/${_selectedDateTime.month}/${_selectedDateTime.year} at ${_selectedDateTime.hour}:${_selectedDateTime.minute.toString().padLeft(2, '0')}'),
          trailing: const Icon(Icons.calendar_month),
          onTap: () async {
            final date = await showDatePicker(context: context, initialDate: _selectedDateTime, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 365)));
            if (date != null) {
              if (!mounted) return;
              final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_selectedDateTime));
              if (time != null) {
                setState(() => _selectedDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute));
              }
            }
          },
        ),
      ],
    );
  }

  Widget _buildPersonnelStep() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('req_${_reqOfficers.length}_${_reqOfficers.any((u) => u['uid'] == _requestingOfficerId) ? _requestingOfficerId : 'none'}'),
          initialValue: _reqOfficers.any((u) => u['uid'] == _requestingOfficerId) ? _requestingOfficerId : null,
          decoration: const InputDecoration(
            labelText: 'Requesting Officer', 
            prefixIcon: Icon(Icons.person_outline),
            helperText: 'Filtered by requesting department & scope (or higher authority)',
          ),
          isExpanded: true,
          items: _reqOfficers.map((u) {
            final name = (u['displayName'] ?? 'User').toString();
            final role = (u['role'] ?? '').toString();
            final dept = (u['department'] ?? '').toString();
            final emp = (u['employeeId'] ?? '').toString();
            final detail = emp.isNotEmpty ? '$role • $dept • $emp' : '$role • $dept';
            return DropdownMenuItem<String>(
              value: u['uid'] as String,
              child: Text('$name ($detail)', overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (val) => setState(() => _requestingOfficerId = val),
          validator: (v) => v == null ? 'Selection required' : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey('iso_${_isoOfficers.length}_${_isoOfficers.any((u) => u['uid'] == _isolationOfficerId) ? _isolationOfficerId : 'none'}'),
          initialValue: _isoOfficers.any((u) => u['uid'] == _isolationOfficerId) ? _isolationOfficerId : null,
          decoration: const InputDecoration(
            labelText: 'Isolation Officer (Authorized)', 
            prefixIcon: Icon(Icons.engineering_outlined),
            helperText: 'Electrical Dept personnel in scope or authorized higher authorities',
          ),
          isExpanded: true,
          items: _isoOfficers.map((u) {
            final name = (u['displayName'] ?? 'User').toString();
            final role = (u['role'] ?? '').toString();
            final dept = (u['department'] ?? '').toString();
            final emp = (u['employeeId'] ?? '').toString();
            final detail = emp.isNotEmpty ? '$role • $dept • $emp' : '$role • $dept';
            return DropdownMenuItem<String>(
              value: u['uid'] as String,
              child: Text('$name ($detail)', overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (val) => setState(() => _isolationOfficerId = val),
          validator: (v) => v == null ? 'Selection required' : null,
        ),
        const SizedBox(height: 24),
        const Text('Locking Details', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _requesterLockNoController,
                decoration: const InputDecoration(labelText: 'Req. Lock No.', border: OutlineInputBorder()),
                validator: (v) => v == null || v.isEmpty ? 'Req' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _isolationOfficerLockNoController,
                decoration: const InputDecoration(labelText: 'Iso. Lock No.', border: OutlineInputBorder()),
                validator: (v) => v == null || v.isEmpty ? 'Req' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _personalLocksCountController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'No. of Personal Locks (Group LOTO)', prefixIcon: Icon(Icons.groups_outlined)),
        ),
      ],
    );
  }
}
