import 'package:flutter/material.dart';
import 'package:asset_pulse_pro/features/assets/data/models/isolation_permit_model.dart';
import 'add_isolation_permit_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/hierarchy_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/widgets/glass_container.dart';

class IsolationPermitCard extends StatefulWidget {
  final IsolationPermitModel permit;
  final bool showActions;
  
  const IsolationPermitCard({
    super.key, 
    required this.permit, 
    this.showActions = false,
  });

  @override
  State<IsolationPermitCard> createState() => _IsolationPermitCardState();
}

class _IsolationPermitCardState extends State<IsolationPermitCard> {
  bool _isExpanded = false;
  static final Map<String, String> _userNamesCache = {};

  @override
  void initState() {
    super.initState();
    _checkAndResolveNames();
  }

  @override
  void didUpdateWidget(covariant IsolationPermitCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.permit.id != widget.permit.id) {
      _checkAndResolveNames();
    }
  }

  void _checkAndResolveNames() {
    if (widget.permit.requestingOfficerName == null || widget.permit.requestingOfficerName!.isEmpty) {
      _resolveUserName(widget.permit.requestingOfficerId);
    }
    if (widget.permit.isolationOfficerName == null || widget.permit.isolationOfficerName!.isEmpty) {
      _resolveUserName(widget.permit.isolationOfficerId);
    }
    if (widget.permit.clearingOfficerId != null && widget.permit.clearingOfficerId!.isNotEmpty) {
      _resolveUserName(widget.permit.clearingOfficerId!);
    }
    if (widget.permit.normalizingOfficerId != null && widget.permit.normalizingOfficerId!.isNotEmpty) {
      _resolveUserName(widget.permit.normalizingOfficerId!);
    }
  }

  Future<void> _resolveUserName(String uid) async {
    if (uid.isEmpty || _userNamesCache.containsKey(uid)) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        final data = doc.data();
        final name = (data?['displayName'] ?? data?['name'] ?? data?['email'] ?? uid).toString();
        setState(() {
          _userNamesCache[uid] = name;
        });
      }
    } catch (_) {}
  }

  String get _feederDisplay {
    if (widget.permit.feederName != null && widget.permit.feederName!.isNotEmpty) {
      return widget.permit.feederName!;
    }
    return HierarchyService.stripPrefix(widget.permit.feederId, widget.permit.plantId, widget.permit.unitId);
  }

  String get _panelDisplay {
    if (widget.permit.panelName != null && widget.permit.panelName!.isNotEmpty) {
      return widget.permit.panelName!;
    }
    return HierarchyService.stripPrefix(widget.permit.panelId, widget.permit.plantId, widget.permit.unitId);
  }

  String get _locationDisplay {
    return HierarchyService.stripPrefix(widget.permit.locationId, widget.permit.plantId, widget.permit.unitId);
  }

  String get _requesterDisplay {
    if (widget.permit.requestingOfficerName != null && widget.permit.requestingOfficerName!.isNotEmpty) {
      return widget.permit.requestingOfficerName!;
    }
    return _userNamesCache[widget.permit.requestingOfficerId] ?? widget.permit.requestingOfficerId;
  }

  String get _isolatorDisplay {
    if (widget.permit.isolationOfficerName != null && widget.permit.isolationOfficerName!.isNotEmpty) {
      return widget.permit.isolationOfficerName!;
    }
    return _userNamesCache[widget.permit.isolationOfficerId] ?? widget.permit.isolationOfficerId;
  }

  String _getDuration() {
    final end = widget.permit.clearanceDateTime ?? DateTime.now();
    final diff = end.difference(widget.permit.isolationDateTime);
    
    if (diff.inDays > 0) return '${diff.inDays}d ${diff.inHours % 24}h';
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}m';
    return '${diff.inMinutes}m';
  }

  Color _getStatusColor() {
    switch (widget.permit.status) {
      case IsolationStatus.active: return Colors.orange;
      case IsolationStatus.cleared: return Colors.green;
      case IsolationStatus.renewed: return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      width: double.infinity,
      height: null,
      borderRadius: 16,
      child: InkWell(
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Permit: ${widget.permit.permitNo}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        widget.permit.requestingDepartment,
                        style: TextStyle(color: _getStatusColor(), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  _buildStatusBadge(),
                ],
              ),
              const Divider(height: 24),
              _buildHierarchyInfo(),
              if (_isExpanded) ...[
                const SizedBox(height: 16),
                _buildDetails(),
                if (widget.showActions && widget.permit.status == IsolationStatus.active) _buildActionButtons(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor().withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getStatusColor()),
      ),
      child: Text(
        widget.permit.status.name.toUpperCase(),
        style: TextStyle(color: _getStatusColor(), fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildHierarchyInfo() {
    return Row(
      children: [
        Icon(Icons.electric_bolt, size: 16, color: Colors.blue.shade400),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Feeder: $_feederDisplay',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          _getDuration(),
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Reason', widget.permit.reason),
        _buildInfoRow('Location', _locationDisplay),
        _buildInfoRow('Panel', _panelDisplay),
        const SizedBox(height: 12),
        const Text('Authorized Personnel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        _buildInfoRow('Requester', _requesterDisplay),
        _buildInfoRow('Isolator', _isolatorDisplay),
        if (widget.permit.clearingOfficerId != null && widget.permit.clearingOfficerId!.isNotEmpty)
          _buildInfoRow('Cleared By', widget.permit.clearingOfficerName ?? (_userNamesCache[widget.permit.clearingOfficerId] ?? widget.permit.clearingOfficerId!)),
        if (widget.permit.normalizingOfficerId != null && widget.permit.normalizingOfficerId!.isNotEmpty)
          _buildInfoRow('Normalized By', widget.permit.normalizingOfficerName ?? (_userNamesCache[widget.permit.normalizingOfficerId] ?? widget.permit.normalizingOfficerId!)),
        const SizedBox(height: 12),
        _buildInfoRow('Locks', 'Req: ${widget.permit.requesterLockNo} | Iso: ${widget.permit.isolationOfficerLockNo}'),
        if (widget.permit.personalLocksCount > 0) 
          _buildInfoRow('Personal Locks', widget.permit.personalLocksCount.toString()),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text('$label:', style: const TextStyle(color: Colors.grey, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => AddIsolationPermitPage(renewFrom: widget.permit))
              );
            }, 
            icon: const Icon(Icons.refresh, size: 18), 
            label: const Text('Renew'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _showClearDialog(context), 
            icon: const Icon(Icons.check_circle_outline, size: 18), 
            label: const Text('Clear'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );
  }

  void _showClearDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _ClearPermitDialog(permit: widget.permit),
    );
  }
}

class _ClearPermitDialog extends StatefulWidget {
  final IsolationPermitModel permit;
  const _ClearPermitDialog({required this.permit});

  @override
  State<_ClearPermitDialog> createState() => _ClearPermitDialogState();
}

class _ClearPermitDialogState extends State<_ClearPermitDialog> {
  final _firestoreService = FirestoreService();
  String? _selectedNormalizingOfficerId;
  String? _selectedClearingOfficerId;
  bool _isLoading = false;
  List<Map<String, dynamic>> _isoOfficers = [];
  List<Map<String, dynamic>> _reqOfficers = [];

  @override
  void initState() {
    super.initState();
    _fetchAuthorizedPersonnel();
  }

  Future<void> _fetchAuthorizedPersonnel() async {
    final businessId = widget.permit.businessId;
    
    // Requesting Officers for clearance (same department or higher authority)
    final req = await _firestoreService.getLotoAuthorizedUsers(
      businessId: businessId,
      plantId: widget.permit.plantId,
      unitId: widget.permit.unitId,
      isRequestingAuth: true,
      isIsolationAuth: false,
      department: widget.permit.requestingDepartment,
    );

    // Isolation Officers (Normalizing)
    final iso = await _firestoreService.getLotoAuthorizedUsers(
      businessId: businessId,
      plantId: widget.permit.plantId,
      unitId: widget.permit.unitId,
      isRequestingAuth: false,
      isIsolationAuth: true,
    );

    if (mounted) {
      setState(() {
        _reqOfficers = req;
        _isoOfficers = iso;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Clear Isolation Permit'),
      content: _isLoading 
        ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Provide clearance and normalization authorization to close this permit.', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Clearing Officer'),
                items: _reqOfficers.map((u) => DropdownMenuItem<String>(value: u['uid'] as String, child: Text(u['displayName'] as String))).toList(),
                onChanged: (val) => setState(() => _selectedClearingOfficerId = val),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Normalizing Officer'),
                items: _isoOfficers.map((u) => DropdownMenuItem<String>(value: u['uid'] as String, child: Text(u['displayName'] as String))).toList(),
                onChanged: (val) => setState(() => _selectedNormalizingOfficerId = val),
              ),
            ],
          ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: (_selectedClearingOfficerId == null || _selectedNormalizingOfficerId == null) ? null : _submitClearance, 
          child: const Text('Clear Permit'),
        ),
      ],
    );
  }

  Future<void> _submitClearance() async {
    setState(() => _isLoading = true);
    try {
      final updatedPermit = IsolationPermitModel(
        id: widget.permit.id,
        permitNo: widget.permit.permitNo,
        businessId: widget.permit.businessId,
        plantId: widget.permit.plantId,
        unitId: widget.permit.unitId,
        locationId: widget.permit.locationId,
        panelId: widget.permit.panelId,
        feederId: widget.permit.feederId,
        panelName: widget.permit.panelName,
        feederName: widget.permit.feederName,
        requestingDepartment: widget.permit.requestingDepartment,
        reason: widget.permit.reason,
        isolationDateTime: widget.permit.isolationDateTime,
        requestingOfficerId: widget.permit.requestingOfficerId,
        isolationOfficerId: widget.permit.isolationOfficerId,
        requestingOfficerName: widget.permit.requestingOfficerName,
        isolationOfficerName: widget.permit.isolationOfficerName,
        requesterLockNo: widget.permit.requesterLockNo,
        isolationOfficerLockNo: widget.permit.isolationOfficerLockNo,
        personalLocksCount: widget.permit.personalLocksCount,
        status: IsolationStatus.cleared,
        clearingOfficerId: _selectedClearingOfficerId,
        normalizingOfficerId: _selectedNormalizingOfficerId,
        clearingOfficerName: _reqOfficers.firstWhere((u) => u['uid'] == _selectedClearingOfficerId, orElse: () => {})['displayName'],
        normalizingOfficerName: _isoOfficers.firstWhere((u) => u['uid'] == _selectedNormalizingOfficerId, orElse: () => {})['displayName'],
        clearanceDateTime: DateTime.now(),
        renewalHistory: widget.permit.renewalHistory,
      );

      await _firestoreService.saveIsolationPermit(updatedPermit);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permit Cleared'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
