// ignore_for_file: deprecated_member_use
import 'package:material_ui/material_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:asset_pulse_pro/core/constants/app_colors.dart';
import 'package:asset_pulse_pro/core/widgets/pulse_loading.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/rendering.dart';
import 'package:file_picker/file_picker.dart';
import 'shift_checklist_config_page.dart';
import 'shift_checklist_presets.dart';

class ShiftChecklistManagementPage extends StatefulWidget {
  final String plantId;
  final String unitId;
  final bool isAdmin;
  final String userRole;
  final VoidCallback onBack;

  const ShiftChecklistManagementPage({
    super.key,
    required this.plantId,
    required this.unitId,
    required this.isAdmin,
    required this.userRole,
    required this.onBack,
  });

  @override
  State<ShiftChecklistManagementPage> createState() => _ShiftChecklistManagementPageState();
}

class _ShiftChecklistManagementPageState extends State<ShiftChecklistManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ShiftChecklistPresetService _presetService = ShiftChecklistPresetService();
  bool _isGenerating = false;

  void _deleteChecklist(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Delete Checklist?'),
        content: const Text('Are you sure you want to permanently delete this checklist configuration?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore.collection('custom_checklists').doc(id).delete();
    }
  }

  void _showQRCodeDialog(Map<String, dynamic> checklist) {
    final qrData = checklist['name'];
    final qrRepaintKey = GlobalKey();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Equipment QR Code'),
        content: SizedBox(
          width: 250,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('Print & affix this QR directly onto the physical equipment.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
              const SizedBox(height: 24),
              RepaintBoundary(
                key: qrRepaintKey,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(checklist['name'],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  textAlign: TextAlign.center),
              Text('Plant: ${checklist['plantId']} • Unit: ${checklist['unitId']}',
                  style: TextStyle(
                      fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Save QR'),
            onPressed: () => _downloadQRCode(qrRepaintKey, checklist['name']),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadQRCode(GlobalKey repaintKey, String checklistName) async {
    try {
      final boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw 'Failed to capture image';
      Uint8List pngBytes = byteData.buffer.asUint8List();

      final uri = await FilePicker.saveFile(
        dialogTitle: 'Save QR Code',
        fileName: '${checklistName.replaceAll(' ', '_')}_qr.png',
        bytes: pngBytes,
      );
      String? path = uri != null ? (uri.hasScheme && uri.scheme == 'file' ? uri.toFilePath() : uri.path) : null;

      if (path == null) {
        final dir = Directory('/storage/emulated/0/Download');
        if (await dir.exists()) {
          final filePath = '${dir.path}/${checklistName.replaceAll(' ', '_')}_qr.png';
          await File(filePath).writeAsBytes(pngBytes);
          path = filePath;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                path != null ? 'QR Code downloaded to: $path' : 'QR saved locally successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading QR code: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Dialog to auto-generate standard unit checklists from the 20 plant section presets
  void _showPresetGenerationDialog() {
    final selectedKeys = kStandardUnitChecklistPresets.map((p) => p.key).toSet();
    bool overwrite = true;
    String selectedCategory = 'All';

    final categories = ['All', ...kStandardUnitChecklistPresets.map((p) => p.category).toSet()];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final displayedPresets = selectedCategory == 'All'
                ? kStandardUnitChecklistPresets
                : kStandardUnitChecklistPresets.where((p) => p.category == selectedCategory).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              expand: false,
              builder: (_, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.auto_awesome, color: AppColors.primary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Generate Unit Checklists',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Asset-level reliability presets for ${widget.plantId} • ${widget.unitId}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Category filter chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: categories.map((cat) {
                            final isSel = selectedCategory == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(cat, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : Colors.white70)),
                                selected: isSel,
                                selectedColor: AppColors.primary,
                                backgroundColor: Colors.white.withValues(alpha: 0.05),
                                onSelected: (sel) {
                                  if (sel) {
                                    setModalState(() => selectedCategory = cat);
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Select All / Deselect All + Overwrite toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              TextButton(
                                onPressed: () {
                                  setModalState(() {
                                    if (selectedCategory == 'All') {
                                      selectedKeys.addAll(kStandardUnitChecklistPresets.map((p) => p.key));
                                    } else {
                                      selectedKeys.addAll(displayedPresets.map((p) => p.key));
                                    }
                                  });
                                },
                                child: Text('Select (${displayedPresets.length})'),
                              ),
                              const SizedBox(width: 4),
                              TextButton(
                                onPressed: () {
                                  setModalState(() {
                                    if (selectedCategory == 'All') {
                                      selectedKeys.clear();
                                    } else {
                                      for (final p in displayedPresets) {
                                        selectedKeys.remove(p.key);
                                      }
                                    }
                                  });
                                },
                                child: const Text('Clear', style: TextStyle(color: Colors.grey)),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Text('Overwrite', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(width: 4),
                              Switch(
                                value: overwrite,
                                onChanged: (val) {
                                  setModalState(() => overwrite = val);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 14),

                      // List of presets
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: displayedPresets.length,
                          itemBuilder: (context, idx) {
                            final preset = displayedPresets[idx];
                            final isChecked = selectedKeys.contains(preset.key);
                            return CheckboxListTile(
                              dense: true,
                              value: isChecked,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              title: Text(
                                preset.name,
                                style: TextStyle(
                                  fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blueAccent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      preset.category,
                                      style: const TextStyle(fontSize: 9.5, color: Colors.blueAccent, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${preset.fields.length} fields',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                  if (preset.isLocationRequired) ...[
                                    const SizedBox(width: 6),
                                    const Icon(Icons.gps_fixed, size: 11, color: Colors.greenAccent),
                                  ],
                                ],
                              ),
                              onChanged: (val) {
                                setModalState(() {
                                  if (val == true) {
                                    selectedKeys.add(preset.key);
                                  } else {
                                    selectedKeys.remove(preset.key);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.auto_awesome),
                        label: Text(
                          'Generate ${selectedKeys.length} Checklist${selectedKeys.length == 1 ? '' : 's'}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        onPressed: selectedKeys.isEmpty || _isGenerating
                            ? null
                            : () async {
                                final messenger = ScaffoldMessenger.of(context);
                                Navigator.pop(ctx);
                                setState(() => _isGenerating = true);
                                try {
                                  final count = await _presetService.seedPresetsForUnit(
                                    plantId: widget.plantId,
                                    unitId: widget.unitId,
                                    businessId: 'VISL',
                                    selectedKeys: selectedKeys.toList(),
                                    overwrite: overwrite,
                                  );
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          count > 0
                                              ? 'Successfully generated $count checklists for ${widget.plantId} - ${widget.unitId}!'
                                              : 'Checklists already exist. Toggle "Overwrite" to update them.',
                                        ),
                                        backgroundColor: count > 0 ? Colors.green : Colors.orange,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(content: Text('Error generating presets: $e'), backgroundColor: Colors.red),
                                    );
                                  }
                                } finally {
                                  if (mounted) setState(() => _isGenerating = false);
                                }
                              },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Export all checklists of current plant & unit to a JSON file
  Future<void> _exportChecklistsJson() async {
    try {
      final jsonStr = await _presetService.exportUnitChecklistsAsJson(
        plantId: widget.plantId,
        unitId: widget.unitId,
      );
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));

      final uri = await FilePicker.saveFile(
        dialogTitle: 'Export Unit Checklists JSON',
        fileName: '${widget.plantId}_${widget.unitId}_checklists.json',
        bytes: bytes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(uri != null ? 'Exported configuration successfully!' : 'Export saved.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Import checklists from a JSON file
  Future<void> _importChecklistsJson() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
      );
      if (result.isEmpty) return;

      final file = result.first;
      final fileBytes = await file.readAsBytes();
      final content = utf8.decode(fileBytes);

      setState(() => _isGenerating = true);
      final count = await _presetService.importChecklistsFromJson(
        content,
        plantId: widget.plantId,
        unitId: widget.unitId,
        businessId: 'VISL',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported $count checklists into ${widget.plantId} - ${widget.unitId}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing JSON: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Header Style ──────────────────────────────────────────────
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Shift Checklist Management',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Scope: ${widget.plantId}  •  ${widget.unitId}',
                      style: TextStyle(fontSize: 12, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ─── Primary Action: Auto-Generate Unit Checklists ──────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.2),
                  Colors.blueAccent.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.auto_awesome, color: AppColors.primaryLight, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '1-Click Standard Unit Checklists',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Instant setup of all 20 plant section checklists without manual entry.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isGenerating ? null : _showPresetGenerationDialog,
                  child: _isGenerating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Generate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ─── Inline Secondary Action Buttons ────────────────────────────
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Custom Checklist',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ShiftChecklistConfigPage(
                          plantId: widget.plantId,
                          unitId: widget.unitId,
                        ),
                      ),
                    ).then((value) {
                      if (value == true && mounted) {
                        setState(() {});
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.blueAccent.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.download, size: 15, color: Colors.blueAccent),
                label: const Text('Export JSON', style: TextStyle(fontSize: 11, color: Colors.blueAccent)),
                onPressed: _exportChecklistsJson,
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.greenAccent.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.file_upload, size: 15, color: Colors.greenAccent),
                label: const Text('Import JSON', style: TextStyle(fontSize: 11, color: Colors.greenAccent)),
                onPressed: _importChecklistsJson,
              ),
            ],
          ),
          const Divider(height: 28),

          // ─── Streamed checklist list ────────────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('custom_checklists')
                .where('plantId', isEqualTo: widget.plantId)
                .where('unitId', isEqualTo: widget.unitId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: PulseLoading());
              }

              final docs = snapshot.hasData ? snapshot.data!.docs : [];

              if (docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.checklist_rtl_outlined, size: 48, color: Colors.grey.shade600),
                        const SizedBox(height: 12),
                        const Text(
                          'No Checklists Configured',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tap "Generate" above to load standard unit checklists\nor create a custom checklist.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final checklist = docs[index].data() as Map<String, dynamic>;
                  final isGeofenced = checklist['isLocationRequired'] == true;
                  final fieldCount = (checklist['fields'] as List? ?? []).length;
                  final typeKey = checklist['checklistTypeKey'] ?? checklist['type'] ?? 'custom';

                  final typeMatch = kChecklistTypes.firstWhere(
                    (t) => t['value'] == typeKey,
                    orElse: () => {'label': typeKey, 'color': 0xFF6B7280},
                  );
                  final typeColor = Color(typeMatch['color'] as int? ?? 0xFF6B7280);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: typeColor.withValues(alpha: 0.18),
                                child: Icon(Icons.fact_check, size: 16, color: typeColor),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      checklist['name'] ?? 'Untitled Checklist',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      typeMatch['label'] as String? ?? typeKey,
                                      style: TextStyle(fontSize: 11, color: typeColor, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isGeofenced
                                      ? Colors.green.withValues(alpha: 0.15)
                                      : Colors.grey.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isGeofenced
                                        ? Colors.green.withValues(alpha: 0.3)
                                        : Colors.grey.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  isGeofenced ? 'GPS Active' : 'No Geofence',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isGeofenced ? Colors.greenAccent : Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            children: [
                              Icon(Icons.list_alt, size: 13, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text(
                                '$fieldCount field${fieldCount == 1 ? '' : 's'} configured',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              if (isGeofenced) ...[
                                const SizedBox(width: 12),
                                Icon(Icons.gps_fixed, size: 13, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Lat: ${(checklist['latitude'] as num?)?.toStringAsFixed(4) ?? 'N/A'}, Lng: ${(checklist['longitude'] as num?)?.toStringAsFixed(4) ?? 'N/A'}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.blueAccent.withValues(alpha: 0.5)),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.qr_code_2, color: Colors.blueAccent, size: 15),
                                label: const Text('QR',
                                    style: TextStyle(fontSize: 11, color: Colors.blueAccent)),
                                onPressed: () => _showQRCodeDialog(checklist),
                              ),
                              if (widget.isAdmin) ...[
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.green.withValues(alpha: 0.5)),
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.edit_outlined,
                                      color: Colors.greenAccent, size: 15),
                                  label: const Text('Edit',
                                      style: TextStyle(fontSize: 11, color: Colors.greenAccent)),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ShiftChecklistConfigPage(
                                          plantId: widget.plantId,
                                          unitId: widget.unitId,
                                          existingChecklist: checklist,
                                        ),
                                      ),
                                    ).then((value) {
                                      if (value == true && mounted) {
                                        setState(() {});
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                        color: Colors.redAccent.withValues(alpha: 0.5)),
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.redAccent, size: 15),
                                  label: const Text('Delete',
                                      style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                                  onPressed: () => _deleteChecklist(checklist['id']),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
