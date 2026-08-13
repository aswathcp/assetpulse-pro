// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../../core/utils/permission_helper.dart';
import '../../data/models/asset_model.dart';
import '../../data/models/health_log_model.dart';
import '../../../../core/services/health_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/widgets/pulse_loading.dart';
import '../../../assets/presentation/pages/add_edit_asset_page.dart';
import '../../../log_data/presentation/pages/add_fault_log_page.dart';
import 'log_diagnostic_test_page.dart';
import '../../data/models/fault_log_model.dart';

class AssetDetailPage extends StatefulWidget {
  final AssetModel asset;

  const AssetDetailPage({super.key, required this.asset});

  @override
  State<AssetDetailPage> createState() => _AssetDetailPageState();
}

class _AssetDetailPageState extends State<AssetDetailPage> {
  bool _isLoading = true;
  String _userRole = '';
  bool _isAdmin = false;
  String? _userPlantId;
  String? _userUnitId;
  String? _assetPlantId;
  String? _assetUnitId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final currentUser = AuthService().currentUser;
      if (currentUser != null) {
        final profile = await FirestoreService().getUserProfile(currentUser.uid);
        if (profile != null) {
          _userRole = profile['role'] ?? 'Guest';
          _isAdmin = profile['isAdmin'] == true;
          _userPlantId = profile['plantId'] as String?;
          _userUnitId = profile['unitId'] as String?;
        }
      }

      if (widget.asset.masterEquipmentId.isNotEmpty) {
        final meDoc = await FirebaseFirestore.instance
            .collection('master_equipments')
            .doc(widget.asset.masterEquipmentId)
            .get();
        if (meDoc.exists && meDoc.data() != null) {
          final data = meDoc.data()!;
          _assetPlantId = data['plantId'] as String?;
          _assetUnitId = data['unitId'] as String?;
        }
      }
    } catch (e) {
      debugPrint("Error loading detail permissions: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool get _canEdit {
    return PermissionHelper.canEditDatabaseItem(
      userRole: _userRole,
      isAdmin: _isAdmin,
      userPlantId: _userPlantId,
      userUnitId: _userUnitId,
      itemPlantId: _assetPlantId,
      itemUnitId: _assetUnitId,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('assets').doc(widget.asset.id).snapshots(),
      builder: (context, snapshot) {
        final AssetModel currentAsset = snapshot.hasData && snapshot.data!.exists && snapshot.data!.data() != null
            ? AssetModel.fromMap(snapshot.data!.data()!, snapshot.data!.id)
            : widget.asset;

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: Text(currentAsset.tagNo),
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).colorScheme.onSurface),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_alert_rounded),
                tooltip: 'Log Fault',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddFaultLogPage(
                        masterEquipmentId: currentAsset.masterEquipmentId,
                        masterEquipmentName: 'Equipment ${currentAsset.masterEquipmentId}',
                        assetId: currentAsset.id,
                      ),
                    ),
                  );
                },
              ),
              if (!_isLoading && _canEdit)
                IconButton(
                  icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.onSurface),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddEditAssetPage(
                          asset: currentAsset,
                          unitId: _assetUnitId,
                          plantId: _assetPlantId,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          body: AnimatedGradientBackground(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 100, bottom: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header Information
                  _buildHeader(context, currentAsset),

                  const SizedBox(height: 20),

                  // 2. Tabbed Details
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GlassContainer(
                      width: double.infinity,
                      height: 620,
                      borderRadius: 24,
                      child: DefaultTabController(
                        length: 4,
                        child: Column(
                          children: [
                            const TabBar(
                              labelColor: AppColors.accent,
                              unselectedLabelColor: Colors.grey,
                              indicatorColor: AppColors.accent,
                              isScrollable: true,
                              tabAlignment: TabAlignment.start,
                              tabs: [
                                Tab(text: 'Identity'),
                                Tab(text: 'Specs'),
                                Tab(text: 'Health'),
                                Tab(text: 'History'),
                              ],
                            ),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  _buildIdentityTab(context, currentAsset),
                                  _buildSpecsTab(context, currentAsset),
                                  _buildHealthTab(context, currentAsset),
                                  _buildHistoryTab(context, currentAsset),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, AssetModel asset) {
    return Center(
      child: Column(
        children: [
          Text(
            asset.displayName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 10),

          // Header Badges (Status, Type, Critical, and Health only if known)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildStatusBadge(asset.status),
              _buildTypeBadge(asset.type),
              if (asset.isCritical) _buildCriticalBadge(),
              if (asset.healthStatus != AssetHealthStatus.unknown) _buildHealthBadge(asset.healthStatus),
            ],
          ),
          const SizedBox(height: 14),

          if (asset.status == AssetStatus.active) ...[
            TextButton.icon(
              onPressed: () => _showReplaceWithSpareDialog(context, asset),
              icon: const Icon(Icons.swap_horiz, color: AppColors.accent),
              label: const Text('Replace with Spare', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Quick Context Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.precision_manufacturing, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 16),
              const SizedBox(width: 4),
              Text(
                asset.status == AssetStatus.spare
                    ? (asset.spareLocation != null && asset.spareLocation!.isNotEmpty ? asset.spareLocation! : 'Spare Pool')
                    : (asset.masterEquipmentId.isNotEmpty ? asset.masterEquipmentId : 'Unassigned Machine'),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
              ),
              if (asset.make.isNotEmpty) ...[
                const SizedBox(width: 16),
                Icon(Icons.factory_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 16),
                const SizedBox(width: 4),
                Text(asset.make, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(AssetStatus status) {
    Color color;
    switch (status) {
      case AssetStatus.active:
        color = AppColors.success;
        break;
      case AssetStatus.underMaintenance:
        color = AppColors.warning;
        break;
      case AssetStatus.scrapped:
        color = AppColors.error;
        break;
      case AssetStatus.spare:
        color = Colors.cyanAccent;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _buildTypeBadge(AssetType type) {
    IconData icon;
    switch (type) {
      case AssetType.motor:
        icon = Icons.electric_bolt;
        break;
      case AssetType.gearbox:
        icon = Icons.settings;
        break;
      case AssetType.pump:
        icon = Icons.water_drop;
        break;
      case AssetType.brake:
        icon = Icons.disc_full_outlined;
        break;
      case AssetType.actuator:
        icon = Icons.tune;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.accent),
          const SizedBox(width: 5),
          Text(
            type.name.toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildCriticalBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber, color: Colors.redAccent, size: 13),
          SizedBox(width: 4),
          Text(
            'CRITICAL',
            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthBadge(AssetHealthStatus status) {
    final service = HealthService();
    final color = service.getHealthColor(status);
    final label = service.getHealthLabel(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.monitor_heart_outlined, color: color, size: 13),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: IDENTITY & GENERAL ---
  Widget _buildIdentityTab(BuildContext context, AssetModel asset) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('General Identity'),
          Row(
            children: [
              Expanded(child: _buildDetailBox(context, 'Asset Tag ID', asset.tagNo)),
              const SizedBox(width: 12),
              Expanded(child: _buildDetailBox(context, 'Asset Name', asset.name)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildDetailBox(context, 'Classification', asset.type.name.toUpperCase())),
              const SizedBox(width: 12),
              Expanded(child: _buildDetailBox(context, 'Status', asset.status.name.toUpperCase())),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildDetailBox(context, 'Manufacturer / Make', asset.make.isNotEmpty ? asset.make : '-')),
              const SizedBox(width: 12),
              Expanded(child: _buildDetailBox(context, 'Model', asset.model.isNotEmpty ? asset.model : '-')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildDetailBox(context, 'Serial Number', asset.serialNo.isNotEmpty ? asset.serialNo : '-')),
              const SizedBox(width: 12),
              Expanded(child: _buildDetailBox(context, 'Mfg Year', asset.manufacturingYear != null ? asset.manufacturingYear.toString() : '-')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildDetailBox(context, 'PO Number', asset.poNo != null && asset.poNo!.isNotEmpty ? asset.poNo! : '-')),
              const SizedBox(width: 12),
              Expanded(child: _buildDetailBox(context, 'RFID / NFC Tag ID', asset.rfidTag != null && asset.rfidTag!.isNotEmpty ? asset.rfidTag! : '-')),
            ],
          ),
          if (asset.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildDetailBox(context, 'Asset Description / Observations', asset.description),
          ],

          Divider(color: Theme.of(context).dividerColor, height: 32),
          _sectionHeader('Context & Operational Placement'),

          if (asset.status == AssetStatus.active) ...[
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Installed Parent Equipment', asset.masterEquipmentId.isNotEmpty ? asset.masterEquipmentId : 'Unassigned')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Site Installation Date', asset.installationDate != null ? _formatDate(asset.installationDate!) : '-')),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Spare Warehouse Location', asset.spareLocation != null && asset.spareLocation!.isNotEmpty ? asset.spareLocation! : 'Not Specified')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Spare Status', 'Available in Reserve')),
              ],
            ),
          ],

          const SizedBox(height: 14),
          const Text('Applicable / Compatible Parent Machines:', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          asset.applicableParentEquipmentIds != null && asset.applicableParentEquipmentIds!.isNotEmpty
              ? Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: asset.applicableParentEquipmentIds!
                      .map((pid) => Chip(
                            label: Text(pid, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            backgroundColor: Colors.cyan.withValues(alpha: 0.15),
                            side: const BorderSide(color: Colors.cyanAccent),
                          ))
                      .toList(),
                )
              : Text(
                  asset.status == AssetStatus.active ? 'No additional spare compatibility machines linked.' : 'No parent machines assigned for this equipment.',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
        ],
      ),
    );
  }

  // --- TAB 2: TECHNICAL SPECIFICATIONS (TAILORED PER ASSET TYPE) ---
  Widget _buildSpecsTab(BuildContext context, AssetModel asset) {
    final isMotor = asset.type == AssetType.motor;
    final isGearbox = asset.type == AssetType.gearbox;
    final isPump = asset.type == AssetType.pump;
    final isBrake = asset.type == AssetType.brake;
    final isActuator = asset.type == AssetType.actuator;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. MOTOR SPECIFICATIONS
          if (isMotor) ...[
            _sectionHeader('Motor Electrical Specifications'),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Motor Type / Technology', asset.motorType ?? 'Induction Motor')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Rated Power', asset.powerKw != null ? '${asset.powerKw} kW' : '-')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Rated Voltage', asset.voltage != null ? '${asset.voltage} V' : '-')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Full Load Current (FLC)', asset.fullLoadCurrent != null ? '${asset.fullLoadCurrent} A' : '-')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Rated Speed', asset.speedRpm != null ? '${asset.speedRpm} RPM' : '-')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Poles', asset.poles?.toString() ?? '-')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Frequency', asset.frequency != null ? '${asset.frequency} Hz' : '-')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Power Factor (cos φ)', asset.powerFactor?.toString() ?? '-')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Efficiency', asset.efficiency != null ? '${asset.efficiency}%' : '-')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Frame Size', asset.frameSize ?? '-')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Mounting Type', asset.mountingType ?? '-')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Grease Type / Grade', asset.greaseType ?? asset.specs?['greaseType'] ?? '-')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Duty Cycle', asset.dutyCycle ?? '-')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Insulation Class', asset.insulationClass ?? '-')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Efficiency Class', asset.efficiencyClass ?? '-')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'IP Rating (Enclosure)', asset.ipRating ?? '-')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDetailBox(
                    context,
                    'Coupling / Coupler',
                    (asset.couplingAvailable?.toUpperCase() == 'YES' || asset.couplingType != null && asset.couplingType!.isNotEmpty)
                        ? 'YES (${asset.couplingType ?? 'Installed'})'
                        : (asset.couplingAvailable?.toUpperCase() == 'NO' ? 'NO (Direct / None)' : '-'),
                  ),
                ),
              ],
            ),
          ]

          // 2. GEARBOX SPECIFICATIONS
          else if (isGearbox) ...[
            _sectionHeader('Gearbox Transmission Specifications'),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Gear Ratio', asset.gearRatio ?? asset.specs?['gearRatio'] ?? '-')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Input Power Rating', asset.powerKw != null ? '${asset.powerKw} kW' : (asset.specs?['inputPowerKw'] != null ? '${asset.specs!['inputPowerKw']} kW' : '-'))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Input Speed', asset.inputSpeedRpm != null ? '${asset.inputSpeedRpm} RPM' : (asset.specs?['inputSpeedRpm'] != null ? '${asset.specs!['inputSpeedRpm']} RPM' : '-'))),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Output Speed', asset.outputSpeedRpm != null ? '${asset.outputSpeedRpm} RPM' : (asset.specs?['outputSpeedRpm'] != null ? '${asset.specs!['outputSpeedRpm']} RPM' : '-'))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Oil Grade', asset.oilType ?? asset.specs?['oilType'] ?? '-')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Oil Sump Capacity', asset.oilCapacity != null ? '${asset.oilCapacity} L' : (asset.specs?['oilCapacity'] != null ? '${asset.specs!['oilCapacity']} L' : '-'))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Input Shaft Ø', asset.inputShaftMm != null ? '${asset.inputShaftMm} mm' : (asset.specs?['inputShaftMm'] != null ? '${asset.specs!['inputShaftMm']} mm' : '-'))),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Output Shaft Ø', asset.outputShaftMm != null ? '${asset.outputShaftMm} mm' : (asset.specs?['outputShaftMm'] != null ? '${asset.specs!['outputShaftMm']} mm' : '-'))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Lubrication Method', asset.lubricationMethod ?? asset.specs?['lubricationMethod'] ?? '-')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Mounting Orientation', asset.mountingOrientation ?? asset.specs?['mountingOrientation'] ?? '-')),
              ],
            ),
          ]

          // 3. PUMP SPECIFICATIONS
          else if (isPump) ...[
            _sectionHeader('Pump Hydraulic Specifications'),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Flow Rate / Capacity', asset.flowRate != null ? '${asset.flowRate} m³/hr' : (asset.specs?['flowRate'] != null ? '${asset.specs!['flowRate']} m³/hr' : '-'))),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Total Head', asset.head != null ? '${asset.head} m' : (asset.specs?['head'] != null ? '${asset.specs!['head']} m' : '-'))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Pump Speed', asset.speedRpm != null ? '${asset.speedRpm} RPM' : (asset.specs?['pumpSpeedRpm'] != null ? '${asset.specs!['pumpSpeedRpm']} RPM' : '-'))),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Shaft Power Required', asset.pumpPower != null ? '${asset.pumpPower} kW' : (asset.powerKw != null ? '${asset.powerKw} kW' : '-'))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Impeller Diameter', asset.impellerSize != null && asset.impellerSize!.isNotEmpty ? '${asset.impellerSize} mm' : (asset.specs?['impellerSize'] != null ? '${asset.specs!['impellerSize']} mm' : '-'))),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Seal Type', asset.sealType ?? asset.specs?['sealType'] ?? '-')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Suction Flange Ø', asset.suctionFlangeMm != null ? '${asset.suctionFlangeMm} mm' : (asset.specs?['suctionFlangeMm'] != null ? '${asset.specs!['suctionFlangeMm']} mm' : '-'))),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Discharge Flange Ø', asset.dischargeFlangeMm != null ? '${asset.dischargeFlangeMm} mm' : (asset.specs?['dischargeFlangeMm'] != null ? '${asset.specs!['dischargeFlangeMm']} mm' : '-'))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Casing Material', asset.casingMaterial ?? asset.specs?['casingMaterial'] ?? '-')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Grease / Lubricant', asset.greaseType ?? asset.specs?['greaseType'] ?? '-')),
              ],
            ),
          ]

          // 4. BRAKE SPECIFICATIONS
          else if (isBrake) ...[
            _sectionHeader('Brake Technical & Dimensional Specifications'),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Brake Technology / Type', asset.brakeType ?? 'Industrial Brake')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Voltage Supply', '${asset.voltageType ?? ''} ${asset.voltageRating != null ? '${asset.voltageRating!.toStringAsFixed(0)}V' : ''}'.trim())),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Thruster Capacity', asset.thrusterCapacityKg != null ? '${asset.thrusterCapacityKg!.toStringAsFixed(0)} kg' : '-')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Braking Torque', asset.brakingTorqueNm != null ? '${asset.brakingTorqueNm} Nm' : '-')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Drum / Disc Diameter', asset.drumDiaMm != null ? 'Ø ${asset.drumDiaMm!.toStringAsFixed(0)} mm' : '-')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Drum Width', asset.drumWidthMm != null ? '${asset.drumWidthMm!.toStringAsFixed(0)} mm' : '-')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Drum Installation', asset.drumInstallation ?? '-')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Mounting Bolts', '${asset.mountingBoltSize ?? '-'} (${asset.mountingBoltCount ?? '-'} Nos)')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Mounting Pitch (L x W)', '${asset.mountingLengthMm != null ? '${asset.mountingLengthMm!.toStringAsFixed(0)} mm' : '-'} x ${asset.mountingWidthMm != null ? '${asset.mountingWidthMm!.toStringAsFixed(0)} mm' : '-'}')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Shoe Lining Material', asset.brakeShoeLining ?? '-')),
              ],
            ),
          ]

          // 5. ACTUATOR SPECIFICATIONS
          else if (isActuator) ...[
            _sectionHeader('Actuator & Valve Automation Specifications'),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Actuator Type', asset.actuatorType ?? 'Actuator')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Torque / Thrust', asset.torqueOrThrust != null ? '${asset.torqueOrThrust} Nm/kN' : '-')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Operating Time', asset.operatingTimeSeconds != null ? '${asset.operatingTimeSeconds} s' : '-')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Control Signal', asset.controlSignal ?? '-')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Valve Type & Size', '${asset.valveType ?? '-'} (${asset.valveSize ?? '-'})')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Mounting Flange (ISO)', asset.valveFlangeStandard ?? '-')),
              ],
            ),
          ],

          // Common Bearing Specifications
          if (isMotor || isGearbox || isPump) ...[
            Divider(color: Theme.of(context).dividerColor, height: 32),
            _sectionHeader('Bearing Details'),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Drive End (DE) Bearing', asset.bearingDE ?? '-')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Non-Drive End (NDE) Bearing', asset.bearingNDE ?? '-')),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // --- TAB 3: DIAGNOSTICS & HEALTH ---
  Widget _buildHealthTab(BuildContext context, AssetModel asset) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Diagnostic Test Logs', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 15)),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LogDiagnosticTestPage(asset: asset),
                    ),
                  );
                },
                icon: const Icon(Icons.add_chart, size: 16),
                label: const Text('Log Test', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<HealthLogModel>>(
            stream: FirestoreService().getHealthLogsStream(asset.id, tagNo: asset.tagNo),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: PulseLoading(size: 40));
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('Error loading test logs: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),
                );
              }
              final logs = snapshot.data ?? [];
              if (logs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_turned_in_outlined, size: 48, color: Theme.of(context).disabledColor),
                      const SizedBox(height: 16),
                      Text('No diagnostic health logs recorded yet.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LogDiagnosticTestPage(asset: asset),
                            ),
                          );
                        },
                        child: const Text('Record First Test Log'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  return Card(
                    color: Theme.of(context).cardColor.withValues(alpha: 0.3),
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ExpansionTile(
                      leading: _buildHealthBadge(
                        log.healthStatus == 'healthy'
                            ? AssetHealthStatus.healthy
                            : log.healthStatus == 'warning'
                                ? AssetHealthStatus.warning
                                : AssetHealthStatus.critical,
                      ),
                      title: Text('Test Run: ${_formatDate(log.testDate)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      subtitle: Text('By ${log.testedBy} • Status: ${log.healthStatus.toUpperCase()}', style: const TextStyle(fontSize: 11)),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (log.remarks.isNotEmpty) ...[
                                Text('Remarks: ${log.remarks}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontStyle: FontStyle.italic)),
                                const Divider(),
                              ],
                              if (asset.type == AssetType.motor) ...[
                                if (log.noLoadCurrent != null) _buildLogItem('No-Load Current', '${log.noLoadCurrent} A'),
                                if (log.windingResistance != null)
                                  _buildLogItem('Winding Resistance',
                                      'R-Y: ${log.windingResistance!['R-Y'] ?? "-"} Ω, Y-B: ${log.windingResistance!['Y-B'] ?? "-"} Ω, R-B: ${log.windingResistance!['R-B'] ?? "-"} Ω'),
                                if (log.insulationResistance != null) ...[
                                  _buildLogItem('IR Phase-Phase',
                                      'R-Y: ${log.insulationResistance!['R-Y'] ?? "-"} MΩ, Y-B: ${log.insulationResistance!['Y-B'] ?? "-"} MΩ, B-R: ${log.insulationResistance!['B-R'] ?? "-"} MΩ'),
                                  _buildLogItem('IR Phase-Earth',
                                      'R-E: ${log.insulationResistance!['R-E'] ?? "-"} MΩ, Y-E: ${log.insulationResistance!['Y-E'] ?? "-"} MΩ, B-E: ${log.insulationResistance!['B-E'] ?? "-"} MΩ'),
                                ],
                                if (log.polarizationIndex != null) _buildLogItem('Polarization Index (PI)', '${log.polarizationIndex}'),
                              ],
                              if (log.vibration != null) ...[
                                _buildLogItem('DE Vibration',
                                    'H: ${log.vibration!['DE_H'] ?? "-"} mm/s, V: ${log.vibration!['DE_V'] ?? "-"} mm/s, A: ${log.vibration!['DE_A'] ?? "-"} mm/s'),
                                _buildLogItem('NDE Vibration',
                                    'H: ${log.vibration!['NDE_H'] ?? "-"} mm/s, V: ${log.vibration!['NDE_V'] ?? "-"} mm/s, A: ${log.vibration!['NDE_A'] ?? "-"} mm/s'),
                                if (log.vibration!['G_Value'] != null) _buildLogItem('Acceleration (G-Value)', '${log.vibration!['G_Value']} G'),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- TAB 4: HISTORY ---
  Widget _buildHistoryTab(BuildContext context, AssetModel asset) {
    return StreamBuilder<List<FaultLogModel>>(
      stream: FirestoreService().getFaultLogsStream(asset.masterEquipmentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: PulseLoading(size: 40));
        }

        final logs = snapshot.data ?? [];
        final assetLogs = logs.where((FaultLogModel l) => l.assetId == asset.id).toList();

        if (assetLogs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 48, color: Theme.of(context).disabledColor),
                const SizedBox(height: 16),
                Text('No fault or replacement history found.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: assetLogs.length,
          itemBuilder: (context, index) {
            final log = assetLogs[index];
            final dateStr = _formatDate(log.reportedAt);

            return _buildHistoryItem(
              context,
              log.category.name.toUpperCase(),
              '${log.cause}\n${log.actionTaken}',
              dateStr,
              status: log.status.name,
            );
          },
        );
      },
    );
  }

  // --- Helpers ---
  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.accent,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
          fontSize: 11.5,
        ),
      ),
    );
  }

  Widget _buildDetailBox(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 13.5)),
        ],
      ),
    );
  }

  Widget _buildLogItem(String title, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$title: ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          Expanded(child: Text(val, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, String title, String subtitle, String date, {String? status}) {
    Color statusColor = AppColors.success;
    if (status == 'open') statusColor = AppColors.error;
    if (status == 'in_progress') statusColor = AppColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Icon(status == 'open' ? Icons.warning_rounded : Icons.check_circle_outline, color: statusColor, size: 16),
              ),
              Container(width: 2, height: 36, color: Theme.of(context).dividerColor),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(date, style: TextStyle(color: Theme.of(context).disabledColor, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showReplaceWithSpareDialog(BuildContext context, AssetModel asset) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('assets')
        .where('type', isEqualTo: asset.type.name)
        .where('status', isEqualTo: AssetStatus.spare.name)
        .get();

    final spares = querySnapshot.docs.map((doc) => AssetModel.fromMap(doc.data(), doc.id)).toList();

    // Sort spares so that assets specifically mapped to this machine appear at the top
    spares.sort((a, b) {
      final aMatch = a.applicableParentEquipmentIds?.contains(asset.masterEquipmentId) ?? false;
      final bMatch = b.applicableParentEquipmentIds?.contains(asset.masterEquipmentId) ?? false;
      if (aMatch && !bMatch) return -1;
      if (!aMatch && bMatch) return 1;
      return a.tagNo.compareTo(b.tagNo);
    });

    if (!context.mounted) return;

    if (spares.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text('No Spares Available', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
          content: Text('There are no spare ${asset.type.name}s registered in the inventory.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    AssetModel? selectedSpare = spares.isNotEmpty ? spares.first : null;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: Text('Replace with Spare', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select a compatible spare ${asset.type.name} to deploy at ${asset.masterEquipmentId}:',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<AssetModel>(
                    isExpanded: true,
                    dropdownColor: Theme.of(context).colorScheme.surface,
                    value: selectedSpare,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: const InputDecoration(
                      labelText: 'Select Spare Asset',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    items: spares.map((s) {
                      final isDirectMatch = s.applicableParentEquipmentIds?.contains(asset.masterEquipmentId) ?? false;
                      return DropdownMenuItem<AssetModel>(
                        value: s,
                        child: Text(
                          '${s.tagNo} - ${s.name} ${isDirectMatch ? "⭐ [Assigned Spare]" : ""}',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(fontWeight: isDirectMatch ? FontWeight.bold : FontWeight.normal, fontSize: 12),
                        ),
                      );
                    }).toList(),
                    selectedItemBuilder: (context) {
                      return spares.map((s) {
                        return Text(
                          '${s.tagNo} - ${s.name}',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        );
                      }).toList();
                    },
                    onChanged: (v) {
                      setDialogState(() {
                        selectedSpare = v;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Note: Upon confirmation, the current asset (${asset.tagNo}) will transition to "UNDER MAINTENANCE" and retain its link to ${asset.masterEquipmentId} for future redeployment. The spare (${selectedSpare?.tagNo ?? "..."}) will become ACTIVE at this machine.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: selectedSpare == null
                      ? null
                      : () async {
                          final db = FirebaseFirestore.instance;
                          final batch = db.batch();

                          final currentRef = db.collection('assets').doc(asset.id);
                          final spareRef = db.collection('assets').doc(selectedSpare!.id);

                          // 1. Move current asset to underMaintenance and ensure previous parent is kept in its applicableParentEquipmentIds pool!
                          final Set<String> oldAssetParents = {
                            ...?asset.applicableParentEquipmentIds,
                            if (asset.masterEquipmentId.isNotEmpty) asset.masterEquipmentId,
                          };

                          batch.update(currentRef, {
                            'status': AssetStatus.underMaintenance.name,
                            'masterEquipmentId': '',
                            'applicableParentEquipmentIds': oldAssetParents.toList(),
                            'spareLocation': 'Electrical Maintenance Workshop',
                            'modifiedAt': FieldValue.serverTimestamp(),
                            'modifiedBy': AuthService().currentUser?.email ?? 'Tech',
                          });

                          // 2. Move spare to active and set parent machine
                          final Set<String> newAssetParents = {
                            ...?selectedSpare!.applicableParentEquipmentIds,
                            if (asset.masterEquipmentId.isNotEmpty) asset.masterEquipmentId,
                          };

                          final Map<String, dynamic> spareUpdates = {
                            'status': AssetStatus.active.name,
                            'masterEquipmentId': asset.masterEquipmentId,
                            'applicableParentEquipmentIds': newAssetParents.toList(),
                            'installationDate': FieldValue.serverTimestamp(),
                            'modifiedAt': FieldValue.serverTimestamp(),
                            'modifiedBy': AuthService().currentUser?.email ?? 'Tech',
                            'spareLocation': FieldValue.delete(),
                          };

                          batch.update(spareRef, spareUpdates);

                          await batch.commit();

                          await FirestoreService().logActivity(
                            userId: AuthService().currentUser?.uid ?? 'unknown',
                            action: 'Replace Asset with Spare',
                            details: 'Replaced asset ${asset.tagNo} with spare ${selectedSpare!.tagNo} at equipment location ${asset.masterEquipmentId}',
                          );

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Asset replaced with ${selectedSpare!.tagNo} successfully!'), backgroundColor: AppColors.success),
                            );
                            Navigator.pop(dialogCtx);
                            Navigator.pop(context);
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                  child: const Text('Confirm Swap', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
