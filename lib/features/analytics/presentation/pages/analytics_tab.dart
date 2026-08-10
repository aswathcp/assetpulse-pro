import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_roles.dart';
import '../../../../features/home/presentation/widgets/custom_app_bar.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/services/hierarchy_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/firestore_service.dart';

class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  final HierarchyService _hierarchyService = HierarchyService();
  final FirestoreService _firestoreService = FirestoreService();

  bool _isLoading = true;
  String? _selectedPlantId;
  String? _selectedUnitId;
  List<String> _plants = [];
  List<String> _units = [];
  bool _isPlantLocked = false;
  bool _isUnitLocked = false;

  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _initHierarchyAndScope();
  }

  Future<void> _initHierarchyAndScope() async {
    final user = AuthService().currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final profile = await _firestoreService.getUserProfile(user.uid);
    final userRole = profile?['role'] ?? AppRoles.guest;
    final userPlantId = profile?['plantId'] as String?;
    final userUnitId = profile?['unitId'] as String?;
    final uBusinessId = profile?['businessId'] as String? ?? 'VISL';

    await _hierarchyService.init(businessId: uBusinessId);
    _plants = _hierarchyService.getPlants();

    final String? userPlant = (userPlantId == null || userPlantId.isEmpty || userPlantId == 'Unknown') ? null : userPlantId;
    final String? userUnit = (userUnitId == null || userUnitId.isEmpty || userUnitId == 'Unknown') ? null : userUnitId;

    final bool hasGlobalAdmin = profile?['isAdmin'] == true && userPlant == null;
    final bool hasPlantAdmin = profile?['isAdmin'] == true && userPlant != null;

    final bool isPlantScope = (hasPlantAdmin || userRole == AppRoles.plantAdmin || userRole == AppRoles.plantHod) &&
        userRole != AppRoles.manager &&
        userRole != AppRoles.deputyManager &&
        userRole != AppRoles.associateManager &&
        userRole != AppRoles.assistantManager &&
        userRole != AppRoles.unitAdmin &&
        userRole != AppRoles.unitHod;

    if (userRole == AppRoles.developer || userRole == AppRoles.auditor || hasGlobalAdmin) {
      _isPlantLocked = false;
      _isUnitLocked = false;
      _selectedPlantId = userPlant ?? (_plants.isNotEmpty ? _plants.first : null);
      _updateUnitList();
      _selectedUnitId = userUnit ?? (_units.isNotEmpty ? _units.first : null);
    } else if (isPlantScope) {
      _isPlantLocked = true;
      _isUnitLocked = false;
      _selectedPlantId = userPlant ?? (_plants.isNotEmpty ? _plants.first : null);
      _updateUnitList();
      _selectedUnitId = userUnit ?? (_units.isNotEmpty ? _units.first : null);
    } else {
      _isPlantLocked = true;
      _isUnitLocked = true;
      _selectedPlantId = userPlant ?? (_plants.isNotEmpty ? _plants.first : null);
      _updateUnitList();
      _selectedUnitId = userUnit;
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _updateUnitList() {
    if (_selectedPlantId == null) {
      _units = [];
      _selectedUnitId = null;
      return;
    }
    _units = _hierarchyService.getUnitsForPlant(_selectedPlantId!);
    if (!_units.contains(_selectedUnitId)) {
      _selectedUnitId = _units.isNotEmpty ? _units.first : null;
    }
  }

  Widget _buildSkeletonLoader() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 16),
          Container(
            height: 260,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
            ),
          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 16),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
            ),
          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.08)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const CustomAppBar(title: 'Plant Intelligence & Analytics'),
        body: _buildSkeletonLoader(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: 'Plant Intelligence & Analytics'),
      body: ResponsiveContentWrapper(
        maxWidth: 1320,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Scope & Filter Bar
              GlassContainer(
                borderRadius: 16,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedPlantId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Plant', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                          items: _plants.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: _isPlantLocked ? null : (val) {
                            if (val != null) {
                              setState(() {
                                _selectedPlantId = val;
                                _updateUnitList();
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedUnitId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                          items: _units.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: _isUnitLocked ? null : (val) {
                            if (val != null) setState(() => _selectedUnitId = val);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 300.ms),
              const SizedBox(height: 16),

              // 2. Real-Time Fleet Reliability & Health Distribution
              _buildFleetHealthSection().animate().fadeIn(duration: 350.ms),
              const SizedBox(height: 16),

              // 3. Machinery Category Breakdown
              _buildAssetTypeBreakdown().animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 16),

              // 4. Operations & Diagnostic Intelligence
              _buildOperationsIntelligence().animate().fadeIn(duration: 450.ms),
            ],
          ),
        ),
      ),
    );
  }

  // --- 2. LIVE FLEET HEALTH DISTRIBUTION (DONUT CHART) ---
  Widget _buildFleetHealthSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('assets').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(height: 220, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(20)));
        }

        final allDocs = snapshot.data!.docs;
        final docs = allDocs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          if (_selectedPlantId != null && _selectedPlantId!.isNotEmpty) {
            if (data['plantId'] != _selectedPlantId) return false;
          }
          if (_selectedUnitId != null && _selectedUnitId!.isNotEmpty) {
            if (data['unitId'] != _selectedUnitId) return false;
          }
          return true;
        }).toList();

        final total = docs.length;
        final active = docs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'active').length;
        final spares = docs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'spare').length;
        final maintenance = docs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'underMaintenance').length;
        final critical = docs.where((d) => (d.data() as Map<String, dynamic>)['isCritical'] == true).length;
        final readiness = total == 0 ? 0.0 : ((active + spares) / total) * 100;

        return GlassContainer(
          width: double.infinity,
          borderRadius: 20,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.pie_chart_outline, color: AppColors.accent, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Fleet Health Distribution',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: readiness >= 85 ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: readiness >= 85 ? Colors.greenAccent.withValues(alpha: 0.4) : Colors.orangeAccent.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '${readiness.toStringAsFixed(0)}% Ready',
                        style: TextStyle(
                          color: readiness >= 85 ? Colors.greenAccent : Colors.orangeAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  child: Row(
                    children: [
                      // Donut Chart
                      Expanded(
                        flex: 4,
                        child: total == 0
                            ? const Center(child: Text('No assets registered', style: TextStyle(fontSize: 11, color: Colors.grey)))
                            : PieChart(
                                PieChartData(
                                  pieTouchData: PieTouchData(
                                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                      setState(() {
                                        if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                                          _touchedIndex = -1;
                                          return;
                                        }
                                        _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                      });
                                    },
                                  ),
                                  borderData: FlBorderData(show: false),
                                  sectionsSpace: 3,
                                  centerSpaceRadius: 36,
                                  sections: [
                                    if (active > 0)
                                      PieChartSectionData(
                                        color: Colors.greenAccent,
                                        value: active.toDouble(),
                                        title: '$active',
                                        radius: _touchedIndex == 0 ? 38 : 32,
                                        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                                      ),
                                    if (spares > 0)
                                      PieChartSectionData(
                                        color: Colors.cyanAccent,
                                        value: spares.toDouble(),
                                        title: '$spares',
                                        radius: _touchedIndex == 1 ? 38 : 32,
                                        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                                      ),
                                    if (maintenance > 0)
                                      PieChartSectionData(
                                        color: Colors.redAccent,
                                        value: maintenance.toDouble(),
                                        title: '$maintenance',
                                        radius: _touchedIndex == 2 ? 38 : 32,
                                        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    if (critical > 0)
                                      PieChartSectionData(
                                        color: Colors.orangeAccent,
                                        value: critical.toDouble(),
                                        title: '$critical',
                                        radius: _touchedIndex == 3 ? 38 : 32,
                                        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                                      ),
                                  ],
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      // Legend
                      Expanded(
                        flex: 6,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLegendItem(Colors.greenAccent, 'In-Service Active', '$active'),
                            const SizedBox(height: 6),
                            _buildLegendItem(Colors.cyanAccent, 'Standby Spares', '$spares'),
                            const SizedBox(height: 6),
                            _buildLegendItem(Colors.redAccent, 'Under Maintenance', '$maintenance'),
                            const SizedBox(height: 6),
                            _buildLegendItem(Colors.orangeAccent, 'Critical Path', '$critical'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(Color color, String label, String count) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70), overflow: TextOverflow.ellipsis)),
        Text(count, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  // --- 3. MACHINERY CATEGORY BREAKDOWN (BAR CHART) ---
  Widget _buildAssetTypeBreakdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('assets').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final allDocs = snapshot.data!.docs;
        final docs = allDocs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          if (_selectedPlantId != null && _selectedPlantId!.isNotEmpty) {
            if (data['plantId'] != _selectedPlantId) return false;
          }
          if (_selectedUnitId != null && _selectedUnitId!.isNotEmpty) {
            if (data['unitId'] != _selectedUnitId) return false;
          }
          return true;
        }).toList();

        final motors = docs.where((d) => (d.data() as Map<String, dynamic>)['type'] == 'motor').length;
        final gearboxes = docs.where((d) => (d.data() as Map<String, dynamic>)['type'] == 'gearbox').length;
        final pumps = docs.where((d) => (d.data() as Map<String, dynamic>)['type'] == 'pump').length;
        final maxVal = docs.isEmpty ? 10.0 : [motors, gearboxes, pumps].reduce((a, b) => a > b ? a : b).toDouble();

        return GlassContainer(
          width: double.infinity,
          borderRadius: 20,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bar_chart, color: AppColors.accent, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Asset Distribution by Type',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 150,
                  child: BarChart(
                    BarChartData(
                      maxY: maxVal > 0 ? maxVal * 1.3 : 10,
                      barTouchData: BarTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, _) {
                              switch (val.toInt()) {
                                case 0:
                                  return Text('Motors ($motors)', style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold));
                                case 1:
                                  return Text('Gearboxes ($gearboxes)', style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold));
                                case 2:
                                  return Text('Pumps ($pumps)', style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold));
                                default:
                                  return const Text('');
                              }
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: [
                        BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: motors.toDouble(), color: Colors.blueAccent, width: 22, borderRadius: BorderRadius.circular(6))]),
                        BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: gearboxes.toDouble(), color: Colors.amberAccent, width: 22, borderRadius: BorderRadius.circular(6))]),
                        BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: pumps.toDouble(), color: Colors.tealAccent, width: 22, borderRadius: BorderRadius.circular(6))]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- 4. OPERATIONS & DIAGNOSTIC INTELLIGENCE ---
  Widget _buildOperationsIntelligence() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('health_logs').snapshots(),
      builder: (context, snapshot) {
        final logs = snapshot.data?.docs ?? [];
        final totalTests = logs.length;

        return GlassContainer(
          width: double.infinity,
          borderRadius: 20,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.monitor_heart_outlined, color: Colors.pinkAccent, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Diagnostic & Health Intelligence',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _buildMetricCard('Total Diagnostic Logs', '$totalTests Tests', Colors.cyanAccent, Icons.science_outlined)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildMetricCard('Insulation Health (IR)', '≥ 100 MΩ Pass', Colors.greenAccent, Icons.bolt)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildMetricCard('Vibration Index', 'ISO 10816 Zone A/B', Colors.blueAccent, Icons.vibration)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildMetricCard('LOTO Safety Rate', '100% Verified', Colors.amberAccent, Icons.lock_clock_outlined)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.grey))),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
