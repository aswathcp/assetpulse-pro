// ignore_for_file: deprecated_member_use
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

  TextEditingController _getController(String name, {String initialText = ''}) {
    return _controllers.putIfAbsent(
      name,
      () => TextEditingController(text: initialText),
    );
  }

  @override
  void initState() {
    super.initState();
    final existingFields = widget.existingSubmission != null
        ? (widget.existingSubmission!['fields'] as Map<String, dynamic>? ?? {})
        : {};
    final fields = widget.checklist['fields'] as List? ?? [];
    for (final f in fields) {
      if (f is! Map) continue;
      final name = (f['name'] ?? '').toString();
      final type = (f['type'] ?? 'text').toString();
      if (name.isEmpty) continue;

      if (type == 'toggle') {
        final options = f['options'] as List? ?? [];
        _toggleValues[name] = existingFields[name]?.toString() ??
            (options.isNotEmpty ? options.first.toString() : '');
      } else {
        _getController(name,
            initialText: existingFields[name]?.toString() ?? '');
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

  bool _isFieldOptional(String name) {
    final lower = name.toLowerCase();
    return lower.contains('remark') ||
        lower.contains('note') ||
        lower.contains('reason') ||
        lower.contains('fault code') ||
        lower.contains('details') ||
        lower.contains('instructions') ||
        lower.contains('optional');
  }

  Future<void> _submitChecklist() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields before submitting.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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
      final hasLocationCoords = widget.checklist['isLocationRequired'] == true &&
          widget.checklist['latitude'] != null &&
          (widget.checklist['latitude'] as num).toDouble() != 0.0;

      if (hasLocationCoords) {
        try {
          endPosition = await locationService.getCurrentLocation();
        } catch (_) {}
      }

      final submissionFields = <String, dynamic>{};
      final fields = widget.checklist['fields'] as List? ?? [];
      for (final f in fields) {
        if (f is! Map) continue;
        final name = (f['name'] ?? '').toString();
        final type = (f['type'] ?? 'text').toString();
        if (name.isEmpty) continue;

        if (type == 'toggle') {
          submissionFields[name] = _toggleValues[name] ?? '';
        } else if (type == 'numeric') {
          final txt = _getController(name).text.trim();
          submissionFields[name] = double.tryParse(txt) ?? txt;
        } else {
          submissionFields[name] = _getController(name).text.trim();
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
        locationTargetId:
            '${widget.checklist['unitId'] ?? ''} ${widget.checklist['name'] ?? ''}',
        startCoordinates: widget.startPosition != null
            ? {
                'lat': widget.startPosition!.latitude,
                'lng': widget.startPosition!.longitude
              }
            : null,
        endCoordinates: endPosition != null
            ? {'lat': endPosition.latitude, 'lng': endPosition.longitude}
            : null,
        timestampStart: widget.startPosition?.timestamp ??
            (widget.existingSubmission?['timestampStart'] != null
                ? (DateTime.tryParse(
                        widget.existingSubmission!['timestampStart'].toString()) ??
                    DateTime.now())
                : DateTime.now()),
        timestampEnd: DateTime.now(),
        submittedBy: authUser.uid,
        submittedByName: userProfile?['displayName'] ?? 'Unknown Operator',
        fields: submissionFields,
        isVerifiedLocation:
            (widget.checklist['isLocationRequired'] == true) && (widget.isVerified == true),
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
            content: Text('Checklist Submitted Successfully!',
                style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawFields = widget.checklist['fields'] as List? ?? [];
    final fields = rawFields
        .whereType<Map>()
        .map((f) => Map<String, dynamic>.from(f))
        .toList();

    final isLocationRequired = widget.checklist['isLocationRequired'] == true &&
        widget.checklist['latitude'] != null &&
        (widget.checklist['latitude'] as num).toDouble() != 0.0;
    final isGpsVerified = widget.isVerified == true;

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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                              padding: const EdgeInsets.all(18.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.checklist['name'] ?? '',
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    widget.checklist['description'] ??
                                        'Record equipment parameters, status and operational readings.',
                                    style: const TextStyle(
                                        fontSize: 13, color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

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
                                    isGpsVerified
                                        ? Icons.verified_user
                                        : Icons.gps_off,
                                    color: isGpsVerified
                                        ? Colors.greenAccent
                                        : Colors.orangeAccent,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isGpsVerified
                                        ? 'Physical Presence Verified (${widget.checklist['unitId']})'
                                        : 'Geofence Bypassed — Location Not Verified',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isGpsVerified
                                          ? Colors.white
                                          : Colors.orangeAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // All fields rendered in clean, full-width spacious layout
                          ...fields.map((f) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _buildSingleField(f),
                              )),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),

                // Submit Button Banner
                _buildStatusBanner(),
              ],
            ),
    );
  }

  Widget _buildSingleField(Map<String, dynamic> f) {
    final name = (f['name'] ?? '').toString();
    final type = (f['type'] ?? 'text').toString();

    if (type == 'toggle') {
      final options =
          (f['options'] as List? ?? []).map((e) => e.toString()).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70)),
          const SizedBox(height: 8),
          _buildToggleSelector(name, options),
        ],
      );
    } else if (type == 'numeric') {
      return _HealthAwareNumericField(
        field: f,
        controller: _getController(name),
        isOptional: _isFieldOptional(name),
      );
    } else {
      return _buildTextField(name, Icons.text_snippet, isNumeric: false);
    }
  }

  Widget _buildTextField(String name, IconData icon,
      {required bool isNumeric}) {
    final isOptional = _isFieldOptional(name);
    final isMultiline = !isNumeric && isOptional;
    return TextFormField(
      controller: _getController(name),
      style: const TextStyle(color: Colors.white, fontSize: 14),
      keyboardType: isNumeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : (isMultiline ? TextInputType.multiline : TextInputType.text),
      maxLines: isMultiline ? 3 : 1,
      decoration: InputDecoration(
        labelText: isOptional ? '$name (Optional)' : name,
        labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white54, size: 20),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: Colors.white.withValues(alpha: 0.15))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primaryLight, width: 2)),
      ),
      validator: (v) {
        if (isOptional) return null;
        return v == null || v.trim().isEmpty ? 'Required' : null;
      },
    );
  }

  Widget _buildToggleSelector(String fieldName, List<String> options) {
    final selectedValue = _toggleValues[fieldName] ?? '';

    if (options.length > 3) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((opt) {
          final isSelected = selectedValue == opt;
          return GestureDetector(
            onTap: () {
              setState(() {
                _toggleValues[fieldName] = opt;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF136980)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryLight
                      : Colors.white.withValues(alpha: 0.15),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Text(
                opt,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12.5,
                ),
              ),
            ),
          );
        }).toList(),
      );
    }

    return GlassContainer(
      width: double.infinity,
      borderRadius: 10,
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
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF136980)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    opt,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white60,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
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



  Widget _buildStatusBanner() {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 2,
            ),
            icon: const Icon(Icons.check_circle_outline, size: 20),
            label: const Text('SUBMIT LOG',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            onPressed: _isSubmitting ? null : _submitChecklist,
          ),
        ),
      ),
    );
  }
}

/// Lightweight, self-contained numeric input with live health assessment
/// (HEALTHY [green] / WARNING [amber] / CRITICAL [red]) based on nominal values
/// and configured warning/critical limits. Only this widget rebuilds on keystroke.
class _HealthAwareNumericField extends StatefulWidget {
  final Map<String, dynamic> field;
  final TextEditingController controller;
  final bool isOptional;

  const _HealthAwareNumericField({
    required this.field,
    required this.controller,
    required this.isOptional,
  });

  @override
  State<_HealthAwareNumericField> createState() => _HealthAwareNumericFieldState();
}

class _HealthAwareNumericFieldState extends State<_HealthAwareNumericField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant _HealthAwareNumericField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  String _extractUnit(String name) {
    final start = name.lastIndexOf('(');
    final end = name.lastIndexOf(')');
    if (start != -1 && end != -1 && end > start) {
      return name.substring(start + 1, end).trim();
    }
    final lower = name.toLowerCase();
    if (lower.contains('%lel')) return '%LEL';
    if (lower.contains('temp')) return '°C';
    if (lower.contains('current')) return 'A';
    if (lower.contains('voltage')) return 'V';
    if (lower.contains('rpm')) return 'RPM';
    if (lower.contains('level') && lower.contains('%')) return '%';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.field['name'] ?? '').toString();
    final unit = _extractUnit(name);

    final nominal = (widget.field['nominalValue'] as num?)?.toDouble();
    final wMin = (widget.field['warningMin'] as num?)?.toDouble();
    final wMax = (widget.field['warningMax'] as num?)?.toDouble();
    final cMin = (widget.field['criticalMin'] as num?)?.toDouble();
    final cMax = (widget.field['criticalMax'] as num?)?.toDouble();

    final hasThresholds =
        nominal != null || wMin != null || wMax != null || cMin != null || cMax != null;

    final text = widget.controller.text.trim();
    final val = double.tryParse(text);

    Color? statusColor;
    String statusLabel = '';
    IconData? statusIcon;

    if (val != null && hasThresholds) {
      bool isCrit = false;
      bool isWarn = false;

      if ((cMin != null && val < cMin) || (cMax != null && val > cMax)) {
        isCrit = true;
      } else if ((wMin != null && val < wMin) || (wMax != null && val > wMax)) {
        isWarn = true;
      }

      if (isCrit) {
        statusColor = Colors.redAccent;
        statusLabel = 'CRITICAL';
        statusIcon = Icons.error_outline;
      } else if (isWarn) {
        statusColor = Colors.orangeAccent;
        statusLabel = 'WARNING';
        statusIcon = Icons.warning_amber_rounded;
      } else {
        statusColor = Colors.greenAccent;
        statusLabel = 'HEALTHY';
        statusIcon = Icons.check_circle_outline;
      }
    }

    // Build limits summary text
    final List<String> limitsDetails = [];
    if (nominal != null) limitsDetails.add('Nominal: $nominal${unit.isNotEmpty ? ' $unit' : ''}');
    if (wMin != null || wMax != null) {
      final range = '${wMin ?? '—'} to ${wMax ?? '—'}';
      limitsDetails.add('Warn: $range${unit.isNotEmpty ? ' $unit' : ''}');
    }
    if (cMin != null || cMax != null) {
      final range = '${cMin ?? '—'} to ${cMax ?? '—'}';
      limitsDetails.add('Crit: $range${unit.isNotEmpty ? ' $unit' : ''}');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: widget.isOptional ? '$name (Optional)' : name,
            labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
            prefixIcon: const Icon(Icons.electric_meter, color: Colors.white54, size: 20),
            suffixIcon: (statusLabel.isNotEmpty && statusColor != null)
                ? Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 16),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : (unit.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Align(
                          alignment: Alignment.centerRight,
                          widthFactor: 1.0,
                          child: Text(
                            unit,
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ),
                      )
                    : null),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: statusColor != null
                    ? statusColor.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.15),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: statusColor ?? AppColors.primaryLight,
                width: 2,
              ),
            ),
          ),
          validator: (v) {
            if (widget.isOptional) return null;
            return v == null || v.trim().isEmpty ? 'Required' : null;
          },
        ),
        if (limitsDetails.isNotEmpty) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              limitsDetails.join('   •   '),
              style: TextStyle(
                fontSize: 10.5,
                color: statusColor ?? Colors.grey.shade400,
                fontWeight: statusColor != null ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
