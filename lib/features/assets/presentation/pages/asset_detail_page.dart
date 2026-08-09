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
import '../../data/models/fault_log_model.dart';

class AssetDetailPage extends StatefulWidget {
  final AssetModel asset;

  const AssetDetailPage({super.key, required this.asset});

  @override
  State<AssetDetailPage> createState() => _AssetDetailPageState();
}

class _AssetDetailPageState extends State<AssetDetailPage> {
  AssetModel get asset => widget.asset;
  
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
      
      final meDoc = await FirebaseFirestore.instance
          .collection('master_equipments')
          .doc(widget.asset.masterEquipmentId)
          .get();
      if (meDoc.exists && meDoc.data() != null) {
        final data = meDoc.data()!;
        _assetPlantId = data['plantId'] as String?;
        _assetUnitId = data['unitId'] as String?;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.asset.tagNo),
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
                    masterEquipmentId: widget.asset.masterEquipmentId,
                    masterEquipmentName: 'Equipment ${widget.asset.masterEquipmentId}',
                    assetId: widget.asset.id,
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
                      asset: widget.asset,
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
              _buildHeader(context),
              
              const SizedBox(height: 24),

              // 2. Tabbed Details
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GlassContainer(
                  width: double.infinity,
                  height: 600, // Taller for more specs
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
                              _buildIdentityTab(context),
                              _buildSpecsTab(context),
                              _buildHealthTab(context),
                              _buildHistoryTab(context),
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
  }

  Widget _buildHeader(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Text(
            asset.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               _buildStatusBadge(asset.status),
               const SizedBox(width: 12),
               _buildHealthBadge(asset.healthStatus),
            ],
          ),
          const SizedBox(height: 16),
          if (asset.status == AssetStatus.active) ...[
            TextButton.icon(
              onPressed: () => _showReplaceWithSpareDialog(context),
              icon: const Icon(Icons.swap_horiz, color: AppColors.accent),
              label: const Text('Replace with Spare', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Quick Context
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               Icon(Icons.place, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 16),
               const SizedBox(width: 4),
               Text(asset.masterEquipmentId.isNotEmpty ? asset.masterEquipmentId : 'Unassigned', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
               const SizedBox(width: 16),
               Icon(Icons.sell, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 16),
               const SizedBox(width: 4),
               Text(asset.make, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatusBadge(AssetStatus status) {
    Color color;
    switch (status) {
      case AssetStatus.active: color = AppColors.success; break;
      case AssetStatus.underMaintenance: color = AppColors.warning; break;
      case AssetStatus.scrapped: color = AppColors.error; break;
      case AssetStatus.spare: color = Colors.grey; break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildHealthBadge(AssetHealthStatus status) {
    final service = HealthService();
    final color = service.getHealthColor(status);
    final label = service.getHealthLabel(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.monitor_heart_outlined, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('General Identity'),
          Row(
            children: [
              Expanded(child: _buildDetailBox(context, 'Tag No', asset.tagNo)),
              const SizedBox(width: 12),
              Expanded(child: _buildDetailBox(context, 'Serial No', asset.serialNo)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildDetailBox(context, 'Make', asset.make)),
              const SizedBox(width: 12),
              Expanded(child: _buildDetailBox(context, 'Model', asset.model)),
            ],
          ),
          if (asset.rfidTag != null || asset.manufacturingYear != null || asset.poNo != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (asset.poNo != null) Expanded(child: _buildDetailBox(context, 'PO Number', asset.poNo!)) else const Expanded(child: SizedBox()),
                if (asset.poNo != null && (asset.rfidTag != null || asset.manufacturingYear != null)) const SizedBox(width: 12),
                if (asset.rfidTag != null) Expanded(child: _buildDetailBox(context, 'RFID', asset.rfidTag!)) else if (asset.manufacturingYear != null) Expanded(child: _buildDetailBox(context, 'Mfg Year', asset.manufacturingYear.toString())) else const Expanded(child: SizedBox()),
              ],
            ),
            if (asset.rfidTag != null && asset.manufacturingYear != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildDetailBox(context, 'Mfg Year', asset.manufacturingYear.toString())),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ]
          ],
          
          Divider(color: Theme.of(context).dividerColor, height: 32),
          _sectionHeader('Context'),
          Row(
            children: [
              if (asset.masterEquipmentId.isNotEmpty) 
                Expanded(child: _buildDetailBox(context, 'Parent Equipment', asset.masterEquipmentId)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildDetailBox(context, 'Asset Type', asset.type.name.toUpperCase())),
              const SizedBox(width: 12),
              Expanded(child: _buildDetailBox(context, 'Criticality', asset.isCritical ? 'CRITICAL' : 'Normal')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpecsTab(BuildContext context) {
    final isMotor = asset.type == AssetType.motor;
    final isGearbox = asset.type == AssetType.gearbox;
    final isPump = asset.type == AssetType.pump;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMotor) ...[
            _sectionHeader('Motor Technical Specifications'),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Power', asset.powerKw != null ? '${asset.powerKw} KW' : '-')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Voltage', asset.voltage != null ? '${asset.voltage} V' : '-')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'FLA / Rated Current', asset.fullLoadCurrent != null ? '${asset.fullLoadCurrent} A' : '-')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Speed', asset.speedRpm != null ? '${asset.speedRpm} RPM' : '-')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Frequency', asset.frequency != null ? '${asset.frequency} Hz' : '-')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Poles', asset.poles?.toString() ?? '-')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Power Factor (PF)', asset.powerFactor?.toString() ?? '-')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Efficiency', asset.efficiency != null ? '${asset.efficiency}%' : '-')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Frame Size', asset.frameSize ?? '-')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Mounting', asset.mountingType ?? '-')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'DE Bearing', asset.bearingDE ?? '-')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'NDE Bearing', asset.bearingNDE ?? '-')),
              ],
            ),
            if (asset.specs?['greaseType'] != null) ...[
              const SizedBox(height: 12),
              _buildDetailBox(context, 'Grease Type / Grade', asset.specs!['greaseType']),
            ],
          ],
          
          if (isGearbox) ...[
            _sectionHeader('Gearbox Technical Specifications'),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Power Rating', asset.powerKw != null ? '${asset.powerKw} KW' : '-')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Gear Ratio (i)', asset.specs?['gearRatio']?.toString() ?? '-')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Input Speed', asset.speedRpm != null ? '${asset.speedRpm} RPM' : '-')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Oil Capacity', asset.specs?['oilCapacity'] != null ? '${asset.specs!['oilCapacity']} L' : '-')),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailBox(context, 'Recommended Oil Type', asset.specs?['oilType'] ?? '-'),
            const SizedBox(height: 12),
            _buildDetailBox(context, 'Mounting', asset.mountingType ?? '-'),
          ],
          
          if (isPump) ...[
            _sectionHeader('Pump Technical Specifications'),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Power Required', asset.specs?['pumpPower'] != null ? '${asset.specs!['pumpPower']} KW' : '-')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Speed', asset.speedRpm != null ? '${asset.speedRpm} RPM' : '-')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Flow Rate', asset.specs?['flowRate'] != null ? '${asset.specs!['flowRate']} m³/hr' : '-')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Head', asset.specs?['head'] != null ? '${asset.specs!['head']} meters' : '-')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDetailBox(context, 'Impeller Diameter', asset.specs?['impellerSize'] != null ? '${asset.specs!['impellerSize']} mm' : '-')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailBox(context, 'Grease Type', asset.specs?['greaseType'] ?? '-')),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHealthTab(BuildContext context) {
    return Column(
      children: [
        // Action Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Historical Diagnostic Tests', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
              ElevatedButton.icon(
                onPressed: () => _showLogTestDialog(context),
                icon: const Icon(Icons.add_chart, size: 18),
                label: const Text('Log Test'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: StreamBuilder<List<HealthLogModel>>(
            stream: FirestoreService().getHealthLogsStream(asset.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: PulseLoading(size: 40));
              }
              final logs = snapshot.data ?? [];
              if (logs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_turned_in_outlined, size: 48, color: Theme.of(context).disabledColor),
                      const SizedBox(height: 16),
                      Text('No diagnostic health logs found.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => _showLogTestDialog(context),
                        child: const Text('Record First Test Log'),
                      )
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
                        log.healthStatus == 'healthy' ? AssetHealthStatus.healthy :
                        log.healthStatus == 'warning' ? AssetHealthStatus.warning : AssetHealthStatus.critical
                      ),
                      title: Text('Test Run: ${_formatDate(log.testDate)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('By ${log.testedBy} • Status: ${log.healthStatus.toUpperCase()}', style: const TextStyle(fontSize: 12)),
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
                                if (log.noLoadCurrent != null)
                                  _buildLogItem('No-Load Current', '${log.noLoadCurrent} A'),
                                if (log.windingResistance != null)
                                  _buildLogItem('Winding Resistance', 'R-Y: ${log.windingResistance!['R-Y'] ?? "-"} Ω, Y-B: ${log.windingResistance!['Y-B'] ?? "-"} Ω, R-B: ${log.windingResistance!['R-B'] ?? "-"} Ω'),
                                if (log.insulationResistance != null) ...[
                                  _buildLogItem('IR Phase-Phase', 'R-Y: ${log.insulationResistance!['R-Y'] ?? "-"} MΩ, Y-B: ${log.insulationResistance!['Y-B'] ?? "-"} MΩ, B-R: ${log.insulationResistance!['B-R'] ?? "-"} MΩ'),
                                  _buildLogItem('IR Phase-Earth', 'R-E: ${log.insulationResistance!['R-E'] ?? "-"} MΩ, Y-E: ${log.insulationResistance!['Y-E'] ?? "-"} MΩ, B-E: ${log.insulationResistance!['B-E'] ?? "-"} MΩ'),
                                ],
                                if (log.polarizationIndex != null)
                                  _buildLogItem('Polarization Index (PI)', '${log.polarizationIndex}'),
                              ],
                              if (log.vibration != null) ...[
                                _buildLogItem('DE Vibration', 'H: ${log.vibration!['DE_H'] ?? "-"} mm/s, V: ${log.vibration!['DE_V'] ?? "-"} mm/s, A: ${log.vibration!['DE_A'] ?? "-"} mm/s'),
                                _buildLogItem('NDE Vibration', 'H: ${log.vibration!['NDE_H'] ?? "-"} mm/s, V: ${log.vibration!['NDE_V'] ?? "-"} mm/s, A: ${log.vibration!['NDE_A'] ?? "-"} mm/s'),
                                if (log.vibration!['G_Value'] != null)
                                  _buildLogItem('Acceleration (G-Value)', '${log.vibration!['G_Value']} G'),
                              ],
                            ],
                          ),
                        )
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _showLogTestDialog(BuildContext context) {
    final testedByController = TextEditingController(text: AuthService().currentUser?.displayName ?? 'Operator');
    final remarksController = TextEditingController();
    
    // Motor specific
    final noLoadCurrentController = TextEditingController();
    final resRYController = TextEditingController();
    final resYBController = TextEditingController();
    final resRBController = TextEditingController();
    
    final irRyController = TextEditingController();
    final irYbController = TextEditingController();
    final irBrController = TextEditingController();
    final irReController = TextEditingController();
    final irYeController = TextEditingController();
    final irBeController = TextEditingController();
    
    final piController = TextEditingController();
    
    // Vibration
    final vibDeHController = TextEditingController();
    final vibDeVController = TextEditingController();
    final vibDeAController = TextEditingController();
    final vibNdeHController = TextEditingController();
    final vibNdeVController = TextEditingController();
    final vibNdeAController = TextEditingController();
    final vibGController = TextEditingController();
    
    String selectedStatus = 'healthy';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: Text('Log Diagnostic Test Run', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: testedByController,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      decoration: const InputDecoration(labelText: 'Tested By', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      value: selectedStatus,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      decoration: const InputDecoration(labelText: 'Overall Health Status', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'healthy', child: Text('HEALTHY')),
                        DropdownMenuItem(value: 'warning', child: Text('WARNING')),
                        DropdownMenuItem(value: 'critical', child: Text('CRITICAL')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() {
                            selectedStatus = v;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: remarksController,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      decoration: const InputDecoration(labelText: 'Remarks / Comments', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    
                    if (asset.type == AssetType.motor) ...[
                      const Divider(),
                      const Text('Winding Resistance (Ω)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: resRYController, style: TextStyle(color: Theme.of(context).colorScheme.onSurface), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'R-Y'))),
                          const SizedBox(width: 8),
                          Expanded(child: TextField(controller: resYBController, style: TextStyle(color: Theme.of(context).colorScheme.onSurface), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Y-B'))),
                          const SizedBox(width: 8),
                          Expanded(child: TextField(controller: resRBController, style: TextStyle(color: Theme.of(context).colorScheme.onSurface), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'R-B'))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Insulation Resistance / IR (MΩ)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: irRyController, style: TextStyle(color: Theme.of(context).colorScheme.onSurface), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'R-Y'))),
                          const SizedBox(width: 8),
                          Expanded(child: TextField(controller: irYbController, style: TextStyle(color: Theme.of(context).colorScheme.onSurface), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Y-B'))),
                          const SizedBox(width: 8),
                          Expanded(child: TextField(controller: irBrController, style: TextStyle(color: Theme.of(context).colorScheme.onSurface), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'B-R'))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: irReController, style: TextStyle(color: Theme.of(context).colorScheme.onSurface), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'R-E'))),
                          const SizedBox(width: 8),
                          Expanded(child: TextField(controller: irYeController, style: TextStyle(color: Theme.of(context).colorScheme.onSurface), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Y-E'))),
                          const SizedBox(width: 8),
                          Expanded(child: TextField(controller: irBeController, style: TextStyle(color: Theme.of(context).colorScheme.onSurface), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'B-E'))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: noLoadCurrentController, style: TextStyle(color: Theme.of(context).colorScheme.onSurface), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'No-Load Current (A)'))),
                          const SizedBox(width: 12),
                          Expanded(child: TextField(controller: piController, style: TextStyle(color: Theme.of(context).colorScheme.onSurface), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'PI Value'))),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    const Divider(),
                    const Text('Vibration (mm/s)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    const Text('Drive End (DE)', style: TextStyle(fontSize: 11)),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: vibDeHController, style: TextStyle(color: Theme.of(context).colorScheme.onSurface), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'H'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: vibDeVController, style: TextStyle(color: Theme.of(context).colorScheme.onSurface), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'V'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: vibDeAController, style: TextStyle(color: Theme.of(context).colorScheme.onSurface), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'A'))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Non-Drive End (NDE)', style: TextStyle(fontSize: 11)),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: vibNdeHController, style: TextStyle(color: Theme.of(context).colorScheme.onSurface), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'H'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: vibNdeVController, style: TextStyle(color: Theme.of(context).colorScheme.onSurface), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'V'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: vibNdeAController, style: TextStyle(color: Theme.of(context).colorScheme.onSurface), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'A'))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: vibGController,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Acceleration (G-Value)', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    // Create health log model
                    final windingRes = {
                      if (resRYController.text.isNotEmpty) 'R-Y': double.tryParse(resRYController.text),
                      if (resYBController.text.isNotEmpty) 'Y-B': double.tryParse(resYBController.text),
                      if (resRBController.text.isNotEmpty) 'R-B': double.tryParse(resRBController.text),
                    };
                    
                    final irMap = {
                      if (irRyController.text.isNotEmpty) 'R-Y': double.tryParse(irRyController.text),
                      if (irYbController.text.isNotEmpty) 'Y-B': double.tryParse(irYbController.text),
                      if (irBrController.text.isNotEmpty) 'B-R': double.tryParse(irBrController.text),
                      if (irReController.text.isNotEmpty) 'R-E': double.tryParse(irReController.text),
                      if (irYeController.text.isNotEmpty) 'Y-E': double.tryParse(irYeController.text),
                      if (irBeController.text.isNotEmpty) 'B-E': double.tryParse(irBeController.text),
                    };
                    
                    final vibMap = {
                      if (vibDeHController.text.isNotEmpty) 'DE_H': double.tryParse(vibDeHController.text),
                      if (vibDeVController.text.isNotEmpty) 'DE_V': double.tryParse(vibDeVController.text),
                      if (vibDeAController.text.isNotEmpty) 'DE_A': double.tryParse(vibDeAController.text),
                      if (vibNdeHController.text.isNotEmpty) 'NDE_H': double.tryParse(vibNdeHController.text),
                      if (vibNdeVController.text.isNotEmpty) 'NDE_V': double.tryParse(vibNdeVController.text),
                      if (vibNdeAController.text.isNotEmpty) 'NDE_A': double.tryParse(vibNdeAController.text),
                      if (vibGController.text.isNotEmpty) 'G_Value': double.tryParse(vibGController.text),
                    };
                    
                    final log = HealthLogModel(
                      id: 'new',
                      assetId: asset.id,
                      testDate: DateTime.now(),
                      testedBy: testedByController.text,
                      noLoadCurrent: double.tryParse(noLoadCurrentController.text),
                      windingResistance: windingRes.isNotEmpty ? windingRes : null,
                      insulationResistance: irMap.isNotEmpty ? irMap : null,
                      polarizationIndex: double.tryParse(piController.text),
                      vibration: vibMap.isNotEmpty ? vibMap : null,
                      remarks: remarksController.text,
                      healthStatus: selectedStatus,
                    );
                    
                    // Save to DB
                    await FirestoreService().saveHealthLog(log);
                    
                    // Update asset status
                    final hStatus = selectedStatus == 'healthy' ? AssetHealthStatus.healthy :
                                   selectedStatus == 'warning' ? AssetHealthStatus.warning : AssetHealthStatus.critical;
                                   
                    final updatedAsset = AssetModel(
                      id: asset.id,
                      masterEquipmentId: asset.masterEquipmentId,
                      tagNo: asset.tagNo,
                      name: asset.name,
                      make: asset.make,
                      model: asset.model,
                      serialNo: asset.serialNo,
                      poNo: asset.poNo,
                      manufacturingYear: asset.manufacturingYear,
                      imageUrl: asset.imageUrl,
                      rfidTag: asset.rfidTag,
                      type: asset.type,
                      status: asset.status,
                      specs: asset.specs,
                      powerKw: asset.powerKw,
                      voltage: asset.voltage,
                      fullLoadCurrent: asset.fullLoadCurrent,
                      noLoadCurrent: log.noLoadCurrent ?? asset.noLoadCurrent,
                      frequency: asset.frequency,
                      speedRpm: asset.speedRpm,
                      poles: asset.poles,
                      frameSize: asset.frameSize,
                      mountingType: asset.mountingType,
                      powerFactor: asset.powerFactor,
                      efficiency: asset.efficiency,
                      bearingDE: asset.bearingDE,
                      bearingNDE: asset.bearingNDE,
                      windingResistance: log.windingResistance ?? asset.windingResistance,
                      insulationResistance: log.insulationResistance ?? asset.insulationResistance,
                      polarizationIndex: log.polarizationIndex ?? asset.polarizationIndex,
                      vibration: log.vibration ?? asset.vibration,
                      isCritical: asset.isCritical,
                      installationDate: asset.installationDate,
                      healthStatus: hStatus,
                      lastPulseTime: DateTime.now(),
                      createdAt: asset.createdAt,
                      createdBy: asset.createdBy,
                      modifiedAt: DateTime.now(),
                      modifiedBy: AuthService().currentUser?.uid,
                    );
                    
                    await FirestoreService().saveAsset(updatedAsset);
                    
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Diagnostic log recorded successfully!'), backgroundColor: AppColors.success));
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLight),
                  child: const Text('Save Test', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryTab(BuildContext context) {
    return StreamBuilder<List<FaultLogModel>>(
      stream: FirestoreService().getFaultLogsStream(asset.masterEquipmentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: PulseLoading(size: 40));
        }

        final logs = snapshot.data ?? [];
        // Filter for specific asset if it was logged against this sub-component
        final assetLogs = logs.where((FaultLogModel l) => l.assetId == asset.id).toList();

        if (assetLogs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 48, color: Theme.of(context).disabledColor),
                const SizedBox(height: 16),
                Text('No fault history found.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: assetLogs.length,
          itemBuilder: (context, index) {
            final log = assetLogs[index];
            final dateStr = log.reportedAt.toString().split(' ')[0];
            
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
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.accent, 
          fontWeight: FontWeight.bold, 
          letterSpacing: 1.1,
          fontSize: 12,
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }



  Widget _buildHistoryItem(BuildContext context, String title, String subtitle, String date, {String? status}) {
    Color statusColor = AppColors.success;
    if (status == 'open') statusColor = AppColors.error;
    if (status == 'in_progress') statusColor = AppColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
                child: Icon(
                  status == 'open' ? Icons.warning_rounded : Icons.check_circle_outline, 
                  color: statusColor, 
                  size: 18
                ),
              ),
              // Timeline line
              Container(width: 2, height: 40, color: Theme.of(context).dividerColor),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
                    Text(date, style: TextStyle(color: Theme.of(context).disabledColor, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showReplaceWithSpareDialog(BuildContext context) async {
    // 1. Fetch available spares of the same type
    final querySnapshot = await FirebaseFirestore.instance.collection('assets')
        .where('type', isEqualTo: asset.type.name)
        .where('status', isEqualTo: AssetStatus.spare.name)
        .get();

    final spares = querySnapshot.docs.map((doc) => AssetModel.fromMap(doc.data(), doc.id)).toList();

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

    AssetModel? selectedSpare;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: Text('Replace with Spare', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select a compatible spare ${asset.type.name} to deploy:', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<AssetModel>(
                    dropdownColor: Theme.of(context).colorScheme.surface,
                    value: selectedSpare,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: const InputDecoration(labelText: 'Select Spare Asset', border: OutlineInputBorder()),
                    items: spares.map((s) {
                      return DropdownMenuItem<AssetModel>(
                        value: s,
                        child: Text('${s.tagNo} - ${s.make} (${s.model})'),
                      );
                    }).toList(),
                    onChanged: (v) {
                      setDialogState(() {
                        selectedSpare = v;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Note: Upon confirmation, the current asset (${asset.tagNo}) will be marked as "Under Maintenance" and removed from this location. The selected spare will take its place.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: selectedSpare == null ? null : () async {
                    // Start transaction
                    final db = FirebaseFirestore.instance;
                    final batch = db.batch();

                    final currentRef = db.collection('assets').doc(asset.id);
                    final spareRef = db.collection('assets').doc(selectedSpare!.id);

                    // 1. Move current asset to underMaintenance and clear parent
                    batch.update(currentRef, {
                      'status': AssetStatus.underMaintenance.name,
                      'masterEquipmentId': '', // unassigned
                      'modifiedAt': FieldValue.serverTimestamp(),
                      'modifiedBy': AuthService().currentUser?.uid,
                    });

                    // 2. Move spare to active and set parent
                    batch.update(spareRef, {
                      'status': AssetStatus.active.name,
                      'masterEquipmentId': asset.masterEquipmentId,
                      'modifiedAt': FieldValue.serverTimestamp(),
                      'modifiedBy': AuthService().currentUser?.uid,
                    });

                    // Commit batch
                    await batch.commit();

                    // Log activity
                    await FirestoreService().logActivity(
                      userId: AuthService().currentUser?.uid ?? 'unknown',
                      action: 'Replace Asset with Spare',
                      details: 'Replaced asset ${asset.tagNo} with spare ${selectedSpare!.tagNo} at equipment location ${asset.masterEquipmentId}',
                    );

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Asset replaced with ${selectedSpare!.tagNo} successfully!'), backgroundColor: AppColors.success),
                      );
                      Navigator.pop(context); // close dialog
                      Navigator.pop(context); // go back to assets list since current asset is now unassigned
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                  child: const Text('Confirm Swap', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
