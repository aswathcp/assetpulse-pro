import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../../core/widgets/pulse_loading.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/hierarchy_service.dart';
import '../../../home/presentation/widgets/custom_app_bar.dart';
import 'package:asset_pulse_pro/features/assets/data/models/location_model.dart';
import 'package:asset_pulse_pro/features/assets/data/models/panel_model.dart';
import 'package:asset_pulse_pro/features/assets/data/models/feeder_model.dart';
import 'package:asset_pulse_pro/features/assets/data/models/isolation_permit_model.dart';

class AddIsolationPermitPage extends StatefulWidget {
  final IsolationPermitModel? renewFrom;
  const AddIsolationPermitPage({super.key, this.renewFrom});

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

  // Multi-step form values
  String? _selectedLocationId;
  String? _selectedPanelId;
  String? _selectedFeederId;

  String? _selectedDept;
  String? _requestingOfficerId;
  String? _isolationOfficerId;
  DateTime _selectedDateTime = DateTime.now();

  // Dropdown lists
  List<LocationModel> _locations = [];
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
    _selectedLocationId = p.locationId;
    _selectedPanelId = p.panelId;
    _selectedFeederId = p.feederId;
    _loadHierarchyDetails();
  }

  Future<void> _loadHierarchyDetails() async {
    // If renewing, we need to load subsequent lists if IDs exist
    if (_selectedLocationId != null) {
      final pList = await _firestoreService.getPanelsStream(_selectedLocationId!).first;
      setState(() => _panels = pList);
    }
    if (_selectedPanelId != null) {
      final fList = await _firestoreService.getFeedersStream(_selectedPanelId!).first;
      setState(() => _feeders = fList);
    }
  }

  Future<void> _loadInitialData() async {
    final authUser = _firestoreService.currentUser;
    if (authUser == null) return;

    final user = await _firestoreService.getUserProfile(authUser.uid);
    final plantId = user?['plantId'] ?? '';
    final unitId = user?['unitId'] ?? '';

    final locs = await _firestoreService.getLocationsStream(unitId, plantId).first;
    setState(() => _locations = locs);
    
    // Load default department
    _selectedDept = user?['department'];
    _fetchAuthorizedPersonnel();
  }

  Future<void> _fetchAuthorizedPersonnel() async {
    final businessId = _hierarchyService.currentBusinessId;
    
    // Requesting Officers (same department, has isRequestingAuth)
    final req = await _firestoreService.getLotoAuthorizedUsers(
      businessId: businessId,
      isRequestingAuth: true,
      isIsolationAuth: false,
      department: _selectedDept,
    );

    // Isolation Officers (any department, has isIsolationAuth)
    final iso = await _firestoreService.getLotoAuthorizedUsers(
      businessId: businessId,
      isRequestingAuth: false,
      isIsolationAuth: true,
    );

    setState(() {
      _reqOfficers = req;
      _isoOfficers = iso;
    });
  }

  Future<void> _savePermit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final authUser = _firestoreService.currentUser;
      if (authUser == null) throw 'Not logged in';

      final user = await _firestoreService.getUserProfile(authUser.uid);
      final businessId = user?['businessId'] ?? '';
      final plantId = user?['plantId'] ?? '';
      final unitId = user?['unitId'] ?? '';

      final permit = IsolationPermitModel(
        id: '', // Firestore will generate
        permitNo: _permitNoController.text,
        businessId: businessId,
        plantId: plantId,
        unitId: unitId,
        locationId: _selectedLocationId!,
        panelId: _selectedPanelId!,
        feederId: _selectedFeederId!,
        requestingDepartment: _selectedDept!,
        reason: _reasonController.text,
        isolationDateTime: _selectedDateTime,
        requestingOfficerId: _requestingOfficerId!,
        isolationOfficerId: _isolationOfficerId!,
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
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedLocationId,
          decoration: const InputDecoration(labelText: 'Location', prefixIcon: Icon(Icons.location_on_outlined)),
          items: _locations.map((l) => DropdownMenuItem(value: l.id, child: Text(l.name))).toList(),
          onChanged: (val) async {
            setState(() {
              _selectedLocationId = val;
              _selectedPanelId = null;
              _selectedFeederId = null;
              _panels = [];
              _feeders = [];
            });
            if (val != null) {
              final pList = await _firestoreService.getPanelsStream(val).first;
              setState(() => _panels = pList);
            }
          },
          validator: (v) => v == null ? 'Selection required' : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _selectedPanelId,
          decoration: const InputDecoration(labelText: 'Panel', prefixIcon: Icon(Icons.settings_input_component_outlined)),
          items: _panels.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
          onChanged: (val) async {
            setState(() {
              _selectedPanelId = val;
              _selectedFeederId = null;
              _feeders = [];
            });
            if (val != null) {
              final fList = await _firestoreService.getFeedersStream(val).first;
              setState(() => _feeders = fList);
            }
          },
          validator: (v) => v == null ? 'Selection required' : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _selectedFeederId,
          decoration: const InputDecoration(labelText: 'Feeder', prefixIcon: Icon(Icons.electric_bolt_outlined)),
          items: _feeders.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name))).toList(),
          onChanged: (val) => setState(() => _selectedFeederId = val),
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
          initialValue: _requestingOfficerId,
          decoration: const InputDecoration(labelText: 'Requesting Officer', prefixIcon: Icon(Icons.person_outline)),
          items: _reqOfficers.map((u) => DropdownMenuItem<String>(value: u['uid'] as String, child: Text('${u['displayName']} (${u['employeeId']})'))).toList(),
          onChanged: (val) => setState(() => _requestingOfficerId = val),
          validator: (v) => v == null ? 'Selection required' : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _isolationOfficerId,
          decoration: const InputDecoration(labelText: 'Isolation Officer (Authorized)', prefixIcon: Icon(Icons.engineering_outlined)),
          items: _isoOfficers.map((u) => DropdownMenuItem<String>(value: u['uid'] as String, child: Text('${u['displayName']} (${u['employeeId']})'))).toList(),
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
