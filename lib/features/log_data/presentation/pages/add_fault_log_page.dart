import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../home/presentation/widgets/custom_app_bar.dart';
import '../../../assets/data/models/fault_log_model.dart';
import '../../../assets/data/models/master_equipment_model.dart';
import '../../../../core/constants/app_roles.dart';

class AddFaultLogPage extends StatefulWidget {
  final String? masterEquipmentId;
  final String? masterEquipmentName;
  final String? assetId; // Optional asset context

  const AddFaultLogPage({
    super.key,
    this.masterEquipmentId,
    this.masterEquipmentName,
    this.assetId,
  });

  @override
  State<AddFaultLogPage> createState() => _AddFaultLogPageState();
}

class _AddFaultLogPageState extends State<AddFaultLogPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  FaultCategory _selectedCategory = FaultCategory.electrical;
  FaultStatus _selectedStatus = FaultStatus.open;
  WorkShift _selectedShift = WorkShift.as;

  final _causeController = TextEditingController();
  final _odcController = TextEditingController();
  final _actionController = TextEditingController();
  final _rectifiedByController = TextEditingController();
  final _downtimeController = TextEditingController();

  // Advanced State
  String? _selectedEquipmentId;
  List<MasterEquipmentModel> _allEquipments = [];
  
  List<Map<String, dynamic>> _availableUsers = [];
  List<String> _assignedEngineersNames = [];
  List<String> _assignedTechniciansNames = [];

  bool _isOdcApplicable = false;
  bool _isOdcClosed = false;

  @override
  void initState() {
    super.initState();
    _selectedEquipmentId = (widget.masterEquipmentId != null && widget.masterEquipmentId!.isNotEmpty) ? widget.masterEquipmentId : null;
    
    if (_selectedEquipmentId == null) {
      _fetchEquipments();
    }
  }

  @override
  void dispose() {
    _causeController.dispose();
    _odcController.dispose();
    _actionController.dispose();
    _rectifiedByController.dispose();
    _downtimeController.dispose();
    super.dispose();
  }

  Future<void> _fetchEquipments() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final profile = await FirestoreService().getUserProfile(user.uid);
      final String? businessId = profile?['businessId'];
      final String? plantId = profile?['plantId'];
      final String? unitId = profile?['unitId'];
      final String role = profile?['role'] ?? AppRoles.guest;
      
      final bool isAdmin = profile?['isAdmin'] == true;
      Query query = FirebaseFirestore.instance.collection('master_equipments');
      if (role == AppRoles.developer || (isAdmin && plantId == null)) {
        // Show all
      } else if ((isAdmin || role == AppRoles.plantAdmin) && plantId != null) {
        query = query.where('plantId', isEqualTo: plantId);
      } else if (role == AppRoles.unitAdmin && plantId != null && unitId != null) {
        query = query.where('plantId', isEqualTo: plantId).where('unitId', isEqualTo: unitId);
      } else if (role == AppRoles.businessAdmin && businessId != null) {
        query = query.where('businessId', isEqualTo: businessId);
      } else if (plantId != null && unitId != null) {
        query = query.where('plantId', isEqualTo: plantId).where('unitId', isEqualTo: unitId);
      }

      final snapshot = await query.get();
      if (mounted) {
        setState(() {
          _allEquipments = snapshot.docs.map((doc) => MasterEquipmentModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
        });
      }
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

  Future<void> _showUserSelection({required bool isEngineer}) async {
    if (_availableUsers.isEmpty) await _fetchUsers();
    
    List<String> tempSelected = List.from(isEngineer ? _assignedEngineersNames : _assignedTechniciansNames);

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Select ${isEngineer ? 'Engineers' : 'Technicians'}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              backgroundColor: Theme.of(context).colorScheme.surface,
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _availableUsers.length,
                  itemBuilder: (context, index) {
                    final u = _availableUsers[index];
                    final name = u['name'] ?? u['email'];
                    final isChecked = tempSelected.contains(name);
                    return CheckboxListTile(
                      title: Text(name, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                      subtitle: Text(u['role'] ?? '', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                      value: isChecked,
                      checkColor: Theme.of(context).colorScheme.onPrimary,
                      activeColor: Theme.of(context).colorScheme.primary,
                      onChanged: (val) {
                        setDialogState(() {
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
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Save Selection')),
              ],
            );
          }
        );
      }
    );
    
    setState(() {
      if (isEngineer) {
        _assignedEngineersNames = tempSelected;
      } else {
        _assignedTechniciansNames = tempSelected;
      }
    });
  }

  Future<void> _save() async {
    if (_selectedEquipmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an Equipment piece.')));
      return;
    }
    if ((_selectedStatus == FaultStatus.resolved || _selectedStatus == FaultStatus.closed) && _isOdcApplicable && !_isOdcClosed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot resolve fault while ODC is still unresolved!')));
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      final logId = DateTime.now().millisecondsSinceEpoch.toString();

      final log = FaultLogModel(
        id: logId,
        masterEquipmentId: _selectedEquipmentId!,
        assetId: widget.assetId,
        reportedByUserId: userId,
        reportedAt: DateTime.now(),
        category: _selectedCategory,
        cause: _causeController.text.trim(),
        odc: _isOdcApplicable ? _odcController.text.trim() : '',
        actionTaken: _actionController.text.trim(),
        status: _selectedStatus,
        shift: _selectedShift,
        assignedEngineers: _assignedEngineersNames,
        assignedTechnicians: _assignedTechniciansNames,
        isOdcApplicable: _isOdcApplicable,
        isOdcClosed: _isOdcClosed,
        downtimeMinutes: int.tryParse(_downtimeController.text.trim()),
        rectifiedBy: _rectifiedByController.text.trim().isEmpty ? null : _rectifiedByController.text.trim(),
      );

      await FirestoreService().saveFaultLog(log);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fault Log Saved!'), backgroundColor: Colors.green),
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
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: CustomAppBar(title: (widget.masterEquipmentId == null || widget.masterEquipmentId!.isEmpty) ? 'New Fault Log' : 'Log Fault'),
      body: AnimatedGradientBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Info or Selection
                if (widget.masterEquipmentId != null && widget.masterEquipmentId!.isNotEmpty)
                  GlassContainer(
                    width: double.infinity,
                    height: null,
                    borderRadius: 12,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.precision_manufacturing, color: Theme.of(context).colorScheme.primary, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Equipment', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                                Text(widget.masterEquipmentName ?? '', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
                                Text('ID: ${widget.masterEquipmentId}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  _buildDropdown<MasterEquipmentModel?>(
                    label: 'Target Equipment',
                    value: _allEquipments.where((e) => e.id == _selectedEquipmentId).firstOrNull,
                    items: _allEquipments,
                    onChanged: (v) => setState(() {
                      _selectedEquipmentId = v?.id;
                    }),
                    itemLabel: (v) => v != null ? '${v.name} (${v.id})' : 'Select Equipment',
                  ),
                const SizedBox(height: 16),

                // Shift & Category Row
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildDropdown<WorkShift>(
                        label: 'Shift',
                        value: _selectedShift,
                        items: WorkShift.values,
                        onChanged: (v) => setState(() => _selectedShift = v!),
                        itemLabel: (v) => v.name.toUpperCase(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: _buildDropdown<FaultCategory>(
                        label: 'Fault Category',
                        value: _selectedCategory,
                        items: FaultCategory.values,
                        onChanged: (v) => setState(() => _selectedCategory = v!),
                        itemLabel: (v) => v.name.toUpperCase().replaceAll('_', ' '),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Assigned Personnel Selection
                Row(
                  children: [
                    Expanded(
                      child: _buildPersonnelSelector(
                        title: 'Engineers',
                        count: _assignedEngineersNames.length,
                        onTap: () => _showUserSelection(isEngineer: true),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildPersonnelSelector(
                        title: 'Technicians',
                        count: _assignedTechniciansNames.length,
                        onTap: () => _showUserSelection(isEngineer: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Cause
                _buildGlassField(
                  controller: _causeController,
                  label: 'Cause of Failure',
                  icon: Icons.warning_amber_rounded,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Action Taken
                _buildGlassField(
                  controller: _actionController,
                  label: 'Action Taken (Rectification)',
                  icon: Icons.build,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                // ODC Tracker
                GlassContainer(
                   width: double.infinity,
                   height: null,
                   borderRadius: 12,
                   child: Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                     child: Column(
                       children: [
                         SwitchListTile(
                           title: const Text('Is ODC Applicable?'),
                           subtitle: Text('Observation / Defect / Condition', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                           value: _isOdcApplicable,
                           onChanged: (v) => setState(() {
                             _isOdcApplicable = v;
                             if (!v) _isOdcClosed = false;
                           }),
                           activeThumbColor: Theme.of(context).colorScheme.primary,
                           contentPadding: EdgeInsets.zero,
                         ),
                         if (_isOdcApplicable) ...[
                            _buildGlassField(
                              controller: _odcController,
                              label: 'ODC Description',
                              icon: Icons.visibility,
                              maxLines: 2,
                              validator: (v) => (v == null || v.isEmpty) && _isOdcApplicable ? 'ODC Description Required' : null,
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              title: const Text('Is ODC Closed/Resolved?'),
                              value: _isOdcClosed,
                              onChanged: (v) => setState(() => _isOdcClosed = v),
                              activeThumbColor: Colors.green,
                              contentPadding: EdgeInsets.zero,
                            ),
                         ],
                       ],
                     ),
                   ),
                ),
                const SizedBox(height: 16),

                // Status
                _buildDropdown<FaultStatus>(
                  label: 'Resolution Status',
                  value: _selectedStatus,
                  items: FaultStatus.values,
                  onChanged: (v) => setState(() => _selectedStatus = v!),
                  itemLabel: (v) => v.name.toUpperCase().replaceAll('_', ' '),
                ),
                const SizedBox(height: 16),

                // Downtime
                _buildGlassField(
                  controller: _downtimeController,
                  label: 'Downtime (in minutes)',
                  icon: Icons.timer,
                  isNumber: true,
                ),
                const SizedBox(height: 16),

                // Rectified By
                _buildGlassField(
                  controller: _rectifiedByController,
                  label: 'Rectified By (External / Contractor)',
                  icon: Icons.engineering,
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
                      ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Theme.of(context).colorScheme.onPrimary, strokeWidth: 2))
                      : Text('Submit Fault Log', style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onPrimary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPersonnelSelector({required String title, required int count, required VoidCallback onTap}) {
     return InkWell(
       onTap: onTap,
       borderRadius: BorderRadius.circular(12),
       child: GlassContainer(
         width: double.infinity,
         height: 65,
         borderRadius: 12,
         child: Padding(
           padding: const EdgeInsets.symmetric(horizontal: 16),
           child: Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(title, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                   const SizedBox(height: 2),
                   Text(count == 0 ? 'Select...' : '$count Selected', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                 ],
               ),
               Icon(Icons.arrow_drop_down, color: Theme.of(context).colorScheme.primary),
             ],
           ),
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
    return GlassContainer(
      width: double.infinity,
      height: null,
      borderRadius: 12,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: isNumber ? TextInputType.number : TextInputType.multiline,
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

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required void Function(T?) onChanged,
    required String Function(T) itemLabel,
  }) {
    return GlassContainer(
      width: double.infinity,
      height: null,
      borderRadius: 12,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          items: items.map((e) => DropdownMenuItem<T>(value: e, child: Text(itemLabel(e)))).toList(),
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
        ),
      ),
    );
  }
}
