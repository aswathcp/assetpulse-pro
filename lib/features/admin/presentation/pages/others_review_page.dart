import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/others_suggestion_service.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/animated_gradient_background.dart';

class OthersReviewPage extends StatefulWidget {
  const OthersReviewPage({super.key});

  @override
  State<OthersReviewPage> createState() => _OthersReviewPageState();
}

class _OthersReviewPageState extends State<OthersReviewPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirestoreService _firestoreService = FirestoreService();
  Map<String, dynamic>? _userProfile;
  String _filterCollection = 'all';

  final _collectionLabels = const {
    'all': 'All',
    'master_equipments': 'Equipment',
    'locations': 'Locations',
    'feeders': 'Feeders',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = AuthService().currentUser;
    if (user != null) {
      final profile = await _firestoreService.getUserProfile(user.uid);
      if (mounted) setState(() => _userProfile = profile);
    }
  }

  String get _reviewerName => _userProfile?['displayName'] ?? 'Admin';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Others Review Queue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Pending catalog additions from field', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_outlined),
            tooltip: 'Filter by collection',
            onSelected: (v) => setState(() => _filterCollection = v),
            itemBuilder: (_) => _collectionLabels.entries
                .map((e) => PopupMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
          ),
        ],
      ),
      body: AnimatedGradientBackground(
        child: Column(
          children: [
            // Tab bar
            Container(
              color: isDark ? Colors.transparent : Colors.white.withValues(alpha: 0.5),
              child: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Pending', icon: Icon(Icons.pending_actions, size: 18)),
                  Tab(text: 'Reviewed', icon: Icon(Icons.done_all, size: 18)),
                ],
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                unselectedLabelStyle: const TextStyle(fontSize: 12),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSuggestionList('pending', isDark),
                  _buildSuggestionList('reviewed', isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionList(String tab, bool isDark) {
    final stream = tab == 'pending'
        ? OthersSuggestionService.pendingStream()
        : OthersSuggestionService.allStream();

    return StreamBuilder<List<OthersSuggestion>>(
      stream: stream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        var items = snap.data ?? [];

        // Tab filter
        if (tab == 'reviewed') {
          items = items.where((s) => s.status != 'pending').toList();
        }

        // Collection filter
        if (_filterCollection != 'all') {
          items = items.where((s) => s.collection == _filterCollection).toList();
        }

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  tab == 'pending' ? Icons.check_circle_outline : Icons.inbox_outlined,
                  size: 60,
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                ),
                const SizedBox(height: 12),
                Text(
                  tab == 'pending' ? 'No pending suggestions!\nAll clear.' : 'No reviewed items yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: isDark ? Colors.white38 : Colors.grey, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (_, i) => _buildSuggestionCard(items[i], isDark),
        );
      },
    );
  }

  Widget _buildSuggestionCard(OthersSuggestion suggestion, bool isDark) {
    Color statusColor;
    IconData statusIcon;
    switch (suggestion.status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending_actions;
    }

    final collLabel = _collectionLabels[suggestion.collection] ?? suggestion.collection;
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(suggestion.submittedAt.toLocal());

    return GlassContainer(
      borderRadius: 14,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(collLabel, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                ),
                const Spacer(),
                Icon(statusIcon, size: 16, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  suggestion.status.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Suggested name
            Text(
              suggestion.suggestedName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),

            // Context & submitter
            if (suggestion.context != null)
              Text(
                suggestion.context!,
                style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade600),
              ),
            const SizedBox(height: 6),

            Row(
              children: [
                Icon(Icons.person_outline, size: 12, color: isDark ? Colors.white38 : Colors.grey),
                const SizedBox(width: 4),
                Text(
                  suggestion.submittedByName ?? 'Unknown',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade600),
                ),
                const SizedBox(width: 12),
                Icon(Icons.schedule, size: 12, color: isDark ? Colors.white38 : Colors.grey),
                const SizedBox(width: 4),
                Text(
                  dateStr,
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade600),
                ),
                if (suggestion.plantId != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.factory_outlined, size: 12, color: isDark ? Colors.white38 : Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${suggestion.plantId} / ${suggestion.unitId ?? '?'}',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade600),
                  ),
                ],
              ],
            ),

            // Review note if present
            if (suggestion.reviewNote != null && suggestion.reviewNote!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (suggestion.status == 'approved' ? Colors.green : Colors.red).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (suggestion.status == 'approved' ? Colors.green : Colors.red).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.comment_outlined, size: 13, color: statusColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        suggestion.reviewNote!,
                        style: TextStyle(fontSize: 11, color: statusColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Action buttons (only for pending)
            if (suggestion.status == 'pending') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectDialog(suggestion),
                      icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                      label: const Text('Reject', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _approveDialog(suggestion),
                      icon: const Icon(Icons.check, size: 16, color: Colors.white),
                      label: const Text('Approve & Add to DB', style: TextStyle(color: Colors.white, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _approveDialog(OthersSuggestion suggestion) async {
    final noteCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve & Add to Catalog', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add "${suggestion.suggestedName}" to ${_collectionLabels[suggestion.collection] ?? suggestion.collection} catalog?',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Review Note (Optional)',
                hintText: 'e.g. Added to database',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await OthersSuggestionService.approve(
        suggestion.id,
        reviewedByName: _reviewerName,
        note: noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : 'Approved by $_reviewerName',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${suggestion.suggestedName}" approved! Remember to add it to the ${_collectionLabels[suggestion.collection]} catalog in Firestore.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _rejectDialog(OthersSuggestion suggestion) async {
    final noteCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Suggestion', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reject "${suggestion.suggestedName}"?', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason for Rejection',
                hintText: 'e.g. Duplicate, already exists as XYZ',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await OthersSuggestionService.reject(
        suggestion.id,
        reviewedByName: _reviewerName,
        note: noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : 'Rejected by $_reviewerName',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Suggestion rejected.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
