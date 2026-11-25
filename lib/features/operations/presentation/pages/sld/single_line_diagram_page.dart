import 'package:flutter/material.dart';
import 'package:asset_pulse_pro/core/constants/app_colors.dart';
import 'package:asset_pulse_pro/core/services/auth_service.dart';
import 'package:asset_pulse_pro/core/services/firestore_service.dart';
import 'package:asset_pulse_pro/core/services/hierarchy_service.dart';
import 'package:asset_pulse_pro/core/services/power_flow_service.dart';
import 'package:asset_pulse_pro/core/widgets/pulse_loading.dart';
import 'package:asset_pulse_pro/core/utils/permission_helper.dart';
import 'widgets/sld_canvas_view.dart';
import 'widgets/sld_tree_view.dart';
import 'widgets/sld_node_detail_sheet.dart';

enum SldDisplayMode {
  schematicCanvas,
  hierarchyTree,
}

class SingleLineDiagramPage extends StatefulWidget {
  final String? initialPlantId;
  final String? initialUnitId;
  final String? initialTargetNodeId;

  const SingleLineDiagramPage({
    super.key,
    this.initialPlantId,
    this.initialUnitId,
    this.initialTargetNodeId,
  });

  @override
  State<SingleLineDiagramPage> createState() => _SingleLineDiagramPageState();
}

class _SingleLineDiagramPageState extends State<SingleLineDiagramPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final PowerFlowService _powerFlowService = PowerFlowService();
  final TextEditingController _searchController = TextEditingController();

  String? _selectedPlantId;
  String? _selectedUnitId;
  List<String> _plants = [];
  List<String> _units = [];
  bool _isLoadingScope = true;
  bool _isLoadingGraph = false;

  PowerFlowHierarchy? _hierarchy;
  SldDisplayMode _displayMode = SldDisplayMode.schematicCanvas;

  String? _selectedActivePanelId;
  PowerFlowNode? _selectedNode;
  List<PowerFlowNode> _activeTracedPath = [];
  final Set<String> _highlightedNodeIds = {};

  List<PowerFlowNode> _searchResults = [];
  bool _isSearching = false;

  bool _isPlantLocked = false;
  bool _isUnitLocked = false;

  @override
  void initState() {
    super.initState();
    _loadUserScope();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserScope() async {
    setState(() => _isLoadingScope = true);
    try {
      final user = AuthService().currentUser;
      _plants = HierarchyService().getPlants();

      if (user != null) {
        final profile = await _firestoreService.getUserProfile(user.uid);
        if (profile != null) {
          final businessId = profile['businessId'] as String? ?? 'VISL';
          await HierarchyService().init(businessId: businessId);

          final userScope = PermissionHelper.resolveUserScope(profile);
          _isPlantLocked = userScope.isPlantLocked;
          _isUnitLocked = userScope.isUnitLocked;

          _plants = userScope.getAvailablePlants();
          _selectedPlantId = widget.initialPlantId ?? userScope.getInitialPlant(_plants);
          if (_selectedPlantId != null) {
            _units = userScope.getAvailableUnits(_selectedPlantId!);
            _selectedUnitId = widget.initialUnitId ?? userScope.getInitialUnit(_units);
          }
        }
      }

      _selectedPlantId ??= widget.initialPlantId ?? (_plants.isNotEmpty ? _plants.first : null);
      if (_selectedPlantId != null) {
        _units = HierarchyService().getUnitsForPlant(_selectedPlantId!);
        if (_selectedUnitId == null || !_units.contains(_selectedUnitId)) {
          _selectedUnitId = widget.initialUnitId ?? (_units.isNotEmpty ? _units.first : null);
        }
      }
    } catch (e) {
      debugPrint('Error loading scope in SLD: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingScope = false);
        _loadPowerHierarchy();
      }
    }
  }

  void _onPlantChanged(String? newPlant) {
    if (newPlant == null || _isPlantLocked || newPlant == _selectedPlantId) return;
    setState(() {
      _selectedPlantId = newPlant;
      _units = HierarchyService().getUnitsForPlant(newPlant);
      _selectedUnitId = _units.isNotEmpty ? _units.first : null;
      _selectedActivePanelId = null;
    });
    _loadPowerHierarchy();
  }

  void _onUnitChanged(String? newUnit) {
    if (newUnit == null || _isUnitLocked || newUnit == _selectedUnitId) return;
    setState(() {
      _selectedUnitId = newUnit;
      _selectedActivePanelId = null;
    });
    _loadPowerHierarchy();
  }

  Future<void> _loadPowerHierarchy() async {
    if (_selectedPlantId == null || _selectedUnitId == null) return;

    setState(() {
      _isLoadingGraph = true;
      _selectedNode = null;
      _activeTracedPath.clear();
      _highlightedNodeIds.clear();
      _selectedActivePanelId = null; // Always reset to top-most root switchboard on refresh
    });

    try {
      final hierarchy = await _powerFlowService.buildHierarchy(
        plantId: _selectedPlantId!,
        unitId: _selectedUnitId!,
      );

      if (mounted) {
        setState(() {
          _hierarchy = hierarchy;
          _isLoadingGraph = false;
        });

        // If an initial target node was requested, highlight it immediately
        if (widget.initialTargetNodeId != null) {
          final target = hierarchy.findNode(widget.initialTargetNodeId!);
          if (target != null) {
            _selectAndTraceNode(target);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingGraph = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading SLD hierarchy: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _selectAndTraceNode(PowerFlowNode node) {
    if (_hierarchy == null) return;
    final path = _hierarchy!.traceUpstream(node.id);

    setState(() {
      _selectedNode = node;
      _activeTracedPath = path;
      _highlightedNodeIds.clear();
      for (final p in path) {
        _highlightedNodeIds.add(p.id);
        _highlightedNodeIds.add(p.rawId);
      }
      // If node or its ancestor belongs to a panel or transformer, focus it on canvas
      for (final p in path) {
        if (p.level == PowerFlowLevel.panel || p.level == PowerFlowLevel.transformer) {
          _selectedActivePanelId = p.id;
          break;
        }
      }
    });

    _showNodeDetails(node);
  }

  void _clearTrace() {
    setState(() {
      _selectedNode = null;
      _activeTracedPath.clear();
      _highlightedNodeIds.clear();
      _searchController.clear();
      _searchResults.clear();
      _isSearching = false;
    });
  }

  void _showNodeDetails(PowerFlowNode node) {
    if (_hierarchy == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SldNodeDetailSheet(
        node: node,
        hierarchy: _hierarchy!,
        onTraceNode: (n) => _selectAndTraceNode(n),
      ),
    );
  }

  void _performSearch(String query) {
    if (_hierarchy == null || query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    final results = _hierarchy!.search(query);
    setState(() {
      _searchResults = results.take(15).toList();
      _isSearching = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B111E) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.cyan.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.schema, color: Colors.cyan, size: 20),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Single Line Diagram (SLD)',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Power Flow (Reset to Root)',
            icon: const Icon(Icons.refresh, size: 22),
            onPressed: _isLoadingGraph
                ? null
                : () {
                    setState(() => _selectedActivePanelId = null);
                    _loadPowerHierarchy();
                  },
          ),
        ],
      ),
      body: _isLoadingScope
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PulseLoading(),
                  SizedBox(height: 16),
                  Text('Initializing Scope...', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            )
          : Column(
              children: [
                // Top Scope & Mode Bar
                _buildScopeAndModeHeader(context, isDark),

                // Metrics Summary Strip
                if (_hierarchy != null) _buildMetricsStrip(context, isDark),

                // Active Traced Path Banner (Breadcrumb flow from Area down to Asset)
                if (_activeTracedPath.isNotEmpty) _buildActivePathBanner(context, isDark),

                // Search Bar
                _buildSearchBar(context, isDark),

                // Main Content View (Canvas or Tree)
                Expanded(
                  child: _isLoadingGraph
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PulseLoading(),
                              SizedBox(height: 16),
                              Text('Assembling SLD Network...', style: TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        )
                      : _hierarchy == null
                          ? const Center(child: Text('No data loaded'))
                          : _displayMode == SldDisplayMode.schematicCanvas
                              ? SldCanvasView(
                                  hierarchy: _hierarchy!,
                                  highlightedNodeIds: _highlightedNodeIds,
                                  activePanelId: _selectedActivePanelId,
                                  onActivePanelChanged: (newPanelId) {
                                    if (newPanelId != null && _hierarchy != null) {
                                      final target = _hierarchy!.findNode(newPanelId);
                                      if (target != null &&
                                          (target.level == PowerFlowLevel.panel ||
                                              target.level == PowerFlowLevel.transformer)) {
                                        setState(() => _selectedActivePanelId = newPanelId);
                                        return;
                                      }
                                    }
                                    setState(() => _selectedActivePanelId = newPanelId);
                                  },
                                  onNodeSelected: (node) => _selectAndTraceNode(node),
                                  onNodeDetailsRequested: (node) => _showNodeDetails(node),
                                )
                              : SldTreeView(
                                  hierarchy: _hierarchy!,
                                  highlightedNodeIds: _highlightedNodeIds,
                                  onNodeSelected: (node) => _selectAndTraceNode(node),
                                ),
                ),
              ],
            ),
    );
  }

  Widget _buildScopeAndModeHeader(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
      ),
      child: Row(
        children: [
          // Plant Selector Dropdown
          Expanded(
            flex: 4,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedPlantId,
                  isExpanded: true,
                  hint: const Text('Plant', style: TextStyle(fontSize: 12)),
                  icon: const Icon(Icons.arrow_drop_down, size: 18),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  items: _plants.map((p) {
                    return DropdownMenuItem(
                      value: p,
                      child: Text(p, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: _isPlantLocked ? null : _onPlantChanged,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Unit Selector Dropdown
          Expanded(
            flex: 5,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedUnitId,
                  isExpanded: true,
                  hint: const Text('Unit', style: TextStyle(fontSize: 12)),
                  icon: const Icon(Icons.arrow_drop_down, size: 18),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  items: _units.map((u) {
                    return DropdownMenuItem(
                      value: u,
                      child: Text(u, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: _isUnitLocked ? null : _onUnitChanged,
                ),
              ),
            ),
          ),

          if (_isPlantLocked || _isUnitLocked) ...[
            const SizedBox(width: 4),
            const Tooltip(
              message: 'Scope locked to your assigned operational post',
              child: Icon(Icons.lock, size: 15, color: Colors.amberAccent),
            ),
          ],

          const SizedBox(width: 8),

          // View Toggle: Schematic Canvas vs Tree
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModeTabButton(
                  icon: Icons.schema,
                  label: 'Canvas',
                  mode: SldDisplayMode.schematicCanvas,
                  isDark: isDark,
                ),
                _buildModeTabButton(
                  icon: Icons.account_tree_outlined,
                  label: 'Tree',
                  mode: SldDisplayMode.hierarchyTree,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTabButton({
    required IconData icon,
    required String label,
    required SldDisplayMode mode,
    required bool isDark,
  }) {
    final isSelected = _displayMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _displayMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsStrip(BuildContext context, bool isDark) {
    final h = _hierarchy!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0E1524) : const Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildMetricPill(
              label: 'Locations',
              count: h.totalAreas,
              color: Colors.indigoAccent,
              icon: Icons.location_on,
            ),
            const SizedBox(width: 10),
            _buildMetricPill(
              label: 'Transformers',
              count: h.totalTransformers,
              color: Colors.deepPurpleAccent,
              icon: Icons.offline_bolt,
            ),
            const SizedBox(width: 10),
            _buildMetricPill(
              label: 'Panels (MCC)',
              count: h.totalPanels,
              color: Colors.amber.shade700,
              icon: Icons.developer_board,
            ),
            const SizedBox(width: 10),
            _buildMetricPill(
              label: 'Feeders',
              count: h.totalFeeders,
              color: Colors.blueAccent,
              icon: Icons.electric_bolt,
            ),
            const SizedBox(width: 10),
            _buildMetricPill(
              label: 'LOTO Isolated',
              count: h.totalIsolatedFeeders,
              color: h.totalIsolatedFeeders > 0 ? AppColors.error : Colors.grey,
              icon: Icons.lock,
              isAlert: h.totalIsolatedFeeders > 0,
            ),
            const SizedBox(width: 10),
            _buildMetricPill(
              label: 'Machinery',
              count: h.totalMasterEquipments,
              color: Colors.teal,
              icon: Icons.precision_manufacturing,
            ),
            const SizedBox(width: 10),
            _buildMetricPill(
              label: 'Connected Assets',
              count: h.totalAssets,
              color: Colors.green,
              icon: Icons.speed,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricPill({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
    bool isAlert = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isAlert ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11.5,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              color: color.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivePathBanner(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F2636), const Color(0xFF131D30)]
              : [const Color(0xFFE0F7FA), const Color(0xFFE0F2FE)],
        ),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.offline_bolt, size: 18, color: Color(0xFF00E5FF)),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < _activeTracedPath.length; i++) ...[
                    GestureDetector(
                      onTap: () => _showNodeDetails(_activeTracedPath[i]),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: _activeTracedPath[i].id == _selectedNode?.id
                              ? const Color(0xFF00E5FF)
                              : (isDark ? const Color(0xFF1E293B) : Colors.white),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          _activeTracedPath[i].rawId,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _activeTracedPath[i].id == _selectedNode?.id
                                ? Colors.black
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    if (i < _activeTracedPath.length - 1)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.arrow_forward, size: 12, color: Color(0xFF00E5FF)),
                      ),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            tooltip: 'Clear Path Highlight',
            onPressed: _clearTrace,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A2338) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _performSearch,
              style: const TextStyle(fontSize: 12.5),
              decoration: InputDecoration(
                hintText: 'Search Asset, Machine, Feeder, or Switchboard to Trace Power...',
                hintStyle: TextStyle(
                  fontSize: 11.5,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: InputBorder.none,
              ),
            ),
          ),
        ),

        // Search Results Dropdown List
        if (_isSearching && _searchResults.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            margin: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A2338) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _searchResults.length,
              separatorBuilder: (_, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _searchResults[index];
                return ListTile(
                  dense: true,
                  leading: Icon(_getLevelIcon(item.level), size: 18),
                  title: Text(
                    item.rawId,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  subtitle: Text(
                    '${item.level.shortLabel} • ${item.name.isNotEmpty ? item.name : item.type}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                  onTap: () {
                    setState(() {
                      _isSearching = false;
                      _searchController.text = item.rawId;
                    });
                    _selectAndTraceNode(item);
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  IconData _getLevelIcon(PowerFlowLevel level) {
    switch (level) {
      case PowerFlowLevel.area:
        return Icons.location_on;
      case PowerFlowLevel.panelRoom:
        return Icons.location_on;
      case PowerFlowLevel.transformer:
        return Icons.offline_bolt;
      case PowerFlowLevel.panel:
        return Icons.developer_board;
      case PowerFlowLevel.feeder:
        return Icons.electric_bolt;
      case PowerFlowLevel.masterEquipment:
        return Icons.precision_manufacturing;
      case PowerFlowLevel.asset:
        return Icons.speed;
    }
  }
}
