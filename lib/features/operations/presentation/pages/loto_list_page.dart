import 'package:flutter/material.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/loto_service.dart';
import '../../../../core/services/firestore_service.dart'; // NEW
import '../../../../core/widgets/pulse_loading.dart';
import '../../data/models/loto_model.dart';
import 'create_loto_page.dart'; // Will create next
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';

class LotoListWidget extends StatefulWidget {
  const LotoListWidget({super.key});

  @override
  State<LotoListWidget> createState() => _LotoListWidgetState();
}

class _LotoListWidgetState extends State<LotoListWidget> with SingleTickerProviderStateMixin {
  late TabController _internalTabController;
  final LotoService _lotoService = LotoService();
  String? _currentUserId;
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _internalTabController = TabController(length: 2, vsync: this);
    _loadUser();
  }
  
  void _loadUser() async {
     final user = AuthService().currentUser;
     if (user != null) {
       final profile = await FirestoreService().getUserProfile(user.uid);
       if (mounted) {
         setState(() {
           _currentUserId = user.uid;
           _userProfile = profile;
         });
       }
     }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sub-tabs for LOTO
        Container(
           margin: const EdgeInsets.symmetric(horizontal: 24),
           child: TabBar(
            controller: _internalTabController,
            labelColor: AppColors.accent,
            unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'Active / Pending'),
              Tab(text: 'My Requests'),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Action Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreateLotoPage()),
                );
              },
              icon: const Icon(Icons.add_moderator),
              label: const Text('New Isolation Request'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
                foregroundColor: AppColors.accent,
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        Expanded(
          child: TabBarView(
            controller: _internalTabController,
            children: [
              _buildLotoList(stream: _lotoService.getActiveLotos()),
              if (_currentUserId != null)
                 _buildLotoList(stream: _lotoService.getMyRequests(_currentUserId!))
              else
                 const Center(child: Text('Please log in')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLotoList({required Stream<List<LotoModel>> stream}) {
    return StreamBuilder<List<LotoModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: PulseLoading(size: 40));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return Center(
             child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.check_circle_outline, size: 60, color: Colors.green.withValues(alpha: 0.5)),
                   const SizedBox(height: 16),
                   const Text('No Active LOTO', style: TextStyle(color: Colors.grey)),
                ],
             ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
             return _buildLotoCard(requests[index]);
          },
        );
      },
    );
  }

  Widget _buildLotoCard(LotoModel loto) {
    final bool isIsolator = _userProfile?['isIsolationAuth'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
         width: double.infinity,
         borderRadius: 12,
         child: Padding(
           padding: const EdgeInsets.all(16),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               // Header
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                    Expanded(
                      child: Text(
                        '${loto.assetTag} - ${loto.assetName}', 
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusBadge(loto.status),
                 ],
               ),
               const SizedBox(height: 8),
               
               // Details
               Text('Point: ${loto.isolationPoint}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
               Text('Reason: ${loto.reason}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
               const SizedBox(height: 8),

               // Requester Info
               Row(
                 children: [
                    Icon(Icons.person_outline, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('Req: ${loto.requesterName}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                 ],
               ),
               
               // Divider if actions are available
               if ((loto.status == LotoStatus.requested && isIsolator) || (loto.status == LotoStatus.active && isIsolator))
                 const Divider(height: 24),
                 
               // Action Buttons
               if (loto.status == LotoStatus.requested && isIsolator)
                 Row(
                   mainAxisAlignment: MainAxisAlignment.end,
                   children: [
                     OutlinedButton(
                       onPressed: () => _handleAction(loto, 'reject'),
                       child: const Text('Reject', style: TextStyle(color: Colors.grey)),
                     ),
                     const SizedBox(width: 8),
                     ElevatedButton.icon(
                       onPressed: () => _handleAction(loto, 'approve'),
                       icon: const Icon(Icons.lock, size: 16),
                       label: const Text('Approve & Lock'),
                       style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                     ),
                   ],
                 ),
                 
               if (loto.status == LotoStatus.active && isIsolator)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _handleAction(loto, 'complete'),
                        icon: const Icon(Icons.lock_open),
                        label: const Text('Remove Lock & Close'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                      ),
                    ),
                  ),
             ],
           ),
         ),
      ),
    );
  }

  Future<void> _handleAction(LotoModel loto, String action) async {
    if (_userProfile == null) return;
    
    final name = _userProfile!['name'] ?? 'Admin';
    final uid = _userProfile!['uid'];

    try {
      if (action == 'approve') {
        await _lotoService.approveRequest(loto.id, uid, name);
      } else if (action == 'reject') {
         await _lotoService.rejectRequest(loto.id, uid, name);
      } else if (action == 'complete') {
         await _lotoService.completeRequest(loto.id);
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Request Updated')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
  
  Widget _buildStatusBadge(LotoStatus status) {
     Color color;
     switch (status) {
       case LotoStatus.requested: color = Colors.orange; break;
       case LotoStatus.active: color = AppColors.error; break; // Red for Locked
       case LotoStatus.completed: color = Colors.green; break;
       case LotoStatus.rejected: color = Colors.grey; break;
     }
     
     return Container(
       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
       decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color),
       ),
       child: Text(status.name.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
     );
  }
}
