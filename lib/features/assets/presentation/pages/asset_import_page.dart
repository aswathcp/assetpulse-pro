import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_roles.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/excel_service.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../home/presentation/widgets/custom_app_bar.dart';
import '../../../../core/services/hierarchy_service.dart';
import '../../../../core/utils/file_download_helper.dart';

class AssetImportPage extends StatefulWidget {
  final String? unitId;
  final String? plantId;

  const AssetImportPage({
    super.key,
    this.unitId,
    this.plantId,
  });

  @override
  State<AssetImportPage> createState() => _AssetImportPageState();
}

class _AssetImportPageState extends State<AssetImportPage> {
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

  void _showAssetTemplateModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Choose Asset Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Download tailored Excel templates with technical specification columns per asset classification:',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.bolt, color: Colors.amberAccent),
                ),
                title: const Text('Electric Motors Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Power (kW), Voltage, FLC, Poles, Frame Size, Mounting, Bearings, Grease Grade', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.download, size: 18, color: Colors.amberAccent),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadAssetTemplate('motor');
                },
              ),
              const Divider(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.disc_full_outlined, color: Colors.purpleAccent),
                ),
                title: const Text('Industrial Brakes Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('DC Electromagnetic / AC EHT Thrusters, Drum Dia/Width, Mounting Pitch, Torque, Lining', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.download, size: 18, color: Colors.purpleAccent),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadAssetTemplate('brake');
                },
              ),
              const Divider(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.tune, color: Colors.tealAccent),
                ),
                title: const Text('Valve Actuators Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Electric / Pneumatic / Hydraulic, Torque/Thrust, Signal (4-20mA), Valve Size, ISO Flange', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.download, size: 18, color: Colors.tealAccent),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadAssetTemplate('actuator');
                },
              ),
              const Divider(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.settings, color: Colors.orangeAccent),
                ),
                title: const Text('Industrial Gearboxes Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Gear Ratio, Sump Capacity, Oil Grade, Input/Output Shafts, Speeds, Bearings', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.download, size: 18, color: Colors.orangeAccent),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadAssetTemplate('gearbox');
                },
              ),
              const Divider(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.water_drop, color: Colors.blueAccent),
                ),
                title: const Text('Process & Water Pumps Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Flow Rate (m³/h), Head, Speed, Impeller, Suction/Discharge Flanges, Seal Type', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.download, size: 18, color: Colors.blueAccent),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadAssetTemplate('pump');
                },
              ),
              const Divider(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.table_chart, color: Colors.greenAccent),
                ),
                title: const Text('All-in-One Master Workbook (5 Sheets)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Contains Motors, Brakes, Actuators, Gearboxes, Pumps tabs and Parent Reference Guide', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.download, size: 18, color: Colors.greenAccent),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadAssetTemplate('all');
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadAssetTemplate(String type) async {
    if (_userUnitId == null || _userPlantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Select scope first.'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      var excel = Excel.createExcel();
      String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';

      final commonPrefix = [
        'tagNo', 'name', 'type', 'status', 'parentEquipment',
        'applicableParentEquipmentIds', 'spareLocation', 'installationDate',
        'isCritical',
        'make', 'model', 'serialNo', 'manufacturingYear',
        'rfidTag', 'poNo', 'imageUrl', 'description',
      ];

      final motorCols = [
        ...commonPrefix,
        'powerKw', 'voltage', 'fullLoadCurrent', 'noLoadCurrent', 'speedRpm',
        'poles', 'frequency', 'efficiency', 'powerFactor', 'frameSize',
        'mountingType', 'greaseType', 'motorType', 'dutyCycle', 'insulationClass',
        'couplingAvailable', 'couplingType', 'efficiencyClass', 'ipRating',
        'bearingDE', 'bearingNDE',
      ];

      final brakeCols = [
        ...commonPrefix,
        'brakeType', 'thrusterCapacityKg', 'voltageType', 'voltageRating',
        'drumDiaMm', 'drumWidthMm', 'drumInstallation', 'mountingBoltSize',
        'mountingBoltCount', 'mountingLengthMm', 'mountingWidthMm',
        'brakingTorqueNm', 'brakeShoeLining',
      ];

      final actuatorCols = [
        ...commonPrefix,
        'actuatorType', 'torqueOrThrust', 'operatingTimeSeconds',
        'controlSignal', 'valveFlangeStandard', 'valveType', 'valveSize',
      ];

      final gearboxCols = [
        ...commonPrefix,
        'powerKw', 'gearRatio', 'oilType', 'oilCapacity',
        'inputSpeedRpm', 'outputSpeedRpm', 'inputShaftMm', 'outputShaftMm',
        'lubricationMethod', 'mountingOrientation',
        'bearingDE', 'bearingNDE',
      ];

      final pumpCols = [
        ...commonPrefix,
        'flowRate', 'head', 'speedRpm', 'pumpPower', 'impellerSize',
        'suctionFlangeMm', 'dischargeFlangeMm', 'sealType', 'casingMaterial', 'greaseType',
        'bearingDE', 'bearingNDE',
      ];

      void appendTab(String sheetName, List<String> cols, List<List<String>> sampleRows) {
        if (excel.sheets.containsKey(defaultSheet) && excel.sheets.length == 1) {
          excel.rename(defaultSheet, sheetName);
        }
        Sheet sheet = excel[sheetName];
        sheet.appendRow(cols.map((e) => TextCellValue(e)).toList());
        for (final row in sampleRows) {
          sheet.appendRow(row.map((e) => TextCellValue(e)).toList());
        }
      }

      if (type == 'all' || type == 'motor') {
        appendTab(type == 'all' ? 'Motors' : 'Motors_Template', motorCols, [
          [
            '${_userPlantId!}-${_userUnitId!}-MTR-001', '90kW 4P 415V Primary Sizer 1 Drive Motor', 'motor', 'active', 'BF1-SIZER-01',
            'BF1-SIZER-01, BF1-SIZER-02', 'Bay-3 Shelf-B', '2022-04-15',
            'TRUE',
            'ABB', 'M3BP 280SMB 4', '3G13142001', '2022',
            'E280117000000201', 'PO-2022-8819', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=60', 'Heavy duty sizer main drive motor',
            '90', '415', '158', '45', '1485',
            '4', '50', '95.5', '0.87', '280S',
            'Foot Mounted (B3)', 'Mobil Polyrex EM', 'Induction Motor', 'S1 (Continuous)', 'Class F',
            'YES', 'Flexible Pin-Bush', 'IE3', 'IP55',
            '6317 C3', '6317 C3',
          ]
        ]);
      }

      if (type == 'all' || type == 'brake') {
        appendTab(type == 'all' ? 'Brakes' : 'Brakes_Template', brakeCols, [
          [
            '${_userPlantId!}-${_userUnitId!}-BRK-001', 'EHT Thruster Brake 300mm Dia', 'brake', 'active', 'BF1-CH-CRANE-01',
            'BF1-CH-CRANE-01', 'Brake Yard Bay-1', '2023-01-20',
            'TRUE',
            'Electromag', 'EHT-300-50', 'BRK-9901', '2023',
            'E280117000000211', 'PO-2023-3301', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=60', 'Cast house crane main hoist brake',
            'Electro-Hydraulic Thruster (EHT)', '50', 'AC', '415',
            '300', '125', 'Motor Shaft', 'M16',
            '4', '350', '250',
            '650', 'Asbestos-Free Molded Friction Material',
          ]
        ]);
      }

      if (type == 'all' || type == 'actuator') {
        appendTab(type == 'all' ? 'Actuators' : 'Actuators_Template', actuatorCols, [
          [
            '${_userPlantId!}-${_userUnitId!}-ACT-001', 'Rotork IQ35 Pro Multi-Turn Actuator 4-20mA', 'actuator', 'active', 'BF1-SNORT-VALVE',
            'BF1-SNORT-VALVE', 'Actuator Rack Bay-2', '2023-03-10',
            'TRUE',
            'Rotork', 'IQ35 Pro', 'ACT-2023-01', '2023',
            'E280117000000221', 'PO-2023-4412', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=60', 'Cold blast snort valve regulating actuator',
            'Electric Multi-Turn', '600', '30',
            '4-20mA Modulating', 'ISO 5211 (F14)', 'Butterfly Valve', '12 Inch (DN300)',
          ]
        ]);
      }

      if (type == 'all' || type == 'gearbox') {
        appendTab(type == 'all' ? 'Gearboxes' : 'Gearboxes_Template', gearboxCols, [
          [
            '${_userPlantId!}-${_userUnitId!}-GBX-001', 'Bevel Helical 3-Stage Heavy Duty Sizer Gearbox', 'gearbox', 'active', 'BF1-SIZER-01',
            'BF1-SIZER-01, BF1-SIZER-02', 'Heavy Storage Shed A', '2022-05-12',
            'TRUE',
            'Elecon', 'PBN 355-3', 'EL-2022-881', '2022',
            'E280117000000231', 'PO-2022-7721', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=60', 'Dual roll mineral sizer speed reduction gearbox',
            '90', '31.5 : 1', 'ISO VG 320', '65',
            '1480', '47', '75', '180',
            'Splash / Forced', 'Horizontal Foot',
            '22220 E', '23236 CC/W33',
          ]
        ]);
      }

      if (type == 'all' || type == 'pump') {
        appendTab(type == 'all' ? 'Pumps' : 'Pumps_Template', pumpCols, [
          [
            '${_userPlantId!}-${_userUnitId!}-PMP-001', 'End Suction Tuyere Cooling Water Pump (350 m3/h)', 'pump', 'active', 'BF1-CWP-01',
            'BF1-CWP-01, BF1-CWP-02', 'Pump Bay 2', '2021-11-25',
            'TRUE',
            'Kirloskar Brothers', 'DB 125-330', 'KBL-2021-009', '2021',
            'E280117000000241', 'PO-2021-9920', 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=60', 'Blast furnace tuyere cooling water circulating pump',
            '350', '65', '1480', '75', '330mm',
            '150', '125', 'Mechanical Seal', 'Cast Iron FG 260', 'ISO VG 68 Turbinol Oil',
            'NU 312', '7312 BECBP',
          ]
        ]);
      }

      // Reference Guide Sheet
      Sheet refSheet = excel['Reference_Guide'];
      refSheet.appendRow([TextCellValue('AVAILABLE PARENT EQUIPMENTS IN UNIT: $_userUnitId')]);
      refSheet.appendRow([TextCellValue('Raw Equipment ID (Use in parentEquipment column)'), TextCellValue('Full Document Key'), TextCellValue('Equipment Name')]);

      final snapshot = await FirebaseFirestore.instance
          .collection('master_equipments')
          .where('plantId', isEqualTo: _userPlantId)
          .where('unitId', isEqualTo: _userUnitId)
          .get();

      for (final doc in snapshot.docs) {
        final rawId = HierarchyService.stripPrefix(doc.id, _userPlantId!, _userUnitId!);
        refSheet.appendRow([TextCellValue(rawId), TextCellValue(doc.id), TextCellValue(doc.data()['name'] ?? '')]);
      }

      final filename = type == 'motor'
          ? 'Motor_Import_Template.xlsx'
          : type == 'gearbox'
              ? 'Gearbox_Import_Template.xlsx'
              : type == 'pump'
                  ? 'Pump_Import_Template.xlsx'
                  : type == 'brake'
                      ? 'Brake_Import_Template.xlsx'
                      : type == 'actuator'
                          ? 'Actuator_Import_Template.xlsx'
                          : 'Asset_Master_Templates.xlsx';

      final fileBytes = excel.save();
      if (fileBytes != null) {
        final savedPath = await downloadFile(fileBytes, filename);
        if (mounted) {
          final message = savedPath != null
              ? 'Saved template to: $savedPath'
              : 'Template generated successfully!';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: AppColors.success, duration: const Duration(seconds: 6)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating asset template: $e'), backgroundColor: AppColors.error),
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
        .collection('assets')
        .where('plantId', isEqualTo: _userPlantId)
        .where('unitId', isEqualTo: _userUnitId)
        .get();
    final Set<String> existingIds = snapshot.docs.map((d) => d.id.toUpperCase()).toSet();

    final parentSnapshot = await FirebaseFirestore.instance
        .collection('master_equipments')
        .where('plantId', isEqualTo: _userPlantId)
        .where('unitId', isEqualTo: _userUnitId)
        .get();
    final Set<String> validParentIds = parentSnapshot.docs.map((d) => d.id.toUpperCase()).toSet();

    for (final rawRow in rawData) {
      final Map<String, dynamic> row = Map.from(rawRow);

      final name = row['name']?.toString().trim() ??
          row['equipmentName']?.toString().trim() ??
          row['assetName']?.toString().trim() ?? '';
      final rawType = row['type']?.toString().trim().toLowerCase() ?? 'motor';
      final typeStr = rawType.contains('gear')
          ? 'gearbox'
          : rawType.contains('pump')
              ? 'pump'
              : rawType.contains('brake')
                  ? 'brake'
                  : rawType.contains('actuat')
                      ? 'actuator'
                      : 'motor';

      final rawStatus = row['status']?.toString().trim().toLowerCase() ?? 'active';
      final statusStr = rawStatus.contains('spare')
          ? 'spare'
          : rawStatus.contains('maint')
              ? 'underMaintenance'
              : rawStatus.contains('scrap')
                  ? 'scrapped'
                  : 'active';

      final seqStr = row['seqNo']?.toString().trim() ?? row['seq']?.toString().trim() ?? '';
      final rawTag = row['tagNo']?.toString().trim() ?? row['tagId']?.toString().trim() ?? row['id']?.toString().trim() ?? '';

      final typeCode = typeStr == 'gearbox'
          ? 'GBX'
          : typeStr == 'pump'
              ? 'PMP'
              : typeStr == 'brake'
                  ? 'BRK'
                  : typeStr == 'actuator'
                      ? 'ACT'
                      : 'MTR';
      final finalTagId = rawTag.isNotEmpty
          ? rawTag
          : seqStr.isNotEmpty
              ? '${_userPlantId!}-${_userUnitId!}-$typeCode-${seqStr.padLeft(3, '0')}'
              : '${_userPlantId!}-${_userUnitId!}-$typeCode-AUTO';

      String status = 'OK';

      if (name.isEmpty) {
        status = 'Error: Asset name is missing.';
      } else if (existingIds.contains(finalTagId.toUpperCase()) && rawTag.isNotEmpty) {
        status = 'Warning: Tag ID "$finalTagId" exists. Will update record.';
      } else {
        final parentRaw = row['parentEquipment']?.toString().trim() ??
            row['masterEquipmentId']?.toString().trim() ??
            row['installedMachine']?.toString().trim() ?? '';

        if (statusStr == 'active' && parentRaw.isNotEmpty) {
          final fullParent = HierarchyService.prefixId(parentRaw, _userPlantId!, _userUnitId!);
          final rawParentUpper = parentRaw.toUpperCase();
          final fullParentUpper = fullParent.toUpperCase();
          final matches = validParentIds.contains(fullParentUpper) || validParentIds.contains(rawParentUpper);
          if (!matches && validParentIds.isNotEmpty) {
            status = 'Info: Assigned to parent "$parentRaw"';
          }
        } else if (statusStr == 'spare') {
          status = 'OK (Spare Asset)';
        }
      }

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
        final data = _excelService.parseAllSheets(fileBytes);
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

        final rawType = data['type']?.toString().trim().toLowerCase() ?? 'motor';
        final typeStr = rawType.contains('gear')
            ? 'gearbox'
            : rawType.contains('pump')
                ? 'pump'
                : rawType.contains('brake')
                    ? 'brake'
                    : rawType.contains('actuat')
                        ? 'actuator'
                        : 'motor';
        data['type'] = typeStr;

        final rawStatus = data['status']?.toString().trim().toLowerCase() ?? 'active';
        final statusStr = rawStatus.contains('spare')
            ? 'spare'
            : rawStatus.contains('maint')
                ? 'underMaintenance'
                : rawStatus.contains('scrap')
                    ? 'scrapped'
                    : 'active';
        data['status'] = statusStr;

        final typeCode = typeStr == 'gearbox'
            ? 'GBX'
            : typeStr == 'pump'
                ? 'PMP'
                : typeStr == 'brake'
                    ? 'BRK'
                    : typeStr == 'actuator'
                        ? 'ACT'
                        : 'MTR';
        final rawTag = data['tagNo']?.toString().trim() ?? data['tagId']?.toString().trim() ?? data['id']?.toString().trim() ?? '';
        final seqStr = data['seqNo']?.toString().trim() ?? data['seq']?.toString().trim() ?? '';

        final finalTagId = rawTag.isNotEmpty
            ? rawTag
            : seqStr.isNotEmpty
                ? '${_userPlantId!}-${_userUnitId!}-$typeCode-${seqStr.padLeft(3, '0')}'
                : '${_userPlantId!}-${_userUnitId!}-$typeCode-${DateTime.now().millisecondsSinceEpoch % 10000}';

        final parentRaw = data['parentEquipment']?.toString().trim() ??
            data['masterEquipmentId']?.toString().trim() ??
            data['installedMachine']?.toString().trim() ?? '';

        // Numeric conversion helpers
        double? toDouble(dynamic v) {
          if (v == null) return null;
          if (v is num) return v.toDouble();
          final s = v.toString().trim();
          if (s.isEmpty || s.toLowerCase() == 'n/a' || s == '-') return null;
          final direct = double.tryParse(s);
          if (direct != null) return direct;
          final match = RegExp(r'[-+]?\d*\.?\d+').firstMatch(s);
          return match != null ? double.tryParse(match.group(0)!) : null;
        }

        int? toInt(dynamic v) {
          if (v == null) return null;
          if (v is num) return v.toInt();
          final s = v.toString().trim();
          if (s.isEmpty || s.toLowerCase() == 'n/a' || s == '-') return null;
          final direct = int.tryParse(s);
          if (direct != null) return direct;
          final match = RegExp(r'[-+]?\d+').firstMatch(s);
          return match != null ? int.tryParse(match.group(0)!) : null;
        }

        DateTime? parseDate(dynamic v) {
          if (v == null) return null;
          if (v is DateTime) return v;
          final s = v.toString().trim();
          if (s.isEmpty || s.toLowerCase() == 'n/a' || s == '-') return null;
          final direct = DateTime.tryParse(s);
          if (direct != null) return direct;
          if (s.contains('/')) {
            final parts = s.split('/');
            if (parts.length == 3) {
              final day = int.tryParse(parts[0]);
              final month = int.tryParse(parts[1]);
              final year = int.tryParse(parts[2]);
              if (day != null && month != null && year != null) {
                return DateTime(year, month, day);
              }
            }
          }
          return null;
        }

        final Map<String, dynamic> cleanData = {};

        cleanData['id'] = finalTagId;
        cleanData['tagNo'] = finalTagId;
        cleanData['name'] = data['name']?.toString().trim() ?? '';
        cleanData['type'] = typeStr;
        cleanData['status'] = statusStr;
        cleanData['unitId'] = _userUnitId!;
        cleanData['plantId'] = _userPlantId!;
        cleanData['make'] = data['make']?.toString().trim() ?? '';
        cleanData['model'] = data['model']?.toString().trim() ?? '';
        cleanData['serialNo'] = data['serialNo']?.toString().trim() ?? '';
        cleanData['description'] = data['description']?.toString().trim() ?? '';
        cleanData['manufacturingYear'] = toInt(data['manufacturingYear'] ?? data['yearOfManufacture']);
        cleanData['spareLocation'] = data['spareLocation']?.toString().trim() ?? data['locationInWarehouse']?.toString().trim();
        cleanData['installationDate'] = parseDate(data['installationDate']);
        cleanData['isCritical'] = data['isCritical'] == true ||
            data['isCritical']?.toString().toLowerCase() == 'true' ||
            data['isCritical']?.toString().toLowerCase() == 'yes';
        cleanData['rfidTag'] = data['rfidTag']?.toString().trim();
        cleanData['poNo'] = data['poNo']?.toString().trim();
        cleanData['imageUrl'] = data['imageUrl']?.toString().trim();

        // Parent equipment linking
        if (statusStr == 'active' && parentRaw.isNotEmpty) {
          final prefixedParent = HierarchyService.prefixId(parentRaw, _userPlantId!, _userUnitId!);
          cleanData['masterEquipmentId'] = prefixedParent;
          cleanData['parentEquipment'] = prefixedParent;
        } else {
          cleanData['masterEquipmentId'] = '';
          cleanData['parentEquipment'] = null;
        }

        // Compatible equipment list for spares
        final rawCompat = data['applicableParentEquipmentIds'] ?? data['compatibleEquipments'];
        if (rawCompat != null) {
          if (rawCompat is List) {
            cleanData['applicableParentEquipmentIds'] = rawCompat
                .map((e) => HierarchyService.prefixId(e.toString().trim(), _userPlantId!, _userUnitId!))
                .where((e) => e.isNotEmpty)
                .toList();
          } else if (rawCompat is String && rawCompat.isNotEmpty) {
            cleanData['applicableParentEquipmentIds'] = rawCompat
                .split(',')
                .map((e) => HierarchyService.prefixId(e.trim(), _userPlantId!, _userUnitId!))
                .where((e) => e.isNotEmpty)
                .toList();
          }
        }
        // Motor Specs
        if (typeStr == 'motor') {
          cleanData['powerKw'] = toDouble(data['powerKw']);
          cleanData['voltage'] = toDouble(data['voltage'] ?? data['supplyVoltage']);
          cleanData['fullLoadCurrent'] = toDouble(data['fullLoadCurrent'] ?? data['ratedCurrent']);
          cleanData['noLoadCurrent'] = toDouble(data['noLoadCurrent']);
          cleanData['speedRpm'] = toDouble(data['speedRpm']);
          cleanData['poles'] = toInt(data['poles']);
          cleanData['frequency'] = toDouble(data['frequency']);
          cleanData['efficiency'] = toDouble(data['efficiency']);
          cleanData['powerFactor'] = toDouble(data['powerFactor']);
          cleanData['frameSize'] = data['frameSize']?.toString().trim();
          cleanData['mountingType'] = data['mountingType']?.toString().trim();
          cleanData['motorType'] = data['motorType']?.toString().trim();
          cleanData['dutyCycle'] = data['dutyCycle']?.toString().trim();
          cleanData['insulationClass'] = data['insulationClass']?.toString().trim();
          cleanData['couplingType'] = data['couplingType']?.toString().trim();
          cleanData['couplingAvailable'] = data['couplingAvailable']?.toString().trim() ?? (cleanData['couplingType'] != null ? 'YES' : 'NO');
          cleanData['efficiencyClass'] = data['efficiencyClass']?.toString().trim();
          cleanData['ipRating'] = data['ipRating']?.toString().trim() ?? data['enclosureRating']?.toString().trim();
          cleanData['greaseType'] = data['greaseType']?.toString().trim() ?? data['greaseGrade']?.toString().trim();
          cleanData['bearingDE'] = data['bearingDE']?.toString().trim() ?? data['driveEndBearing']?.toString().trim();
          cleanData['bearingNDE'] = data['bearingNDE']?.toString().trim() ?? data['nonDriveEndBearing']?.toString().trim();
        }

        // Brake Specs
        if (typeStr == 'brake') {
          cleanData['brakeType'] = data['brakeType']?.toString().trim();
          cleanData['thrusterCapacityKg'] = toDouble(data['thrusterCapacityKg'] ?? data['thrusterLiftingForceN']);
          cleanData['voltageType'] = data['voltageType']?.toString().trim();
          cleanData['voltageRating'] = toDouble(data['voltageRating'] ?? data['supplyVoltage']);
          cleanData['drumDiaMm'] = toDouble(data['drumDiaMm'] ?? data['drumDiameterMm']);
          cleanData['drumWidthMm'] = toDouble(data['drumWidthMm']);
          cleanData['drumInstallation'] = data['drumInstallation']?.toString().trim();
          cleanData['mountingBoltSize'] = data['mountingBoltSize']?.toString().trim() ?? data['mountingHolePitch']?.toString().trim();
          cleanData['mountingBoltCount'] = toInt(data['mountingBoltCount']);
          cleanData['mountingLengthMm'] = toDouble(data['mountingLengthMm']);
          cleanData['mountingWidthMm'] = toDouble(data['mountingWidthMm']);
          cleanData['brakingTorqueNm'] = toDouble(data['brakingTorqueNm'] ?? data['ratedTorqueNm']);
          cleanData['brakeShoeLining'] = data['brakeShoeLining']?.toString().trim() ?? data['liningMaterial']?.toString().trim();
        }

        // Actuator Specs
        if (typeStr == 'actuator') {
          cleanData['actuatorType'] = data['actuatorType']?.toString().trim();
          cleanData['torqueOrThrust'] = toDouble(data['torqueOrThrust'] ?? data['operatingTorqueNm']);
          cleanData['operatingTimeSeconds'] = toDouble(data['operatingTimeSeconds']);
          cleanData['controlSignal'] = data['controlSignal']?.toString().trim() ?? data['inputControlSignal']?.toString().trim();
          cleanData['valveFlangeStandard'] = data['valveFlangeStandard']?.toString().trim() ?? data['isoFlangeSize']?.toString().trim();
          cleanData['valveType'] = data['valveType']?.toString().trim();
          cleanData['valveSize'] = data['valveSize']?.toString().trim() ?? data['valveSizeInch']?.toString().trim();
        }

        // Gearbox Specs
        if (typeStr == 'gearbox') {
          cleanData['powerKw'] = toDouble(data['powerKw']);
          cleanData['gearRatio'] = data['gearRatio']?.toString().trim() ?? data['ratio']?.toString().trim();
          cleanData['oilType'] = data['oilType']?.toString().trim() ?? data['oilGrade']?.toString().trim();
          cleanData['oilCapacity'] = toDouble(data['oilCapacity'] ?? data['oilCapacityLiters']);
          cleanData['inputSpeedRpm'] = toDouble(data['inputSpeedRpm']);
          cleanData['outputSpeedRpm'] = toDouble(data['outputSpeedRpm']);
          cleanData['inputShaftMm'] = toDouble(data['inputShaftMm'] ?? data['inputShaftDiameterMm']);
          cleanData['outputShaftMm'] = toDouble(data['outputShaftMm'] ?? data['outputShaftDiameterMm']);
          cleanData['lubricationMethod'] = data['lubricationMethod']?.toString().trim() ?? data['lubricationType']?.toString().trim();
          cleanData['mountingOrientation'] = data['mountingOrientation']?.toString().trim();
          cleanData['bearingDE'] = data['bearingDE']?.toString().trim() ?? data['driveEndBearing']?.toString().trim() ?? data['inputBearing']?.toString().trim();
          cleanData['bearingNDE'] = data['bearingNDE']?.toString().trim() ?? data['nonDriveEndBearing']?.toString().trim() ?? data['outputBearing']?.toString().trim();
        }

        // Pump Specs
        if (typeStr == 'pump') {
          cleanData['flowRate'] = toDouble(data['flowRate'] ?? data['flowRateM3Hr']);
          cleanData['head'] = toDouble(data['head'] ?? data['headMeters']);
          cleanData['speedRpm'] = toDouble(data['speedRpm']);
          cleanData['pumpPower'] = toDouble(data['pumpPower'] ?? data['powerKw']);
          cleanData['impellerSize'] = data['impellerSize']?.toString().trim() ?? data['impellerDiameterMm']?.toString().trim();
          cleanData['suctionFlangeMm'] = toDouble(data['suctionFlangeMm'] ?? data['suctionSizeMm']);
          cleanData['dischargeFlangeMm'] = toDouble(data['dischargeFlangeMm'] ?? data['dischargeSizeMm']);
          cleanData['sealType'] = data['sealType']?.toString().trim();
          cleanData['casingMaterial'] = data['casingMaterial']?.toString().trim();
          cleanData['greaseType'] = data['greaseType']?.toString().trim() ?? data['oilGreaseGrade']?.toString().trim();
          cleanData['bearingDE'] = data['bearingDE']?.toString().trim() ?? data['driveEndBearing']?.toString().trim() ?? data['bearingDriveEnd']?.toString().trim();
          cleanData['bearingNDE'] = data['bearingNDE']?.toString().trim() ?? data['nonDriveEndBearing']?.toString().trim() ?? data['bearingNonDriveEnd']?.toString().trim();
        }

        cleanData.removeWhere((k, v) => v == null || (v is String && v.isEmpty));
        return cleanData;
      }).toList();

      await _firestoreService.batchSave('assets', finalData);

      if (mounted) {
        setState(() {
          _statusMessage = "Success! Uploaded ${finalData.length} assets.";
          _previewData.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import Successful: ${finalData.length} assets imported'), backgroundColor: AppColors.success),
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
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: const CustomAppBar(title: 'Import Assets'),
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
                                  onPressed: _showAssetTemplateModal,
                                  icon: const Icon(Icons.download, size: 16),
                                  label: const Text('Choose Template', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    foregroundColor: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text("Template Guidelines:", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                            const Text(
                              "Customized templates available for Motors, Brakes, Actuators, Gearboxes & Pumps!",
                              style: TextStyle(fontFamily: 'monospace', fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            Text("Instructions:", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                            const Text(
                              "Tap 'Choose Template' to download the exact technical specification columns for your equipment:\n"
                              "• Motors: kW, Voltage, FLC, Poles, Frame Size, Mounting, Bearings, Grease\n"
                              "• Brakes: AC Thrusters, DC Solenoid, Drum Dia/Width, Torque, Lining\n"
                              "• Actuators: Multi/Part-Turn, Signal (4-20mA), Valve Type/Size, ISO Flange\n"
                              "• Gearboxes & Pumps: Ratios, Shafts, Flow, Head, Impeller, Seals\n"
                              "• Spares: Define warehouse storage location and compatible parent machines!",
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
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
