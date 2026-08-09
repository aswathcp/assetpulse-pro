// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:asset_pulse_pro/core/constants/app_colors.dart';
import 'package:asset_pulse_pro/core/services/auth_service.dart';
import 'package:asset_pulse_pro/core/services/firestore_service.dart';
import 'package:asset_pulse_pro/core/services/location_verification_service.dart';
import 'package:uuid/uuid.dart';

/// Supported checklist types.
/// Add new types here as they are developed.
const List<Map<String, dynamic>> kChecklistTypes = [
  {
    'value': 'battery_room',
    'label': 'Battery Room Checklist',
    'available': true,
  },
  {
    'value': 'vfd',
    'label': 'VFD Checklist',
    'available': false, // Coming soon
  },
];

/// Default field templates per checklist type.
List<Map<String, dynamic>> _defaultFieldsForType(String type) {
  switch (type) {
    case 'battery_room':
      return [
        {'name': 'Charger Selection', 'type': 'toggle', 'options': ['Auto', 'Manual']},
        {'name': 'Charger Mode', 'type': 'toggle', 'options': ['Float', 'Boot']},
        {'name': 'DV Voltage', 'type': 'numeric'},
        {'name': 'DC Current', 'type': 'numeric'},
        {
          'name': 'H2 %LEL',
          'type': 'numeric',
          'warningMin': 10.0,
          'warningMax': 19.9,
          'criticalMin': 20.0,
          'criticalMax': 100.0,
        },
      ];
    default:
      return [];
  }
}

class ShiftChecklistConfigPage extends StatefulWidget {
  final String plantId;
  final String unitId;
  final Map<String, dynamic>? existingChecklist;

  const ShiftChecklistConfigPage({
    super.key,
    required this.plantId,
    required this.unitId,
    this.existingChecklist,
  });

  @override
  State<ShiftChecklistConfigPage> createState() =>
      _ShiftChecklistConfigPageState();
}

class _ShiftChecklistConfigPageState extends State<ShiftChecklistConfigPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _fieldNameController = TextEditingController();
  final _fieldOptionsController = TextEditingController(text: 'Auto, Manual');
  final _warningMinController = TextEditingController(text: '10.0');
  final _warningMaxController = TextEditingController(text: '19.9');
  final _criticalMinController = TextEditingController(text: '20.0');
  final _criticalMaxController = TextEditingController(text: '100.0');

  String? _selectedType;
  bool _isLocationRequired = true;
  bool _isSaving = false;
  bool _isFetchingGps = false;
  String _addFieldType = 'numeric';
  List<Map<String, dynamic>> _fields = [];

  bool get _isEditing => widget.existingChecklist != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final c = widget.existingChecklist!;
      _nameController.text = c['name'] ?? '';
      _selectedType = c['checklistTypeKey'] ?? 'battery_room';
      _isLocationRequired = c['isLocationRequired'] == true;
      _latController.text = (c['latitude'] as num?)?.toString() ?? '';
      _lngController.text = (c['longitude'] as num?)?.toString() ?? '';
      _fields = List<Map<String, dynamic>>.from(
        ((c['fields'] as List?) ?? []).map((f) => Map<String, dynamic>.from(f)),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _fieldNameController.dispose();
    _fieldOptionsController.dispose();
    _warningMinController.dispose();
    _warningMaxController.dispose();
    _criticalMinController.dispose();
    _criticalMaxController.dispose();
    super.dispose();
  }

  void _onTypeSelected(String? val) {
    if (val == null) return;
    setState(() {
      _selectedType = val;
      // Auto-populate name if empty
      final label = kChecklistTypes
          .firstWhere((t) => t['value'] == val)['label'] as String;
      if (_nameController.text.isEmpty) {
        _nameController.text = label;
      }
      // Load default fields for the selected type
      if (_fields.isEmpty) {
        _fields = _defaultFieldsForType(val);
      }
    });
  }

  Future<void> _fetchCurrentGps() async {
    setState(() => _isFetchingGps = true);
    try {
      final svc = LocationVerificationService();
      final pos = await svc.getCurrentLocation();
      if (pos != null) {
        setState(() {
          _latController.text = pos.latitude.toStringAsFixed(6);
          _lngController.text = pos.longitude.toStringAsFixed(6);
        });
      } else {
        throw 'Unable to acquire location coordinates';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('GPS error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isFetchingGps = false);
    }
  }

  void _addField() {
    if (_fieldNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a field name.')),
      );
      return;
    }
    final newField = <String, dynamic>{
      'name': _fieldNameController.text.trim(),
      'type': _addFieldType,
    };
    if (_addFieldType == 'toggle') {
      newField['options'] = _fieldOptionsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else if (_addFieldType == 'numeric') {
      final wMin = double.tryParse(_warningMinController.text);
      final wMax = double.tryParse(_warningMaxController.text);
      final cMin = double.tryParse(_criticalMinController.text);
      final cMax = double.tryParse(_criticalMaxController.text);
      if (wMin != null) newField['warningMin'] = wMin;
      if (wMax != null) newField['warningMax'] = wMax;
      if (cMin != null) newField['criticalMin'] = cMin;
      if (cMax != null) newField['criticalMax'] = cMax;
    }
    setState(() {
      _fields.add(newField);
      _fieldNameController.clear();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a checklist type.')),
      );
      return;
    }
    if (_fields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please add at least one field component.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final firestoreService = FirestoreService();
      final user = AuthService().currentUser;
      if (user == null) throw 'Not authenticated';
      final profile = await firestoreService.getUserProfile(user.uid);
      final businessId = profile?['businessId'] as String? ?? 'VISL';

      final id = widget.existingChecklist?['id'] ?? const Uuid().v4();
      final docData = <String, dynamic>{
        'id': id,
        'name': _nameController.text.trim(),
        'checklistTypeKey': _selectedType,
        'plantId': widget.plantId,
        'unitId': widget.unitId,
        'businessId': businessId,
        'isLocationRequired': _isLocationRequired,
        'latitude':
            _isLocationRequired ? (double.tryParse(_latController.text) ?? 0.0) : 0.0,
        'longitude': _isLocationRequired
            ? (double.tryParse(_lngController.text) ?? 0.0)
            : 0.0,
        'fields': _fields,
      };

      await firestore
          .collection('custom_checklists')
          .doc(id)
          .set(docData, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Checklist saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // return true = refresh needed
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error saving: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Edit Checklist Config' : 'New Shift Checklist',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ─── Scope chip ───────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.factory_outlined,
                              size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            '${widget.plantId}  •  ${widget.unitId}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ─── Step 1: Checklist Type ───────────────────────────
                    _sectionLabel('1. Checklist Type'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: InputDecoration(
                        labelText: 'Select Checklist Type',
                        prefixIcon: const Icon(Icons.category_outlined),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => v == null ? 'Required' : null,
                      items: kChecklistTypes.map((t) {
                        final available = t['available'] as bool;
                        return DropdownMenuItem<String>(
                          value: t['value'] as String,
                          enabled: available,
                          child: Row(
                            children: [
                              Text(t['label'] as String),
                              if (!available) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('Soon',
                                      style: TextStyle(
                                          fontSize: 9, color: Colors.grey)),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: _onTypeSelected,
                    ),

                    if (_selectedType != null) ...[
                      const SizedBox(height: 24),

                      // ─── Step 2: Name ─────────────────────────────────
                      _sectionLabel('2. Checklist Name'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Display Name',
                          hintText: 'e.g. BF1 Battery Room',
                          prefixIcon: const Icon(Icons.label_outline),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 24),

                      // ─── Step 3: Location Verification ───────────────
                      _sectionLabel('3. Location Verification'),
                      const SizedBox(height: 8),
                      Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 4),
                          child: SwitchListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            title: const Text(
                                'Require GPS Geofence Verification',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                            subtitle: const Text(
                              'Verifies operator is physically present at the equipment.',
                              style: TextStyle(fontSize: 11),
                            ),
                            value: _isLocationRequired,
                            onChanged: (val) =>
                                setState(() => _isLocationRequired = val),
                          ),
                        ),
                      ),
                      if (_isLocationRequired) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _latController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'Latitude',
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                validator: (v) =>
                                    _isLocationRequired &&
                                            (v == null ||
                                                double.tryParse(v) == null)
                                        ? 'Required'
                                        : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _lngController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'Longitude',
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                validator: (v) =>
                                    _isLocationRequired &&
                                            (v == null ||
                                                double.tryParse(v) == null)
                                        ? 'Required'
                                        : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                  color: AppColors.primary.withValues(alpha: 0.5)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: _isFetchingGps
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : Icon(Icons.my_location,
                                    color: AppColors.primary),
                            label: Text(
                              _isFetchingGps
                                  ? 'Getting GPS...'
                                  : 'Capture Current GPS Location',
                              style: TextStyle(color: AppColors.primary),
                            ),
                            onPressed:
                                _isFetchingGps ? null : _fetchCurrentGps,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // ─── Step 4: Fields ───────────────────────────────
                      _sectionLabel('4. Checklist Fields'),
                      const SizedBox(height: 8),
                      if (_fields.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No fields yet. Add fields below.',
                            style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey,
                                fontSize: 13),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _fields.length,
                          itemBuilder: (context, idx) {
                            final f = _fields[idx];
                            final isToggle = f['type'] == 'toggle';
                            final hasLimits = f['warningMin'] != null;
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              child: ListTile(
                                dense: true,
                                leading: Icon(
                                  isToggle
                                      ? Icons.toggle_on_outlined
                                      : Icons.numbers,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                title: Text(
                                  '${f['name']}  (${(f['type'] as String).toUpperCase()})',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                                subtitle: isToggle
                                    ? Text(
                                        'Options: ${(f['options'] as List).join(', ')}',
                                        style: const TextStyle(fontSize: 11))
                                    : hasLimits
                                        ? Text(
                                            'Warn ≥${f['warningMin']}%  •  Critical ≥${f['criticalMin']}%',
                                            style: const TextStyle(
                                                fontSize: 11))
                                        : null,
                                trailing: IconButton(
                                  icon: const Icon(Icons.remove_circle_outline,
                                      color: Colors.redAccent, size: 18),
                                  onPressed: () => setState(
                                      () => _fields.removeAt(idx)),
                                ),
                              ),
                            );
                          },
                        ),

                      // ─── Add field form ─────────────────────────────
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:
                              Colors.blueAccent.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.blueAccent.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Add Field Component',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _fieldNameController,
                              decoration: InputDecoration(
                                labelText: 'Field Name',
                                hintText: 'e.g. DC Current',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              value: _addFieldType,
                              decoration: InputDecoration(
                                labelText: 'Field Type',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: 'numeric',
                                    child: Text('Numeric (Decimal Input)')),
                                DropdownMenuItem(
                                    value: 'toggle',
                                    child: Text('Toggle / Segmented Buttons')),
                                DropdownMenuItem(
                                    value: 'text',
                                    child: Text('Text Field')),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _addFieldType = v);
                                }
                              },
                            ),
                            if (_addFieldType == 'toggle') ...[
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _fieldOptionsController,
                                decoration: InputDecoration(
                                  labelText: 'Options (comma separated)',
                                  hintText: 'Auto, Manual',
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                  isDense: true,
                                ),
                              ),
                            ],
                            if (_addFieldType == 'numeric') ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _warningMinController,
                                      keyboardType: const TextInputType
                                          .numberWithOptions(decimal: true),
                                      decoration: InputDecoration(
                                        labelText: 'Warn Min',
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _warningMaxController,
                                      keyboardType: const TextInputType
                                          .numberWithOptions(decimal: true),
                                      decoration: InputDecoration(
                                        labelText: 'Warn Max',
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _criticalMinController,
                                      keyboardType: const TextInputType
                                          .numberWithOptions(decimal: true),
                                      decoration: InputDecoration(
                                        labelText: 'Crit Min',
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent
                                    .withValues(alpha: 0.15),
                                foregroundColor: Colors.blueAccent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add Field',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold)),
                              onPressed: _addField,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ─── Save button ──────────────────────────────────
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.save_outlined),
                        label: Text(
                          _isEditing
                              ? 'Update Checklist'
                              : 'Save Checklist',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _isSaving ? null : _save,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
    );
  }
}
