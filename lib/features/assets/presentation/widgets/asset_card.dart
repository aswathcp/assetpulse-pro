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
                                asset.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                asset.type.name.toUpperCase(),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 10, 
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                asset.tagNo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                  fontSize: 12,
                                  fontFamily: 'monospace',
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
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Text(
                                  'CRITICAL',
                                  style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold),
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
