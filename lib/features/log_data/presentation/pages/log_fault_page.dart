import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/hierarchy_service.dart';
import '../../../../core/utils/permission_helper.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../../core/widgets/pulse_loading.dart';
import '../../../home/presentation/widgets/custom_app_bar.dart';
import '../../../assets/data/models/fault_log_model.dart';
import 'add_fault_log_page.dart';

class LogFaultPage extends StatefulWidget {
  final String? listFilter; // 'Pending', 'Resolved', or null (All)
  final bool showAppBar;
  final String? plantId;
  final String? unitId;

  const LogFaultPage({
    super.key,
    this.listFilter,
    this.showAppBar = true,
    this.plantId,
    this.unitId,
  });

  @override
  State<LogFaultPage> createState() => _LogFaultPageState();
}

class _LogFaultPageState extends State<LogFaultPage> {
  String? _activePlant;
  String? _activeUnit;
  List<String> _plants = [];
  List<String> _units = [];
  bool _isPlantLocked = false;
  bool _isUnitLocked = false;

  @override
  void initState() {
    super.initState();
    _activePlant = widget.plantId;
    _activeUnit = widget.unitId;
    if (widget.showAppBar && (_activePlant == null || _activeUnit == null)) {
      _loadScope();
    }
  }

  @override
  void didUpdateWidget(covariant LogFaultPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.plantId != oldWidget.plantId || widget.unitId != oldWidget.unitId) {
      setState(() {
        _activePlant = widget.plantId;
        _activeUnit = widget.unitId;
      });
    }
  }

  Future<void> _loadScope() async {
    final user = AuthService().currentUser;
    if (user == null) {
      return;
    }

    final profile = await FirestoreService().getUserProfile(user.uid);
    if (profile == null) {
      return;
    }

    final userBusinessId = profile['businessId'] as String? ?? 'VISL';
    await HierarchyService().init(businessId: userBusinessId);

    final userScope = PermissionHelper.resolveUserScope(profile);
    _isPlantLocked = userScope.isPlantLocked;
    _isUnitLocked = userScope.isUnitLocked;

    _plants = userScope.getAvailablePlants();
    _activePlant = widget.plantId ?? userScope.getInitialPlant(_plants);
    if (_activePlant != null) {
      _units = userScope.getAvailableUnits(_activePlant!);
      _activeUnit = widget.unitId ?? userScope.getInitialUnit(_units);
    }

    if (mounted) setState(() {});
  }

  void _updateUnitList() {
    if (_activePlant == null) {
      _units = [];
      _activeUnit = null;
    } else {
      _units = HierarchyService().getUnitsForPlant(_activePlant!);
      if (_units.isEmpty) _units = ['PID1', 'MCD'];
      if (!_units.contains(_activeUnit)) {
        _activeUnit = _units.isNotEmpty ? _units.first : null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = AnimatedGradientBackground(
      child: Column(
        children: [
          // If opened as standalone page, show scope bar
          if (widget.showAppBar && _plants.isNotEmpty) _buildStandaloneScopeBar(),

          Expanded(
            child: StreamBuilder<List<FaultLogModel>>(
              stream: FirestoreService().getAllFaultLogsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: PulseLoading(size: 40));
                }

                var logs = snapshot.data ?? [];

                // 1. Filter by Status (Simplified: Pending vs Closed)
                if (widget.listFilter == 'Pending') {
                  logs = logs.where((l) => l.status == FaultStatus.pending).toList();
                } else if (widget.listFilter == 'Closed' || widget.listFilter == 'Resolved') {
                  logs = logs.where((l) => l.status == FaultStatus.closed).toList();
                }

                // 2. Filter by Scope (Plant & Unit)
                if (_activePlant != null && _activePlant!.isNotEmpty && _activePlant != 'ALL') {
                  logs = logs.where((l) {
                    if (l.plantId != null && l.plantId!.isNotEmpty) {
                      return l.plantId!.toLowerCase() == _activePlant!.toLowerCase();
                    }
                    // Fallback to checking equipment string
                    return l.masterEquipmentId.toUpperCase().contains(_activePlant!.toUpperCase());
                  }).toList();
                }

                if (_activeUnit != null && _activeUnit!.isNotEmpty && _activeUnit != 'ALL') {
                  logs = logs.where((l) {
                    if (l.unitId != null && l.unitId!.isNotEmpty) {
                      return l.unitId!.toLowerCase() == _activeUnit!.toLowerCase();
                    }
                    return l.masterEquipmentId.toUpperCase().contains(_activeUnit!.toUpperCase());
                  }).toList();
                }

                if (logs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 64, color: Theme.of(context).disabledColor),
                        const SizedBox(height: 16),
                        Text(
                          'No fault logs match the current filter or scope.',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return _buildLogCard(context, log);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );

    if (widget.showAppBar) {
      return Scaffold(
        extendBodyBehindAppBar: false,
        appBar: const CustomAppBar(title: 'Log Fault Records'),
        body: content,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddFaultLogPage(
                  masterEquipmentId: '',
                  masterEquipmentName: '',
                  plantId: _activePlant,
                  unitId: _activeUnit,
                ),
              ),
            );
          },
          backgroundColor: AppColors.primaryLight,
          icon: const Icon(Icons.auto_awesome, size: 20, color: Colors.white),
          label: const Text(
            'Log Fault (AI)',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
    } else {
      return content;
    }
  }

  Widget _buildStandaloneScopeBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: GlassContainer(
        borderRadius: 16,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _plants.contains(_activePlant) ? _activePlant : (_plants.isNotEmpty ? _plants.first : null),
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Select Plant', border: InputBorder.none),
                  items: _plants.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: _isPlantLocked
                      ? null
                      : (val) {
                          if (val != null) {
                            setState(() {
                              _activePlant = val;
                              _updateUnitList();
                            });
                          }
                        },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _units.contains(_activeUnit) ? _activeUnit : (_units.isNotEmpty ? _units.first : null),
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Select Unit', border: InputBorder.none),
                  items: _units.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: _isUnitLocked
                      ? null
                      : (val) {
                          if (val != null) {
                            setState(() => _activeUnit = val);
                          }
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildLogCard(BuildContext context, FaultLogModel log) {
    final Color statusColor = log.status == FaultStatus.pending ? Colors.amber : AppColors.success;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showFaultDetailModal(context, log),
          child: GlassContainer(
            width: double.infinity,
            height: null,
            borderRadius: 16,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges Row: Priority + Shift + Discipline + Scope + Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildPriorityBadge(log.priority),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              log.shift.name.toUpperCase(),
                              style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                          ),
                          Text(
                            log.category.name.toUpperCase(),
                            style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                          if (log.plantId != null || log.unitId != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.purple.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${log.plantId ?? ""}${log.unitId != null ? "/${log.unitId}" : ""}',
                                style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 10),
                              ),
                            ),
                        ],
                      ),
                      _buildStatusBadge(log.status, statusColor),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Problem Title
                  Text(
                    log.cause,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Remedial Action Preview if exists
                  if (log.actionTaken.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.build_circle_outlined, size: 13, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            log.actionTaken,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 6),
                  // Master Equipment & Sub-Asset
                  Row(
                    children: [
                      Icon(Icons.precision_manufacturing_outlined, size: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Equipment: ${log.masterEquipmentId}${log.assetId != null && log.assetId!.isNotEmpty ? " • Asset: ${log.assetId}" : ""}',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // ODC Tag if applicable
                  if (log.isOdcApplicable) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (log.isOdcClosed ? Colors.green : Colors.amber).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: (log.isOdcClosed ? Colors.green : Colors.amber).withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.find_in_page_rounded, size: 13, color: log.isOdcClosed ? Colors.green : Colors.amber),
                              const SizedBox(width: 5),
                              Text(
                                log.isOdcClosed ? 'ODC Root-Cause Resolved' : 'ODC Root-Cause Pending',
                                style: TextStyle(
                                  color: log.isOdcClosed ? Colors.green : Colors.amber,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (log.odcObject != null && log.odcObject!.isNotEmpty)
                                _buildOdcPill(Icons.extension_outlined, 'Object: ${log.odcObject}', Colors.purpleAccent),
                              if (log.odcDamage != null && log.odcDamage!.isNotEmpty)
                                _buildOdcPill(Icons.broken_image_outlined, 'Damage: ${log.odcDamage}', Colors.orangeAccent),
                              if (log.odcCause != null && log.odcCause!.isNotEmpty)
                                _buildOdcPill(Icons.psychology_outlined, 'Cause: ${log.odcCause}', Colors.cyanAccent),
                              if (log.odcObject == null && log.odc.isNotEmpty)
                                _buildOdcPill(Icons.info_outline, log.odc, Colors.amberAccent),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Divider(height: 20),

                  // Bottom Metadata Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 12, color: Theme.of(context).disabledColor),
                          const SizedBox(width: 4),
                          Text(
                            '${log.reportedAt.day}/${log.reportedAt.month}/${log.reportedAt.year}',
                            style: TextStyle(color: Theme.of(context).disabledColor, fontSize: 11),
                          ),
                        ],
                      ),
                      if (log.assignedEngineers.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.engineering, size: 13, color: Theme.of(context).disabledColor),
                            const SizedBox(width: 4),
                            Text(
                              '${log.assignedEngineers.length} Staff',
                              style: TextStyle(color: Theme.of(context).disabledColor, fontSize: 11),
                            ),
                          ],
                        ),
                      if (log.downtimeMinutes != null && log.downtimeMinutes! > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.timer_outlined, size: 12, color: Colors.redAccent),
                              const SizedBox(width: 3),
                              Text(
                                '${log.downtimeMinutes}m down',
                                style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOdcPill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityBadge(FaultPriority priority) {
    Color pColor = Colors.grey;
    IconData icon = Icons.info_outline;
    switch (priority) {
      case FaultPriority.critical:
        pColor = Colors.redAccent;
        icon = Icons.warning_rounded;
        break;
      case FaultPriority.high:
        pColor = Colors.orangeAccent;
        icon = Icons.priority_high_rounded;
        break;
      case FaultPriority.medium:
        pColor = Colors.amber;
        icon = Icons.adjust_rounded;
        break;
      case FaultPriority.low:
        pColor = Colors.blueGrey;
        icon = Icons.low_priority_rounded;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: pColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: pColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: pColor),
          const SizedBox(width: 3),
          Text(
            priority.name.toUpperCase(),
            style: TextStyle(color: pColor, fontWeight: FontWeight.bold, fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(FaultStatus status, Color color) {
    final bool isPending = status == FaultStatus.pending;
    final String label = isPending ? 'PENDING' : 'CLOSED';
    final Color badgeColor = isPending ? Colors.amber : Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showFaultDetailModal(BuildContext context, FaultLogModel log) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    _buildPriorityBadge(log.priority),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Fault Record Detail',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildModalSection('Problem / Defect Statement', log.cause, theme,
                        icon: Icons.error_outline, iconColor: Colors.redAccent),
                    if (log.actionTaken.isNotEmpty)
                      _buildModalSection('Remedial Action Taken', log.actionTaken, theme,
                          icon: Icons.build_circle_outlined, iconColor: Colors.greenAccent),
                    _buildModalSection(
                      'Target Asset Information',
                      'Master Equipment: ${log.masterEquipmentId}\nSub-Asset Tag: ${log.assetId ?? "None specified"}\nCategory: ${log.category.name.toUpperCase()}\nShift: ${log.shift.name.toUpperCase()}',
                      theme,
                      icon: Icons.precision_manufacturing_outlined,
                    ),
                    if (log.isOdcApplicable)
                      _buildModalSection(
                        'ODC Root-Cause Analysis (ISO 14224)',
                        [
                          if (log.odcObject != null && log.odcObject!.isNotEmpty) '• Component: ${log.odcObject}',
                          if (log.odcDamage != null && log.odcDamage!.isNotEmpty) '• Damage Mode: ${log.odcDamage}',
                          if (log.odcCause != null && log.odcCause!.isNotEmpty) '• Root Cause: ${log.odcCause}',
                          if (log.odc.isNotEmpty && log.odcObject == null) '• Details: ${log.odc}',
                          '• Status: ${log.isOdcClosed ? "Closed / Resolved" : "Open / Pending Investigation"}'
                        ].join('\n'),
                        theme,
                        icon: Icons.find_in_page_rounded,
                        iconColor: log.isOdcClosed ? Colors.green : Colors.orange,
                      ),
                    _buildModalSection(
                      'Operations & Personnel',
                      'Reported On: ${log.reportedAt}\nReported By: ${log.reportedByUserId}\nDowntime: ${log.downtimeMinutes ?? 0} minutes\nAssigned Personnel: ${log.assignedEngineers.isEmpty ? "None" : log.assignedEngineers.join(", ")}',
                      theme,
                      icon: Icons.schedule,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModalSection(String title, String body, ThemeData theme,
      {IconData? icon, Color? iconColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: iconColor ?? theme.colorScheme.primary),
                const SizedBox(width: 6),
              ],
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}
