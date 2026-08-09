import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/pulse_loading.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../../core/services/hierarchy_service.dart';
import '../../../home/presentation/widgets/custom_app_bar.dart';

class HierarchyConfigPage extends StatefulWidget {
  const HierarchyConfigPage({super.key});

  @override
  State<HierarchyConfigPage> createState() => _HierarchyConfigPageState();
}

class _HierarchyConfigPageState extends State<HierarchyConfigPage> {
  final HierarchyService _hierarchyService = HierarchyService();
  bool _isLoading = true;
  String _businessName = '';
  Map<String, Map<String, String>> _structure = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _businessName = _hierarchyService.businessName;
      _structure = {};
      final plants = _hierarchyService.getPlants();
      for (var p in plants) {
        _structure[p] = Map<String, String>.from(_hierarchyService.getUnitNamesForPlant(p));
      }
    } catch (e) {
      debugPrint("HierarchyConfigPage: Error loading data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: CustomAppBar(
        title: 'Company Structure',
        onNotificationTap: () {},
      ),
      body: AnimatedGradientBackground(
        child: _isLoading 
        ? const Center(child: PulseLoading(size: 60))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Business Display Name Card
                GlassContainer(
                  width: double.infinity,
                  borderRadius: 16,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('CORPORATE NAME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.accent)),
                        const SizedBox(height: 8),
                        Text(
                          _businessName,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                const Text('PLANTS & UNITS LAYOUT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 12),

                // Tree View (Read-Only)
                ..._structure.keys.map((plant) => _buildPlantCard(plant, _structure[plant]!)),
              ],
            ),
          ),
      ),
    );
  }

  Widget _buildPlantCard(String code, Map<String, String> units) {
    // Get full plant display name
    final plantDisplay = _hierarchyService.getPlantNames()[code] ?? code;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GlassContainer(
        width: double.infinity,
        borderRadius: 16,
        child: ExpansionTile(
          initiallyExpanded: true,
          leading: const Icon(Icons.factory, color: AppColors.primary),
          title: Text(plantDisplay, style: const TextStyle(fontWeight: FontWeight.bold)),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const Divider(),
                  ...units.entries.map((entry) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.circle, size: 8, color: AppColors.accent),
                    title: Text(entry.value),
                  )),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
