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
import '../../../assets/data/models/location_model.dart';
import '../../../assets/data/models/panel_model.dart';
import '../../../../core/services/hierarchy_service.dart';
import '../../../../core/utils/file_download_helper.dart';

class HierarchyImportPage extends StatefulWidget {
  final String collectionId;
  final String title;
  final String? unitId;
  final String? plantId;

  const HierarchyImportPage({
    super.key,
    required this.collectionId,
    required this.title,
    this.unitId,
    this.plantId,
  });

  @override
  State<HierarchyImportPage> createState() => _HierarchyImportPageState();
}

class _HierarchyImportPageState extends State<HierarchyImportPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final ExcelService _excelService = ExcelService();

  String? _fileName;
  List<Map<String, dynamic>> _previewData = [];
  bool _isProcessing = false;
  String? _statusMessage;
  String? _userUnitId;
  String? _userPlantId;
  bool _isLoadingHierarchy = false;

  // Scope State
  List<String> _plants = [];
  List<String> _units = [];
  bool _isPlantLocked = false;
  bool _isUnitLocked = false;
  bool _isLoadingScope = true;
  String _userRole = '';
  bool _isAdmin = false;

  // Cascading context
  List<LocationModel> _locations = [];
  List<PanelModel> _panels = [];
  String? _selectedLocationId;
  String? _selectedPanelId;

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
      _loadHierarchyData();
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

  Future<void> _loadHierarchyData() async {
    if (_userUnitId == null || _userPlantId == null) return;

    if (['panels', 'feeders', 'master_equipments'].contains(widget.collectionId)) {
      setState(() => _isLoadingHierarchy = true);
      if (widget.collectionId == 'panels') {
        _firestoreService.getPanelRoomsStream(_userUnitId!, _userPlantId!).listen((rooms) {
          if (mounted) {
            setState(() {
              _locations = rooms.map((r) => LocationModel(
                id: r.id,
                unitId: r.unitId,
                plantId: r.plantId,
                name: r.name,
                type: 'Panel Room',
                description: r.description,
              )).toList();
              _isLoadingHierarchy = false;
            });
          }
        });
      } else {
        _firestoreService.getLocationsStream(_userUnitId!, _userPlantId!).listen((locs) {
          if (mounted) {
            setState(() {
              _locations = locs;
              _isLoadingHierarchy = false;
            });
          }
        });
      }
    }
  }

  void _onLocationChanged(String? locId) {
    setState(() {
      _selectedLocationId = locId;
      _selectedPanelId = null;
      _panels = [];
      if (locId != null) _isLoadingHierarchy = true;
    });
    if (locId != null) {
      _firestoreService.getPanelsStream(locId).listen((ps) {
        if (mounted) {
          setState(() {
            _panels = ps;
            _isLoadingHierarchy = false;
          });
        }
      });
    }
  }

  Map<String, String> _getInstructions() {
    switch (widget.collectionId) {
      case 'locations':
        return {
          'Cols': 'id, name, description',
          'Note': 'Physical Area (e.g. BF1-RMHS). Provide human-readable ID, Name, and optional Description.'
        };
      case 'panel_rooms':
        return {
          'Cols': 'id, name, description, locationId',
          'Note': 'Substation room (e.g. MCC-ROOM-2). Link to Physical Area via locationId.'
        };
      case 'panels':
        return {
          'Cols': 'id, name, type, description, panelRoomId',
          'Note': 'Valid types: MCC, PCC, LDB, Control Panel. Specify panelRoomId directly in the row or choose from header.'
        };
      case 'feeders':
        return {
          'Cols': 'id, name, type, description, panelId',
          'Note': 'Valid types: Feeder, Spare, Incomer, Bus Coupler. Specify panelId directly in the row or choose from header.'
        };
      case 'master_equipments':
        return {
          'Cols': 'id, name, type, description, locationId, panelRoomId, panelId, feederId',
          'Note': 'Equipment tag goes into the id column. Link to locationId, panelRoomId, panelId, and feederId.'
        };
      case 'combined_hierarchy':
      default:
        return {
          'Cols': 'Physical Areas, Panel Rooms, Panels / MCCs, Feeders, Master Equipment',
          'Note': 'Upload an All-in-One 5-sheet Master Excel file or single level sheets.\n• Sheet 1: Physical Areas (id, name, description)\n• Sheet 2: Panel Rooms (id, name, description, locationId)\n• Sheet 3: Panels / MCCs (id, name, type, description, panelRoomId)\n• Sheet 4: Feeders (id, name, type, description, panelId)\n• Sheet 5: Master Equipment (id, name, type, description, locationId, panelRoomId, panelId, feederId)\n* Existing live unit data is pre-populated when you download templates!'
        };
    }
  }

  Future<void> _downloadTemplate() async {
    _showHierarchyTemplateModal();
  }

  Future<void> _downloadHierarchyTemplate(String type) async {
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

      // 1. Locations (Physical Areas) - No 'type' column!
      if (type == 'all' || type == 'location' || (widget.collectionId == 'locations' && type == 'single')) {
        final isSingle = type == 'location' || (widget.collectionId == 'locations' && type == 'single');
        final sheetName = isSingle ? 'Locations_Template' : 'Physical Areas';
        if (isSingle && excel.sheets.containsKey(defaultSheet)) {
          excel.rename(defaultSheet, sheetName);
        }
        Sheet locSheet = excel[sheetName];
        final locCols = ['id', 'name', 'description'];
        locSheet.appendRow(locCols.map((e) => TextCellValue(e)).toList());

        final locSnap = await FirebaseFirestore.instance
            .collection('locations')
            .where('plantId', isEqualTo: _userPlantId)
            .where('unitId', isEqualTo: _userUnitId)
            .get();

        if (locSnap.docs.isNotEmpty) {
          for (final doc in locSnap.docs) {
            final data = doc.data();
            final rawId = HierarchyService.stripPrefix(doc.id, _userPlantId!, _userUnitId!);
            locSheet.appendRow([
              TextCellValue(rawId),
              TextCellValue(data['name']?.toString() ?? ''),
              TextCellValue(data['description']?.toString() ?? ''),
            ]);
          }
        } else {
          locSheet.appendRow([TextCellValue('CAST-HOUSE'), TextCellValue('Blast Furnace Cast House Floor'), TextCellValue('Hot metal tapping floor')]);
          locSheet.appendRow([TextCellValue('SIZER-AREA'), TextCellValue('Primary Sizer & Screening Plant'), TextCellValue('Raw ore reduction area')]);
          locSheet.appendRow([TextCellValue('WTP-AREA'), TextCellValue('Water Treatment & Cooling Tower'), TextCellValue('Circulation pump station')]);
        }
      }

      // 2. Panel Rooms (Substations)
      if (type == 'all' || type == 'panel_room' || (widget.collectionId == 'panel_rooms' && type == 'single')) {
        final isSingle = type == 'panel_room' || (widget.collectionId == 'panel_rooms' && type == 'single');
        final sheetName = isSingle ? 'Panel_Rooms_Template' : 'Panel Rooms';
        if (isSingle && excel.sheets.containsKey(defaultSheet)) {
          excel.rename(defaultSheet, sheetName);
        }
        Sheet prSheet = excel[sheetName];
        final prCols = ['id', 'name', 'description', 'locationId'];
        prSheet.appendRow(prCols.map((e) => TextCellValue(e)).toList());

        final prSnap = await FirebaseFirestore.instance
            .collection('panel_rooms')
            .where('plantId', isEqualTo: _userPlantId)
            .where('unitId', isEqualTo: _userUnitId)
            .get();

        if (prSnap.docs.isNotEmpty) {
          for (final doc in prSnap.docs) {
            final data = doc.data();
            final rawId = HierarchyService.stripPrefix(doc.id, _userPlantId!, _userUnitId!);
            final rawLocId = data['locationId'] != null ? HierarchyService.stripPrefix(data['locationId'].toString(), _userPlantId!, _userUnitId!) : '';
            prSheet.appendRow([
              TextCellValue(rawId),
              TextCellValue(data['name']?.toString() ?? ''),
              TextCellValue(data['description']?.toString() ?? ''),
              TextCellValue(rawLocId),
            ]);
          }
        } else {
          prSheet.appendRow([TextCellValue('MCC-ROOM-01'), TextCellValue('Main Cast House MCC Room 1'), TextCellValue('Substation 1 housing main drives'), TextCellValue('CAST-HOUSE')]);
          prSheet.appendRow([TextCellValue('MCC-ROOM-02'), TextCellValue('Secondary Sizer MCC Room 2'), TextCellValue('Substation 2 housing sizers'), TextCellValue('SIZER-AREA')]);
          prSheet.appendRow([TextCellValue('WTP-ELEC-ROOM'), TextCellValue('WTP Electrical Control Room'), TextCellValue('Water treatment substation'), TextCellValue('WTP-AREA')]);
        }
      }

      // 3. Panels (MCCs / PCCs)
      if (type == 'all' || type == 'panel' || (widget.collectionId == 'panels' && type == 'single')) {
        final isSingle = type == 'panel' || (widget.collectionId == 'panels' && type == 'single');
        final sheetName = isSingle ? 'Panels_Template' : 'Panels';
        if (isSingle && excel.sheets.containsKey(defaultSheet)) {
          excel.rename(defaultSheet, sheetName);
        }
        Sheet pnlSheet = excel[sheetName];
        final pnlCols = ['id', 'name', 'type', 'description', 'panelRoomId'];
        pnlSheet.appendRow(pnlCols.map((e) => TextCellValue(e)).toList());

        final pnlSnap = await FirebaseFirestore.instance
            .collection('panels')
            .where('plantId', isEqualTo: _userPlantId)
            .where('unitId', isEqualTo: _userUnitId)
            .get();

        if (pnlSnap.docs.isNotEmpty) {
          for (final doc in pnlSnap.docs) {
            final data = doc.data();
            final rawId = HierarchyService.stripPrefix(doc.id, _userPlantId!, _userUnitId!);
            final rawPrId = data['panelRoomId'] != null ? HierarchyService.stripPrefix(data['panelRoomId'].toString(), _userPlantId!, _userUnitId!) : '';
            pnlSheet.appendRow([
              TextCellValue(rawId),
              TextCellValue(data['name']?.toString() ?? ''),
              TextCellValue(data['type']?.toString() ?? 'MCC'),
              TextCellValue(data['description']?.toString() ?? ''),
              TextCellValue(rawPrId),
            ]);
          }
        } else {
          pnlSheet.appendRow([TextCellValue('MCC-01'), TextCellValue('415V Cast House Main MCC Panel 1'), TextCellValue('MCC'), TextCellValue('Fed from TR-1'), TextCellValue('MCC-ROOM-01')]);
          pnlSheet.appendRow([TextCellValue('MCC-02'), TextCellValue('415V Sizer Drives MCC Panel 2'), TextCellValue('MCC'), TextCellValue('Fed from TR-2'), TextCellValue('MCC-ROOM-02')]);
          pnlSheet.appendRow([TextCellValue('PCC-01'), TextCellValue('415V Main Power Control Center'), TextCellValue('PCC'), TextCellValue('Main incomer switchboard'), TextCellValue('MCC-ROOM-01')]);
        }
      }

      // 4. Feeders
      if (type == 'all' || type == 'feeder' || (widget.collectionId == 'feeders' && type == 'single')) {
        final isSingle = type == 'feeder' || (widget.collectionId == 'feeders' && type == 'single');
        final sheetName = isSingle ? 'Feeders_Template' : 'Feeders';
        if (isSingle && excel.sheets.containsKey(defaultSheet)) {
          excel.rename(defaultSheet, sheetName);
        }
        Sheet fdrSheet = excel[sheetName];
        final fdrCols = ['id', 'name', 'type', 'description', 'panelId'];
        fdrSheet.appendRow(fdrCols.map((e) => TextCellValue(e)).toList());

        final fdrSnap = await FirebaseFirestore.instance
            .collection('feeders')
            .where('plantId', isEqualTo: _userPlantId)
            .where('unitId', isEqualTo: _userUnitId)
            .get();

        if (fdrSnap.docs.isNotEmpty) {
          for (final doc in fdrSnap.docs) {
            final data = doc.data();
            final rawId = HierarchyService.stripPrefix(doc.id, _userPlantId!, _userUnitId!);
            final rawPnlId = data['panelId'] != null ? HierarchyService.stripPrefix(data['panelId'].toString(), _userPlantId!, _userUnitId!) : '';
            fdrSheet.appendRow([
              TextCellValue(rawId),
              TextCellValue(data['name']?.toString() ?? ''),
              TextCellValue(data['type']?.toString() ?? 'Feeder'),
              TextCellValue(data['description']?.toString() ?? ''),
              TextCellValue(rawPnlId),
            ]);
          }
        } else {
          fdrSheet.appendRow([TextCellValue('INCOMER-1'), TextCellValue('1600A Incomer ACB Feeder 1'), TextCellValue('Incomer'), TextCellValue('From 2MVA Transformer 1'), TextCellValue('PCC-01')]);
          fdrSheet.appendRow([TextCellValue('SIZER-MTR-FDR'), TextCellValue('160A Sizer Drive Feeder'), TextCellValue('Feeder'), TextCellValue('Sizer motor MPCB/Contactor module'), TextCellValue('MCC-02')]);
          fdrSheet.appendRow([TextCellValue('CRANE-BUS-FDR'), TextCellValue('250A Cast House Crane Power Feeder'), TextCellValue('Feeder'), TextCellValue('DSL busbar power tap-off'), TextCellValue('MCC-01')]);
        }
      }

      // 5. Master Equipment
      if (type == 'all' || type == 'master_equipment' || (widget.collectionId == 'master_equipments' && type == 'single')) {
        final isSingle = type == 'master_equipment' || (widget.collectionId == 'master_equipments' && type == 'single');
        final sheetName = isSingle ? 'Master_Equipment_Template' : 'Master Equipment';
        if (isSingle && excel.sheets.containsKey(defaultSheet)) {
          excel.rename(defaultSheet, sheetName);
        }
        Sheet meSheet = excel[sheetName];
        final meCols = ['id', 'name', 'type', 'description', 'locationId', 'panelRoomId', 'panelId', 'feederId'];
        meSheet.appendRow(meCols.map((e) => TextCellValue(e)).toList());

        final meSnap = await FirebaseFirestore.instance
            .collection('master_equipments')
            .where('plantId', isEqualTo: _userPlantId)
            .where('unitId', isEqualTo: _userUnitId)
            .get();

        if (meSnap.docs.isNotEmpty) {
          for (final doc in meSnap.docs) {
            final data = doc.data();
            final rawId = HierarchyService.stripPrefix(doc.id, _userPlantId!, _userUnitId!);
            final rawLocId = data['locationId'] != null ? HierarchyService.stripPrefix(data['locationId'].toString(), _userPlantId!, _userUnitId!) : '';
            final rawPrId = data['panelRoomId'] != null ? HierarchyService.stripPrefix(data['panelRoomId'].toString(), _userPlantId!, _userUnitId!) : '';
            final rawPnlId = data['panelId'] != null ? HierarchyService.stripPrefix(data['panelId'].toString(), _userPlantId!, _userUnitId!) : '';
            final rawFdrId = data['feederId'] != null ? HierarchyService.stripPrefix(data['feederId'].toString(), _userPlantId!, _userUnitId!) : '';

            meSheet.appendRow([
              TextCellValue(rawId),
              TextCellValue(data['name']?.toString() ?? ''),
              TextCellValue(data['type']?.toString() ?? 'Machinery'),
              TextCellValue(data['description']?.toString() ?? ''),
              TextCellValue(rawLocId),
              TextCellValue(rawPrId),
              TextCellValue(rawPnlId),
              TextCellValue(rawFdrId),
            ]);
          }
        } else {
          meSheet.appendRow([
            TextCellValue('BF1-SIZER-01'),
            TextCellValue('Primary Sizer Machine 1'),
            TextCellValue('Crushing & Sizing'),
            TextCellValue('Heavy duty mineral sizer'),
            TextCellValue('SIZER-AREA'),
            TextCellValue('MCC-ROOM-02'),
            TextCellValue('MCC-02'),
            TextCellValue('SIZER-MTR-FDR'),
          ]);
          meSheet.appendRow([
            TextCellValue('BF1-CH-CRANE-01'),
            TextCellValue('Cast House 60T Hot Metal Crane 1'),
            TextCellValue('EOT Crane'),
            TextCellValue('60/10T Cast house crane'),
            TextCellValue('CAST-HOUSE'),
            TextCellValue('MCC-ROOM-01'),
            TextCellValue('MCC-01'),
            TextCellValue('CRANE-BUS-FDR'),
          ]);
        }
      }

      // 6. Reference Guide Sheet
      if (type == 'all') {
        Sheet refSheet = excel['Reference_Guide'];
        refSheet.appendRow([TextCellValue('HIERARCHY MASTER DATA STRUCTURE & LINKING GUIDE')]);
        refSheet.appendRow([TextCellValue('Tier'), TextCellValue('Sheet Name'), TextCellValue('ID Tag Format'), TextCellValue('Parent Link Column'), TextCellValue('Description')]);
        refSheet.appendRow([TextCellValue('Tier 1'), TextCellValue('Physical Areas'), TextCellValue('CAST-HOUSE, SIZER-AREA'), TextCellValue('N/A (Root)'), TextCellValue('Geographical or functional plant zone')]);
        refSheet.appendRow([TextCellValue('Tier 2'), TextCellValue('Panel Rooms'), TextCellValue('MCC-ROOM-01'), TextCellValue('locationId (Optional)'), TextCellValue('Substation, Switchgear or MCC Room')]);
        refSheet.appendRow([TextCellValue('Tier 3'), TextCellValue('Panels'), TextCellValue('MCC-01, PCC-01, LDB-01'), TextCellValue('panelRoomId'), TextCellValue('Switchboard, MCC or PCC distribution panel')]);
        refSheet.appendRow([TextCellValue('Tier 4'), TextCellValue('Feeders'), TextCellValue('INCOMER-1, FDR-01'), TextCellValue('panelId'), TextCellValue('Breaker, module, starter or outgoer feeder')]);
        refSheet.appendRow([TextCellValue('Tier 5'), TextCellValue('Master Equipment'), TextCellValue('BF1-SIZER-01, CRANE-01'), TextCellValue('locationId, panelRoomId, panelId, feederId'), TextCellValue('Physical machine tag holding electrical/mechanical assets')]);
      }

      final filename = type == 'location' || (widget.collectionId == 'locations' && type == 'single')
          ? 'Physical_Areas_Template.xlsx'
          : type == 'panel_room' || (widget.collectionId == 'panel_rooms' && type == 'single')
              ? 'Panel_Rooms_Template.xlsx'
              : type == 'panel' || (widget.collectionId == 'panels' && type == 'single')
                  ? 'Panels_MCC_Template.xlsx'
                  : type == 'feeder' || (widget.collectionId == 'feeders' && type == 'single')
                      ? 'Feeders_Template.xlsx'
                      : type == 'master_equipment' || (widget.collectionId == 'master_equipments' && type == 'single')
                          ? 'Master_Equipment_Template.xlsx'
                          : 'Hierarchy_Master_All_In_One.xlsx';

      final fileBytes = excel.save();
      if (fileBytes != null) {
        final savedPath = await downloadFile(fileBytes, filename);
        if (mounted) {
          final message = savedPath != null
              ? 'Saved hierarchy template with live unit data to: $savedPath'
              : 'Template generated successfully with live unit data!';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: AppColors.success, duration: const Duration(seconds: 6)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating hierarchy template: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showHierarchyTemplateModal() {
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
                  const Text('Choose Hierarchy Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Download tailored Excel templates populated with your live unit database records for editing and re-import:',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.indigo.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.map, color: Colors.indigoAccent),
                ),
                title: const Text('Physical Areas (Locations) Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Tier 1: Geographic plant zones (ID, Name, Description)', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.download, size: 18, color: Colors.indigoAccent),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadHierarchyTemplate('location');
                },
              ),
              const Divider(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.deepPurple.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.room_preferences, color: Colors.deepPurpleAccent),
                ),
                title: const Text('Panel Rooms (Substations) Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Tier 2: Substation switchgear rooms (ID, Name, Description, Location Link)', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.download, size: 18, color: Colors.deepPurpleAccent),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadHierarchyTemplate('panel_room');
                },
              ),
              const Divider(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.electric_bolt, color: Colors.amberAccent),
                ),
                title: const Text('Panels / MCCs Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Tier 3: MCCs, PCCs, LDBs (ID, Name, Type, Description, Panel Room Link)', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.download, size: 18, color: Colors.amberAccent),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadHierarchyTemplate('panel');
                },
              ),
              const Divider(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.cyan.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.power_input, color: Colors.cyanAccent),
                ),
                title: const Text('Feeders Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Tier 4: Incomer, Outgoer, Starter Feeders (ID, Name, Type, Panel Link)', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.download, size: 18, color: Colors.cyanAccent),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadHierarchyTemplate('feeder');
                },
              ),
              const Divider(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.precision_manufacturing, color: Colors.orangeAccent),
                ),
                title: const Text('Master Equipment Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Tier 5: Machine tags linked to Location, Panel Room, Panel, Feeder', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.download, size: 18, color: Colors.orangeAccent),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadHierarchyTemplate('master_equipment');
                },
              ),
              const Divider(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.table_chart, color: Colors.greenAccent),
                ),
                title: const Text('All-in-One Master Hierarchy Workbook (5 Sheets)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Contains all 5 levels + Reference Guide pre-populated with live unit data', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.download, size: 18, color: Colors.greenAccent),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadHierarchyTemplate('all');
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _validateImportData(List<Map<String, dynamic>> rawData) async {
    if (_userPlantId == null || _userUnitId == null) return rawData;

    final List<Map<String, dynamic>> enriched = [];

    // Pre-fetch existing documents for validation
    final locs = await FirebaseFirestore.instance.collection('locations').where('plantId', isEqualTo: _userPlantId).where('unitId', isEqualTo: _userUnitId).get();
    final Set<String> knownLocIds = {};
    for (var d in locs.docs) {
      knownLocIds.add(d.id.toUpperCase());
      knownLocIds.add(HierarchyService.stripPrefix(d.id, _userPlantId!, _userUnitId!).toUpperCase());
    }

    final prs = await FirebaseFirestore.instance.collection('panel_rooms').where('plantId', isEqualTo: _userPlantId).where('unitId', isEqualTo: _userUnitId).get();
    final Set<String> knownPrIds = {};
    for (var d in prs.docs) {
      knownPrIds.add(d.id.toUpperCase());
      knownPrIds.add(HierarchyService.stripPrefix(d.id, _userPlantId!, _userUnitId!).toUpperCase());
    }

    final pnls = await FirebaseFirestore.instance.collection('panels').where('plantId', isEqualTo: _userPlantId).where('unitId', isEqualTo: _userUnitId).get();
    final Set<String> knownPnlIds = {};
    for (var d in pnls.docs) {
      knownPnlIds.add(d.id.toUpperCase());
      knownPnlIds.add(HierarchyService.stripPrefix(d.id, _userPlantId!, _userUnitId!).toUpperCase());
    }

    final fdrs = await FirebaseFirestore.instance.collection('feeders').where('plantId', isEqualTo: _userPlantId).where('unitId', isEqualTo: _userUnitId).get();
    final Set<String> knownFdrIds = {};
    for (var d in fdrs.docs) {
      knownFdrIds.add(d.id.toUpperCase());
      knownFdrIds.add(HierarchyService.stripPrefix(d.id, _userPlantId!, _userUnitId!).toUpperCase());
    }

    final eqs = await FirebaseFirestore.instance.collection('master_equipments').where('plantId', isEqualTo: _userPlantId).where('unitId', isEqualTo: _userUnitId).get();
    final Set<String> knownEqIds = {};
    for (var d in eqs.docs) {
      knownEqIds.add(d.id.toUpperCase());
      knownEqIds.add(HierarchyService.stripPrefix(d.id, _userPlantId!, _userUnitId!).toUpperCase());
    }

    for (final rawRow in rawData) {
      final Map<String, dynamic> row = Map.from(rawRow);

      final target = row['_collection']?.toString().trim() ?? '';
      final sheet = row['_sheetName']?.toString().toLowerCase().trim() ?? '';

      String coll = target;
      if (coll.isEmpty) {
        if (widget.collectionId != 'combined_hierarchy') {
          coll = widget.collectionId;
        } else if (sheet.contains('location') || sheet.contains('area') || sheet.contains('physical')) {
          coll = 'locations';
        } else if (sheet.contains('room') || sheet.contains('substation')) {
          coll = 'panel_rooms';
        } else if (sheet.contains('panel') || sheet.contains('mcc') || sheet.contains('pcc')) {
          coll = 'panels';
        } else if (sheet.contains('feeder')) {
          coll = 'feeders';
        } else if (sheet.contains('equipment') || sheet.contains('machin') || sheet.contains('master')) {
          coll = 'master_equipments';
        } else {
          if (row.containsKey('feederId') || (row.containsKey('locationId') && row.containsKey('panelId'))) {
            coll = 'master_equipments';
          } else if (row.containsKey('panelId') && !row.containsKey('feederId')) {
            coll = 'feeders';
          } else if (row.containsKey('panelRoomId') && !row.containsKey('feederId')) {
            coll = 'panels';
          } else if (row.containsKey('locationId') && !row.containsKey('panelRoomId')) {
            coll = 'panel_rooms';
          } else {
            coll = 'locations';
          }
        }
      }
      row['_collection'] = coll;

      final rawId = row['id']?.toString().trim() ?? row['tagId']?.toString().trim() ?? '';
      final name = row['name']?.toString().trim() ?? '';

      String status = 'OK';
      if (rawId.isEmpty) {
        status = 'Error: ID / Tag is missing.';
      } else if (name.isEmpty) {
        status = 'Warning: Name is blank.';
      } else {
        final fullId = HierarchyService.prefixId(rawId, _userPlantId!, _userUnitId!);
        final upperRaw = rawId.toUpperCase();
        final upperFull = fullId.toUpperCase();

        if (coll == 'locations') {
          if (knownLocIds.contains(upperFull) || knownLocIds.contains(upperRaw)) {
            status = 'Warning: Area "$rawId" exists. Will update.';
          }
          knownLocIds.add(upperFull);
          knownLocIds.add(upperRaw);
        } else if (coll == 'panel_rooms') {
          if (knownPrIds.contains(upperFull) || knownPrIds.contains(upperRaw)) {
            status = 'Warning: Panel Room "$rawId" exists. Will update.';
          }
          final locId = row['locationId']?.toString().trim() ?? '';
          if (locId.isNotEmpty) {
            final fullLoc = HierarchyService.prefixId(locId, _userPlantId!, _userUnitId!).toUpperCase();
            if (!knownLocIds.contains(fullLoc) && !knownLocIds.contains(locId.toUpperCase())) {
              status = 'Info: Linked Location "$locId" (will resolve).';
            }
          }
          knownPrIds.add(upperFull);
          knownPrIds.add(upperRaw);
        } else if (coll == 'panels') {
          if (knownPnlIds.contains(upperFull) || knownPnlIds.contains(upperRaw)) {
            status = 'Warning: Panel "$rawId" exists. Will update.';
          }
          final prId = row['panelRoomId']?.toString().trim() ?? '';
          if (prId.isNotEmpty) {
            final fullPr = HierarchyService.prefixId(prId, _userPlantId!, _userUnitId!).toUpperCase();
            if (!knownPrIds.contains(fullPr) && !knownPrIds.contains(prId.toUpperCase())) {
              status = 'Warning: Panel Room "$prId" not found in batch or unit.';
            }
          } else if (_selectedLocationId == null && widget.collectionId == 'panels') {
            status = 'Error: Select Panel Room in header or specify in panelRoomId column.';
          }
          knownPnlIds.add(upperFull);
          knownPnlIds.add(upperRaw);
        } else if (coll == 'feeders') {
          if (knownFdrIds.contains(upperFull) || knownFdrIds.contains(upperRaw)) {
            status = 'Warning: Feeder "$rawId" exists. Will update.';
          }
          final pId = row['panelId']?.toString().trim() ?? '';
          if (pId.isNotEmpty) {
            final fullP = HierarchyService.prefixId(pId, _userPlantId!, _userUnitId!).toUpperCase();
            if (!knownPnlIds.contains(fullP) && !knownPnlIds.contains(pId.toUpperCase())) {
              status = 'Warning: Panel "$pId" not found in batch or unit.';
            }
          } else if (_selectedPanelId == null && widget.collectionId == 'feeders') {
            status = 'Error: Select Panel in header or specify in panelId column.';
          }
          knownFdrIds.add(upperFull);
          knownFdrIds.add(upperRaw);
        } else if (coll == 'master_equipments') {
          if (knownEqIds.contains(upperFull) || knownEqIds.contains(upperRaw)) {
            status = 'Warning: Machine "$rawId" exists. Will update.';
          }
          final locId = row['locationId']?.toString().trim() ?? '';
          if (locId.isNotEmpty) {
            final fullLoc = HierarchyService.prefixId(locId, _userPlantId!, _userUnitId!).toUpperCase();
            if (!knownLocIds.contains(fullLoc) && !knownLocIds.contains(locId.toUpperCase())) {
              status = 'Info: Location "$locId" assigned.';
            }
          }
          knownEqIds.add(upperFull);
          knownEqIds.add(upperRaw);
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

        final data = widget.collectionId == 'combined_hierarchy'
            ? _excelService.parseAllSheets(fileBytes)
            : _excelService.parseExcel(fileBytes);
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
      final List<Map<String, dynamic>> locList = [];
      final List<Map<String, dynamic>> prList = [];
      final List<Map<String, dynamic>> pnlList = [];
      final List<Map<String, dynamic>> fdrList = [];
      final List<Map<String, dynamic>> meList = [];

      for (final raw in _previewData) {
        final data = Map<String, dynamic>.from(raw);
        data.remove('Validation');
        final target = data.remove('_collection')?.toString() ?? (widget.collectionId == 'combined_hierarchy' ? 'locations' : widget.collectionId);
        data.remove('_sheetName');

        data['plantId'] = _userPlantId!;
        data['unitId'] = _userUnitId!;

        final rawId = data['id']?.toString().trim() ?? '';
        if (rawId.isNotEmpty) {
          data['id'] = HierarchyService.prefixId(rawId, _userPlantId!, _userUnitId!);
        }

        if (target == 'locations') {
          locList.add(data);
        } else if (target == 'panel_rooms') {
          if (data['locationId'] != null && data['locationId'].toString().isNotEmpty) {
            data['locationId'] = HierarchyService.prefixId(data['locationId'].toString(), _userPlantId!, _userUnitId!);
          }
          prList.add(data);
        } else if (target == 'panels') {
          if (data['panelRoomId'] == null || data['panelRoomId'].toString().isEmpty) {
            if (_selectedLocationId != null) data['panelRoomId'] = _selectedLocationId;
          } else {
            data['panelRoomId'] = HierarchyService.prefixId(data['panelRoomId'].toString(), _userPlantId!, _userUnitId!);
          }
          pnlList.add(data);
        } else if (target == 'feeders') {
          if (data['panelId'] == null || data['panelId'].toString().isEmpty) {
            if (_selectedPanelId != null) data['panelId'] = _selectedPanelId;
          } else {
            data['panelId'] = HierarchyService.prefixId(data['panelId'].toString(), _userPlantId!, _userUnitId!);
          }
          fdrList.add(data);
        } else if (target == 'master_equipments' || target == 'master_equipment') {
          if (data['locationId'] == null || data['locationId'].toString().isEmpty) {
            if (_selectedLocationId != null) data['locationId'] = _selectedLocationId;
          } else {
            data['locationId'] = HierarchyService.prefixId(data['locationId'].toString(), _userPlantId!, _userUnitId!);
          }
          if (data['panelRoomId'] != null && data['panelRoomId'].toString().isNotEmpty) {
            data['panelRoomId'] = HierarchyService.prefixId(data['panelRoomId'].toString(), _userPlantId!, _userUnitId!);
          }
          if (data['panelId'] != null && data['panelId'].toString().isNotEmpty) {
            data['panelId'] = HierarchyService.prefixId(data['panelId'].toString(), _userPlantId!, _userUnitId!);
          }
          if (data['feederId'] != null && data['feederId'].toString().isNotEmpty) {
            data['feederId'] = HierarchyService.prefixId(data['feederId'].toString(), _userPlantId!, _userUnitId!);
          }
          meList.add(data);
        }
      }

      if (locList.isNotEmpty) {
        if (mounted) setState(() => _statusMessage = 'Uploading ${locList.length} Areas...');
        await _firestoreService.batchSave('locations', locList);
      }
      if (prList.isNotEmpty) {
        if (mounted) setState(() => _statusMessage = 'Uploading ${prList.length} Panel Rooms...');
        await _firestoreService.batchSave('panel_rooms', prList);
      }
      if (pnlList.isNotEmpty) {
        if (mounted) setState(() => _statusMessage = 'Uploading ${pnlList.length} Panels...');
        await _firestoreService.batchSave('panels', pnlList);
      }
      if (fdrList.isNotEmpty) {
        if (mounted) setState(() => _statusMessage = 'Uploading ${fdrList.length} Feeders...');
        await _firestoreService.batchSave('feeders', fdrList);
      }
      if (meList.isNotEmpty) {
        if (mounted) setState(() => _statusMessage = 'Uploading ${meList.length} Master Equipment...');
        await _firestoreService.batchSave('master_equipments', meList);
      }

      final summary = [
        if (locList.isNotEmpty) '${locList.length} Areas',
        if (prList.isNotEmpty) '${prList.length} Rooms',
        if (pnlList.isNotEmpty) '${pnlList.length} Panels',
        if (fdrList.isNotEmpty) '${fdrList.length} Feeders',
        if (meList.isNotEmpty) '${meList.length} Machines',
      ].join(', ');

      if (mounted) {
        setState(() {
          _statusMessage = "Success! Uploaded $summary.";
          _previewData.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import complete: $summary'), backgroundColor: AppColors.success),
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
                                  _selectedLocationId = null;
                                  _selectedPanelId = null;
                                  _previewData.clear();
                                });
                                _loadHierarchyData();
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
                                  _selectedLocationId = null;
                                  _selectedPanelId = null;
                                  _previewData.clear();
                                });
                                _loadHierarchyData();
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

                        if (_isLoadingHierarchy) ...[
                          const SizedBox(width: 12),
                          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        ] else ...[
                          if (['panels', 'feeders', 'master_equipments'].contains(widget.collectionId)) ...[
                            const SizedBox(width: 8),
                            _buildScopeDropdown(
                              label: widget.collectionId == 'panels' ? 'Panel Room' : 'Location',
                              value: _locations.any((l) => l.id == _selectedLocationId)
                                  ? _locations.firstWhere((l) => l.id == _selectedLocationId).name
                                  : null,
                              items: _locations.map((e) => e.name).toList(),
                              onChanged: (v) {
                                final loc = _locations.firstWhere((l) => l.name == v);
                                _onLocationChanged(loc.id);
                              },
                              icon: Icons.location_on,
                            ),
                          ],

                          if (widget.collectionId == 'master_equipments') ...[
                            const SizedBox(width: 8),
                            _buildScopeDropdown(
                              label: 'Panel',
                              value: _panels.any((p) => p.id == _selectedPanelId)
                                  ? _panels.firstWhere((p) => p.id == _selectedPanelId).name
                                  : null,
                              items: _panels.map((e) => e.name).toList(),
                              onChanged: (v) {
                                final panel = _panels.firstWhere((p) => p.name == v);
                                setState(() => _selectedPanelId = panel.id);
                              },
                              icon: Icons.electric_bolt,
                            ),
                          ],
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
                                  label: const Text('Choose Template', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                            "${_previewData.where((r) => r['Validation'] == 'OK').length} Ready / ${_previewData.where((r) => r['Validation']?.toString().startsWith('Warning') == true).length} Warnings / ${_previewData.where((r) => r['Validation']?.toString().startsWith('Error') == true).length} Errors",
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
                                        } else if (val.startsWith('Warning') || val.startsWith('Will')) {
                                          txtColor = Colors.orangeAccent;
                                        } else if (val == 'OK') {
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
