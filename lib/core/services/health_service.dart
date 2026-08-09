import '../../features/assets/data/models/asset_model.dart';
import 'package:flutter/material.dart';

class HealthService {
  // Singleton pattern (optional, but good for consistency)
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  /// Calculates the health status of an asset based on its latest readings.
  AssetHealthStatus calculateHealth(AssetModel asset) {
    // 1. Criticality Check (If marked critical, thresholds might be stricter - ignored for now)
    
    // 2. Vibration Analysis (ISO 10816-1 simplified)
    // Class I: Small machines (<= 15kW) -> Good < 0.71, Satisfactory < 1.8, Unsatisfactory < 4.5
    // Class II: Medium machines (15-75kW) -> Good < 1.12, Satisfactory < 2.8, Unsatisfactory < 7.1
    // Class III: Large rigid -> Good < 1.8, Satisfactory < 4.5, Unsatisfactory < 11.2
    // We will use a simplified general threshold for now.
    // > 7.0 mm/s = Critical
    // > 4.0 mm/s = Warning
    if (asset.vibration != null) {
      double maxVel = 0;
      asset.vibration!.forEach((k, v) {
        if ((k.endsWith('_H') || k.endsWith('_V') || k.endsWith('_A')) && v is num) {
          if (v > maxVel) maxVel = v.toDouble();
        }
      });
      
      if (maxVel >= 7.0) return AssetHealthStatus.critical;
      if (maxVel >= 4.0) return AssetHealthStatus.warning;
    }

    // 3. Electrical Analysis (Motors)
    if (asset.type == AssetType.motor && asset.fullLoadCurrent != null) {
       // Current Imbalance calculation could go here if we had 3-phase current readings.
       // AssetModel currently only stores 'fullLoadCurrent' (rated) and maybe we need actual readings.
       // For now, let's check if 'noLoadCurrent' > 50% of FLA (which is odd).
       if (asset.noLoadCurrent != null && asset.fullLoadCurrent! > 0) {
          if (asset.noLoadCurrent! > (0.6 * asset.fullLoadCurrent!)) {
            return AssetHealthStatus.warning; // High no-load current
          }
       }
    }

    // 4. Maintenance Schedule
    // If overdue for service -> Warning
    if (asset.nextServiceDue != null) {
      if (DateTime.now().isAfter(asset.nextServiceDue!)) {
        return AssetHealthStatus.warning;
      }
    }

    // 5. Gearbox / Oil Analysis (Placeholder)
    if (asset.type == AssetType.gearbox && asset.specs != null) {
       // Check oil change date if we had it.
    }

    return AssetHealthStatus.healthy;
  }
  
  /// Returns a color representing the health status
  Color getHealthColor(AssetHealthStatus status) {
    switch (status) {
      case AssetHealthStatus.healthy: return Colors.greenAccent;
      case AssetHealthStatus.warning: return Colors.orangeAccent;
      case AssetHealthStatus.critical: return Colors.redAccent;
      case AssetHealthStatus.unknown: return Colors.grey;
    }
  }

  /// Returns a readable label
  String getHealthLabel(AssetHealthStatus status) {
    switch (status) {
      case AssetHealthStatus.healthy: return "Healthy";
      case AssetHealthStatus.warning: return "Warning";
      case AssetHealthStatus.critical: return "Critical";
      case AssetHealthStatus.unknown: return "Unknown";
    }
  }
}
