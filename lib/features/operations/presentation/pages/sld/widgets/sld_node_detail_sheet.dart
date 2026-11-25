import 'package:material_ui/material_ui.dart';
import 'package:asset_pulse_pro/core/constants/app_colors.dart';
import 'package:asset_pulse_pro/core/services/power_flow_service.dart';
import 'package:asset_pulse_pro/features/assets/data/models/asset_model.dart';
import 'package:asset_pulse_pro/features/assets/presentation/pages/asset_detail_page.dart';

class SldNodeDetailSheet extends StatelessWidget {
  final PowerFlowNode node;
  final PowerFlowHierarchy hierarchy;
  final void Function(PowerFlowNode targetNode)? onTraceNode;

  const SldNodeDetailSheet({
    super.key,
    required this.node,
    required this.hierarchy,
    this.onTraceNode,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final upstreamPath = hierarchy.traceUpstream(node.id);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header: Level Badge + Actions
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getLevelColor(node.level).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getLevelColor(node.level).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getLevelIcon(node.level), size: 14, color: _getLevelColor(node.level)),
                        const SizedBox(width: 6),
                        Text(
                          node.level.label.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _getLevelColor(node.level),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (node.isIsolated)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.error),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock, size: 13, color: AppColors.error),
                          SizedBox(width: 4),
                          Text(
                            'LOTO ISOLATED',
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Node Tag & Name
              Text(
                node.rawId,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (node.name.isNotEmpty && node.name != node.rawId) ...[
                const SizedBox(height: 2),
                Text(
                  node.name,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
              if (node.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  node.description,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Active LOTO Permit Banner (If Isolated)
              if (node.isIsolated && node.isolationPermit != null) ...[
                _buildIsolationCard(context, isDark),
                const SizedBox(height: 16),
              ],

              // Upstream Electrical Power Path
              Text(
                'Power Supply Path (Source ➔ Load)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              _buildUpstreamPathBreadcrumbs(context, upstreamPath, isDark),
              const SizedBox(height: 16),

              // Details & Specifications
              if (node.details.isNotEmpty) ...[
                Text(
                  'Specifications & Operational Context',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                _buildDetailsGrid(context, isDark),
                const SizedBox(height: 16),
              ],

              // Connected Downstream Loads
              if (node.children.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Direct Downstream Branches',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${node.children.length} Connected',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryLight,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildChildrenList(context, isDark),
                const SizedBox(height: 16),
              ],

              // Actions Footer
              Row(
                children: [
                  if (onTraceNode != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.hub_outlined, size: 18),
                        label: const Text('Highlight Path'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          onTraceNode!(node);
                        },
                      ),
                    ),
                  if (node.level == PowerFlowLevel.asset && node.originalModel is AssetModel) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: const Text('Asset Details'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryLight,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AssetDetailPage(asset: node.originalModel as AssetModel),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIsolationCard(BuildContext context, bool isDark) {
    final permit = node.isolationPermit!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C151B) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
              const SizedBox(width: 8),
              Text(
                'LOTO LOCKOUT ACTIVE: ${permit.permitNo}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Reason: ${permit.reason.isNotEmpty ? permit.reason : 'Scheduled Maintenance Isolation'}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'Dept: ${permit.requestingDepartment}',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Padlocks: ${permit.personalLocksCount + 2}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpstreamPathBreadcrumbs(BuildContext context, List<PowerFlowNode> path, bool isDark) {
    if (path.isEmpty) {
      return const Text('Independent / Root Node');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: [
          for (int i = 0; i < path.length; i++) ...[
            GestureDetector(
              onTap: () {
                if (onTraceNode != null) {
                  Navigator.pop(context);
                  onTraceNode!(path[i]);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: path[i].id == node.id
                      ? _getLevelColor(path[i].level)
                      : (isDark ? const Color(0xFF0F172A) : Colors.white),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _getLevelColor(path[i].level).withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getLevelIcon(path[i].level),
                      size: 12,
                      color: path[i].id == node.id
                          ? Colors.white
                          : _getLevelColor(path[i].level),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      path[i].rawId,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: path[i].id == node.id
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (i < path.length - 1)
              Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailsGrid(BuildContext context, bool isDark) {
    final items = <MapEntry<String, String>>[];
    if (node.type.isNotEmpty) items.add(MapEntry('Type', node.type));
    node.details.forEach((k, v) {
      if (v != null && v.toString().trim().isNotEmpty) {
        String label = k;
        String val = v.toString();
        if (k == 'powerKw') {
          label = 'Power Rating';
          val = '$v kW';
        } else if (k == 'voltage') {
          label = 'Voltage';
          val = '$v V';
        } else if (k == 'fullLoadCurrent') {
          label = 'FLC Current';
          val = '$v A';
        } else if (k == 'speedRpm') {
          label = 'Speed';
          val = '$v RPM';
        } else if (k == 'isCritical') {
          label = 'Critical Asset';
          val = v == true ? 'YES' : 'NO';
        } else if (k == 'ratingKva') {
          label = 'Rating (kVA)';
          val = '$v kVA';
        } else if (k == 'primaryVoltage') {
          label = 'Primary Voltage';
          val = '$v';
        } else if (k == 'secondaryVoltage') {
          label = 'Secondary Voltage';
          val = '$v';
        } else if (k == 'tertiaryVoltage') {
          label = 'Tertiary Voltage';
          val = '$v';
        } else if (k == 'primarySourceFeederId') {
          label = 'Source Feeder';
          val = '$v';
        } else if (k == 'secondaryTargetPanelId') {
          label = 'Secondary Target';
          val = '$v';
        } else if (k == 'tertiaryTargetPanelId') {
          label = 'Tertiary Target';
          val = '$v';
        } else if (k == 'voltageLevel') {
          label = 'Voltage Level';
          val = '$v';
        } else if (k == 'busSections') {
          label = 'Bus Section(s)';
          val = (v is List) ? v.join(', ') : '$v';
        } else if (k == 'busSection') {
          label = 'Bus Section';
          val = '$v';
        } else if (k == 'operatingState') {
          label = 'Breaker State';
          val = '$v';
        } else if (k == 'upstreamFeederId') {
          label = 'Upstream Source';
          val = '$v';
        }
        items.add(MapEntry(label, val));
      }
    });

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((e) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black12,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                e.key.toUpperCase(),
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                e.value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChildrenList(BuildContext context, bool isDark) {
    return Column(
      children: node.children.take(6).map((child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black12,
            ),
          ),
          child: ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: Icon(_getLevelIcon(child.level), size: 18, color: _getLevelColor(child.level)),
            title: Text(
              child.rawId,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
            ),
            subtitle: Text(
              child.name.isNotEmpty ? child.name : child.type,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () {
              Navigator.pop(context);
              if (onTraceNode != null) {
                onTraceNode!(child);
              }
            },
          ),
        );
      }).toList(),
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
