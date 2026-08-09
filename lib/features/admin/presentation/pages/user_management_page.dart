import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final String myRole = widget.currentUserProfile['role'] ?? AppRoles.guest;
      final String? myPlantId = widget.currentUserProfile['plantId'];
      final String? myUnitId = widget.currentUserProfile['unitId'];
      final String? myBusinessId = widget.currentUserProfile['businessId']; // NEW

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
    
    // Determine allowed roles to promote to
    List<String> allowedRoles = [];
    
    if (myRole == AppRoles.developer) {
      allowedRoles = AppRoles.values;
    } else {
      allowedRoles = AppRoles.values.where((r) => r != AppRoles.developer).toList();
    }

    if (allowedRoles.isEmpty || userId == FirebaseAuth.instance.currentUser?.uid) return; // Prevent editing own profile

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
        _loadUsers(); // Refresh
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
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Approve User', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text('Are you sure you want to approve this user?\n\nRole: ${user['role']}\nScope: ${user['plantId']} - ${user['unitId']}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Approve', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'isValidated': true,
          'approvedBy': widget.currentUserProfile['uid'], // Audit
          'approvedAt': FieldValue.serverTimestamp(),
        });
        
        _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User Approved Successfully'), backgroundColor: AppColors.success),
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
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Reject Registration Request?'),
        content: Text('Are you sure you want to reject the request for ${user['displayName'] ?? 'Unknown'}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'isRejected': true,
          'isValidated': false,
        });
        _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration request rejected'), backgroundColor: AppColors.error),
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
      // Determine new values
      final isRequesting = field == 'isRequestingAuth' ? newValue : (user['isRequestingAuth'] ?? false);
      final isIsolation = field == 'isIsolationAuth' ? newValue : (user['isIsolationAuth'] ?? false);

      await _firestoreService.updateUserLotoRights(
        user['uid'], 
        isRequestingAuth: isRequesting, 
        isIsolationAuth: isIsolation
      );
      
      _loadUsers(); // Refresh UI
      
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface), // Fix invisible back button
        titleTextStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold), // Ensure title visible
      ),
      body: AnimatedGradientBackground(
        child: _isLoading 
          ? const Center(child: PulseLoading(size: 60))
          : _errorMessage != null 
            ? Center(child: Text('Error: $_errorMessage', style: const TextStyle(color: AppColors.error)))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  final user = _users[index];
                  final isMe = user['uid'] == FirebaseAuth.instance.currentUser?.uid;
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GlassContainer(
                      width: double.infinity,
                      height: null,
                      borderRadius: 12,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primaryLight,
                              child: Text(
                                (user['displayName'] ?? 'U')[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user['displayName'] ?? 'Unknown',
                                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(user['email'] ?? '', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        '${user['role']} • ${user['department'] ?? 'No Dept'} • ${user['plantId']} • ${user['unitId']}${user['isAdmin'] == true ? ' • Admin' : ''}',
                                        style: const TextStyle(color: AppColors.accent, fontSize: 11),
                                      ),
                                      if (user['isValidated'] == false)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                                          child: const Text('Pending Approval', style: TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  // LOTO Rights
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      // Requesting Auth Toggle
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
                                      // Isolation Auth Toggle
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
                            // Trailing
                            isMe 
                              ? Chip(label: const Text('Me', style: TextStyle(color: Colors.white, fontSize: 10)), backgroundColor: Theme.of(context).disabledColor)
                              : !PermissionHelper.canManageUser(widget.currentUserProfile, user)
                                ? const Tooltip(
                                    message: 'No permission to manage this user (equal or higher authority)',
                                    child: Icon(Icons.lock_outline, color: Colors.grey, size: 20),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (user['isValidated'] == false) ...[
                                        IconButton(
                                          icon: const Icon(Icons.check_circle, color: AppColors.success, size: 28),
                                          onPressed: () => _approveUser(user),
                                          tooltip: 'Approve User',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.cancel, color: AppColors.error, size: 28),
                                          onPressed: () => _rejectUser(user),
                                          tooltip: 'Reject User Request',
                                        ),
                                      ],
                                      IconButton(
                                        icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
  late bool _isAdmin;

  final List<String> _departments = ['Electrical', 'Mechanical', 'Operations', 'Instrumentation', 'Safety', 'Other'];
  List<String> _plants = [];
  List<String> _units = [];

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.allowedRoles.contains(widget.currentRole) ? widget.currentRole : widget.allowedRoles.first;
    _selectedDept = _departments.contains(widget.currentDept) ? widget.currentDept : 'Other';
    _isAdmin = widget.currentIsAdmin;

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
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Admin Rights', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
              subtitle: Text('Grants capability to modify database values', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              value: _isAdmin,
              onChanged: (v) => setState(() => _isAdmin = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, {
            'role': _selectedRole,
            'department': _selectedDept,
            'plantId': _selectedPlant,
            'unitId': _selectedUnit,
            'isAdmin': _isAdmin,
          }),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLight),
          child: const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
