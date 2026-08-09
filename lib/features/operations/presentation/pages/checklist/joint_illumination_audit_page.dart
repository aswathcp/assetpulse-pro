// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:asset_pulse_pro/core/constants/app_colors.dart';
import 'package:asset_pulse_pro/core/widgets/glass_container.dart';
import 'package:asset_pulse_pro/core/widgets/pulse_loading.dart';
import 'package:asset_pulse_pro/features/home/presentation/widgets/custom_app_bar.dart';
import 'package:asset_pulse_pro/core/services/auth_service.dart';
import 'package:asset_pulse_pro/core/services/firestore_service.dart';
import 'package:asset_pulse_pro/core/services/hierarchy_service.dart';
import 'package:asset_pulse_pro/core/constants/app_roles.dart';
import 'package:uuid/uuid.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:asset_pulse_pro/core/services/excel_service.dart';
import 'package:asset_pulse_pro/core/utils/file_download_helper.dart';
import 'package:asset_pulse_pro/features/operations/data/models/joint_illumination_audit_model.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'lux_level_checklist_page.dart';

class JointIlluminationAuditPage extends StatefulWidget {
  const JointIlluminationAuditPage({super.key});

  @override
  State<JointIlluminationAuditPage> createState() => _JointIlluminationAuditPageState();
}

class _JointIlluminationAuditPageState extends State<JointIlluminationAuditPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Scope State
  String? _selectedBusinessId;
  String? _selectedPlantId;
  String? _selectedUnitId;
  List<String> _plants = [];
  List<String> _units = [];
  bool _isPlantLocked = false;
  bool _isUnitLocked = false;
  bool _isLoading = true;
  String? _userPlantId;
  String? _userUnitId;
  bool _isAdmin = false;
  String _currentUserName = 'Operator';
  String _userRole = 'Electrical Inspector';

  // Data & Filter State
  List<Map<String, dynamic>> _locations = [];
  List<JointIlluminationAuditModel> _audits = [];
  List<Map<String, dynamic>> _processedLocations = [];
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'All'; // 'All', 'Open', 'Closed'

  // Navigation State
  Map<String, dynamic>? _selectedLocation;
  Map<String, dynamic>? _historyLocation;

  // Recording Form State
  final _formKey = GlobalKey<FormState>();
  String _auditQuarter = 'Q1 2026';
  final TextEditingController _jointAuditorNameCtl = TextEditingController();
  final TextEditingController _jointDeptCtl = TextEditingController(text: 'Production');
  final TextEditingController _faultyCountCtl = TextEditingController(text: '0');
  final TextEditingController _replacementDetailsCtl = TextEditingController();
  final TextEditingController _additionalLightDetailsCtl = TextEditingController();
  final TextEditingController _remarksCtl = TextEditingController();

  bool _hasFaultyLights = false;
  bool _needsReplacement = false;
  bool _needsAdditionalLight = false;
  bool _isSubmitting = false;

  final List<String> _departments = [
    'Production',
    'Safety & HSE',
    'Security & Plant Access',
    'Mechanical Maintenance',
    'Civil & Infrastructure',
    'Instrumentation',
    'Operations',
    'Central Stores',
    'Quality Control',
  ];

  final List<String> _quarters = [
    'Q1 2026 (Jan-Mar)',
    'Q2 2026 (Apr-Jun)',
    'Q3 2026 (Jul-Sep)',
    'Q4 2026 (Oct-Dec)',
  ];

  // Analytics Metrics
  int _totalAudits = 0;
  int _openAuditsCount = 0;
  int _closedAuditsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadScopeAndData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _jointAuditorNameCtl.dispose();
    _jointDeptCtl.dispose();
    _faultyCountCtl.dispose();
    _replacementDetailsCtl.dispose();
    _additionalLightDetailsCtl.dispose();
    _remarksCtl.dispose();
    super.dispose();
  }

  Future<void> _loadScopeAndData() async {
    setState(() => _isLoading = true);
    final user = AuthService().currentUser;
    if (user != null) {
      final profile = await _firestoreService.getUserProfile(user.uid);
      if (profile != null) {
        final role = profile['role'] ?? AppRoles.guest;
        final desig = profile['designation'] ?? profile['title'] ?? role;
        _userRole = desig.toString();
        _userPlantId = profile['plantId'] as String?;
        _userUnitId = profile['unitId'] as String?;
        _isAdmin = profile['isAdmin'] == true || role == AppRoles.developer;
        _currentUserName = profile['displayName'] ?? profile['name'] ?? 'Operator';
        final userBusinessId = profile['businessId'] as String? ?? 'VISL';

        await HierarchyService().init(businessId: userBusinessId);
        _selectedBusinessId = HierarchyService().currentBusinessId;
        _plants = HierarchyService().getPlants();

        final plantNames = HierarchyService().getPlantNames();
        if (!_isAdmin && _userPlantId != null && plantNames.containsKey(_userPlantId)) {
          _selectedPlantId = _userPlantId;
          _isPlantLocked = true;
        }
        _selectedPlantId ??= _plants.isNotEmpty ? _plants.first : null;

        _updateUnitList();

        if (!_isAdmin && _userUnitId != null && _units.contains(_userUnitId)) {
          _selectedUnitId = _userUnitId;
          _isUnitLocked = true;
        }
      }
    }

    await _loadData();
    if (mounted) setState(() => _isLoading = false);
  }

  void _updateUnitList() {
    if (_selectedPlantId == null) {
      _units = [];
      _selectedUnitId = null;
    } else {
      _units = HierarchyService().getUnitsForPlant(_selectedPlantId!);
      if (_units.isEmpty) _units = ['PID1', 'MCD'];
      if (!_units.contains(_selectedUnitId)) {
        _selectedUnitId = _units.isNotEmpty ? _units.first : null;
      }
    }
  }

  Future<void> _loadData() async {
    if (_selectedPlantId == null || _selectedUnitId == null) return;

    try {
      final locSnapshot = await _firestore
          .collection('lux_locations')
          .where('plantId', isEqualTo: _selectedPlantId)
          .where('unitId', isEqualTo: _selectedUnitId)
          .get();

      final locs = locSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      locs.sort((a, b) => compareNatural(a['id'].toString(), b['id'].toString()));

      final auditSnapshot = await _firestore
          .collection('joint_illumination_audits')
          .where('plantId', isEqualTo: _selectedPlantId)
          .where('unitId', isEqualTo: _selectedUnitId)
          .get();

      final auditList = auditSnapshot.docs
          .map((doc) => JointIlluminationAuditModel.fromMap(doc.data(), doc.id))
          .toList();

      _locations = locs;
      _audits = auditList;

      _processData();
    } catch (e) {
      debugPrint('Error loading Joint Illumination Audit data: $e');
    }
  }

  void _processData() {
    final List<Map<String, dynamic>> processed = [];
    int openCount = 0;
    int closedCount = 0;

    for (final loc in _locations) {
      final locId = loc['id'];
      final locAudits = _audits.where((a) => a.locationId == locId).toList();
      locAudits.sort((a, b) => b.auditDate.compareTo(a.auditDate));

      final latestAudit = locAudits.isNotEmpty ? locAudits.first : null;
      String status = latestAudit != null ? latestAudit.status : 'No Audit';

      if (latestAudit != null) {
        if (latestAudit.status == 'Open') {
          openCount++;
        } else {
          closedCount++;
        }
      }

      processed.add({
        ...loc,
        'jointStatus': status,
        'latestAudit': latestAudit,
        'history': locAudits,
      });
    }

    setState(() {
      _processedLocations = processed;
      _totalAudits = _audits.length;
      _openAuditsCount = openCount;
      _closedAuditsCount = closedCount;

      if (_historyLocation != null) {
        _historyLocation = _processedLocations.firstWhere(
          (element) => element['id'] == _historyLocation!['id'],
          orElse: () => _historyLocation!,
        );
      }
    });
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  String _formatDateTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    final min = date.minute.toString().padLeft(2, '0');
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} $hour:$min $ampm";
  }

  void _startNewAudit(Map<String, dynamic> loc) {
    setState(() {
      _selectedLocation = loc;
      _auditQuarter = 'Q1 2026 (Jan-Mar)';
      _jointAuditorNameCtl.clear();
      _jointDeptCtl.text = 'Production';
      _faultyCountCtl.text = '0';
      _replacementDetailsCtl.clear();
      _additionalLightDetailsCtl.clear();
      _remarksCtl.clear();
      _hasFaultyLights = false;
      _needsReplacement = false;
      _needsAdditionalLight = false;
    });
  }

  Future<void> _submitJointAudit() async {
    if (!_formKey.currentState!.validate() || _selectedLocation == null) return;

    if (_hasFaultyLights && (int.tryParse(_faultyCountCtl.text.trim()) ?? 0) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the count of faulty/burnt lights.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    if (_needsReplacement && _replacementDetailsCtl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the fittings requiring replacement.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    if (_needsAdditionalLight && _additionalLightDetailsCtl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please specify location details for additional lighting.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final docId = const Uuid().v4();
      final bool requiresRectification = _hasFaultyLights || _needsReplacement || _needsAdditionalLight;
      final String initialStatus = requiresRectification ? 'Open' : 'Closed';

      final category = _selectedLocation!['category'] ?? getCategoryForType(_selectedLocation!['type'] ?? '');

      final audit = JointIlluminationAuditModel(
        id: docId,
        plantId: _selectedPlantId!,
        unitId: _selectedUnitId!,
        businessId: _selectedBusinessId ?? 'VISL',
        locationId: _selectedLocation!['id'],
        locationName: _selectedLocation!['name'],
        category: category,
        locationType: _selectedLocation!['type'],
        auditQuarter: _auditQuarter,
        auditDate: DateTime.now(),
        auditedByTech: _currentUserName,
        jointDeptName: _jointDeptCtl.text.trim(),
        jointAuditorName: _jointAuditorNameCtl.text.trim(),
        hasFaultyLights: _hasFaultyLights,
        faultyCount: int.tryParse(_faultyCountCtl.text.trim()) ?? 0,
        needsReplacement: _needsReplacement,
        replacementDetails: _replacementDetailsCtl.text.trim(),
        needsAdditionalLight: _needsAdditionalLight,
        additionalLightDetails: _additionalLightDetailsCtl.text.trim(),
        status: initialStatus,
        remarks: _remarksCtl.text.trim(),
      );

      await _firestore.collection('joint_illumination_audits').doc(docId).set(audit.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(initialStatus == 'Open' ? 'Joint Audit Logged! Status: OPEN (Needs Rectification)' : 'Joint Audit Logged! Status: CLOSED (Satisfactory)'),
            backgroundColor: initialStatus == 'Open' ? Colors.orangeAccent : Colors.green,
          ),
        );
        setState(() => _selectedLocation = null);
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting joint audit: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // Rectification & Closure Dialog Modal
  void _showRectificationModal(JointIlluminationAuditModel audit) {
    final actionCtl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Row(
            children: [
              const Icon(Icons.published_with_changes, color: Colors.greenAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Attend & Close Audit: ${audit.locationName}', style: const TextStyle(fontSize: 14)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Logged Audit Defects:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.redAccent)),
                        if (audit.hasFaultyLights) Text('• Faulty/Burnt Lights: ${audit.faultyCount} nos', style: const TextStyle(fontSize: 10, color: Colors.white70)),
                        if (audit.needsReplacement) Text('• Replacement: ${audit.replacementDetails}', style: const TextStyle(fontSize: 10, color: Colors.white70)),
                        if (audit.needsAdditionalLight) Text('• Additional Light: ${audit.additionalLightDetails}', style: const TextStyle(fontSize: 10, color: Colors.white70)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: actionCtl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Rectification Action Taken *',
                      hintText: 'e.g. Replaced 2 burnt 150W LED Highbays & added 1x 100W fitting near stairwell',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required to close audit' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              icon: const Icon(Icons.check_circle, color: Colors.white, size: 16),
              label: const Text('Close Audit (Mark Rectified)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  await _firestore.collection('joint_illumination_audits').doc(audit.id).update({
                    'status': 'Closed',
                    'rectifiedBy': _currentUserName,
                    'rectificationDate': DateTime.now().toIso8601String(),
                    'rectificationAction': actionCtl.text.trim(),
                  });
                  if (context.mounted) Navigator.pop(context);
                  await _loadData();
                  setState(() {});
                }
              },
            ),
          ],
        );
      },
    );
  }

  // --- Export Excel Joint Audit Report ---
  Future<void> _exportExcelReport() async {
    try {
      final List<Map<String, dynamic>> excelData = _processedLocations.map((loc) {
        final rawId = HierarchyService.stripPrefix(loc['id'], _selectedPlantId!, _selectedUnitId!);
        final JointIlluminationAuditModel? a = loc['latestAudit'];

        return {
          'Location ID': rawId,
          'Area Name': loc['name'] ?? '',
          'Category': loc['category'] ?? getCategoryForType(loc['type'] ?? ''),
          'Sub-Type': loc['type'] ?? '',
          'Audit Quarter': a?.auditQuarter ?? 'N/A',
          'Audit Date': a != null ? _formatDate(a.auditDate) : 'N/A',
          'Lead Electrical Tech': a?.auditedByTech ?? 'N/A',
          'Co-Auditing Dept': a?.jointDeptName ?? 'N/A',
          'Co-Auditor Name': a?.jointAuditorName ?? 'N/A',
          'Faulty Lights Found?': a != null ? (a.hasFaultyLights ? 'YES (${a.faultyCount} nos)' : 'NO') : 'N/A',
          'Replacement Required?': a != null ? (a.needsReplacement ? 'YES' : 'NO') : 'N/A',
          'Replacement Details': a?.replacementDetails ?? 'N/A',
          'Additional Light Needed?': a != null ? (a.needsAdditionalLight ? 'YES' : 'NO') : 'N/A',
          'Additional Light Details': a?.additionalLightDetails ?? 'N/A',
          'Audit Status': a?.status ?? 'No Audit',
          'Rectified By': a?.rectifiedBy ?? 'N/A',
          'Rectification Date': (a != null && a.rectificationDate != null) ? _formatDate(a.rectificationDate!) : 'N/A',
          'Rectification Action Taken': a?.rectificationAction ?? 'N/A',
          'Remarks': a?.remarks ?? '',
        };
      }).toList();

      final fileName = 'Joint_Illumination_Audit_${_selectedPlantId}_${_selectedUnitId}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final bytes = ExcelService().generateExcel(excelData, 'Joint Illumination Audit');

      if (bytes != null) {
        final path = await downloadFile(bytes, fileName);
        if (path != null) {
          _handleSavedFile(path, fileName);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating Excel report: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // --- Export PDF Joint Illumination Audit Report ---
  Future<void> _exportPDFReport() async {
    final pdf = pw.Document();
    final String reportGenTime = _formatDateTime(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(16),
        build: (pw.Context context) {
          return [
            // Clean Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('VEDANTA IRON & STEEL LIMITED', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.Text('Quarterly Joint Illumination Inspection Audit', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                    pw.SizedBox(height: 2),
                    pw.Text('Ref Standard: IS 3646 (Part 1) : 2025 Internal Audit', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
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
                    pw.Text('Report Generated: $reportGenTime', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 8),

            // Summary Stats Box
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
                color: PdfColors.grey50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
              ),
              padding: const pw.EdgeInsets.all(6),
              child: pw.Row(
                children: [
                  pw.Expanded(child: _pdfStatItem('Total Locations', '${_processedLocations.length}')),
                  pw.Expanded(child: _pdfStatItem('Open (Needs Action)', '$_openAuditsCount', color: PdfColors.red800)),
                  pw.Expanded(child: _pdfStatItem('Closed (Rectified)', '$_closedAuditsCount', color: PdfColors.green800)),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // Optimized Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.8), // ID
                1: const pw.FlexColumnWidth(1.6), // Area Name
                2: const pw.FlexColumnWidth(1.2), // Quarter & Date
                3: const pw.FlexColumnWidth(1.6), // Joint Auditors (Tech + Co-dept)
                4: const pw.FlexColumnWidth(1.2), // Faulty Lights Count
                5: const pw.FlexColumnWidth(1.6), // Replacement / Additional Needs
                6: const pw.FlexColumnWidth(1.0), // Status
                7: const pw.FlexColumnWidth(1.8), // Rectification Action
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                  children: [
                    _pdfHeaderCell('ID'),
                    _pdfHeaderCell('Area Name'),
                    _pdfHeaderCell('Quarter / Date'),
                    _pdfHeaderCell('Joint Auditors'),
                    _pdfHeaderCell('Faulty Lights'),
                    _pdfHeaderCell('Replacement / Add Light'),
                    _pdfHeaderCell('Status'),
                    _pdfHeaderCell('Rectification Action'),
                  ],
                ),
                ..._processedLocations.map((itemLoc) {
                  final rawId = HierarchyService.stripPrefix(itemLoc['id'], _selectedPlantId!, _selectedUnitId!);
                  final JointIlluminationAuditModel? a = itemLoc['latestAudit'];
                  final bool isOpen = a?.status == 'Open';

                  final String auditorsStr = a != null
                      ? "Tech: ${a.auditedByTech}\n${a.jointDeptName}: ${a.jointAuditorName}"
                      : "-";

                  final String defectDetailsStr = a != null
                      ? "Repl: ${a.needsReplacement ? a.replacementDetails : 'No'}\nAdd: ${a.needsAdditionalLight ? a.additionalLightDetails : 'No'}"
                      : "-";

                  final String rectStr = a?.rectificationAction != null
                      ? "${a!.rectificationAction}\nBy: ${a.rectifiedBy} (${a.rectificationDate != null ? _formatDate(a.rectificationDate!) : ''})"
                      : "-";

                  return pw.TableRow(
                    children: [
                      _pdfDataCell(rawId, isBold: true),
                      _pdfDataCell('${itemLoc['name']}\n(${itemLoc['type']})'),
                      _pdfDataCell(a != null ? '${a.auditQuarter}\n${_formatDate(a.auditDate)}' : '-'),
                      _pdfDataCell(auditorsStr),
                      _pdfDataCell(a != null ? (a.hasFaultyLights ? '${a.faultyCount} Faulty' : '0 Faulty') : '-'),
                      _pdfDataCell(defectDetailsStr),
                      _pdfDataCell(a?.status ?? 'No Audit', color: isOpen ? PdfColors.red800 : PdfColors.green800, isBold: true),
                      _pdfDataCell(rectStr),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 12),

            // Footer & Signatures
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Joint Audit Purpose:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                    pw.Text('- Quarterly joint physical verification of luminaires with user department.', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                    pw.Text('- Audits with Open status must be rectified & signed off by maintenance.', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Electrical Auditor / Engineer', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 10),
                    pw.Text('Co-Auditing Department Head', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    final fileName = 'Joint_Illumination_Audit_${_selectedPlantId}_${_selectedUnitId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final bytes = await pdf.save();
    final path = await downloadFile(bytes, fileName);

    if (path != null) {
      _handleSavedFile(path, fileName);
    }
  }

  pw.Widget _pdfStatItem(String label, String value, {PdfColor color = PdfColors.black}) {
    return pw.Column(
      children: [
        pw.Text(value, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: color)),
        pw.SizedBox(height: 1),
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
      ],
    );
  }

  pw.Widget _pdfHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 5),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
    );
  }

  pw.Widget _pdfDataCell(String text, {bool isBold = false, PdfColor color = PdfColors.black}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 7.5, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
    );
  }

  void _handleSavedFile(String path, String fileName) {
    if (!mounted) return;

    final bool isPublic = path.contains('/storage/emulated/0/Download/Assetpulse-pro');
    final String locationMessage = isPublic
        ? 'Saved to Internal Storage: Download/Assetpulse-pro/$fileName'
        : 'Saved to Application Storage: $fileName';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
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
                  onPressed: () => Navigator.pop(context),
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
                    Navigator.pop(context);
                    await Share.shareXFiles([XFile(path)], text: 'Joint Illumination Audit: $fileName');
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
                    Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        appBar: CustomAppBar(title: 'Joint Illumination Audit'),
        body: Center(child: PulseLoading()),
      );
    }

    return PopScope(
      canPop: _selectedLocation == null && _historyLocation == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() {
          if (_selectedLocation != null) {
            _selectedLocation = null;
          } else if (_historyLocation != null) {
            _historyLocation = null;
          }
        });
      },
      child: Scaffold(
        appBar: const CustomAppBar(title: 'Joint Illumination Audit'),
        body: _selectedLocation != null
            ? _buildNewAuditFormView()
            : _historyLocation != null
                ? _buildHistoryView()
                : _buildLocationListView(),
      ),
    );
  }

  Widget _buildLocationListView() {
    final query = _searchController.text.trim().toLowerCase();
    final filteredLocations = _processedLocations.where((loc) {
      final name = (loc['name'] ?? '').toString().toLowerCase();
      final type = (loc['type'] ?? '').toString().toLowerCase();
      final id = HierarchyService.stripPrefix(loc['id'], _selectedPlantId!, _selectedUnitId!).toLowerCase();
      final String jointStatus = loc['jointStatus'] ?? 'No Audit';

      final matchesQuery = name.contains(query) || type.contains(query) || id.contains(query);
      if (_statusFilter == 'Open') return matchesQuery && jointStatus == 'Open';
      if (_statusFilter == 'Closed') return matchesQuery && jointStatus == 'Closed';
      return matchesQuery;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Compact Scope Selectors (RCCB Style)
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
                                  _updateUnitList();
                                  _isLoading = true;
                                });
                                await _loadData();
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
                                await _loadData();
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

          // 2. Dashboard Metrics Box
          GlassContainer(
            borderRadius: 20,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Quarterly Joint Audit Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Icon(Icons.groups_3, color: Colors.cyanAccent, size: 20),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('Total Audits', '$_totalAudits', Colors.white),
                      _buildStatItem('Open (Needs Action)', '$_openAuditsCount', Colors.redAccent),
                      _buildStatItem('Closed (Rectified)', '$_closedAuditsCount', Colors.greenAccent),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Search & Filter Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search location or ID...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'All', label: Text('All Audits', style: TextStyle(fontSize: 11))),
                    ButtonSegment(value: 'Open', label: Text('Open (Needs Action)', style: TextStyle(fontSize: 11))),
                    ButtonSegment(value: 'Closed', label: Text('Closed (Rectified)', style: TextStyle(fontSize: 11))),
                  ],
                  selected: {_statusFilter},
                  onSelectionChanged: (val) {
                    setState(() => _statusFilter = val.first);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4. Header Row with Action Buttons
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Joint Audit Schedule (${filteredLocations.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: _exportExcelReport,
                    icon: const Icon(Icons.table_chart, size: 16, color: Colors.greenAccent),
                    label: const Text('Excel', style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: _exportPDFReport,
                    icon: const Icon(Icons.picture_as_pdf, size: 16, color: Colors.redAccent),
                    label: const Text('PDF Report', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 5. Locations List
          filteredLocations.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Text('No matching locations found for Joint Audit.'),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredLocations.length,
                  itemBuilder: (context, idx) {
                    final loc = filteredLocations[idx];
                    final rawId = HierarchyService.stripPrefix(loc['id'], _selectedPlantId!, _selectedUnitId!);
                    final String jointStatus = loc['jointStatus'];
                    final JointIlluminationAuditModel? latest = loc['latestAudit'];

                    Color statusColor = Colors.grey;
                    if (jointStatus == 'Closed') statusColor = Colors.greenAccent;
                    if (jointStatus == 'Open') statusColor = Colors.redAccent;

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
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.groups_3, color: statusColor, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('$rawId - ${loc['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      const SizedBox(height: 3),
                                      Text('Sub-Type: ${loc['type']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                                  ),
                                  child: Text(jointStatus, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor)),
                                ),
                              ],
                            ),
                            const Divider(height: 14),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        latest != null
                                            ? 'Latest Audit: ${latest.auditQuarter} (${_formatDate(latest.auditDate)})'
                                            : 'Latest Audit: Never Audited',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                      if (latest != null) ...[
                                        Text(
                                          'Auditors: Tech: ${latest.auditedByTech} | ${latest.jointDeptName}: ${latest.jointAuditorName}',
                                          style: const TextStyle(fontSize: 10, color: Colors.white70),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (latest.status == 'Open') ...[
                                          Text(
                                            'Defects: ${latest.hasFaultyLights ? '${latest.faultyCount} Faulty; ' : ''}${latest.needsReplacement ? 'Needs Repl; ' : ''}${latest.needsAdditionalLight ? 'Needs Add Light' : ''}',
                                            style: const TextStyle(fontSize: 10, color: Colors.redAccent, fontWeight: FontWeight.bold),
                                          ),
                                        ] else if (latest.rectificationAction != null) ...[
                                          Text(
                                            'Rectified Action: ${latest.rectificationAction}',
                                            style: const TextStyle(fontSize: 10, color: Colors.greenAccent, fontStyle: FontStyle.italic),
                                          ),
                                        ],
                                      ],
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.history, color: Colors.blueAccent, size: 20),
                                      tooltip: 'Audit History',
                                      onPressed: () => setState(() => _historyLocation = loc),
                                    ),
                                    if (latest != null && latest.status == 'Open') ...[
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orangeAccent,
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        icon: const Icon(Icons.build_circle, size: 14, color: Colors.black),
                                        label: const Text('Close Audit', style: TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold)),
                                        onPressed: () => _showRectificationModal(latest),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.add, size: 14, color: Colors.white),
                                      label: const Text('Joint Audit', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                      onPressed: () => _startNewAudit(loc),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildNewAuditFormView() {
    final rawId = HierarchyService.stripPrefix(_selectedLocation!['id'], _selectedPlantId!, _selectedUnitId!);
    final category = _selectedLocation!['category'] ?? getCategoryForType(_selectedLocation!['type'] ?? '');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _selectedLocation = null),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('New Joint Audit: $rawId', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          GlassContainer(
            borderRadius: 16,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Area Name: ${_selectedLocation!['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('Category: $category', style: const TextStyle(fontSize: 11, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                  Text('Sub-Type: ${_selectedLocation!['type']}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: _auditQuarter,
                  decoration: const InputDecoration(
                    labelText: 'Select Audit Quarter *',
                    border: OutlineInputBorder(),
                  ),
                  items: _quarters.map((q) => DropdownMenuItem(value: q, child: Text(q))).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _auditQuarter = v);
                  },
                ),
                const SizedBox(height: 16),

                // Joint Auditors Info Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Joint Auditor Representatives', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueAccent)),
                      const SizedBox(height: 8),
                      Text('Electrical Representative: $_currentUserName ($_userRole)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        value: _jointDeptCtl.text,
                        decoration: const InputDecoration(
                          labelText: 'Co-Auditing Department *',
                          border: OutlineInputBorder(),
                        ),
                        items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _jointDeptCtl.text = v);
                        },
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _jointAuditorNameCtl,
                        decoration: const InputDecoration(
                          labelText: 'Co-Auditor Person Name *',
                          hintText: 'e.g. Mr. Rajesh Kumar (Production Manager)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Please enter co-auditor name' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Luminaire Health Checkpoints
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade800),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Luminaire Verification & Defect Checkpoints', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amberAccent)),
                      const SizedBox(height: 8),

                      // Checkpoint 1: Faulty / Burnt Lights
                      CheckboxListTile(
                        dense: true,
                        title: const Text('Are any lights faulty, non-functional or burnt out?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        value: _hasFaultyLights,
                        onChanged: (v) => setState(() => _hasFaultyLights = v ?? false),
                      ),
                      if (_hasFaultyLights)
                        Padding(
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                          child: TextFormField(
                            controller: _faultyCountCtl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Number of Faulty Lights *',
                              hintText: 'e.g. 2',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),

                      const Divider(),

                      // Checkpoint 2: Need Replacement
                      CheckboxListTile(
                        dense: true,
                        title: const Text('Does any fitting or fixture require complete replacement?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        value: _needsReplacement,
                        onChanged: (v) => setState(() => _needsReplacement = v ?? false),
                      ),
                      if (_needsReplacement)
                        Padding(
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                          child: TextFormField(
                            controller: _replacementDetailsCtl,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Replacement Details & Fixture Specs *',
                              hintText: 'e.g. 2x 150W LED Highbay fittings broken glass cover',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),

                      const Divider(),

                      // Checkpoint 3: Need Additional Light
                      CheckboxListTile(
                        dense: true,
                        title: const Text('Is additional lighting required in dark spots / new work area?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        value: _needsAdditionalLight,
                        onChanged: (v) => setState(() => _needsAdditionalLight = v ?? false),
                      ),
                      if (_needsAdditionalLight)
                        Padding(
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                          child: TextFormField(
                            controller: _additionalLightDetailsCtl,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Additional Light Details & Location *',
                              hintText: 'e.g. 1x 100W LED fitting needed near raw material discharge gate',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _remarksCtl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Joint Audit Remarks / General Observations',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send, color: Colors.white),
                  label: Text(_isSubmitting ? 'Saving Audit...' : 'Submit Joint Audit Log', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                  onPressed: _isSubmitting ? null : _submitJointAudit,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryView() {
    final List<JointIlluminationAuditModel> history = List<JointIlluminationAuditModel>.from(_historyLocation!['history'] ?? []);
    final rawId = HierarchyService.stripPrefix(_historyLocation!['id'], _selectedPlantId!, _selectedUnitId!);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _historyLocation = null),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Joint Audit History: $rawId', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          GlassContainer(
            borderRadius: 16,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Area Name: ${_historyLocation!['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('Category: ${_historyLocation!['category'] ?? getCategoryForType(_historyLocation!['type'] ?? '')}', style: const TextStyle(fontSize: 11, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          history.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 32), child: Text('No historical joint audit logs found.')))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: history.length,
                  itemBuilder: (context, idx) {
                    final item = history[idx];
                    final bool isOpen = item.status == 'Open';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${item.auditQuarter} (${_formatDate(item.auditDate)})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isOpen ? Colors.red.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(item.status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isOpen ? Colors.redAccent : Colors.greenAccent)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('Auditors: Electrical Tech: ${item.auditedByTech} | ${item.jointDeptName}: ${item.jointAuditorName}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 6),

                            if (item.hasFaultyLights) Text('• Faulty Lights: ${item.faultyCount} nos', style: const TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                            if (item.needsReplacement) Text('• Replacement: ${item.replacementDetails}', style: const TextStyle(fontSize: 11, color: Colors.orangeAccent)),
                            if (item.needsAdditionalLight) Text('• Additional Light Needed: ${item.additionalLightDetails}', style: const TextStyle(fontSize: 11, color: Colors.cyanAccent)),
                            if (!item.hasFaultyLights && !item.needsReplacement && !item.needsAdditionalLight) const Text('• Physical Health: Satisfactory (No Faults)', style: TextStyle(fontSize: 11, color: Colors.greenAccent)),

                            if (item.rectificationAction != null) ...[
                              const Divider(height: 16),
                              Text('Rectified Action: ${item.rectificationAction}', style: const TextStyle(fontSize: 11, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                              Text('Rectified By: ${item.rectifiedBy} (${item.rectificationDate != null ? _formatDate(item.rectificationDate!) : ''})', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
