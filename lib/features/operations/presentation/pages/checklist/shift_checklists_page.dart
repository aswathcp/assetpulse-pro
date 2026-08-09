// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:asset_pulse_pro/core/constants/app_colors.dart';
import 'package:asset_pulse_pro/core/widgets/glass_container.dart';
import 'package:asset_pulse_pro/features/home/presentation/widgets/custom_app_bar.dart';
import 'package:asset_pulse_pro/core/services/auth_service.dart';
import 'package:asset_pulse_pro/core/services/firestore_service.dart';
import 'package:asset_pulse_pro/core/services/hierarchy_service.dart';
import 'package:asset_pulse_pro/core/constants/app_roles.dart';
import 'package:asset_pulse_pro/core/widgets/pulse_loading.dart';
import 'geofenced_checklist_wrapper.dart';
import 'checklists/dynamic_checklist_form.dart';
import 'shift_checklist_management_page.dart';

/// Determines which shift a given time belongs to.
/// AS: 07:00–15:00, BS: 15:00–23:00, CS: 23:00–07:00
String getShiftForTime(DateTime time) {
  final hr = time.hour;
  if (hr >= 7 && hr < 15) return 'AS';
  if (hr >= 15 && hr < 23) return 'BS';
  return 'CS';
}

String shiftLabel(String shift) {
  switch (shift) {
    case 'AS':
      return 'A-Shift (07:00–15:00)';
    case 'BS':
      return 'B-Shift (15:00–23:00)';
    case 'CS':
      return 'C-Shift (23:00–07:00)';
    default:
      return shift;
  }
}

class ShiftChecklistsPage extends StatefulWidget {
  const ShiftChecklistsPage({super.key});

  @override
  State<ShiftChecklistsPage> createState() => _ShiftChecklistsPageState();
}

class _ShiftChecklistsPageState extends State<ShiftChecklistsPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Scope State
  String? _selectedBusinessId;
  String? _selectedPlantId;
  String? _selectedUnitId;

  Map<String, String> _availableBusinesses = {};
  List<String> _plants = [];
  List<String> _units = [];

  bool _isPlantLocked = false;
  bool _isUnitLocked = false;
  bool _isLoading = true;
  String _userRole = '';
  String _currentUserId = '';
  String _currentUserName = '';
  bool _isAdmin = false;

  // List of checklist definitions
  List<Map<String, dynamic>> _checklists = [];

  // Per checklist: latest submission data per shift for today
  // key: checklistId -> map of shift -> submission doc
  Map<String, Map<String, Map<String, dynamic>>> _todaySubmissions = {};

  // Inline view state  (like lux page)
  Map<String, dynamic>? _historyChecklist; // show history for this checklist
  bool _isManagingChecklists = false;

  final TextEditingController _searchController = TextEditingController();

  // Dashboard metrics
  int _totalChecklists = 0;
  int _todayCompleted = 0;
  int _todayPending = 0;

  @override
  void initState() {
    super.initState();
    _loadUserScope();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserScope() async {
    final user = AuthService().currentUser;
    if (user == null) return;

    final profile = await _firestoreService.getUserProfile(user.uid);
    if (profile == null) return;

    _currentUserId = user.uid;
    _userRole = profile['role'] ?? AppRoles.guest;
    _currentUserName = profile['displayName'] ?? 'Unknown Operator';
    _isAdmin = profile['isAdmin'] == true || _userRole == AppRoles.developer;
    final userPlantId = profile['plantId'] as String?;
    final userUnitId = profile['unitId'] as String?;
    final userBusinessId = profile['businessId'] as String? ?? 'VISL';

    final hierarchyService = HierarchyService();
    await hierarchyService.init(businessId: userBusinessId);
    _availableBusinesses = await _firestoreService.getHierarchyConfigs();
    _selectedBusinessId = hierarchyService.currentBusinessId;
    if (_selectedBusinessId != null &&
        !_availableBusinesses.containsKey(_selectedBusinessId)) {
      _selectedBusinessId =
          _availableBusinesses.isNotEmpty ? _availableBusinesses.keys.first : null;
    }

    _plants = hierarchyService.getPlants();

    final bool hasGlobalAdmin = profile['isAdmin'] == true && userPlantId == null;
    final bool hasPlantAdmin = profile['isAdmin'] == true && userPlantId != null;

    final String? cleanPlant =
        (userPlantId == null || userPlantId.isEmpty || userPlantId == 'Unknown')
            ? null
            : userPlantId;
    final String? cleanUnit =
        (userUnitId == null || userUnitId.isEmpty || userUnitId == 'Unknown')
            ? null
            : userUnitId;

    final bool isPlantScope = (hasPlantAdmin ||
            _userRole == AppRoles.businessAdmin ||
            _userRole == AppRoles.plantAdmin ||
            _userRole == AppRoles.plantHod) &&
        _userRole != AppRoles.manager &&
        _userRole != AppRoles.deputyManager &&
        _userRole != AppRoles.associateManager &&
        _userRole != AppRoles.assistantManager &&
        _userRole != AppRoles.unitAdmin &&
        _userRole != AppRoles.unitHod;

    if (_userRole == AppRoles.developer ||
        _userRole == AppRoles.auditor ||
        hasGlobalAdmin) {
      _isPlantLocked = false;
      _isUnitLocked = false;
      _selectedPlantId = _plants.isNotEmpty ? _plants.first : null;
    } else if (isPlantScope) {
      _isPlantLocked = true;
      _isUnitLocked = false;
      _selectedPlantId = cleanPlant ?? (_plants.isNotEmpty ? _plants.first : null);
    } else {
      _isPlantLocked = true;
      _isUnitLocked = true;
      _selectedPlantId = cleanPlant ?? (_plants.isNotEmpty ? _plants.first : null);
      _selectedUnitId = cleanUnit;
    }

    _updateUnitList();

    if (!_isUnitLocked && _selectedUnitId == null) {
      _selectedUnitId = _units.isNotEmpty ? _units.first : null;
    }

    await _loadData();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateUnitList() {
    if (_selectedPlantId == null) {
      _units = [];
      _selectedUnitId = null;
    } else {
      _units = HierarchyService().getUnitsForPlant(_selectedPlantId!);
      if (_units.isEmpty) _units = ['PID1', 'MCD'];
      if (!_units.contains(_selectedUnitId)) {
        _selectedUnitId = _units.isNotEmpty ? _units.first : null;
      }
    }
  }

  Future<void> _loadData() async {
    if (_selectedPlantId == null || _selectedUnitId == null) return;

    // Load checklists definitions
    Query q = _firestore.collection('custom_checklists');
    if (_userRole == AppRoles.developer && _selectedBusinessId != null) {
      q = q.where('businessId', isEqualTo: _selectedBusinessId);
    } else if (_userRole != AppRoles.developer) {
      q = q.where('businessId', isEqualTo: HierarchyService().currentBusinessId);
    }
    q = q
        .where('plantId', isEqualTo: _selectedPlantId)
        .where('unitId', isEqualTo: _selectedUnitId);

    final checklistSnap = await q.get();
    _checklists =
        checklistSnap.docs.map((d) => d.data() as Map<String, dynamic>).toList();

    // Load today's submissions for all checklists
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    Query subQ = _firestore.collection('checklist_submissions');
    subQ = subQ
        .where('plantId', isEqualTo: _selectedPlantId)
        .where('unitId', isEqualTo: _selectedUnitId)
        .where('timestampEnd', isGreaterThanOrEqualTo: todayStart.toIso8601String())
        .where('timestampEnd', isLessThan: todayEnd.toIso8601String());

    final subSnap = await subQ.orderBy('timestampEnd', descending: true).get();

    final Map<String, Map<String, Map<String, dynamic>>> todayMap = {};
    for (final doc in subSnap.docs) {
      final sub = doc.data() as Map<String, dynamic>;
      if (sub['deleted'] == true) continue;
      final checklistType = sub['checklistType'] as String? ?? '';
      final shift = sub['shift'] as String? ?? getShiftForTime(
        sub['timestampEnd'] != null
            ? DateTime.parse(sub['timestampEnd'])
            : DateTime.now(),
      );
      todayMap[checklistType] ??= {};
      // Keep the most recent submission per shift
      if (!todayMap[checklistType]!.containsKey(shift)) {
        todayMap[checklistType]![shift] = {...sub, 'id': doc.id};
      }
    }
    _todaySubmissions = todayMap;

    // Calculate metrics
    final currentShift = getShiftForTime(now);
    _totalChecklists = _checklists.length;
    _todayCompleted = _checklists
        .where((c) =>
            (_todaySubmissions[c['name']]?.containsKey(currentShift) ?? false))
        .length;
    _todayPending = _totalChecklists - _todayCompleted;
  }

  void _launchChecklist(BuildContext context, Map<String, dynamic> checklist,
      {Map<String, dynamic>? existingSubmission}) {
    final isLocationRequired = checklist['isLocationRequired'] == true;

    if (isLocationRequired) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GeofencedChecklistWrapper(
            targetLatitude: (checklist['latitude'] as num).toDouble(),
            targetLongitude: (checklist['longitude'] as num).toDouble(),
            targetName: '${checklist['unitId'] ?? ''} ${checklist['name'] ?? ''}',
            builder: (pos, verified) => DynamicChecklistForm(
              checklist: checklist,
              startPosition: pos,
              isVerified: verified,
              existingSubmission: existingSubmission,
            ),
          ),
        ),
      ).then((_) => _refreshData());
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DynamicChecklistForm(
            checklist: checklist,
            existingSubmission: existingSubmission,
          ),
        ),
      ).then((_) => _refreshData());
    }
  }

  Future<void> _refreshData() async {
    await _loadData();
    if (mounted) setState(() {});
  }

  String _formatDateTime(DateTime dt) {
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-$month-$day $hour:$minute';
  }

  bool _canEditOrDelete(Map<String, dynamic> sub) {
    if (_isAdmin) return true;
    final submittedBy = sub['submittedBy'] as String? ?? '';
    if (submittedBy != _currentUserId) return false;
    final timestampRaw = sub['timestampEnd'] ?? sub['timestampStart'];
    if (timestampRaw == null) return false;
    final submittedTime = DateTime.tryParse(timestampRaw.toString());
    if (submittedTime == null) return false;
    return DateTime.now().difference(submittedTime).inHours < 8;
  }

  Future<void> _softDelete(String docId) async {
    await _firestore.collection('checklist_submissions').doc(docId).update({
      'deleted': true,
      'deletedBy': _currentUserName,
      'deletedAt': DateTime.now().toIso8601String(),
    });
    await _refreshData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        appBar: CustomAppBar(title: 'Shift Checklists'),
        body: Center(child: PulseLoading()),
      );
    }

    return PopScope(
      canPop: _historyChecklist == null && !_isManagingChecklists,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() {
          if (_historyChecklist != null) {
            _historyChecklist = null;
          } else if (_isManagingChecklists) {
            _isManagingChecklists = false;
          }
        });
      },
      child: Scaffold(
        appBar: const CustomAppBar(title: 'Shift Checklists'),
        body: _historyChecklist != null
            ? _buildHistoryView()
            : _isManagingChecklists
                ? ShiftChecklistManagementPage(
                    plantId: _selectedPlantId!,
                    unitId: _selectedUnitId!,
                    isAdmin: _isAdmin,
                    userRole: _userRole,
                    onBack: () => setState(() {
                      _isManagingChecklists = false;
                      _refreshData();
                    }),
                  )
                : _buildListView(),
      ),
    );
  }

  Widget _buildListView() {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _checklists.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      return name.contains(query);
    }).toList();

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Scope Bar
            GlassContainer(
              borderRadius: 16,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedPlantId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Plant', border: InputBorder.none),
                        items: _plants
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: _isPlantLocked
                            ? null
                            : (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedPlantId = val;
                                    _updateUnitList();
                                    _isLoading = true;
                                  });
                                  _loadData().then(
                                      (_) => setState(() => _isLoading = false));
                                }
                              },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedUnitId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Unit', border: InputBorder.none),
                        items: _units
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: _isUnitLocked
                            ? null
                            : (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedUnitId = val;
                                    _isLoading = true;
                                  });
                                  _loadData().then(
                                      (_) => setState(() => _isLoading = false));
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Dashboard Metrics
            _buildMetricsDashboard(),
            const SizedBox(height: 20),

            // 3. Search + Settings cog
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search checklists...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                if (_isAdmin)
                  IconButton.filled(
                    style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary),
                    icon: const Icon(Icons.settings, color: Colors.white),
                    tooltip: 'Manage Checklists',
                    onPressed: () =>
                        setState(() => _isManagingChecklists = true),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // 4. Shift legend row
            _buildShiftLegend(),
            const SizedBox(height: 12),

            // 5. List header
            Text(
              'Checklists (${filtered.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // 6. Checklist cards
            filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        _checklists.isEmpty
                            ? 'No checklists configured for this unit yet.\nAdmins can click the settings cog to add.'
                            : 'No checklists matched your search.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) =>
                        _buildChecklistCard(filtered[index]),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsDashboard() {
    final now = DateTime.now();
    final currentShift = getShiftForTime(now);
    final rate = _totalChecklists == 0
        ? 0.0
        : (_todayCompleted / _totalChecklists) * 100;
    final color = rate >= 100
        ? Colors.greenAccent
        : rate >= 60
            ? Colors.orangeAccent
            : Colors.redAccent;

    return GlassContainer(
      borderRadius: 20,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Today\'s Shift Completion',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('Current Shift: ${shiftLabel(currentShift)}',
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
                Text(
                  '${rate.toStringAsFixed(1)}%',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _totalChecklists == 0
                    ? 0.0
                    : _todayCompleted / _totalChecklists,
                minHeight: 10,
                backgroundColor: Colors.grey.shade800,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _metricColumn('Total', '$_totalChecklists', Colors.white),
                _metricColumn(
                    'Completed', '$_todayCompleted', Colors.greenAccent),
                _metricColumn('Pending', '$_todayPending', Colors.orangeAccent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildShiftLegend() {
    final shifts = [
      {'code': 'AS', 'label': 'A-Shift', 'time': '07:00–15:00', 'color': Colors.blueAccent},
      {'code': 'BS', 'label': 'B-Shift', 'time': '15:00–23:00', 'color': Colors.purpleAccent},
      {'code': 'CS', 'label': 'C-Shift', 'time': '23:00–07:00', 'color': Colors.tealAccent},
    ];
    final currentShift = getShiftForTime(DateTime.now());

    return Row(
      children: shifts.map((s) {
        final isActive = s['code'] == currentShift;
        final col = s['color'] as Color;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
                right: s['code'] != 'CS' ? 8 : 0),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              color: col.withValues(alpha: isActive ? 0.2 : 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: col.withValues(alpha: isActive ? 0.6 : 0.2),
                  width: isActive ? 1.5 : 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(s['label'] as String,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: col)),
                    if (isActive) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                            color: col.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4)),
                        child: Text('NOW',
                            style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: col)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(s['time'] as String,
                    style: const TextStyle(fontSize: 9, color: Colors.grey)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChecklistCard(Map<String, dynamic> checklist) {
    final name = checklist['name'] as String? ?? 'Unnamed';
    final isLocationRequired = checklist['isLocationRequired'] == true;
    final shiftSubmissions = _todaySubmissions[name] ?? {};
    final currentShift = getShiftForTime(DateTime.now());
    final currentShiftSub = shiftSubmissions[currentShift];

    final List<Map<String, dynamic>> shiftDefs = [
      {'code': 'AS', 'label': 'A', 'color': Colors.blueAccent},
      {'code': 'BS', 'label': 'B', 'color': Colors.purpleAccent},
      {'code': 'CS', 'label': 'C', 'color': Colors.tealAccent},
    ];

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (currentShiftSub != null) {
      statusColor = Colors.greenAccent;
      statusText = 'COMPLETED';
      statusIcon = Icons.check_circle_outline;
    } else {
      statusColor = Colors.orangeAccent;
      statusText = 'PENDING';
      statusIcon = Icons.pending_outlined;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            isLocationRequired
                                ? Icons.location_on
                                : Icons.location_off_outlined,
                            size: 12,
                            color: isLocationRequired
                                ? Colors.blueAccent
                                : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isLocationRequired
                                ? 'GPS Verification Required'
                                : 'No GPS Required',
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),

            // Shift status row
            Row(
              children: shiftDefs.map((s) {
                final code = s['code'] as String;
                final col = s['color'] as Color;
                final sub = shiftSubmissions[code];
                final done = sub != null;
                final isCurrent = code == currentShift;

                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(
                        right: code != 'CS' ? 6 : 0),
                    padding: const EdgeInsets.symmetric(
                        vertical: 6, horizontal: 4),
                    decoration: BoxDecoration(
                      color: done
                          ? Colors.greenAccent.withValues(alpha: 0.1)
                          : isCurrent
                              ? Colors.orangeAccent.withValues(alpha: 0.1)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: done
                            ? Colors.greenAccent.withValues(alpha: 0.4)
                            : isCurrent
                                ? Colors.orangeAccent.withValues(alpha: 0.4)
                                : col.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${s['label']}-Shift',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: col),
                        ),
                        const SizedBox(height: 2),
                        Icon(
                          done
                              ? Icons.check_circle
                              : isCurrent
                                  ? Icons.radio_button_unchecked
                                  : Icons.remove_circle_outline,
                          size: 14,
                          color: done
                              ? Colors.greenAccent
                              : isCurrent
                                  ? Colors.orangeAccent
                                  : Colors.grey.shade600,
                        ),
                        if (done) ...[
                          const SizedBox(height: 2),
                          Text(
                            _formatTime(sub),
                            style: const TextStyle(
                                fontSize: 8, color: Colors.grey),
                          ),
                          if (sub['isVerifiedLocation'] == false &&
                              sub['startCoordinates'] != null)
                            const Text(
                              'GPS Bypassed',
                              style: TextStyle(
                                  fontSize: 7,
                                  color: Colors.orangeAccent,
                                  fontWeight: FontWeight.bold),
                            ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),

            // Bottom action row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // "Submitted by" info for current shift
                currentShiftSub != null
                    ? Expanded(
                        child: Text(
                          'By: ${currentShiftSub['submittedByName'] ?? 'Unknown'}',
                          style: const TextStyle(
                              fontSize: 10, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : const Expanded(child: SizedBox()),

                Row(
                  children: [
                    // History icon
                    IconButton(
                      icon: const Icon(Icons.history, size: 20),
                      tooltip: 'View Submission History',
                      onPressed: () =>
                          setState(() => _historyChecklist = checklist),
                    ),
                    // Record/Start button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            statusColor.withValues(alpha: 0.15),
                        foregroundColor: statusColor,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 0),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: Icon(
                          currentShiftSub != null
                              ? Icons.refresh
                              : Icons.play_arrow,
                          size: 16),
                      label: Text(
                        currentShiftSub != null
                            ? 'Re-submit'
                            : 'Start',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () =>
                          _launchChecklist(context, checklist),
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

  String _formatTime(Map<String, dynamic> sub) {
    final raw = sub['timestampEnd'] ?? sub['timestampStart'];
    if (raw == null) return '';
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildHistoryView() {
    final checklist = _historyChecklist!;
    final name = checklist['name'] as String? ?? 'Unnamed';

    return StreamBuilder<QuerySnapshot>(
      stream: () {
        Query q = _firestore
            .collection('checklist_submissions')
            .where('checklistType', isEqualTo: name);
        if (_selectedPlantId != null) {
          q = q.where('plantId', isEqualTo: _selectedPlantId);
        }
        if (_selectedUnitId != null) {
          q = q.where('unitId', isEqualTo: _selectedUnitId);
        }
        return q.orderBy('timestampEnd', descending: true).snapshots();
      }(),
      builder: (context, snapshot) {
        final docs = snapshot.hasData ? snapshot.data!.docs : [];
        final entries = docs
            .map((d) => {...d.data() as Map<String, dynamic>, 'id': d.id})
            .where((s) => s['deleted'] != true)
            .toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () =>
                        setState(() => _historyChecklist = null),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'History: $name',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text('No submission history found.',
                        style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: entries.length,
                  itemBuilder: (context, idx) {
                    final sub = entries[idx];
                    return _buildHistoryCard(sub, checklist);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryCard(
      Map<String, dynamic> sub, Map<String, dynamic> checklist) {
    final timestampRaw = sub['timestampEnd'] ?? sub['timestampStart'];
    final DateTime timestamp = timestampRaw != null
        ? (DateTime.tryParse(timestampRaw.toString()) ?? DateTime.now())
        : DateTime.now();

    final shift = sub['shift'] as String? ?? getShiftForTime(timestamp);
    final isVerified = sub['isVerifiedLocation'] == true;
    final submittedByName =
        sub['submittedByName'] as String? ?? 'Unknown Operator';
    final fields = sub['fields'] as Map<String, dynamic>? ?? {};
    final canAct = _canEditOrDelete(sub);
    final docId = sub['id'] as String? ?? '';

    final Color shiftColor;
    switch (shift) {
      case 'AS':
        shiftColor = Colors.blueAccent;
        break;
      case 'BS':
        shiftColor = Colors.purpleAccent;
        break;
      default:
        shiftColor = Colors.tealAccent;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: shiftColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: shiftColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    shiftLabel(shift),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: shiftColor),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatDateTime(timestamp),
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
                // Geofence badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isVerified
                        ? Colors.greenAccent.withValues(alpha: 0.12)
                        : Colors.orangeAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                          isVerified
                              ? Icons.verified_outlined
                              : Icons.gps_off,
                          size: 10,
                          color: isVerified
                              ? Colors.greenAccent
                              : Colors.orangeAccent),
                      const SizedBox(width: 3),
                      Text(
                        isVerified ? 'GPS OK' : 'Bypassed',
                        style: TextStyle(
                            fontSize: 9,
                            color: isVerified
                                ? Colors.greenAccent
                                : Colors.orangeAccent,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Tested by: $submittedByName',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            if (sub['lastModifiedBy'] != null)
              Text(
                  'Last modified by: ${sub['lastModifiedBy']} at ${sub['lastModifiedAt'] ?? ''}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
            const Divider(height: 12),
            // Fields — show ALL
            ...fields.entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(e.key,
                            style: const TextStyle(fontSize: 11)),
                      ),
                      Text(e.value?.toString() ?? '-',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ],
                  ),
                )),
            if (canAct) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Delete',
                        style: TextStyle(fontSize: 11)),
                    onPressed: () => _confirmDelete(docId),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.blueAccent.withValues(alpha: 0.15),
                      foregroundColor: Colors.blueAccent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const Text('Edit',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                    onPressed: () => _launchChecklist(context, checklist,
                        existingSubmission: sub),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Submission'),
        content: const Text(
            'Are you sure you want to delete this checklist submission? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await _softDelete(docId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
