import 'package:flutter/material.dart';
import 'package:asset_pulse_pro/core/constants/app_colors.dart';
import 'package:asset_pulse_pro/core/services/power_flow_service.dart';

class SldTreeView extends StatefulWidget {
  final PowerFlowHierarchy hierarchy;
  final Set<String> highlightedNodeIds;
  final void Function(PowerFlowNode node) onNodeSelected;

  const SldTreeView({
    super.key,
    required this.hierarchy,
    required this.highlightedNodeIds,
    required this.onNodeSelected,
  });

  @override
  State<SldTreeView> createState() => _SldTreeViewState();
}

class _SldTreeViewState extends State<SldTreeView> {
  final Set<String> _expandedNodeIds = {};
  bool _initializedExpansion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedExpansion) {
      // By default expand root areas and first panel rooms
      for (final area in widget.hierarchy.rootAreas) {
        _expandedNodeIds.add(area.id);
        _expandedNodeIds.add(area.rawId);
        for (final room in area.children) {
          _expandedNodeIds.add(room.id);
          _expandedNodeIds.add(room.rawId);
        }
      }
      _initializedExpansion = true;
    }
  }

  @override
  void didUpdateWidget(covariant SldTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If new nodes highlighted, make sure all parent ancestors are expanded so they are visible
    if (widget.highlightedNodeIds.isNotEmpty) {
      for (final id in widget.highlightedNodeIds) {
        _expandAncestors(id);
      }
    }
  }

  void _expandAncestors(String nodeId) {
    PowerFlowNode? current = widget.hierarchy.findNode(nodeId);
    while (current != null) {
      _expandedNodeIds.add(current.id);
      _expandedNodeIds.add(current.rawId);
      if (current.parentId != null && current.parentId!.isNotEmpty) {
        current = widget.hierarchy.findNode(current.parentId!);
      } else {
        break;
      }
    }
  }

  void _expandAll() {
    setState(() {
      for (final node in widget.hierarchy.allNodes.values) {
        _expandedNodeIds.add(node.id);
        _expandedNodeIds.add(node.rawId);
      }
    });
  }

  void _collapseAll() {
    setState(() {
      _expandedNodeIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rootAreas = widget.hierarchy.rootAreas;

    return Column(
      children: [
        // Tree Toolbar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text(
                'Power Hierarchy Tree',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _expandAll,
                icon: const Icon(Icons.unfold_more, size: 16),
                label: const Text('Expand All', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: _collapseAll,
                icon: const Icon(Icons.unfold_less, size: 16),
                label: const Text('Collapse', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Tree List
        Expanded(
          child: rootAreas.isEmpty
              ? _buildEmptyState(context)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                  itemCount: rootAreas.length,
                  itemBuilder: (context, index) {
                    return _buildTreeNode(context, rootAreas[index], 0, isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_tree_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'No Hierarchy Configured',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Upload areas, panel rooms, panels, and feeders in Admin.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreeNode(BuildContext context, PowerFlowNode node, int depth, bool isDark) {
    final hasChildren = node.children.isNotEmpty;
    final isExpanded = _expandedNodeIds.contains(node.id) || _expandedNodeIds.contains(node.rawId);
    final isHighlighted = widget.highlightedNodeIds.contains(node.id) ||
        widget.highlightedNodeIds.contains(node.rawId);

    final levelColor = _getLevelColor(node.level);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: EdgeInsets.only(left: depth * 18.0, top: 2, bottom: 2),
          decoration: BoxDecoration(
            color: isHighlighted
                ? const Color(0xFF00E5FF).withValues(alpha: 0.15)
                : (isDark ? const Color(0xFF161F33) : Colors.white),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isHighlighted
                  ? const Color(0xFF00E5FF)
                  : (isDark ? Colors.white10 : Colors.black12),
              width: isHighlighted ? 1.5 : 0.8,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => widget.onNodeSelected(node),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  // Expand/Collapse arrow or bullet
                  if (hasChildren)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isExpanded) {
                            _expandedNodeIds.remove(node.id);
                            _expandedNodeIds.remove(node.rawId);
                          } else {
                            _expandedNodeIds.add(node.id);
                            _expandedNodeIds.add(node.rawId);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(
                          isExpanded ? Icons.expand_more : Icons.chevron_right,
                          size: 18,
                          color: isHighlighted ? const Color(0xFF00E5FF) : Colors.grey,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 24),

                  // Level Icon
                  Icon(_getLevelIcon(node.level), size: 16, color: levelColor),
                  const SizedBox(width: 8),

                  // Tag & Name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              node.rawId,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: isHighlighted
                                    ? (isDark ? const Color(0xFF00E5FF) : const Color(0xFF00838F))
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: levelColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                node.level.shortLabel.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: levelColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (node.name.isNotEmpty && node.name != node.rawId) ...[
                          const SizedBox(height: 1),
                          Text(
                            node.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Trailing Indicators: LOTO or Power kW or Children Count
                  if (node.isIsolated)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock, size: 10, color: Colors.white),
                          SizedBox(width: 3),
                          Text(
                            'LOTO',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (node.level == PowerFlowLevel.asset && node.details['powerKw'] != null)
                    Text(
                      '${node.details['powerKw']} kW',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    )
                  else if (hasChildren)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${node.children.length}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // Recursive Children
        if (hasChildren && isExpanded)
          ...node.children.map((child) => _buildTreeNode(context, child, depth + 1, isDark)),
      ],
    );
  }

  Color _getLevelColor(PowerFlowLevel level) {
    switch (level) {
      case PowerFlowLevel.area:
        return Colors.indigoAccent;
      case PowerFlowLevel.panelRoom:
        return Colors.cyan;
      case PowerFlowLevel.transformer:
        return Colors.deepPurpleAccent;
      case PowerFlowLevel.panel:
        return Colors.amber.shade700;
      case PowerFlowLevel.feeder:
        return Colors.blueAccent;
      case PowerFlowLevel.masterEquipment:
        return Colors.teal;
      case PowerFlowLevel.asset:
        return Colors.green;
    }
  }

  IconData _getLevelIcon(PowerFlowLevel level) {
    switch (level) {
      case PowerFlowLevel.area:
        return Icons.location_city;
      case PowerFlowLevel.panelRoom:
        return Icons.meeting_room;
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
