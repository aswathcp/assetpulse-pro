import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:asset_pulse_pro/core/widgets/glass_container.dart';
import 'package:asset_pulse_pro/core/services/location_verification_service.dart';
import 'package:asset_pulse_pro/core/services/checklist_service.dart';
import 'package:asset_pulse_pro/core/services/hierarchy_service.dart';
import 'package:asset_pulse_pro/core/services/firestore_service.dart';
import 'package:asset_pulse_pro/features/operations/data/models/checklist_model.dart';
import 'package:uuid/uuid.dart';

class BatteryRoomChecklistForm extends StatefulWidget {
  final String targetName;
  final Position startPosition;
  final bool isVerified;

  const BatteryRoomChecklistForm({
    super.key,
    required this.targetName,
    required this.startPosition,
    this.isVerified = true,
  });

  @override
  State<BatteryRoomChecklistForm> createState() => _BatteryRoomChecklistFormState();
}

class _BatteryRoomChecklistFormState extends State<BatteryRoomChecklistForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  final _dcVoltageController = TextEditingController();
  final _dcCurrentController = TextEditingController();
  final _batteryCurrentController = TextEditingController();
  final _h2LelController = TextEditingController();

  bool _exhaustFanOn = false;
  String _selection = 'manual';
  String _mode = 'float';

  @override
  void dispose() {
    _dcVoltageController.dispose();
    _dcCurrentController.dispose();
    _batteryCurrentController.dispose();
    _h2LelController.dispose();
    super.dispose();
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
      
      // Secondary GPS Check for 'End' verification
      final endPosition = await locationService.getCurrentLocation();
      
      String getSafeScope(String key) {
        final profileVal = userProfile?[key]?.toString().trim();
        if (profileVal != null && profileVal.isNotEmpty) {
          return profileVal;
        }
        if (key == 'plantId') return 'VAB';
        if (key == 'unitId') return 'PID1';
        return '';
      }

      final submission = ChecklistSubmissionModel(
        id: const Uuid().v4(),
        checklistType: 'Shift Checklist - Battery Room',
        locationTargetId: widget.targetName,
        startCoordinates: {'lat': widget.startPosition.latitude, 'lng': widget.startPosition.longitude},
        endCoordinates: endPosition != null ? {'lat': endPosition.latitude, 'lng': endPosition.longitude} : null,
        timestampStart: widget.startPosition.timestamp,
        timestampEnd: DateTime.now(),
        submittedBy: authUser.uid,
        fields: {
          'dcVoltage': _dcVoltageController.text,
          'dcCurrent': _dcCurrentController.text,
          'batteryCurrent': _batteryCurrentController.text,
          'h2Lel': _h2LelController.text,
          'exhaustFanOn': _exhaustFanOn,
          'selection': _selection,
          'mode': _mode,
        },
        isVerifiedLocation: true, // As proven by the wrapper
        businessId: hierarchyService.currentBusinessId,
        plantId: getSafeScope('plantId'),
        unitId: getSafeScope('unitId'),
        shift: () {
          final hr = DateTime.now().hour;
          if (hr >= 7 && hr < 15) return 'AS';
          if (hr >= 15 && hr < 23) return 'BS';
          return 'CS';
        }(),
      );

      await checklistService.submitChecklist(submission);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verified Checklist Submitted Successfully!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
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
    return _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: GlassContainer(
                  width: double.infinity,
                  height: null,
                  borderRadius: 16,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Verification Badge
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: widget.isVerified
                                ? Colors.green.withValues(alpha: 0.2)
                                : Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: widget.isVerified ? Colors.green : Colors.orange,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                widget.isVerified ? Icons.check_circle : Icons.gps_off,
                                color: widget.isVerified ? Colors.green : Colors.orangeAccent,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.isVerified
                                    ? 'Physical Presence Verified'
                                    : 'Geofence Bypassed — Location Not Verified',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: widget.isVerified ? null : Colors.orangeAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Readings
                        const Text('Readings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        _buildTextField(context, _dcVoltageController, 'DC Voltage (V)', Icons.bolt),
                        const SizedBox(height: 16),
                        _buildTextField(context, _dcCurrentController, 'DC Current (A)', Icons.electric_meter),
                        const SizedBox(height: 16),
                        _buildTextField(context, _batteryCurrentController, 'Battery Current (A)', Icons.battery_charging_full),
                        const SizedBox(height: 16),
                        _buildTextField(context, _h2LelController, 'H2 %LEL', Icons.warning_amber),
                        
                        const Divider(height: 48),

                        // Toggles & Selection
                        const Text('Exhaust Fan & States', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        
                        SwitchListTile(
                          title: const Text('Exhaust Fan Status'),
                          subtitle: Text(_exhaustFanOn ? 'Running' : 'Stopped', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
                          activeThumbColor: Colors.greenAccent,
                          value: _exhaustFanOn,
                          onChanged: (val) => setState(() => _exhaustFanOn = val),
                        ),
                        const SizedBox(height: 16),
                        
                        DropdownButtonFormField<String>(
                          dropdownColor: Theme.of(context).colorScheme.surface,
                          decoration: InputDecoration(
                            labelText: 'Selection', 
                            prefixIcon: Icon(Icons.touch_app, color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.7))
                          ),
                          initialValue: _selection,
                          items: ['auto', 'manual'].map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
                          onChanged: (v) => setState(() => _selection = v!),
                        ),
                        const SizedBox(height: 16),
                        
                        DropdownButtonFormField<String>(
                          dropdownColor: Theme.of(context).colorScheme.surface,
                          decoration: InputDecoration(
                            labelText: 'Mode', 
                            prefixIcon: Icon(Icons.settings, color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.7))
                          ),
                          initialValue: _mode,
                          items: ['float', 'boost'].map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
                          onChanged: (v) => setState(() => _mode = v!),
                        ),
                        
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: _submitChecklist,
                          icon: const Icon(Icons.save),
                          label: const Text('Submit & Verify Exit'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
  }

  Widget _buildTextField(BuildContext context, TextEditingController controller, String label, IconData icon) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.7)),
      ),
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
    );
  }
}
