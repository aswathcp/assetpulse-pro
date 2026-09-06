// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart';

import 'package:asset_pulse_pro/core/constants/app_colors.dart';
import 'package:asset_pulse_pro/core/widgets/glass_container.dart';
import 'package:asset_pulse_pro/core/widgets/pulse_loading.dart';
import 'package:asset_pulse_pro/core/widgets/animated_gradient_background.dart';
import 'package:asset_pulse_pro/core/services/firestore_service.dart';
import 'package:asset_pulse_pro/core/services/auth_service.dart';
import 'package:asset_pulse_pro/features/assets/data/models/asset_model.dart';
import 'package:asset_pulse_pro/features/assets/data/models/health_log_model.dart';

class LogDiagnosticTestPage extends StatefulWidget {
  final AssetModel asset;

  const LogDiagnosticTestPage({super.key, required this.asset});

  @override
  State<LogDiagnosticTestPage> createState() => _LogDiagnosticTestPageState();
}

class _LogDiagnosticTestPageState extends State<LogDiagnosticTestPage> {
  final _formKey = GlobalKey<FormState>();
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isSaving = false;

  late TextEditingController _testedByController;
  final _remarksController = TextEditingController();

  // 1. Motor Electrical Controllers & Checkpoints
  final _noLoadCurrentController = TextEditingController();
  final _resRYController = TextEditingController();
  final _resYBController = TextEditingController();
  final _resRBController = TextEditingController();

  final _irRyController = TextEditingController();
  final _irYbController = TextEditingController();
  final _irBrController = TextEditingController();
  final _irReController = TextEditingController();
  final _irYeController = TextEditingController();
  final _irBeController = TextEditingController();
  final _piController = TextEditingController();

  String _motorFanCondition = 'Clean & Good';
  String _motorShaftRotation = 'Smooth Hand Rotation';
  String _motorTerminalBox = 'Sealed & Dry';
  String _motorGreaseStatus = 'Greased OK';

  // 2. Gearbox Diagnostic Controllers & Checkpoints
  final _gbxBacklashController = TextEditingController();
  final _gbxSumpTempController = TextEditingController();
  String _gbxOilLevelQuality = 'Clean & Normal';
  String _gbxBreather = 'Clean & Free';
  String _gbxToothContact = 'Normal Mesh Pattern';
  String _gbxOilSeal = 'Zero Leak (Pass)';
  String _gbxShaftRotation = 'Smooth Hand Rotation';

  // 3. Pump Diagnostic Controllers & Checkpoints
  final _pmpHeadController = TextEditingController();
  final _pmpDischargePressController = TextEditingController();
  final _pmpFlowRateController = TextEditingController();
  final _pmpBearingTempController = TextEditingController();
  String _pmpSealCondition = 'Zero Leak (Pass)';
  String _pmpImpellerNoise = 'Silent & Smooth';

  // 4. Brake Diagnostic Controllers & Checkpoints
  final _brkStrokeController = TextEditingController();
  final _brkLiningThicknessController = TextEditingController();
  final _brkDrumClearanceController = TextEditingController();
  final _brkTorqueController = TextEditingController();
  String _brkHoldingTest = 'Pass (Zero Slip)';
  String _brkManualRelease = 'Free & Smooth';

  // 5. Actuator Diagnostic Controllers & Checkpoints
  final _actTorqueController = TextEditingController();
  final _actTravelTimeController = TextEditingController();
  String _actFeedbackSignal = 'Linear 4.0 - 20.0 mA';
  String _actLimitSwitch = 'Open/Close Trip OK';
  String _actHandwheel = 'Smooth Engagement';
  String _actTerminalSeal = 'Sealed & Dry';

  // 6. Universal Vibration Controllers
  final _vibDeHController = TextEditingController();
  final _vibDeVController = TextEditingController();
  final _vibDeAController = TextEditingController();
  final _vibNdeHController = TextEditingController();
  final _vibNdeVController = TextEditingController();
  final _vibNdeAController = TextEditingController();
  final _vibGController = TextEditingController();

  // Intelligent Status Determination
  String _selectedHealthStatus = 'healthy';
  bool _manualOverride = false;
  List<String> _diagnosticNotes = [];

  // Post-Test Conversion to Spare
  bool _convertToSpareOnPass = true;
  final _spareLocationController = TextEditingController();

  // Biometric Signing
  bool _enableBiometricSigning = true;

  @override
  void initState() {
    super.initState();
    final currentUser = AuthService().currentUser;
    final initialName = (currentUser?.displayName != null && currentUser!.displayName!.isNotEmpty)
        ? currentUser.displayName!
        : (currentUser?.email != null && currentUser!.email!.isNotEmpty)
            ? currentUser.email!.split('@').first
            : 'Quality Control Tech';
    _testedByController = TextEditingController(text: initialName);
    _spareLocationController.text = widget.asset.spareLocation ?? 'Central Warehouse';
    _recalculateHealth();
    _loadTestedByUser();
  }

  Future<void> _loadTestedByUser() async {
    final user = AuthService().currentUser;
    if (user != null) {
      final profile = await FirestoreService().getUserProfile(user.uid);
      if (profile != null) {
        final profileName = (profile['displayName'] as String?) ??
            (profile['fullName'] as String?) ??
            (profile['name'] as String?) ??
            user.displayName ??
            user.email?.split('@').first ??
            'Quality Control Tech';
        if (mounted && profileName.isNotEmpty) {
          setState(() {
            _testedByController.text = profileName;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _testedByController.dispose();
    _remarksController.dispose();
    _noLoadCurrentController.dispose();
    _resRYController.dispose();
    _resYBController.dispose();
    _resRBController.dispose();
    _irRyController.dispose();
    _irYbController.dispose();
    _irBrController.dispose();
    _irReController.dispose();
    _irYeController.dispose();
    _irBeController.dispose();
    _piController.dispose();

    _gbxBacklashController.dispose();
    _gbxSumpTempController.dispose();

    _pmpHeadController.dispose();
    _pmpDischargePressController.dispose();
    _pmpFlowRateController.dispose();
    _pmpBearingTempController.dispose();

    _brkStrokeController.dispose();
    _brkLiningThicknessController.dispose();
    _brkDrumClearanceController.dispose();
    _brkTorqueController.dispose();

    _actTorqueController.dispose();
    _actTravelTimeController.dispose();

    _vibDeHController.dispose();
    _vibDeVController.dispose();
    _vibDeAController.dispose();
    _vibNdeHController.dispose();
    _vibNdeVController.dispose();
    _vibNdeAController.dispose();
    _vibGController.dispose();
    _spareLocationController.dispose();
    super.dispose();
  }

  // --- AUTOMATED INTELLIGENT DIAGNOSTIC EVALUATION ENGINE ---
  void _recalculateHealth() {
    final notes = <String>[];
    String status = 'healthy';

    // 1. Motor Specific Checks
    if (widget.asset.type == AssetType.motor) {
      final irValues = [
        double.tryParse(_irRyController.text),
        double.tryParse(_irYbController.text),
        double.tryParse(_irBrController.text),
        double.tryParse(_irReController.text),
        double.tryParse(_irYeController.text),
        double.tryParse(_irBeController.text),
      ].whereType<double>().toList();

      if (irValues.isNotEmpty) {
        final minIr = irValues.reduce(math.min);
        if (minIr < 2.0) {
          status = 'critical';
          notes.add('🚨 Critical IR degradation detected ($minIr MΩ < 2 MΩ threshold). Extreme earth-fault risk!');
        } else if (minIr < 5.0) {
          if (status != 'critical') status = 'warning';
          notes.add('⚠️ Marginal insulation resistance ($minIr MΩ). Baking/drying out required.');
        } else {
          notes.add('✅ Healthy insulation resistance (Lowest: $minIr MΩ ≥ 5 MΩ).');
        }
      }

      final rRy = double.tryParse(_resRYController.text);
      final rYb = double.tryParse(_resYBController.text);
      final rRb = double.tryParse(_resRBController.text);
      if (rRy != null && rYb != null && rRb != null && rRy > 0 && rYb > 0 && rRb > 0) {
        final avg = (rRy + rYb + rRb) / 3.0;
        final maxDev = math.max((rRy - avg).abs(), math.max((rYb - avg).abs(), (rRb - avg).abs()));
        final unbalancePct = (maxDev / avg) * 100.0;

        if (unbalancePct > 5.0) {
          status = 'critical';
          notes.add('🚨 Severe resistance unbalance (${unbalancePct.toStringAsFixed(1)}% > 5%). Turn-to-turn short risk.');
        } else if (unbalancePct > 2.0) {
          if (status != 'critical') status = 'warning';
          notes.add('⚠️ Moderate resistance imbalance (${unbalancePct.toStringAsFixed(1)}%). Check connections.');
        } else {
          notes.add('✅ Balanced winding resistance (${unbalancePct.toStringAsFixed(1)}% unbalance ≤ 2%).');
        }
      }

      if (_motorShaftRotation == 'Seized') {
        status = 'critical';
        notes.add('🚨 Motor rotor shaft is seized / cannot rotate freely by hand!');
      } else if (_motorShaftRotation == 'Tight / Stiff') {
        if (status != 'critical') status = 'warning';
        notes.add('⚠️ Rotor shaft rotation is stiff. Check bearings / alignment.');
      }

      if (_motorFanCondition == 'Damaged' || _motorFanCondition == 'Missing / Loose') {
        if (status != 'critical') status = 'warning';
        notes.add('⚠️ Cooling fan condition defect: $_motorFanCondition.');
      }
    }

    // 2. Gearbox Specific Checks
    if (widget.asset.type == AssetType.gearbox) {
      if (_gbxOilLevelQuality == 'Degraded / Dark' || _gbxOilLevelQuality == 'Low Level') {
        if (status != 'critical') status = 'warning';
        notes.add('⚠️ Gearbox lubrication defect: $_gbxOilLevelQuality. Lube flush required.');
      }
      if (_gbxOilSeal == 'Active Leak') {
        if (status != 'critical') status = 'warning';
        notes.add('⚠️ Active oil seal leak on gearbox shaft.');
      }
      if (_gbxToothContact == 'Severe Wear' || _gbxToothContact == 'Pitted / Spalling') {
        status = 'critical';
        notes.add('🚨 Gear tooth meshing defect: $_gbxToothContact.');
      }
      if (_gbxShaftRotation == 'Binding / Notchy') {
        status = 'critical';
        notes.add('🚨 Gearbox shaft binding detected during hand rotation.');
      }
    }

    // 3. Pump Specific Checks
    if (widget.asset.type == AssetType.pump) {
      if (_pmpSealCondition == 'Excessive Leak') {
        status = 'critical';
        notes.add('🚨 Excessive gland / mechanical seal leakage.');
      }
      if (_pmpImpellerNoise == 'Cavitation Noise' || _pmpImpellerNoise == 'Vane Wear') {
        if (status != 'critical') status = 'warning';
        notes.add('⚠️ Cavitation noise or impeller wear flagged during rotation.');
      }
    }

    // 4. Brake Specific Checks
    if (widget.asset.type == AssetType.brake) {
      final lining = double.tryParse(_brkLiningThicknessController.text);
      if (lining != null && lining < 3.0) {
        status = 'critical';
        notes.add('🚨 Brake shoe lining worn out ($lining mm < 3 mm limit). Immediate relining required.');
      }
      if (_brkHoldingTest == 'Slip Detected') {
        status = 'critical';
        notes.add('🚨 Brake holding slip failure detected during torque test!');
      }
      if (_brkManualRelease == 'Stiff / Jammed') {
        if (status != 'critical') status = 'warning';
        notes.add('⚠️ Manual release / spring mechanism is stiff.');
      }
    }

    // 5. Actuator Specific Checks
    if (widget.asset.type == AssetType.actuator) {
      if (_actFeedbackSignal == 'Signal Loss' || _actLimitSwitch == 'Fault / Over-travel') {
        status = 'critical';
        notes.add('🚨 Actuator signal loss or limit switch trip fault.');
      }
      if (_actHandwheel == 'Stiff / Jammed') {
        if (status != 'critical') status = 'warning';
        notes.add('⚠️ Handwheel declutch / manual mechanism is stiff.');
      }
    }

    // 6. Universal Vibration Check
    final vibValues = [
      double.tryParse(_vibDeHController.text),
      double.tryParse(_vibDeVController.text),
      double.tryParse(_vibDeAController.text),
      double.tryParse(_vibNdeHController.text),
      double.tryParse(_vibNdeVController.text),
      double.tryParse(_vibNdeAController.text),
    ].whereType<double>().toList();

    if (vibValues.isNotEmpty) {
      final maxVib = vibValues.reduce(math.max);
      if (maxVib > 4.5) {
        status = 'critical';
        notes.add('🚨 Severe mechanical vibration ($maxVib mm/s > 4.5 mm/s limit, ISO Zone D). Trip risk!');
      } else if (maxVib > 2.8) {
        if (status != 'critical') status = 'warning';
        notes.add('⚠️ Elevated vibration ($maxVib mm/s, ISO Zone C). Realignment recommended.');
      } else {
        notes.add('✅ Smooth vibration levels (Peak: $maxVib mm/s, ISO Zone A/B).');
      }
    }

    if (notes.isEmpty) {
      notes.add('Enter test measurements below to trigger real-time AI diagnostic evaluation.');
    }

    setState(() {
      if (!_manualOverride) {
        _selectedHealthStatus = status;
      }
      _diagnosticNotes = notes;
    });
  }

  Future<void> _submitDiagnosticTest() async {
    if (!_formKey.currentState!.validate()) return;

    bool biometricPassed = false;
    if (_enableBiometricSigning) {
      try {
        final bool canCheck = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
        if (canCheck) {
          biometricPassed = await _localAuth.authenticate(
            localizedReason: 'Please authenticate to digitally sign and certify health test for ${widget.asset.tagNo}',
            biometricOnly: true,
          );
        }
      } catch (e) {
        debugPrint('Biometric authentication error: $e');
      }
    }

    setState(() => _isSaving = true);

    try {
      final Map<String, dynamic> irMap = {};
      if (_irRyController.text.isNotEmpty) irMap['R-Y'] = double.tryParse(_irRyController.text);
      if (_irYbController.text.isNotEmpty) irMap['Y-B'] = double.tryParse(_irYbController.text);
      if (_irBrController.text.isNotEmpty) irMap['B-R'] = double.tryParse(_irBrController.text);
      if (_irReController.text.isNotEmpty) irMap['R-E'] = double.tryParse(_irReController.text);
      if (_irYeController.text.isNotEmpty) irMap['Y-E'] = double.tryParse(_irYeController.text);
      if (_irBeController.text.isNotEmpty) irMap['B-E'] = double.tryParse(_irBeController.text);

      final irVals = irMap.values.whereType<double>().toList();
      if (irVals.isNotEmpty) {
        irMap['lowest'] = irVals.reduce(math.min);
      }

      final Map<String, dynamic> windingRes = {};
      if (_resRYController.text.isNotEmpty) windingRes['R-Y'] = double.tryParse(_resRYController.text);
      if (_resYBController.text.isNotEmpty) windingRes['Y-B'] = double.tryParse(_resYBController.text);
      if (_resRBController.text.isNotEmpty) windingRes['R-B'] = double.tryParse(_resRBController.text);

      final Map<String, dynamic> vibMap = {};
      if (_vibDeHController.text.isNotEmpty) vibMap['DE_H'] = double.tryParse(_vibDeHController.text);
      if (_vibDeVController.text.isNotEmpty) vibMap['DE_V'] = double.tryParse(_vibDeVController.text);
      if (_vibDeAController.text.isNotEmpty) vibMap['DE_A'] = double.tryParse(_vibDeAController.text);
      if (_vibNdeHController.text.isNotEmpty) vibMap['NDE_H'] = double.tryParse(_vibNdeHController.text);
      if (_vibNdeVController.text.isNotEmpty) vibMap['NDE_V'] = double.tryParse(_vibNdeVController.text);
      if (_vibNdeAController.text.isNotEmpty) vibMap['NDE_A'] = double.tryParse(_vibNdeAController.text);
      if (_vibGController.text.isNotEmpty) vibMap['G_Value'] = double.tryParse(_vibGController.text);

      final vibVals = [
        vibMap['DE_H'], vibMap['DE_V'], vibMap['DE_A'],
        vibMap['NDE_H'], vibMap['NDE_V'], vibMap['NDE_A'],
      ].whereType<double>().toList();
      if (vibVals.isNotEmpty) {
        vibMap['peak'] = vibVals.reduce(math.max);
      }

      // Collect type-specific diagnostic parameters
      final Map<String, dynamic> dynamicDiagnosticSpecs = {};
      if (widget.asset.type == AssetType.motor) {
        dynamicDiagnosticSpecs['fanCondition'] = _motorFanCondition;
        dynamicDiagnosticSpecs['shaftRotation'] = _motorShaftRotation;
        dynamicDiagnosticSpecs['terminalBox'] = _motorTerminalBox;
        dynamicDiagnosticSpecs['greaseStatus'] = _motorGreaseStatus;
      } else if (widget.asset.type == AssetType.gearbox) {
        if (_gbxBacklashController.text.isNotEmpty) dynamicDiagnosticSpecs['backlash'] = double.tryParse(_gbxBacklashController.text);
        if (_gbxSumpTempController.text.isNotEmpty) dynamicDiagnosticSpecs['sumpTemp'] = double.tryParse(_gbxSumpTempController.text);
        dynamicDiagnosticSpecs['oilLevelQuality'] = _gbxOilLevelQuality;
        dynamicDiagnosticSpecs['breather'] = _gbxBreather;
        dynamicDiagnosticSpecs['toothContact'] = _gbxToothContact;
        dynamicDiagnosticSpecs['oilSeal'] = _gbxOilSeal;
        dynamicDiagnosticSpecs['shaftRotation'] = _gbxShaftRotation;
      } else if (widget.asset.type == AssetType.pump) {
        if (_pmpHeadController.text.isNotEmpty) dynamicDiagnosticSpecs['head'] = double.tryParse(_pmpHeadController.text);
        if (_pmpDischargePressController.text.isNotEmpty) dynamicDiagnosticSpecs['dischargePressure'] = double.tryParse(_pmpDischargePressController.text);
        if (_pmpFlowRateController.text.isNotEmpty) dynamicDiagnosticSpecs['flowRate'] = double.tryParse(_pmpFlowRateController.text);
        if (_pmpBearingTempController.text.isNotEmpty) dynamicDiagnosticSpecs['bearingTemp'] = double.tryParse(_pmpBearingTempController.text);
        dynamicDiagnosticSpecs['sealStatus'] = _pmpSealCondition;
        dynamicDiagnosticSpecs['impellerNoise'] = _pmpImpellerNoise;
      } else if (widget.asset.type == AssetType.brake) {
        if (_brkStrokeController.text.isNotEmpty) dynamicDiagnosticSpecs['stroke'] = double.tryParse(_brkStrokeController.text);
        if (_brkLiningThicknessController.text.isNotEmpty) dynamicDiagnosticSpecs['lining'] = double.tryParse(_brkLiningThicknessController.text);
        if (_brkDrumClearanceController.text.isNotEmpty) dynamicDiagnosticSpecs['drumClearance'] = double.tryParse(_brkDrumClearanceController.text);
        if (_brkTorqueController.text.isNotEmpty) dynamicDiagnosticSpecs['torque'] = double.tryParse(_brkTorqueController.text);
        dynamicDiagnosticSpecs['holdingTest'] = _brkHoldingTest;
        dynamicDiagnosticSpecs['manualRelease'] = _brkManualRelease;
      } else {
        if (_actTorqueController.text.isNotEmpty) dynamicDiagnosticSpecs['torque'] = double.tryParse(_actTorqueController.text);
        if (_actTravelTimeController.text.isNotEmpty) dynamicDiagnosticSpecs['travelTime'] = double.tryParse(_actTravelTimeController.text);
        dynamicDiagnosticSpecs['feedbackSignal'] = _actFeedbackSignal;
        dynamicDiagnosticSpecs['limitSwitch'] = _actLimitSwitch;
        dynamicDiagnosticSpecs['handwheel'] = _actHandwheel;
        dynamicDiagnosticSpecs['terminalSeal'] = _actTerminalSeal;
      }

      final finalRemarks = [
        if (_remarksController.text.trim().isNotEmpty) _remarksController.text.trim() else _diagnosticNotes.join(" \n"),
        if (biometricPassed) '[Biometric Sign-Off: Verified by ${_testedByController.text} at ${DateTime.now().toLocal()}]',
      ].join(' \n');

      final healthLog = HealthLogModel(
        id: 'new',
        assetId: widget.asset.id,
        testDate: DateTime.now(),
        testedBy: _testedByController.text.trim(),
        noLoadCurrent: double.tryParse(_noLoadCurrentController.text),
        windingResistance: windingRes.isNotEmpty ? windingRes : null,
        insulationResistance: irMap.isNotEmpty ? irMap : null,
        polarizationIndex: double.tryParse(_piController.text),
        vibration: vibMap.isNotEmpty ? vibMap : null,
        specs: dynamicDiagnosticSpecs.isNotEmpty ? dynamicDiagnosticSpecs : null,
        remarks: finalRemarks,
        healthStatus: _selectedHealthStatus,
      );

      await FirestoreService().saveHealthLog(healthLog);

      final finalHealthEnum = _selectedHealthStatus == 'healthy'
          ? AssetHealthStatus.healthy
          : _selectedHealthStatus == 'warning'
              ? AssetHealthStatus.warning
              : AssetHealthStatus.critical;

      final bool shouldPromoteToSpare = _selectedHealthStatus == 'healthy' &&
          widget.asset.status == AssetStatus.underMaintenance &&
          _convertToSpareOnPass;

      final Map<String, dynamic> assetUpdates = {
        'healthStatus': finalHealthEnum.name,
        'lastPulseTime': FieldValue.serverTimestamp(),
        'lastServiceDate': FieldValue.serverTimestamp(),
        'nextServiceDue': Timestamp.fromDate(DateTime.now().add(const Duration(days: 180))), // 6-Month Cycle
        'modifiedAt': FieldValue.serverTimestamp(),
        'modifiedBy': AuthService().currentUser?.email ?? _testedByController.text,
      };

      if (irMap.isNotEmpty) assetUpdates['insulationResistance'] = irMap;
      if (windingRes.isNotEmpty) assetUpdates['windingResistance'] = windingRes;
      if (vibMap.isNotEmpty) assetUpdates['vibration'] = vibMap;
      if (double.tryParse(_piController.text) != null) assetUpdates['polarizationIndex'] = double.tryParse(_piController.text);
      if (double.tryParse(_noLoadCurrentController.text) != null) assetUpdates['noLoadCurrent'] = double.tryParse(_noLoadCurrentController.text);

      // Merge dynamic specs
      if (dynamicDiagnosticSpecs.isNotEmpty) {
        final existingSpecs = Map<String, dynamic>.from(widget.asset.specs ?? {});
        existingSpecs.addAll(dynamicDiagnosticSpecs);
        assetUpdates['specs'] = existingSpecs;
      }

      if (shouldPromoteToSpare) {
        assetUpdates['status'] = AssetStatus.spare.name;
        if (_spareLocationController.text.trim().isNotEmpty) {
          assetUpdates['spareLocation'] = _spareLocationController.text.trim();
        }
      }

      await FirebaseFirestore.instance.collection('assets').doc(widget.asset.id).update(assetUpdates);

      await FirestoreService().logActivity(
        userId: AuthService().currentUser?.uid ?? 'unknown',
        action: 'Diagnostic Test Run',
        details: 'Diagnostic Test Logged for ${widget.asset.tagNo} (Status: ${_selectedHealthStatus.toUpperCase()}, Period: 6 Months)',
      );

      if (mounted) {
        setState(() => _isSaving = false);
        _showAnimatedCompletionDialog(
          isCertified: _selectedHealthStatus == 'healthy',
          tagNo: widget.asset.tagNo,
          biometricPassed: biometricPassed,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving diagnostic log: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showAnimatedCompletionDialog({
    required bool isCertified,
    required String tagNo,
    required bool biometricPassed,
  }) {
    final String testerDisplay = _testedByController.text.trim().isNotEmpty
        ? _testedByController.text.trim()
        : (AuthService().currentUser?.displayName ?? AuthService().currentUser?.email?.split('@').first ?? 'QC Tech');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCertified ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                  border: Border.all(
                    color: isCertified ? Colors.greenAccent : Colors.redAccent,
                    width: 2,
                  ),
                ),
                child: Icon(
                  isCertified ? Icons.verified_user_rounded : Icons.warning_amber_rounded,
                  color: isCertified ? Colors.greenAccent : Colors.redAccent,
                  size: 46,
                ),
              )
                  .animate()
                  .scale(duration: 450.ms, curve: Curves.elasticOut)
                  .then()
                  .shimmer(duration: 1000.ms, color: isCertified ? Colors.greenAccent : Colors.redAccent),
              const SizedBox(height: 16),

              Text(
                isCertified ? 'HEALTH CHECK CERTIFIED (6-MO)' : 'DIAGNOSTIC ISSUES FLAGGED',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isCertified ? Colors.greenAccent : Colors.redAccent,
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: 8),

              Text(
                isCertified
                    ? 'Asset $tagNo parameters verified healthy and certified for 6-month validity period.'
                    : 'Diagnostic parameters for $tagNo require maintenance attention.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 14),

              if (biometricPassed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.fingerprint, color: Colors.blueAccent, size: 16),
                      const SizedBox(width: 6),
                      Text('Biometrically Certified by $testerDisplay',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    ],
                  ),
                ).animate().fadeIn(delay: 400.ms),
              const SizedBox(height: 20),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCertified ? AppColors.primary : Colors.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  Navigator.pop(context);
                },
                child: const Text('Return to Registry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    final isMotor = asset.type == AssetType.motor;
    final isGearbox = asset.type == AssetType.gearbox;
    final isPump = asset.type == AssetType.pump;
    final isBrake = asset.type == AssetType.brake;
    final isActuator = asset.type == AssetType.actuator;

    Color badgeColor = Colors.greenAccent;
    if (_selectedHealthStatus == 'warning') badgeColor = Colors.orangeAccent;
    if (_selectedHealthStatus == 'critical') badgeColor = Colors.redAccent;

    final isUnderMaintenance = asset.status == AssetStatus.underMaintenance;

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: Text('Diagnostic Health Check (${asset.tagNo})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: AnimatedGradientBackground(
        child: SafeArea(
          child: _isSaving
              ? const Center(child: PulseLoading(size: 60))
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Asset Overview Card
                        GlassContainer(
                          borderRadius: 16,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isMotor
                                        ? Icons.electric_bolt
                                        : isGearbox
                                            ? Icons.settings
                                            : isPump
                                                ? Icons.water_drop
                                                : isBrake
                                                    ? Icons.offline_bolt
                                                    : Icons.precision_manufacturing,
                                    color: AppColors.accent,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        asset.name.isNotEmpty ? asset.name : '${asset.type.name.toUpperCase()} Equipment',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${asset.tagNo} • ${asset.type.name.toUpperCase()} • ${asset.status.name.toUpperCase()}',
                                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 2. Intelligent AI Diagnostic Card
                        GlassContainer(
                          borderRadius: 16,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.auto_awesome, color: Colors.cyanAccent, size: 18),
                                        SizedBox(width: 6),
                                        Text('AI Diagnostic Evaluation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: badgeColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                                      ),
                                      child: Text(
                                        _selectedHealthStatus.toUpperCase(),
                                        style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ..._diagnosticNotes.map((note) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(note, style: const TextStyle(fontSize: 11.5, height: 1.35)),
                                    )),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 3. Status Manual Override
                        GlassContainer(
                          borderRadius: 16,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Inspector Final Certification Status', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                SegmentedButton<String>(
                                  segments: const [
                                    ButtonSegment(value: 'healthy', label: Text('Healthy (Pass)', style: TextStyle(fontSize: 10))),
                                    ButtonSegment(value: 'warning', label: Text('Attention', style: TextStyle(fontSize: 10))),
                                    ButtonSegment(value: 'critical', label: Text('Defect / Lockout', style: TextStyle(fontSize: 10))),
                                  ],
                                  selected: {_selectedHealthStatus},
                                  onSelectionChanged: (set) {
                                    setState(() {
                                      _selectedHealthStatus = set.first;
                                      _manualOverride = true;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 4. Conversion to Spare Pool (Only for Under Maintenance assets)
                        if (isUnderMaintenance) ...[
                          GlassContainer(
                            borderRadius: 16,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.inventory_2, color: Colors.cyanAccent, size: 18),
                                          SizedBox(width: 8),
                                          Text('Deploy to Spare Pool on Pass', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        ],
                                      ),
                                      Switch(
                                        value: _convertToSpareOnPass,
                                        activeColor: Colors.cyanAccent,
                                        onChanged: (v) => setState(() => _convertToSpareOnPass = v),
                                      ),
                                    ],
                                  ),
                                  if (_convertToSpareOnPass) ...[
                                    const SizedBox(height: 10),
                                    TextFormField(
                                      controller: _spareLocationController,
                                      decoration: const InputDecoration(
                                        labelText: 'Designated Storage Bay / Rack Location',
                                        prefixIcon: Icon(Icons.warehouse, size: 18),
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // 5. Inspector Biometric Sign-off
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _testedByController,
                                readOnly: true,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Tested By / Inspector (Locked)',
                                  labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                  prefixIcon: const Icon(Icons.lock, color: Colors.amberAccent, size: 18),
                                  suffixIcon: Container(
                                    margin: const EdgeInsets.all(8),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.6)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.verified, size: 12, color: Colors.greenAccent),
                                        SizedBox(width: 4),
                                        Text('Authenticated', style: TextStyle(fontSize: 10, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.fingerprint, color: Colors.cyanAccent, size: 18),
                                      SizedBox(width: 6),
                                      Text('Biometric Digital Sign-Off', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  Switch(
                                    value: _enableBiometricSigning,
                                    activeColor: Colors.cyanAccent,
                                    onChanged: (v) => setState(() => _enableBiometricSigning = v),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // --- TYPE SPECIFIC HEALTH TEST INPUTS ---

                        // A. MOTOR HEALTH PARAMETERS
                        if (isMotor) ...[
                          const Text('Winding Resistance (Ω)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accent)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: TextFormField(controller: _resRYController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'R-Y (Ω)', isDense: true, border: OutlineInputBorder()), onChanged: (_) => _recalculateHealth())),
                              const SizedBox(width: 8),
                              Expanded(child: TextFormField(controller: _resYBController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Y-B (Ω)', isDense: true, border: OutlineInputBorder()), onChanged: (_) => _recalculateHealth())),
                              const SizedBox(width: 8),
                              Expanded(child: TextFormField(controller: _resRBController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'R-B (Ω)', isDense: true, border: OutlineInputBorder()), onChanged: (_) => _recalculateHealth())),
                            ],
                          ),
                          const SizedBox(height: 14),

                          const Text('Insulation Resistance Phase-Phase (MΩ)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accent)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: TextFormField(controller: _irRyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'R-Y (MΩ)', isDense: true, border: OutlineInputBorder()), onChanged: (_) => _recalculateHealth())),
                              const SizedBox(width: 8),
                              Expanded(child: TextFormField(controller: _irYbController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Y-B (MΩ)', isDense: true, border: OutlineInputBorder()), onChanged: (_) => _recalculateHealth())),
                              const SizedBox(width: 8),
                              Expanded(child: TextFormField(controller: _irBrController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'B-R (MΩ)', isDense: true, border: OutlineInputBorder()), onChanged: (_) => _recalculateHealth())),
                            ],
                          ),
                          const SizedBox(height: 14),

                          const Text('Insulation Resistance Phase-Earth (MΩ)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accent)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: TextFormField(controller: _irReController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'R-E (MΩ)', isDense: true, border: OutlineInputBorder()), onChanged: (_) => _recalculateHealth())),
                              const SizedBox(width: 8),
                              Expanded(child: TextFormField(controller: _irYeController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Y-E (MΩ)', isDense: true, border: OutlineInputBorder()), onChanged: (_) => _recalculateHealth())),
                              const SizedBox(width: 8),
                              Expanded(child: TextFormField(controller: _irBeController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'B-E (MΩ)', isDense: true, border: OutlineInputBorder()), onChanged: (_) => _recalculateHealth())),
                            ],
                          ),
                          const SizedBox(height: 14),

                          Row(
                            children: [
                              Expanded(child: TextFormField(controller: _noLoadCurrentController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'No Load Current (A)', isDense: true, border: OutlineInputBorder()), onChanged: (_) => _recalculateHealth())),
                              const SizedBox(width: 12),
                              Expanded(child: TextFormField(controller: _piController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Polarization Index (PI 10m/1m)', isDense: true, border: OutlineInputBorder()), onChanged: (_) => _recalculateHealth())),
                            ],
                          ),
                          const SizedBox(height: 14),

                          const Text('Motor Mechanical & Visual Checks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accent)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _motorFanCondition,
                            decoration: const InputDecoration(labelText: 'Cooling Fan & Cowl Condition', border: OutlineInputBorder(), isDense: true),
                            items: const [
                              DropdownMenuItem(value: 'Clean & Good', child: Text('Clean & Good (Pass)')),
                              DropdownMenuItem(value: 'Damaged', child: Text('Damaged / Cracked Blades')),
                              DropdownMenuItem(value: 'Missing / Loose', child: Text('Missing / Loose Cowl')),
                            ],
                            onChanged: (v) {
                              setState(() => _motorFanCondition = v ?? 'Clean & Good');
                              _recalculateHealth();
                            },
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: _motorShaftRotation,
                            decoration: const InputDecoration(labelText: 'Free Shaft Rotation by Hand', border: OutlineInputBorder(), isDense: true),
                            items: const [
                              DropdownMenuItem(value: 'Smooth Hand Rotation', child: Text('Smooth Hand Rotation (Pass)')),
                              DropdownMenuItem(value: 'Tight / Stiff', child: Text('Tight / Stiff Rotation')),
                              DropdownMenuItem(value: 'Seized', child: Text('Seized / Cannot Turn')),
                            ],
                            onChanged: (v) {
                              setState(() => _motorShaftRotation = v ?? 'Smooth Hand Rotation');
                              _recalculateHealth();
                            },
                          ),
                          const SizedBox(height: 14),
                        ],

                        // B. GEARBOX HEALTH PARAMETERS
                        if (isGearbox) ...[
                          const Text('Gearbox Mechanical & Lube Checks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accent)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: TextFormField(controller: _gbxBacklashController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Backlash / Play (mm)', isDense: true, border: OutlineInputBorder()), onChanged: (_) => _recalculateHealth())),
                              const SizedBox(width: 10),
                              Expanded(child: TextFormField(controller: _gbxSumpTempController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sump Temp (°C)', isDense: true, border: OutlineInputBorder()), onChanged: (_) => _recalculateHealth())),
                            ],
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: _gbxOilLevelQuality,
                            decoration: const InputDecoration(labelText: 'Lube Oil Quality & Level', border: OutlineInputBorder(), isDense: true),
                            items: const [
                              DropdownMenuItem(value: 'Clean & Normal', child: Text('Clean & Normal Level (Pass)')),
                              DropdownMenuItem(value: 'Degraded / Dark', child: Text('Degraded / Contaminated')),
                              DropdownMenuItem(value: 'Low Level', child: Text('Low Oil Level')),
                            ],
                            onChanged: (v) {
                              setState(() => _gbxOilLevelQuality = v ?? 'Clean & Normal');
                              _recalculateHealth();
                            },
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: _gbxOilSeal,
                            decoration: const InputDecoration(labelText: 'Shaft Oil Seal Condition', border: OutlineInputBorder(), isDense: true),
                            items: const [
                              DropdownMenuItem(value: 'Zero Leak (Pass)', child: Text('Zero Leak (Pass)')),
                              DropdownMenuItem(value: 'Minor Weeping', child: Text('Minor Oil Weeping')),
                              DropdownMenuItem(value: 'Active Leak', child: Text('Active Oil Leakage')),
                            ],
                            onChanged: (v) {
                              setState(() => _gbxOilSeal = v ?? 'Zero Leak (Pass)');
                              _recalculateHealth();
                            },
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: _gbxToothContact,
                            decoration: const InputDecoration(labelText: 'Gear Tooth Mesh & Visual', border: OutlineInputBorder(), isDense: true),
                            items: const [
                              DropdownMenuItem(value: 'Normal Mesh Pattern', child: Text('Normal Mesh Pattern (Pass)')),
                              DropdownMenuItem(value: 'Pitted / Spalling', child: Text('Pitted / Surface Spalling')),
                              DropdownMenuItem(value: 'Severe Wear', child: Text('Severe Flank Wear')),
                            ],
                            onChanged: (v) {
                              setState(() => _gbxToothContact = v ?? 'Normal Mesh Pattern');
                              _recalculateHealth();
                            },
                          ),
                          const SizedBox(height: 14),
                        ],

                        // C. PUMP HEALTH PARAMETERS
                        if (isPump) ...[
                          const Text('Pump Hydraulic & Mechanical Checks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accent)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: TextFormField(controller: _pmpHeadController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Discharge Head (m)', isDense: true, border: OutlineInputBorder()), onChanged: (_) => _recalculateHealth())),
                              const SizedBox(width: 8),
                              Expanded(child: TextFormField(controller: _pmpDischargePressController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Pressure (Bar)', isDense: true, border: OutlineInputBorder()), onChanged: (_) => _recalculateHealth())),
                              const SizedBox(width: 8),
                              Expanded(child: TextFormField(controller: _pmpFlowRateController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Flow (m3/h)', isDense: true, border: OutlineInputBorder()), onChanged: (_) => _recalculateHealth())),
                            ],
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: _pmpSealCondition,
                            decoration: const InputDecoration(labelText: 'Gland / Mechanical Seal Condition', border: OutlineInputBorder(), isDense: true),
                            items: const [
                              DropdownMenuItem(value: 'Zero Leak (Pass)', child: Text('Zero Leak (Pass)')),
                              DropdownMenuItem(value: 'Normal Drip (10-20/min)', child: Text('Normal Drip (10-20 drops/min)')),
                              DropdownMenuItem(value: 'Excessive Leak', child: Text('Excessive Gland Leakage')),
                            ],
                            onChanged: (v) {
                              setState(() => _pmpSealCondition = v ?? 'Zero Leak (Pass)');
                              _recalculateHealth();
                            },
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: _pmpImpellerNoise,
                            decoration: const InputDecoration(labelText: 'Impeller & Hydraulic Noise', border: OutlineInputBorder(), isDense: true),
                            items: const [
                              DropdownMenuItem(value: 'Silent & Smooth', child: Text('Silent & Smooth (Pass)')),
                              DropdownMenuItem(value: 'Cavitation Noise', child: Text('Cavitation Noise Detected')),
                              DropdownMenuItem(value: 'Vane Wear', child: Text('Vane Wear / Rubbing')),
                            ],
                            onChanged: (v) {
                              setState(() => _pmpImpellerNoise = v ?? 'Silent & Smooth');
                              _recalculateHealth();
                            },
                          ),
                          const SizedBox(height: 14),
                        ],

                        // D. BRAKE HEALTH PARAMETERS
                        if (isBrake) ...[
                          const Text('Brake & Thruster Operational Checks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accent)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: TextFormField(controller: _brkStrokeController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Thruster Stroke (mm)', isDense: true, border: OutlineInputBorder()), onChanged: (_) => _recalculateHealth())),
                              const SizedBox(width: 8),
                              Expanded(child: TextFormField(controller: _brkLiningThicknessController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Lining Thk (mm)', isDense: true, border: OutlineInputBorder()), onChanged: (_) => _recalculateHealth())),
                              const SizedBox(width: 8),
                              Expanded(child: TextFormField(controller: _brkDrumClearanceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Drum Gap (mm)', isDense: true, border: OutlineInputBorder()), onChanged: (_) => _recalculateHealth())),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(child: TextFormField(controller: _brkTorqueController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Torque (Nm)', isDense: true, border: OutlineInputBorder()), onChanged: (_) => _recalculateHealth())),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _brkHoldingTest,
                                  decoration: const InputDecoration(labelText: 'Holding Test', border: OutlineInputBorder(), isDense: true),
                                  items: const [
                                    DropdownMenuItem(value: 'Pass (Zero Slip)', child: Text('Pass (Zero Slip)')),
                                    DropdownMenuItem(value: 'Slip Detected', child: Text('Slip Detected')),
                                  ],
                                  onChanged: (v) {
                                    setState(() => _brkHoldingTest = v ?? 'Pass (Zero Slip)');
                                    _recalculateHealth();
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                        ],

                        // E. ACTUATOR HEALTH PARAMETERS
                        if (isActuator) ...[
                          const Text('Actuator Control & Limit Checks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accent)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: TextFormField(controller: _actTorqueController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Torque/Thrust (Nm/kN)', isDense: true, border: OutlineInputBorder()), onChanged: (_) => _recalculateHealth())),
                              const SizedBox(width: 10),
                              Expanded(child: TextFormField(controller: _actTravelTimeController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Travel Time (sec)', isDense: true, border: OutlineInputBorder()), onChanged: (_) => _recalculateHealth())),
                            ],
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: _actFeedbackSignal,
                            decoration: const InputDecoration(labelText: 'Positioner Feedback (4-20mA)', border: OutlineInputBorder(), isDense: true),
                            items: const [
                              DropdownMenuItem(value: 'Linear 4.0 - 20.0 mA', child: Text('Linear 4.0 - 20.0 mA (Pass)')),
                              DropdownMenuItem(value: 'Offset / Non-Linear', child: Text('Offset / Non-Linear')),
                              DropdownMenuItem(value: 'Signal Loss', child: Text('Signal Loss / Open Loop')),
                            ],
                            onChanged: (v) {
                              setState(() => _actFeedbackSignal = v ?? 'Linear 4.0 - 20.0 mA');
                              _recalculateHealth();
                            },
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: _actLimitSwitch,
                            decoration: const InputDecoration(labelText: 'Limit & Torque Switch Operation', border: OutlineInputBorder(), isDense: true),
                            items: const [
                              DropdownMenuItem(value: 'Open/Close Trip OK', child: Text('Open/Close Trip OK (Pass)')),
                              DropdownMenuItem(value: 'Fault / Over-travel', child: Text('Fault / Over-travel Trip')),
                            ],
                            onChanged: (v) {
                              setState(() => _actLimitSwitch = v ?? 'Open/Close Trip OK');
                              _recalculateHealth();
                            },
                          ),
                          const SizedBox(height: 14),
                        ],

                        // 7. Universal Vibration Analysis
                        const Text('Vibration Analysis (ISO 10816 Velocity mm/s)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accent)),
                        const SizedBox(height: 6),
                        const Text('Drive End (DE) Vibration:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(child: TextFormField(controller: _vibDeHController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'DE Horizontal', isDense: true, border: OutlineInputBorder()), onChanged: (_) => _recalculateHealth())),
                            const SizedBox(width: 8),
                            Expanded(child: TextFormField(controller: _vibDeVController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'DE Vertical', isDense: true, border: OutlineInputBorder()), onChanged: (_) => _recalculateHealth())),
                            const SizedBox(width: 8),
                            Expanded(child: TextFormField(controller: _vibDeAController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'DE Axial', isDense: true, border: OutlineInputBorder()), onChanged: (_) => _recalculateHealth())),
                          ],
                        ),
                        const SizedBox(height: 8),

                        const Text('Non-Drive End (NDE) Vibration:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(child: TextFormField(controller: _vibNdeHController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'NDE Horizontal', isDense: true, border: OutlineInputBorder()), onChanged: (_) => _recalculateHealth())),
                            const SizedBox(width: 8),
                            Expanded(child: TextFormField(controller: _vibNdeVController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'NDE Vertical', isDense: true, border: OutlineInputBorder()), onChanged: (_) => _recalculateHealth())),
                            const SizedBox(width: 8),
                            Expanded(child: TextFormField(controller: _vibNdeAController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'NDE Axial', isDense: true, border: OutlineInputBorder()), onChanged: (_) => _recalculateHealth())),
                          ],
                        ),
                        const SizedBox(height: 10),

                        TextFormField(
                          controller: _vibGController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Peak Impact Acceleration G-Value (g)', isDense: true, border: OutlineInputBorder()),
                          onChanged: (_) => _recalculateHealth(),
                        ),
                        const SizedBox(height: 14),

                        // 8. Inspector Remarks
                        TextFormField(
                          controller: _remarksController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Inspector Remarks / Notes',
                            hintText: 'Enter specific observations or leave blank for auto-generated AI notes...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Submit Button
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: badgeColor == Colors.redAccent ? Colors.redAccent : AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.verified, color: Colors.white),
                          label: Text(
                            'SUBMIT & CERTIFY 6-MONTH HEALTH LOG (${_selectedHealthStatus.toUpperCase()})',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                          onPressed: _submitDiagnosticTest,
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
