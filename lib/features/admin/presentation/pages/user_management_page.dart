import 'package:material_ui/material_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_roles.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../../core/widgets/pulse_loading.dart';
import '../../../../core/services/hierarchy_service.dart';
import 'package:asset_pulse_pro/core/utils/permission_helper.dart';

enum UserFilterTab { all, pending, active, rejected }

class UserManagementPage extends StatefulWidget {
  final Map<String, dynamic> currentUserProfile;

  const UserManagementPage({super.key, required this.currentUserProfile});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final FirestoreService _firestoreService = FirestoreService();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String? _errorMessage;
  UserFilterTab _selectedTab = UserFilterTab.all;

  // Search — ValueNotifier so only the list rebuilds, not the TextField
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String> _searchNotifier = ValueNotifier('');

  int get _pendingCount => _users.where((u) => u['isValidated'] != true && u['isRejected'] != true).length;
  int get _activeCount => _users.where((u) => u['isValidated'] == true && u['isRejected'] != true).length;
  int get _rejectedCount => _users.where((u) => u['isRejected'] == true).length;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final String myRole = widget.currentUserProfile['role'] ?? AppRoles.guest;
      final String? myPlantId = widget.currentUserProfile['plantId'];
      final String? myUnitId = widget.currentUserProfile['unitId'];
      final String? myBusinessId = widget.currentUserProfile['businessId'];

      List<Map<String, dynamic>> users = [];
      final bool myIsAdmin = widget.currentUserProfile['isAdmin'] == true;

      if (myRole == AppRoles.developer || (myIsAdmin && myPlantId == null)) {
        users = await _firestoreService.getAllUsers();
      } else if (myIsAdmin && myPlantId != null) {
        users = await _firestoreService.getAllUsers(plantId: myPlantId);
      } else if (myRole == AppRoles.businessAdmin) {
        if (myBusinessId != null && myBusinessId.isNotEmpty) {
           users = await _firestoreService.getAllUsers(businessId: myBusinessId);
        }
      } else if (myRole == AppRoles.plantAdmin) {
        if (myPlantId != null && myPlantId.isNotEmpty) {
           users = await _firestoreService.getAllUsers(plantId: myPlantId);
        }
      } else if (myRole == AppRoles.unitAdmin) {
        if (myPlantId != null && myPlantId.isNotEmpty && myUnitId != null && myUnitId.isNotEmpty) {
           users = await _firestoreService.getAllUsers(plantId: myPlantId, unitId: myUnitId);
        }
      } else {
        if (myPlantId != null && myPlantId.isNotEmpty && myUnitId != null && myUnitId.isNotEmpty) {
          users = await _firestoreService.getAllUsers(plantId: myPlantId, unitId: myUnitId);
        } else if (myPlantId != null && myPlantId.isNotEmpty) {
          users = await _firestoreService.getAllUsers(plantId: myPlantId);
        }
      }
      
      setState(() {
        _users = users;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateUser(String userId, String currentRole, String currentDept, String currentPlant, String currentUnit, bool currentIsAdmin) async {
    final myRole = widget.currentUserProfile['role'];
    
    List<String> allowedRoles = [];
    if (myRole == AppRoles.developer) {
      allowedRoles = AppRoles.values;
    } else {
      allowedRoles = AppRoles.values.where((r) => r != AppRoles.developer).toList();
    }

    if (allowedRoles.isEmpty || userId == FirebaseAuth.instance.currentUser?.uid) return;

    final Map<String, dynamic>? result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _EditUserDialog(
        currentRole: currentRole,
        currentDept: currentDept,
        currentPlant: currentPlant,
        currentUnit: currentUnit,
        currentIsAdmin: currentIsAdmin,
        allowedRoles: allowedRoles,
      ),
    );

    if (result != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'role': result['role'],
          'department': result['department'],
          'plantId': result['plantId'],
          'unitId': result['unitId'],
          'isAdmin': result['isAdmin'],
        });
        _loadUsers();
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User profile updated successfully'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  Future<void> _approveUser(Map<String, dynamic> user) async {
    final userId = user['uid'];
    final name = user['displayName'] ?? user['name'] ?? 'User';
    final role = user['role'] ?? 'Guest';
    final empId = user['employeeId'] ?? 'N/A';
    final scope = '${user['plantId'] ?? 'All'} • ${user['unitId'] ?? 'All'}';

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: AppColors.success, size: 24),
            SizedBox(width: 8),
            Text('Approve User Access'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Grant application access to $name?'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Employee ID: $empId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('Role: $role', style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('Scope: $scope', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve Access'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'isValidated': true,
          'isRejected': false,
          'rejectionReason': FieldValue.delete(),
          'approvedBy': widget.currentUserProfile['uid'],
          'approvedByName': widget.currentUserProfile['displayName'] ?? widget.currentUserProfile['name'] ?? 'Admin',
          'approvedAt': FieldValue.serverTimestamp(),
        });
        
        _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$name approved successfully!'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to approve user: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  Future<void> _rejectUser(Map<String, dynamic> user) async {
    final userId = user['uid'];
    final name = user['displayName'] ?? user['name'] ?? 'User';
    final empId = user['employeeId'] ?? 'N/A';

    final String? reason = await showDialog<String>(
      context: context,
      builder: (context) => _RejectUserDialog(
        userName: name,
        employeeId: empId,
        plantId: user['plantId'] ?? '',
        unitId: user['unitId'] ?? '',
        role: user['role'] ?? '',
      ),
    );

    if (reason != null && reason.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'isRejected': true,
          'isValidated': false,
          'rejectionReason': reason,
          'rejectedBy': widget.currentUserProfile['uid'],
          'rejectedByName': widget.currentUserProfile['displayName'] ?? widget.currentUserProfile['name'] ?? 'Admin',
          'rejectedAt': FieldValue.serverTimestamp(),
        });

        _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Request for $name rejected.'), backgroundColor: AppColors.error),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
        }
      }
    }
  }

  Future<void> _updateLotoRights(Map<String, dynamic> user, String field, bool newValue) async {
    try {
      final isRequesting = field == 'isRequestingAuth' ? newValue : (user['isRequestingAuth'] ?? false);
      final isIsolation = field == 'isIsolationAuth' ? newValue : (user['isIsolationAuth'] ?? false);

      await _firestoreService.updateUserLotoRights(
        user['uid'], 
        isRequestingAuth: isRequesting, 
        isIsolationAuth: isIsolation
      );
      
      _loadUsers();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('$field updated to $newValue'), backgroundColor: AppColors.success, duration: const Duration(milliseconds: 500)),
        );
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  List<Map<String, dynamic>> _filteredUsers(String query) {
    List<Map<String, dynamic>> list = _users;

    // 1. Filter by Tab
    switch (_selectedTab) {
      case UserFilterTab.pending:
        list = list.where((u) => u['isValidated'] != true && u['isRejected'] != true).toList();
        break;
      case UserFilterTab.active:
        list = list.where((u) => u['isValidated'] == true && u['isRejected'] != true).toList();
        break;
      case UserFilterTab.rejected:
        list = list.where((u) => u['isRejected'] == true).toList();
        break;
      case UserFilterTab.all:
        break;
    }

    // 2. Filter by Search Query
    if (query.isEmpty) return list;
    final q = query.toLowerCase().trim();
    return list.where((user) {
      final name = (user['displayName'] ?? user['name'] ?? '').toString().toLowerCase();
      final email = (user['email'] ?? '').toString().toLowerCase();
      final empId = (user['employeeId'] ?? '').toString().toLowerCase();
      final role = (user['role'] ?? '').toString().toLowerCase();
      final dept = (user['department'] ?? '').toString().toLowerCase();
      final plant = (user['plantId'] ?? '').toString().toLowerCase();
      final unit = (user['unitId'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q) || empId.contains(q) || role.contains(q) || dept.contains(q) || plant.contains(q) || unit.contains(q);
    }).toList();
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _buildFilterChip('All', _users.length, UserFilterTab.all, AppColors.accent),
          const SizedBox(width: 8),
          _buildFilterChip('Pending', _pendingCount, UserFilterTab.pending, Colors.amber),
          const SizedBox(width: 8),
          _buildFilterChip('Active', _activeCount, UserFilterTab.active, AppColors.success),
          const SizedBox(width: 8),
          _buildFilterChip('Rejected', _rejectedCount, UserFilterTab.rejected, AppColors.error),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int count, UserFilterTab tab, Color color) {
    final isSelected = _selectedTab == tab;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTab = tab;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Theme.of(context).dividerColor.withValues(alpha: 0.5),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected ? color : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Map<String, dynamic> user) {
    if (user['isRejected'] == true) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cancel_outlined, color: AppColors.error, size: 12),
            SizedBox(width: 4),
            Text('Rejected', style: TextStyle(color: AppColors.error, fontSize: 10.5, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    } else if (user['isValidated'] != true) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_top, color: Colors.amber, size: 12),
            SizedBox(width: 4),
            Text('Pending Approval', style: TextStyle(color: Colors.amber, fontSize: 10.5, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, color: AppColors.success, size: 12),
            SizedBox(width: 4),
            Text('Active', style: TextStyle(color: AppColors.success, fontSize: 10.5, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        titleTextStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Users',
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: AnimatedGradientBackground(
        child: _isLoading 
          ? const Center(child: PulseLoading(size: 60))
          : _errorMessage != null 
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Error: $_errorMessage', style: const TextStyle(color: AppColors.error)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _loadUsers,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name, email, employee ID, role...',
                        hintStyle: const TextStyle(fontSize: 13),
                        prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.accent),
                        suffixIcon: ValueListenableBuilder<String>(
                          valueListenable: _searchNotifier,
                          builder: (_, q, child) => q.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    _searchNotifier.value = '';
                                  },
                                )
                              : const SizedBox.shrink(),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Theme.of(context).dividerColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                        ),
                      ),
                      onChanged: (val) => _searchNotifier.value = val,
                    ),
                  ),

                  // Filter Tabs
                  _buildFilterChips(),

                  // Count & List with Pull-to-Refresh
                  Expanded(
                    child: ValueListenableBuilder<String>(
                      valueListenable: _searchNotifier,
                      builder: (context, query, _) {
                        final filtered = _filteredUsers(query);
                        return RefreshIndicator(
                          onRefresh: _loadUsers,
                          child: Column(
                            children: [
                              if (query.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Showing ${filtered.length} matching users',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                      const Spacer(),
                                      GestureDetector(
                                        onTap: () {
                                          _searchController.clear();
                                          _searchNotifier.value = '';
                                        },
                                        child: const Text('Clear', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accent)),
                                      ),
                                    ],
                                  ),
                                ),
                              Expanded(
                                child: filtered.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _selectedTab == UserFilterTab.pending
                                                  ? Icons.check_circle_outline
                                                  : Icons.person_search,
                                              size: 52,
                                              color: Colors.grey.withValues(alpha: 0.5),
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              query.isNotEmpty
                                                  ? 'No users found matching "$query"'
                                                  : _selectedTab == UserFilterTab.pending
                                                      ? 'No users pending approval'
                                                      : _selectedTab == UserFilterTab.rejected
                                                          ? 'No rejected users'
                                                          : 'No users found',
                                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.builder(
                                        padding: const EdgeInsets.all(16),
                                        itemCount: filtered.length,
                                        itemBuilder: (context, index) {
                                          final user = filtered[index];
                                          final isMe = user['uid'] == FirebaseAuth.instance.currentUser?.uid;
                                          final isRejected = user['isRejected'] == true;
                                          final isPending = user['isValidated'] != true && !isRejected;
                                          final rejectionReason = user['rejectionReason'];
                                          
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 12),
                                            child: GlassContainer(
                                              width: double.infinity,
                                              height: null,
                                              borderRadius: 14,
                                              child: Padding(
                                                padding: const EdgeInsets.all(16),
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    CircleAvatar(
                                                      backgroundColor: isRejected
                                                          ? AppColors.error.withValues(alpha: 0.8)
                                                          : isPending
                                                              ? Colors.amber.shade700
                                                              : AppColors.primaryLight,
                                                      child: Text(
                                                        (user['displayName'] ?? user['name'] ?? 'U')[0].toUpperCase(),
                                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 14),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Flexible(
                                                                child: Text(
                                                                  user['displayName'] ?? user['name'] ?? 'Unknown',
                                                                  style: TextStyle(
                                                                    color: Theme.of(context).colorScheme.onSurface,
                                                                    fontWeight: FontWeight.bold,
                                                                    fontSize: 15.5,
                                                                  ),
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                              ),
                                                              const SizedBox(width: 8),
                                                              _buildStatusBadge(user),
                                                            ],
                                                          ),
                                                          const SizedBox(height: 3),
                                                          Text(
                                                            '${user['email'] ?? ''} • ID: ${user['employeeId'] ?? 'N/A'}',
                                                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12.5),
                                                          ),
                                                          const SizedBox(height: 6),
                                                          Wrap(
                                                            spacing: 6,
                                                            runSpacing: 4,
                                                            crossAxisAlignment: WrapCrossAlignment.center,
                                                            children: [
                                                              Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                                decoration: BoxDecoration(
                                                                  color: AppColors.primary.withValues(alpha: 0.1),
                                                                  borderRadius: BorderRadius.circular(6),
                                                                ),
                                                                child: Text(
                                                                  '${user['role']} • ${user['department'] ?? 'No Dept'}',
                                                                  style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w600),
                                                                ),
                                                              ),
                                                              Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                                decoration: BoxDecoration(
                                                                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                                                  borderRadius: BorderRadius.circular(6),
                                                                ),
                                                                child: Text(
                                                                  '${user['plantId'] ?? 'Plant'} • ${user['unitId'] ?? 'Unit'}',
                                                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11),
                                                                ),
                                                              ),
                                                              if (user['isAdmin'] == true)
                                                                Container(
                                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                  decoration: BoxDecoration(
                                                                    color: Colors.purple.withValues(alpha: 0.15),
                                                                    borderRadius: BorderRadius.circular(6),
                                                                  ),
                                                                  child: const Text('Admin', style: TextStyle(color: Colors.purple, fontSize: 10, fontWeight: FontWeight.bold)),
                                                                ),
                                                            ],
                                                          ),

                                                          // Rejection reason preview
                                                          if (isRejected && rejectionReason != null && rejectionReason.toString().trim().isNotEmpty) ...[
                                                            const SizedBox(height: 6),
                                                            Container(
                                                              width: double.infinity,
                                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                              decoration: BoxDecoration(
                                                                color: AppColors.error.withValues(alpha: 0.08),
                                                                borderRadius: BorderRadius.circular(6),
                                                                border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                                                              ),
                                                              child: Text(
                                                                'Reason: $rejectionReason',
                                                                style: const TextStyle(color: AppColors.error, fontSize: 11),
                                                              ),
                                                            ),
                                                          ],

                                                          const SizedBox(height: 10),
                                                          // LOTO Rights
                                                          Wrap(
                                                            spacing: 8,
                                                            runSpacing: 4,
                                                            children: [
                                                              InkWell(
                                                                onTap: !PermissionHelper.canManageUser(widget.currentUserProfile, user)
                                                                    ? null
                                                                    : () => _updateLotoRights(user, 'isRequestingAuth', !(user['isRequestingAuth'] ?? false)),
                                                                child: Container(
                                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                                  decoration: BoxDecoration(
                                                                    color: (user['isRequestingAuth'] ?? false) ? Colors.blue.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1),
                                                                    borderRadius: BorderRadius.circular(6),
                                                                    border: Border.all(color: (user['isRequestingAuth'] ?? false) ? Colors.blue : Colors.grey.withValues(alpha: 0.3)),
                                                                  ),
                                                                  child: Row(
                                                                    mainAxisSize: MainAxisSize.min,
                                                                    children: [
                                                                      Icon(Icons.key, size: 14, color: (user['isRequestingAuth'] ?? false) ? Colors.blue : Colors.grey),
                                                                      const SizedBox(width: 4),
                                                                      Text('Req-Auth', style: TextStyle(fontSize: 11, color: (user['isRequestingAuth'] ?? false) ? Colors.blue : Colors.grey)),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                              InkWell(
                                                                onTap: !PermissionHelper.canManageUser(widget.currentUserProfile, user)
                                                                    ? null
                                                                    : () => _updateLotoRights(user, 'isIsolationAuth', !(user['isIsolationAuth'] ?? false)),
                                                                child: Container(
                                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                                  decoration: BoxDecoration(
                                                                    color: (user['isIsolationAuth'] ?? false) ? Colors.orange.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1),
                                                                    borderRadius: BorderRadius.circular(6),
                                                                    border: Border.all(color: (user['isIsolationAuth'] ?? false) ? Colors.orange : Colors.grey.withValues(alpha: 0.3)),
                                                                  ),
                                                                  child: Row(
                                                                    mainAxisSize: MainAxisSize.min,
                                                                    children: [
                                                                      Icon(Icons.lock, size: 14, color: (user['isIsolationAuth'] ?? false) ? Colors.orange : Colors.grey),
                                                                      const SizedBox(width: 4),
                                                                      Text('Iso-Auth', style: TextStyle(fontSize: 11, color: (user['isIsolationAuth'] ?? false) ? Colors.orange : Colors.grey)),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),

                                                    // Action buttons
                                                    isMe 
                                                      ? Chip(label: const Text('Me', style: TextStyle(color: Colors.white, fontSize: 10)), backgroundColor: Theme.of(context).disabledColor)
                                                      : !PermissionHelper.canManageUser(widget.currentUserProfile, user)
                                                        ? const Tooltip(
                                                            message: 'No permission to manage this user (equal or higher authority)',
                                                            child: Icon(Icons.lock_outline, color: Colors.grey, size: 20),
                                                          )
                                                        : Column(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              // Pending user actions
                                                              if (isPending) ...[
                                                                IconButton(
                                                                  icon: const Icon(Icons.check_circle, color: AppColors.success, size: 26),
                                                                  onPressed: () => _approveUser(user),
                                                                  tooltip: 'Approve User',
                                                                ),
                                                                IconButton(
                                                                  icon: const Icon(Icons.cancel, color: AppColors.error, size: 26),
                                                                  onPressed: () => _rejectUser(user),
                                                                  tooltip: 'Reject User Request',
                                                                ),
                                                              ],

                                                              // Rejected user actions
                                                              if (isRejected) ...[
                                                                IconButton(
                                                                  icon: const Icon(Icons.restore_from_trash, color: AppColors.success, size: 26),
                                                                  onPressed: () => _approveUser(user),
                                                                  tooltip: 'Reinstate / Approve User',
                                                                ),
                                                              ],

                                                              // Active user actions: allow Revoke if needed
                                                              if (!isPending && !isRejected) ...[
                                                                IconButton(
                                                                  icon: const Icon(Icons.block, color: AppColors.error, size: 22),
                                                                  onPressed: () => _rejectUser(user),
                                                                  tooltip: 'Revoke / Reject Access',
                                                                ),
                                                              ],

                                                              // Edit User details
                                                              IconButton(
                                                                icon: Icon(Icons.edit, size: 22, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                                                tooltip: 'Edit User Profile',
                                                                onPressed: () => _updateUser(
                                                                  user['uid'], 
                                                                  user['role'] ?? 'Guest', 
                                                                  user['department'] ?? 'Other',
                                                                  user['plantId'] ?? '',
                                                                  user['unitId'] ?? '',
                                                                  user['isAdmin'] == true,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _EditUserDialog extends StatefulWidget {
  final String currentRole;
  final String currentDept;
  final String currentPlant;
  final String currentUnit;
  final bool currentIsAdmin;
  final List<String> allowedRoles;

  const _EditUserDialog({
    required this.currentRole,
    required this.currentDept,
    required this.currentPlant,
    required this.currentUnit,
    required this.currentIsAdmin,
    required this.allowedRoles,
  });

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  late String _selectedRole;
  late String _selectedDept;
  late String _selectedPlant;
  late String _selectedUnit;

  final List<String> _departments = ['Electrical', 'Mechanical', 'Operations', 'Instrumentation', 'Safety', 'Other'];
  List<String> _plants = [];
  List<String> _units = [];

  @override
  void initState() {
    super.initState();
    final normalized = AppRoles.normalizeRole(widget.currentRole);
    _selectedRole = widget.allowedRoles.contains(normalized)
        ? normalized
        : (widget.allowedRoles.contains(widget.currentRole) ? widget.currentRole : widget.allowedRoles.first);
    _selectedDept = _departments.contains(widget.currentDept) ? widget.currentDept : 'Other';

    _plants = HierarchyService().getPlants();
    _selectedPlant = _plants.contains(widget.currentPlant) ? widget.currentPlant : (_plants.isNotEmpty ? _plants.first : '');
    
    _units = _selectedPlant.isNotEmpty ? HierarchyService().getUnitsForPlant(_selectedPlant) : [];
    _selectedUnit = _units.contains(widget.currentUnit) ? widget.currentUnit : (_units.isNotEmpty ? _units.first : '');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: Text('Edit User Profile', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              dropdownColor: Theme.of(context).colorScheme.surface,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              initialValue: _selectedRole,
              decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
              items: widget.allowedRoles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedRole = v);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              dropdownColor: Theme.of(context).colorScheme.surface,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              initialValue: _selectedDept,
              decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()),
              items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedDept = v);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              dropdownColor: Theme.of(context).colorScheme.surface,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              initialValue: _selectedPlant,
              decoration: const InputDecoration(labelText: 'Plant Scope', border: OutlineInputBorder()),
              items: _plants.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _selectedPlant = v;
                    _units = HierarchyService().getUnitsForPlant(v);
                    _selectedUnit = _units.isNotEmpty ? _units.first : '';
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            if (_units.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                key: ValueKey('unit_dropdown_$_selectedPlant'),
                dropdownColor: Theme.of(context).colorScheme.surface,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                initialValue: _units.contains(_selectedUnit) ? _selectedUnit : _units.first,
                decoration: const InputDecoration(labelText: 'Unit Scope', border: OutlineInputBorder()),
                items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedUnit = v);
                },
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final effectiveAdmin = AppRoles.isAdminRole(_selectedRole);
            Navigator.pop(context, {
              'role': _selectedRole,
              'department': _selectedDept,
              'plantId': _selectedPlant,
              'unitId': _selectedUnit,
              'isAdmin': effectiveAdmin,
            });
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLight),
          child: const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class _RejectUserDialog extends StatefulWidget {
  final String userName;
  final String employeeId;
  final String plantId;
  final String unitId;
  final String role;

  const _RejectUserDialog({
    required this.userName,
    required this.employeeId,
    required this.plantId,
    required this.unitId,
    required this.role,
  });

  @override
  State<_RejectUserDialog> createState() => _RejectUserDialogState();
}

class _RejectUserDialogState extends State<_RejectUserDialog> {
  final List<String> _reasons = [
    'Invalid or unverified Employee ID',
    'Incorrect Plant or Unit scope',
    'Unauthorized Role requested',
    'Duplicate account registration',
    'Other reason (specify below)',
  ];

  late String _selectedReason;
  final TextEditingController _customNoteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedReason = _reasons.first;
  }

  @override
  void dispose() {
    _customNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOther = _selectedReason == 'Other reason (specify below)';
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: const Row(
        children: [
          Icon(Icons.person_off_outlined, color: AppColors.error, size: 26),
          SizedBox(width: 8),
          Text('Reject User Request', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reject registration request for ${widget.userName} (ID: ${widget.employeeId})?',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13.5),
            ),
            const SizedBox(height: 14),
            Text(
              'Select Rejection Reason:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 6),
            RadioGroup<String>(
              groupValue: _selectedReason,
              onChanged: (val) {
                if (val != null) setState(() => _selectedReason = val);
              },
              child: Column(
                children: _reasons.map((r) => RadioListTile<String>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(r, style: const TextStyle(fontSize: 12.5)),
                  value: r,
                  activeColor: AppColors.error,
                )).toList(),
              ),
            ),
            if (isOther) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _customNoteController,
                maxLines: 2,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Enter reason for rejection...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            String finalReason = _selectedReason;
            if (isOther) {
              final text = _customNoteController.text.trim();
              if (text.isNotEmpty) {
                finalReason = text;
              }
            }
            Navigator.pop(context, finalReason);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          child: const Text('Confirm Rejection'),
        ),
      ],
    );
  }
}
