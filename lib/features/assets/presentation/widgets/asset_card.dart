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

  Color _getStatusColor(BuildContext context, AssetStatus status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (status) {
      case AssetStatus.active:
        return isDark ? Colors.greenAccent : const Color(0xFF059669);
      case AssetStatus.underMaintenance:
        return isDark ? Colors.orangeAccent : const Color(0xFFD97706);
      case AssetStatus.scrapped:
        return isDark ? Colors.redAccent : const Color(0xFFDC2626);
      case AssetStatus.spare:
        return isDark ? Colors.cyanAccent : const Color(0xFF0891B2);
    }
  }

  String _getStatusText(AssetStatus status) {
    return status.name.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(context, asset.status);
    final indicatorColor = asset.healthStatus != AssetHealthStatus.unknown
        ? HealthService().getHealthColor(asset.healthStatus)
        : statusColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: GlassContainer(
          width: double.infinity,
          borderRadius: 16,
          border: 0.5,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // Live Status / Health Indicator Bar
                  Container(
                    width: 5,
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
                          children: [
                            Expanded(
                              child: Text(
                                asset.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                              ),
                              child: Text(
                                _getStatusText(asset.status),
                                style: TextStyle(
                                  color: statusColor,
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
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                asset.tagNo,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 11, 
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                asset.technicalSummary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(Icons.precision_manufacturing_outlined, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), size: 13),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                asset.masterEquipmentId.isNotEmpty 
                                  ? 'Parent: ${asset.masterEquipmentId}'
                                  : (asset.status == AssetStatus.spare 
                                      ? (asset.spareLocation?.isNotEmpty == true ? 'Spare @ ${asset.spareLocation}' : 'Spare (Available)')
                                      : 'No Equipment Assigned'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 11),
                              ),
                            ),
                            if (asset.isCritical) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.4), width: 0.8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.workspace_premium_rounded, size: 9, color: Colors.amberAccent),
                                    SizedBox(width: 2),
                                    Text(
                                      'CRITICAL SPARE',
                                      style: TextStyle(color: Colors.amberAccent, fontSize: 8.5, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Arrow
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3), size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
