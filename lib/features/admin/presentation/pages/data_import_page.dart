import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/excel_service.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../home/presentation/widgets/custom_app_bar.dart';
import '../../../assets/data/models/location_model.dart';
import '../../../assets/data/models/panel_model.dart';
import '../../../../core/services/hierarchy_service.dart';
import '../../../../core/utils/file_download_helper.dart';
import '../../../operations/presentation/pages/checklist/lux_level_checklist_page.dart';

class DataImportPage extends StatefulWidget {
  final String collectionId;
  final String title;
  final String? unitId;
  final String? plantId;

  const DataImportPage({
    super.key, 
    required this.collectionId, 
    required this.title,
    this.unitId, 
    this.plantId
  });

  @override
  State<DataImportPage> createState() => _DataImportPageState();
}

class _DataImportPageState extends State<DataImportPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final ExcelService _excelService = ExcelService();
  
  String? _fileName;
  List<Map<String, dynamic>> _previewData = [];
  bool _isProcessing = false;
  String? _statusMessage;
  String? _userUnitId;
  String? _userPlantId;
  bool _isLoadingHierarchy = false;

  // For cascading context if needed during import
  List<LocationModel> _locations = [];
  List<PanelModel> _panels = [];
  String? _selectedLocationId;
  String? _selectedPanelId;

  @override
  void initState() {
    super.initState();
    _userUnitId = widget.unitId;
    _userPlantId = widget.plantId;
    
    if (_userUnitId == null || _userPlantId == null) {
      _loadUserProfile();
    } else {
      _loadHierarchyData();
    }
  }

  Future<void> _loadUserProfile() async {
    final unitAndPlant = await _firestoreService.getUserUnitAndPlant();
    if (mounted) {
      if (unitAndPlant == null || unitAndPlant['unitId']!.isEmpty || unitAndPlant['plantId']!.isEmpty) {
        setState(() => _statusMessage = "Error: Assign Unit/Plant in Profile first.");
      } else {
        setState(() {
          _userUnitId = unitAndPlant['unitId'];
          _userPlantId = unitAndPlant['plantId'];
        });
        _loadHierarchyData();
      }
    }
  }

  Future<void> _loadHierarchyData() async {
    if (_userUnitId == null || _userPlantId == null) return;
    
    // Only fetch if collection needs parent context
    if (['panels', 'feeders', 'master_equipments', 'assets'].contains(widget.collectionId)) {
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
          'Cols': 'id, name, type, description',
          'Note': 'Location represents a Physical Area (e.g. BF1-RMHS). Valid types: Area, Panel Room, Other.'
        };
      case 'panel_rooms':
        return {
          'Cols': 'id, name, description',
          'Note': 'Panel Room represents a Substation room (e.g. MCC-ROOM-2).'
        };
      case 'panels':
        return {
          'Cols': 'id, name, type, description, panelRoomId',
          'Note': 'Valid types: MCC, PCC, LDB, Control Panel. You can specify panelRoomId directly in the row.'
        };
      case 'feeders':
        return {
          'Cols': 'id, name, type, description, panelId',
          'Note': 'Valid types: Feeder, Spare, Incomer, Bus Coupler. You can specify panelId directly in the row.'
        };
      case 'master_equipments':
        return {
          'Cols': 'id, name, type, description, locationId, panelRoomId, panelId, feederId',
          'Note': 'TagNo goes into the id column. Link to locationId (Physical Area), panelRoomId, panelId, and feederId.'
        };
      case 'assets':
        return {
          'Cols': 'Dedicated templates available for Motors, Gearboxes, and Pumps!',
          'Note': 'Choose your specific Asset Type template below to download the exact technical specification columns.\n• Motors: kW, Voltage, FLC, Poles, Frame Size, Mounting, Bearings, Grease\n• Gearboxes: Ratio, Sump Capacity, Oil Grade, Shafts, Lubrication, Bearings\n• Pumps: Flow Rate, Head, Speed, Impeller, Flange Sizes, Seal Type\n• Spares: Define warehouse location and compatible parent machines (e.g. CB-1; CB-2)!'
        };
      case 'lighting_dbs':
        return {
          'Cols': 'id, location, rccbCount, incomingSource, description',
          'Note': 'Lighting DB represents a Lighting Distribution Board. Location is plain text, and rccbCount is a number (e.g. 12).'
        };
      case 'lux_locations':
        return {
          'Cols': 'id, name, category, type, tableRef, lowLux, midLux, highLux, uniformity, ra, rugl, plane, compassOrientation',
          'Note': 'Lux Location represents physical space to audit under IS 3646:2025. Required columns: id (e.g. 1), name, type. Optional columns: category, tableRef, lowLux, midLux, highLux, uniformity, ra, rugl, plane, compassOrientation (defaults to North-Up). If category/tableRef/scale values are left blank, they are automatically populated based on type!'
        };
      case 'water_coolers':
        return {
          'Cols': 'coolerType, location, make, capacityLiters, seqNo',
          'Note': 'Water Coolers & Hot/Cold Dispensers Registry (IS 14724 / IS 10500).\n• coolerType / type: Standard type (Hot & Cold Dispenser, Storage Water Cooler, RO + UV Water Cooler, Wall Mounted Chiller, Other Water Coolers)\n• location / area: Area name (e.g. BF 1 Cast House, Electrical Workshop, Dispatch Area, Canteen, Admin HR)\n• make / brand: Manufacturer (e.g. Aquaguard, Voltas, Blue Star, Kent RO - Optional)\n• capacityLiters: Capacity (e.g. 40 L/hr, 150 L/hr, 200 L/hr, 300 L/hr - Optional)\n• seqNo: 3-digit sequence (e.g. 001, 002 - Optional, auto-generated if blank).\n* Plant & Unit are automatically linked from your selected scope. Tag ID is auto-generated!'
        };
      case 'high_mast_towers':
        return {
          'Cols': 'location, seqNo',
          'Note': 'High Mast Lighting Towers Registry (IS 875 / IS 2266 / CEA 2023).\n• location / area: Physical area name (e.g. BF 1 Sizer, BF 2 Sizer, Contractor Shed, Dispatch, Plant 5, Jayanti Yard, 27MTR Level, Plant 8)\n• seqNo: 3-digit sequence (e.g. 001, 002 - Optional, auto-generated if blank).\n* Plant & Unit are automatically linked from your selected scope. Tag ID is auto-generated as [Plant]-[Unit]-HMT-[seqNo]!'
        };
      case 'power_tools':
      case 'portable_tools':
        return {
          'Cols': 'tagId, equipmentType, owner, department, location, seqNo',
          'Note': 'Power Tools & Equipment Registry (IS/CEA Industrial Standard).\n• tagId: Tag ID / Document Key (e.g. PLANT-UNIT-WM-001, optional - auto-generated if left blank)\n• equipmentType / type: Standard equipment name (e.g. Welding Machine, Grinding Machine, Cutting Machine, Hand Drilling Machine, Pedestal Drill Machine, Extension Board, Mancooler, etc.)\n• owner / contractor: Owner or Vendor name (e.g. Vedanta, Monomark, V.Desai, Bhavana, Devika, Ishan Logistics)\n• department: Department (e.g. Electrical, Mechanical, Civil, Production, Instrumentation, HSE)\n• location: Area name (e.g. Cast House Floor Bay 1)\n• seqNo: 3-digit sequence number (e.g. 001, 002).'
        };
      default:
        return {
          'Cols': 'id, name, description',
          'Note': 'Ensure the First Row contains column headers matching the model fields.'
        };
    }
  }

  Future<void> _downloadTemplate() async {
    if (widget.collectionId == 'assets') {
      _showAssetTemplateModal();
      return;
    }

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
      // Rename default sheet
      String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
      excel.rename(defaultSheet, 'Template');
      Sheet templateSheet = excel['Template'];
      
      // Headers
      templateSheet.appendRow(cols.map((e) => TextCellValue(e)).toList());
      
      // Fetch pre-existing data from Firestore for the selected scope
      final querySnapshot = await FirebaseFirestore.instance
          .collection(widget.collectionId)
          .where('plantId', isEqualTo: _userPlantId)
          .where('unitId', isEqualTo: _userUnitId)
          .get();

      if (widget.collectionId == 'high_mast_towers') {
        for (final doc in querySnapshot.docs) {
          final data = doc.data();
          final row = [
            TextCellValue(data['location']?.toString() ?? ''),
            TextCellValue(data['seqNo']?.toString() ?? '001'),
          ];
          templateSheet.appendRow(row);
        }

        if (querySnapshot.docs.isEmpty) {
          final defaultTowers = [
            ['BF 1 Sizer', '001'],
            ['BF 2 Sizer', '002'],
            ['Contractor Shed', '003'],
            ['Dispatch', '004'],
            ['Plant 5', '005'],
            ['Jayanti Yard', '006'],
            ['27MTR Level', '007'],
            ['Plant 8', '008'],
          ];

          for (var row in defaultTowers) {
            templateSheet.appendRow(row.map((val) => TextCellValue(val)).toList());
          }
        }
      } else if (widget.collectionId == 'water_coolers') {
        for (final doc in querySnapshot.docs) {
          final data = doc.data();
          final row = [
            TextCellValue(data['coolerType']?.toString() ?? data['type']?.toString() ?? 'Hot & Cold Dispenser'),
            TextCellValue(data['location']?.toString() ?? ''),
            TextCellValue(data['make']?.toString() ?? 'Voltas'),
            TextCellValue(data['capacityLiters']?.toString() ?? '40 L/hr'),
            TextCellValue(data['seqNo']?.toString() ?? '001'),
          ];
          templateSheet.appendRow(row);
        }

        if (querySnapshot.docs.isEmpty) {
          templateSheet.appendRow([
            TextCellValue('Hot & Cold Dispenser'),
            TextCellValue('BF 1 Cast House'),
            TextCellValue('Aquaguard'),
            TextCellValue('40 L/hr'),
            TextCellValue('001'),
          ]);
          templateSheet.appendRow([
            TextCellValue('Hot & Cold Dispenser'),
            TextCellValue('Electrical Workshop'),
            TextCellValue('Aquaguard'),
            TextCellValue('40 L/hr'),
            TextCellValue('002'),
          ]);
          templateSheet.appendRow([
            TextCellValue('Storage Water Cooler'),
            TextCellValue('BF 2 Area (Unit No. 2)'),
            TextCellValue('Other'),
            TextCellValue('300 L/hr'),
            TextCellValue('001'),
          ]);
          templateSheet.appendRow([
            TextCellValue('Storage Water Cooler'),
            TextCellValue('Contractor Shed'),
            TextCellValue('Voltas'),
            TextCellValue('150 L/hr'),
            TextCellValue('002'),
          ]);
          templateSheet.appendRow([
            TextCellValue('RO + UV Water Cooler'),
            TextCellValue('Main Canteen Dining Hall'),
            TextCellValue('Aquaguard'),
            TextCellValue('50 L/hr'),
            TextCellValue('001'),
          ]);
        }
      } else if (widget.collectionId == 'power_tools' || widget.collectionId == 'portable_tools') {
        for (final doc in querySnapshot.docs) {
          final data = doc.data();
          final row = [
            TextCellValue(data['tagId']?.toString() ?? doc.id),
            TextCellValue(data['equipmentType']?.toString() ?? data['type']?.toString() ?? ''),
            TextCellValue(data['owner']?.toString() ?? data['contractorName']?.toString() ?? 'Vedanta'),
            TextCellValue(data['department']?.toString() ?? 'Electrical'),
            TextCellValue(data['location']?.toString() ?? ''),
            TextCellValue(data['seqNo']?.toString() ?? '001'),
          ];
          templateSheet.appendRow(row);
        }

        if (querySnapshot.docs.isEmpty) {
          templateSheet.appendRow([
            TextCellValue('$_userPlantId-$_userUnitId-WM-001'),
            TextCellValue('Welding Machine'),
            TextCellValue('Vedanta'),
            TextCellValue('Electrical'),
            TextCellValue('Cast House Floor Bay 1'),
            TextCellValue('001'),
          ]);
          templateSheet.appendRow([
            TextCellValue('$_userPlantId-$_userUnitId-GM-001'),
            TextCellValue('Grinding Machine'),
            TextCellValue('Monomark'),
            TextCellValue('Mechanical'),
            TextCellValue('Maintenance Workshop'),
            TextCellValue('001'),
          ]);
          templateSheet.appendRow([
            TextCellValue('$_userPlantId-$_userUnitId-HDM-001'),
            TextCellValue('Hand Drilling Machine'),
            TextCellValue('V.Desai'),
            TextCellValue('Civil'),
            TextCellValue('Project Area'),
            TextCellValue('001'),
          ]);
          templateSheet.appendRow([
            TextCellValue('$_userPlantId-$_userUnitId-EXT-001'),
            TextCellValue('Extension Board'),
            TextCellValue('Vedanta'),
            TextCellValue('Electrical'),
            TextCellValue('Cast House Bay 2'),
            TextCellValue('001'),
          ]);
        }
      } else if (widget.collectionId == 'assets') {
        for (final doc in querySnapshot.docs) {
          final data = doc.data();
          final row = [
            TextCellValue(data['type']?.toString() ?? 'motor'),
            TextCellValue(data['name']?.toString() ?? ''),
            TextCellValue(data['make']?.toString() ?? ''),
            TextCellValue(data['model']?.toString() ?? ''),
            TextCellValue(data['serialNo']?.toString() ?? ''),
            TextCellValue(data['powerKw']?.toString() ?? '75'),
            TextCellValue(data['voltage']?.toString() ?? '415'),
            TextCellValue(data['speedRpm']?.toString() ?? '1480'),
            TextCellValue(data['status']?.toString() ?? 'active'),
            TextCellValue(data['seqNo']?.toString() ?? '001'),
          ];
          templateSheet.appendRow(row);
        }

        if (querySnapshot.docs.isEmpty) {
          templateSheet.appendRow([
            TextCellValue('motor'),
            TextCellValue('BF 1 Sizer Drive Motor'),
            TextCellValue('ABB'),
            TextCellValue('M3BP 280SMB'),
            TextCellValue('SN-882310'),
            TextCellValue('75'),
            TextCellValue('415'),
            TextCellValue('1480'),
            TextCellValue('active'),
            TextCellValue('001'),
          ]);
          templateSheet.appendRow([
            TextCellValue('pump'),
            TextCellValue('Cooling Water Circulation Pump'),
            TextCellValue('Kirloskar'),
            TextCellValue('DB 100/26'),
            TextCellValue('SN-441920'),
            TextCellValue('45'),
            TextCellValue('415'),
            TextCellValue('2900'),
            TextCellValue('active'),
            TextCellValue('002'),
          ]);
          templateSheet.appendRow([
            TextCellValue('gearbox'),
            TextCellValue('Primary Sizer Speed Reducer Gearbox'),
            TextCellValue('Elecon'),
            TextCellValue('SNH-315'),
            TextCellValue('SN-129033'),
            TextCellValue('90'),
            TextCellValue('415'),
            TextCellValue('1500'),
            TextCellValue('active'),
            TextCellValue('003'),
          ]);
        }
      } else {
        for (final doc in querySnapshot.docs) {
          final data = doc.data();
          final List<CellValue> row = [];
          for (final col in cols) {
            final rawVal = col == 'id' ? doc.id : data[col];
            // Strip prefix from ID for user convenience
            var val = rawVal;
            if (col == 'id' || col == 'panelRoomId' || col == 'panelId' || col == 'locationId' || col == 'masterEquipmentId') {
              if (rawVal != null) {
                val = HierarchyService.stripPrefix(rawVal.toString(), _userPlantId!, _userUnitId!);
              }
            }
            if (val == null) {
              row.add(TextCellValue(''));
            } else if (val is num) {
              row.add(DoubleCellValue(val.toDouble()));
            } else {
              row.add(TextCellValue(val.toString()));
            }
          }
          templateSheet.appendRow(row);
        }
      }
      
      // Add reference options sheet
      Sheet refSheet = excel['Available Reference Options'];
      
      // Fetch and list relevant references
      if (widget.collectionId == 'high_mast_towers') {
        refSheet.appendRow([TextCellValue('HIGH MAST TOWER REFERENCE & SPECIFICATIONS')]);
        refSheet.appendRow([TextCellValue('Standard Height'), TextCellValue('Standard Luminaire Count'), TextCellValue('Typical Locations')]);

        final highMastRef = [
          ['16 Meters', '6 to 8 Fixtures', 'Contractor Shed Yard / Small Junction'],
          ['20 Meters', '8 to 12 Fixtures', 'Substation Yard / Parking Area'],
          ['25 Meters', '12 to 16 Fixtures', 'BF 1 / BF 2 Sizer / Plant 5 / 27MTR'],
          ['30 Meters', '16 to 24 Fixtures', 'Dispatch Loading Bay / Jayanti Scrap Yard'],
          ['35 Meters', '24 to 32 Fixtures', 'Main Raw Material Handling Yard'],
        ];

        for (var item in highMastRef) {
          refSheet.appendRow([TextCellValue(item[0]), TextCellValue(item[1]), TextCellValue(item[2])]);
        }
      } else if (widget.collectionId == 'water_coolers') {
        refSheet.appendRow([TextCellValue('AVAILABLE WATER COOLER TYPES & CATEGORIES')]);
        refSheet.appendRow([TextCellValue('Short Code'), TextCellValue('Dispenser / Cooler Type'), TextCellValue('Industrial Category')]);

        final coolerTypesRef = [
          ['HCD', 'Hot & Cold Dispenser', 'Dual-Temp Dispenser (Heating & Cooling)'],
          ['SWC', 'Storage Water Cooler', 'High-Capacity Bulk Storage Cooler'],
          ['ROUV', 'RO + UV Water Cooler', 'Multi-Stage Membrane & Sterilization'],
          ['CWC', 'Commercial SS Water Cooler', 'Industrial Heavy-Duty Floor Unit'],
          ['WMC', 'Wall Mounted Chiller', 'Compact Confined Space Drinking Station'],
          ['WC', 'Other Water Coolers', 'General Drinking Water Dispenser'],
        ];

        for (var item in coolerTypesRef) {
          refSheet.appendRow([TextCellValue(item[0]), TextCellValue(item[1]), TextCellValue(item[2])]);
        }

        refSheet.appendRow([TextCellValue('')]);
        refSheet.appendRow([TextCellValue('POPULAR MAKES / BRANDS')]);
        refSheet.appendRow([TextCellValue('Voltas'), TextCellValue('Blue Star'), TextCellValue('Eureka Forbes')]);
        refSheet.appendRow([TextCellValue('')]);
        refSheet.appendRow([TextCellValue('STANDARD CAPACITIES')]);
        refSheet.appendRow([TextCellValue('20 L/hr'), TextCellValue('40 L/hr'), TextCellValue('60 L/hr')]);
        refSheet.appendRow([TextCellValue('80 L/hr'), TextCellValue('150 L/hr'), TextCellValue('200 L/hr'), TextCellValue('300 L/hr')]);
      } else if (widget.collectionId == 'power_tools' || widget.collectionId == 'portable_tools') {
        refSheet.appendRow([TextCellValue('AVAILABLE 24 EQUIPMENT TYPES & FUNCTIONAL CLASSES')]);
        refSheet.appendRow([TextCellValue('Short Code'), TextCellValue('Equipment Type / Machine Name'), TextCellValue('Industrial Category')]);
        
        final powerToolsRef = [
          ['WM', 'Welding Machine', 'Class 1: Welding & High-Current'],
          ['PPM', 'Plate Polishing Machine', 'Class 1: Welding & High-Current'],
          ['GM', 'Grinding Machine', 'Class 2: High-Speed Abrasive & Cutting'],
          ['CM', 'Cutting Machine', 'Class 2: High-Speed Abrasive & Cutting'],
          ['PCM', 'Ply Cutter Machine', 'Class 2: High-Speed Abrasive & Cutting'],
          ['JSM', 'Jigsaw Machine', 'Class 2: High-Speed Abrasive & Cutting'],
          ['HDM', 'Hand Drilling Machine', 'Class 3: Drilling, Impact & Demolition'],
          ['PDM', 'Pedestal Drill Machine', 'Class 3: Drilling, Impact & Demolition'],
          ['MDM', 'Magnetic Drilling Machine', 'Class 3: Drilling, Impact & Demolition'],
          ['EB', 'Electrical Breaker', 'Class 3: Drilling, Impact & Demolition'],
          ['PF', 'Pedestal Fan', 'Class 4: Industrial Air Movers, Pumps & Agitators'],
          ['MC', 'Mancooler', 'Class 4: Industrial Air Movers, Pumps & Agitators'],
          ['FG', 'Fog Gun', 'Class 4: Industrial Air Movers, Pumps & Agitators'],
          ['HB', 'Hand Blower', 'Class 4: Industrial Air Movers, Pumps & Agitators'],
          ['MXM', 'Mixer Machine', 'Class 4: Industrial Air Movers, Pumps & Agitators'],
          ['HMX', 'Hand Mixer', 'Class 4: Industrial Air Movers, Pumps & Agitators'],
          ['JP', 'Jet Pump', 'Class 4: Industrial Air Movers, Pumps & Agitators'],
          ['VM', 'Vibrating Machine', 'Class 4: Industrial Air Movers, Pumps & Agitators'],
          ['FCM', 'Floor Cleaning Machine', 'Class 4: Industrial Air Movers, Pumps & Agitators'],
          ['PUG', 'Pug Machine', 'Class 4: Industrial Air Movers, Pumps & Agitators'],
          ['ELC', 'ELC Machine', 'Class 4: Industrial Air Movers, Pumps & Agitators'],
          ['EXT', 'Extension Board', 'Class 5: Portable Power Distribution & Temporary Lighting'],
          ['PL', 'Portable Light', 'Class 5: Portable Power Distribution & Temporary Lighting'],
          ['PLT', 'Portable Lighting Transformer', 'Class 5: Portable Power Distribution & Temporary Lighting'],
          ['OPT', 'Other Power Tools', 'Class 2: High-Speed Abrasive & Cutting'],
        ];

        for (var item in powerToolsRef) {
          refSheet.appendRow([TextCellValue(item[0]), TextCellValue(item[1]), TextCellValue(item[2])]);
        }

        refSheet.appendRow([TextCellValue('')]);
        refSheet.appendRow([TextCellValue('STANDARD CONTRACTORS / OWNERS')]);
        refSheet.appendRow([TextCellValue('Vedanta'), TextCellValue('Monomark'), TextCellValue('V.Desai')]);
        refSheet.appendRow([TextCellValue('Bhavana'), TextCellValue('Devika'), TextCellValue('Ishan Logistics')]);
        refSheet.appendRow([TextCellValue('Trupti'), TextCellValue('Surya Transport')]);

        refSheet.appendRow([TextCellValue('')]);
        refSheet.appendRow([TextCellValue('STANDARD DEPARTMENTS')]);
        refSheet.appendRow([TextCellValue('Electrical'), TextCellValue('Mechanical'), TextCellValue('Civil')]);
        refSheet.appendRow([TextCellValue('Production'), TextCellValue('Instrumentation'), TextCellValue('HSE')]);
      } else if (widget.collectionId == 'panels') {
        refSheet.appendRow([TextCellValue('AVAILABLE PANEL ROOMS (Copy clean IDs from here)')]);
        refSheet.appendRow([TextCellValue('Room ID (Raw)'), TextCellValue('Room ID (Prefixed)'), TextCellValue('Room Name')]);
        final snapshot = await FirebaseFirestore.instance
            .collection('panel_rooms')
            .where('plantId', isEqualTo: _userPlantId)
            .where('unitId', isEqualTo: _userUnitId)
            .get();
        for (final doc in snapshot.docs) {
          final rawId = HierarchyService.stripPrefix(doc.id, _userPlantId!, _userUnitId!);
          refSheet.appendRow([TextCellValue(rawId), TextCellValue(doc.id), TextCellValue(doc.data()['name'] ?? '')]);
        }
      } else if (widget.collectionId == 'feeders') {
        refSheet.appendRow([TextCellValue('AVAILABLE PANELS (Copy clean IDs from here)')]);
        refSheet.appendRow([TextCellValue('Panel ID (Raw)'), TextCellValue('Panel ID (Prefixed)'), TextCellValue('Panel Name')]);
        final snapshot = await FirebaseFirestore.instance
            .collection('panels')
            .where('plantId', isEqualTo: _userPlantId)
            .where('unitId', isEqualTo: _userUnitId)
            .get();
        for (final doc in snapshot.docs) {
          final rawId = HierarchyService.stripPrefix(doc.id, _userPlantId!, _userUnitId!);
          refSheet.appendRow([TextCellValue(rawId), TextCellValue(doc.id), TextCellValue(doc.data()['name'] ?? '')]);
        }
      } else if (widget.collectionId == 'master_equipments') {
        refSheet.appendRow([TextCellValue('AVAILABLE PHYSICAL AREAS (Copy Location IDs)')]);
        refSheet.appendRow([TextCellValue('Location ID (Raw)'), TextCellValue('Location ID (Prefixed)'), TextCellValue('Location Name')]);
        final snapshot = await FirebaseFirestore.instance
            .collection('locations')
            .where('plantId', isEqualTo: _userPlantId)
            .where('unitId', isEqualTo: _userUnitId)
            .get();
        for (final doc in snapshot.docs) {
          final rawId = HierarchyService.stripPrefix(doc.id, _userPlantId!, _userUnitId!);
          refSheet.appendRow([TextCellValue(rawId), TextCellValue(doc.id), TextCellValue(doc.data()['name'] ?? '')]);
        }
        refSheet.appendRow([TextCellValue('')]);
        refSheet.appendRow([TextCellValue('AVAILABLE PANEL ROOMS')]);
        refSheet.appendRow([TextCellValue('Room ID (Raw)'), TextCellValue('Room ID (Prefixed)'), TextCellValue('Room Name')]);
        final prSnapshot = await FirebaseFirestore.instance
            .collection('panel_rooms')
            .where('plantId', isEqualTo: _userPlantId)
            .where('unitId', isEqualTo: _userUnitId)
            .get();
        for (final doc in prSnapshot.docs) {
          final rawId = HierarchyService.stripPrefix(doc.id, _userPlantId!, _userUnitId!);
          refSheet.appendRow([TextCellValue(rawId), TextCellValue(doc.id), TextCellValue(doc.data()['name'] ?? '')]);
        }
      } else if (widget.collectionId == 'assets') {
        refSheet.appendRow([TextCellValue('AVAILABLE MASTER EQUIPMENTS')]);
        refSheet.appendRow([TextCellValue('Equipment Tag (Raw)'), TextCellValue('Equipment Tag (Prefixed)'), TextCellValue('Equipment Name')]);
        final snapshot = await FirebaseFirestore.instance
            .collection('master_equipments')
            .where('plantId', isEqualTo: _userPlantId)
            .where('unitId', isEqualTo: _userUnitId)
            .get();
        for (final doc in snapshot.docs) {
          final rawId = HierarchyService.stripPrefix(doc.id, _userPlantId!, _userUnitId!);
          refSheet.appendRow([TextCellValue(rawId), TextCellValue(doc.id), TextCellValue(doc.data()['name'] ?? '')]);
        }
      }
      
      final fileBytes = excel.save();
      if (fileBytes != null) {
        final savedPath = await downloadFile(fileBytes, '${widget.collectionId}_template.xlsx');
        if (mounted) {
          final message = savedPath != null
              ? 'Saved to: $savedPath'
              : 'Template generated for ${widget.title}!';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 6),
            ),
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

  Future<void> _downloadAssetTemplate([String type = 'all']) async {
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

      // 1. Motors Sheet
      if (type == 'all' || type == 'motor') {
        final sheetName = type == 'all' ? 'Motors' : 'Motor_Template';
        if (excel.sheets.containsKey(defaultSheet)) {
          excel.rename(defaultSheet, sheetName);
        }
        Sheet motorSheet = excel[sheetName];

        final motorCols = [
          'type', 'name', 'status', 'parentEquipment', 'compatibleSpares', 'spareLocation', 'isCritical',
          'powerKw', 'voltage', 'fullLoadCurrent', 'noLoadCurrent', 'speedRpm', 'frequency', 'poles',
          'frameSize', 'mountingType', 'efficiency', 'powerFactor', 'greaseType', 'bearingDE', 'bearingNDE',
          'make', 'model', 'serialNo', 'manufacturingYear', 'poNo', 'rfidTag', 'seqNo',
        ];
        motorSheet.appendRow(motorCols.map((e) => TextCellValue(e)).toList());

        // Sample Motor 1: Active
        motorSheet.appendRow([
          TextCellValue('motor'),
          TextCellValue('BF 1 Sizer Drive Motor'),
          TextCellValue('active'),
          TextCellValue('BF1-SIZER-01'),
          TextCellValue('BF1-SIZER-01; BF2-SIZER-01'),
          TextCellValue(''),
          TextCellValue('YES'),
          TextCellValue('75'),
          TextCellValue('415'),
          TextCellValue('130.5'),
          TextCellValue('38.0'),
          TextCellValue('1480'),
          TextCellValue('50'),
          TextCellValue('4'),
          TextCellValue('280M'),
          TextCellValue('B3 Foot Mounted'),
          TextCellValue('95.2'),
          TextCellValue('0.88'),
          TextCellValue('Mobilith SHC 100'),
          TextCellValue('6316 C3'),
          TextCellValue('6316 C3'),
          TextCellValue('ABB'),
          TextCellValue('M3BP 280SMB'),
          TextCellValue('SN-882310'),
          TextCellValue('2022'),
          TextCellValue('PO-450012'),
          TextCellValue('E28011700000020A'),
          TextCellValue('001'),
        ]);

        // Sample Motor 2: Spare
        motorSheet.appendRow([
          TextCellValue('motor'),
          TextCellValue('75kW Standby Spare Motor'),
          TextCellValue('spare'),
          TextCellValue(''),
          TextCellValue('BF1-SIZER-01; BF2-SIZER-01'),
          TextCellValue('Central Warehouse - Bay 3, Rack A2'),
          TextCellValue('YES'),
          TextCellValue('75'),
          TextCellValue('415'),
          TextCellValue('130.5'),
          TextCellValue('38.0'),
          TextCellValue('1480'),
          TextCellValue('50'),
          TextCellValue('4'),
          TextCellValue('280M'),
          TextCellValue('B3 Foot Mounted'),
          TextCellValue('95.2'),
          TextCellValue('0.88'),
          TextCellValue('Mobilith SHC 100'),
          TextCellValue('6316 C3'),
          TextCellValue('6316 C3'),
          TextCellValue('Siemens'),
          TextCellValue('1LE1001-1DB2'),
          TextCellValue('SN-994120'),
          TextCellValue('2023'),
          TextCellValue('PO-450088'),
          TextCellValue(''),
          TextCellValue('002'),
        ]);
      }

      // 2. Gearboxes Sheet
      if (type == 'all' || type == 'gearbox') {
        final sheetName = type == 'all' ? 'Gearboxes' : (type == 'gearbox' && !excel.sheets.containsKey('Gearbox_Template') ? 'Gearbox_Template' : 'Gearboxes');
        if (type == 'gearbox' && excel.sheets.containsKey(defaultSheet)) {
          excel.rename(defaultSheet, 'Gearbox_Template');
        }
        Sheet gbxSheet = excel[type == 'gearbox' ? 'Gearbox_Template' : sheetName];

        final gbxCols = [
          'type', 'name', 'status', 'parentEquipment', 'compatibleSpares', 'spareLocation', 'isCritical',
          'powerKw', 'gearRatio', 'inputSpeedRpm', 'outputSpeedRpm', 'oilType', 'oilCapacity',
          'inputShaftMm', 'outputShaftMm', 'lubricationMethod', 'mountingOrientation', 'bearingDE', 'bearingNDE',
          'make', 'model', 'serialNo', 'manufacturingYear', 'poNo', 'rfidTag', 'seqNo',
        ];
        gbxSheet.appendRow(gbxCols.map((e) => TextCellValue(e)).toList());

        // Sample Gearbox 1: Active
        gbxSheet.appendRow([
          TextCellValue('gearbox'),
          TextCellValue('Primary Sizer Speed Reducer Gearbox'),
          TextCellValue('active'),
          TextCellValue('BF1-SIZER-01'),
          TextCellValue('BF1-SIZER-01'),
          TextCellValue(''),
          TextCellValue('YES'),
          TextCellValue('90'),
          TextCellValue('25:1'),
          TextCellValue('1480'),
          TextCellValue('59.2'),
          TextCellValue('Mobilgear 600 XP 220'),
          TextCellValue('45.0'),
          TextCellValue('65'),
          TextCellValue('140'),
          TextCellValue('Splash Lubrication'),
          TextCellValue('Horizontal Foot Mounted'),
          TextCellValue('22218 EK'),
          TextCellValue('22216 EK'),
          TextCellValue('Elecon'),
          TextCellValue('SNH-315'),
          TextCellValue('SN-129033'),
          TextCellValue('2021'),
          TextCellValue('PO-450033'),
          TextCellValue('E28011700000030B'),
          TextCellValue('001'),
        ]);

        // Sample Gearbox 2: Spare
        gbxSheet.appendRow([
          TextCellValue('gearbox'),
          TextCellValue('SNH-315 Helical Gearbox Spare'),
          TextCellValue('spare'),
          TextCellValue(''),
          TextCellValue('BF1-SIZER-01; BF2-SIZER-01'),
          TextCellValue('Mechanical Yard - Bay 2'),
          TextCellValue('YES'),
          TextCellValue('90'),
          TextCellValue('25:1'),
          TextCellValue('1480'),
          TextCellValue('59.2'),
          TextCellValue('Mobilgear 600 XP 220'),
          TextCellValue('45.0'),
          TextCellValue('65'),
          TextCellValue('140'),
          TextCellValue('Splash Lubrication'),
          TextCellValue('Horizontal Foot Mounted'),
          TextCellValue('22218 EK'),
          TextCellValue('22216 EK'),
          TextCellValue('Radicon'),
          TextCellValue('PZ-250'),
          TextCellValue('SN-443912'),
          TextCellValue('2022'),
          TextCellValue('PO-450091'),
          TextCellValue(''),
          TextCellValue('002'),
        ]);
      }

      // 3. Pumps Sheet
      if (type == 'all' || type == 'pump') {
        final sheetName = type == 'all' ? 'Pumps' : (type == 'pump' && !excel.sheets.containsKey('Pump_Template') ? 'Pump_Template' : 'Pumps');
        if (type == 'pump' && excel.sheets.containsKey(defaultSheet)) {
          excel.rename(defaultSheet, 'Pump_Template');
        }
        Sheet pumpSheet = excel[type == 'pump' ? 'Pump_Template' : sheetName];

        final pumpCols = [
          'type', 'name', 'status', 'parentEquipment', 'compatibleSpares', 'spareLocation', 'isCritical',
          'flowRate', 'head', 'pumpSpeed', 'powerKw', 'impellerSize', 'suctionFlangeMm', 'dischargeFlangeMm',
          'sealType', 'casingMaterial', 'greaseType', 'bearingDE', 'bearingNDE',
          'make', 'model', 'serialNo', 'manufacturingYear', 'poNo', 'rfidTag', 'seqNo',
        ];
        pumpSheet.appendRow(pumpCols.map((e) => TextCellValue(e)).toList());

        // Sample Pump 1: Active
        pumpSheet.appendRow([
          TextCellValue('pump'),
          TextCellValue('Cooling Tower Circulation Pump 1'),
          TextCellValue('active'),
          TextCellValue('CT-PUMP-01'),
          TextCellValue('CT-PUMP-01; CT-PUMP-02'),
          TextCellValue(''),
          TextCellValue('YES'),
          TextCellValue('250'),
          TextCellValue('45.0'),
          TextCellValue('1450'),
          TextCellValue('45'),
          TextCellValue('260'),
          TextCellValue('150'),
          TextCellValue('100'),
          TextCellValue('Mechanical Seal (Cartridge)'),
          TextCellValue('Cast Iron FG 260'),
          TextCellValue('Servo Gem 3'),
          TextCellValue('6312 C3'),
          TextCellValue('6312 C3'),
          TextCellValue('Kirloskar'),
          TextCellValue('DB 100/26'),
          TextCellValue('SN-441920'),
          TextCellValue('2021'),
          TextCellValue('PO-450044'),
          TextCellValue('E28011700000040C'),
          TextCellValue('001'),
        ]);

        // Sample Pump 2: Spare
        pumpSheet.appendRow([
          TextCellValue('pump'),
          TextCellValue('DB 100/26 Bare Shaft Pump Spare'),
          TextCellValue('spare'),
          TextCellValue(''),
          TextCellValue('CT-PUMP-01; CT-PUMP-02'),
          TextCellValue('Pump Store - Rack C1'),
          TextCellValue('YES'),
          TextCellValue('250'),
          TextCellValue('45.0'),
          TextCellValue('1450'),
          TextCellValue('45'),
          TextCellValue('260'),
          TextCellValue('150'),
          TextCellValue('100'),
          TextCellValue('Mechanical Seal (Cartridge)'),
          TextCellValue('Cast Iron FG 260'),
          TextCellValue('Servo Gem 3'),
          TextCellValue('6312 C3'),
          TextCellValue('6312 C3'),
          TextCellValue('KSB'),
          TextCellValue('MegaCPK 080-050-200'),
          TextCellValue('SN-772189'),
          TextCellValue('2023'),
          TextCellValue('PO-450099'),
          TextCellValue(''),
          TextCellValue('002'),
        ]);
      }

      // 4. Reference Options Sheet
      Sheet refSheet = excel['Reference Guide'];
      refSheet.appendRow([TextCellValue('AVAILABLE MASTER EQUIPMENTS IN UNIT (Use in parentEquipment / compatibleSpares)')]);
      refSheet.appendRow([TextCellValue('Equipment Tag (Raw)'), TextCellValue('Full Tag ID'), TextCellValue('Equipment Name')]);
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

  void _showAssetTemplateModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
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
            const Text('Download tailored Excel templates with exact technical specification columns per asset classification:',
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
              title: const Text('All-in-One Master Workbook (3 Sheets)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Contains Motors, Gearboxes, Pumps tabs and Parent Equipment Reference Guide', style: TextStyle(fontSize: 11)),
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
    );
  }

  Future<List<Map<String, dynamic>>> _validateImportData(List<Map<String, dynamic>> rawData) async {
    if (_userPlantId == null || _userUnitId == null) return rawData;

    final List<Map<String, dynamic>> enriched = [];
    
    // Fetch all existing document IDs in this collection for duplicates check
    final snapshot = await FirebaseFirestore.instance
        .collection(widget.collectionId)
        .where('plantId', isEqualTo: _userPlantId)
        .where('unitId', isEqualTo: _userUnitId)
        .get();
        
    final Set<String> existingIds = snapshot.docs.map((d) => d.id.toUpperCase()).toSet();
    
    // Fetch parent lists to check reference validity
    Set<String> validParentIds = {};
    if (widget.collectionId == 'panels') {
      final parents = await FirebaseFirestore.instance
          .collection('panel_rooms')
          .where('plantId', isEqualTo: _userPlantId)
          .where('unitId', isEqualTo: _userUnitId)
          .get();
      validParentIds = parents.docs.map((d) => d.id.toUpperCase()).toSet();
    } else if (widget.collectionId == 'feeders') {
      final parents = await FirebaseFirestore.instance
          .collection('panels')
          .where('plantId', isEqualTo: _userPlantId)
          .where('unitId', isEqualTo: _userUnitId)
          .get();
      validParentIds = parents.docs.map((d) => d.id.toUpperCase()).toSet();
    } else if (widget.collectionId == 'master_equipments') {
      final parents = await FirebaseFirestore.instance
          .collection('locations')
          .where('plantId', isEqualTo: _userPlantId)
          .where('unitId', isEqualTo: _userUnitId)
          .get();
      validParentIds = parents.docs.map((d) => d.id.toUpperCase()).toSet();
    } else if (widget.collectionId == 'assets') {
      final parents = await FirebaseFirestore.instance
          .collection('master_equipments')
          .where('plantId', isEqualTo: _userPlantId)
          .where('unitId', isEqualTo: _userUnitId)
          .get();
      validParentIds = parents.docs.map((d) => d.id.toUpperCase()).toSet();
    }

    for (final rawRow in rawData) {
      final Map<String, dynamic> row = Map.from(rawRow);

      if (widget.collectionId == 'water_coolers') {
        final cType = row['coolerType']?.toString().trim() ??
                      row['type']?.toString().trim() ??
                      row['dispenserType']?.toString().trim() ?? '';
        final tagId = row['tagId']?.toString().trim() ?? row['id']?.toString().trim() ?? '';

        String status = 'OK';
        if (cType.isEmpty) {
          status = 'Error: coolerType (or type) is missing.';
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
          status = 'Error: equipmentType (or type) is missing.';
        } else if (tagId.isNotEmpty && existingIds.contains(tagId.toUpperCase())) {
          status = 'Warning: Tag ID "$tagId" exists. Will update existing.';
        }

        row['Validation'] = status;
        enriched.add(row);
        continue;
      }

      if (widget.collectionId == 'assets') {
        final name = row['name']?.toString().trim() ??
                     row['equipmentName']?.toString().trim() ??
                     row['assetName']?.toString().trim() ?? '';
        final rawType = row['type']?.toString().trim().toLowerCase() ?? 'motor';
        final typeStr = rawType.contains('gear') ? 'gearbox' : rawType.contains('pump') ? 'pump' : 'motor';
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
        
        final typeCode = typeStr == 'gearbox' ? 'GBX' : typeStr == 'pump' ? 'PMP' : 'MTR';
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
          // Soft check on parent equipment
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
        continue;
      }

      final rawId = row['id']?.toString().trim() ?? '';
      
      if (rawId.isEmpty) {
        row['Validation'] = 'Error: ID is missing';
        enriched.add(row);
        continue;
      }

      final fullId = HierarchyService.prefixId(rawId, _userPlantId!, _userUnitId!);
      
      String status = 'OK';
      
      // Check prefixing
      if (rawId.toUpperCase() != fullId.toUpperCase()) {
        status = 'Will auto-prefix to $fullId';
      }

      // Check existing database conflicts
      if (existingIds.contains(fullId.toUpperCase())) {
        status = 'Warning: ID exists. Will update existing.';
      }
      
      // Check parent references
      if (widget.collectionId == 'panels') {
        final prId = row['panelRoomId']?.toString().trim();
        if (prId != null && prId.isNotEmpty) {
          final fullPrId = HierarchyService.prefixId(prId, _userPlantId!, _userUnitId!);
          if (!validParentIds.contains(fullPrId.toUpperCase())) {
            status = 'Warning: Panel Room ID "$fullPrId" not found in unit.';
          }
        } else if (_selectedLocationId == null) {
          status = 'Error: Select Panel Room in header or specify in panelRoomId column.';
        }
      } else if (widget.collectionId == 'feeders') {
        final pId = row['panelId']?.toString().trim();
        if (pId != null && pId.isNotEmpty) {
          final fullPId = HierarchyService.prefixId(pId, _userPlantId!, _userUnitId!);
          if (!validParentIds.contains(fullPId.toUpperCase())) {
            status = 'Warning: Panel ID "$fullPId" not found in unit.';
          }
        } else if (_selectedPanelId == null) {
          status = 'Error: Select Panel in header or specify in panelId column.';
        }
      } else if (widget.collectionId == 'master_equipments') {
        final locId = row['locationId']?.toString().trim();
        if (locId != null && locId.isNotEmpty) {
          final fullLocId = HierarchyService.prefixId(locId, _userPlantId!, _userUnitId!);
          if (!validParentIds.contains(fullLocId.toUpperCase())) {
            status = 'Warning: Location ID "$fullLocId" not found.';
          }
        } else if (_selectedLocationId == null) {
          status = 'Error: Select Location in header or specify in locationId column.';
        }
      } else if (widget.collectionId == 'lighting_dbs') {
        final rccbVal = row['rccbCount'];
        final rccbStr = rccbVal?.toString().trim() ?? '';
        if (rccbStr.isEmpty) {
          status = 'Error: rccbCount is missing.';
        } else {
          // Excel numeric cells come as doubles (e.g. 1.0), so try both int and double
          final asInt = int.tryParse(rccbStr);
          final asDouble = double.tryParse(rccbStr);
          if (asInt == null && (asDouble == null || asDouble != asDouble.truncateToDouble())) {
            status = 'Error: rccbCount must be a whole number.';
          }
        }
      } else if (widget.collectionId == 'lux_locations') {
        final type = row['type']?.toString().trim() ?? '';
        if (type.isEmpty) {
          status = 'Error: type is missing.';
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

        final data = widget.collectionId == 'assets'
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
      final List<Map<String, dynamic>> finalData = _previewData.map((raw) {
        final Map<String, dynamic> data = Map.from(raw);
        
        // Remove Validation helper column so it doesn't get saved to database
        data.remove('Validation');
        
        // Auto-inject context
        data['unitId'] = _userUnitId;
        data['plantId'] = _userPlantId;
        
        // Ensure ID is prefixed for hierarchical entities
        if (data['id'] != null && widget.collectionId != 'power_tools' && widget.collectionId != 'portable_tools') {
          data['id'] = HierarchyService.prefixId(data['id'].toString(), _userPlantId!, _userUnitId!);
        }

        // Parent selections in header (if not specified in rows)
        if (widget.collectionId == 'panels') {
          if (data['panelRoomId'] == null || data['panelRoomId'].toString().isEmpty) {
            data['panelRoomId'] = _selectedLocationId;
          } else {
            data['panelRoomId'] = HierarchyService.prefixId(data['panelRoomId'].toString(), _userPlantId!, _userUnitId!);
          }
        } else if (widget.collectionId == 'feeders') {
          if (data['panelId'] == null || data['panelId'].toString().isEmpty) {
            data['panelId'] = _selectedPanelId;
          } else {
            data['panelId'] = HierarchyService.prefixId(data['panelId'].toString(), _userPlantId!, _userUnitId!);
          }
        } else if (widget.collectionId == 'master_equipments') {
          if (data['locationId'] == null || data['locationId'].toString().isEmpty) {
            data['locationId'] = _selectedLocationId;
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
        } else if (widget.collectionId == 'assets') {
          if (data['masterEquipmentId'] != null) {
            data['masterEquipmentId'] = HierarchyService.prefixId(data['masterEquipmentId'].toString(), _userPlantId!, _userUnitId!);
          }
        } else if (widget.collectionId == 'lighting_dbs') {
          // Convert rccbCount from Excel double (e.g. 1.0) to clean int
          final rccbRaw = data['rccbCount'];
          if (rccbRaw != null) {
            final parsed = double.tryParse(rccbRaw.toString());
            if (parsed != null) data['rccbCount'] = parsed.toInt();
          }
          // Remove businessId if it sneaked in
          data.remove('businessId');
        } else if (widget.collectionId == 'lux_locations') {
          data['plantId'] = _userPlantId!;
          data['unitId'] = _userUnitId!;
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
          data['plantId'] = _userPlantId!;
          data['unitId'] = _userUnitId!;

          final locStr = data['location']?.toString().trim() ??
                         data['area']?.toString().trim() ??
                         data['areaName']?.toString().trim() ??
                         data['towerName']?.toString().trim() ??
                         data['name']?.toString().trim() ??
                         'Plant Yard';

          final seqStr = data['seqNo']?.toString().trim() ??
                         data['seq']?.toString().trim() ??
                         '001';

          final rawTagId = data['tagId']?.toString().trim() ?? data['id']?.toString().trim() ?? '';
          final finalTagId = rawTagId.isNotEmpty
              ? rawTagId
              : '${_userPlantId!}-${_userUnitId!}-HMT-${seqStr.padLeft(3, '0')}';

          data['id'] = finalTagId;
          data['tagId'] = finalTagId;
          data['location'] = locStr;
          data['seqNo'] = seqStr.padLeft(3, '0');
          data['status'] = data['status']?.toString().isNotEmpty == true ? data['status'] : 'Never Tested';
          data['createdAt'] = data['createdAt'] ?? DateTime.now().toIso8601String();
          data['updatedAt'] = DateTime.now().toIso8601String();
        } else if (widget.collectionId == 'water_coolers') {
          data['plantId'] = _userPlantId!;
          data['unitId'] = _userUnitId!;

          final cTypeStr = data['coolerType']?.toString().trim() ??
                           data['type']?.toString().trim() ??
                           data['dispenserType']?.toString().trim() ??
                           'Hot & Cold Dispenser';

          final makeStr = data['make']?.toString().trim() ??
                          data['brand']?.toString().trim() ??
                          'Voltas';

          final capStr = data['capacityLiters']?.toString().trim() ??
                         data['capacity']?.toString().trim() ??
                         '40 L/hr';

          final ownerStr = data['owner']?.toString().trim() ??
                           data['vendorName']?.toString().trim() ??
                           data['contractor']?.toString().trim() ??
                           'Vedanta';

          final deptStr = data['department']?.toString().trim() ??
                          data['dept']?.toString().trim() ??
                          'Administration';

          final locStr = data['location']?.toString().trim() ??
                         data['area']?.toString().trim() ??
                         data['areaName']?.toString().trim() ??
                         'Pantry';

          final seqStr = data['seqNo']?.toString().trim() ??
                         data['seq']?.toString().trim() ??
                         '001';

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
          final finalTagId = rawTagId.isNotEmpty
              ? rawTagId
              : '${_userPlantId!}-${_userUnitId!}-$code-${seqStr.padLeft(3, '0')}';

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
          data['plantId'] = _userPlantId!;
          data['unitId'] = _userUnitId!;

          final eqTypeStr = data['equipmentType']?.toString().trim() ??
                            data['type']?.toString().trim() ??
                            data['equipment_type']?.toString().trim() ??
                            data['machineType']?.toString().trim() ??
                            'Other Power Tools';

          final ownerStr = data['owner']?.toString().trim() ??
                           data['contractor']?.toString().trim() ??
                           data['contractorName']?.toString().trim() ??
                           data['company']?.toString().trim() ??
                           'Vedanta';

          final deptStr = data['department']?.toString().trim() ??
                          data['dept']?.toString().trim() ??
                          'Electrical';

          final locStr = data['location']?.toString().trim() ??
                         data['area']?.toString().trim() ??
                         data['areaName']?.toString().trim() ??
                         'Plant Floor';

          final seqStr = data['seqNo']?.toString().trim() ??
                         data['seq']?.toString().trim() ??
                         data['sequence']?.toString().trim() ??
                         '001';

          final eqCodeMap = {
            'Welding Machine': 'WM',
            'Plate Polishing Machine': 'PPM',
            'Grinding Machine': 'GM',
            'Cutting Machine': 'CM',
            'Ply Cutter Machine': 'PCM',
            'Jigsaw Machine': 'JSM',
            'Hand Drilling Machine': 'HDM',
            'Pedestal Drill Machine': 'PDM',
            'Magnetic Drilling Machine': 'MDM',
            'Electrical Breaker': 'EB',
            'Hand Blower': 'HB',
            'Extension Board': 'EXT',
            'Floor Cleaning Machine': 'FCM',
            'Mixer Machine': 'MXM',
            'Hand Mixer': 'HMX',
            'Fog Gun': 'FG',
            'Pug Machine': 'PUG',
            'Vibrating Machine': 'VM',
            'Pedestal Fan': 'PF',
            'Portable Light': 'PL',
            'Portable Lighting Transformer': 'PLT',
            'ELC Machine': 'ELC',
            'Mancooler': 'MC',
            'Jet Pump': 'JP',
            'Other Power Tools': 'OPT',
          };
          final eqCode = eqCodeMap[eqTypeStr] ?? 'TL';

          final rawTagId = data['tagId']?.toString().trim() ?? data['id']?.toString().trim() ?? '';
          final finalTagId = rawTagId.isNotEmpty
              ? rawTagId
              : '${_userPlantId!}-${_userUnitId!}-$eqCode-${seqStr.padLeft(3, '0')}';

          data['id'] = finalTagId;
          data['tagId'] = finalTagId;
          data['equipmentType'] = eqTypeStr;
          data['type'] = eqTypeStr;
          data['owner'] = ownerStr;
          data['contractorName'] = ownerStr;
          data['department'] = deptStr;
          data['location'] = locStr;
          data['seqNo'] = seqStr.padLeft(3, '0');
          data['status'] = data['status']?.toString().isNotEmpty == true ? data['status'] : 'Never Tested';
          data['createdAt'] = data['createdAt'] ?? DateTime.now().toIso8601String();
          data['updatedAt'] = DateTime.now().toIso8601String();
        } else if (widget.collectionId == 'assets') {
          final rawType = data['type']?.toString().trim().toLowerCase() ?? 'motor';
          final typeStr = rawType.contains('gear') ? 'gearbox' : rawType.contains('pump') ? 'pump' : 'motor';
          final nameStr = data['name']?.toString().trim() ?? 'Equipment Asset';
          final makeStr = data['make']?.toString().trim() ?? '';
          final modelStr = data['model']?.toString().trim() ?? '';
          final serialStr = data['serialNo']?.toString().trim() ?? '';
          final rawStatus = data['status']?.toString().trim().toLowerCase() ?? 'active';
          final statusStr = rawStatus.contains('spare')
              ? 'spare'
              : rawStatus.contains('maint')
                  ? 'underMaintenance'
                  : rawStatus.contains('scrap')
                      ? 'scrapped'
                      : 'active';

          final seqStr = data['seqNo']?.toString().trim() ??
                         data['seq']?.toString().trim() ??
                         '001';

          final typeCode = typeStr == 'gearbox' ? 'GBX' : typeStr == 'pump' ? 'PMP' : 'MTR';
          final rawTagId = data['tagNo']?.toString().trim() ?? data['tagId']?.toString().trim() ?? data['id']?.toString().trim() ?? '';
          final finalTagId = rawTagId.isNotEmpty
              ? rawTagId
              : '${_userPlantId!}-${_userUnitId!}-$typeCode-${seqStr.padLeft(3, '0')}';

          // Parse Parent Equipment & Compatible Spares list
          final parentRaw = data['parentEquipment']?.toString().trim() ??
                            data['masterEquipmentId']?.toString().trim() ??
                            data['installedMachine']?.toString().trim() ??
                            '';
          final fullParentId = parentRaw.isNotEmpty
              ? HierarchyService.prefixId(parentRaw, _userPlantId!, _userUnitId!)
              : '';

          final rawSpares = data['compatibleSpares']?.toString().trim() ??
                            data['applicableParentEquipmentIds']?.toString().trim() ??
                            '';
          final List<String> applicableParents = [];
          if (rawSpares.isNotEmpty) {
            final parts = rawSpares.split(RegExp(r'[,;]'));
            for (var p in parts) {
              final trimmed = p.trim();
              if (trimmed.isNotEmpty) {
                applicableParents.add(HierarchyService.prefixId(trimmed, _userPlantId!, _userUnitId!));
              }
            }
          }
          if (fullParentId.isNotEmpty && !applicableParents.contains(fullParentId)) {
            applicableParents.add(fullParentId);
          }

          final isCriticalVal = data['isCritical']?.toString().trim().toLowerCase();
          final bool isCritical = isCriticalVal == 'true' || isCriticalVal == 'yes' || isCriticalVal == '1';

          data['id'] = finalTagId;
          data['tagNo'] = finalTagId;
          data['name'] = nameStr;
          data['type'] = typeStr;
          data['status'] = statusStr;
          data['masterEquipmentId'] = fullParentId;
          data['applicableParentEquipmentIds'] = applicableParents;
          data['spareLocation'] = data['spareLocation']?.toString().trim() ?? data['location']?.toString().trim() ?? '';
          data['isCritical'] = isCritical;
          data['make'] = makeStr;
          data['model'] = modelStr;
          data['serialNo'] = serialStr;
          data['manufacturingYear'] = int.tryParse(data['manufacturingYear']?.toString() ?? '');
          data['poNo'] = data['poNo']?.toString().trim() ?? '';
          data['rfidTag'] = data['rfidTag']?.toString().trim() ?? '';
          data['seqNo'] = seqStr.padLeft(3, '0');
          data['powerKw'] = double.tryParse(data['powerKw']?.toString() ?? '');
          data['voltage'] = double.tryParse(data['voltage']?.toString() ?? '');
          data['speedRpm'] = double.tryParse(data['speedRpm']?.toString() ?? '');

          // Motor Specific Fields
          data['fullLoadCurrent'] = double.tryParse(data['fullLoadCurrent']?.toString() ?? data['flc']?.toString() ?? '');
          data['noLoadCurrent'] = double.tryParse(data['noLoadCurrent']?.toString() ?? '');
          data['frequency'] = double.tryParse(data['frequency']?.toString() ?? '');
          data['poles'] = int.tryParse(data['poles']?.toString() ?? '');
          data['frameSize'] = data['frameSize']?.toString().trim() ?? '';
          data['mountingType'] = data['mountingType']?.toString().trim() ?? '';
          data['efficiency'] = double.tryParse(data['efficiency']?.toString() ?? '');
          data['powerFactor'] = double.tryParse(data['powerFactor']?.toString() ?? '');

          // Common Lubrication & Bearings
          data['greaseType'] = data['greaseType']?.toString().trim() ?? '';
          data['bearingDE'] = data['bearingDE']?.toString().trim() ?? '';
          data['bearingNDE'] = data['bearingNDE']?.toString().trim() ?? '';

          // Gearbox Specific Fields
          data['gearRatio'] = data['gearRatio']?.toString().trim() ?? '';
          data['oilType'] = data['oilType']?.toString().trim() ?? '';
          data['oilCapacity'] = double.tryParse(data['oilCapacity']?.toString() ?? '');
          data['inputSpeedRpm'] = double.tryParse(data['inputSpeedRpm']?.toString() ?? '');
          data['outputSpeedRpm'] = double.tryParse(data['outputSpeedRpm']?.toString() ?? '');
          data['inputShaftMm'] = double.tryParse(data['inputShaftMm']?.toString() ?? '');
          data['outputShaftMm'] = double.tryParse(data['outputShaftMm']?.toString() ?? '');
          data['lubricationMethod'] = data['lubricationMethod']?.toString().trim() ?? '';
          data['mountingOrientation'] = data['mountingOrientation']?.toString().trim() ?? '';

          // Pump Specific Fields
          data['flowRate'] = double.tryParse(data['flowRate']?.toString() ?? '');
          data['head'] = double.tryParse(data['head']?.toString() ?? '');
          data['pumpSpeed'] = double.tryParse(data['pumpSpeed']?.toString() ?? '');
          data['impellerSize'] = double.tryParse(data['impellerSize']?.toString() ?? '');
          data['suctionFlangeMm'] = double.tryParse(data['suctionFlangeMm']?.toString() ?? '');
          data['dischargeFlangeMm'] = double.tryParse(data['dischargeFlangeMm']?.toString() ?? '');
          data['sealType'] = data['sealType']?.toString().trim() ?? '';
          data['casingMaterial'] = data['casingMaterial']?.toString().trim() ?? '';

          data['createdAt'] = data['createdAt'] ?? DateTime.now().toIso8601String();
          data['updatedAt'] = DateTime.now().toIso8601String();
        }
        
        return data;
      }).toList();

      await _firestoreService.batchSave(widget.collectionId, finalData);

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = "Success! Uploaded ${finalData.length} items.";
          _previewData.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Import Successful')));
      }
    } catch (e) {
      debugPrint('Upload Error: $e');
      if (mounted) {
        setState(() {
          _statusMessage = "Upload failed: $e";
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 8),
          ),
        );
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
            // 1. SCOPE HEADER (Standardized)
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
                        _buildScopeChip(
                          label: 'Plant',
                          value: _userPlantId ?? '...',
                          icon: Icons.factory,
                        ),
                        const SizedBox(width: 8),
                        _buildScopeChip(
                          label: 'Unit',
                          value: _userUnitId ?? '...',
                          icon: Icons.settings_input_component,
                        ),
                        
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
                                  label: Text(widget.collectionId == 'assets' ? 'Template Options' : 'Template', style: const TextStyle(fontSize: 12)),
                                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                ),
                              ],
                            ),
                            if (widget.collectionId == 'assets') ...[
                              const SizedBox(height: 8),
                              const Text('Download Specific Template by Asset Type:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ActionChip(
                                    avatar: const Icon(Icons.bolt, color: Colors.amberAccent, size: 16),
                                    label: const Text('Motors Template', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    backgroundColor: Colors.amber.withValues(alpha: 0.15),
                                    side: const BorderSide(color: Colors.amberAccent),
                                    onPressed: () => _downloadAssetTemplate('motor'),
                                  ),
                                  ActionChip(
                                    avatar: const Icon(Icons.settings, color: Colors.orangeAccent, size: 16),
                                    label: const Text('Gearboxes Template', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    backgroundColor: Colors.orange.withValues(alpha: 0.15),
                                    side: const BorderSide(color: Colors.orangeAccent),
                                    onPressed: () => _downloadAssetTemplate('gearbox'),
                                  ),
                                  ActionChip(
                                    avatar: const Icon(Icons.water_drop, color: Colors.blueAccent, size: 16),
                                    label: const Text('Pumps Template', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    backgroundColor: Colors.blue.withValues(alpha: 0.15),
                                    side: const BorderSide(color: Colors.blueAccent),
                                    onPressed: () => _downloadAssetTemplate('pump'),
                                  ),
                                  ActionChip(
                                    avatar: const Icon(Icons.table_chart, color: Colors.greenAccent, size: 16),
                                    label: const Text('All-in-One (3 Sheets)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    backgroundColor: Colors.green.withValues(alpha: 0.15),
                                    side: const BorderSide(color: Colors.greenAccent),
                                    onPressed: () => _downloadAssetTemplate('all'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],
                            const SizedBox(height: 4),
                            Text(widget.collectionId == 'assets' ? "Template Guidelines:" : "Required Columns:", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                            Text(instructions['Cols']!, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                            const SizedBox(height: 12),
                            Text("Pro Tip:", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary)),
                            Text(instructions['Note']!, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 3. FILE PICKER
                    if (_previewData.isEmpty)
                      GestureDetector(
                        onTap: _pickFile,
                        child: GlassContainer(
                          height: 150,
                          borderRadius: 20,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.upload_file, size: 48, color: _userUnitId == null ? Colors.grey : AppColors.primary),
                              const SizedBox(height: 16),
                              Text(
                                _fileName ?? (_userUnitId == null ? "Assign Unit first" : "Upload XLSX File"), 
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                    const SizedBox(height: 16),
                    if (_statusMessage != null)
                      Text(_statusMessage!, style: TextStyle(color: _statusMessage!.contains('Error') ? Colors.red : AppColors.primary), textAlign: TextAlign.center),

                    // 4. PREVIEW TABLE
                    if (_previewData.isNotEmpty) ...[ 
                        Material(
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
                                columns: _previewData.first.keys.map((k) => DataColumn(
                                  label: Text(
                                    k, 
                                    style: TextStyle(
                                      fontSize: 12, 
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    )
                                  )
                                )).toList(),
                                rows: _previewData.take(50).map((r) {
                                  return DataRow(
                                    cells: r.entries.map((e) {
                                      final val = e.value?.toString() ?? '';
                                      final isValidation = e.key == 'Validation';
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
                                          )
                                        )
                                      );
                                    }).toList()
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
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
