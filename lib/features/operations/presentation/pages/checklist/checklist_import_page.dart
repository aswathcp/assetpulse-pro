import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_roles.dart';
import '../../../../../core/services/auth_service.dart';
import '../../../../../core/services/firestore_service.dart';
import '../../../../../core/services/excel_service.dart';
import '../../../../../core/widgets/glass_container.dart';
import '../../../../../core/widgets/animated_gradient_background.dart';
import '../../../../home/presentation/widgets/custom_app_bar.dart';
import '../../../../../core/services/hierarchy_service.dart';
import '../../../../../core/utils/file_download_helper.dart';
import 'lux_level_checklist_page.dart';

class ChecklistImportPage extends StatefulWidget {
  final String collectionId;
  final String title;
  final String? unitId;
  final String? plantId;

  const ChecklistImportPage({
    super.key,
    required this.collectionId,
    required this.title,
    this.unitId,
    this.plantId,
  });

  @override
  State<ChecklistImportPage> createState() => _ChecklistImportPageState();
}

class _ChecklistImportPageState extends State<ChecklistImportPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final ExcelService _excelService = ExcelService();

  String? _fileName;
  List<Map<String, dynamic>> _previewData = [];
  bool _isProcessing = false;
  String? _statusMessage;
  String? _userUnitId;
  String? _userPlantId;

  // Scope State
  List<String> _plants = [];
  List<String> _units = [];
  bool _isPlantLocked = false;
  bool _isUnitLocked = false;
  bool _isLoadingScope = true;
  String _userRole = '';
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadScope();
  }

  Future<void> _loadScope() async {
    setState(() => _isLoadingScope = true);
    final user = AuthService().currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingScope = false);
      return;
    }

    final profile = await _firestoreService.getUserProfile(user.uid);
    if (profile == null) {
      if (mounted) setState(() => _isLoadingScope = false);
      return;
    }

    _userRole = profile['role'] ?? AppRoles.guest;
    final userPlantId = profile['plantId'] as String?;
    final userUnitId = profile['unitId'] as String?;
    final userBusinessId = profile['businessId'] as String? ?? 'VISL';

    await HierarchyService().init(businessId: userBusinessId);
    _plants = HierarchyService().getPlants();
    _isAdmin = profile['isAdmin'] == true;

    final String? cleanPlant = (userPlantId == null || userPlantId.isEmpty || userPlantId == 'Unknown') ? null : userPlantId;
    final String? cleanUnit = (userUnitId == null || userUnitId.isEmpty || userUnitId == 'Unknown') ? null : userUnitId;

    final bool hasGlobalAdmin = _isAdmin && cleanPlant == null;
    final bool hasPlantAdmin = _isAdmin && cleanPlant != null;

    final bool isPlantScope = (hasPlantAdmin || _userRole == AppRoles.plantAdmin || _userRole == AppRoles.plantHod) &&
        _userRole != AppRoles.manager &&
        _userRole != AppRoles.deputyManager &&
        _userRole != AppRoles.associateManager &&
        _userRole != AppRoles.assistantManager &&
        _userRole != AppRoles.unitAdmin &&
        _userRole != AppRoles.unitHod;

    if (_userRole == AppRoles.developer || _userRole == AppRoles.auditor || hasGlobalAdmin) {
      _isPlantLocked = false;
      _isUnitLocked = false;
      _userPlantId = widget.plantId ?? cleanPlant ?? (_plants.isNotEmpty ? _plants.first : null);
    } else if (isPlantScope) {
      _isPlantLocked = true;
      _userPlantId = widget.plantId ?? cleanPlant ?? (_plants.isNotEmpty ? _plants.first : null);
      _isUnitLocked = false;
    } else {
      _isPlantLocked = true;
      _userPlantId = widget.plantId ?? cleanPlant ?? (_plants.isNotEmpty ? _plants.first : null);
      _isUnitLocked = true;
      _userUnitId = widget.unitId ?? cleanUnit;
    }

    _updateUnitList();

    if (!_isUnitLocked) {
      _userUnitId = widget.unitId ?? cleanUnit ?? (_units.isNotEmpty ? _units.first : null);
    }

    if (mounted) {
      setState(() => _isLoadingScope = false);
    }
  }

  void _updateUnitList() {
    if (_userPlantId == null) {
      _units = [];
      _userUnitId = null;
    } else {
      _units = HierarchyService().getUnitsForPlant(_userPlantId!);
      if (!_units.contains(_userUnitId)) {
        _userUnitId = _units.isNotEmpty ? _units.first : null;
      }
    }
  }

  Map<String, String> _getInstructions() {
    switch (widget.collectionId) {
      case 'water_coolers':
        return {
          'Cols': 'coolerType, location, make, capacityLiters, seqNo',
          'Note': 'Water Coolers & Hot/Cold Dispensers Registry (IS 14724 / IS 10500).\n'
              '• coolerType: Standard type (Hot & Cold Dispenser, Storage Water Cooler, RO + UV Water Cooler, Wall Mounted Chiller, Other Water Coolers)\n'
              '• location: Area name (e.g. BF 1 Cast House, Workshop, Dispatch, Canteen, Admin HR)\n'
              '• make: Manufacturer (e.g. Aquaguard, Voltas, Blue Star, Kent RO - Optional)\n'
              '• capacityLiters: Capacity (e.g. 40 L/hr, 150 L/hr - Optional)\n'
              '• seqNo: 3-digit sequence number (e.g. 001, 002).'
        };
      case 'high_mast_towers':
        return {
          'Cols': 'location, seqNo',
          'Note': 'High Mast Lighting Towers Registry (IS 875 / IS 2266 / CEA 2023).\n'
              '• location: Physical area name (e.g. BF 1 Sizer, Contractor Shed, Dispatch, Plant Yard)\n'
              '• seqNo: 3-digit sequence (e.g. 001, 002).'
        };
      case 'power_tools':
      case 'portable_tools':
        return {
          'Cols': 'tagId, equipmentType, owner, department, location, seqNo',
          'Note': 'Power Tools & Equipment Registry (IS/CEA Industrial Standard).\n'
              '• tagId: Tag ID / Document Key (Optional - auto-generated if left blank)\n'
              '• equipmentType: Standard equipment name (Welding Machine, Grinding Machine, Cutting Machine, Hand Drilling Machine, Pedestal Drill Machine, Extension Board, Mancooler, etc.)\n'
              '• owner: Owner or Vendor name\n'
              '• department: Department (Electrical, Mechanical, Civil, Production, HSE)\n'
              '• location: Area name\n'
              '• seqNo: 3-digit sequence number (e.g. 001, 002).'
        };
      case 'lighting_dbs':
        return {
          'Cols': 'id, location, rccbCount, incomingSource, description',
          'Note': 'Lighting Distribution Board. Location is plain text, and rccbCount is a number (e.g. 12).'
        };
      case 'lux_locations':
        return {
          'Cols': 'id, name, category, type, tableRef, lowLux, midLux, highLux, uniformity, ra, rugl, plane, compassOrientation',
          'Note': 'Lux Location Audit spaces under IS 3646:2025. Required: id, name, type. Optional scale parameters auto-populate if left blank.'
        };
      default:
        return {
          'Cols': 'id, name, description',
          'Note': 'Ensure the first row contains column headers matching the model fields.'
        };
    }
  }

  Future<void> _downloadTemplate() async {
    if (_userUnitId == null || _userPlantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Select scope first.'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final instructions = _getInstructions();
      final List<String> cols = instructions['Cols']!.split(',').map((e) => e.trim()).toList();

      var excel = Excel.createExcel();
      String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
      excel.rename(defaultSheet, 'Template');
      Sheet templateSheet = excel['Template'];

      templateSheet.appendRow(cols.map((e) => TextCellValue(e)).toList());

      final querySnapshot = await FirebaseFirestore.instance
          .collection(widget.collectionId)
          .where('plantId', isEqualTo: _userPlantId)
          .where('unitId', isEqualTo: _userUnitId)
          .get();

      if (widget.collectionId == 'high_mast_towers') {
        for (final doc in querySnapshot.docs) {
          final data = doc.data();
          templateSheet.appendRow([
            TextCellValue(data['location']?.toString() ?? ''),
            TextCellValue(data['seqNo']?.toString() ?? '001'),
          ]);
        }
      } else if (widget.collectionId == 'water_coolers') {
        for (final doc in querySnapshot.docs) {
          final data = doc.data();
          templateSheet.appendRow([
            TextCellValue(data['coolerType']?.toString() ?? ''),
            TextCellValue(data['location']?.toString() ?? ''),
            TextCellValue(data['make']?.toString() ?? ''),
            TextCellValue(data['capacityLiters']?.toString() ?? ''),
            TextCellValue(data['seqNo']?.toString() ?? '001'),
          ]);
        }
      } else if (widget.collectionId == 'power_tools' || widget.collectionId == 'portable_tools') {
        for (final doc in querySnapshot.docs) {
          final data = doc.data();
          templateSheet.appendRow([
            TextCellValue(doc.id),
            TextCellValue(data['equipmentType']?.toString() ?? ''),
            TextCellValue(data['owner']?.toString() ?? ''),
            TextCellValue(data['department']?.toString() ?? ''),
            TextCellValue(data['location']?.toString() ?? ''),
            TextCellValue(data['seqNo']?.toString() ?? '001'),
          ]);
        }
      } else if (widget.collectionId == 'lighting_dbs') {
        for (final doc in querySnapshot.docs) {
          final data = doc.data();
          final rawId = HierarchyService.stripPrefix(doc.id, _userPlantId!, _userUnitId!);
          templateSheet.appendRow([
            TextCellValue(rawId),
            TextCellValue(data['location']?.toString() ?? ''),
            IntCellValue((data['rccbCount'] as num?)?.toInt() ?? 0),
            TextCellValue(data['incomingSource']?.toString() ?? ''),
            TextCellValue(data['description']?.toString() ?? ''),
          ]);
        }
      } else if (widget.collectionId == 'lux_locations') {
        for (final doc in querySnapshot.docs) {
          final data = doc.data();
          templateSheet.appendRow([
            TextCellValue(doc.id),
            TextCellValue(data['name']?.toString() ?? ''),
            TextCellValue(data['category']?.toString() ?? ''),
            TextCellValue(data['type']?.toString() ?? ''),
            TextCellValue(data['tableRef']?.toString() ?? ''),
            DoubleCellValue((data['lowLux'] as num?)?.toDouble() ?? 0.0),
            DoubleCellValue((data['midLux'] as num?)?.toDouble() ?? 0.0),
            DoubleCellValue((data['highLux'] as num?)?.toDouble() ?? 0.0),
            DoubleCellValue((data['uniformity'] as num?)?.toDouble() ?? 0.0),
            DoubleCellValue((data['ra'] as num?)?.toDouble() ?? 0.0),
            DoubleCellValue((data['rugl'] as num?)?.toDouble() ?? 0.0),
            TextCellValue(data['plane']?.toString() ?? ''),
            TextCellValue(data['compassOrientation']?.toString() ?? 'North-Up'),
          ]);
        }
      }

      final fileBytes = excel.save();
      if (fileBytes != null) {
        final savedPath = await downloadFile(fileBytes, '${widget.collectionId}_template.xlsx');
        if (mounted) {
          final message = savedPath != null
              ? 'Saved template to: $savedPath'
              : 'Template generated successfully!';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: AppColors.success, duration: const Duration(seconds: 5)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating template: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<List<Map<String, dynamic>>> _validateImportData(List<Map<String, dynamic>> rawData) async {
    if (_userPlantId == null || _userUnitId == null) return rawData;

    final List<Map<String, dynamic>> enriched = [];

    final snapshot = await FirebaseFirestore.instance
        .collection(widget.collectionId)
        .where('plantId', isEqualTo: _userPlantId)
        .where('unitId', isEqualTo: _userUnitId)
        .get();

    final Set<String> existingIds = snapshot.docs.map((d) => d.id.toUpperCase()).toSet();

    for (final rawRow in rawData) {
      final Map<String, dynamic> row = Map.from(rawRow);

      if (widget.collectionId == 'water_coolers') {
        final cType = row['coolerType']?.toString().trim() ??
            row['type']?.toString().trim() ??
            row['dispenserType']?.toString().trim() ?? '';
        final tagId = row['tagId']?.toString().trim() ?? row['id']?.toString().trim() ?? '';

        String status = 'OK';
        if (cType.isEmpty) {
          status = 'Error: coolerType is missing.';
        } else if (tagId.isNotEmpty && existingIds.contains(tagId.toUpperCase())) {
          status = 'Warning: Tag ID "$tagId" exists. Will update existing.';
        }

        row['Validation'] = status;
        enriched.add(row);
        continue;
      }

      if (widget.collectionId == 'power_tools' || widget.collectionId == 'portable_tools') {
        final eqType = row['equipmentType']?.toString().trim() ??
            row['type']?.toString().trim() ??
            row['equipment_type']?.toString().trim() ??
            row['machineType']?.toString().trim() ?? '';
        final tagId = row['tagId']?.toString().trim() ?? row['id']?.toString().trim() ?? '';

        String status = 'OK';
        if (eqType.isEmpty) {
          status = 'Error: equipmentType is missing.';
        } else if (tagId.isNotEmpty && existingIds.contains(tagId.toUpperCase())) {
          status = 'Warning: Tag ID "$tagId" exists. Will update existing.';
        }

        row['Validation'] = status;
        enriched.add(row);
        continue;
      }

      if (widget.collectionId == 'high_mast_towers') {
        final location = row['location']?.toString().trim() ?? row['area']?.toString().trim() ?? '';
        final seqNo = row['seqNo']?.toString().trim() ?? row['seq']?.toString().trim() ?? '';
        String status = 'OK';
        if (location.isEmpty) {
          status = 'Error: Location is missing.';
        } else {
          final tagId = '${_userPlantId!}-${_userUnitId!}-HMT-${seqNo.padLeft(3, '0')}';
          if (existingIds.contains(tagId.toUpperCase())) {
            status = 'Warning: Tower "$tagId" exists. Will update.';
          }
        }
        row['Validation'] = status;
        enriched.add(row);
        continue;
      }

      if (widget.collectionId == 'lighting_dbs') {
        final rawId = row['id']?.toString().trim() ?? '';
        final rccbVal = row['rccbCount'];
        final rccbStr = rccbVal?.toString().trim() ?? '';
        String status = 'OK';
        if (rawId.isEmpty) {
          status = 'Error: ID is missing.';
        } else if (rccbStr.isEmpty) {
          status = 'Error: rccbCount is missing.';
        } else {
          final fullId = HierarchyService.prefixId(rawId, _userPlantId!, _userUnitId!);
          if (existingIds.contains(fullId.toUpperCase())) {
            status = 'Warning: Lighting DB exists. Will update.';
          }
        }
        row['Validation'] = status;
        enriched.add(row);
        continue;
      }

      if (widget.collectionId == 'lux_locations') {
        final type = row['type']?.toString().trim() ?? '';
        final name = row['name']?.toString().trim() ?? '';
        String status = 'OK';
        if (name.isEmpty) {
          status = 'Error: Name is missing.';
        } else if (type.isEmpty) {
          status = 'Error: Type is missing.';
        }
        row['Validation'] = status;
        enriched.add(row);
        continue;
      }

      final rawId = row['id']?.toString().trim() ?? '';
      String status = rawId.isEmpty ? 'Error: ID is missing' : 'OK';
      row['Validation'] = status;
      enriched.add(row);
    }

    return enriched;
  }

  Future<void> _pickFile() async {
    if (_userUnitId == null) return;

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.single;
        setState(() {
          _fileName = pickedFile.name;
          _isProcessing = true;
          _statusMessage = 'Parsing Excel...';
        });

        final fileBytes = await pickedFile.readAsBytes();
        final data = _excelService.parseExcel(fileBytes);
        final validatedData = await _validateImportData(data);
        setState(() {
          _previewData = validatedData;
          _statusMessage = data.isEmpty
              ? "Error: No data found in file."
              : "Parsed ${data.length} records. Please review warnings/errors below.";
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = "Error: $e";
        _isProcessing = false;
      });
    }
  }

  Future<void> _upload() async {
    final hasErrors = _previewData.any((row) => row['Validation']?.toString().startsWith('Error') == true);
    if (hasErrors) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Resolve validation errors in the preview list before importing.')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = "Uploading to Firestore...";
    });

    try {
      final List<Map<String, dynamic>> finalData = _previewData.map((raw) {
        final Map<String, dynamic> data = Map.from(raw);
        data.remove('Validation');
        data.remove('_sheetName');
        data.remove('_collection');

        data['unitId'] = _userUnitId;
        data['plantId'] = _userPlantId;

        if (widget.collectionId == 'lighting_dbs') {
          if (data['id'] != null) {
            data['id'] = HierarchyService.prefixId(data['id'].toString(), _userPlantId!, _userUnitId!);
          }
          final rccbRaw = data['rccbCount'];
          if (rccbRaw != null) {
            final parsed = double.tryParse(rccbRaw.toString());
            if (parsed != null) data['rccbCount'] = parsed.toInt();
          }
          data.remove('businessId');
        } else if (widget.collectionId == 'lux_locations') {
          if (data['compassOrientation'] == null || data['compassOrientation'].toString().isEmpty) {
            data['compassOrientation'] = 'North-Up';
          }
          final String type = data['type']?.toString() ?? '';
          if (type.isNotEmpty) {
            final details = getDetailsForType(type);
            if (data['category'] == null || data['category'].toString().isEmpty) {
              data['category'] = getCategoryForType(type);
            }
            if (data['tableRef'] == null || data['tableRef'].toString().isEmpty) {
              data['tableRef'] = details['tableRef'];
            }
            if (data['lowLux'] == null) data['lowLux'] = details['lowLux'];
            if (data['midLux'] == null) data['midLux'] = details['midLux'];
            if (data['highLux'] == null) data['highLux'] = details['highLux'];
            if (data['uniformity'] == null) data['uniformity'] = details['uniformity'];
            if (data['ra'] == null) data['ra'] = details['ra'];
            if (data['rugl'] == null) data['rugl'] = details['rugl'];
            if (data['plane'] == null || data['plane'].toString().isEmpty) {
              data['plane'] = details['plane'];
            }
          }
        } else if (widget.collectionId == 'high_mast_towers') {
          final locStr = data['location']?.toString().trim() ?? data['area']?.toString().trim() ?? 'Plant Yard';
          final seqStr = data['seqNo']?.toString().trim() ?? data['seq']?.toString().trim() ?? '001';
          final rawTagId = data['tagId']?.toString().trim() ?? data['id']?.toString().trim() ?? '';
          final finalTagId = rawTagId.isNotEmpty ? rawTagId : '${_userPlantId!}-${_userUnitId!}-HMT-${seqStr.padLeft(3, '0')}';
          data['id'] = finalTagId;
          data['tagId'] = finalTagId;
          data['location'] = locStr;
          data['seqNo'] = seqStr.padLeft(3, '0');
          data['status'] = data['status']?.toString().isNotEmpty == true ? data['status'] : 'Never Tested';
          data['createdAt'] = data['createdAt'] ?? DateTime.now().toIso8601String();
          data['updatedAt'] = DateTime.now().toIso8601String();
        } else if (widget.collectionId == 'water_coolers') {
          final cTypeStr = data['coolerType']?.toString().trim() ?? data['type']?.toString().trim() ?? 'Hot & Cold Dispenser';
          final makeStr = data['make']?.toString().trim() ?? 'Voltas';
          final capStr = data['capacityLiters']?.toString().trim() ?? '40 L/hr';
          final ownerStr = data['owner']?.toString().trim() ?? 'Vedanta';
          final deptStr = data['department']?.toString().trim() ?? 'Administration';
          final locStr = data['location']?.toString().trim() ?? 'Pantry';
          final seqStr = data['seqNo']?.toString().trim() ?? '001';

          final codeMap = {
            'Hot & Cold Dispenser': 'HCD',
            'Storage Water Cooler': 'SWC',
            'RO + UV Water Cooler': 'ROUV',
            'Commercial SS Water Cooler': 'CWC',
            'Wall Mounted Chiller': 'WMC',
            'Other Water Coolers': 'WC',
          };
          final code = codeMap[cTypeStr] ?? 'WC';
          final rawTagId = data['tagId']?.toString().trim() ?? data['id']?.toString().trim() ?? '';
          final finalTagId = rawTagId.isNotEmpty ? rawTagId : '${_userPlantId!}-${_userUnitId!}-$code-${seqStr.padLeft(3, '0')}';

          data['id'] = finalTagId;
          data['tagId'] = finalTagId;
          data['coolerType'] = cTypeStr;
          data['type'] = cTypeStr;
          data['make'] = makeStr;
          data['capacityLiters'] = capStr;
          data['owner'] = ownerStr;
          data['department'] = deptStr;
          data['location'] = locStr;
          data['seqNo'] = seqStr.padLeft(3, '0');
          data['status'] = data['status']?.toString().isNotEmpty == true ? data['status'] : 'Never Tested';
          data['createdAt'] = data['createdAt'] ?? DateTime.now().toIso8601String();
          data['updatedAt'] = DateTime.now().toIso8601String();
        } else if (widget.collectionId == 'portable_tools' || widget.collectionId == 'power_tools') {
          final eqTypeStr = data['equipmentType']?.toString().trim() ?? data['type']?.toString().trim() ?? 'Other Power Tools';
          final ownerStr = data['owner']?.toString().trim() ?? 'Vedanta';
          final deptStr = data['department']?.toString().trim() ?? 'Electrical';
          final locStr = data['location']?.toString().trim() ?? 'Plant Floor';
          final seqStr = data['seqNo']?.toString().trim() ?? '001';

          final eqCodeMap = {
            'Welding Machine': 'WM',
            'Plate Polishing Machine': 'PPM',
            'Grinding Machine': 'GM',
            'Cutting Machine': 'CM',
            'Hand Drilling Machine': 'HDM',
            'Pedestal Drill Machine': 'PDM',
            'Pipe Threading Machine': 'PTM',
            'Hydraulic Crimping Tool': 'HCT',
            'Torque Wrench (Pneumatic)': 'TWP',
            'Extension Board': 'EB',
            'Mancooler': 'MC',
          };
          final code = eqCodeMap[eqTypeStr] ?? 'PT';
          final rawTagId = data['tagId']?.toString().trim() ?? data['id']?.toString().trim() ?? '';
          final finalTagId = rawTagId.isNotEmpty ? rawTagId : '${_userPlantId!}-${_userUnitId!}-$code-${seqStr.padLeft(3, '0')}';

          data['id'] = finalTagId;
          data['tagId'] = finalTagId;
          data['equipmentType'] = eqTypeStr;
          data['owner'] = ownerStr;
          data['department'] = deptStr;
          data['location'] = locStr;
          data['seqNo'] = seqStr.padLeft(3, '0');
          data['status'] = data['status']?.toString().isNotEmpty == true ? data['status'] : 'Never Tested';
          data['createdAt'] = data['createdAt'] ?? DateTime.now().toIso8601String();
          data['updatedAt'] = DateTime.now().toIso8601String();
        } else {
          if (data['id'] != null) {
            data['id'] = HierarchyService.prefixId(data['id'].toString(), _userPlantId!, _userUnitId!);
          }
        }

        return data;
      }).toList();

      await _firestoreService.batchSave(widget.collectionId, finalData);

      if (mounted) {
        setState(() {
          _statusMessage = "Success! Uploaded ${finalData.length} items.";
          _previewData.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import Successful: ${finalData.length} items imported'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      debugPrint('Upload Error: $e');
      if (mounted) {
        setState(() {
          _statusMessage = "Upload failed: $e";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final instructions = _getInstructions();

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: CustomAppBar(title: 'Import ${widget.title}'),
      body: AnimatedGradientBackground(
        child: Column(
          children: [
            // 1. SCOPE HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SCOPE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: AppColors.accent)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (_isLoadingScope) ...[
                          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        ] else ...[
                          if (!_isPlantLocked && _plants.isNotEmpty)
                            _buildScopeDropdown(
                              label: 'Plant',
                              value: _userPlantId,
                              items: _plants,
                              onChanged: (v) {
                                setState(() {
                                  _userPlantId = v;
                                  _updateUnitList();
                                  _previewData.clear();
                                });
                              },
                              icon: Icons.factory,
                            )
                          else
                            _buildScopeChip(
                              label: 'Plant',
                              value: _userPlantId ?? '...',
                              icon: Icons.factory,
                            ),
                          const SizedBox(width: 8),

                          if (!_isUnitLocked && _units.isNotEmpty)
                            _buildScopeDropdown(
                              label: 'Unit',
                              value: _userUnitId,
                              items: _units,
                              onChanged: (v) {
                                setState(() {
                                  _userUnitId = v;
                                  _previewData.clear();
                                });
                              },
                              icon: Icons.settings_input_component,
                            )
                          else
                            _buildScopeChip(
                              label: 'Unit',
                              value: _userUnitId ?? '...',
                              icon: Icons.settings_input_component,
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 2. FORMAT GUIDE
                    GlassContainer(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("FORMAT GUIDE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.accent)),
                                TextButton.icon(
                                  onPressed: _downloadTemplate,
                                  icon: const Icon(Icons.download, size: 16),
                                  label: const Text('Download Template', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    foregroundColor: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text("Required Columns:", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                            Text(instructions['Cols']!, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                            const SizedBox(height: 12),
                            Text("Instructions:", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                            Text(instructions['Note']!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. FILE PICKER
                    GlassContainer(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _isProcessing ? null : _pickFile,
                              icon: const Icon(Icons.attach_file),
                              label: const Text("Select Excel File (.xlsx)"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).cardColor,
                                foregroundColor: Theme.of(context).colorScheme.onSurface,
                                elevation: 0,
                                side: BorderSide(color: Theme.of(context).dividerColor),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                            ),
                            if (_fileName != null) ...[
                              const SizedBox(height: 12),
                              Text("Selected: $_fileName", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
                            ],
                            if (_statusMessage != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _statusMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _statusMessage!.startsWith('Error') || _statusMessage!.startsWith('Upload failed')
                                      ? Colors.redAccent
                                      : _statusMessage!.startsWith('Success')
                                          ? AppColors.success
                                          : Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 4. PREVIEW TABLE & UPLOAD
                    if (_previewData.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Preview Records (${_previewData.length})", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(
                            "${_previewData.where((r) => r['Validation'] == 'OK' || r['Validation']?.toString().startsWith('OK') == true).length} Ready / ${_previewData.where((r) => r['Validation']?.toString().startsWith('Warning') == true || r['Validation']?.toString().startsWith('Info') == true).length} Warnings / ${_previewData.where((r) => r['Validation']?.toString().startsWith('Error') == true).length} Errors",
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      () {
                        final allKeys = <String>{};
                        for (final row in _previewData) {
                          allKeys.addAll(row.keys);
                        }
                        final previewCols = allKeys
                            .where((k) => k != '_sheetName' && k != '_collection')
                            .toList();
                        if (previewCols.contains('Validation')) {
                          previewCols.remove('Validation');
                          previewCols.insert(0, 'Validation');
                        }

                        return Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: GlassContainer(
                            borderRadius: 12,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowHeight: 40,
                                headingRowColor: WidgetStateProperty.all(
                                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                                ),
                                dataRowColor: WidgetStateProperty.resolveWith((states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return Theme.of(context).colorScheme.primary.withValues(alpha: 0.1);
                                  }
                                  return Colors.transparent;
                                }),
                                columns: previewCols.map((k) => DataColumn(
                                  label: Text(
                                    k,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                )).toList(),
                                rows: _previewData.take(50).map((r) {
                                  return DataRow(
                                    cells: previewCols.map((colKey) {
                                      final val = r[colKey]?.toString() ?? '';
                                      final isValidation = colKey == 'Validation';
                                      Color? txtColor;
                                      if (isValidation) {
                                        if (val.startsWith('Error')) {
                                          txtColor = Colors.redAccent;
                                        } else if (val.startsWith('Warning') || val.startsWith('Info')) {
                                          txtColor = Colors.orangeAccent;
                                        } else if (val.startsWith('OK')) {
                                          txtColor = Colors.greenAccent;
                                        }
                                      }
                                      return DataCell(
                                        Text(
                                          val,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: txtColor ?? Theme.of(context).colorScheme.onSurface,
                                            fontWeight: isValidation ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        );
                      }(),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isProcessing ? null : _upload,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isProcessing
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("Confirm & Import All", style: TextStyle(fontSize: 16, color: Colors.white)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeChip({required String label, required String value, required IconData icon}) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.accent),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildScopeDropdown({required String label, required String? value, required List<String> items, required void Function(String?) onChanged, required IconData icon}) {
    final safeValue = items.contains(value) ? value : null;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: DropdownButton<String>(
        value: safeValue,
        underline: const SizedBox(),
        icon: const SizedBox(),
        hint: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.accent),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
        selectedItemBuilder: (context) {
          return items.map((String item) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: AppColors.accent),
                const SizedBox(width: 8),
                Text(item, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            );
          }).toList();
        },
        items: items.map((p) => DropdownMenuItem(value: p, child: Text(p, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13)))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}
