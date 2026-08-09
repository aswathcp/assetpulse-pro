import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:asset_pulse_pro/core/widgets/glass_container.dart';
import 'package:asset_pulse_pro/core/services/location_verification_service.dart';
import 'package:asset_pulse_pro/core/services/checklist_service.dart';
import 'package:asset_pulse_pro/core/services/hierarchy_service.dart';
import 'package:asset_pulse_pro/core/services/firestore_service.dart';
import 'package:asset_pulse_pro/features/operations/data/models/checklist_model.dart';
import 'package:asset_pulse_pro/core/constants/app_colors.dart';
import 'package:uuid/uuid.dart';

class DynamicChecklistForm extends StatefulWidget {
  final Map<String, dynamic> checklist;
  final Position? startPosition;
  final bool? isVerified;
  final Map<String, dynamic>? existingSubmission;

  const DynamicChecklistForm({
    super.key,
    required this.checklist,
    this.startPosition,
    this.isVerified,
    this.existingSubmission,
  });

  @override
  State<DynamicChecklistForm> createState() => _DynamicChecklistFormState();
}

class _DynamicChecklistFormState extends State<DynamicChecklistForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  // Controllers & Values
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _toggleValues = {};

  @override
  void initState() {
    super.initState();
    final existingFields = widget.existingSubmission != null ? (widget.existingSubmission!['fields'] as Map<String, dynamic>? ?? {}) : {};
    final fields = widget.checklist['fields'] as List? ?? [];
    for (final f in fields) {
      final name = f['name'] as String;
      final type = f['type'] as String;
      if (type == 'toggle') {
        final options = f['options'] as List? ?? [];
        _toggleValues[name] = existingFields[name]?.toString() ?? (options.isNotEmpty ? options.first.toString() : '');
      } else {
        _controllers[name] = TextEditingController(text: existingFields[name]?.toString() ?? '');
        // Add listener to rebuild form for real-time safety alerts and section completeness
        _controllers[name]!.addListener(() {
          setState(() {});
        });
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _isFormComplete() {
    final fields = widget.checklist['fields'] as List? ?? [];
    for (final f in fields) {
      final name = f['name'] as String;
      final type = f['type'] as String;
      if (type == 'toggle') {
        if (_toggleValues[name] == null || _toggleValues[name]!.isEmpty) return false;
      } else {
        if (_controllers[name] == null || _controllers[name]!.text.trim().isEmpty) return false;
      }
    }
    return true;
  }

  Future<void> _submitChecklist() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final firestoreService = FirestoreService();
      final hierarchyService = HierarchyService();
      final checklistService = ChecklistService();
      final locationService = LocationVerificationService();

      final authUser = firestoreService.currentUser;
      if (authUser == null) throw 'Not authenticated';

      final userProfile = await firestoreService.getUserProfile(authUser.uid);
      
      Position? endPosition;
      if (widget.checklist['isLocationRequired'] == true) {
        // Secondary GPS verification
        endPosition = await locationService.getCurrentLocation();
      }

      final submissionFields = <String, dynamic>{};
      final fields = widget.checklist['fields'] as List? ?? [];
      for (final f in fields) {
        final name = f['name'] as String;
        final type = f['type'] as String;
        if (type == 'toggle') {
          submissionFields[name] = _toggleValues[name];
        } else if (type == 'numeric') {
          submissionFields[name] = double.tryParse(_controllers[name]!.text) ?? _controllers[name]!.text;
        } else {
          submissionFields[name] = _controllers[name]!.text;
        }
      }

      String getSafeScope(String key) {
        final checklistVal = widget.checklist[key]?.toString().trim();
        if (checklistVal != null && checklistVal.isNotEmpty) {
          return checklistVal;
        }
        final profileVal = userProfile?[key]?.toString().trim();
        if (profileVal != null && profileVal.isNotEmpty) {
          return profileVal;
        }
        return '';
      }

      String getShiftFromTime(DateTime time) {
        final hr = time.hour;
        if (hr >= 7 && hr < 15) return 'AS';
        if (hr >= 15 && hr < 23) return 'BS';
        return 'CS';
      }

      final submission = ChecklistSubmissionModel(
        id: widget.existingSubmission?['id'] ?? const Uuid().v4(),
        checklistType: widget.checklist['name'] ?? '',
        locationTargetId: '${widget.checklist['unitId'] ?? ''} ${widget.checklist['name'] ?? ''}',
        startCoordinates: widget.startPosition != null 
            ? {'lat': widget.startPosition!.latitude, 'lng': widget.startPosition!.longitude} 
            : null,
        endCoordinates: endPosition != null 
            ? {'lat': endPosition.latitude, 'lng': endPosition.longitude} 
            : null,
        timestampStart: widget.startPosition?.timestamp ??
            (widget.existingSubmission?['timestampStart'] != null
                ? (DateTime.tryParse(widget.existingSubmission!['timestampStart'].toString()) ?? DateTime.now())
                : DateTime.now()),
        timestampEnd: DateTime.now(),
        submittedBy: authUser.uid,
        submittedByName: userProfile?['displayName'] ?? 'Unknown Operator',
        fields: submissionFields,
        isVerifiedLocation: (widget.checklist['isLocationRequired'] == true) && (widget.isVerified == true),
        businessId: hierarchyService.currentBusinessId,
        plantId: getSafeScope('plantId'),
        unitId: getSafeScope('unitId'),
        shift: getShiftFromTime(DateTime.now()),
        lastModifiedBy: widget.existingSubmission != null
            ? (userProfile?['displayName'] ?? 'Unknown')
            : null,
        lastModifiedAt: widget.existingSubmission != null
            ? DateTime.now().toIso8601String()
            : null,
      );

      await checklistService.submitChecklist(submission);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Checklist Submitted Successfully!', style: TextStyle(color: Colors.white)), 
            backgroundColor: Colors.green
          )
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = widget.checklist['fields'] as List? ?? [];
    final isLocationRequired = widget.checklist['isLocationRequired'] == true;
    final isGpsVerified = widget.isVerified == true;

    // Group adjacent numeric fields so we can render them side-by-side in a 3-column row
    final List<List<Map<String, dynamic>>> layoutGroups = [];
    List<Map<String, dynamic>> currentNumericGroup = [];

    for (final f in fields) {
      final mapField = Map<String, dynamic>.from(f);
      if (mapField['type'] == 'numeric' && (mapField['warningMin'] == null)) {
        // Generic adjacent numeric (e.g. DC Current, DC Voltage, Cell Voltage)
        currentNumericGroup.add(mapField);
        if (currentNumericGroup.length == 3) {
          layoutGroups.add(List.from(currentNumericGroup));
          currentNumericGroup.clear();
        }
      } else {
        if (currentNumericGroup.isNotEmpty) {
          layoutGroups.add(List.from(currentNumericGroup));
          currentNumericGroup.clear();
        }
        layoutGroups.add([mapField]);
      }
    }
    if (currentNumericGroup.isNotEmpty) {
      layoutGroups.add(List.from(currentNumericGroup));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.checklist['name'] ?? 'Checklist'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Custom Header Card
                          GlassContainer(
                            width: double.infinity,
                            borderRadius: 16,
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.checklist['name'] ?? '',
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Record selection, mode, battery readings and H2 %LEL safety value.',
                                    style: TextStyle(fontSize: 14, color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Location geofencing badge
                          if (isLocationRequired) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isGpsVerified
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isGpsVerified
                                      ? Colors.green.withValues(alpha: 0.6)
                                      : Colors.orange.withValues(alpha: 0.6),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isGpsVerified ? Icons.verified_user : Icons.gps_off,
                                    color: isGpsVerified ? Colors.greenAccent : Colors.orangeAccent,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isGpsVerified
                                        ? 'Physical Presence Verified (${widget.checklist['unitId']})'
                                        : 'Geofence Bypassed — Location Not Verified',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isGpsVerified ? Colors.white : Colors.orangeAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Dynamic Layout Items
                          ...layoutGroups.map((group) {
                            if (group.length > 1) {
                              // Adjacent standard numeric fields rendered in a horizontal row
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: Row(
                                  children: group.asMap().entries.map((entry) {
                                    final idx = entry.key;
                                    final f = entry.value;
                                    return Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                          left: idx > 0 ? 8.0 : 0.0,
                                          right: idx < group.length - 1 ? 8.0 : 0.0,
                                        ),
                                        child: _buildNumericField(f),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              );
                            } else {
                              // Single field layout (Toggle, safety-alert numeric, text)
                              final f = group.first;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: _buildSingleField(f),
                              );
                            }
                          }),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),

                // Orange Section Incomplete / Green Ready Bar at the bottom
                _buildStatusBanner(),
              ],
            ),
    );
  }

  Widget _buildSingleField(Map<String, dynamic> f) {
    final name = f['name'] as String;
    final type = f['type'] as String;

    if (type == 'toggle') {
      final options = (f['options'] as List? ?? []).map((e) => e.toString()).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70)),
          const SizedBox(height: 10),
          _buildToggleSelector(name, options),
        ],
      );
    } else if (type == 'numeric' && f['warningMin'] != null) {
      // Safety threshold LEL field
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField(name, Icons.warning_amber, isNumeric: true),
          const SizedBox(height: 12),
          _buildSafetyAlertCard(f),
        ],
      );
    } else if (type == 'numeric') {
      return _buildTextField(name, Icons.electric_meter, isNumeric: true);
    } else {
      return _buildTextField(name, Icons.text_snippet, isNumeric: false);
    }
  }

  Widget _buildNumericField(Map<String, dynamic> f) {
    final name = f['name'] as String;
    return TextFormField(
      controller: _controllers[name],
      style: const TextStyle(color: Colors.white, fontSize: 14),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: name,
        labelStyle: const TextStyle(color: Colors.white70, fontSize: 11),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5)),
      ),
      validator: (v) => v == null || v.isEmpty ? '' : null,
    );
  }

  Widget _buildTextField(String name, IconData icon, {required bool isNumeric}) {
    return TextFormField(
      controller: _controllers[name],
      style: const TextStyle(color: Colors.white),
      keyboardType: isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      decoration: InputDecoration(
        labelText: name,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryLight, width: 2)),
      ),
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
    );
  }

  Widget _buildToggleSelector(String fieldName, List<String> options) {
    final selectedValue = _toggleValues[fieldName] ?? '';
    return GlassContainer(
      width: double.infinity,
      borderRadius: 12,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Row(
          children: options.map((opt) {
            final isSelected = selectedValue == opt;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _toggleValues[fieldName] = opt;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF136980) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    opt,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white60,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSafetyAlertCard(Map<String, dynamic> f) {
    final name = f['name'] as String;
    final valText = _controllers[name]?.text ?? '';
    final val = double.tryParse(valText);

    final wMin = (f['warningMin'] ?? 10.0) as double;
    final wMax = (f['warningMax'] ?? 19.9) as double;
    final cMin = (f['criticalMin'] ?? 20.0) as double;

    String statusTitle = 'Normal: below $wMin% LEL';
    String limitsText = 'Recommended limits: <$wMin% Normal, $wMin-$wMax% Warning, >=$cMin% Critical.';
    Color cardBg = Colors.green.withValues(alpha: 0.12);
    Color borderCol = Colors.green.withValues(alpha: 0.4);
    Color textCol = Colors.greenAccent;

    if (val != null) {
      if (val >= cMin) {
        statusTitle = 'Critical: >= $cMin% LEL';
        cardBg = Colors.red.withValues(alpha: 0.15);
        borderCol = Colors.red.withValues(alpha: 0.5);
        textCol = Colors.redAccent;
      } else if (val >= wMin && val <= wMax) {
        statusTitle = 'Warning: $wMin - $wMax% LEL';
        cardBg = Colors.amber.withValues(alpha: 0.12);
        borderCol = Colors.amber.withValues(alpha: 0.5);
        textCol = Colors.amberAccent;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            statusTitle,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textCol),
          ),
          const SizedBox(height: 4),
          Text(
            limitsText,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    final isComplete = _isFormComplete();
    
    if (!isComplete) {
      return Container(
        color: const Color(0xFF3E2D1A), // Dark orange/brown
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: const SafeArea(
          top: false,
          child: Row(
            children: [
              Icon(Icons.more_horiz, color: Colors.orangeAccent),
              SizedBox(width: 12),
              Text(
                'Section Incomplete',
                style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _submitChecklist,
      child: Container(
        color: const Color(0xFF1E3A1E), // Dark green
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.greenAccent),
                  SizedBox(width: 12),
                  Text(
                    'All Sections Complete',
                    style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text(
                    'SUBMIT LOG',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward, color: Colors.white.withValues(alpha: 0.8)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
