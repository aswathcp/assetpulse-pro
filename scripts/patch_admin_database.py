import os

path = 'lib/features/admin/presentation/pages/admin_database_page.dart'
with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = [
    "                                            if (widget.collectionId == 'fault_types') {\n",
    "                                              final code = item['faultCode'] ?? item['id'] ?? rawId;\n",
    "                                              final cat = item['category'] ?? item['discipline'] ?? 'Electrical';\n",
    "                                              final sev = item['severity'] ?? item['defaultSeverity'] ?? 'Major';\n",
    "                                              final target = item['targetEquipment'] ?? item['equipmentType'] ?? '';\n",
    "                                              title = item['name'] ?? item['faultName'] ?? rawId;\n",
    "                                              subtitle = 'Code: $code | $cat ' + (target.isNotEmpty ? '• $target ' : '') + '| Severity: $sev';\n",
    "                                            }\n",
    "                                            if (widget.collectionId == 'odc_causes') {\n",
    "                                              final obj = item['objectPart'] ?? item['object'] ?? '';\n",
    "                                              final dmg = item['damage'] ?? '';\n",
    "                                              final cau = item['cause'] ?? item['name'] ?? '';\n",
    "                                              final eqCat = item['equipmentCategory'] ?? item['category'] ?? '';\n",
    "                                              final disc = item['discipline'] ?? '';\n",
    "                                              if (obj.isNotEmpty && dmg.isNotEmpty) {\n",
    "                                                title = '$obj ➔ $dmg';\n",
    "                                                subtitle = 'Root Cause: $cau\\nEq: $eqCat ($disc) | Code: $rawId';\n",
    "                                              } else {\n",
    "                                                title = item['name'] ?? (cau.isNotEmpty ? cau : rawId);\n",
    "                                                subtitle = 'Root Cause: $cau | Eq: $eqCat ($disc) | Code: $rawId';\n",
    "                                              }\n",
    "                                            }\n"
]

lines[699:708] = new_lines

wipe_method = '''
  void _showWipeConfirmation() {
    final isMasterCatalog = widget.collectionId == 'odc_causes' || widget.collectionId == 'fault_types';
    final scopeDesc = isMasterCatalog ? 'the entire catalog in Firestore' : 'all records for plant ' + (_selectedPlant ?? '') + ' / unit ' + (_selectedUnit ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            const SizedBox(width: 10),
            Expanded(child: Text('Wipe ' + widget.title + '?', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
          ],
        ),
        content: Text(
          'Are you sure you want to delete ' + scopeDesc + '?\\n\\nThis will permanently delete all records in collection "' + widget.collectionId + '" so you can re-import clean data from Excel. This action CANNOT be undone.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text('Delete All'),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isUploading = true);
              try {
                final count = await FirestoreService().clearCollection(
                  widget.collectionId,
                  unitId: _selectedUnit,
                  plantId: _selectedPlant,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Successfully deleted ' + count.toString() + ' records from ' + widget.title + '! Ready for clean import.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error wiping collection: ' + e.toString()), backgroundColor: AppColors.error),
                  );
                }
              } finally {
                if (mounted) setState(() => _isUploading = false);
              }
            },
          ),
        ],
      ),
    );
  }
'''

content = ''.join(lines)
idx = content.rfind('}')
content = content[:idx] + wipe_method + '\n}\n'

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('SUCCESS')
