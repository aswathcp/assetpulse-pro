import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/hierarchy_service.dart';
import '../../features/assets/data/models/location_model.dart';
import '../../features/assets/data/models/transformer_model.dart';
import '../../features/assets/data/models/panel_model.dart';
import '../../features/assets/data/models/feeder_model.dart';
import '../../features/assets/data/models/master_equipment_model.dart';
import '../../features/assets/data/models/asset_model.dart';
import '../../features/assets/data/models/isolation_permit_model.dart';

enum PowerFlowLevel {
  area,
  panelRoom,
  transformer,
  panel,
  feeder,
  masterEquipment,
  asset,
}

extension PowerFlowLevelExt on PowerFlowLevel {
  String get label {
    switch (this) {
      case PowerFlowLevel.area:
        return 'Physical Area';
      case PowerFlowLevel.panelRoom:
        return 'Panel Room / Substation';
      case PowerFlowLevel.transformer:
        return 'Step-Down Transformer';
      case PowerFlowLevel.panel:
        return 'Switchboard / Panel';
      case PowerFlowLevel.feeder:
        return 'Feeder / Circuit Breaker';
      case PowerFlowLevel.masterEquipment:
        return 'Master Equipment / Machine';
      case PowerFlowLevel.asset:
        return 'Drive / Load Asset';
    }
  }

  String get shortLabel {
    switch (this) {
      case PowerFlowLevel.area:
        return 'Area';
      case PowerFlowLevel.panelRoom:
        return 'Substation';
      case PowerFlowLevel.transformer:
        return 'Transformer';
      case PowerFlowLevel.panel:
        return 'Panel';
      case PowerFlowLevel.feeder:
        return 'Feeder';
      case PowerFlowLevel.masterEquipment:
        return 'Machine';
      case PowerFlowLevel.asset:
        return 'Asset';
    }
  }
}

class PowerFlowNode {
  final String id;
  final String rawId;
  final String name;
  final PowerFlowLevel level;
  final String? parentId;
  final String type;
  final String description;
  final Map<String, dynamic> details;
  final bool isIsolated;
  final IsolationPermitModel? isolationPermit;
  final AssetHealthStatus? healthStatus;
  final dynamic originalModel;
  final List<PowerFlowNode> children = [];

  PowerFlowNode({
    required this.id,
    required this.rawId,
    required this.name,
    required this.level,
    this.parentId,
    this.type = '',
    this.description = '',
    this.details = const {},
    this.isIsolated = false,
    this.isolationPermit,
    this.healthStatus,
    this.originalModel,
  });
}

class SimulationImpact {
  final List<PowerFlowNode> openBreakers;
  final List<PowerFlowNode> blackedOutPanels;
  final List<PowerFlowNode> partiallyBlackedOutPanels;
  final List<PowerFlowNode> blackedOutFeeders;
  final List<PowerFlowNode> blackedOutEquipment;
  final List<PowerFlowNode> blackedOutAssets;

  int get totalBlackedOut =>
      blackedOutPanels.length +
      blackedOutEquipment.length +
      blackedOutAssets.length;

  const SimulationImpact({
    required this.openBreakers,
    required this.blackedOutPanels,
    required this.partiallyBlackedOutPanels,
    required this.blackedOutFeeders,
    required this.blackedOutEquipment,
    required this.blackedOutAssets,
  });
}

class PowerFlowHierarchy {
  final String plantId;
  final String unitId;
  final Map<String, PowerFlowNode> allNodes = {};
  final List<PowerFlowNode> rootAreas = [];
  final List<PowerFlowNode> orphanRooms = [];
  final List<PowerFlowNode> orphanPanels = [];
  final List<PowerFlowNode> orphanFeeders = [];
  final List<PowerFlowNode> orphanEquipments = [];
  final List<PowerFlowNode> orphanAssets = [];
  final List<IsolationPermitModel> activeIsolations;

  /// Simulation Mode State: Maps feederId/rawId -> simulated operating state ('OPEN' or 'CLOSED')
  final Map<String, String> simulatedFeederStates = {};
  bool isSimulationActive = false;

  PowerFlowHierarchy({
    required this.plantId,
    required this.unitId,
    required this.activeIsolations,
  });

  void setSimulationActive(bool active) {
    isSimulationActive = active;
    if (!active) {
      simulatedFeederStates.clear();
    }
  }

  void resetSimulation() {
    simulatedFeederStates.clear();
  }

  void toggleFeederState(PowerFlowNode feeder) {
    if (!isSimulationActive) {
      isSimulationActive = true;
    }
    final isCurrentlyConducting = isFeederConducting(feeder);
    final newState = isCurrentlyConducting ? 'OPEN' : 'CLOSED';
    simulatedFeederStates[feeder.id] = newState;
    simulatedFeederStates[feeder.rawId] = newState;
  }

  bool isFeederSimulated(PowerFlowNode feeder) {
    if (!isSimulationActive) return false;
    return simulatedFeederStates.containsKey(feeder.id) ||
        simulatedFeederStates.containsKey(feeder.rawId);
  }

  int get totalAreas => allNodes.values.toSet().where((n) => n.level == PowerFlowLevel.area).length;
  int get totalPanelRooms => allNodes.values.toSet().where((n) => n.level == PowerFlowLevel.panelRoom).length;
  int get totalTransformers => allNodes.values.toSet().where((n) => n.level == PowerFlowLevel.transformer).length;
  int get totalPanels => allNodes.values.toSet().where((n) => n.level == PowerFlowLevel.panel).length;
  int get totalFeeders => allNodes.values.toSet().where((n) => n.level == PowerFlowLevel.feeder).length;
  int get totalMasterEquipments => allNodes.values.toSet().where((n) => n.level == PowerFlowLevel.masterEquipment).length;
  int get totalAssets => allNodes.values.toSet().where((n) => n.level == PowerFlowLevel.asset).length;
  int get totalIsolatedFeeders => allNodes.values.toSet().where((n) => n.level == PowerFlowLevel.feeder && n.isIsolated).length;

  List<PowerFlowNode> get transformers =>
      allNodes.values.where((n) => n.level == PowerFlowLevel.transformer).toSet().toList();
  List<PowerFlowNode> get panels =>
      allNodes.values.where((n) => n.level == PowerFlowLevel.panel).toSet().toList();

  /// Trace upstream electrical path from any node up to root source (Area, Substation, Transformer, or Incomer)
  List<PowerFlowNode> traceUpstream(String nodeId) {
    final List<PowerFlowNode> path = [];
    final visited = <String>{};
    PowerFlowNode? current = findNode(nodeId);

    while (current != null && !visited.contains(current.id)) {
      visited.add(current.id);
      path.add(current);

      String? nextId;
      // If feeder has an upstream feeder or transformer designated
      if (current.level == PowerFlowLevel.feeder) {
        final upFeeder = current.details['upstreamFeederId']?.toString();
        if (upFeeder != null && upFeeder.isNotEmpty && upFeeder != 'None') {
          nextId = upFeeder;
        }
      } else if (current.level == PowerFlowLevel.transformer) {
        final srcFeeder = current.details['primarySourceFeederId']?.toString();
        if (srcFeeder != null && srcFeeder.isNotEmpty && srcFeeder != 'None') {
          nextId = srcFeeder;
        }
      }

      // Default to parentId if no specific electrical source link
      nextId ??= (current.parentId != null && current.parentId!.isNotEmpty) ? current.parentId : null;

      if (nextId == null || nextId.isEmpty) {
        break;
      }
      current = findNode(nextId);
    }

    // Return from source (Root) -> down to Target (Asset/Machine)
    return path.reversed.toList();
  }

  /// Search across all nodes by query text (tag, name, id, description)
  List<PowerFlowNode> search(String query) {
    if (query.trim().isEmpty) return [];
    final q = query.trim().toLowerCase();
    return allNodes.values.where((node) {
      return node.id.toLowerCase().contains(q) ||
          node.rawId.toLowerCase().contains(q) ||
          node.name.toLowerCase().contains(q) ||
          node.type.toLowerCase().contains(q) ||
          node.description.toLowerCase().contains(q);
    }).toList();
  }

  /// Lookup node by ID, trying exact key, stripped key, and prefixed key
  PowerFlowNode? findNode(String id) {
    if (allNodes.containsKey(id)) return allNodes[id];
    final prefixed = HierarchyService.prefixId(id, plantId, unitId);
    if (allNodes.containsKey(prefixed)) return allNodes[prefixed];
    final stripped = HierarchyService.stripPrefix(id, plantId, unitId);
    if (allNodes.containsKey(stripped)) return allNodes[stripped];

    // Case insensitive search
    final upper = id.toUpperCase();
    for (final entry in allNodes.entries) {
      if (entry.key.toUpperCase() == upper ||
          entry.value.rawId.toUpperCase() == upper ||
          entry.value.id.toUpperCase() == upper) {
        return entry.value;
      }
    }
    return null;
  }

  /// Check if a feeder is currently closed and conducting (not isolated by LOTO)
  bool isFeederConducting(PowerFlowNode feederNode) {
    if (feederNode.isIsolated) return false;
    if (isSimulationActive) {
      final simState = simulatedFeederStates[feederNode.id] ?? simulatedFeederStates[feederNode.rawId];
      if (simState != null) {
        return simState == 'CLOSED';
      }
    }
    final opState = feederNode.details['operatingState']?.toString().toUpperCase() ?? 'CLOSED';
    return opState == 'CLOSED';
  }

  /// Check whether a transformer is energized by its primary supply
  bool isTransformerEnergized(PowerFlowNode xfmrNode, [Set<String>? visited]) {
    final v = visited ?? <String>{};
    if (v.contains('xfmr:${xfmrNode.id}')) return false;
    final pathVisited = Set<String>.from(v)..add('xfmr:${xfmrNode.id}');

    final priFeederId = xfmrNode.details['primarySourceFeederId']?.toString();
    if (priFeederId != null && priFeederId.isNotEmpty && priFeederId != 'None') {
      final priFeeder = findNode(priFeederId);
      if (priFeeder != null) {
        return isFeederEnergized(priFeeder, pathVisited);
      }
    }
    if (xfmrNode.parentId != null && xfmrNode.parentId!.isNotEmpty) {
      final parentPnl = findNode(xfmrNode.parentId!);
      if (parentPnl != null && parentPnl.level == PowerFlowLevel.panel) {
        return isBusSectionEnergized(parentPnl, 'MAIN', pathVisited);
      }
    }
    return true; // Default grid utility infeed
  }

  /// Check if an incomer's source supply is live (tracing upstream feeder / transformer)
  bool isIncomerSourceLive(PowerFlowNode inc, [Set<String>? visited]) {
    final v = visited ?? <String>{};
    if (v.contains('inc:${inc.id}')) return false;
    final pathVisited = Set<String>.from(v)..add('inc:${inc.id}');

    // 1. Direct upstream link
    final upId = inc.details['upstreamFeederId']?.toString();
    if (upId != null && upId.isNotEmpty && upId != 'None') {
      final upNode = findNode(upId);
      if (upNode != null) {
        if (upNode.level == PowerFlowLevel.feeder) {
          return isFeederEnergized(upNode, pathVisited);
        } else if (upNode.level == PowerFlowLevel.transformer) {
          return isTransformerEnergized(upNode, pathVisited);
        } else if (upNode.level == PowerFlowLevel.panel) {
          return isBusSectionEnergized(upNode, 'MAIN', pathVisited);
        }
      }
    }

    // 2. Transformer outputting to this panel
    if (inc.parentId != null) {
      final parentPanel = findNode(inc.parentId!);
      if (parentPanel != null) {
        final incSec = inc.details['busSection']?.toString().toUpperCase() ?? '';
        final incRaw = inc.rawId.toUpperCase();
        for (final tr in transformers) {
          final routing = getTransformerRouting(tr);
          final secMatch = routing.secondaryTargetPanelId == parentPanel.id ||
              routing.secondaryTargetPanelId == parentPanel.rawId;
          final tertMatch = routing.tertiaryTargetPanelId == parentPanel.id ||
              routing.tertiaryTargetPanelId == parentPanel.rawId;

          if (secMatch || tertMatch) {
            final isSec1 = incSec.contains('SEC-1') ||
                incRaw.contains('INC-01') ||
                incRaw.contains('INC-1') ||
                incRaw.contains('INCOMER-01') ||
                incRaw.contains('INCOMER-1') ||
                incRaw.contains('INCOMER 1');
            final isSec2 = incSec.contains('SEC-2') ||
                incRaw.contains('INC-02') ||
                incRaw.contains('INC-2') ||
                incRaw.contains('INCOMER-02') ||
                incRaw.contains('INCOMER-2') ||
                incRaw.contains('INCOMER 2');
            final trName = tr.rawId.toUpperCase();

            bool pairMatch = false;
            if (isSec1 &&
                (trName.contains('TR-01') ||
                    trName.contains('TR-1') ||
                    trName.contains('TR1') ||
                    trName.contains('XFMR-01') ||
                    trName.contains('XFMR-1') ||
                    trName.contains('TRANSFORMER-01') ||
                    trName.contains('TRANSFORMER-1') ||
                    trName.contains('TRANSFORMER 1'))) {
              pairMatch = true;
            } else if (isSec2 &&
                (trName.contains('TR-02') ||
                    trName.contains('TR-2') ||
                    trName.contains('TR2') ||
                    trName.contains('XFMR-02') ||
                    trName.contains('XFMR-2') ||
                    trName.contains('TRANSFORMER-02') ||
                    trName.contains('TRANSFORMER-2') ||
                    trName.contains('TRANSFORMER 2'))) {
              pairMatch = true;
            } else if (!isSec1 && !isSec2) {
              pairMatch = true;
            }

            if (pairMatch) {
              return isTransformerEnergized(tr, pathVisited);
            }
          }
        }
      }
    }

    return true;
  }

  /// Check whether a panel is configured with a split busbar (e.g. SEC-1, SEC-2)
  bool isPanelSplitBus(PowerFlowNode panelNode) {
    final rawSections = panelNode.details['busSections'];
    if (rawSections is List && rawSections.length > 1) {
      return true;
    }
    final str = rawSections?.toString().toUpperCase() ?? '';
    return (str.contains('SEC-1') && str.contains('SEC-2')) || str.contains('& 2') || str.contains('&2');
  }

  /// Retrieve all feeders belonging to a panel
  List<PowerFlowNode> getPanelFeeders(PowerFlowNode panelNode) {
    final set = <PowerFlowNode>{};
    set.addAll(panelNode.children.where((c) => c.level == PowerFlowLevel.feeder));
    set.addAll(allNodes.values.where((n) =>
        n.level == PowerFlowLevel.feeder &&
        (n.parentId == panelNode.id || n.parentId == panelNode.rawId)));
    return set.toList();
  }

  bool isFeederIncomer(PowerFlowNode f) {
    final t = f.type.toLowerCase();
    final r = f.rawId.toUpperCase();
    final n = f.name.toUpperCase();
    return t.contains('incomer') || r.contains('INCOMER') || r.contains('INC-') || n.contains('INCOMER');
  }

  bool isFeederBusCoupler(PowerFlowNode f) {
    final t = f.type.toLowerCase();
    final r = f.rawId.toUpperCase();
    final n = f.name.toUpperCase();
    return t.contains('coupler') || r.contains('COUPLER') || r.contains('BUS COUPLER') || n.contains('COUPLER');
  }

  bool isFeederTie(PowerFlowNode f) {
    final t = f.type.toLowerCase();
    final r = f.rawId.toUpperCase();
    return t == 'tie' || r.contains('TIE');
  }

  bool isFeederSpare(PowerFlowNode f) {
    final t = f.type.toLowerCase();
    final r = f.rawId.toUpperCase();
    final n = f.name.toUpperCase();
    return t.contains('spare') || r.contains('SPARE') || n.contains('SPARE');
  }

  /// Evaluate if a particular bus section of a panel is energized.
  /// Handles Incomers, Bus Couplers across split buses (SEC-1 / SEC-2), and Tie feeders.
  bool isBusSectionEnergized(PowerFlowNode panelNode, String section, [Set<String>? visited]) {
    final v = visited ?? <String>{};
    final key = '${panelNode.id}:$section';
    if (v.contains(key)) return false;
    final pathVisited = Set<String>.from(v)..add(key);

    if (panelNode.isIsolated) return false;

    final feeders = getPanelFeeders(panelNode);
    final incomers = feeders.where((f) => isFeederIncomer(f)).toList();

    // If no incomers explicitly modelled in data, bus is presumed energized unless panel is isolated
    if (incomers.isEmpty) {
      return !panelNode.isIsolated;
    }

    final secUpper = section.toUpperCase().trim();
    final isSplit = isPanelSplitBus(panelNode);

    if (!isSplit) {
      // Single bus: any conducting incomer with live source energizes the bus
      return incomers.any((inc) => isFeederConducting(inc) && isIncomerSourceLive(inc, pathVisited));
    }

    // Split bus: Identify incomers attached to SEC-1 vs SEC-2
    bool evalSec1() => incomers.any((inc) {
      final s = inc.details['busSection']?.toString().toUpperCase() ?? '';
      final r = inc.rawId.toUpperCase();
      final isSec1 = s.contains('SEC-1') ||
          r.contains('INC-01') ||
          r.contains('INC-1') ||
          r.contains('INCOMER-01') ||
          r.contains('INCOMER-1') ||
          r.contains('INCOMER 1');
      return isSec1 && isFeederConducting(inc) && isIncomerSourceLive(inc, pathVisited);
    });

    bool evalSec2() => incomers.any((inc) {
      final s = inc.details['busSection']?.toString().toUpperCase() ?? '';
      final r = inc.rawId.toUpperCase();
      final isSec2 = s.contains('SEC-2') ||
          s.contains('& 2') ||
          r.contains('INC-02') ||
          r.contains('INC-2') ||
          r.contains('INCOMER-02') ||
          r.contains('INCOMER-2') ||
          r.contains('INCOMER 2');
      return isSec2 && isFeederConducting(inc) && isIncomerSourceLive(inc, pathVisited);
    });

    // Check Bus Couplers bridging SEC-1 and SEC-2
    final couplers = feeders.where((f) => isFeederBusCoupler(f)).toList();
    final couplerConducting = couplers.any((c) => isFeederConducting(c));

    if (secUpper.contains('SEC-1') || secUpper == '1') {
      if (evalSec1()) return true;
      if (couplerConducting && evalSec2()) return true; // Power bridged from SEC-2!
      return false;
    } else if (secUpper.contains('SEC-2') || secUpper == '2' || secUpper.contains('& 2')) {
      if (evalSec2()) return true;
      if (couplerConducting && evalSec1()) return true; // Power bridged from SEC-1!
      return false;
    }

    // Fallback for general queries
    return evalSec1() || evalSec2();
  }

  /// Evaluate if an outgoing feeder has live power
  bool isFeederEnergized(PowerFlowNode feederNode, [Set<String>? visited]) {
    if (feederNode.isIsolated) return false;
    if (!isFeederConducting(feederNode)) return false;

    // Incomers are energized if their upstream source is live
    if (isFeederIncomer(feederNode)) {
      return isIncomerSourceLive(feederNode, visited);
    }

    // Bus couplers are energized if either bus section is energized
    if (isFeederBusCoupler(feederNode)) {
      if (feederNode.parentId != null) {
        final parentPanel = findNode(feederNode.parentId!);
        if (parentPanel != null) {
          return isBusSectionEnergized(parentPanel, 'SEC-1', visited) ||
              isBusSectionEnergized(parentPanel, 'SEC-2', visited);
        }
      }
      return true;
    }

    // Outgoings are energized if their parent bus section is energized
    if (feederNode.parentId != null) {
      final parentPanel = findNode(feederNode.parentId!);
      if (parentPanel != null && parentPanel.level == PowerFlowLevel.panel) {
        final section = feederNode.details['busSection']?.toString() ?? 'MAIN';
        return isBusSectionEnergized(parentPanel, section, visited);
      }
    }
    return true;
  }

  /// Check if a master equipment is energized
  bool isEquipmentEnergized(PowerFlowNode eqNode) {
    if (eqNode.isIsolated) return false;
    if (eqNode.parentId != null) {
      final parentFeeder = findNode(eqNode.parentId!);
      if (parentFeeder != null && parentFeeder.level == PowerFlowLevel.feeder) {
        return isFeederEnergized(parentFeeder);
      }
      final parentPanel = findNode(eqNode.parentId!);
      if (parentPanel != null && parentPanel.level == PowerFlowLevel.panel) {
        return isBusSectionEnergized(parentPanel, 'MAIN');
      }
    }
    return true;
  }

  /// Check if a downstream asset is energized
  bool isAssetEnergized(PowerFlowNode assetNode) {
    if (assetNode.isIsolated) return false;
    if (assetNode.parentId != null) {
      final parent = findNode(assetNode.parentId!);
      if (parent != null) {
        if (parent.level == PowerFlowLevel.masterEquipment) {
          return isEquipmentEnergized(parent);
        } else if (parent.level == PowerFlowLevel.feeder) {
          return isFeederEnergized(parent);
        }
      }
    }
    return true;
  }

  /// Calculate plant-wide power disruption impact for current simulation state
  SimulationImpact calculateSimulationImpact() {
    final List<PowerFlowNode> openBreakers = [];
    final List<PowerFlowNode> blackedOutPanels = [];
    final List<PowerFlowNode> partialPanels = [];
    final List<PowerFlowNode> blackedOutFeeders = [];
    final List<PowerFlowNode> blackedOutEquipment = [];
    final List<PowerFlowNode> blackedOutAssets = [];

    // Breakers explicitly tripped in simulation or actively isolated via LOTO
    for (final node in allNodes.values.toSet().where((n) => n.level == PowerFlowLevel.feeder)) {
      final isSim = isFeederSimulated(node);
      final isCond = isFeederConducting(node);
      if (isSim && !isCond) {
        openBreakers.add(node);
      } else if (node.isIsolated) {
        openBreakers.add(node);
      }
    }

    // Panels
    for (final panel in panels) {
      final isSplit = isPanelSplitBus(panel);
      if (isSplit) {
        final sec1 = isBusSectionEnergized(panel, 'SEC-1');
        final sec2 = isBusSectionEnergized(panel, 'SEC-2');
        if (!sec1 && !sec2) {
          blackedOutPanels.add(panel);
        } else if (!sec1 || !sec2) {
          partialPanels.add(panel);
        }
      } else {
        if (!isBusSectionEnergized(panel, 'MAIN')) {
          blackedOutPanels.add(panel);
        }
      }
    }

    // Outgoing feeders (excluding incomers, couplers, and non-simulated spares/ties)
    for (final feeder in allNodes.values.toSet().where((n) => n.level == PowerFlowLevel.feeder)) {
      if (!isFeederIncomer(feeder) && !isFeederBusCoupler(feeder) && !isFeederSpare(feeder)) {
        if (!isFeederEnergized(feeder)) {
          // If it's a normally open standby tie and not currently simulated, don't count as outage
          if (isFeederTie(feeder) && !isFeederSimulated(feeder)) continue;
          blackedOutFeeders.add(feeder);
        }
      }
    }

    // Master equipment
    for (final eq in allNodes.values.toSet().where((n) => n.level == PowerFlowLevel.masterEquipment)) {
      if (!isEquipmentEnergized(eq)) {
        blackedOutEquipment.add(eq);
      }
    }

    // Assets
    for (final asset in allNodes.values.toSet().where((n) => n.level == PowerFlowLevel.asset)) {
      if (!isAssetEnergized(asset)) {
        blackedOutAssets.add(asset);
      }
    }

    return SimulationImpact(
      openBreakers: openBreakers,
      blackedOutPanels: blackedOutPanels,
      partiallyBlackedOutPanels: partialPanels,
      blackedOutFeeders: blackedOutFeeders,
      blackedOutEquipment: blackedOutEquipment,
      blackedOutAssets: blackedOutAssets,
    );
  }

  /// Find all upstream power source nodes for a given panel (Transformers, Upstream Panels, Feeders, Captive DGs)
  List<PowerFlowNode> getAllUpstreamSourcesForPanel(PowerFlowNode panelNode) {
    final List<PowerFlowNode> sources = [];
    final Set<String> seenIds = {};

    final feeders = getPanelFeeders(panelNode);
    final incomers = feeders.where((f) => isFeederIncomer(f)).toList();

    for (final inc in incomers) {
      final upId = inc.details['upstreamFeederId']?.toString();
      if (upId != null && upId.isNotEmpty && upId != 'None') {
        final node = findNode(upId);
        if (node != null) {
          PowerFlowNode actualSource = node;
          if (node.level == PowerFlowLevel.feeder && node.parentId != null) {
            final parentPnl = findNode(node.parentId!);
            if (parentPnl != null) actualSource = parentPnl;
          }
          if (seenIds.add(actualSource.id)) {
            sources.add(actualSource);
          }
        }
      }
    }

    // Also check if any transformer outputs to this panel (secondary or tertiary winding)
    for (final tr in transformers) {
      final sec = tr.details['secondaryTargetPanelId']?.toString();
      final tert = tr.details['tertiaryTargetPanelId']?.toString();
      if ((sec != null && (sec == panelNode.id || sec == panelNode.rawId)) ||
          (tert != null && (tert == panelNode.id || tert == panelNode.rawId))) {
        if (seenIds.add(tr.id)) {
          sources.add(tr);
        }
      }
    }

    return sources;
  }

  /// Find the primary upstream power source node for a given panel
  PowerFlowNode? getUpstreamSourceForPanel(PowerFlowNode panelNode) {
    final sources = getAllUpstreamSourcesForPanel(panelNode);
    return sources.isNotEmpty ? sources.first : null;
  }

  /// Get the downstream panel fed by a specific outgoing feeder, if any
  PowerFlowNode? getDownstreamPanelForFeeder(PowerFlowNode feederNode) {
    // 1. Direct match: Check if any panel's incomer has upstreamFeederId == feederNode.id or rawId
    for (final p in panels) {
      if (p.id == feederNode.parentId || p.rawId == feederNode.parentId) continue;
      final incomers = getPanelFeeders(p).where((f) => isFeederIncomer(f));
      for (final inc in incomers) {
        final up = inc.details['upstreamFeederId']?.toString();
        if (up != null && (up == feederNode.id || up == feederNode.rawId)) {
          return p;
        }
      }
    }

    // 2. Check if this feeder powers a transformer
    final downstreamTr = getDownstreamTransformerForFeeder(feederNode);
    if (downstreamTr != null) {
      return downstreamTr;
    }

    // 3. Heuristic name/tag match: e.g. feeder rawId 'PCC1-OG-MCC7-IC1' -> matches panel 'MCC7'
    final rawUpper = feederNode.rawId.toUpperCase();
    final nameUpper = feederNode.name.toUpperCase();
    for (final p in panels) {
      if (p.id == feederNode.parentId || p.rawId == feederNode.parentId) continue;
      final pRaw = p.rawId.toUpperCase();
      if ((rawUpper.contains(pRaw) || nameUpper.contains(pRaw)) && pRaw.length >= 3) {
        return p;
      }
    }

    return null;
  }

  /// Get downstream transformer fed by an HT feeder
  PowerFlowNode? getDownstreamTransformerForFeeder(PowerFlowNode feederNode) {
    for (final tr in transformers) {
      final src = tr.details['primarySourceFeederId']?.toString();
      if (src != null && (src == feederNode.id || src == feederNode.rawId)) {
        return tr;
      }
      final rawTr = tr.rawId.toUpperCase();
      if (feederNode.rawId.toUpperCase().contains(rawTr) || feederNode.name.toUpperCase().contains(rawTr)) {
        return tr;
      }
    }
    return null;
  }

  /// Find all downstream panels fed by outgoings of this panel
  List<PowerFlowNode> getDownstreamPanelsForPanel(PowerFlowNode panelNode) {
    final list = <PowerFlowNode>[];
    final feeders = getPanelFeeders(panelNode).where((f) => !isFeederIncomer(f) && !isFeederBusCoupler(f));
    for (final f in feeders) {
      final ds = getDownstreamPanelForFeeder(f);
      if (ds != null && !list.contains(ds)) {
        list.add(ds);
      }
    }
    return list;
  }

  /// Return root HT panels (e.g. 11kV HT PCC that is fed by grid / generators)
  List<PowerFlowNode> getRootHTPanels() {
    final roots = panels.where((p) {
      final volt = p.details['voltageLevel']?.toString().toUpperCase() ?? '';
      final raw = p.rawId.toUpperCase();
      return volt.contains('11KV') || volt.contains('33KV') || raw.contains('HT-PCC');
    }).toList();
    if (roots.isNotEmpty) return roots;
    return panels.take(1).toList();
  }

  /// Hierarchical tier: 1=HT Switchgear, 2=Transformers, 3=Main PCCs, 4=MCCs, 5=Machine
  int getNodeTier(PowerFlowNode node) {
    if (node.level == PowerFlowLevel.transformer) return 2;
    if (node.level == PowerFlowLevel.masterEquipment) return 5;
    if (node.level == PowerFlowLevel.asset) return 6;
    if (node.level == PowerFlowLevel.panel) {
      final raw = node.rawId.toUpperCase();
      final volt = node.details['voltageLevel']?.toString().toUpperCase() ?? '';
      if (volt.contains('11KV') || volt.contains('33KV') || raw.contains('HT-PCC')) return 1;
      if (raw.contains('PCC') || volt.contains('3.3KV')) return 3;
      if (raw.contains('MCC') || raw.contains('MDC') || raw.contains('LDB')) return 4;
      return 4;
    }
    return 3;
  }

  /// Comprehensive transformer winding, section, and downstream routing analysis
  TransformerWindingRouting getTransformerRouting(PowerFlowNode xfmr, {String? currentPanelId}) {
    final priVolt = xfmr.details['primaryVoltage']?.toString() ?? '11kV';
    final secVolt = xfmr.details['secondaryVoltage']?.toString() ?? '415V';
    final tertVolt = xfmr.details['tertiaryVoltage']?.toString();
    final hasTert = tertVolt != null && tertVolt.isNotEmpty && tertVolt != 'None';

    final priSrcFdrId = xfmr.details['primarySourceFeederId']?.toString();
    final priSrcFdr = priSrcFdrId != null ? findNode(priSrcFdrId) : null;
    final priSrcPnlId = priSrcFdr?.parentId;
    final priSrcPnl = priSrcPnlId != null ? findNode(priSrcPnlId) : null;
    final priLabel = priSrcPnl != null
        ? '${priSrcPnl.rawId} ➔ ${priSrcFdr?.rawId ?? priSrcFdrId}'
        : (priSrcFdrId ?? 'HT GRID UTILITY');

    final secTgtPnlId = xfmr.details['secondaryTargetPanelId']?.toString();
    final secTgtPnl = secTgtPnlId != null ? findNode(secTgtPnlId) : null;
    String secSection = 'SEC-1';
    if (secTgtPnl != null) {
      final incomers = getPanelFeeders(secTgtPnl).where((f) => isFeederIncomer(f));
      for (final inc in incomers) {
        final up = inc.details['upstreamFeederId']?.toString().toUpperCase() ?? '';
        if (up == xfmr.id.toUpperCase() ||
            up == xfmr.rawId.toUpperCase() ||
            inc.rawId.toUpperCase().contains(xfmr.rawId.toUpperCase())) {
          final s = inc.details['busSection']?.toString();
          if (s != null && s.isNotEmpty && s != 'None') {
            secSection = s;
            break;
          }
        }
      }
      if (secSection == 'SEC-1' && !isPanelSplitBus(secTgtPnl)) {
        secSection = 'MAIN';
      }
    }

    final tertTgtPnlId = xfmr.details['tertiaryTargetPanelId']?.toString();
    final tertTgtPnl = tertTgtPnlId != null ? findNode(tertTgtPnlId) : null;
    String tertSection = 'SEC-2';
    if (tertTgtPnl != null) {
      if (tertTgtPnl.id == secTgtPnl?.id) {
        tertSection = 'SEC-2';
      } else {
        tertSection = isPanelSplitBus(tertTgtPnl) ? 'SEC-1' : 'MAIN';
        final incomers = getPanelFeeders(tertTgtPnl).where((f) => isFeederIncomer(f));
        for (final inc in incomers) {
          final up = inc.details['upstreamFeederId']?.toString().toUpperCase() ?? '';
          if (up == xfmr.id.toUpperCase() ||
              up == xfmr.rawId.toUpperCase() ||
              inc.rawId.toUpperCase().contains(xfmr.rawId.toUpperCase())) {
            final s = inc.details['busSection']?.toString();
            if (s != null && s.isNotEmpty && s != 'None') {
              tertSection = s;
              break;
            }
          }
        }
      }
    }

    final currentClean = currentPanelId != null ? HierarchyService.stripPrefix(currentPanelId, '', '') : null;
    final isSecCurrent = currentPanelId != null &&
        (secTgtPnlId == currentPanelId ||
            secTgtPnl?.rawId == currentPanelId ||
            secTgtPnl?.id == currentPanelId ||
            (currentClean != null && secTgtPnl?.rawId == currentClean));
    final isTertCurrent = currentPanelId != null &&
        (tertTgtPnlId == currentPanelId ||
            tertTgtPnl?.rawId == currentPanelId ||
            tertTgtPnl?.id == currentPanelId ||
            (currentClean != null && tertTgtPnl?.rawId == currentClean));

    String? connWinding;
    String? connSection;
    if (isSecCurrent) {
      connWinding = 'SECONDARY ($secVolt)';
      connSection = secSection;
    } else if (isTertCurrent) {
      connWinding = 'TERTIARY (${tertVolt ?? "415V"})';
      connSection = tertSection;
    }

    return TransformerWindingRouting(
      transformer: xfmr,
      primaryVoltage: priVolt,
      primarySourcePanelId: priSrcPnlId,
      primarySourceFeederId: priSrcFdrId,
      primarySourceLabel: priLabel,
      secondaryVoltage: secVolt,
      secondaryTargetPanelId: secTgtPnlId,
      secondaryTargetSection: secSection,
      isSecondaryConnectedToCurrent: isSecCurrent,
      hasTertiary: hasTert,
      tertiaryVoltage: tertVolt,
      tertiaryTargetPanelId: tertTgtPnlId,
      tertiaryTargetSection: tertSection,
      isTertiaryConnectedToCurrent: isTertCurrent,
      connectedWindingForCurrent: connWinding,
      connectedSectionForCurrent: connSection,
    );
  }
}

class TransformerWindingRouting {
  final PowerFlowNode transformer;
  // Primary
  final String primaryVoltage;
  final String? primarySourcePanelId;
  final String? primarySourceFeederId;
  final String primarySourceLabel;
  // Secondary
  final String secondaryVoltage;
  final String? secondaryTargetPanelId;
  final String secondaryTargetSection;
  final bool isSecondaryConnectedToCurrent;
  // Tertiary
  final bool hasTertiary;
  final String? tertiaryVoltage;
  final String? tertiaryTargetPanelId;
  final String tertiaryTargetSection;
  final bool isTertiaryConnectedToCurrent;
  // Current SLD connection
  final String? connectedWindingForCurrent;
  final String? connectedSectionForCurrent;

  TransformerWindingRouting({
    required this.transformer,
    required this.primaryVoltage,
    this.primarySourcePanelId,
    this.primarySourceFeederId,
    required this.primarySourceLabel,
    required this.secondaryVoltage,
    this.secondaryTargetPanelId,
    required this.secondaryTargetSection,
    required this.isSecondaryConnectedToCurrent,
    required this.hasTertiary,
    this.tertiaryVoltage,
    this.tertiaryTargetPanelId,
    required this.tertiaryTargetSection,
    required this.isTertiaryConnectedToCurrent,
    this.connectedWindingForCurrent,
    this.connectedSectionForCurrent,
  });
}

class PowerFlowService {
  static final PowerFlowService _instance = PowerFlowService._internal();
  factory PowerFlowService() => _instance;
  PowerFlowService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch and construct the complete Power Flow hierarchy graph for a specific plant & unit
  Future<PowerFlowHierarchy> buildHierarchy({
    required String plantId,
    required String unitId,
  }) async {
    final cleanPlant = plantId.trim();
    final cleanUnit = unitId.trim();

    // 1. Fetch active isolation permits for live LOTO status
    final isolationSnap = await _firestore
        .collection('isolation_permits')
        .where('plantId', isEqualTo: cleanPlant)
        .where('unitId', isEqualTo: cleanUnit)
        .where('status', isEqualTo: 'active')
        .get();

    final activeIsolations = isolationSnap.docs
        .map((d) => IsolationPermitModel.fromMap(d.data(), d.id))
        .toList();

    // Fast lookup for isolated feeder IDs and panel IDs
    final Set<String> isolatedFeederIds = {};
    final Map<String, IsolationPermitModel> feederToPermit = {};

    for (final permit in activeIsolations) {
      if (permit.feederId.isNotEmpty) {
        final raw = HierarchyService.stripPrefix(permit.feederId, cleanPlant, cleanUnit).toUpperCase();
        final full = HierarchyService.prefixId(permit.feederId, cleanPlant, cleanUnit).toUpperCase();
        isolatedFeederIds.add(raw);
        isolatedFeederIds.add(full);
        feederToPermit[raw] = permit;
        feederToPermit[full] = permit;
      }
    }

    final hierarchy = PowerFlowHierarchy(
      plantId: cleanPlant,
      unitId: cleanUnit,
      activeIsolations: activeIsolations,
    );

    // 2. Fetch Locations (Physical Areas) with flexible matching
    final locSnap = await _firestore.collection('locations').get();

    for (final doc in locSnap.docs) {
      final data = doc.data();
      final docPlant = data['plantId']?.toString().toUpperCase();
      final docUnit = data['unitId']?.toString().toUpperCase();
      final targetPlant = cleanPlant.toUpperCase();
      final targetUnit = cleanUnit.toUpperCase();

      bool matches = false;
      if (docPlant == null && docUnit == null) {
        matches = true;
      } else if (docPlant == targetPlant && (docUnit == targetUnit || docUnit == null || targetUnit.isEmpty)) {
        matches = true;
      } else if (doc.id.toUpperCase().startsWith('$targetPlant-$targetUnit-') ||
          doc.id.toUpperCase().startsWith('$targetPlant-')) {
        matches = true;
      }
      if (!matches) continue;

      final loc = LocationModel.fromMap(data, doc.id);
      final raw = HierarchyService.stripPrefix(loc.id, cleanPlant, cleanUnit);
      final node = PowerFlowNode(
        id: loc.id,
        rawId: raw,
        name: loc.name.isNotEmpty ? loc.name : raw,
        level: PowerFlowLevel.area,
        type: loc.type,
        description: loc.description,
        originalModel: loc,
      );
      hierarchy.allNodes[loc.id] = node;
      hierarchy.allNodes[raw] = node;
      hierarchy.rootAreas.add(node);
    }

    // 3. Panel Rooms / Substations are not part of the primary electrical hierarchy.
    // In accordance with DATABASE_SCHEMA.md, only Location (Area) is the physical root.
    // Panels, transformers, and master equipments connect directly to their Location (locationId).

    // 4. Fetch Transformers (Power & Distribution Transformers)
    final xfmrSnap = await _firestore.collection('transformers').get();

    for (final doc in xfmrSnap.docs) {
      final data = doc.data();
      final docPlant = data['plantId']?.toString().toUpperCase();
      final docUnit = data['unitId']?.toString().toUpperCase();
      final targetPlant = cleanPlant.toUpperCase();
      final targetUnit = cleanUnit.toUpperCase();

      bool matches = false;
      if (docPlant == null && docUnit == null) {
        matches = true;
      } else if (docPlant == targetPlant && (docUnit == targetUnit || docUnit == null || targetUnit.isEmpty)) {
        matches = true;
      } else if (doc.id.toUpperCase().startsWith('$targetPlant-$targetUnit-') ||
          doc.id.toUpperCase().startsWith('$targetPlant-')) {
        matches = true;
      }
      if (!matches) continue;

      final xfmr = TransformerModel.fromMap(data, doc.id);
      final raw = HierarchyService.stripPrefix(xfmr.id, cleanPlant, cleanUnit);
      final node = PowerFlowNode(
        id: xfmr.id,
        rawId: raw,
        name: xfmr.name.isNotEmpty ? xfmr.name : raw,
        level: PowerFlowLevel.transformer,
        parentId: xfmr.locationId.isNotEmpty ? xfmr.locationId : null,
        type: xfmr.isThreeWinding ? '3-Winding Transformer' : '2-Winding Transformer',
        description: '${xfmr.ratingKva} kVA | ${xfmr.primaryVoltage} ➔ ${xfmr.secondaryVoltage}${xfmr.tertiaryVoltage != null ? ' / ${xfmr.tertiaryVoltage}' : ''}',
        details: {
          'ratingKva': xfmr.ratingKva,
          'windingType': xfmr.windingType,
          'primaryVoltage': xfmr.primaryVoltage,
          'secondaryVoltage': xfmr.secondaryVoltage,
          'tertiaryVoltage': xfmr.tertiaryVoltage,
          'primarySourceFeederId': xfmr.primarySourceFeederId,
          'secondaryTargetPanelId': xfmr.secondaryTargetPanelId,
          'tertiaryTargetPanelId': xfmr.tertiaryTargetPanelId,
          'locationId': xfmr.locationId,
        },
        originalModel: xfmr,
      );
      hierarchy.allNodes[xfmr.id] = node;
      hierarchy.allNodes[raw] = node;

      // Link to parent Area / Location
      final parentArea = xfmr.locationId.isNotEmpty ? hierarchy.findNode(xfmr.locationId) : null;
      if (parentArea != null) {
        if (!parentArea.children.contains(node)) {
          parentArea.children.add(node);
        }
      }
    }

    // 5. Fetch Panels (MCC / PCC / LDB / Switchboards)
    final panelSnap = await _firestore.collection('panels').get();

    for (final doc in panelSnap.docs) {
      final data = doc.data();
      final docPlant = data['plantId']?.toString().toUpperCase();
      final docUnit = data['unitId']?.toString().toUpperCase();
      final targetPlant = cleanPlant.toUpperCase();
      final targetUnit = cleanUnit.toUpperCase();

      bool matches = false;
      if (docPlant == null && docUnit == null) {
        matches = true;
      } else if (docPlant == targetPlant && (docUnit == targetUnit || docUnit == null || targetUnit.isEmpty)) {
        matches = true;
      } else if (doc.id.toUpperCase().startsWith('$targetPlant-$targetUnit-') ||
          doc.id.toUpperCase().startsWith('$targetPlant-')) {
        matches = true;
      }
      if (!matches) continue;

      final panel = PanelModel.fromMap(data, doc.id);
      final raw = HierarchyService.stripPrefix(panel.id, cleanPlant, cleanUnit);
      final node = PowerFlowNode(
        id: panel.id,
        rawId: raw,
        name: panel.name.isNotEmpty ? panel.name : raw,
        level: PowerFlowLevel.panel,
        parentId: panel.locationId.isNotEmpty
            ? panel.locationId
            : (panel.panelRoomId.isNotEmpty ? panel.panelRoomId : null),
        type: panel.type,
        description: panel.description,
        details: {
          'voltageLevel': panel.voltageLevel,
          'busSections': panel.busSections,
          'locationId': panel.locationId,
          'panelRoomId': panel.panelRoomId,
        },
        originalModel: panel,
      );
      hierarchy.allNodes[panel.id] = node;
      hierarchy.allNodes[raw] = node;

      // Link directly to parent Location (Area), with fallback to panelRoom if locationId is missing
      PowerFlowNode? parent = panel.locationId.isNotEmpty ? hierarchy.findNode(panel.locationId) : null;
      parent ??= panel.panelRoomId.isNotEmpty ? hierarchy.findNode(panel.panelRoomId) : null;

      if (parent != null) {
        if (!parent.children.contains(node)) {
          parent.children.add(node);
        }
      } else {
        hierarchy.orphanPanels.add(node);
      }
    }

    // 6. Fetch Feeders
    final feederSnap = await _firestore.collection('feeders').get();

    for (final doc in feederSnap.docs) {
      final data = doc.data();
      final docPlant = data['plantId']?.toString().toUpperCase();
      final docUnit = data['unitId']?.toString().toUpperCase();
      final targetPlant = cleanPlant.toUpperCase();
      final targetUnit = cleanUnit.toUpperCase();

      bool matches = false;
      if (docPlant == null && docUnit == null) {
        matches = true;
      } else if (docPlant == targetPlant && (docUnit == targetUnit || docUnit == null || targetUnit.isEmpty)) {
        matches = true;
      } else if (doc.id.toUpperCase().startsWith('$targetPlant-$targetUnit-') ||
          doc.id.toUpperCase().startsWith('$targetPlant-')) {
        matches = true;
      }
      if (!matches) continue;

      final feeder = FeederModel.fromMap(data, doc.id);
      final raw = HierarchyService.stripPrefix(feeder.id, cleanPlant, cleanUnit);
      final isIso = isolatedFeederIds.contains(feeder.id.toUpperCase()) ||
          isolatedFeederIds.contains(raw.toUpperCase());
      final permit = feederToPermit[feeder.id.toUpperCase()] ?? feederToPermit[raw.toUpperCase()];

      final node = PowerFlowNode(
        id: feeder.id,
        rawId: raw,
        name: feeder.name.isNotEmpty ? feeder.name : raw,
        level: PowerFlowLevel.feeder,
        parentId: feeder.panelId.isNotEmpty ? feeder.panelId : null,
        type: feeder.type,
        description: feeder.description,
        isIsolated: isIso,
        isolationPermit: permit,
        details: {
          'busSection': feeder.busSection,
          'operatingState': feeder.operatingState,
          'upstreamFeederId': feeder.upstreamFeederId,
          'panelId': feeder.panelId,
        },
        originalModel: feeder,
      );
      hierarchy.allNodes[feeder.id] = node;
      hierarchy.allNodes[raw] = node;

      // Link to parent Panel if available
      final parentPanel = feeder.panelId.isNotEmpty ? hierarchy.findNode(feeder.panelId) : null;
      if (parentPanel != null) {
        if (!parentPanel.children.contains(node)) {
          parentPanel.children.add(node);
        }
      } else {
        hierarchy.orphanFeeders.add(node);
      }
    }

    // 6.5. Auto-synthesize Transformers if referenced by feeders or target panels
    for (final f in hierarchy.allNodes.values.where((n) => n.level == PowerFlowLevel.feeder).toList()) {
      final upId = f.details['upstreamFeederId']?.toString();
      if (upId != null && upId.isNotEmpty && upId != 'None') {
        final upUpper = upId.toUpperCase();
        if ((upUpper.startsWith('TR-') || upUpper.contains('MVA') || upUpper.startsWith('T/F')) &&
            hierarchy.findNode(upId) == null) {
          final isThreeWinding = upUpper.contains('5.5MVA') || upUpper.contains('4MVA');
          final ratingKva = upUpper.contains('5.5') ? 5500.0 : (upUpper.contains('4MVA') ? 4000.0 : 1000.0);
          final secVolt = upUpper.contains('33KV') || upUpper.contains('BLOWER') ? '3.3kV' : '415V';
          final tertVolt = isThreeWinding ? '415V' : null;

          final xfmrNode = PowerFlowNode(
            id: upId,
            rawId: upId,
            name: upId.replaceAll('-', ' '),
            level: PowerFlowLevel.transformer,
            type: isThreeWinding ? '3-Winding Transformer' : '2-Winding Transformer',
            description: '${ratingKva.toInt()} kVA | 11kV ➔ $secVolt${tertVolt != null ? ' / $tertVolt' : ''}',
            details: {
              'ratingKva': ratingKva,
              'windingType': isThreeWinding ? 'three_winding' : 'two_winding',
              'primaryVoltage': '11kV',
              'secondaryVoltage': secVolt,
              'tertiaryVoltage': tertVolt,
              'primarySourceFeederId': 'HTPCC-OG-$upId',
              'secondaryTargetPanelId': f.parentId,
            },
          );
          hierarchy.allNodes[upId] = xfmrNode;
          hierarchy.allNodes[upUpper] = xfmrNode;
        }
      }
    }

    // 7. Fetch Master Equipment
    final meSnap = await _firestore
        .collection('master_equipments')
        .where('plantId', isEqualTo: cleanPlant)
        .where('unitId', isEqualTo: cleanUnit)
        .get();

    for (final doc in meSnap.docs) {
      final me = MasterEquipmentModel.fromMap(doc.data(), doc.id);
      final raw = HierarchyService.stripPrefix(me.id, cleanPlant, cleanUnit);

      // Parent resolution priority: Feeder -> Panel -> Panel Room -> Location
      String? parentId = me.feederId?.isNotEmpty == true
          ? me.feederId
          : (me.panelId?.isNotEmpty == true
              ? me.panelId
              : (me.panelRoomId?.isNotEmpty == true
                  ? me.panelRoomId
                  : (me.locationId.isNotEmpty ? me.locationId : null)));

      final node = PowerFlowNode(
        id: me.id,
        rawId: raw,
        name: me.name.isNotEmpty ? me.name : raw,
        level: PowerFlowLevel.masterEquipment,
        parentId: parentId,
        type: me.type,
        description: me.description,
        details: {
          'area': me.area,
          'feederId': me.feederId,
          'panelId': me.panelId,
          'panelRoomId': me.panelRoomId,
          'locationId': me.locationId,
        },
        originalModel: me,
      );
      hierarchy.allNodes[me.id] = node;
      hierarchy.allNodes[raw] = node;

      // Link to parent Feeder or upstream node
      PowerFlowNode? parentNode;
      if (parentId != null) {
        parentNode = hierarchy.findNode(parentId);
      }
      if (parentNode != null) {
        if (!parentNode.children.contains(node)) {
          parentNode.children.add(node);
        }
      } else {
        hierarchy.orphanEquipments.add(node);
      }
    }

    // 7. Fetch Assets (Drive Motors, Pumps, Actuators, etc.)
    final assetSnap = await _firestore.collection('assets').get();

    for (final doc in assetSnap.docs) {
      final data = doc.data();
      final asset = AssetModel.fromMap(data, doc.id);

      // Check if asset belongs to this plant/unit scope
      final docPlant = data['plantId']?.toString();
      final docUnit = data['unitId']?.toString();
      final prefix = "${cleanPlant.toUpperCase()}-${cleanUnit.toUpperCase()}-";

      bool belongsToScope = false;
      if (docPlant != null && docUnit != null) {
        belongsToScope = docPlant.toUpperCase() == cleanPlant.toUpperCase() &&
            docUnit.toUpperCase() == cleanUnit.toUpperCase();
      } else if (doc.id.toUpperCase().startsWith(prefix) ||
          asset.masterEquipmentId.toUpperCase().startsWith(prefix)) {
        belongsToScope = true;
      } else if (docPlant == null && docUnit == null) {
        // If unscoped directly, check if its masterEquipmentId exists in our current unit's equipment
        if (asset.masterEquipmentId.isNotEmpty &&
            hierarchy.findNode(asset.masterEquipmentId) != null) {
          belongsToScope = true;
        }
      }

      if (!belongsToScope) continue;

      // In an operational Single Line Diagram (SLD), only active (installed/energized at site) assets
      // are connected to the power network. Spares in warehouse/store should not appear as active loads.
      if (asset.status != AssetStatus.active) continue;

      final rawTag = HierarchyService.stripPrefix(asset.tagNo, cleanPlant, cleanUnit);
      final parentEqId = asset.masterEquipmentId.isNotEmpty ? asset.masterEquipmentId : null;

      final node = PowerFlowNode(
        id: asset.id,
        rawId: rawTag,
        name: asset.name.isNotEmpty ? asset.name : rawTag,
        level: PowerFlowLevel.asset,
        parentId: parentEqId,
        type: asset.type.name.toUpperCase(),
        description: asset.description,
        healthStatus: asset.healthStatus,
        details: {
          'powerKw': asset.powerKw,
          'voltage': asset.voltage,
          'fullLoadCurrent': asset.fullLoadCurrent,
          'speedRpm': asset.speedRpm,
          'motorType': asset.motorType,
          'make': asset.make,
          'model': asset.model,
          'serialNo': asset.serialNo,
          'isCritical': asset.isCritical,
        },
        originalModel: asset,
      );
      hierarchy.allNodes[asset.id] = node;
      hierarchy.allNodes[rawTag] = node;

      // Link to parent Master Equipment
      final parentEq = parentEqId != null ? hierarchy.findNode(parentEqId) : null;
      if (parentEq != null) {
        if (!parentEq.children.contains(node)) {
          parentEq.children.add(node);
        }
      } else {
        hierarchy.orphanAssets.add(node);
      }
    }

    return hierarchy;
  }
}
