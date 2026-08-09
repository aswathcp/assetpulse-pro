// ignore_for_file: deprecated_member_use

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/widgets/pulse_loading.dart';
import '../../data/models/asset_model.dart';
import '../../data/models/health_log_model.dart';

class LogDiagnosticTestPage extends StatefulWidget {
  final AssetModel asset;

  const LogDiagnosticTestPage({super.key, required this.asset});

  @override
  State<LogDiagnosticTestPage> createState() => _LogDiagnosticTestPageState();
}

class _LogDiagnosticTestPageState extends State<LogDiagnosticTestPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  late TextEditingController _testedByController;
  final _remarksController = TextEditingController();

  // Motor Electrical Controllers
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

  // Vibration Controllers
  final _vibDeHController = TextEditingController();
  final _vibDeVController = TextEditingController();
  final _vibDeAController = TextEditingController();
  final _vibNdeHController = TextEditingController();
  final _vibNdeVController = TextEditingController();
  final _vibNdeAController = TextEditingController();
  final _vibGController = TextEditingController();

  // Intelligent Status Determination
  String _calculatedHealthStatus = 'healthy';
  String _selectedHealthStatus = 'healthy';
  bool _manualOverride = false;
  List<String> _diagnosticNotes = [];

  // Post-Test Conversion to Spare
  bool _convertToSpareOnPass = true;
  final _spareLocationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _testedByController = TextEditingController(text: AuthService().currentUser?.displayName ?? AuthService().currentUser?.email?.split('@').first ?? 'Maintenance Tech');
    _spareLocationController.text = widget.asset.spareLocation ?? 'Central Warehouse';
    _recalculateHealth();
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

    // 1. Insulation Resistance Check (IEEE 43-2000 Standards)
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
        notes.add('🚨 Critical IR degradation detected ($minIr MΩ < 2 MΩ threshold). Extreme earth-fault/flashover risk!');
      } else if (minIr < 5.0) {
        if (status != 'critical') status = 'warning';
        notes.add('⚠️ Marginal insulation resistance ($minIr MΩ). Baking/drying out or cleaning required.');
      } else {
        notes.add('✅ Healthy insulation resistance (Lowest: $minIr MΩ ≥ 5 MΩ).');
      }
    }

    // 2. Winding Resistance Balance Check
    final rRy = double.tryParse(_resRYController.text);
    final rYb = double.tryParse(_resYBController.text);
    final rRb = double.tryParse(_resRBController.text);

    if (rRy != null && rYb != null && rRb != null && rRy > 0 && rYb > 0 && rRb > 0) {
      final avg = (rRy + rYb + rRb) / 3.0;
      final maxDev = math.max((rRy - avg).abs(), math.max((rYb - avg).abs(), (rRb - avg).abs()));
      final unbalancePct = (maxDev / avg) * 100.0;

      if (unbalancePct > 5.0) {
        status = 'critical';
        notes.add('🚨 Severe resistance unbalance (${unbalancePct.toStringAsFixed(1)}% > 5%). Probable turn-to-turn short or loose terminal connection.');
      } else if (unbalancePct > 2.0) {
        if (status != 'critical') status = 'warning';
        notes.add('⚠️ Moderate winding resistance imbalance (${unbalancePct.toStringAsFixed(1)}%). Check terminal tightness.');
      } else {
        notes.add('✅ Balanced 3-phase winding resistance (${unbalancePct.toStringAsFixed(1)}% imbalance ≤ 2%).');
      }
    }

    // 3. Polarization Index (PI) Check
    final pi = double.tryParse(_piController.text);
    if (pi != null) {
      if (pi < 1.5) {
        if (status != 'critical') status = 'warning';
        notes.add('⚠️ Low Polarization Index (PI: $pi < 1.5). Moisture absorption or carbon dirt detected.');
      } else if (pi >= 2.0) {
        notes.add('✅ Excellent Polarization Index (PI: $pi ≥ 2.0).');
      } else {
        notes.add('✅ Good Polarization Index (PI: $pi).');
      }
    }

    // 4. Vibration Analysis (ISO 10816-3 Velocity RMS in mm/s)
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
        notes.add('🚨 Severe mechanical vibration ($maxVib mm/s > 4.5 mm/s limit, ISO Zone D). Machine trip risk!');
      } else if (maxVib > 2.8) {
        if (status != 'critical') status = 'warning';
        notes.add('⚠️ Elevated vibration ($maxVib mm/s, ISO Zone C). Laser alignment / rotor rebalancing recommended.');
      } else {
        notes.add('✅ Normal smooth vibration levels (Peak: $maxVib mm/s, ISO Zone A/B).');
      }
    }

    // 5. Bearing Impact Acceleration (G-Value)
    final gVal = double.tryParse(_vibGController.text);
    if (gVal != null) {
      if (gVal > 2.0) {
        if (status != 'critical') status = 'warning';
        notes.add('⚠️ High bearing shock acceleration ($gVal g > 2.0 g). Check for bearing raceway spalling / lubrication.');
      } else {
        notes.add('✅ Normal bearing acceleration ($gVal g ≤ 2.0 g).');
      }
    }

    if (notes.isEmpty) {
      notes.add('Enter test measurements below to trigger real-time AI diagnostic evaluation.');
    }

    setState(() {
      _calculatedHealthStatus = status;
      if (!_manualOverride) {
        _selectedHealthStatus = status;
      }
      _diagnosticNotes = notes;
    });
  }

  Future<void> _submitDiagnosticTest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final windingRes = {
        if (_resRYController.text.isNotEmpty) 'R-Y': double.tryParse(_resRYController.text),
        if (_resYBController.text.isNotEmpty) 'Y-B': double.tryParse(_resYBController.text),
        if (_resRBController.text.isNotEmpty) 'R-B': double.tryParse(_resRBController.text),
      };

      final irMap = {
        if (_irRyController.text.isNotEmpty) 'R-Y': double.tryParse(_irRyController.text),
        if (_irYbController.text.isNotEmpty) 'Y-B': double.tryParse(_irYbController.text),
        if (_irBrController.text.isNotEmpty) 'B-R': double.tryParse(_irBrController.text),
        if (_irReController.text.isNotEmpty) 'R-E': double.tryParse(_irReController.text),
        if (_irYeController.text.isNotEmpty) 'Y-E': double.tryParse(_irYeController.text),
        if (_irBeController.text.isNotEmpty) 'B-E': double.tryParse(_irBeController.text),
      };

      final vibMap = {
        if (_vibDeHController.text.isNotEmpty) 'DE_H': double.tryParse(_vibDeHController.text),
        if (_vibDeVController.text.isNotEmpty) 'DE_V': double.tryParse(_vibDeVController.text),
        if (_vibDeAController.text.isNotEmpty) 'DE_A': double.tryParse(_vibDeAController.text),
        if (_vibNdeHController.text.isNotEmpty) 'NDE_H': double.tryParse(_vibNdeHController.text),
        if (_vibNdeVController.text.isNotEmpty) 'NDE_V': double.tryParse(_vibNdeVController.text),
        if (_vibNdeAController.text.isNotEmpty) 'NDE_A': double.tryParse(_vibNdeAController.text),
        if (_vibGController.text.isNotEmpty) 'G_Value': double.tryParse(_vibGController.text),
      };

      final finalRemarks = _remarksController.text.trim().isNotEmpty
          ? _remarksController.text.trim()
          : _diagnosticNotes.join(" \n");

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
        remarks: finalRemarks,
        healthStatus: _selectedHealthStatus,
      );

      // 1. Save Health Log to Dedicated Collection
      await FirestoreService().saveHealthLog(healthLog);

      // 2. Prepare Asset Updates
      final finalHealthEnum = _selectedHealthStatus == 'healthy'
          ? AssetHealthStatus.healthy
          : _selectedHealthStatus == 'warning'
              ? AssetHealthStatus.warning
              : AssetHealthStatus.critical;

      final bool shouldPromoteToSpare = _selectedHealthStatus == 'healthy' &&
          widget.asset.status != AssetStatus.active &&
          _convertToSpareOnPass;

      final Map<String, dynamic> assetUpdates = {
        'healthStatus': finalHealthEnum.name,
        'lastPulseTime': FieldValue.serverTimestamp(),
        'lastServiceDate': FieldValue.serverTimestamp(),
        'modifiedAt': FieldValue.serverTimestamp(),
        'modifiedBy': AuthService().currentUser?.email ?? 'Tech',
      };

      if (shouldPromoteToSpare) {
        assetUpdates['status'] = AssetStatus.spare.name;
        if (_spareLocationController.text.trim().isNotEmpty) {
          assetUpdates['spareLocation'] = _spareLocationController.text.trim();
        }
      }

      // Update asset doc in Firestore
      await FirebaseFirestore.instance.collection('assets').doc(widget.asset.id).update(assetUpdates);

      // Log Activity
      await FirestoreService().logActivity(
        userId: AuthService().currentUser?.uid ?? 'unknown',
        action: 'Diagnostic Test Run',
        details: 'Recorded diagnostic test for ${widget.asset.tagNo} with outcome: ${_selectedHealthStatus.toUpperCase()}'
            '${shouldPromoteToSpare ? " and moved asset to SPARE pool." : ""}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              shouldPromoteToSpare
                  ? 'Diagnostic test saved! Asset ${widget.asset.tagNo} verified and promoted to SPARE pool.'
                  : 'Diagnostic test recorded successfully with status ${_selectedHealthStatus.toUpperCase()}.',
            ),
            backgroundColor: _selectedHealthStatus == 'healthy' ? AppColors.success : Colors.orangeAccent,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving test: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    final isMotor = asset.type == AssetType.motor;

    Color badgeColor = Colors.greenAccent;
    if (_selectedHealthStatus == 'warning') badgeColor = Colors.orangeAccent;
    if (_selectedHealthStatus == 'critical') badgeColor = Colors.redAccent;

    final isNonActive = asset.status != AssetStatus.active;

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: Text('Diagnostic Health Check (${asset.tagNo})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: AnimatedGradientBackground(
        child: _isSaving
            ? const Center(child: PulseLoading(size: 60))
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Asset Context Card
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
                                  color: AppColors.primary.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  asset.type == AssetType.motor
                                      ? Icons.electric_bolt
                                      : asset.type == AssetType.gearbox
                                          ? Icons.settings
                                          : Icons.water_drop,
                                  color: AppColors.accent,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(asset.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 2),
                                    Text('${asset.tagNo} • ${asset.type.name.toUpperCase()} • ${asset.status.name.toUpperCase()}',
                                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 2. Intelligent Real-Time Evaluation Banner
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: badgeColor.withValues(alpha: 0.8), width: 1.5),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.auto_awesome, color: badgeColor, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        _manualOverride ? 'AI Assessment: ${_calculatedHealthStatus.toUpperCase()} (Overridden)' : 'AI Diagnostic Health Assessment',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: badgeColor),
                                    ),
                                    child: Text(
                                      _selectedHealthStatus.toUpperCase(),
                                      style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ..._diagnosticNotes.map((n) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(n, style: const TextStyle(fontSize: 11.5, height: 1.3)),
                                  )),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text('Override Assessment: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: SegmentedButton<String>(
                                      segments: const [
                                        ButtonSegment(value: 'healthy', label: Text('Healthy', style: TextStyle(fontSize: 10))),
                                        ButtonSegment(value: 'warning', label: Text('Warning', style: TextStyle(fontSize: 10))),
                                        ButtonSegment(value: 'critical', label: Text('Critical', style: TextStyle(fontSize: 10))),
                                      ],
                                      selected: {_selectedHealthStatus},
                                      onSelectionChanged: (set) {
                                        setState(() {
                                          _selectedHealthStatus = set.first;
                                          _manualOverride = true;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 3. Post-Test Promotion to Spare (When status is healthy & asset is not active)
                      if (isNonActive) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.cyan.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.5)),
                          ),
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
                                      Text('Ready for Deployment to Spare Pool',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.cyanAccent)),
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
                                const SizedBox(height: 6),
                                const Text(
                                  'Upon saving with HEALTHY status, this asset will automatically be upgraded from UNDER MAINTENANCE to the active SPARE inventory.',
                                  style: TextStyle(fontSize: 11, color: Colors.white70),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _spareLocationController,
                                  decoration: const InputDecoration(
                                    labelText: 'Warehouse Rack / Storage Bay',
                                    hintText: 'e.g. Central Warehouse - Rack B3',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.warehouse, color: Colors.cyanAccent, size: 18),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // 4. Test Header Info
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _testedByController,
                              decoration: const InputDecoration(labelText: 'Tested By / Inspector *', border: OutlineInputBorder(), isDense: true),
                              validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 5. Motor Electrical Tests
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
                      ],

                      // 6. Vibration Analysis
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

                      // 7. Inspector Remarks
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
                          'SUBMIT & CERTIFY DIAGNOSTIC LOG (${_selectedHealthStatus.toUpperCase()})',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                        onPressed: _submitDiagnosticTest,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
