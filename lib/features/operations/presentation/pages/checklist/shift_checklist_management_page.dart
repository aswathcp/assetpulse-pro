import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:asset_pulse_pro/core/constants/app_colors.dart';
import 'package:asset_pulse_pro/core/widgets/pulse_loading.dart';
import 'package:asset_pulse_pro/features/admin/presentation/pages/data_import_page.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/rendering.dart';
import 'package:file_picker/file_picker.dart';
import 'shift_checklist_config_page.dart';

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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ElevatedButton.icon(
            icon: const Icon(Icons.download, size: 16, color: Colors.white),
            label: const Text('Download QR', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLight),
            onPressed: () => _downloadQR(qrRepaintKey, checklist['name']),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadQR(GlobalKey repaintKey, String checklistName) async {
    try {
      RenderRepaintBoundary boundary =
          repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw 'Failed to capture image';
      Uint8List pngBytes = byteData.buffer.asUint8List();

      String? path = await FilePicker.saveFile(
        dialogTitle: 'Save QR Code',
        fileName: '${checklistName.replaceAll(' ', '_')}_qr.png',
        bytes: pngBytes,
      );

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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Header Style matching Lux ──────────────────────────────────
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Shift Checklist Management',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ─── Inline Action Buttons (Add / Import) ───────────────────────
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Add New Checklist',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent.withValues(alpha: 0.15),
                    foregroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.file_upload),
                  label: const Text('Import Excel', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DataImportPage(
                          collectionId: 'custom_checklists',
                          title: 'Shift Checklists',
                          plantId: widget.plantId,
                          unitId: widget.unitId,
                        ),
                      ),
                    );
                    if (mounted) setState(() {});
                  },
                ),
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
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'No custom checklists configured for ${widget.plantId} • ${widget.unitId} yet.',
                      style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final checklist = doc.data() as Map<String, dynamic>;
                  final isGeofenced = checklist['isLocationRequired'] == true;
                  final fieldsList = (checklist['fields'] ?? []) as List;
                  final fieldCount = fieldsList.length;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: isGeofenced
                                      ? Colors.blueAccent.withValues(alpha: 0.12)
                                      : Colors.grey.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isGeofenced ? Icons.location_on : Icons.assignment_outlined,
                                  color: isGeofenced ? Colors.blueAccent : Colors.grey,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      checklist['name'] ?? '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Type: ${checklist['checklistTypeKey'] == "battery_room" ? "Battery Room" : "Other"}',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isGeofenced
                                      ? Colors.blueAccent.withValues(alpha: 0.12)
                                      : Colors.grey.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: isGeofenced
                                          ? Colors.blueAccent.withValues(alpha: 0.4)
                                          : Colors.grey.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  isGeofenced ? 'GPS' : 'NO GPS',
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: isGeofenced ? Colors.blueAccent : Colors.grey),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 14),
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
