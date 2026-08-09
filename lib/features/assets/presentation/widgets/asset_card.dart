import 'package:flutter/material.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../data/models/asset_model.dart';
import '../../../../core/services/health_service.dart';

class AssetCard extends StatelessWidget {
  final AssetModel asset;
  final VoidCallback onTap;

  const AssetCard({
    super.key,
    required this.asset,
    required this.onTap,
  });

  Color _getStatusColor(AssetStatus status) {
    switch (status) {
      case AssetStatus.active:
        return Colors.greenAccent;
      case AssetStatus.underMaintenance:
        return Colors.orangeAccent;
      case AssetStatus.scrapped:
        return Colors.redAccent;
      case AssetStatus.spare:
        return Colors.cyanAccent;
    }
  }

  String _getStatusText(AssetStatus status) {
    return status.name.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(asset.status);
    final indicatorColor = asset.healthStatus != AssetHealthStatus.unknown
        ? HealthService().getHealthColor(asset.healthStatus)
        : statusColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: GlassContainer(
          width: double.infinity,
          height: 100, // Compact height
          borderRadius: 16,
          border: 0.5,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Live Status / Health Indicator Bar
                Container(
                  width: 5,
                  height: double.infinity,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: indicatorColor,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: indicatorColor.withValues(alpha: 0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            asset.name,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(asset.status).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _getStatusColor(asset.status).withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              _getStatusText(asset.status),
                              style: TextStyle(
                                color: _getStatusColor(asset.status),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              asset.type.name.toUpperCase(),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 10, 
                                fontWeight: FontWeight.w600
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            asset.tagNo,
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), size: 12),
                          const SizedBox(width: 4),
                          Text(
                            asset.masterEquipmentId.isNotEmpty 
                              ? 'Eq: ${asset.masterEquipmentId}'
                              : 'No Equipment Assigned',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 12),
                          ),
                          const Spacer(),
                           // Pulse Time
                           if (asset.lastPulseTime != null)
                             Text(
                               'Pulse: ${asset.lastPulseTime!.minute}m ago', // Simplified relative time logic? Nah, just simplistic for now.
                               style: const TextStyle(color: Colors.white38, fontSize: 10),
                             ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Arrow
                Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
