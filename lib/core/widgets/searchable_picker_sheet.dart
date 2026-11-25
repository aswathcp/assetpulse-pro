import 'package:flutter/material.dart';

/// A generic item for searchable pickers.
class PickerItem {
  final String id;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final bool isOthers;

  const PickerItem({
    required this.id,
    required this.label,
    this.subtitle,
    this.icon,
    this.isOthers = false,
  });
}

/// Shows a searchable bottom-sheet picker.
/// Returns the selected [PickerItem] or null if dismissed.
Future<PickerItem?> showSearchablePicker({
  required BuildContext context,
  required String title,
  required List<PickerItem> items,
  String? currentId,
  bool allowOthers = true,
  String? othersHint,
}) async {
  return showModalBottomSheet<PickerItem>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _SearchablePickerSheet(
      title: title,
      items: items,
      currentId: currentId,
      allowOthers: allowOthers,
      othersHint: othersHint ?? 'Type your custom entry...',
    ),
  );
}

class _SearchablePickerSheet extends StatefulWidget {
  final String title;
  final List<PickerItem> items;
  final String? currentId;
  final bool allowOthers;
  final String othersHint;

  const _SearchablePickerSheet({
    required this.title,
    required this.items,
    this.currentId,
    required this.allowOthers,
    required this.othersHint,
  });

  @override
  State<_SearchablePickerSheet> createState() => _SearchablePickerSheetState();
}

class _SearchablePickerSheetState extends State<_SearchablePickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _othersCtrl = TextEditingController();
  bool _showOthersInput = false;
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _othersCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = widget.items.where((i) {
      if (_query.isEmpty) return true;
      return i.label.toLowerCase().contains(_query.toLowerCase()) ||
          (i.subtitle?.toLowerCase().contains(_query.toLowerCase()) ?? false) ||
          i.id.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search ${widget.title.toLowerCase()}...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (v) => setState(() {
                  _query = v;
                  _showOthersInput = false;
                }),
              ),
            ),
            // Count
            if (filtered.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${filtered.length} result${filtered.length == 1 ? "" : "s"}',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey),
                  ),
                ),
              ),
            // List
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                children: [
                  ...filtered.map((item) {
                    final isSelected = item.id == widget.currentId;
                    return _buildItemTile(item, isSelected, isDark);
                  }),
                  // Others option
                  if (widget.allowOthers) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1),
                    ),
                    if (!_showOthersInput)
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.add_circle_outline, color: Colors.orange, size: 18),
                        ),
                        title: const Text(
                          'Others (Not in list)',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 13),
                        ),
                        subtitle: const Text(
                          'Submit a new entry for admin review',
                          style: TextStyle(fontSize: 11),
                        ),
                        onTap: () => setState(() => _showOthersInput = true),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Type your custom entry:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _othersCtrl,
                              autofocus: true,
                              decoration: InputDecoration(
                                hintText: widget.othersHint,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                filled: true,
                                fillColor: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white,
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '⚠️ This will be submitted for admin review and added to the catalog.',
                              style: TextStyle(fontSize: 10, color: Colors.orange),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                OutlinedButton(
                                  onPressed: () => setState(() => _showOthersInput = false),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.grey,
                                    side: const BorderSide(color: Colors.grey),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      final v = _othersCtrl.text.trim();
                                      if (v.isEmpty) return;
                                      Navigator.pop(
                                        context,
                                        PickerItem(
                                          id: '__others__',
                                          label: v,
                                          subtitle: 'Pending admin review',
                                          isOthers: true,
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.send_outlined, size: 16),
                                    label: const Text('Submit', style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemTile(PickerItem item, bool isSelected, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF2563EB).withValues(alpha: 0.12)
            : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF2563EB).withValues(alpha: 0.5)
              : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
        ),
      ),
      child: ListTile(
        dense: true,
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF2563EB).withValues(alpha: 0.2)
                : (isDark ? Colors.white10 : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            item.icon ?? Icons.radio_button_off,
            size: 16,
            color: isSelected ? const Color(0xFF2563EB) : Colors.grey,
          ),
        ),
        title: Text(
          item.label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? const Color(0xFF2563EB) : null,
          ),
        ),
        subtitle: item.subtitle != null
            ? Text(item.subtitle!, style: const TextStyle(fontSize: 11))
            : null,
        trailing: isSelected
            ? const Icon(Icons.check_circle, color: Color(0xFF2563EB), size: 18)
            : null,
        onTap: () => Navigator.pop(context, item),
      ),
    );
  }
}
