// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:asset_pulse_pro/core/constants/app_colors.dart';
import 'package:asset_pulse_pro/core/widgets/glass_container.dart';
import 'package:asset_pulse_pro/core/widgets/pulse_loading.dart';
import 'package:asset_pulse_pro/core/widgets/responsive_layout.dart';
import 'package:asset_pulse_pro/features/home/presentation/widgets/custom_app_bar.dart';
import 'package:asset_pulse_pro/core/services/auth_service.dart';
import 'package:asset_pulse_pro/core/services/hierarchy_service.dart';
import 'package:asset_pulse_pro/core/constants/app_roles.dart';
import 'package:asset_pulse_pro/features/assets/data/models/panel_room_model.dart';
import 'package:asset_pulse_pro/features/operations/data/models/panel_room_checklist_model.dart';
import 'package:asset_pulse_pro/features/admin/presentation/pages/admin_database_page.dart';

// PDF, Excel & File Export Dependencies
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:asset_pulse_pro/core/services/excel_service.dart';
import 'package:asset_pulse_pro/core/utils/file_download_helper.dart';

class PanelRoomChecklistPage extends StatefulWidget {
  const PanelRoomChecklistPage({super.key});

  @override
  State<PanelRoomChecklistPage> createState() => _PanelRoomChecklistPageState();
}

class _PanelRoomChecklistPageState extends State<PanelRoomChecklistPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final HierarchyService _hierarchyService = HierarchyService();

  // Scope State
  String? _selectedPlantId;
  String? _selectedUnitId;
  List<String> _plants = [];
  List<String> _units = [];
  bool _isPlantLocked = false;
  bool _isUnitLocked = false;
  bool _isLoading = true;
  String _userRole = '';
  String _currentUserName = '';
  String _currentUserId = '';
  bool _isAdmin = false;

  // View States
  PanelRoomModel? _selectedRoom; // Non-null shows the audit form view
  bool _showHelp = false;

  // Audit Form State
  String _monthYear = '';
  final DateTime _inspectionDate = DateTime.now();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  // Live Data & Audit Items State
  List<PanelRoomModel> _panelRooms = [];
  List<PanelRoomChecklistReportModel> _reports = [];
  List<Map<String, dynamic>> _processedRooms = [];

  // Metrics
  int _totalRooms = 0;
  int _compliantCount = 0;
  int _defectsCount = 0;
  int _pendingCount = 0;
  double _complianceRate = 0.0;
  bool _isSubmitting = false;

  // 14 Mandatory Checkpoints (from physical inspection sheet)
  final List<Map<String, String>> _checklistParameters = const [
    {'key': 'rubberMat', 'label': '1. Rubber Mat'},
    {'key': 'illumination', 'label': '2. Illumination'},
    {'key': 'ventilation', 'label': '3. Ventilation'},
    {'key': 'sealing', 'label': '4. Sealing'},
    {'key': 'cleaning', 'label': '5. Cleaning'},
    {'key': 'dangerBoard', 'label': '6. Danger Board'},
    {'key': 'feederNaming', 'label': '7. Feeder Naming'},
    {'key': 'pprSld', 'label': '8. PPR+ SLD'},
    {'key': 'fireExtinguisher', 'label': '9. Fire Extinguisher'},
    {'key': 'accessControl', 'label': '10. Access Control'},
    {'key': 'emergencyExit', 'label': '11. Emergency Exit'},
    {'key': 'doorInterlock', 'label': '12. Door Interlock'},
    {'key': 'authorisedPeopleList', 'label': '13. List of Authorised People'},
    {'key': 'shockTreatmentChart', 'label': '14. Shock Treatment Chart'},
  ];

  // Current room's checkpoint audit values
  PanelRoomAuditItem? _activeAuditItem;

  @override
  void initState() {
    super.initState();
    _monthYear = _formatMonthYear(DateTime.now());
    _loadUserScope();
  }

  @override
  void dispose() {
    _remarksController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _formatMonthYear(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatDateTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    final min = date.minute.toString().padLeft(2, '0');
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} $hour:$min $ampm";
  }

  Future<void> _loadUserScope() async {
    setState(() => _isLoading = true);
    try {
      final user = AuthService().currentUser;
      if (user != null) {
        _currentUserId = user.uid;
        _currentUserName = user.displayName ?? user.email ?? 'Inspector';

        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data()!;
          _userRole = data['role'] ?? AppRoles.guest;
          _isAdmin = data['isAdmin'] == true ||
              _userRole == AppRoles.developer ||
              _userRole == AppRoles.businessAdmin;

          final fetchedName = (data['displayName'] ?? data['name'] ?? data['fullName'] ?? '').toString().trim();
          if (fetchedName.isNotEmpty) {
            _currentUserName = fetchedName;
          } else if (user.displayName != null && user.displayName!.isNotEmpty) {
            _currentUserName = user.displayName!;
          } else if (user.email != null && user.email!.isNotEmpty) {
            _currentUserName = user.email!;
          }

          final userPlant = data['plantId'] as String?;
          final userUnit = data['unitId'] as String?;

          _plants = _hierarchyService.getPlants();

          if (_isAdmin) {
            _selectedPlantId = userPlant ?? (_plants.isNotEmpty ? _plants.first : 'VISL');
            _units = _hierarchyService.getUnitsForPlant(_selectedPlantId!);
            _selectedUnitId = userUnit ?? (_units.isNotEmpty ? _units.first : 'UNIT-1');
          } else {
            _isPlantLocked = userPlant != null && userPlant.isNotEmpty;
            _selectedPlantId = userPlant ?? (_plants.isNotEmpty ? _plants.first : 'VISL');

            _units = _hierarchyService.getUnitsForPlant(_selectedPlantId!);
            _isUnitLocked = userUnit != null && userUnit.isNotEmpty;
            _selectedUnitId = userUnit ?? (_units.isNotEmpty ? _units.first : 'UNIT-1');
          }
        } else {
          _plants = _hierarchyService.getPlants();
          _selectedPlantId = _plants.isNotEmpty ? _plants.first : 'VISL';
          _units = _hierarchyService.getUnitsForPlant(_selectedPlantId!);
          _selectedUnitId = _units.isNotEmpty ? _units.first : 'UNIT-1';
        }
      }

      await _fetchData();
    } catch (e) {
      debugPrint('Error loading scope in PanelRoomChecklistPage: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchData() async {
    if (_selectedUnitId == null || _selectedPlantId == null) return;

    try {
      // Query global panel_rooms collection
      Query prQuery = _firestore.collection('panel_rooms');
      if (_selectedUnitId != 'ALL') {
        prQuery = prQuery.where('unitId', isEqualTo: _selectedUnitId);
      }
      if (_selectedPlantId != 'ALL') {
        prQuery = prQuery.where('plantId', isEqualTo: _selectedPlantId);
      }

      final snapshot = await prQuery.get();
      final rooms = snapshot.docs
          .map((d) => PanelRoomModel.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();

      rooms.sort((a, b) => a.name.compareTo(b.name));

      // Fetch history reports
      Query reportQuery = _firestore.collection('panel_room_reports');
      if (_selectedUnitId != 'ALL') {
        reportQuery = reportQuery.where('unitId', isEqualTo: _selectedUnitId);
      }
      if (_selectedPlantId != 'ALL') {
        reportQuery = reportQuery.where('plantId', isEqualTo: _selectedPlantId);
      }

      final reportSnap = await reportQuery.get();
      final reports = reportSnap.docs
          .map((d) => PanelRoomChecklistReportModel.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
      reports.sort((a, b) => b.inspectionDate.compareTo(a.inspectionDate));

      _panelRooms = rooms;
      _reports = reports;

      _processMetricsData();
    } catch (e) {
      debugPrint('Error fetching panel rooms data: $e');
    }
  }

  void _processMetricsData() {
    int compliant = 0;
    int defects = 0;
    int pending = 0;

    final List<Map<String, dynamic>> processed = [];
    final latestReport = _reports.isNotEmpty ? _reports.first : null;

    for (final room in _panelRooms) {
      PanelRoomAuditItem? roomAudit;
      if (latestReport != null) {
        final matches = latestReport.roomAudits.where((a) => a.panelRoomId == room.id);
        if (matches.isNotEmpty) {
          roomAudit = matches.first;
        }
      }

      String status = 'Pending';
      if (roomAudit == null) {
        status = 'Pending';
        pending++;
      } else if (roomAudit.hasDefect) {
        status = 'Defects Found';
        defects++;
      } else {
        status = 'Compliant';
        compliant++;
      }

      processed.add({
        'room': room,
        'status': status,
        'audit': roomAudit,
      });
    }

    setState(() {
      _processedRooms = processed;
      _totalRooms = _panelRooms.length;
      _compliantCount = compliant;
      _defectsCount = defects;
      _pendingCount = pending;
      _complianceRate = _totalRooms == 0 ? 0.0 : (compliant / _totalRooms) * 100.0;
    });
  }

  void _openRoomAuditForm(PanelRoomModel room, PanelRoomAuditItem? existingAudit) {
    setState(() {
      _selectedRoom = room;
      _activeAuditItem = existingAudit ??
          PanelRoomAuditItem(
            panelRoomId: room.id,
            panelRoomName: room.name,
          );
      _remarksController.text = _activeAuditItem?.remarks ?? '';
    });
  }

  void _updateParamStatus(String paramKey, String newStatus) {
    if (_activeAuditItem == null) return;
    PanelRoomAuditItem current = _activeAuditItem!;
    PanelRoomAuditItem updated;

    switch (paramKey) {
      case 'rubberMat':
        updated = current.copyWith(rubberMat: newStatus);
        break;
      case 'illumination':
        updated = current.copyWith(illumination: newStatus);
        break;
      case 'ventilation':
        updated = current.copyWith(ventilation: newStatus);
        break;
      case 'sealing':
        updated = current.copyWith(sealing: newStatus);
        break;
      case 'cleaning':
        updated = current.copyWith(cleaning: newStatus);
        break;
      case 'dangerBoard':
        updated = current.copyWith(dangerBoard: newStatus);
        break;
      case 'feederNaming':
        updated = current.copyWith(feederNaming: newStatus);
        break;
      case 'pprSld':
        updated = current.copyWith(pprSld: newStatus);
        break;
      case 'fireExtinguisher':
        updated = current.copyWith(fireExtinguisher: newStatus);
        break;
      case 'accessControl':
        updated = current.copyWith(accessControl: newStatus);
        break;
      case 'emergencyExit':
        updated = current.copyWith(emergencyExit: newStatus);
        break;
      case 'doorInterlock':
        updated = current.copyWith(doorInterlock: newStatus);
        break;
      case 'authorisedPeopleList':
        updated = current.copyWith(authorisedPeopleList: newStatus);
        break;
      case 'shockTreatmentChart':
        updated = current.copyWith(shockTreatmentChart: newStatus);
        break;
      default:
        updated = current;
    }

    setState(() {
      _activeAuditItem = updated;
    });
  }

  void _updateParamRemark(String paramKey, String text) {
    if (_activeAuditItem == null) return;
    final currentRemarks = Map<String, String>.from(_activeAuditItem!.paramRemarks);
    if (text.trim().isEmpty) {
      currentRemarks.remove(paramKey);
    } else {
      currentRemarks[paramKey] = text.trim();
    }
    setState(() {
      _activeAuditItem = _activeAuditItem!.copyWith(paramRemarks: currentRemarks);
    });
  }

  Future<void> _saveRoomAudit() async {
    if (_selectedRoom == null || _activeAuditItem == null) return;

    setState(() => _isSubmitting = true);
    try {
      final updatedItem = _activeAuditItem!.copyWith(
        remarks: _remarksController.text.trim(),
      );

      final reportId = 'pr_report_${_selectedUnitId}_${_selectedPlantId}_${DateTime.now().millisecondsSinceEpoch}';

      List<PanelRoomAuditItem> currentAudits = [];
      if (_reports.isNotEmpty) {
        currentAudits = List.from(_reports.first.roomAudits);
      }

      currentAudits.removeWhere((a) => a.panelRoomId == _selectedRoom!.id);
      currentAudits.add(updatedItem);

      final hasDefects = currentAudits.any((item) => item.hasDefect);
      final overallStatus = hasDefects ? 'Action Required' : 'Pass';

      final report = PanelRoomChecklistReportModel(
        id: reportId,
        unitId: _selectedUnitId ?? 'UNIT-1',
        plantId: _selectedPlantId ?? 'VISL',
        monthYear: _monthYear,
        inspectionDate: _inspectionDate,
        inspectorId: _currentUserId,
        inspectorName: _currentUserName,
        overallStatus: overallStatus,
        overallRemarks: 'Room ${_selectedRoom!.name} audited.',
        roomAudits: currentAudits,
        createdAt: DateTime.now(),
        createdBy: _currentUserName,
      );

      await _firestore.collection('panel_room_reports').doc(reportId).set(report.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Audit saved for ${_selectedRoom!.name}!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _fetchData();
      setState(() {
        _selectedRoom = null;
        _activeAuditItem = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving audit: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _navigateToDatabaseManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminDatabasePage(initialCollection: 'panel_rooms'),
      ),
    ).then((_) => _fetchData());
  }

  // --- File Saved Confirmation Dialog (Matching Lux Level Checklist Style) ---
  void _handleSavedFile(String path, String fileName) {
    if (!mounted) return;

    final bool isPublic = path.contains('/storage/emulated/0/Download/Assetpulse-pro');
    final String locationMessage = isPublic
        ? 'Saved to Internal Storage: Download/Assetpulse-pro/$fileName'
        : 'Saved to Application Storage: $fileName';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: Theme.of(dialogCtx).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: const Row(
            children: [
              Icon(Icons.file_download_done, color: Colors.greenAccent, size: 24),
              SizedBox(width: 10),
              Text('Report Exported', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(locationMessage, style: const TextStyle(fontSize: 12, color: Colors.white70)),
              const SizedBox(height: 12),
              const Text('Would you like to open or share this file?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Close', style: TextStyle(color: Colors.grey)),
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.share, size: 14),
                  label: const Text('Share', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    await Share.shareXFiles([XFile(path)], text: 'Panel Room Checklist Report: $fileName');
                  },
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.open_in_new, size: 14, color: Colors.white),
                  label: const Text('Open', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    final result = await OpenFile.open(path);
                    if (result.type != ResultType.done && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not open file: ${result.message}')),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // --- PDF Export (Full Details + Matching Header Style) ---
  Future<void> _exportPdfReport() async {
    if (_reports.isEmpty && _panelRooms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No panel room data available to export PDF!'), backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      final latest = _reports.isNotEmpty ? _reports.first : null;
      final pdf = pw.Document();

      final auditsToExport = latest?.roomAudits ??
          _panelRooms
              .map((r) => PanelRoomAuditItem(panelRoomId: r.id, panelRoomName: r.name))
              .toList();

      final monthStr = latest?.monthYear ?? _monthYear;
      final overallStatus = latest?.overallStatus ?? 'Pass';

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(16),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header (Matching Lux Level Checklist Style for VEDANTA IRON & STEEL LIMITED)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('VEDANTA IRON & STEEL LIMITED', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                        pw.Text('Panel Room Safety & Maintenance Checklist Report', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                        pw.SizedBox(height: 2),
                        pw.Text('Ref Standard: Electrical Substation & Switchgear Safety Inspection (IS 3043 / CEA)', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.blue100,
                            borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                          ),
                          child: pw.Text('Plant: $_selectedPlantId | Unit: $_selectedUnitId', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.blue900)),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text('Month: $monthStr | Date: ${_formatDateTime(_inspectionDate)}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),

                // Full Details Summary Row (Audit Done By, Inspection Date/Time, Status)
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Audit Done By: $_currentUserName', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Inspection Date & Time: ${_formatDateTime(_inspectionDate)}', style: const pw.TextStyle(fontSize: 8.5)),
                      pw.Text('Total Rooms: ${auditsToExport.length}', style: const pw.TextStyle(fontSize: 8.5)),
                      pw.Text('Overall Status: $overallStatus', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: overallStatus == 'Pass' ? PdfColors.green800 : PdfColors.red800)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),

                // Table of Audit Items
                pw.Expanded(
                  child: pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                    columnWidths: const {
                      0: pw.FixedColumnWidth(24), // Sr No
                      1: pw.FlexColumnWidth(3),   // Panel Room Name
                      2: pw.FixedColumnWidth(28), // Rubber Mat
                      3: pw.FixedColumnWidth(28), // Illumination
                      4: pw.FixedColumnWidth(28), // Ventilation
                      5: pw.FixedColumnWidth(28), // Sealing
                      6: pw.FixedColumnWidth(28), // Cleaning
                      7: pw.FixedColumnWidth(28), // Danger Board
                      8: pw.FixedColumnWidth(28), // Feeder Naming
                      9: pw.FixedColumnWidth(28), // PPR SLD
                      10: pw.FixedColumnWidth(28), // Fire Ext.
                      11: pw.FixedColumnWidth(28), // Access Ctrl
                      12: pw.FixedColumnWidth(28), // Emg Exit
                      13: pw.FixedColumnWidth(28), // Door Interlock
                      14: pw.FixedColumnWidth(28), // Auth List
                      15: pw.FixedColumnWidth(28), // Shock Chart
                      16: pw.FlexColumnWidth(2.5), // Remarks
                    },
                    children: [
                      // Header Row
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          _buildPdfTh('SR.'),
                          _buildPdfTh('PANEL ROOM'),
                          _buildPdfTh('MAT'),
                          _buildPdfTh('LUX'),
                          _buildPdfTh('VENT'),
                          _buildPdfTh('SEAL'),
                          _buildPdfTh('CLEN'),
                          _buildPdfTh('DNGR'),
                          _buildPdfTh('NAME'),
                          _buildPdfTh('SLD'),
                          _buildPdfTh('FIRE'),
                          _buildPdfTh('ACC'),
                          _buildPdfTh('EXIT'),
                          _buildPdfTh('INTR'),
                          _buildPdfTh('AUTH'),
                          _buildPdfTh('SHK'),
                          _buildPdfTh('DEFECTS / REMARKS'),
                        ],
                      ),
                      // Data Rows
                      ...auditsToExport.asMap().entries.map((entry) {
                        final idx = entry.key + 1;
                        final item = entry.value;
                        final String combinedRemarks = _getCombinedRemarks(item);

                        return pw.TableRow(
                          children: [
                            _buildPdfTd('$idx', alignCenter: true),
                            _buildPdfTd(item.panelRoomName, bold: true),
                            _buildPdfStatusTd(item.rubberMat),
                            _buildPdfStatusTd(item.illumination),
                            _buildPdfStatusTd(item.ventilation),
                            _buildPdfStatusTd(item.sealing),
                            _buildPdfStatusTd(item.cleaning),
                            _buildPdfStatusTd(item.dangerBoard),
                            _buildPdfStatusTd(item.feederNaming),
                            _buildPdfStatusTd(item.pprSld),
                            _buildPdfStatusTd(item.fireExtinguisher),
                            _buildPdfStatusTd(item.accessControl),
                            _buildPdfStatusTd(item.emergencyExit),
                            _buildPdfStatusTd(item.doorInterlock),
                            _buildPdfStatusTd(item.authorisedPeopleList),
                            _buildPdfStatusTd(item.shockTreatmentChart),
                            _buildPdfTd(combinedRemarks),
                          ],
                        );
                      }),
                    ],
                  ),
                ),

                pw.SizedBox(height: 10),
                // Signatures & Sign-off
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(width: 130, height: 1, color: PdfColors.black),
                        pw.SizedBox(height: 3),
                        pw.Text('Audit Done By: $_currentUserName', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(width: 130, height: 1, color: PdfColors.black),
                        pw.SizedBox(height: 3),
                        pw.Text('Approved By: Plant Electrical Head / HOD', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

      final bytes = await pdf.save();
      final fileName = 'Panel_Room_Checklist_${monthStr.replaceAll(' ', '_')}.pdf';
      final path = await downloadFile(bytes, fileName);

      if (path != null) {
        _handleSavedFile(path, fileName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _getCombinedRemarks(PanelRoomAuditItem item) {
    final List<String> parts = [];
    if (item.remarks.isNotEmpty) parts.add(item.remarks);
    item.paramRemarks.forEach((key, remark) {
      if (remark.isNotEmpty) {
        parts.add('$key: $remark');
      }
    });
    return parts.join('; ');
  }

  pw.Widget _buildPdfTh(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 5.5, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
      ),
    );
  }

  pw.Widget _buildPdfTd(String text, {bool alignCenter = false, bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(2),
      child: pw.Text(
        text,
        textAlign: alignCenter ? pw.TextAlign.center : pw.TextAlign.left,
        style: pw.TextStyle(fontSize: 5.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
      ),
    );
  }

  pw.Widget _buildPdfStatusTd(String status) {
    PdfColor bg = PdfColors.grey100;
    PdfColor fg = PdfColors.black;
    String symbol = '-';

    if (status == 'OK') {
      bg = PdfColors.green100;
      fg = PdfColors.green900;
      symbol = 'OK';
    } else if (status == 'Not OK') {
      bg = PdfColors.red100;
      fg = PdfColors.red900;
      symbol = 'NOK';
    }

    return pw.Container(
      color: bg,
      padding: const pw.EdgeInsets.all(2),
      child: pw.Text(
        symbol,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 5.5, fontWeight: pw.FontWeight.bold, color: fg),
      ),
    );
  }

  // --- Excel Export ---
  Future<void> _exportExcelReport() async {
    try {
      final latest = _reports.isNotEmpty ? _reports.first : null;
      final auditsToExport = latest?.roomAudits ??
          _panelRooms
              .map((r) => PanelRoomAuditItem(panelRoomId: r.id, panelRoomName: r.name))
              .toList();

      final List<Map<String, dynamic>> excelData = [];
      for (int i = 0; i < auditsToExport.length; i++) {
        final item = auditsToExport[i];
        excelData.add({
          'SR. NO': i + 1,
          'PANEL ROOM': item.panelRoomName,
          'RUBBER MAT': item.rubberMat,
          'ILLUMINATION': item.illumination,
          'VENTILATION': item.ventilation,
          'SEALING': item.sealing,
          'CLEANING': item.cleaning,
          'DANGER BOARD': item.dangerBoard,
          'FEEDER NAMING': item.feederNaming,
          'PPR+ SLD': item.pprSld,
          'FIRE EXTINGUISHER': item.fireExtinguisher,
          'ACCESS CONTROL': item.accessControl,
          'EMERGENCY EXIT': item.emergencyExit,
          'DOOR INTERLOCK': item.doorInterlock,
          'LIST OF AUTHORISED PEOPLE': item.authorisedPeopleList,
          'SHOCK TREATMENT CHART': item.shockTreatmentChart,
          'DEFECT OBSERVATIONS': _getCombinedRemarks(item),
          'ROOM STATUS': item.hasDefect ? 'Not OK' : 'OK',
          'AUDIT DONE BY': _currentUserName,
          'INSPECTION DATE': _formatDateTime(_inspectionDate),
        });
      }

      final bytes = ExcelService().generateExcel(excelData, 'Panel Room Checklist');
      if (bytes != null) {
        final monthStr = latest?.monthYear ?? _monthYear;
        final fileName = 'Panel_Room_Checklist_${monthStr.replaceAll(' ', '_')}.xlsx';
        final path = await downloadFile(bytes, fileName);
        if (path != null) {
          _handleSavedFile(path, fileName);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting Excel: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        appBar: CustomAppBar(title: 'Panel Room Checklist'),
        body: Center(child: PulseLoading()),
      );
    }

    return PopScope(
      canPop: _selectedRoom == null && !_showHelp,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() {
          if (_selectedRoom != null) {
            _selectedRoom = null;
          } else if (_showHelp) {
            _showHelp = false;
          }
        });
      },
      child: Scaffold(
        appBar: const CustomAppBar(title: 'Panel Room Checklist'),
        body: _selectedRoom != null
            ? _buildRecordingFormView()
            : _showHelp
                ? _buildHelpView()
                : _buildRoomListView(),
      ),
    );
  }

  // --- Main View: Room List & Overview ---
  Widget _buildRoomListView() {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _processedRooms.where((item) {
      final room = item['room'] as PanelRoomModel;
      return room.name.toLowerCase().contains(query) || room.id.toLowerCase().contains(query);
    }).toList();

    return ResponsiveContentWrapper(
      maxWidth: 1320,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Compact Scope Selectors (GlassContainer with Select Plant & Select Unit dropdowns)
            GlassContainer(
              borderRadius: 16,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedPlantId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Select Plant', border: InputBorder.none),
                        items: _plants.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: _isPlantLocked
                            ? null
                            : (val) async {
                                if (val != null) {
                                  setState(() {
                                    _selectedPlantId = val;
                                    _units = _hierarchyService.getUnitsForPlant(val);
                                    _selectedUnitId = _units.isNotEmpty ? _units.first : 'UNIT-1';
                                    _isLoading = true;
                                  });
                                  await _fetchData();
                                  if (mounted) setState(() => _isLoading = false);
                                }
                              },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedUnitId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Select Unit', border: InputBorder.none),
                        items: _units.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: _isUnitLocked
                            ? null
                            : (val) async {
                                if (val != null) {
                                  setState(() {
                                    _selectedUnitId = val;
                                    _isLoading = true;
                                  });
                                  await _fetchData();
                                  if (mounted) setState(() => _isLoading = false);
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Metrics Dashboard Card
            GlassContainer(
              borderRadius: 20,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Panel Room Safety Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _complianceRate >= 80.0 ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_complianceRate.toStringAsFixed(1)}%',
                            style: TextStyle(fontWeight: FontWeight.bold, color: _complianceRate >= 80.0 ? Colors.greenAccent : Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('Total Rooms', '$_totalRooms', Colors.white),
                        _buildStatItem('Compliant', '$_compliantCount', Colors.greenAccent),
                        _buildStatItem('Defects Found', '$_defectsCount', Colors.redAccent),
                        _buildStatItem('Pending', '$_pendingCount', Colors.orangeAccent),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. Search Field & Help/Settings Buttons
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search room name or ID...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                  icon: const Icon(Icons.help_outline, color: Colors.white),
                  tooltip: 'Safety Inspection Guide',
                  onPressed: () => setState(() => _showHelp = true),
                ),
                if (_isAdmin) ...[
                  const SizedBox(width: 4),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                    icon: const Icon(Icons.settings, color: Colors.white),
                    tooltip: 'Manage Panel Rooms in Database',
                    onPressed: _navigateToDatabaseManagement,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // 4. Header Row with Title & Excel / PDF Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Panel Rooms (${filtered.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _exportExcelReport,
                      icon: const Icon(Icons.table_chart_outlined, size: 16, color: Colors.greenAccent),
                      label: const Text('Excel', style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: _exportPdfReport,
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 16, color: Colors.redAccent),
                      label: const Text('PDF Report', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 5. Room Cards List
            filtered.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.meeting_room_outlined, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          _panelRooms.isEmpty
                              ? 'No Panel Rooms registered in Database for Unit "$_selectedUnitId".'
                              : 'No Panel Rooms match search query.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        if (_panelRooms.isEmpty && _isAdmin) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _navigateToDatabaseManagement,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Panel Rooms in Database Management'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, index) {
                      final item = filtered[index];
                      final room = item['room'] as PanelRoomModel;
                      final status = item['status'] as String;
                      final audit = item['audit'] as PanelRoomAuditItem?;
                      return _buildRoomCard(index + 1, room, status, audit);
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildRoomCard(int index, PanelRoomModel room, String status, PanelRoomAuditItem? audit) {
    Color statusColor = Colors.orangeAccent;
    IconData statusIcon = Icons.pending_actions;

    if (status == 'Compliant') {
      statusColor = Colors.greenAccent;
      statusIcon = Icons.check_circle;
    } else if (status == 'Defects Found') {
      statusColor = Colors.redAccent;
      statusIcon = Icons.warning;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.15),
          child: Icon(statusIcon, color: statusColor, size: 22),
        ),
        title: Text(room.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(room.description.isEmpty ? 'Substation Panel Room' : room.description, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
                if (audit != null && (audit.remarks.isNotEmpty || audit.paramRemarks.isNotEmpty)) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '• ${_getCombinedRemarks(audit)}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Colors.white70, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () => _openRoomAuditForm(room, audit),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Audit Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  // --- Audit Recording Sub-Page View ---
  Widget _buildRecordingFormView() {
    if (_selectedRoom == null || _activeAuditItem == null) return const SizedBox.shrink();

    return ResponsiveContentWrapper(
      maxWidth: 900,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar with Back Arrow
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => setState(() => _selectedRoom = null),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedRoom!.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        'Unit: $_selectedUnitId | Plant: $_selectedPlantId',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Locked Metadata Card (Inspector Name & Date locked to logged-in user & current time)
            GlassContainer(
              borderRadius: 16,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Audit Info (Locked to Active Session)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.tealAccent),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            key: ValueKey('inspector_$_currentUserName'),
                            controller: TextEditingController(
                              text: _currentUserName.isNotEmpty
                                  ? _currentUserName
                                  : (AuthService().currentUser?.displayName ??
                                      AuthService().currentUser?.email ??
                                      'Inspector'),
                            ),
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Audit Done By (Inspector)',
                              isDense: true,
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person, size: 18, color: Colors.tealAccent),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            initialValue: _formatDateTime(_inspectionDate),
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Inspection Date & Time',
                              isDense: true,
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.access_time_filled, size: 18, color: Colors.tealAccent),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: _monthYear,
                      decoration: const InputDecoration(
                        labelText: 'Audit Month / Year',
                        isDense: true,
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_month, size: 18),
                      ),
                      onChanged: (val) => _monthYear = val,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 14 Mandatory Checkpoints Cards
            const Text(
              '14 Safety Checkpoints Verification:',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.tealAccent),
            ),
            const SizedBox(height: 12),

            ..._checklistParameters.map((param) {
              final pKey = param['key']!;
              final pLabel = param['label']!;
              final currentStatus = _getParamValue(_activeAuditItem!, pKey);
              final currentRemark = _activeAuditItem!.paramRemarks[pKey] ?? '';

              return _buildParameterCard(pKey, pLabel, currentStatus, currentRemark);
            }),

            const SizedBox(height: 16),

            // Room Observations / Defect Reason
            GlassContainer(
              borderRadius: 16,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Overall Room Observations & Summary Notes',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _remarksController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'e.g., Overall room safety good, 2 minor defects noted for rectification...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _saveRoomAudit,
              icon: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle, size: 22),
              label: Text(_isSubmitting ? 'Saving Audit...' : 'Save & Complete Room Audit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _getParamValue(PanelRoomAuditItem item, String key) {
    switch (key) {
      case 'rubberMat':
        return item.rubberMat;
      case 'illumination':
        return item.illumination;
      case 'ventilation':
        return item.ventilation;
      case 'sealing':
        return item.sealing;
      case 'cleaning':
        return item.cleaning;
      case 'dangerBoard':
        return item.dangerBoard;
      case 'feederNaming':
        return item.feederNaming;
      case 'pprSld':
        return item.pprSld;
      case 'fireExtinguisher':
        return item.fireExtinguisher;
      case 'accessControl':
        return item.accessControl;
      case 'emergencyExit':
        return item.emergencyExit;
      case 'doorInterlock':
        return item.doorInterlock;
      case 'authorisedPeopleList':
        return item.authorisedPeopleList;
      case 'shockTreatmentChart':
        return item.shockTreatmentChart;
      default:
        return 'OK';
    }
  }

  Widget _buildParameterCard(String paramKey, String label, String currentStatus, String currentRemark) {
    final bool isNotOk = currentStatus == 'Not OK';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isNotOk
              ? Colors.red.withValues(alpha: 0.6)
              : (currentStatus == 'OK' ? Colors.green.withValues(alpha: 0.3) : Colors.white10),
          width: isNotOk ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              _buildChoiceChip(paramKey, 'OK', currentStatus == 'OK', Colors.green),
              const SizedBox(width: 6),
              _buildChoiceChip(paramKey, 'Not OK', currentStatus == 'Not OK', Colors.red),
              const SizedBox(width: 6),
              _buildChoiceChip(paramKey, 'N/A', currentStatus == 'N/A', Colors.grey),
            ],
          ),
          // Individual Defect Remark Input (When Not OK is selected)
          if (isNotOk) ...[
            const SizedBox(height: 10),
            TextFormField(
              initialValue: currentRemark,
              decoration: InputDecoration(
                labelText: 'Specific defect observation / reason for Not OK ($label)',
                hintText: 'e.g., Mat torn/missing, Lamp fixture broken, Door latch jammed...',
                isDense: true,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.redAccent),
              ),
              onChanged: (val) => _updateParamRemark(paramKey, val),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChoiceChip(String paramKey, String status, bool isSelected, Color activeColor) {
    return InkWell(
      onTap: () => _updateParamStatus(paramKey, status),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : activeColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? activeColor : activeColor.withValues(alpha: 0.3)),
        ),
        child: Text(
          status,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : activeColor,
          ),
        ),
      ),
    );
  }

  // --- Help View: IS/CEA Safety Standard Norms Guide ---
  Widget _buildHelpView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => setState(() => _showHelp = false),
              ),
              const SizedBox(width: 8),
              const Text(
                'Panel Room Safety Inspection Guide',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('14 Safety & Compliance Checkpoints:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.tealAccent)),
                SizedBox(height: 12),
                Text('1. Rubber Mat: Insulating mats per IS 15652 / IEC 61111 placed in front of HT/LT panels.', style: TextStyle(fontSize: 12, height: 1.4)),
                SizedBox(height: 8),
                Text('2. Illumination: Adequate lighting level (min 150-200 Lux) per IS 3646.', style: TextStyle(fontSize: 12, height: 1.4)),
                SizedBox(height: 8),
                Text('3. Ventilation: Air circulation / exhaust fans operational to prevent overheating.', style: TextStyle(fontSize: 12, height: 1.4)),
                SizedBox(height: 8),
                Text('4. Sealing: Cable trench entries sealed to prevent rodent and water ingress.', style: TextStyle(fontSize: 12, height: 1.4)),
                SizedBox(height: 8),
                Text('5. Cleaning: Housekeeping clean, no dust, junk, or flammable items stored.', style: TextStyle(fontSize: 12, height: 1.4)),
                SizedBox(height: 8),
                Text('6. Danger Board: Statutory Caution/Danger boards posted at room entry and HT panels.', style: TextStyle(fontSize: 12, height: 1.4)),
                SizedBox(height: 8),
                Text('7. Feeder Naming: All panel feeders clearly labeled with permanent nameplates.', style: TextStyle(fontSize: 12, height: 1.4)),
                SizedBox(height: 8),
                Text('8. PPR+ SLD: Single Line Diagram (SLD) displayed on wall.', style: TextStyle(fontSize: 12, height: 1.4)),
                SizedBox(height: 8),
                Text('9. Fire Extinguisher: CO2 / DCP fire extinguishers within valid inspection date.', style: TextStyle(fontSize: 12, height: 1.4)),
                SizedBox(height: 8),
                Text('10. Access Control: Door lock key management restricted to authorized personnel.', style: TextStyle(fontSize: 12, height: 1.4)),
                SizedBox(height: 8),
                Text('11. Emergency Exit: Unobstructed exit route and illuminated escape sign.', style: TextStyle(fontSize: 12, height: 1.4)),
                SizedBox(height: 8),
                Text('12. Door Interlock: Panel rear door and switchgear interlocks functioning.', style: TextStyle(fontSize: 12, height: 1.4)),
                SizedBox(height: 8),
                Text('13. List of Authorised People: Updated list of authorized electrical personnel displayed.', style: TextStyle(fontSize: 12, height: 1.4)),
                SizedBox(height: 8),
                Text('14. Shock Treatment Chart: Electric shock treatment & CPR chart posted in local language.', style: TextStyle(fontSize: 12, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
