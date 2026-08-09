import 'package:flutter/material.dart';
import 'package:asset_pulse_pro/features/assets/data/models/isolation_permit_model.dart';
import 'add_isolation_permit_page.dart';
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
            'Feeder: ${widget.permit.feederId}',
            style: const TextStyle(fontSize: 14),
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
        _buildInfoRow('Location', widget.permit.locationId),
        _buildInfoRow('Panel', widget.permit.panelId),
        const SizedBox(height: 12),
        const Text('Authorized Personnel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        _buildInfoRow('Requester', widget.permit.requestingOfficerId),
        _buildInfoRow('Isolator', widget.permit.isolationOfficerId),
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
          SizedBox(width: 80, child: Text('$label:', style: const TextStyle(color: Colors.grey, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
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
    
    // Requesting Officers for clearance (same department)
    final req = await _firestoreService.getLotoAuthorizedUsers(
      businessId: businessId,
      isRequestingAuth: true,
      isIsolationAuth: false,
      department: widget.permit.requestingDepartment,
    );

    // Isolation Officers (Normalizing)
    final iso = await _firestoreService.getLotoAuthorizedUsers(
      businessId: businessId,
      isRequestingAuth: false,
      isIsolationAuth: true,
    );

    setState(() {
      _reqOfficers = req;
      _isoOfficers = iso;
    });
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
        requestingDepartment: widget.permit.requestingDepartment,
        reason: widget.permit.reason,
        isolationDateTime: widget.permit.isolationDateTime,
        requestingOfficerId: widget.permit.requestingOfficerId,
        isolationOfficerId: widget.permit.isolationOfficerId,
        requesterLockNo: widget.permit.requesterLockNo,
        isolationOfficerLockNo: widget.permit.isolationOfficerLockNo,
        personalLocksCount: widget.permit.personalLocksCount,
        status: IsolationStatus.cleared,
        clearingOfficerId: _selectedClearingOfficerId,
        normalizingOfficerId: _selectedNormalizingOfficerId,
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
