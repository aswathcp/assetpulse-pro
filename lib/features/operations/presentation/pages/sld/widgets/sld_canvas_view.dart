import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:asset_pulse_pro/core/constants/app_colors.dart';
import 'package:asset_pulse_pro/core/services/power_flow_service.dart';
import 'package:asset_pulse_pro/features/assets/data/models/asset_model.dart';

enum CanvasFlowMode {
  streamStepper, // Interactive Step-by-Step Upstream & Downstream Focus
  fullCascade,   // Complete Top-to-Bottom Multi-Tier Plant Cascade
}

class SldCanvasView extends StatefulWidget {
  final PowerFlowHierarchy hierarchy;
  final Set<String> highlightedNodeIds;
  final void Function(PowerFlowNode node) onNodeSelected;
  final void Function(PowerFlowNode node)? onNodeDetailsRequested;
  final String? activePanelId;
  final ValueChanged<String?> onActivePanelChanged;

  const SldCanvasView({
    super.key,
    required this.hierarchy,
    required this.highlightedNodeIds,
    required this.onNodeSelected,
    this.onNodeDetailsRequested,
    this.activePanelId,
    required this.onActivePanelChanged,
  });

  @override
  State<SldCanvasView> createState() => _SldCanvasViewState();
}

class _SldCanvasViewState extends State<SldCanvasView> {
  final TransformationController _transformController = TransformationController();
  CanvasFlowMode _flowMode = CanvasFlowMode.streamStepper;
  bool _isSimulationMode = false;

  void _openDetails(PowerFlowNode node) {
    if (widget.onNodeDetailsRequested != null) {
      widget.onNodeDetailsRequested!(node);
    } else {
      widget.onNodeSelected(node);
    }
  }

  void _toggleBreaker(PowerFlowNode feeder) {
    setState(() {
      widget.hierarchy.toggleFeederState(feeder);
    });
  }

  void _resetSimulation() {
    setState(() {
      widget.hierarchy.resetSimulation();
    });
  }

  double _calculateFeederBranchWidth(PowerFlowNode feeder) {
    final ds = widget.hierarchy.getDownstreamPanelForFeeder(feeder);
    if (ds != null && ds.level == PowerFlowLevel.transformer) {
      return 210.0;
    }
    if (ds != null) {
      return 190.0;
    }
    return 180.0;
  }

  double _calculateIncomerBranchWidth(PowerFlowNode incomer) {
    return 185.0;
  }

  double _calculateSectionWidth(List<PowerFlowNode> outgoings, List<PowerFlowNode> incomers) {
    double outTotal = 0;
    for (final f in outgoings) {
      outTotal += _calculateFeederBranchWidth(f);
    }
    double incTotal = 0;
    for (final inc in incomers) {
      incTotal += _calculateIncomerBranchWidth(inc);
    }
    return [outTotal + 16.0, incTotal + 16.0, 260.0].reduce(math.max);
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _resetView() {
    _transformController.value = Matrix4.identity();
  }

  @override
  void didUpdateWidget(covariant SldCanvasView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activePanelId != widget.activePanelId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resetView();
      });
    }
  }

  void _switchFlowMode(CanvasFlowMode mode) {
    setState(() => _flowMode = mode);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _resetView();
    });
  }

  Color _getVoltageColor(String? voltageLevel) {
    if (voltageLevel == null) return const Color(0xFF0284C7);
    final v = voltageLevel.toUpperCase();
    if (v.contains('220KV') || v.contains('132KV') || v.contains('110KV') || v.contains('66KV')) {
      return const Color(0xFFDC2626); // Extra High Voltage (Red)
    }
    if (v.contains('33KV') || v.contains('22KV') || v.contains('11KV')) {
      return const Color(0xFF7C3AED); // High Voltage (Violet / Indigo)
    }
    if (v.contains('6.6KV') || v.contains('3.3KV')) {
      return const Color(0xFFD97706); // Medium Voltage (Amber / Orange)
    }
    return const Color(0xFF0284C7); // Low Voltage 415V / 230V (Cyan / Blue)
  }

  PowerFlowNode? _resolveActiveNode(List<PowerFlowNode> allPanels, List<PowerFlowNode> allTransformers) {
    if (widget.activePanelId != null) {
      final found = widget.hierarchy.findNode(widget.activePanelId!);
      // Ensure only Switchboards or Transformers can be active nodes (never Area/Plant/Feeders)
      if (found != null && (found.level == PowerFlowLevel.panel || found.level == PowerFlowLevel.transformer)) {
        return found;
      }
    }
    // DEFAULT TO TOP-MOST ROOT SWITCHBOARD (11kV / 33kV Incoming HT PCC)
    final rootPanels = widget.hierarchy.getRootHTPanels();
    if (rootPanels.isNotEmpty) return rootPanels.first;
    for (final p in allPanels) {
      if (p.rawId.contains('HT-PCC') || p.rawId.contains('11KV') || p.rawId.contains('33KV')) return p;
    }
    for (final p in allPanels) {
      if (p.rawId.contains('415V-LT-PCC1') || p.rawId.contains('PCC1')) return p;
    }
    if (allPanels.isNotEmpty) return allPanels.first;
    if (allTransformers.isNotEmpty) return allTransformers.first;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panels = widget.hierarchy.panels;
    final transformers = widget.hierarchy.transformers;

    final activeNode = _resolveActiveNode(panels, transformers);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Pinned Controls & Stepper Bar (Never overlaps the diagram!)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: _buildFloatingControlsBar(context, activeNode, panels, transformers, isDark),
        ),

        // Interactive Breaker Trip & Switching Simulation Banner
        if (_isSimulationMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: _buildSimulationBanner(context, isDark),
          ),

        // Interactive Diagram Canvas
        // NOTE: We use InteractiveViewer alone (no nested ScrollViews).
        // Nested ScrollViews inside InteractiveViewer clip content on Flutter Web.
        // InteractiveViewer handles all pan/zoom natively; UnconstrainedBox lets
        // the child declare its own natural size so nothing gets clipped.
        Expanded(
          child: activeNode == null
              ? Center(child: _buildEmptyState(context, isDark))
              : InteractiveViewer(
                  transformationController: _transformController,
                  boundaryMargin: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                  minScale: 0.45,
                  maxScale: 2.2,
                  constrained: false,
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 60),
                    child: _flowMode == CanvasFlowMode.streamStepper
                        ? _buildStreamStepperView(context, activeNode, isDark)
                        : _buildFullCascadeView(context, panels, transformers, isDark),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Container(
      width: 450,
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schema_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No Single Line Diagram Data Found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Import Panels, Feeders, and Transformers in Admin & Hierarchy Setup to visualize the Single Line Diagram.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // FLOATING CONTROLS & STEPPER BAR
  // ==========================================
  Widget _buildFloatingControlsBar(
    BuildContext context,
    PowerFlowNode? activeNode,
    List<PowerFlowNode> panels,
    List<PowerFlowNode> transformers,
    bool isDark,
  ) {
    List<PowerFlowNode> upstreamNodes = [];
    List<PowerFlowNode> downstreamPanels = [];

    if (activeNode != null) {
      if (activeNode.level == PowerFlowLevel.panel) {
        upstreamNodes = widget.hierarchy.getAllUpstreamSourcesForPanel(activeNode);
        downstreamPanels = widget.hierarchy.getDownstreamPanelsForPanel(activeNode);
      } else if (activeNode.level == PowerFlowLevel.transformer) {
        final srcFeederId = activeNode.details['primarySourceFeederId']?.toString();
        if (srcFeederId != null) {
          final srcFeeder = widget.hierarchy.findNode(srcFeederId);
          final up = srcFeeder != null && srcFeeder.parentId != null
              ? widget.hierarchy.findNode(srcFeeder.parentId!)
              : srcFeeder;
          if (up != null) upstreamNodes.add(up);
        }
        final secTarget = activeNode.details['secondaryTargetPanelId']?.toString();
        final tertTarget = activeNode.details['tertiaryTargetPanelId']?.toString();
        if (secTarget != null) {
          final p = widget.hierarchy.findNode(secTarget);
          if (p != null) downstreamPanels.add(p);
        }
        if (tertTarget != null) {
          final p = widget.hierarchy.findNode(tertTarget);
          if (p != null && !downstreamPanels.contains(p)) downstreamPanels.add(p);
        }
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Active entity selector dropdown + Mode switcher + Zoom reset
          Row(
            children: [
              // Active Entity Selector Dropdown
              Expanded(
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                  ),
                  child: Builder(
                    builder: (context) {
                      final seenIds = <String>{};
                      final validItemIds = <String>{};
                      final dropdownItems = <DropdownMenuItem<String?>>[];

                      if (transformers.isNotEmpty) {
                        dropdownItems.add(
                          DropdownMenuItem<String?>(
                            enabled: false,
                            value: '__tr_header__',
                            child: Text(
                              '⚡ TRANSFORMERS (${transformers.length})',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.deepPurpleAccent),
                            ),
                          ),
                        );
                        for (final tr in transformers) {
                          if (seenIds.add(tr.id)) {
                            validItemIds.add(tr.id);
                            dropdownItems.add(
                              DropdownMenuItem<String?>(
                                value: tr.id,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Text(
                                    '⚡ ${tr.rawId} (${tr.details['ratingKva'] ?? 1000} kVA)',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                            );
                          }
                        }
                      }

                      if (panels.isNotEmpty) {
                        dropdownItems.add(
                          DropdownMenuItem<String?>(
                            enabled: false,
                            value: '__panel_header__',
                            child: Text(
                              '⚡ SWITCHBOARDS & MCCS (${panels.length})',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.cyan),
                            ),
                          ),
                        );
                        for (final p in panels) {
                          if (seenIds.add(p.id)) {
                            validItemIds.add(p.id);
                            dropdownItems.add(
                              DropdownMenuItem<String?>(
                                value: p.id,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Text(
                                    '${p.rawId} (${p.details['voltageLevel'] ?? p.type})',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                            );
                          }
                        }
                      }

                      final safeSelectedValue = (activeNode != null && validItemIds.contains(activeNode.id))
                          ? activeNode.id
                          : null;

                      return DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: safeSelectedValue,
                          isExpanded: true,
                          hint: const Text(
                            'Select Switchboard / Transformer',
                            style: TextStyle(fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                          icon: const Icon(Icons.arrow_drop_down, size: 18),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          items: dropdownItems,
                          onChanged: (val) {
                            if (val != null && !val.startsWith('__')) {
                              widget.onActivePanelChanged(val);
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // Flow Mode Switcher: Stream vs Cascade
              Container(
                height: 32,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildModeBtn(
                      label: 'Stream',
                      icon: Icons.alt_route,
                      tooltip: 'Stream Stepper: Focused Feeder SLD (Up & Downstream)',
                      isSelected: _flowMode == CanvasFlowMode.streamStepper,
                      onTap: () => _switchFlowMode(CanvasFlowMode.streamStepper),
                      isDark: isDark,
                    ),
                    _buildModeBtn(
                      label: 'Cascade',
                      icon: Icons.account_tree_outlined,
                      tooltip: 'Plant Cascade: Complete multi-tier schematic tree',
                      isSelected: _flowMode == CanvasFlowMode.fullCascade,
                      onTap: () => _switchFlowMode(CanvasFlowMode.fullCascade),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 6),

              // Reset Zoom & Top Center Button
              Tooltip(
                message: 'Fit & Center to Top (Reset View)',
                child: InkWell(
                  onTap: _resetView,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 32,
                    width: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                    ),
                    child: Icon(
                      Icons.center_focus_strong,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // Interactive Simulation Mode Toggle Button
              Tooltip(
                message: _isSimulationMode
                    ? 'Exit Breaker Trip & Switching Simulation'
                    : 'Enter Interactive Breaker Trip & Switching Simulation Mode',
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _isSimulationMode = !_isSimulationMode;
                      widget.hierarchy.setSimulationActive(_isSimulationMode);
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _isSimulationMode
                          ? Colors.amber.shade700
                          : (isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isSimulationMode
                            ? Colors.amberAccent
                            : (isDark ? Colors.white12 : Colors.black12),
                        width: _isSimulationMode ? 1.5 : 1.0,
                      ),
                      boxShadow: _isSimulationMode
                          ? [
                              BoxShadow(
                                color: Colors.amber.withValues(alpha: 0.3),
                                blurRadius: 6,
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isSimulationMode ? Icons.science : Icons.science_outlined,
                          size: 15,
                          color: _isSimulationMode ? Colors.white : Colors.amber.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isSimulationMode ? 'Sim ON' : 'Sim',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: _isSimulationMode
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Row 2: Electrical Stepper Navigation (Upstream ⬆ and Downstream ⬇)
          Row(
            children: [
              // Upstream Stepper Button (Handles single or multiple upstream sources)
              Expanded(
                child: _buildUpstreamBtn(context, upstreamNodes, isDark),
              ),

              const SizedBox(width: 8),

              // Downstream Stepper Button
              Expanded(
                child: _buildDownstreamBtn(context, downstreamPanels, isDark),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpstreamBtn(BuildContext context, List<PowerFlowNode> upstreamNodes, bool isDark) {
    if (upstreamNodes.isEmpty) {
      return Tooltip(
        message: 'Root Power Source reached',
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.offline_bolt_outlined, size: 13, color: Colors.grey),
              SizedBox(width: 5),
              Flexible(
                child: Text(
                  'Root Source',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (upstreamNodes.length == 1) {
      final node = upstreamNodes.first;
      return Tooltip(
        message: 'Step Upstream to ${node.rawId}',
        child: InkWell(
          onTap: () => widget.onActivePanelChanged(node.id),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.arrow_upward, size: 13, color: Color(0xFF60A5FA)),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'Up: ${node.rawId}',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E40AF),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Multiple upstream sources (e.g. TR-01 feeding Sec-1, TR-02 feeding Sec-2, Captive DG)
    return PopupMenuButton<String>(
      tooltip: 'Select Upstream Source to Step Up (${upstreamNodes.length} available)',
      offset: const Offset(0, 36),
      onSelected: (targetId) => widget.onActivePanelChanged(targetId),
      itemBuilder: (ctx) {
        return upstreamNodes.map((src) {
          final isTr = src.level == PowerFlowLevel.transformer;
          return PopupMenuItem<String>(
            value: src.id,
            child: Row(
              children: [
                Icon(
                  isTr ? Icons.offline_bolt : Icons.developer_board,
                  size: 14,
                  color: isTr ? Colors.deepPurpleAccent : Colors.blueAccent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${src.rawId} (${src.details["voltageLevel"] ?? (isTr ? "Transformer" : src.type)})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.arrow_upward, size: 13, color: Color(0xFF60A5FA)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                'Up (${upstreamNodes.length})',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E40AF),
                ),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF60A5FA)),
          ],
        ),
      ),
    );
  }

  Widget _buildDownstreamBtn(BuildContext context, List<PowerFlowNode> downstreamPanels, bool isDark) {
    final hasDownstream = downstreamPanels.isNotEmpty;
    if (!hasDownstream) {
      return Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.arrow_downward, size: 13, color: Colors.grey),
            SizedBox(width: 5),
            Flexible(
              child: Text(
                'Terminal (0 Down)',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    return PopupMenuButton<String>(
      tooltip: 'Step Downstream to connected panels',
      offset: const Offset(0, 36),
      onSelected: (targetId) => widget.onActivePanelChanged(targetId),
      itemBuilder: (ctx) {
        return downstreamPanels.map((ds) {
          return PopupMenuItem<String>(
            value: ds.id,
            child: Row(
              children: [
                const Icon(Icons.developer_board, size: 14, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${ds.rawId} (${ds.details['voltageLevel'] ?? ds.type})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.35) : const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.arrow_downward, size: 13, color: Color(0xFF10B981)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                'Down (${downstreamPanels.length})',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
                ),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF10B981)),
          ],
        ),
      ),
    );
  }

  Widget _buildModeBtn({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              ),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // SIMULATION MODE CONTROLS & IMPACT REPORT
  // ==========================================
  Widget _buildSimulationBanner(BuildContext context, bool isDark) {
    final impact = widget.hierarchy.calculateSimulationImpact();
    final switchedCount = widget.hierarchy.simulatedFeederStates.length;
    final hasBlackout = impact.totalBlackedOut > 0 || impact.blackedOutPanels.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: hasBlackout ? Colors.amber.shade700 : Colors.green.shade600, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: (hasBlackout ? Colors.amber : Colors.green).withValues(alpha: 0.15),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          // Mode Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.amber.shade700,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.science, size: 13, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'SIMULATION',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Switched count info & Blackout indicator
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showSimulationImpactModal(context, impact, isDark),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      hasBlackout
                          ? '🚨 ${impact.blackedOutPanels.length} Panels, ${impact.totalBlackedOut} Total Units Blacked Out'
                          : (switchedCount == 0
                              ? 'Tap any circuit breaker to simulate switching / tripping'
                              : '⚡ Supply stable across all active loads ($switchedCount switched)'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: hasBlackout
                            ? (isDark ? Colors.amberAccent : Colors.red.shade900)
                            : (isDark ? Colors.greenAccent : Colors.green.shade800),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: hasBlackout
                          ? AppColors.error.withValues(alpha: 0.15)
                          : Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'View Impact 📋',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: hasBlackout ? AppColors.error : Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Reset Button
          if (switchedCount > 0)
            InkWell(
              onTap: _resetSimulation,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, size: 12, color: Theme.of(context).colorScheme.onSurface),
                    const SizedBox(width: 3),
                    Text(
                      'Reset',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(width: 6),

          // Close / Exit Sim Mode Button
          InkWell(
            onTap: () {
              setState(() {
                _isSimulationMode = false;
                widget.hierarchy.setSimulationActive(false);
              });
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.black12,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _showSimulationImpactModal(BuildContext context, SimulationImpact impact, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final currentImpact = widget.hierarchy.calculateSimulationImpact();
            final switchedCount = widget.hierarchy.simulatedFeederStates.length;
            final isBlackout = currentImpact.totalBlackedOut > 0 || currentImpact.blackedOutPanels.isNotEmpty;

            return Container(
              height: MediaQuery.of(context).size.height * 0.82,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131B2E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 25,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Handle
                  Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isBlackout ? Colors.red.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isBlackout ? Icons.warning_amber_rounded : Icons.verified_user_outlined,
                            size: 24,
                            color: isBlackout ? AppColors.error : Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Simulation Impact Assessment',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '$switchedCount Breakers Switched • ${currentImpact.totalBlackedOut} Units Blacked Out',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // Content Body
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      children: [
                        // KPI Grid Row
                        Row(
                          children: [
                            _buildImpactKpiCard('Switched Breakers', '${currentImpact.openBreakers.length}', Colors.amber, isDark),
                            const SizedBox(width: 8),
                            _buildImpactKpiCard('Blacked-Out Panels', '${currentImpact.blackedOutPanels.length}', Colors.red, isDark),
                            const SizedBox(width: 8),
                            _buildImpactKpiCard('Machines Down', '${currentImpact.blackedOutEquipment.length}', Colors.orange, isDark),
                            const SizedBox(width: 8),
                            _buildImpactKpiCard('Assets Down', '${currentImpact.blackedOutAssets.length}', Colors.cyan, isDark),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Simulation Status Alert Box
                        if (!isBlackout)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green, size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Grid Stable - No Downstream Disruption',
                                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.green),
                                      ),
                                      Text(
                                        'All downstream switchboards and machinery maintain active electrical supply through alternate transformers or bus couplers.',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Power Outage / Cascading Blackout Active',
                                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.error),
                                      ),
                                      Text(
                                        '${currentImpact.blackedOutPanels.length} switchboards and ${currentImpact.blackedOutEquipment.length} machines have lost supply due to open breaker positions.',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 18),

                        // Section 1: Simulated Switched Breakers
                        _buildImpactSectionHeader(
                          title: 'SIMULATED OPEN BREAKERS (${currentImpact.openBreakers.length})',
                          color: Colors.amber,
                          icon: Icons.power_settings_new,
                        ),
                        if (currentImpact.openBreakers.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('All breakers in normal closed state.', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                          )
                        else
                          ...currentImpact.openBreakers.map((feeder) {
                            final parentNode = feeder.parentId != null ? widget.hierarchy.findNode(feeder.parentId!) : null;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.radio_button_unchecked, size: 14, color: Colors.amber),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          feeder.rawId,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          'Panel: ${parentNode?.rawId ?? feeder.parentId ?? "N/A"} • ${feeder.name}',
                                          style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      minimumSize: const Size(60, 28),
                                      textStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: () {
                                      _toggleBreaker(feeder);
                                      setModalState(() {});
                                    },
                                    child: const Text('CLOSE'),
                                  ),
                                ],
                              ),
                            );
                          }),

                        const SizedBox(height: 18),

                        // Section 2: Blacked-out Switchboards
                        _buildImpactSectionHeader(
                          title: 'BLACKED-OUT PANELS & SWITCHBOARDS (${currentImpact.blackedOutPanels.length})',
                          color: AppColors.error,
                          icon: Icons.developer_board_off,
                        ),
                        if (currentImpact.blackedOutPanels.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('No panels completely de-energized.', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                          )
                        else
                          ...currentImpact.blackedOutPanels.map((panel) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, size: 16, color: AppColors.error),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          panel.rawId,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.error),
                                        ),
                                        Text(
                                          'Voltage: ${panel.details['voltageLevel'] ?? "415V"} • All Bus Sections De-Energized',
                                          style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: const Size(80, 28),
                                      side: const BorderSide(color: Colors.blueAccent),
                                    ),
                                    icon: const Icon(Icons.open_in_new, size: 12, color: Colors.blueAccent),
                                    label: const Text('View', style: TextStyle(fontSize: 10, color: Colors.blueAccent)),
                                    onPressed: () {
                                      Navigator.pop(modalCtx);
                                      widget.onActivePanelChanged(panel.id);
                                    },
                                  ),
                                ],
                              ),
                            );
                          }),

                        if (currentImpact.partiallyBlackedOutPanels.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _buildImpactSectionHeader(
                            title: 'PARTIAL BUS BLACKOUTS (${currentImpact.partiallyBlackedOutPanels.length})',
                            color: Colors.orange,
                            icon: Icons.alt_route,
                          ),
                          ...currentImpact.partiallyBlackedOutPanels.map((panel) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning, size: 16, color: Colors.orange),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          panel.rawId,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
                                        ),
                                        const Text(
                                          'Split Bus Affected (Tip: Close Bus Coupler to restore via alternate section)',
                                          style: TextStyle(fontSize: 10),
                                        ),
                                      ],
                                    ),
                                  ),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: const Size(60, 28),
                                      side: const BorderSide(color: Colors.blueAccent),
                                    ),
                                    onPressed: () {
                                      Navigator.pop(modalCtx);
                                      widget.onActivePanelChanged(panel.id);
                                    },
                                    child: const Text('View', style: TextStyle(fontSize: 10, color: Colors.blueAccent)),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],

                        const SizedBox(height: 18),

                        // Section 3: Blacked-out Master Equipment & Machinery
                        _buildImpactSectionHeader(
                          title: 'BLACKED-OUT MACHINES & EQUIPMENT (${currentImpact.blackedOutEquipment.length})',
                          color: Colors.orange.shade700,
                          icon: Icons.precision_manufacturing,
                        ),
                        if (currentImpact.blackedOutEquipment.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('No machines without power.', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                          )
                        else
                          ...currentImpact.blackedOutEquipment.map((eq) {
                            final parentNode = eq.parentId != null ? widget.hierarchy.findNode(eq.parentId!) : null;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.flash_off, size: 14, color: Colors.orange),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          eq.rawId,
                                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          '${eq.name} • Supplied from: ${parentNode?.rawId ?? "N/A"}',
                                          style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),

                        const SizedBox(height: 18),

                        // Section 4: Blacked-out Assets
                        if (currentImpact.blackedOutAssets.isNotEmpty) ...[
                          _buildImpactSectionHeader(
                            title: 'BLACKED-OUT DOWNSTREAM ASSETS (${currentImpact.blackedOutAssets.length})',
                            color: Colors.cyan,
                            icon: Icons.devices,
                          ),
                          ...currentImpact.blackedOutAssets.map((asset) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 5),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.circle, size: 8, color: Colors.cyan),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${asset.rawId} - ${asset.name}',
                                      style: const TextStyle(fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),

                  // Bottom Action Footer
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
                    ),
                    child: Row(
                      children: [
                        if (switchedCount > 0)
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(color: AppColors.error),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Reset All Breakers'),
                              onPressed: () {
                                _resetSimulation();
                                setModalState(() {});
                              },
                            ),
                          ),
                        if (switchedCount > 0) const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryLight,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => Navigator.pop(modalCtx),
                            child: const Text('Done / Continue Simulating'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildImpactKpiCard(String label, String value, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImpactSectionHeader({
    required String title,
    required Color color,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // VIEW MODE 1: STEP-BY-STEP POWER STREAM
  // ==========================================
  Widget _buildStreamStepperView(BuildContext context, PowerFlowNode activeNode, bool isDark) {
    final upstreamPath = widget.hierarchy.traceUpstream(activeNode.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 6),

        // Live Breadcrumb Stream Tracker (Only if upstream ancestors exist)
        if (upstreamPath.length > 1) ...[
          _buildBreadcrumbTracker(context, upstreamPath, isDark),
          const SizedBox(height: 10),
        ],

        // MAIN ELECTRICAL SCHEMATIC (Switchboard or Transformer)
        if (activeNode.level == PowerFlowLevel.panel)
          _buildPanelSchematic(context, activeNode, isDark)
        else if (activeNode.level == PowerFlowLevel.transformer)
          _buildTransformerStandAloneBay(context, activeNode, isDark),
      ],
    );
  }

  Widget _buildBreadcrumbTracker(BuildContext context, List<PowerFlowNode> path, bool isDark) {
    if (path.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: [
          const Text(
            'POWER STREAM:',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.cyan, letterSpacing: 0.8),
          ),
          const SizedBox(width: 4),
          for (int i = 0; i < path.length; i++) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                final isNavigable = path[i].level == PowerFlowLevel.panel || path[i].level == PowerFlowLevel.transformer;
                if (isNavigable) {
                  widget.onActivePanelChanged(path[i].id);
                } else {
                  _openDetails(path[i]);
                }
              },
              onLongPress: () {
                widget.onNodeSelected(path[i]);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: path[i].id == widget.activePanelId
                      ? AppColors.primaryLight
                      : (isDark ? const Color(0xFF1E293B) : Colors.white),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: path[i].id == widget.activePanelId
                        ? AppColors.primaryLight
                        : (isDark ? Colors.white12 : Colors.black12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      path[i].level == PowerFlowLevel.transformer
                          ? Icons.offline_bolt
                          : (path[i].level == PowerFlowLevel.feeder
                              ? Icons.power
                              : (path[i].level == PowerFlowLevel.panel ? Icons.developer_board : Icons.location_on)),
                      size: 11,
                      color: path[i].id == widget.activePanelId ? Colors.white : Colors.amber,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      path[i].rawId,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: path[i].id == widget.activePanelId ? Colors.white : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (i < path.length - 1)
              const Icon(Icons.arrow_forward, size: 12, color: Colors.grey),
          ],
        ],
      ),
    );
  }

  Widget _buildUpstreamSourceTargetCard(
    BuildContext context,
    PowerFlowNode incomer,
    bool isDark,
  ) {
    final upstreamSource = incomer.details['upstreamFeederId']?.toString();
    final incomerSection = incomer.details['busSection']?.toString() ?? 'MAIN';

    if (upstreamSource == null || upstreamSource.isEmpty || upstreamSource == 'None') {
      return Container(
        width: 165,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
        ),
        child: const Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.electrical_services, size: 11, color: Colors.red),
                SizedBox(width: 4),
                Text(
                  'UTILITY GRID',
                  style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.red),
                ),
              ],
            ),
            SizedBox(height: 2),
            Text(
              'Primary Grid Infeed',
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    final srcNode = widget.hierarchy.findNode(upstreamSource);
    final rawName = srcNode?.rawId ?? upstreamSource;
    final isTransformer = srcNode != null && srcNode.level == PowerFlowLevel.transformer;
    final isDG = rawName.toUpperCase().contains('DG');
    final isTie = rawName.toUpperCase().contains('TIE');

    Color badgeColor = Colors.deepPurpleAccent;
    IconData badgeIcon = Icons.offline_bolt;
    String badgeTitle = 'UPSTREAM T/F';
    String detailText = 'Infeed ➔ $incomerSection';

    if (isTransformer) {
      badgeColor = Colors.deepPurpleAccent;
      badgeIcon = Icons.offline_bolt;
      badgeTitle = 'UPSTREAM T/F';
      final routing = widget.hierarchy.getTransformerRouting(srcNode, currentPanelId: incomer.parentId);
      final winding = routing.isTertiaryConnectedToCurrent
          ? 'Tertiary (${routing.tertiaryVoltage ?? "415V"})'
          : 'Secondary (${routing.secondaryVoltage})';
      detailText = '$winding ➔ $incomerSection';
    } else if (isDG) {
      badgeColor = Colors.amber.shade700;
      badgeIcon = Icons.bolt;
      badgeTitle = 'CAPTIVE DG';
      detailText = 'Emergency Standby ➔ $incomerSection';
    } else if (isTie) {
      badgeColor = Colors.cyan;
      badgeIcon = Icons.alt_route;
      badgeTitle = 'TIE-IN FEED';
      detailText = 'Bus Tie Infeed ➔ $incomerSection';
    } else {
      badgeColor = Colors.blueAccent;
      badgeIcon = Icons.developer_board;
      badgeTitle = 'UPSTREAM FEED';
      detailText = 'Switchboard ➔ $incomerSection';
    }

    final targetNode = (srcNode != null && srcNode.level == PowerFlowLevel.feeder && srcNode.parentId != null)
        ? (widget.hierarchy.findNode(srcNode.parentId!) ?? srcNode)
        : srcNode;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (srcNode != null) {
          _openDetails(srcNode);
        }
      },
      onLongPress: () {
        if (srcNode != null) {
          widget.onNodeSelected(srcNode);
        }
      },
      child: Container(
        width: 165,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: badgeColor.withValues(alpha: 0.6), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: badgeColor.withValues(alpha: 0.1),
              blurRadius: 5,
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(badgeIcon, size: 11, color: badgeColor),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    badgeTitle,
                    style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: badgeColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              rawName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
            ),
            Text(
              detailText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 8, color: badgeColor, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 5),
            // Step Up button: navigates up to this source ONLY!
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (targetNode != null) {
                  widget.onActivePanelChanged(targetNode.id);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: badgeColor.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'STEP UP',
                      style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_upward, size: 10, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TRANSFORMER SCHEMATIC BLOCKS (VERTICAL FLOW)
  // ==========================================
  Widget _buildTransformerSchematicBlock(
    BuildContext context,
    PowerFlowNode xfmr,
    bool isDark, {
    String? currentPanelId,
    bool isCompact = false,
  }) {
    final routing = widget.hierarchy.getTransformerRouting(xfmr, currentPanelId: currentPanelId);
    final ratingKva = xfmr.details['ratingKva']?.toString() ?? '1000';
    final priColor = _getVoltageColor(routing.primaryVoltage);
    final secColor = _getVoltageColor(routing.secondaryVoltage);
    final tertColor = routing.hasTertiary ? _getVoltageColor(routing.tertiaryVoltage) : Colors.cyan;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _openDetails(xfmr);
      },
      onLongPress: () {
        widget.onNodeSelected(xfmr);
      },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.deepPurpleAccent, width: 1.8),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurpleAccent.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Header: Transformer ID, Rating, Winding Type
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.offline_bolt, size: 16, color: Colors.deepPurpleAccent),
                const SizedBox(width: 6),
                Text(
                  '${xfmr.rawId} • $ratingKva kVA',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.deepPurpleAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    routing.hasTertiary ? '3-WINDING STEP-DOWN' : '2-WINDING STEP-DOWN',
                    style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.deepPurpleAccent),
                  ),
                ),
              ],
            ),

            if (routing.connectedSectionForCurrent != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt, size: 12, color: Color(0xFF00E5FF)),
                    const SizedBox(width: 5),
                    Text(
                      'CONNECTED TO CURRENT SLD: ${routing.connectedWindingForCurrent} ➔ ${routing.connectedSectionForCurrent}',
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFF00E5FF)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // ==========================================
            // 1. PRIMARY WINDING IN TOP (HV SUPPLY)
            // ==========================================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: priColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: priColor.withValues(alpha: 0.45)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_downward, size: 12, color: priColor),
                      const SizedBox(width: 4),
                      Text(
                        'Δ PRIMARY (${routing.primaryVoltage}) — HIGH VOLTAGE INFEED',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: priColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  GestureDetector(
                    onTap: routing.primarySourcePanelId != null
                        ? () => widget.onActivePanelChanged(routing.primarySourcePanelId)
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        'Incoming Feed From: ${routing.primarySourceLabel}',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: routing.primarySourcePanelId != null ? priColor : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Vertical conductor down to Core
            Container(width: 3.5, height: 10, color: priColor),

            // ==========================================
            // 2. MAGNETIC CORE COUPLING (CENTER)
            // ==========================================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.deepPurpleAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('║ ║', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.deepPurpleAccent)),
                  const SizedBox(width: 6),
                  Text(
                    'STEP-DOWN CORE: ${routing.primaryVoltage} ➔ ${routing.secondaryVoltage}${routing.hasTertiary ? ' / ${routing.tertiaryVoltage}' : ''}',
                    style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.deepPurpleAccent),
                  ),
                ],
              ),
            ),

            // Vertical conductor down to Secondary/Tertiary Splitter
            Container(width: 3.5, height: 10, color: Colors.deepPurpleAccent),

            // ==========================================
            // 3. SECONDARY & TERTIARY BRANCH DOWN THE LINE (BOTTOM)
            // ==========================================
            if (!routing.hasTertiary)
              // 2-Winding: Single Secondary down the line
              _buildWindingBranchCard(
                context,
                title: 'Y SECONDARY (${routing.secondaryVoltage})',
                targetPanelId: routing.secondaryTargetPanelId,
                targetSection: routing.secondaryTargetSection,
                color: secColor,
                isCurrentSld: routing.isSecondaryConnectedToCurrent,
                isDark: isDark,
              )
            else
              // 3-Winding: Secondary & Tertiary side-by-side down the line
              Column(
                children: [
                  // Horizontal splitter busbar
                  Container(
                    width: 440,
                    height: 3.5,
                    color: Colors.deepPurpleAccent,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left: Secondary Winding
                      _buildWindingBranchCard(
                        context,
                        title: 'Y SECONDARY (${routing.secondaryVoltage})',
                        targetPanelId: routing.secondaryTargetPanelId,
                        targetSection: routing.secondaryTargetSection,
                        color: secColor,
                        isCurrentSld: routing.isSecondaryConnectedToCurrent,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 14),
                      // Right: Tertiary Winding
                      _buildWindingBranchCard(
                        context,
                        title: 'Y TERTIARY (${routing.tertiaryVoltage})',
                        targetPanelId: routing.tertiaryTargetPanelId,
                        targetSection: routing.tertiaryTargetSection,
                        color: tertColor,
                        isCurrentSld: routing.isTertiaryConnectedToCurrent,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWindingBranchCard(
    BuildContext context, {
    required String title,
    required String? targetPanelId,
    required String targetSection,
    required Color color,
    required bool isCurrentSld,
    required bool isDark,
  }) {
    final panelNode = targetPanelId != null ? widget.hierarchy.findNode(targetPanelId) : null;
    final panelName = panelNode?.rawId ?? targetPanelId ?? 'DOWNSTREAM';

    return Container(
      width: 210,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isCurrentSld
            ? const Color(0xFF00E5FF).withValues(alpha: 0.12)
            : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCurrentSld ? const Color(0xFF00E5FF) : color.withValues(alpha: 0.4),
          width: isCurrentSld ? 1.8 : 1.0,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_downward, size: 11, color: isCurrentSld ? const Color(0xFF00E5FF) : color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: isCurrentSld ? const Color(0xFF00E5FF) : color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),

          // Target Panel & Section Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
            ),
            child: Column(
              children: [
                Text(
                  '➔ $panelName',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isCurrentSld
                        ? const Color(0xFF00E5FF).withValues(alpha: 0.25)
                        : Colors.purple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'BUS SECTION: $targetSection',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: isCurrentSld ? const Color(0xFF00E5FF) : Colors.purpleAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 5),

          // Navigation or Status Pill
          if (isCurrentSld)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '⭐ CURRENT SLD ACTIVE',
                style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.black),
              ),
            )
          else if (targetPanelId != null)
            GestureDetector(
              onTap: () => widget.onActivePanelChanged(targetPanelId),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Jump to $panelName',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(Icons.arrow_forward, size: 9),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTransformerStandAloneBay(BuildContext context, PowerFlowNode xfmr, bool isDark) {
    final routing = widget.hierarchy.getTransformerRouting(xfmr);

    return Column(
      children: [
        _buildTransformerSchematicBlock(context, xfmr, isDark, isCompact: false),
        const SizedBox(height: 20),
        Container(
          width: 3.5,
          height: 30,
          color: Colors.green,
        ),
        const SizedBox(height: 10),
        // Downstream targets row with sections and winding designations
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (routing.secondaryTargetPanelId != null && routing.secondaryTargetPanelId!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildDownstreamPanelTargetCard(
                  context,
                  routing.secondaryTargetPanelId!,
                  isDark,
                  customSection: routing.secondaryTargetSection,
                  windingLabel: 'Secondary (${routing.secondaryVoltage})',
                ),
              ),
            if (routing.hasTertiary && routing.tertiaryTargetPanelId != null && routing.tertiaryTargetPanelId!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildDownstreamPanelTargetCard(
                  context,
                  routing.tertiaryTargetPanelId!,
                  isDark,
                  customSection: routing.tertiaryTargetSection,
                  windingLabel: 'Tertiary (${routing.tertiaryVoltage})',
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // SWITCHBOARD SCHEMATIC (TIER 1, 2, 3)
  // ==========================================
  Widget _buildPanelSchematic(BuildContext context, PowerFlowNode panel, bool isDark) {
    final isPanelHighlighted = widget.highlightedNodeIds.contains(panel.id) ||
        widget.highlightedNodeIds.contains(panel.rawId);

    // Parent Location
    final parentLocation = panel.parentId != null ? widget.hierarchy.findNode(panel.parentId!) : null;
    final locationTag = parentLocation?.rawId ?? panel.details['locationId'] ?? 'PLANT';

    // Voltage & Busbar Colors
    final voltageLevel = panel.details['voltageLevel']?.toString() ?? '415V';
    final busColor = _getVoltageColor(voltageLevel);
    final panelColor = isPanelHighlighted ? const Color(0xFF00E5FF) : busColor;

    // Feeder Categorization
    final allFeeders = widget.hierarchy.getPanelFeeders(panel);
    final incomers = allFeeders.where((f) => widget.hierarchy.isFeederIncomer(f)).toList();
    final couplers = allFeeders.where((f) => widget.hierarchy.isFeederBusCoupler(f)).toList();
    final outgoings = allFeeders.where((f) => !widget.hierarchy.isFeederIncomer(f) && !widget.hierarchy.isFeederBusCoupler(f)).toList();

    // Check split busbar
    final isSplit = widget.hierarchy.isPanelSplitBus(panel);

    // Section 1 vs Section 2 segregation for split bus
    List<PowerFlowNode> incomersSec1 = [];
    List<PowerFlowNode> incomersSec2 = [];
    List<PowerFlowNode> outgoingsSec1 = [];
    List<PowerFlowNode> outgoingsSec2 = [];

    if (isSplit) {
      incomersSec1 = incomers.where((f) =>
          f.details['busSection']?.toString().toUpperCase().contains('SEC-1') == true ||
          f.rawId.toUpperCase().contains('INC-1') ||
          f.rawId.toUpperCase().contains('INCOMER-1') ||
          f.rawId.toUpperCase().contains('INCOMER 1')).toList();

      incomersSec2 = incomers.where((f) =>
          f.details['busSection']?.toString().toUpperCase().contains('SEC-2') == true ||
          f.rawId.toUpperCase().contains('INC-2') ||
          f.rawId.toUpperCase().contains('INCOMER-2') ||
          f.rawId.toUpperCase().contains('INCOMER 2')).toList();

      if (incomersSec1.isEmpty && incomersSec2.isEmpty && incomers.length >= 2) {
        incomersSec1 = [incomers[0]];
        incomersSec2 = [incomers[1]];
      } else if (incomersSec1.isEmpty && incomers.isNotEmpty) {
        incomersSec1 = incomers;
      }

      outgoingsSec1 = outgoings.where((f) {
        final s = f.details['busSection']?.toString().toUpperCase() ?? '';
        return s.contains('SEC-1') || s == '1';
      }).toList();

      outgoingsSec2 = outgoings.where((f) {
        final s = f.details['busSection']?.toString().toUpperCase() ?? '';
        return s.contains('SEC-2') || s == '2';
      }).toList();

      final unassigned = outgoings.where((f) => !outgoingsSec1.contains(f) && !outgoingsSec2.contains(f)).toList();
      if (unassigned.isNotEmpty) {
        final half = (unassigned.length / 2).ceil();
        outgoingsSec1.addAll(unassigned.take(half));
        outgoingsSec2.addAll(unassigned.skip(half));
      }
    } else {
      incomersSec1 = incomers;
      outgoingsSec1 = outgoings;
    }

    // Energization States
    final isSec1Energized = isSplit
        ? widget.hierarchy.isBusSectionEnergized(panel, 'SEC-1')
        : widget.hierarchy.isBusSectionEnergized(panel, 'MAIN');
    final isSec2Energized = isSplit
        ? widget.hierarchy.isBusSectionEnergized(panel, 'SEC-2')
        : false;

    final couplerFeeder = couplers.isNotEmpty ? couplers.first : null;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101726) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPanelHighlighted
              ? const Color(0xFF00E5FF)
              : (isDark ? Colors.white10 : Colors.black12),
          width: isPanelHighlighted ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isPanelHighlighted
                ? const Color(0xFF00E5FF).withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Location Tag Header
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (parentLocation != null) _openDetails(parentLocation);
            },
            onLongPress: () {
              if (parentLocation != null) widget.onNodeSelected(parentLocation);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, size: 13, color: Colors.indigoAccent),
                  const SizedBox(width: 6),
                  Text(
                    'LOCATION: $locationTag',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main Panel Enclosure Header
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openDetails(panel),
            onLongPress: () => widget.onNodeSelected(panel),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: panelColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: panelColor.withValues(alpha: 0.6)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.developer_board, size: 16, color: panelColor),
                      const SizedBox(width: 8),
                      Text(
                        panel.rawId,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Voltage Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: busColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          voltageLevel,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Bus Type Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSplit ? Colors.purple : Colors.blueGrey,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isSplit ? 'SPLIT BUS (SEC-1 | SEC-2)' : 'MAIN BUS',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (panel.name.isNotEmpty && panel.name != panel.rawId) ...[
                    const SizedBox(height: 2),
                    Text(
                      panel.name,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // ==========================================
          // TIER 1: INCOMERS & UPSTREAM FEED
          // ==========================================
          if (!isSplit)
            _buildTier1SingleBusIncomers(context, incomers, busColor, isDark)
          else ...[
            Builder(
              builder: (context) {
                final double widthSec1 = _calculateSectionWidth(outgoingsSec1, incomersSec1);
                final double widthSec2 = _calculateSectionWidth(outgoingsSec2, incomersSec2);

                return Column(
                  children: [
                    _buildTier1SplitBusIncomers(
                      context,
                      incomersSec1: incomersSec1,
                      incomersSec2: incomersSec2,
                      widthSec1: widthSec1,
                      widthSec2: widthSec2,
                      busColor: busColor,
                      isDark: isDark,
                    ),

                    // ==========================================
                    // TIER 2: HORIZONTAL BUSBARS & BUS COUPLER
                    // ==========================================
                    _buildTier2SplitBusbarRow(
                      context,
                      panel: panel,
                      couplerFeeder: couplerFeeder,
                      voltageLevel: voltageLevel,
                      busColor: busColor,
                      widthSec1: widthSec1,
                      widthSec2: widthSec2,
                      outgoingsSec1Count: outgoingsSec1.length,
                      outgoingsSec2Count: outgoingsSec2.length,
                      isSec1Energized: isSec1Energized,
                      isSec2Energized: isSec2Energized,
                      isDark: isDark,
                    ),

                    const SizedBox(height: 2),

                    // ==========================================
                    // TIER 3: OUTGOING FEEDERS & DOWNSTREAM TARGETS
                    // ==========================================
                    _buildTier3SplitBusOutgoings(
                      context,
                      outgoingsSec1: outgoingsSec1,
                      outgoingsSec2: outgoingsSec2,
                      widthSec1: widthSec1,
                      widthSec2: widthSec2,
                      busColor: busColor,
                      isSec1Energized: isSec1Energized,
                      isSec2Energized: isSec2Energized,
                      isDark: isDark,
                    ),
                  ],
                );
              },
            ),
          ],
          if (!isSplit) ...[
            Builder(
              builder: (context) {
                final double singleBusWidth = [
                  outgoings.fold<double>(0, (sum, f) => sum + _calculateFeederBranchWidth(f)) + 16.0,
                  incomers.fold<double>(0, (sum, inc) => sum + _calculateIncomerBranchWidth(inc)) + 16.0,
                  260.0,
                ].reduce(math.max);

                return Column(
                  children: [
                    _buildHorizontalBusbar(
                      context,
                      label: '$voltageLevel / 50Hz MAIN POWER BUSBAR',
                      busColor: busColor,
                      feedersCount: outgoings.length,
                      isEnergized: isSec1Energized,
                      customWidth: singleBusWidth,
                    ),
                    const SizedBox(height: 2),
                    ConstrainedBox(
                      constraints: BoxConstraints(minWidth: singleBusWidth),
                      child: _buildTier3SingleBusOutgoings(context, outgoings, busColor, isSec1Energized, isDark),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------
  // TIER 1 BUILDERS
  // ------------------------------------------
  Widget _buildTier1SingleBusIncomers(
    BuildContext context,
    List<PowerFlowNode> incomers,
    Color busColor,
    bool isDark,
  ) {
    if (incomers.isEmpty) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: busColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: busColor.withValues(alpha: 0.4)),
            ),
            child: const Text(
              '⚡ GRID / TRANSFORMER FEED',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
          Container(width: 3, height: 16, color: busColor),
        ],
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: incomers.map((inc) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildIncomerBranch(context, inc, busColor, isDark),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTier1SplitBusIncomers(
    BuildContext context, {
    required List<PowerFlowNode> incomersSec1,
    required List<PowerFlowNode> incomersSec2,
    required double widthSec1,
    required double widthSec2,
    required Color busColor,
    required bool isDark,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Left Section 1 Incomer Bay
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: widthSec1),
          child: incomersSec1.isEmpty
              ? SizedBox(
                  width: widthSec1,
                  child: _buildDefaultIncomerPill('⚡ INC-1 (SEC-1 SUPPLY)', busColor),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: incomersSec1.map((inc) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _buildIncomerBranch(context, inc, busColor, isDark),
                    );
                  }).toList(),
                ),
        ),

        // Coupler Gap Spacer
        const SizedBox(width: 140),

        // Right Section 2 Incomer Bay
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: widthSec2),
          child: incomersSec2.isEmpty
              ? SizedBox(
                  width: widthSec2,
                  child: _buildDefaultIncomerPill('⚡ INC-2 (SEC-2 SUPPLY)', busColor),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: incomersSec2.map((inc) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _buildIncomerBranch(context, inc, busColor, isDark),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildDefaultIncomerPill(String title, Color busColor) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: busColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: busColor.withValues(alpha: 0.4)),
          ),
          child: Text(
            title,
            style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold),
          ),
        ),
        Container(width: 3, height: 16, color: busColor),
      ],
    );
  }

  Widget _buildIncomerBranch(
    BuildContext context,
    PowerFlowNode incomer,
    Color busColor,
    bool isDark,
  ) {
    final isHighlighted = widget.highlightedNodeIds.contains(incomer.id) ||
        widget.highlightedNodeIds.contains(incomer.rawId);
    final isIsolated = incomer.isIsolated;
    final isConducting = widget.hierarchy.isFeederConducting(incomer);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Upstream Source Target Card with STEP UP button!
        _buildUpstreamSourceTargetCard(context, incomer, isDark),

        // Breaker drop line
        Container(
          width: 3,
          height: 14,
          color: isConducting ? Colors.green : (isIsolated ? AppColors.error : busColor),
        ),

        // Circuit Breaker Symbol (Incomer ACB)
        _buildCircuitBreakerSymbol(context, incomer, isIsolated, isHighlighted, isDark, isIncomer: true),

        // Incomer Feeder Card (Constrained)
        Tooltip(
          message: incomer.rawId,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openDetails(incomer),
            onLongPress: () => widget.onNodeSelected(incomer),
            child: Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              constraints: const BoxConstraints(maxWidth: 160),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isIsolated
                      ? AppColors.error
                      : (isHighlighted ? const Color(0xFF00E5FF) : (isDark ? Colors.white12 : Colors.black12)),
                  width: isHighlighted ? 1.8 : 1.0,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isIsolated ? Icons.lock : Icons.power_input,
                        size: 13,
                        color: isIsolated ? AppColors.error : (isConducting ? Colors.green : Colors.grey),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          incomer.rawId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isIsolated ? AppColors.error : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    isIsolated ? 'LOTO ACTIVE' : (isConducting ? 'CLOSED (ON)' : 'OPEN (OFF)'),
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: isIsolated ? AppColors.error : (isConducting ? Colors.green : Colors.grey),
                    ),
                  ),
                  if (_isSimulationMode && !isIsolated) ...[
                    const SizedBox(height: 3),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _toggleBreaker(incomer),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isConducting ? Colors.red.shade700 : Colors.green.shade700,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isConducting ? 'TRIP / OPEN' : 'CLOSE',
                          style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Final Conductor into busbar
        Container(
          width: 3,
          height: 14,
          color: isConducting ? Colors.green : (isIsolated ? AppColors.error : busColor),
        ),
      ],
    );
  }

  // ------------------------------------------
  // TIER 2 BUILDERS (BUSBARS & BUS COUPLER)
  // ------------------------------------------
  Widget _buildHorizontalBusbar(
    BuildContext context, {
    required String label,
    required Color busColor,
    required int feedersCount,
    required bool isEnergized,
    double? customWidth,
  }) {
    final double busWidth = customWidth ??
        (feedersCount > 0 ? feedersCount * 185.0 : 260.0).clamp(260.0, 1800.0);

    return Container(
      width: busWidth,
      height: 14,
      decoration: BoxDecoration(
        color: isEnergized ? busColor : Colors.grey.shade600,
        borderRadius: BorderRadius.circular(4),
        boxShadow: isEnergized
            ? [
                BoxShadow(
                  color: busColor.withValues(alpha: 0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          isEnergized ? '⚡ $label' : '⊘ $label (DE-ENERGIZED)',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }

  Widget _buildTier2SplitBusbarRow(
    BuildContext context, {
    required PowerFlowNode panel,
    required PowerFlowNode? couplerFeeder,
    required String voltageLevel,
    required Color busColor,
    required double widthSec1,
    required double widthSec2,
    required int outgoingsSec1Count,
    required int outgoingsSec2Count,
    required bool isSec1Energized,
    required bool isSec2Energized,
    required bool isDark,
  }) {

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Section 1 Busbar
        _buildHorizontalBusbar(
          context,
          label: '$voltageLevel SEC-1 BUSBAR',
          busColor: busColor,
          feedersCount: outgoingsSec1Count,
          isEnergized: isSec1Energized,
          customWidth: widthSec1,
        ),

        // Bus Coupler Module bridging Section 1 and Section 2
        _buildBusCouplerSection(
          context,
          panel: panel,
          couplerFeeder: couplerFeeder,
          busColor: busColor,
          isSec1Energized: isSec1Energized,
          isSec2Energized: isSec2Energized,
          isDark: isDark,
        ),

        // Section 2 Busbar
        _buildHorizontalBusbar(
          context,
          label: '$voltageLevel SEC-2 BUSBAR',
          busColor: busColor,
          feedersCount: outgoingsSec2Count,
          isEnergized: isSec2Energized,
          customWidth: widthSec2,
        ),
      ],
    );
  }

  Widget _buildBusCouplerSection(
    BuildContext context, {
    required PowerFlowNode panel,
    required PowerFlowNode? couplerFeeder,
    required Color busColor,
    required bool isSec1Energized,
    required bool isSec2Energized,
    required bool isDark,
  }) {
    final isCouplerConducting = couplerFeeder != null && widget.hierarchy.isFeederConducting(couplerFeeder);
    final isCouplerIsolated = couplerFeeder?.isIsolated ?? false;
    final isHighlighted = couplerFeeder != null &&
        (widget.highlightedNodeIds.contains(couplerFeeder.id) ||
            widget.highlightedNodeIds.contains(couplerFeeder.rawId));

    final bool isBridgingPower = isCouplerConducting && (isSec1Energized != isSec2Energized);

    return SizedBox(
      width: 140,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 4,
                  color: isSec1Energized ? busColor : Colors.grey,
                ),
              ),
              if (couplerFeeder != null)
                _buildCircuitBreakerSymbol(
                  context,
                  couplerFeeder,
                  isCouplerIsolated,
                  isHighlighted,
                  isDark,
                  isCoupler: true,
                )
              else
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey, width: 1.5),
                  ),
                  child: const Center(
                    child: Icon(Icons.link, size: 16, color: Colors.grey),
                  ),
                ),
              Expanded(
                child: Container(
                  height: 4,
                  color: isSec2Energized ? busColor : Colors.grey,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (couplerFeeder != null) _openDetails(couplerFeeder);
            },
            onLongPress: () {
              if (couplerFeeder != null) widget.onNodeSelected(couplerFeeder);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isCouplerIsolated
                      ? AppColors.error
                      : (isHighlighted ? const Color(0xFF00E5FF) : (isCouplerConducting ? Colors.green : Colors.grey)),
                  width: 1.2,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    couplerFeeder?.rawId ?? 'BUS COUPLER',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: isCouplerIsolated ? AppColors.error : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    isCouplerIsolated
                        ? 'LOTO LOCKED'
                        : (isCouplerConducting ? 'COUPLED (CLOSED)' : 'SPLIT (OPEN)'),
                    style: TextStyle(
                      fontSize: 7.5,
                      fontWeight: FontWeight.w900,
                      color: isCouplerIsolated
                          ? AppColors.error
                          : (isCouplerConducting ? Colors.green : Colors.grey),
                    ),
                  ),
                  if (isBridgingPower)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        isSec1Energized ? '➔ TIE ACTIVE ➔' : '⬅ TIE ACTIVE ⬅',
                        style: const TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  if (_isSimulationMode && couplerFeeder != null && !isCouplerIsolated) ...[
                    const SizedBox(height: 3),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _toggleBreaker(couplerFeeder),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isCouplerConducting ? Colors.red.shade700 : Colors.green.shade700,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isCouplerConducting ? 'OPEN COUPLER' : 'CLOSE COUPLER',
                          style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------
  // TIER 3 BUILDERS (OUTGOINGS & DOWNSTREAM CASCADE)
  // ------------------------------------------
  Widget _buildTier3SingleBusOutgoings(
    BuildContext context,
    List<PowerFlowNode> outgoings,
    Color busColor,
    bool isBusEnergized,
    bool isDark,
  ) {
    if (outgoings.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'No outgoing feeders configured on this panel',
          style: TextStyle(
            fontSize: 11.5,
            fontStyle: FontStyle.italic,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: outgoings.map((feeder) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _buildFeederBranch(context, feeder, busColor, isBusEnergized, isDark),
        );
      }).toList(),
    );
  }

  Widget _buildTier3SplitBusOutgoings(
    BuildContext context, {
    required List<PowerFlowNode> outgoingsSec1,
    required List<PowerFlowNode> outgoingsSec2,
    required double widthSec1,
    required double widthSec2,
    required Color busColor,
    required bool isSec1Energized,
    required bool isSec2Energized,
    required bool isDark,
  }) {

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section 1 Outgoings
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: widthSec1),
          child: outgoingsSec1.isEmpty
              ? SizedBox(
                  width: widthSec1,
                  child: _buildEmptySectionPlaceholder('No feeders on Sec-1'),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: outgoingsSec1.map((feeder) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: _buildFeederBranch(context, feeder, busColor, isSec1Energized, isDark),
                    );
                  }).toList(),
                ),
        ),

        // Coupler Width Spacer
        const SizedBox(width: 140),

        // Section 2 Outgoings
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: widthSec2),
          child: outgoingsSec2.isEmpty
              ? SizedBox(
                  width: widthSec2,
                  child: _buildEmptySectionPlaceholder('No feeders on Sec-2'),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: outgoingsSec2.map((feeder) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: _buildFeederBranch(context, feeder, busColor, isSec2Energized, isDark),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptySectionPlaceholder(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildFeederBranch(
    BuildContext context,
    PowerFlowNode feeder,
    Color busColor,
    bool isBusEnergized,
    bool isDark,
  ) {
    final isFeederHighlighted = widget.highlightedNodeIds.contains(feeder.id) ||
        widget.highlightedNodeIds.contains(feeder.rawId);
    final isIsolated = feeder.isIsolated;
    final isFeederLive = isBusEnergized && widget.hierarchy.isFeederEnergized(feeder);

    // Check if this feeder feeds a downstream panel or transformer!
    final downstreamPanel = widget.hierarchy.getDownstreamPanelForFeeder(feeder);

    // Children of feeder (Master Equipments)
    final equipments = feeder.children.where((c) => c.level == PowerFlowLevel.masterEquipment).toList();

    return Column(
      children: [
        // Drop line from busbar
        Container(
          width: 2.5,
          height: 16,
          color: isIsolated
              ? AppColors.error
              : (isFeederLive ? Colors.green : (isFeederHighlighted ? const Color(0xFF00E5FF) : Colors.grey)),
        ),

        // Circuit Breaker / Switch Symbol
        _buildCircuitBreakerSymbol(context, feeder, isIsolated, isFeederHighlighted, isDark),

        // Feeder Card
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openDetails(feeder),
          onLongPress: () => widget.onNodeSelected(feeder),
          child: Container(
            width: 145,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isIsolated
                    ? AppColors.error
                    : (isFeederHighlighted ? const Color(0xFF00E5FF) : (isDark ? Colors.white12 : Colors.black12)),
                width: isFeederHighlighted ? 1.8 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isIsolated ? Icons.lock : Icons.electric_bolt,
                      size: 13,
                      color: isIsolated ? AppColors.error : (isFeederLive ? Colors.blueAccent : Colors.grey),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        feeder.rawId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isIsolated ? AppColors.error : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isIsolated
                      ? 'LOTO ACTIVE'
                      : (isFeederLive ? 'ENERGIZED' : 'OPEN / OFF'),
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: isIsolated ? AppColors.error : (isFeederLive ? Colors.green : Colors.grey),
                  ),
                ),
                if (_isSimulationMode && !isIsolated) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _toggleBreaker(feeder),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.hierarchy.isFeederConducting(feeder)
                            ? Colors.red.shade700
                            : Colors.green.shade700,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.hierarchy.isFeederConducting(feeder) ? 'TRIP / OPEN' : 'CLOSE',
                        style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Conductor Drop Line down to downstream entity
        Container(
          width: 2.5,
          height: 18,
          color: isIsolated
              ? AppColors.error.withValues(alpha: 0.4)
              : (isFeederLive ? Colors.green.withValues(alpha: 0.7) : Colors.grey.shade400),
        ),

        // DOWNSTREAM TARGET: PANEL vs MACHINE vs DIRECT TAP
        if (downstreamPanel != null)
          _buildDownstreamPanelTargetCard(context, downstreamPanel.id, isDark)
        else if (equipments.isNotEmpty)
          Column(
            children: equipments.map((eq) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildEquipmentBlock(context, eq, isIsolated, isFeederLive, isDark),
              );
            }).toList(),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF182234) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: Text(
              'Spare / Direct Tap',
              style: TextStyle(
                fontSize: 9.5,
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDownstreamPanelTargetCard(
    BuildContext context,
    String panelId,
    bool isDark, {
    String? customSection,
    String? windingLabel,
  }) {
    final dsPanel = widget.hierarchy.findNode(panelId);
    final rawName = dsPanel?.rawId ?? panelId;
    final volt = dsPanel?.details['voltageLevel']?.toString() ?? '415V';

    // If downstream recipient is a Transformer:
    if (dsPanel != null && dsPanel.level == PowerFlowLevel.transformer) {
      final routing = widget.hierarchy.getTransformerRouting(dsPanel);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // Tapping card body opens the detail page
          _openDetails(dsPanel);
        },
        onLongPress: () {
          widget.onNodeSelected(dsPanel);
        },
        child: Container(
          width: 175,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF3E8FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.deepPurpleAccent.withValues(alpha: 0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.deepPurpleAccent.withValues(alpha: 0.12),
                blurRadius: 6,
              ),
            ],
          ),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.offline_bolt, size: 12, color: Colors.deepPurpleAccent),
                  SizedBox(width: 4),
                  Text(
                    'DOWNSTREAM T/F',
                    style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.deepPurpleAccent),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                rawName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              Text(
                '${routing.primaryVoltage} ➔ ${routing.secondaryVoltage}${routing.hasTertiary ? "/ ${routing.tertiaryVoltage}" : ""}',
                style: const TextStyle(fontSize: 8.5, color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              // Targets summary with direct branch step-down buttons
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  children: [
                    if (routing.secondaryTargetPanelId != null && routing.secondaryTargetPanelId!.isNotEmpty)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          widget.onActivePanelChanged(routing.secondaryTargetPanelId!);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.subdirectory_arrow_right, size: 10, color: Colors.amber),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  'Sec: ${routing.secondaryTargetPanelId} [${routing.secondaryTargetSection}]',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: isDark ? Colors.amberAccent : Colors.amber.shade900),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (routing.hasTertiary && routing.tertiaryTargetPanelId != null && routing.tertiaryTargetPanelId!.isNotEmpty)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          widget.onActivePanelChanged(routing.tertiaryTargetPanelId!);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.subdirectory_arrow_right, size: 10, color: Colors.cyan),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  'Tert: ${routing.tertiaryTargetPanelId} [${routing.tertiaryTargetSection}]',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: isDark ? Colors.cyanAccent : Colors.cyan.shade900),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // Step Down button: opens branch selector or steps down to single branch
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (routing.hasTertiary && routing.tertiaryTargetPanelId != null && routing.tertiaryTargetPanelId!.isNotEmpty) {
                    _showBranchStepDownSheet(context, dsPanel, routing, isDark);
                  } else if (routing.secondaryTargetPanelId != null && routing.secondaryTargetPanelId!.isNotEmpty) {
                    widget.onActivePanelChanged(routing.secondaryTargetPanelId!);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: Colors.deepPurpleAccent,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurpleAccent.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'STEP DOWN',
                        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_downward, size: 10, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // Tapping card body opens the detail page
        if (dsPanel != null) _openDetails(dsPanel);
      },
      onLongPress: () {
        if (dsPanel != null) widget.onNodeSelected(dsPanel);
      },
      child: Container(
        width: 155,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withValues(alpha: 0.1),
              blurRadius: 6,
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.arrow_downward, size: 12, color: Colors.blueAccent),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    windingLabel ?? 'DOWNSTREAM',
                    style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              rawName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            Text(
              volt,
              style: TextStyle(fontSize: 9, color: _getVoltageColor(volt), fontWeight: FontWeight.w600),
            ),
            if (customSection != null) ...[
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'SECTION: $customSection',
                  style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.purpleAccent),
                ),
              ),
            ],
            const SizedBox(height: 6),
            // Step Down button: navigates the canvas down to this panel
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                widget.onActivePanelChanged(dsPanel?.id ?? panelId);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'STEP DOWN',
                      style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_downward, size: 10, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBranchStepDownSheet(
    BuildContext context,
    PowerFlowNode transformerNode,
    TransformerWindingRouting routing,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131B2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black12,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.offline_bolt, color: Colors.deepPurpleAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Step Down: ${transformerNode.rawId}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          'Select which downstream switchboard branch to view on SLD canvas',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Option 1: Secondary Winding
              if (routing.secondaryTargetPanelId != null && routing.secondaryTargetPanelId!.isNotEmpty)
                _buildBranchSelectionTile(
                  ctx,
                  title: 'Secondary Winding (${routing.secondaryVoltage})',
                  targetPanelId: routing.secondaryTargetPanelId!,
                  targetSection: routing.secondaryTargetSection,
                  color: Colors.amber.shade700,
                  isDark: isDark,
                ),

              const SizedBox(height: 10),

              // Option 2: Tertiary Winding
              if (routing.hasTertiary && routing.tertiaryTargetPanelId != null && routing.tertiaryTargetPanelId!.isNotEmpty)
                _buildBranchSelectionTile(
                  ctx,
                  title: 'Tertiary Winding (${routing.tertiaryVoltage})',
                  targetPanelId: routing.tertiaryTargetPanelId!,
                  targetSection: routing.tertiaryTargetSection,
                  color: Colors.cyan,
                  isDark: isDark,
                ),

              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBranchSelectionTile(
    BuildContext ctx, {
    required String title,
    required String targetPanelId,
    required String targetSection,
    required Color color,
    required bool isDark,
  }) {
    final panelNode = widget.hierarchy.findNode(targetPanelId);
    final displayName = panelNode?.rawId ?? targetPanelId;

    return InkWell(
      onTap: () {
        Navigator.pop(ctx);
        widget.onActivePanelChanged(panelNode?.id ?? targetPanelId);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.developer_board, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'Busbar Target: $targetSection',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildCircuitBreakerSymbol(
    BuildContext context,
    PowerFlowNode feeder,
    bool isIsolated,
    bool isHighlighted,
    bool isDark, {
    bool isCoupler = false,
    bool isIncomer = false,
  }) {
    final isConducting = widget.hierarchy.isFeederConducting(feeder);
    final isSimulated = widget.hierarchy.isFeederSimulated(feeder);

    final strokeColor = isIsolated
        ? AppColors.error
        : (_isSimulationMode && isSimulated
            ? Colors.amberAccent
            : (isHighlighted ? const Color(0xFF00E5FF) : (isConducting ? Colors.green : Colors.grey)));

    final tooltipMsg = _isSimulationMode
        ? (isIsolated
            ? 'Breaker Tagged Out (LOTO) - Cannot switch in simulation'
            : 'SIMULATION: Tap to ${isConducting ? "OPEN (Trip)" : "CLOSE"} ${feeder.rawId}')
        : (isIsolated
            ? 'Breaker OPEN - Tagged Out (LOTO)'
            : (isConducting ? 'Breaker CLOSED - Conducting' : 'Breaker OPEN - Off'));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_isSimulationMode) {
          if (!isIsolated) {
            _toggleBreaker(feeder);
          }
        } else {
          _openDetails(feeder);
        }
      },
      onLongPress: () {
        widget.onNodeSelected(feeder);
      },
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Tooltip(
            message: tooltipMsg,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isCoupler ? 36 : 30,
              height: isCoupler ? 36 : 30,
              decoration: BoxDecoration(
                color: isIsolated
                    ? AppColors.error.withValues(alpha: 0.15)
                    : (isConducting
                        ? Colors.green.withValues(alpha: 0.15)
                        : (isDark ? Colors.white10 : Colors.black12)),
                shape: BoxShape.circle,
                border: Border.all(
                  color: strokeColor,
                  width: _isSimulationMode && isSimulated ? 2.5 : 1.8,
                ),
                boxShadow: isConducting && !isIsolated
                    ? [
                        BoxShadow(
                          color: (_isSimulationMode && isSimulated ? Colors.amberAccent : Colors.green)
                              .withValues(alpha: 0.4),
                          blurRadius: _isSimulationMode && isSimulated ? 8 : 6,
                        )
                      ]
                    : null,
              ),
              child: Center(
                child: Icon(
                  isIsolated ? Icons.lock : (isConducting ? Icons.power : Icons.power_off),
                  size: isCoupler ? 18 : 15,
                  color: strokeColor,
                ),
              ),
            ),
          ),
          if (_isSimulationMode && isSimulated)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.science,
                  size: 9,
                  color: Colors.black,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEquipmentBlock(
    BuildContext context,
    PowerFlowNode eq,
    bool isParentIsolated,
    bool isParentLive,
    bool isDark,
  ) {
    final isEqHighlighted = widget.highlightedNodeIds.contains(eq.id) ||
        widget.highlightedNodeIds.contains(eq.rawId);
    final assets = eq.children.where((c) => c.level == PowerFlowLevel.asset).toList();

    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openDetails(eq),
          onLongPress: () => widget.onNodeSelected(eq),
          child: Container(
            width: 145,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131D30) : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isEqHighlighted
                    ? const Color(0xFF00E5FF)
                    : (isDark ? Colors.teal.withValues(alpha: 0.4) : Colors.teal.shade200),
                width: isEqHighlighted ? 1.8 : 1.0,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.precision_manufacturing, size: 14, color: Colors.teal),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        eq.rawId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                if (eq.name.isNotEmpty && eq.name != eq.rawId) ...[
                  const SizedBox(height: 2),
                  Text(
                    eq.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Cable drop to terminal load assets
        if (assets.isNotEmpty) ...[
          Container(
            width: 2.5,
            height: 14,
            color: isEqHighlighted ? const Color(0xFF00E5FF) : (isParentLive ? Colors.teal : Colors.grey.shade400),
          ),
          Column(
            children: assets.map((asset) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _buildAssetTerminal(context, asset, isParentIsolated, isParentLive, isDark),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildAssetTerminal(
    BuildContext context,
    PowerFlowNode asset,
    bool isParentIsolated,
    bool isParentLive,
    bool isDark,
  ) {
    final isAssetHighlighted = widget.highlightedNodeIds.contains(asset.id) ||
        widget.highlightedNodeIds.contains(asset.rawId);

    final powerKw = asset.details['powerKw'];
    final voltage = asset.details['voltage'];
    final flc = asset.details['fullLoadCurrent'];

    Color statusColor = Colors.green;
    if (asset.healthStatus == AssetHealthStatus.warning) statusColor = Colors.amber;
    if (asset.healthStatus == AssetHealthStatus.critical) statusColor = Colors.red;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openDetails(asset),
      onLongPress: () => widget.onNodeSelected(asset),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0D1829) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isAssetHighlighted
                ? const Color(0xFF00E5FF)
                : (isDark ? Colors.white12 : Colors.black12),
            width: isAssetHighlighted ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isAssetHighlighted ? const Color(0xFF00E5FF) : (isParentLive ? Colors.green : Colors.grey),
                  width: 1.5,
                ),
                color: isDark ? Colors.black26 : Colors.green.withValues(alpha: 0.1),
              ),
              child: Center(
                child: Text(
                  'M',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: isAssetHighlighted ? const Color(0xFF00E5FF) : (isParentLive ? Colors.green : Colors.grey),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          asset.rawId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                      ),
                    ],
                  ),
                  if (powerKw != null || voltage != null || flc != null)
                    Text(
                      [
                        if (powerKw != null) '$powerKw kW',
                        if (flc != null) '$flc A',
                      ].join(' • '),
                      style: TextStyle(
                        fontSize: 8.5,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // VIEW MODE 2: FULL MULTI-TIER CASCADING SLD (OVERVIEW)
  // ==========================================
  Widget _buildFullCascadeView(
    BuildContext context,
    List<PowerFlowNode> panels,
    List<PowerFlowNode> transformers,
    bool isDark,
  ) {
    // 1. HT Panels (Tier 1: 11kV / 33kV)
    final htPanels = panels.where((p) {
      final tier = widget.hierarchy.getNodeTier(p);
      final raw = p.rawId.toUpperCase();
      final volt = p.details['voltageLevel']?.toString().toUpperCase() ?? '';
      return tier == 1 || volt.contains('11KV') || volt.contains('33KV') || raw.contains('HT-PCC');
    }).toList();

    if (htPanels.isEmpty) {
      htPanels.addAll(widget.hierarchy.getRootHTPanels());
    }

    // 2. PCCs and MDCs (Tier 3)
    final pccPanels = panels.where((p) {
      if (htPanels.contains(p)) return false;
      final raw = p.rawId.toUpperCase();
      final volt = p.details['voltageLevel']?.toString().toUpperCase() ?? '';
      final tier = widget.hierarchy.getNodeTier(p);
      return tier == 3 || raw.contains('PCC') || raw.contains('MDC') || volt.contains('3.3KV');
    }).toList();

    // 3. MCCs and Sub-Distribution (Tier 4)
    final mccPanels = panels.where((p) {
      return !htPanels.contains(p) && !pccPanels.contains(p);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mode Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.cyan.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_tree_outlined, size: 16, color: Colors.cyan),
              const SizedBox(width: 8),
              Text(
                'PLANT ELECTRICAL CASCADE OVERVIEW (${panels.length} Switchboards, ${transformers.length} Transformers)',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.cyan),
              ),
              const SizedBox(width: 12),
              const Text(
                '• Tap any board to inspect detailed SLD & circuit breakers',
                style: TextStyle(fontSize: 10.5, color: Colors.grey),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // TIER 1: HIGH VOLTAGE SWITCHGEAR & GENERATION
        _buildCascadeTierHeader('TIER 1: HIGH VOLTAGE SWITCHGEAR & PRIMARY INCOMERS (11kV / 33kV)', const Color(0xFF7C3AED)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: htPanels.map((p) => _buildCascadePanelCard(context, p, isDark)).toList(),
        ),

        const SizedBox(height: 12),
        _buildVerticalCascadeBusLine(const Color(0xFF7C3AED)),
        const SizedBox(height: 12),

        // TIER 2: STEP-DOWN POWER TRANSFORMERS
        if (transformers.isNotEmpty) ...[
          _buildCascadeTierHeader('TIER 2: STEP-DOWN DISTRIBUTION TRANSFORMERS (11kV ➔ 3.3kV / 415V)', Colors.deepPurpleAccent),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: transformers.map((tr) => _buildCascadeTransformerCard(context, tr, isDark)).toList(),
          ),
          const SizedBox(height: 12),
          _buildVerticalCascadeBusLine(const Color(0xFF0284C7)),
          const SizedBox(height: 12),
        ],

        // TIER 3: MAIN POWER CONTROL CENTERS (PCCs & MDCs)
        if (pccPanels.isNotEmpty) ...[
          _buildCascadeTierHeader('TIER 3: MAIN POWER CONTROL CENTERS (PCCs & MDCs)', const Color(0xFF0284C7)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: pccPanels.map((p) => _buildCascadePanelCard(context, p, isDark)).toList(),
          ),
          const SizedBox(height: 12),
          _buildVerticalCascadeBusLine(const Color(0xFFD97706)),
          const SizedBox(height: 12),
        ],

        // TIER 4: MOTOR CONTROL CENTERS (MCCs)
        if (mccPanels.isNotEmpty) ...[
          _buildCascadeTierHeader('TIER 4: MOTOR CONTROL CENTERS (MCCs) & SUB-DISTRIBUTION (${mccPanels.length})', const Color(0xFFD97706)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: mccPanels.map((p) => _buildCascadePanelCard(context, p, isDark)).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildCascadePanelCard(BuildContext context, PowerFlowNode panel, bool isDark) {
    final volt = panel.details['voltageLevel']?.toString() ?? '415V';
    final voltColor = _getVoltageColor(volt);
    final isSplit = widget.hierarchy.isPanelSplitBus(panel);
    final feeders = widget.hierarchy.getPanelFeeders(panel);
    final incomers = feeders.where((f) => widget.hierarchy.isFeederIncomer(f)).toList();
    final outgoings = feeders.where((f) => !widget.hierarchy.isFeederIncomer(f) && !widget.hierarchy.isFeederBusCoupler(f)).toList();
    final couplers = feeders.where((f) => widget.hierarchy.isFeederBusCoupler(f)).toList();
    final isHighlighted = widget.highlightedNodeIds.contains(panel.id);

    return Container(
      width: 290,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHighlighted
              ? const Color(0xFF00E5FF)
              : voltColor.withValues(alpha: isDark ? 0.6 : 0.8),
          width: isHighlighted ? 2.2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: voltColor.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            widget.onActivePanelChanged(panel.id);
            _switchFlowMode(CanvasFlowMode.streamStepper);
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header: Voltage & Type Badges + Live Energized dot
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: voltColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: voltColor.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        volt,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: voltColor,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'ENERGIZED',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Panel ID & Name
                Text(
                  panel.rawId,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (panel.name.isNotEmpty && panel.name != panel.rawId) ...[
                  const SizedBox(height: 2),
                  Text(
                    panel.name,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 8),

                // Bus configuration & Coupler
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.linear_scale, size: 13, color: voltColor),
                        const SizedBox(width: 4),
                        Text(
                          isSplit ? 'Split Bus (Sec 1 & 2)' : 'Single Bus (Main)',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isSplit ? Colors.cyan : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    if (couplers.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          couplers.first.rawId,
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 6),

                // Incomers & Outgoings stats
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${incomers.length} Incomer${incomers.length == 1 ? "" : "s"}',
                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${outgoings.length} Feeders',
                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Button: Inspect Feeder SLD
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Inspect Feeder SLD',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: voltColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 12, color: voltColor),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCascadeTransformerCard(BuildContext context, PowerFlowNode tr, bool isDark) {
    final routing = widget.hierarchy.getTransformerRouting(tr);
    final ratingKva = tr.details['ratingKva']?.toString() ?? '1000';
    final priVolt = tr.details['primaryVoltage']?.toString() ?? '11kV';
    final secVolt = tr.details['secondaryVoltage']?.toString() ?? '415V';
    final tertVolt = tr.details['tertiaryVoltage']?.toString();
    final hasTert = tertVolt != null && tertVolt.isNotEmpty && tertVolt != 'None';

    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.deepPurpleAccent.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurpleAccent.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            widget.onActivePanelChanged(tr.id);
            _switchFlowMode(CanvasFlowMode.streamStepper);
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.deepPurpleAccent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.deepPurpleAccent.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        hasTert ? '3-WINDING' : '2-WINDING',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.deepPurpleAccent,
                        ),
                      ),
                    ),
                    Text(
                      '$ratingKva kVA',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  tr.rawId,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasTert ? '$priVolt ➔ $secVolt & $tertVolt' : '$priVolt ➔ $secVolt',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.cyan),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Text(
                  'Primary Infeed: ${routing.primarySourcePanelId ?? "HT GRID"}',
                  style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Secondary ➔ ${routing.secondaryTargetPanelId ?? "Downstream"}',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (hasTert) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Tertiary ➔ ${routing.tertiaryTargetPanelId ?? "Downstream"}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.blueAccent),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Inspect Transformer',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurpleAccent,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 12, color: Colors.deepPurpleAccent),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCascadeTierHeader(String title, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        title,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.8),
      ),
    );
  }

  Widget _buildVerticalCascadeBusLine(Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 3.5, height: 22, color: color),
          Icon(Icons.keyboard_arrow_down, size: 18, color: color),
        ],
      ),
    );
  }
}
