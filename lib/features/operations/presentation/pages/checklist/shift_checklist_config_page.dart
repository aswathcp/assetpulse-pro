// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:asset_pulse_pro/core/constants/app_colors.dart';
import 'package:asset_pulse_pro/core/services/auth_service.dart';
import 'package:asset_pulse_pro/core/services/firestore_service.dart';
import 'package:asset_pulse_pro/core/services/location_verification_service.dart';
import 'package:uuid/uuid.dart';

/// Supported checklist types covering all industrial unit operations.
const List<Map<String, dynamic>> kChecklistTypes = [
  {
    'value': 'battery_charger',
    'label': 'Battery Room & DG Charger',
    'subtitle': 'Battery banks, DG chargers, DC voltage, current, H2 %LEL & exhaust fans',
    'icon': 'battery_charging_full',
    'color': 0xFF16A34A,
    'available': true,
  },
  {
    'value': 'motor_status',
    'label': 'Motor & Pump Running Status',
    'subtitle': 'CTP, RWP, Fire Hydrant, Blowers, starter modes, RPM & bearing temps',
    'icon': 'settings_input_component',
    'color': 0xFFB91C1C,
    'available': true,
  },
  {
    'value': 'diesel_stock',
    'label': 'Diesel Stock & Fuel Levels',
    'subtitle': 'Main storage tanks, DG day tanks, stock in litres, cm & leakage checks',
    'icon': 'local_gas_station',
    'color': 0xFFEA580C,
    'available': true,
  },
  {
    'value': 'power_plant',
    'label': 'Power Plant Monitoring',
    'subtitle': 'MW generation, power export, grid frequency & gas consumption',
    'icon': 'bolt',
    'color': 0xFFF59E0B,
    'available': true,
  },
  {
    'value': 'personnel',
    'label': 'Personnel & Shift Manpower',
    'subtitle': 'Shift engineers, electricians, control room operators & handover notes',
    'icon': 'groups',
    'color': 0xFF2563EB,
    'available': true,
  },
  {
    'value': 'transformer',
    'label': 'Transformer Checklist',
    'subtitle': 'Oil & winding temps, oil levels, silica gel color & OLTC status',
    'icon': 'electric_bolt',
    'color': 0xFFD97706,
    'available': true,
  },
  {
    'value': 'pcc_mcc',
    'label': 'PCC / MCC & Switchgear',
    'subtitle': 'Transformer incomers, bus coupler, neutral grounding & panel AC',
    'icon': 'developer_board',
    'color': 0xFF0284C7,
    'available': true,
  },
  {
    'value': 'panel_room',
    'label': 'Panel Room Observations & Handover',
    'subtitle': 'Room door locks, 5S score, safety briefing, EV charger & space heaters',
    'icon': 'meeting_room',
    'color': 0xFF475569,
    'available': true,
  },
  {
    'value': 'vfd',
    'label': 'VFD / Inverter Drive',
    'subtitle': 'Output frequency, bus voltage, motor current & heat sink temp',
    'icon': 'speed',
    'color': 0xFF7C3AED,
    'available': true,
  },
  {
    'value': 'tools_safety',
    'label': 'Tools, Safety Gear & First Aid',
    'subtitle': 'Safety gloves, discharge rod, multimeter, first aid consumables',
    'icon': 'medical_services',
    'color': 0xFF059669,
    'available': true,
  },
  {
    'value': 'custom',
    'label': 'Custom (Build Your Own)',
    'subtitle': 'Design an entirely bespoke checklist tailored to your equipment',
    'icon': 'tune',
    'color': 0xFF6B7280,
    'available': true,
  },
];

/// Default field templates per checklist type.
/// For 'battery_charger', all fields from battery rooms and all DG chargers are provided together.
List<Map<String, dynamic>> _defaultFieldsForType(String type) {
  switch (type) {
    case 'battery_charger':
    case 'battery_room':
    case 'dg_charger':
      return [
        {'name': 'Charger Selection', 'type': 'toggle', 'options': ['Auto', 'Manual']},
        {'name': 'Charger Mode', 'type': 'toggle', 'options': ['Float', 'Boost']},
        {'name': 'Voltage Selection', 'type': 'toggle', 'options': ['12V', '24V']},
        {'name': '24V Source', 'type': 'toggle', 'options': ['CAT DC Battery Charger', 'Alternate Source']},
        {
          'name': 'DC Voltage (V)',
          'type': 'numeric',
          'nominalValue': 24.0,
          'warningMin': 22.0,
          'warningMax': 26.0,
          'criticalMin': 20.0,
          'criticalMax': 28.0,
        },
        {'name': 'DC Current (A)', 'type': 'numeric'},
        {'name': 'Battery Current (A)', 'type': 'numeric'},
        {
          'name': 'H2 %LEL',
          'type': 'numeric',
          'warningMin': 10.0,
          'warningMax': 19.9,
          'criticalMin': 20.0,
          'criticalMax': 100.0,
        },
        {'name': 'Exhaust Fan', 'type': 'toggle', 'options': ['On', 'Off']},
        {'name': 'CAT DG-1 Mode', 'type': 'toggle', 'options': ['Manual', 'Auto']},
        {'name': 'CAT DG-1 Idle', 'type': 'toggle', 'options': ['Low Idle', 'High Idle']},
        {'name': 'CAT DG-2 Mode', 'type': 'toggle', 'options': ['Manual', 'Auto']},
        {'name': 'CAT DG-2 Idle', 'type': 'toggle', 'options': ['Low Idle', 'High Idle']},
        {'name': 'CAT DG-3 Mode', 'type': 'toggle', 'options': ['Manual', 'Auto']},
        {'name': 'CAT DG-3 Idle', 'type': 'toggle', 'options': ['Low Idle', 'High Idle']},
      ];

    case 'motor_status':
    case 'motor':
      return [
        {'name': 'Motor Running Status', 'type': 'toggle', 'options': ['Running', 'Stopped']},
        {'name': 'Operation Mode', 'type': 'toggle', 'options': ['SS', 'VFD', 'Star-Delta', 'DOL']},
        {'name': 'Auto Mode', 'type': 'toggle', 'options': ['Auto', 'Manual', 'Off']},
        {'name': 'Running Current (A)', 'type': 'numeric'},
        {'name': 'Motor Speed (RPM)', 'type': 'numeric'},
        {'name': 'PU Temp (°C)', 'type': 'numeric', 'warningMax': 70.0, 'criticalMax': 85.0},
        {'name': 'PM Temp (°C)', 'type': 'numeric', 'warningMax': 70.0, 'criticalMax': 85.0},
        {'name': 'VFD Fan Status', 'type': 'toggle', 'options': ['Running', 'Stopped']},
      ];

    case 'diesel_stock':
      return [
        {'name': 'Main Tank (Litre)', 'type': 'numeric'},
        {'name': 'CAT DG1 (cm)', 'type': 'numeric'},
        {'name': 'CAT DG2 (cm)', 'type': 'numeric'},
        {'name': 'CAT DG3 (cm)', 'type': 'numeric'},
        {'name': 'INTAC DG (cm)', 'type': 'numeric'},
        {'name': 'Fire Hydrant DG (cm)', 'type': 'numeric'},
      ];

    case 'power_plant':
      return [
        {'name': 'PP-1 Generation (MW)', 'type': 'numeric'},
        {'name': 'PP-1 Export (MW)', 'type': 'numeric'},
        {'name': 'PP-1 Gas Flow (KNm³/Hr)', 'type': 'numeric'},
        {'name': 'PP-2 Generation (MW)', 'type': 'numeric'},
        {'name': 'PP-2 Export (MW)', 'type': 'numeric'},
        {'name': 'PP-2 Gas Flow (KNm³/Hr)', 'type': 'numeric'},
        {
          'name': 'Grid Frequency (Hz)',
          'type': 'numeric',
          'nominalValue': 50.0,
          'warningMin': 49.5,
          'warningMax': 50.5,
          'criticalMin': 49.0,
          'criticalMax': 51.0,
        },
        {'name': 'Average Power Factor', 'type': 'numeric', 'nominalValue': 0.95, 'warningMin': 0.90, 'criticalMin': 0.85},
      ];

    case 'personnel':
      return [
        {'name': 'Shift Incharge / Engineer', 'type': 'text'},
        {'name': 'Duty Electrician', 'type': 'text'},
        {'name': 'Shift Superintendent', 'type': 'text'},
        {'name': 'BF1 Control Room', 'type': 'text'},
        {'name': 'BF2 Control Room', 'type': 'text'},
        {'name': 'Mechanical Engineer', 'type': 'text'},
        {'name': 'Instrumentation Technician', 'type': 'text'},
        {'name': 'Shift Safety Briefing', 'type': 'toggle', 'options': ['Conducted', 'Not Conducted']},
        {'name': 'Shift Remarks', 'type': 'text'},
      ];

    case 'transformer':
      return [
        {'name': 'Oil Temperature (°C)', 'type': 'numeric', 'warningMax': 75.0, 'criticalMax': 85.0},
        {'name': 'Winding Temperature (°C)', 'type': 'numeric', 'warningMax': 85.0, 'criticalMax': 95.0},
        {'name': 'Oil Level (%)', 'type': 'numeric', 'nominalValue': 60.0, 'warningMin': 40.0, 'criticalMin': 25.0},
        {'name': 'Silica Gel Color', 'type': 'toggle', 'options': ['Blue', 'Light Blue', 'Purple', 'Pink']},
        {'name': 'Oil Leakage', 'type': 'toggle', 'options': ['None', 'Minor', 'Major']},
      ];

    case 'pcc_mcc':
      return [
        {'name': 'TF1 Incomer', 'type': 'toggle', 'options': ['ON', 'OFF']},
        {'name': 'TF2 Incomer', 'type': 'toggle', 'options': ['ON', 'OFF']},
        {'name': 'Bus Coupler', 'type': 'toggle', 'options': ['ON', 'OFF']},
        {'name': 'TF1 Neutral Grounding', 'type': 'toggle', 'options': ['Connected', 'Disconnected']},
        {'name': 'TF2 Neutral Grounding', 'type': 'toggle', 'options': ['Connected', 'Disconnected']},
        {'name': 'PCC Exhaust Fan', 'type': 'toggle', 'options': ['Running', 'Stopped']},
      ];

    case 'panel_room':
      return [
        {'name': 'Panel Room Door Status', 'type': 'toggle', 'options': ['Locked', 'Unlocked']},
        {'name': 'AC 1 Status', 'type': 'toggle', 'options': ['Running', 'Stopped']},
        {'name': 'AC 2 Status', 'type': 'toggle', 'options': ['Running', 'Stopped']},
        {'name': 'Room Temperature (°C)', 'type': 'numeric', 'warningMax': 30.0, 'criticalMax': 35.0},
        {'name': '5S Housekeeping Score (1–5)', 'type': 'numeric', 'nominalValue': 5.0, 'warningMin': 3.0, 'criticalMin': 2.0},
        {'name': 'Shift Observations', 'type': 'text'},
      ];

    case 'vfd':
      return [
        {'name': 'Drive Status', 'type': 'toggle', 'options': ['Running', 'Stopped', 'Fault']},
        {'name': 'Control Mode', 'type': 'toggle', 'options': ['Auto', 'Manual', 'Local', 'Remote']},
        {'name': 'Output Frequency (Hz)', 'type': 'numeric', 'nominalValue': 50.0},
        {'name': 'Output Current (A)', 'type': 'numeric'},
        {'name': 'Drive Temperature (°C)', 'type': 'numeric', 'warningMax': 65.0, 'criticalMax': 75.0},
        {'name': 'Cooling Fan', 'type': 'toggle', 'options': ['Running', 'Stopped']},
      ];

    case 'tools_safety':
      return [
        {'name': '11kV / 33kV Safety Gloves', 'type': 'toggle', 'options': ['Tested & Healthy', 'Damaged', 'Missing']},
        {'name': 'Earth Discharge Rod', 'type': 'toggle', 'options': ['Available & Sound', 'Damaged', 'Missing']},
        {'name': 'Digital Multimeter', 'type': 'toggle', 'options': ['Operational', 'Faulty', 'Low Battery']},
        {'name': 'Digital Clamp Meter', 'type': 'toggle', 'options': ['Operational', 'Faulty', 'Low Battery']},
        {'name': 'HT Line Voltage Detector', 'type': 'toggle', 'options': ['Tested & OK', 'Faulty', 'Missing']},
        {'name': 'Portable Emergency Light / Torch', 'type': 'toggle', 'options': ['Fully Charged', 'Discharged', 'Missing']},
        {'name': 'First Aid Dressing & Cotton Stock', 'type': 'toggle', 'options': ['Full Stock', 'Partially Used', 'Needs Replenishment']},
        {'name': 'Antiseptic & Burn Ointment Stock', 'type': 'toggle', 'options': ['Available & In Date', 'Low Stock', 'Missing']},
        {'name': 'Safety Eye Wash / Shower', 'type': 'toggle', 'options': ['Operational', 'Blocked', 'NA']},
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
  final _nominalValueController = TextEditingController(text: '');
  final _warningMinController = TextEditingController(text: '');
  final _warningMaxController = TextEditingController(text: '');
  final _criticalMinController = TextEditingController(text: '');
  final _criticalMaxController = TextEditingController(text: '');

  String? _selectedType;
  bool _isLocationRequired = false;
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
      _selectedType = c['checklistTypeKey'] ?? c['type'];
      _isLocationRequired = c['isLocationRequired'] == true;
      _latController.text = (c['latitude'] as num?)?.toString() ?? '0.0';
      _lngController.text = (c['longitude'] as num?)?.toString() ?? '0.0';
      final rawFields = c['fields'] as List? ?? [];
      _fields = rawFields.map((f) => Map<String, dynamic>.from(f as Map)).toList();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _fieldNameController.dispose();
    _fieldOptionsController.dispose();
    _nominalValueController.dispose();
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
      final typeInfo = kChecklistTypes.firstWhere(
        (t) => t['value'] == val,
        orElse: () => {'label': 'Checklist'},
      );
      final label = typeInfo['label'] as String;
      if (_nameController.text.isEmpty) {
        _nameController.text = label;
      }
      // Populate fields from default template if empty
      if (_fields.isEmpty) {
        _fields = _defaultFieldsForType(val);
      }
    });
  }

  /// Reset current fields to the default fields for the active type
  void _loadDefaultFields() {
    if (_selectedType == null) return;
    setState(() {
      _fields = _defaultFieldsForType(_selectedType!);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loaded default fields for "${_selectedType!}".'),
        backgroundColor: Colors.blueAccent,
      ),
    );
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
      final nom = double.tryParse(_nominalValueController.text);
      final wMin = double.tryParse(_warningMinController.text);
      final wMax = double.tryParse(_warningMaxController.text);
      final cMin = double.tryParse(_criticalMinController.text);
      final cMax = double.tryParse(_criticalMaxController.text);
      if (nom != null) newField['nominalValue'] = nom;
      if (wMin != null) newField['warningMin'] = wMin;
      if (wMax != null) newField['warningMax'] = wMax;
      if (cMin != null) newField['criticalMin'] = cMin;
      if (cMax != null) newField['criticalMax'] = cMax;
    }
    setState(() {
      _fields.add(newField);
      _fieldNameController.clear();
      _nominalValueController.clear();
      _warningMinController.clear();
      _warningMaxController.clear();
      _criticalMinController.clear();
      _criticalMaxController.clear();
    });
  }

  void _showEditFieldDialog(int index) {
    final field = _fields[index];
    final isNumeric = field['type'] == 'numeric';
    final isToggle = field['type'] == 'toggle';

    final nameCtrl = TextEditingController(text: field['name'] ?? '');
    final optCtrl = TextEditingController(
      text: (field['options'] as List? ?? []).join(', '),
    );
    final nomCtrl = TextEditingController(
      text: field['nominalValue']?.toString() ?? '',
    );
    final wMinCtrl = TextEditingController(
      text: field['warningMin']?.toString() ?? '',
    );
    final wMaxCtrl = TextEditingController(
      text: field['warningMax']?.toString() ?? '',
    );
    final cMinCtrl = TextEditingController(
      text: field['criticalMin']?.toString() ?? '',
    );
    final cMaxCtrl = TextEditingController(
      text: field['criticalMax']?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Field: ${field['name']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Field Name / Label',
                  isDense: true,
                ),
              ),
              if (isToggle) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: optCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Options (comma separated)',
                    isDense: true,
                  ),
                ),
              ],
              if (isNumeric) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: nomCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Nominal Target Value (Optional)',
                    hintText: 'e.g. 24.0 or 45.0',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Warning Limits (Leaves Healthy if inside):',
                    style: TextStyle(fontSize: 11, color: Colors.orangeAccent)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: wMinCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Warn Min',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: wMaxCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Warn Max',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Critical Limits (Triggers Red Alert if outside):',
                    style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: cMinCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Crit Min',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: cMaxCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Crit Max',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                field['name'] = nameCtrl.text.trim();
                if (isToggle) {
                  field['options'] = optCtrl.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
                } else if (isNumeric) {
                  final nom = double.tryParse(nomCtrl.text.trim());
                  final wMin = double.tryParse(wMinCtrl.text.trim());
                  final wMax = double.tryParse(wMaxCtrl.text.trim());
                  final cMin = double.tryParse(cMinCtrl.text.trim());
                  final cMax = double.tryParse(cMaxCtrl.text.trim());

                  if (nom != null) {
                    field['nominalValue'] = nom;
                  } else {
                    field.remove('nominalValue');
                  }
                  if (wMin != null) {
                    field['warningMin'] = wMin;
                  } else {
                    field.remove('warningMin');
                  }
                  if (wMax != null) {
                    field['warningMax'] = wMax;
                  } else {
                    field.remove('warningMax');
                  }
                  if (cMin != null) {
                    field['criticalMin'] = cMin;
                  } else {
                    field.remove('criticalMin');
                  }
                  if (cMax != null) {
                    field['criticalMax'] = cMax;
                  } else {
                    field.remove('criticalMax');
                  }
                }
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
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
        'updatedAt': DateTime.now().toIso8601String(),
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
        Navigator.pop(context, true);
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
                    // ─── Scope Chip ─────────────────────────────────────────
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
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Plant: ${widget.plantId}   •   Unit: ${widget.unitId}',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ─── Step 1: Checklist Type ─────────────────────────────
                    _sectionLabel('1. SELECT CHECKLIST TYPE'),
                    const SizedBox(height: 4),
                    const Text(
                      'Choose a standard equipment type or start with custom fields.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),

                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.3,
                      children: kChecklistTypes.map((t) {
                        final val = t['value'] as String;
                        final label = t['label'] as String;
                        final colorInt = t['color'] as int? ?? 0xFF6B7280;
                        final color = Color(colorInt);
                        final isSelected = _selectedType == val;
                        return GestureDetector(
                          onTap: () => _onTypeSelected(val),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color.withValues(alpha: 0.2)
                                  : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? color : Colors.white.withValues(alpha: 0.1),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(_iconForType(val), size: 18, color: color),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isSelected ? color : null,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(Icons.check_circle_rounded, size: 16, color: color),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    if (_selectedType != null) ...[
                      const SizedBox(height: 28),

                      // ─── Step 2: Name ───────────────────────────────────
                      _sectionLabel('2. CHECKLIST DISPLAY NAME'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Checklist Title',
                          hintText: 'e.g. BF1 Battery Room & Charger',
                          prefixIcon: const Icon(Icons.label_outline),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 24),

                      // ─── Step 3: Location Verification ─────────────────
                      _sectionLabel('3. GEOFENCE LOCATION VERIFICATION'),
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
                                'Require Physical GPS Geofence Verification',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                            subtitle: const Text(
                              'Ensures operator is physically at the equipment during rounds.',
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
                                  ? 'Acquiring GPS Fix...'
                                  : 'Capture Current Equipment Location',
                              style: TextStyle(color: AppColors.primary),
                            ),
                            onPressed:
                                _isFetchingGps ? null : _fetchCurrentGps,
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),

                      // ─── Step 4: Fields & Customization ─────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _sectionLabel('4. CONFIGURED CHECKLIST FIELDS (${_fields.length})'),
                          TextButton.icon(
                            style: TextButton.styleFrom(padding: EdgeInsets.zero),
                            icon: const Icon(Icons.refresh, size: 15),
                            label: const Text('Reset Template', style: TextStyle(fontSize: 12)),
                            onPressed: _loadDefaultFields,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Include or exclude fields for this unit. You can delete, reorder or add custom fields.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),

                      // ─── Available Template Fields Selector (Include/Exclude) ──
                      _buildTemplateFieldSelector(),

                      const SizedBox(height: 16),

                      if (_fields.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                          ),
                          child: const Center(
                            child: Text(
                              'No fields active. Select fields from the template above or add custom fields below.',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else ...[
                        const Text('Active Fields in Checklist:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white70)),
                        const SizedBox(height: 8),
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
                                onTap: () => _showEditFieldDialog(idx),
                                leading: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                  child: Icon(
                                    isToggle
                                        ? Icons.toggle_on_outlined
                                        : Icons.numbers,
                                    color: AppColors.primary,
                                    size: 16,
                                  ),
                                ),
                                title: Text(
                                  '${f['name']}  [${(f['type'] as String).toUpperCase()}]',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5),
                                ),
                                subtitle: isToggle
                                    ? Text(
                                        'Options: ${(f['options'] as List? ?? []).join(', ')}',
                                        style: const TextStyle(fontSize: 10.5))
                                    : hasLimits || f['nominalValue'] != null
                                        ? Text(
                                            '${f['nominalValue'] != null ? 'Nominal: ${f['nominalValue']}  •  ' : ''}Warn: ${f['warningMin'] ?? '—'}–${f['warningMax'] ?? '—'}  •  Crit: ${f['criticalMin'] ?? '—'}–${f['criticalMax'] ?? '—'}',
                                            style: const TextStyle(
                                                fontSize: 10.5, color: Colors.orangeAccent))
                                        : const Text('Tap to set nominal & warning/critical limits',
                                            style: TextStyle(fontSize: 10, color: Colors.grey)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined,
                                          color: Colors.blueAccent, size: 16),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: 'Edit Limits',
                                      onPressed: () => _showEditFieldDialog(idx),
                                    ),
                                    const SizedBox(width: 8),
                                    if (idx > 0)
                                      IconButton(
                                        icon: const Icon(Icons.arrow_upward, size: 16),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () {
                                          setState(() {
                                            final item = _fields.removeAt(idx);
                                            _fields.insert(idx - 1, item);
                                          });
                                        },
                                      ),
                                    if (idx < _fields.length - 1)
                                      IconButton(
                                        icon: const Icon(Icons.arrow_downward, size: 16),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () {
                                          setState(() {
                                            final item = _fields.removeAt(idx);
                                            _fields.insert(idx + 1, item);
                                          });
                                        },
                                      ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.redAccent, size: 18),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => setState(
                                          () => _fields.removeAt(idx)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],

                      // ─── Add Custom Field Component ───────────────────────
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.blueAccent.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.add_circle_outline, size: 16, color: Colors.blueAccent),
                                SizedBox(width: 8),
                                Text('Add Custom Field Component',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _fieldNameController,
                              decoration: InputDecoration(
                                labelText: 'Field Name / Label',
                                hintText: 'e.g. Header Pressure (kg/cm²)',
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
                                    child: Text('Numeric (Decimal Reading)')),
                                DropdownMenuItem(
                                    value: 'toggle',
                                    child: Text('Toggle / Segmented Options')),
                                DropdownMenuItem(
                                    value: 'text',
                                    child: Text('Text Input / Remarks')),
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
                                  labelText: 'Toggle Options (comma separated)',
                                  hintText: 'Auto, Manual, Off',
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                  isDense: true,
                                ),
                              ),
                            ],
                            if (_addFieldType == 'numeric') ...[
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _nominalValueController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'Nominal / Target Value (Optional)',
                                  hintText: 'e.g. 24.0 or 50.0',
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text('Optional Thresholds (Leave blank if none):',
                                  style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                              const SizedBox(height: 6),
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
                                  const SizedBox(width: 6),
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
                                  const SizedBox(width: 6),
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
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _criticalMaxController,
                                      keyboardType: const TextInputType
                                          .numberWithOptions(decimal: true),
                                      decoration: InputDecoration(
                                        labelText: 'Crit Max',
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
                            const SizedBox(height: 12),
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
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                              onPressed: _addField,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ─── Save / Update Button ─────────────────────────────
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

  /// Builds a checkable grid of all default template fields so the user can easily
  /// toggle fields on/off (e.g. Include DG fields, omit H2 %LEL, etc.)
  Widget _buildTemplateFieldSelector() {
    if (_selectedType == null) return const SizedBox.shrink();
    final templateFields = _defaultFieldsForType(_selectedType!);
    if (templateFields.isEmpty) return const SizedBox.shrink();

    final activeFieldNames = _fields.map((f) => f['name'] as String).toSet();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Template Fields (Tap to Include / Exclude):',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _fields = List.from(templateFields);
                      });
                    },
                    child: const Text('All', style: TextStyle(fontSize: 11, color: Colors.blueAccent)),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _fields.clear();
                      });
                    },
                    child: const Text('None', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: templateFields.map((tf) {
              final name = tf['name'] as String;
              final isIncluded = activeFieldNames.contains(name);
              return FilterChip(
                label: Text(name, style: TextStyle(fontSize: 11, color: isIncluded ? Colors.white : Colors.white60)),
                selected: isIncluded,
                selectedColor: AppColors.primary.withValues(alpha: 0.3),
                checkmarkColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                side: BorderSide(
                  color: isIncluded ? AppColors.primary : Colors.white.withValues(alpha: 0.15),
                ),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _fields.add(Map<String, dynamic>.from(tf));
                    } else {
                      _fields.removeWhere((f) => f['name'] == name);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.grey),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'battery_charger':
      case 'battery_room':
      case 'dg_charger':
        return Icons.battery_charging_full_rounded;
      case 'motor_status':
      case 'motor':
        return Icons.settings_input_component_rounded;
      case 'diesel_stock':
        return Icons.local_gas_station_rounded;
      case 'power_plant':
        return Icons.bolt_rounded;
      case 'personnel':
        return Icons.groups_rounded;
      case 'transformer':
        return Icons.electric_bolt_rounded;
      case 'pcc_mcc':
        return Icons.developer_board_rounded;
      case 'panel_room':
        return Icons.meeting_room_rounded;
      case 'vfd':
        return Icons.speed_rounded;
      case 'tools_safety':
        return Icons.medical_services_rounded;
      case 'custom':
        return Icons.tune_rounded;
      default:
        return Icons.checklist_rounded;
    }
  }
}
