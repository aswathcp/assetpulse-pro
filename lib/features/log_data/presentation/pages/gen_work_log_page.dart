import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_roles.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/hierarchy_service.dart';
import '../../../../core/utils/permission_helper.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../../core/widgets/pulse_loading.dart';
import '../../../home/presentation/widgets/custom_app_bar.dart';
import '../../data/models/general_work_log_model.dart';
import '../../utils/whatsapp_log_parser.dart';
import 'add_gen_work_log_page.dart';

class GenWorkLogPage extends StatefulWidget {
  final bool showAppBar;
  final String? listFilter; // 'Pending', 'Completed', or 'All'
  final String? plantId;
  final String? unitId;

  const GenWorkLogPage({
    super.key,
    this.showAppBar = true,
    this.listFilter,
    this.plantId,
    this.unitId,
  });

  @override
  State<GenWorkLogPage> createState() => _GenWorkLogPageState();
}

class _GenWorkLogPageState extends State<GenWorkLogPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();

  String? _activePlant;
  String? _activeUnit;
  List<String> _plants = [];
  List<String> _units = [];
  bool _isPlantLocked = false;
  bool _isUnitLocked = false;
  bool _isLoadingScope = false;
  String _userRole = '';
  String _currentFilter = 'All'; // 'All', 'Completed', 'Pending'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _activePlant = widget.plantId;
    _activeUnit = widget.unitId;
    _currentFilter = widget.listFilter ?? 'All';

    if (widget.showAppBar && (_activePlant == null || _activeUnit == null)) {
      _loadScope();
    }
  }

  @override
  void didUpdateWidget(covariant GenWorkLogPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.plantId != oldWidget.plantId || widget.unitId != oldWidget.unitId) {
      setState(() {
        _activePlant = widget.plantId;
        _activeUnit = widget.unitId;
      });
    }
    if (widget.listFilter != oldWidget.listFilter && widget.listFilter != null) {
      setState(() {
        _currentFilter = widget.listFilter!;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadScope() async {
    setState(() => _isLoadingScope = true);
    final user = AuthService().currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingScope = false);
      return;
    }

    final profile = await _firestoreService.getUserProfile(user.uid);
    if (profile == null) {
      if (mounted) setState(() => _isLoadingScope = false);
      return;
    }

    _userRole = profile['role'] ?? AppRoles.guest;
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

    if (mounted) setState(() => _isLoadingScope = false);
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

  Future<void> _toggleStatus(GeneralWorkLogModel log) async {
    final newStatus = log.isCompleted ? 'pending' : 'completed';
    final updated = log.copyWith(status: newStatus);
    await _firestoreService.updateGeneralWorkLog(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus == 'completed' ? 'Marked as Completed!' : 'Marked as Pending!'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteLog(GeneralWorkLogModel log) async {
    final canDelete = PermissionHelper.canEditDatabase(_userRole);
    if (!canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('View-only users cannot delete work logs.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Work Log?'),
        content: const Text('Are you sure you want to delete this general work record? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestoreService.deleteGeneralWorkLog(log.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Log deleted successfully.')),
        );
      }
    }
  }

  void _shareAsWhatsApp(GeneralWorkLogModel log) {
    final text = WhatsAppLogParser.formatForWhatsApp(
      date: log.date,
      shiftName: log.shift.name.toUpperCase(),
      team: log.team,
      items: log.items,
      equipmentOrArea: log.equipmentOrArea.isNotEmpty ? log.equipmentOrArea : log.unitId,
      pendingFollowUp: log.pendingFollowUp,
      status: log.status,
    );

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied formatted WhatsApp log to clipboard!'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Share.share(text, subject: 'Shift General Work Log');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget content = AnimatedGradientBackground(
      child: Column(
        children: [
          // 1. Standalone Scope Bar (if opened standalone)
          if (widget.showAppBar && _plants.isNotEmpty) _buildStandaloneScopeBar(isDark),

          // 2. Search & Filter Bar
          _buildSearchAndFilterBar(isDark),

          // 3. Log Stream
          Expanded(
            child: StreamBuilder<List<GeneralWorkLogModel>>(
              stream: _firestoreService.getGeneralWorkLogsStream(
                plantId: _activePlant,
                unitId: _activeUnit,
                status: _currentFilter == 'All' ? null : _currentFilter,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: PulseLoading(size: 40));
                }

                var logs = snapshot.data ?? [];

                // Filter by local search query if entered
                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  logs = logs.where((l) {
                    final inTeam = l.team.any((t) => t.toLowerCase().contains(q));
                    final inEquip = l.equipmentOrArea.toLowerCase().contains(q);
                    final inItems = l.items.any((item) => item.toLowerCase().contains(q));
                    final inDesc = l.description.toLowerCase().contains(q);
                    final inCategory = l.category.toLowerCase().contains(q);
                    return inTeam || inEquip || inItems || inDesc || inCategory;
                  }).toList();
                }

                if (logs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.engineering_outlined, size: 64, color: Theme.of(context).disabledColor),
                        const SizedBox(height: 16),
                        Text(
                          'No general work logs found.',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tap the button below or paste a WhatsApp log to record shift maintenance.',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return _buildLogCard(context, log, isDark);
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
        appBar: const CustomAppBar(title: 'General Work Log'),
        body: content,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddGenWorkLogPage(
                  plantId: _activePlant,
                  unitId: _activeUnit,
                ),
              ),
            );
          },
          backgroundColor: const Color(0xFF2563EB),
          icon: const Icon(Icons.add_task, color: Colors.white, size: 20),
          label: const Text('Log General Work', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      );
    } else {
      return content;
    }
  }

  Widget _buildStandaloneScopeBar(bool isDark) {
    if (_isLoadingScope) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
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
                          if (val != null) setState(() => _activeUnit = val);
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search tasks, team, area, or equipment...',
              hintStyle: TextStyle(fontSize: 12, color: isDark ? Colors.white30 : const Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            style: const TextStyle(fontSize: 12),
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('All Logs'),
                selected: _currentFilter == 'All',
                onSelected: (val) {
                  if (val) setState(() => _currentFilter = 'All');
                },
                selectedColor: const Color(0xFF2563EB).withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: _currentFilter == 'All' ? FontWeight.bold : FontWeight.normal,
                  color: _currentFilter == 'All' ? const Color(0xFF2563EB) : Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 13, color: Colors.greenAccent),
                    SizedBox(width: 4),
                    Text('Completed'),
                  ],
                ),
                selected: _currentFilter == 'completed',
                onSelected: (val) {
                  if (val) setState(() => _currentFilter = 'completed');
                },
                selectedColor: Colors.green.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: _currentFilter == 'completed' ? FontWeight.bold : FontWeight.normal,
                  color: _currentFilter == 'completed' ? Colors.greenAccent : Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pending_actions, size: 13, color: Colors.amber),
                    SizedBox(width: 4),
                    Text('Pending / Handover'),
                  ],
                ),
                selected: _currentFilter == 'pending',
                onSelected: (val) {
                  if (val) setState(() => _currentFilter = 'pending');
                },
                selectedColor: Colors.amber.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: _currentFilter == 'pending' ? FontWeight.bold : FontWeight.normal,
                  color: _currentFilter == 'pending' ? Colors.amber : Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(BuildContext context, GeneralWorkLogModel log, bool isDark) {
    final dateStr = '${log.date.day.toString().padLeft(2, '0')}/${log.date.month.toString().padLeft(2, '0')}/${log.date.year}';
    final shiftStr = log.shift.name.toUpperCase();
    final isCompleted = log.isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: !isCompleted
              ? Colors.amber.withValues(alpha: 0.4)
              : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0)),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Date, Shift, Category & Status Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    dateStr,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF2563EB)),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$shiftStr-Shift',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isCompleted ? Colors.green.withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isCompleted ? Colors.green.withValues(alpha: 0.3) : Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isCompleted ? Icons.check_circle : Icons.pending_actions, size: 12, color: isCompleted ? Colors.greenAccent : Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        isCompleted ? 'Completed' : 'Pending',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isCompleted ? Colors.greenAccent : Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Row 2: Equipment / Area & Category
            Row(
              children: [
                if (log.equipmentOrArea.isNotEmpty) ...[
                  Icon(Icons.place_outlined, size: 14, color: isDark ? AppColors.accent : const Color(0xFF2563EB)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      log.equipmentOrArea,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ] else if (log.unitId != null && log.unitId!.isNotEmpty) ...[
                  Icon(Icons.hub_outlined, size: 14, color: isDark ? AppColors.accent : const Color(0xFF2563EB)),
                  const SizedBox(width: 4),
                  Text(
                    'Unit: ${log.unitId}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const Spacer(),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    log.category,
                    style: TextStyle(fontSize: 9, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Row 3: Engineers & Crew Display
            if (log.engineerNames.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.engineering_outlined, size: 13, color: Color(0xFF2563EB)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Eng: ${log.engineerNames.join(" • ")}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],

            if (log.workmenNames.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.handyman_outlined, size: 13, color: Colors.orange),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Workmen: ${log.workmenNames.join(" • ")}',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? Colors.white60 : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ] else if (log.team.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.people_alt_outlined, size: 13, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      log.team.join(' • '),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            const Divider(height: 12),

            // Row 4: Multi-Equipment Work Blocks
            ...log.equipmentWorks.map((block) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.precision_manufacturing_outlined, size: 13, color: isDark ? AppColors.accent : const Color(0xFF2563EB)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            block.equipmentName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                          ),
                        ),
                        if (block.assetName != null && block.assetName!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                            child: Text(block.assetName!, style: const TextStyle(fontSize: 9, color: Color(0xFF2563EB))),
                          ),
                        if (block.feederName != null && block.feederName!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                            child: Text(block.feederName!, style: const TextStyle(fontSize: 9, color: Colors.purpleAccent)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ...List.generate(block.tasks.length, (tIdx) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 6, bottom: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppColors.accent : const Color(0xFF2563EB))),
                            Expanded(child: Text(block.tasks[tIdx], style: const TextStyle(fontSize: 11, height: 1.25))),
                          ],
                        ),
                      );
                    }),
                    if (block.hasPending) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.assignment_late_outlined, size: 12, color: Colors.amber),
                            const SizedBox(width: 4),
                            Expanded(child: Text('Pending: ${block.pendingFollowUp!}', style: const TextStyle(fontSize: 10, color: Colors.amber))),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),

            if (log.hasPendingFollowUp && !log.equipmentWorks.any((b) => b.hasPending)) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.assignment_late_outlined, size: 15, color: Colors.amber),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Follow-up / Handover Required:',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            log.pendingFollowUp!,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark ? Colors.white70 : const Color(0xFF78350F),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),

            // Row 6: Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _shareAsWhatsApp(log),
                  icon: const Icon(Icons.share, size: 14, color: Color(0xFF25D366)),
                  label: const Text('WhatsApp', style: TextStyle(fontSize: 11, color: Color(0xFF25D366), fontWeight: FontWeight.bold)),
                ),
                TextButton.icon(
                  onPressed: () => _toggleStatus(log),
                  icon: Icon(isCompleted ? Icons.undo : Icons.check_circle_outline, size: 14, color: isCompleted ? Colors.amber : Colors.greenAccent),
                  label: Text(isCompleted ? 'Re-open' : 'Done', style: TextStyle(fontSize: 11, color: isCompleted ? Colors.amber : Colors.greenAccent)),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  tooltip: 'Edit Log',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddGenWorkLogPage(
                          existingLog: log,
                          plantId: log.plantId,
                          unitId: log.unitId,
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                  tooltip: 'Delete Log',
                  onPressed: () => _deleteLog(log),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
