import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/widgets/pulse_loading.dart';
import '../../../../core/utils/permission_helper.dart';
import '../../data/models/asset_model.dart';
import '../../data/models/master_equipment_model.dart';
import '../../../../core/services/health_service.dart'; // NEW
import '../../../../core/services/hierarchy_service.dart';

class AddEditAssetPage extends StatefulWidget {
  final AssetModel? asset;
  final String? unitId;  // Required if creating new
  final String? plantId; // Required if creating new

  const AddEditAssetPage({super.key, this.asset, this.unitId, this.plantId});

  @override
  State<AddEditAssetPage> createState() => _AddEditAssetPageState();
}

class _AddEditAssetPageState extends State<AddEditAssetPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;
  bool _isLoading = false;
  
  List<MasterEquipmentModel> _masterEquipments = [];
  String? _selectedParentId;

  String _userRole = '';
  bool _isAdmin = false;
  String? _userPlantId;
  String? _userUnitId;

  // --- Controllers ---
  // Identity
  final _tagController = TextEditingController();
  final _nameController = TextEditingController();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _serialController = TextEditingController();
  final _poController = TextEditingController(); // NEW
  final _yearController = TextEditingController();
  final _imageController = TextEditingController();
  final _descController = TextEditingController(); // NEW
  final _rfidController = TextEditingController(); // NEW

  // Specs
  final _powerController = TextEditingController();
  final _voltageController = TextEditingController();
  final _currentController = TextEditingController(); // FLA
  final _speedController = TextEditingController();
  final _frequencyController = TextEditingController(); // NEW
  final _noLoadCurrentController = TextEditingController(); // NEW
  final _frameController = TextEditingController();
  final _mountingController = TextEditingController(); // NEW
  final _polesController = TextEditingController();
  final _pfController = TextEditingController(); // NEW
  final _efficiencyController = TextEditingController(); // NEW
  
  // Gearbox Specs
  final _gearRatioController = TextEditingController();
  final _oilTypeController = TextEditingController();
  final _oilCapacityController = TextEditingController(); // NEW
  
  // Pump Specs
  final _flowRateController = TextEditingController();
  final _headController = TextEditingController();
  final _impellerSizeController = TextEditingController();
  final _pumpPowerController = TextEditingController(); // NEW
  final _greaseTypeController = TextEditingController(); // NEW

  // Common Motor/Electrical Types
  final _bearingDEController = TextEditingController();
  final _bearingNDEController = TextEditingController();

  // Health (Maps)
  final _resRYController = TextEditingController();
  final _resYBController = TextEditingController();
  final _resRBController = TextEditingController();
  
  // IR Phase-Phase
  final _irRyController = TextEditingController();
  final _irYbController = TextEditingController();
  final _irBrController = TextEditingController();
  // IR Phase-Earth
  final _irReController = TextEditingController();
  final _irYeController = TextEditingController();
  final _irBeController = TextEditingController();
  
  final _piController = TextEditingController();

  // Vibration
  final _vibDeHController = TextEditingController();
  final _vibDeVController = TextEditingController();
  final _vibDeAController = TextEditingController();
  final _vibNdeHController = TextEditingController();
  final _vibNdeVController = TextEditingController();
  final _vibNdeAController = TextEditingController();
  final _vibGController = TextEditingController();

  // Context
  AssetStatus _selectedStatus = AssetStatus.active;
  AssetType _selectedType = AssetType.motor;


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    _loadUserProfile();
    _loadMasterData();

    if (widget.asset != null) {
      _populateControllers();
    }
  }

  Future<void> _loadUserProfile() async {
    final user = AuthService().currentUser;
    if (user != null) {
      final profile = await FirestoreService().getUserProfile(user.uid);
      if (profile != null) {
        if (mounted) {
          setState(() {
            _userRole = profile['role'] ?? 'Guest';
            _isAdmin = profile['isAdmin'] == true;
            _userPlantId = profile['plantId'] as String?;
            _userUnitId = profile['unitId'] as String?;
          });
        }
      }
    }
  }

  Future<void> _loadMasterData() async {
    // Load all master equipments for the given unit/plant context (if provided)
    // or load for editing context using the asset's parent
    final uid = widget.unitId;
    final pid = widget.plantId;

    if (uid != null && pid != null) {
      FirestoreService().getMasterEquipmentsStream(uid, pid).listen((items) {
        if (mounted) {
          setState(() {
            _masterEquipments = items;
          });
        }
      });
    } else {
      // No context- load all (Developer mode)
      FirestoreService().getAllMasterEquipmentsStream(null, null).listen((items) {
        if (mounted) {
          setState(() {
            _masterEquipments = items;
          });
        }
      });
    }
  }

  void _populateControllers() {
    final a = widget.asset!;
    _tagController.text = a.tagNo;
    _nameController.text = a.name;
    _descController.text = a.description; 
    _makeController.text = a.make;
    _modelController.text = a.model;
    _serialController.text = a.serialNo;
    _poController.text = a.poNo ?? ''; // NEW
    _yearController.text = a.manufacturingYear?.toString() ?? '';
    _imageController.text = a.imageUrl;
    _rfidController.text = a.rfidTag ?? ''; 
    
    _powerController.text = a.powerKw?.toString() ?? '';
    _voltageController.text = a.voltage?.toString() ?? '';
    _currentController.text = a.fullLoadCurrent?.toString() ?? '';
    _frequencyController.text = a.frequency?.toString() ?? ''; 
    _noLoadCurrentController.text = a.noLoadCurrent?.toString() ?? ''; 
    _speedController.text = a.speedRpm?.toString() ?? '';
    _frameController.text = a.frameSize ?? '';
    _mountingController.text = a.mountingType ?? '';
    _polesController.text = a.poles?.toString() ?? '';
    _pfController.text = a.powerFactor?.toString() ?? '';
    _efficiencyController.text = a.efficiency?.toString() ?? '';
    _bearingDEController.text = a.bearingDE ?? '';
    _bearingNDEController.text = a.bearingNDE ?? '';

    // Load Dynamic Specs
    if (a.specs != null) {
      _gearRatioController.text = a.specs!['gearRatio']?.toString() ?? '';
      _oilTypeController.text = a.specs!['oilType']?.toString() ?? '';
      _oilCapacityController.text = a.specs!['oilCapacity']?.toString() ?? ''; // NEW
      _flowRateController.text = a.specs!['flowRate']?.toString() ?? '';
      _headController.text = a.specs!['head']?.toString() ?? '';
      _impellerSizeController.text = a.specs!['impellerSize']?.toString() ?? '';
      _pumpPowerController.text = a.specs!['pumpPower']?.toString() ?? ''; // NEW
      _greaseTypeController.text = a.specs!['greaseType']?.toString() ?? ''; // NEW
    }

    // Resistance Maps
    if (a.windingResistance != null) {
      _resRYController.text = a.windingResistance!['R-Y']?.toString() ?? '';
      _resYBController.text = a.windingResistance!['Y-B']?.toString() ?? '';
      _resRBController.text = a.windingResistance!['R-B']?.toString() ?? '';
    }

    // Extended IR
    if (a.insulationResistance != null) {
        _irRyController.text = a.insulationResistance!['R-Y']?.toString() ?? '';
        _irYbController.text = a.insulationResistance!['Y-B']?.toString() ?? '';
        _irBrController.text = a.insulationResistance!['B-R']?.toString() ?? '';
        _irReController.text = a.insulationResistance!['R-E']?.toString() ?? '';
        _irYeController.text = a.insulationResistance!['Y-E']?.toString() ?? '';
        _irBeController.text = a.insulationResistance!['B-E']?.toString() ?? '';
    }
    
    _piController.text = a.polarizationIndex?.toString() ?? '';

    // Vibration
    if (a.vibration != null) {
      _vibDeHController.text = a.vibration!['DE_H']?.toString() ?? '';
      _vibDeVController.text = a.vibration!['DE_V']?.toString() ?? '';
      _vibDeAController.text = a.vibration!['DE_A']?.toString() ?? '';
      _vibNdeHController.text = a.vibration!['NDE_H']?.toString() ?? '';
      _vibNdeVController.text = a.vibration!['NDE_V']?.toString() ?? '';
      _vibNdeAController.text = a.vibration!['NDE_A']?.toString() ?? '';
      _vibGController.text = a.vibration!['G_Value']?.toString() ?? '';
    }

    _selectedStatus = a.status;
    _selectedType = a.type;
    _selectedParentId = a.masterEquipmentId; // Use masterEquipmentId now
    // Parent Name will be set when list loads
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tagController.dispose(); _nameController.dispose(); _makeController.dispose();
    _modelController.dispose(); _serialController.dispose(); _yearController.dispose();
    _imageController.dispose(); _powerController.dispose(); _voltageController.dispose();
    _currentController.dispose(); _speedController.dispose(); _frameController.dispose();
    _frequencyController.dispose(); _noLoadCurrentController.dispose(); _rfidController.dispose(); 
    _poController.dispose(); _greaseTypeController.dispose(); // NEW
    _oilCapacityController.dispose(); _pumpPowerController.dispose(); // NEW
    _mountingController.dispose(); _polesController.dispose(); 
    _pfController.dispose(); _efficiencyController.dispose();
    _bearingDEController.dispose(); _bearingNDEController.dispose();
    _resRYController.dispose(); _resYBController.dispose(); _resRBController.dispose();
    
    _irRyController.dispose(); _irYbController.dispose(); _irBrController.dispose();
    _irReController.dispose(); _irYeController.dispose(); _irBeController.dispose();
    _piController.dispose();
    
    _vibDeHController.dispose(); _vibDeVController.dispose(); _vibDeAController.dispose();
    _vibNdeHController.dispose(); _vibNdeVController.dispose(); _vibNdeAController.dispose();
    _vibGController.dispose();
    
    _gearRatioController.dispose(); _oilTypeController.dispose();
    _flowRateController.dispose(); _headController.dispose(); _impellerSizeController.dispose();

    super.dispose();
  }

  Future<void> _saveAsset() async {
    if (!_formKey.currentState!.validate()) return;
    final parentId = widget.asset != null ? widget.asset!.masterEquipmentId : _selectedParentId;
    if (parentId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Please select a Parent Equipment.")));
        return;
    }

    setState(() => _isLoading = true);

    try {
      final parent = _masterEquipments.firstWhere(
        (e) => e.id == parentId,
        orElse: () => throw Exception("Parent equipment not found."),
      );
      final itemPlantId = parent.plantId;
      final itemUnitId = parent.unitId;

      final canEdit = PermissionHelper.canEditDatabaseItem(
        userRole: _userRole,
        isAdmin: _isAdmin,
        userPlantId: _userPlantId,
        userUnitId: _userUnitId,
        itemPlantId: itemPlantId,
        itemUnitId: itemUnitId,
      );

      if (!canEdit) {
        throw Exception("You do not have permission to modify database items in this scope.");
      }
      // Build Specs Map
      final specsMap = <String, dynamic>{};
      if (_gearRatioController.text.isNotEmpty) specsMap['gearRatio'] = double.tryParse(_gearRatioController.text) ?? _gearRatioController.text;
      if (_oilTypeController.text.isNotEmpty) specsMap['oilType'] = _oilTypeController.text;
      if (_oilCapacityController.text.isNotEmpty) specsMap['oilCapacity'] = double.tryParse(_oilCapacityController.text) ?? _oilCapacityController.text;
      if (_flowRateController.text.isNotEmpty) specsMap['flowRate'] = double.tryParse(_flowRateController.text);
      if (_headController.text.isNotEmpty) specsMap['head'] = double.tryParse(_headController.text);
      if (_impellerSizeController.text.isNotEmpty) specsMap['impellerSize'] = double.tryParse(_impellerSizeController.text);
      if (_pumpPowerController.text.isNotEmpty) specsMap['pumpPower'] = double.tryParse(_pumpPowerController.text);
      if (_greaseTypeController.text.isNotEmpty) specsMap['greaseType'] = _greaseTypeController.text;

      // 1. Create Temporary Asset to calculate health
      final tempAsset = AssetModel(
        id: widget.asset?.id ?? 'new',
        masterEquipmentId: parentId,
        tagNo: _tagController.text,
        name: _nameController.text,
        description: _descController.text,
        make: _makeController.text,
        model: _modelController.text,
        serialNo: _serialController.text,
        poNo: _poController.text.isNotEmpty ? _poController.text : null, // NEW
        manufacturingYear: int.tryParse(_yearController.text),
        imageUrl: _imageController.text.isEmpty 
            ? 'https://images.unsplash.com/photo-1581092918056-0c4c3acd90f9?w=300' 
            : _imageController.text,
        rfidTag: _rfidController.text.isNotEmpty ? _rfidController.text : null,
            
        type: _selectedType,
        status: _selectedStatus,
        
        specs: specsMap.isNotEmpty ? specsMap : null,
        
        powerKw: double.tryParse(_powerController.text),
        voltage: double.tryParse(_voltageController.text),
        fullLoadCurrent: double.tryParse(_currentController.text),
        noLoadCurrent: widget.asset?.noLoadCurrent, // Preserved from asset history
        frequency: double.tryParse(_frequencyController.text),
        speedRpm: double.tryParse(_speedController.text),
        poles: int.tryParse(_polesController.text),
        frameSize: _frameController.text,
        mountingType: _mountingController.text,
        powerFactor: double.tryParse(_pfController.text),
        efficiency: double.tryParse(_efficiencyController.text),
        
        bearingDE: _bearingDEController.text,
        bearingNDE: _bearingNDEController.text,
        
        windingResistance: widget.asset?.windingResistance,
        insulationResistance: widget.asset?.insulationResistance,
        polarizationIndex: widget.asset?.polarizationIndex,
        vibration: widget.asset?.vibration,
        
        isCritical: widget.asset?.isCritical ?? false,
        installationDate: widget.asset?.installationDate ?? DateTime.now(),
      );

      // 2. Calculate Health
      final health = HealthService().calculateHealth(tempAsset);

      // 3. Create Final Asset
      final newAsset = AssetModel(
         id: tempAsset.id,
         masterEquipmentId: tempAsset.masterEquipmentId,
         tagNo: tempAsset.tagNo,
         name: tempAsset.name,
         make: tempAsset.make,
         model: tempAsset.model,
         serialNo: tempAsset.serialNo,
         poNo: tempAsset.poNo, // NEW
         manufacturingYear: tempAsset.manufacturingYear,
         imageUrl: tempAsset.imageUrl,
         rfidTag: tempAsset.rfidTag,
         type: tempAsset.type,
         status: tempAsset.status,
         specs: tempAsset.specs,
         powerKw: tempAsset.powerKw,
         voltage: tempAsset.voltage,
         fullLoadCurrent: tempAsset.fullLoadCurrent,
         noLoadCurrent: tempAsset.noLoadCurrent,
         frequency: tempAsset.frequency,
         speedRpm: tempAsset.speedRpm,
         poles: tempAsset.poles,
         frameSize: tempAsset.frameSize,
         mountingType: tempAsset.mountingType,
         powerFactor: tempAsset.powerFactor,
         efficiency: tempAsset.efficiency,
         bearingDE: tempAsset.bearingDE,
         bearingNDE: tempAsset.bearingNDE,
         windingResistance: tempAsset.windingResistance,
         insulationResistance: tempAsset.insulationResistance,
         polarizationIndex: tempAsset.polarizationIndex,
         vibration: tempAsset.vibration,
         isCritical: tempAsset.isCritical,
         installationDate: tempAsset.installationDate,
         
         // Injected Health Fields
         healthStatus: health,
         lastPulseTime: DateTime.now(),
         
         // Standard Audit Fields
         createdAt: widget.asset?.createdAt ?? DateTime.now(),
         createdBy: widget.asset?.createdBy ?? AuthService().currentUser?.uid,
         modifiedAt: DateTime.now(),
         modifiedBy: AuthService().currentUser?.uid,
      );

      await FirestoreService().saveAsset(newAsset);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Asset Saved Successfully")));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.asset != null ? 'Edit Asset' : 'New Asset', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: _isLoading 
                ? PulseLoading(size: 20, color: Theme.of(context).colorScheme.onSurface)
                : const Icon(Icons.check, color: AppColors.success),
            onPressed: _isLoading ? null : _saveAsset,
          ),
        ],
      ),
      body: AnimatedGradientBackground(
        child: SafeArea( // Use SafeArea to avoid overlap
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.accent,
                  unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  indicatorColor: AppColors.accent,
                  tabs: const [
                    Tab(text: 'Identity'),
                    Tab(text: 'Specs'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildIdentityTab(),
                      _buildSpecsTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Tabs ---

  Widget _buildIdentityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
           GlassContainer(
             width: double.infinity,
             height: null,
             borderRadius: 16,
             child: Padding(
               padding: const EdgeInsets.all(16),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   _buildSectionTitle('Basic Info'),
                   _buildInput(_tagController, 'Tag ID (Required)', required: true),
                   _buildInput(_nameController, 'Asset Name (Required)', required: true),
                   _buildInput(_descController, 'Description'),
                   Row(
                     children: [
                       Expanded(child: _buildInput(_makeController, 'Make')),
                       const SizedBox(width: 16),
                       Expanded(child: _buildInput(_modelController, 'Model')),
                     ],
                   ),
                   _buildInput(_serialController, 'Serial Number'),
                   _buildInput(_poController, 'Purchase Order (PO) Number'),
                   _buildInput(_rfidController, 'RFID Tag ID'),
                   _buildInput(_yearController, 'Manufacturing Year', isNumber: true),
                   _buildInput(_imageController, 'Image URL'),
                 ],
               ),
             ),
           ),
           const SizedBox(height: 16),
           GlassContainer(
             width: double.infinity,
             height: null,
             borderRadius: 16,
             child: Padding(
               padding: const EdgeInsets.all(16),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   _buildSectionTitle('Status & Context'),
                   _buildDropdown<AssetStatus>(
                     value: _selectedStatus,
                     items: AssetStatus.values,
                     label: 'Current Status',
                     onChanged: (v) => setState(() => _selectedStatus = v!),
                     itemLabel: (v) => v.name.toUpperCase(),
                   ),
                   const SizedBox(height: 16),
                    _buildDropdown<AssetType>(
                      value: _selectedType,
                      items: AssetType.values,
                      label: 'Asset Type',
                      onChanged: (v) => setState(() => _selectedType = v!),
                      itemLabel: (v) {
                        final idx = AssetType.values.indexOf(v);
                        if (idx >= 0 && idx < HierarchyService.assetTypes.length) {
                          return HierarchyService.assetTypes[idx];
                        }
                        return v.name;
                      },
                    ),
                   const SizedBox(height: 16),
                 
                  // Parent Equipment Selector
                  _buildEquipmentDropdown(),
               ],
             ),
           ),
         ),
      ],
    ),
  );
}

Widget _buildEquipmentDropdown() {
  // Safe value resolution
  final hasMatch = _masterEquipments.any((e) => e.id == _selectedParentId);
  final safeValue = hasMatch ? _selectedParentId : null;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Belongs to Equipment (Parent)', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: safeValue,
            isExpanded: true,
            hint: Text(
              _masterEquipments.isEmpty ? 'Loading equipments...' : 'Select Parent Equipment',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            dropdownColor: Theme.of(context).colorScheme.surface,
            icon: const Icon(Icons.arrow_drop_down, color: AppColors.accent),
            items: _masterEquipments.map((item) {
              return DropdownMenuItem<String?>(
                value: item.id,
                child: Text('${item.name} • ${item.area}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _selectedParentId = val;
              });
            },
          ),
        ),
      ),
    ],
  );
}

  Widget _buildSpecsTab() {
    final isMotor = _selectedType == AssetType.motor;
    final isGearbox = _selectedType == AssetType.gearbox;
    final isPump = _selectedType == AssetType.pump;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: GlassContainer(
        width: double.infinity,
        height: null,
        borderRadius: 16,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
                // --- MOTOR ---
                if (isMotor) ...[
                  _buildSectionTitle('Motor Specifications'),
                  Row(
                    children: [
                      Expanded(child: _buildInput(_powerController, 'Power (KW Only)', isNumber: true)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildInput(_voltageController, 'Voltage (V)', isNumber: true)),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: _buildInput(_currentController, 'Rated Current / FLA (A)', isNumber: true)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildInput(_speedController, 'Speed (RPM)', isNumber: true)),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: _buildInput(_frequencyController, 'Frequency (Hz)', isNumber: true)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildInput(_polesController, 'Poles', isNumber: true)),
                    ],
                  ),
                  Row(
                    children: [
                       Expanded(child: _buildInput(_pfController, 'Power Factor (PF)', isNumber: true)),
                       const SizedBox(width: 16),
                       Expanded(child: _buildInput(_efficiencyController, 'Efficiency (%)', isNumber: true)),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: _buildInput(_frameController, 'Frame Size')),
                      const SizedBox(width: 16),
                      Expanded(child: _buildInput(_mountingController, 'Mounting (e.g. B3/B35)')),
                    ],
                  ),
                  Row(
                    children: [
                       Expanded(child: _buildInput(_bearingDEController, 'DE Bearing')),
                       const SizedBox(width: 16),
                       Expanded(child: _buildInput(_bearingNDEController, 'NDE Bearing')),
                    ],
                  ),
                  _buildInput(_greaseTypeController, 'Grease Type / Grade for Greasing'),
                  const SizedBox(height: 24),
                ],

                // --- GEARBOX ---
                if (isGearbox) ...[
                    _buildSectionTitle('Gearbox Specifications'),
                    Row(
                      children: [
                        Expanded(child: _buildInput(_powerController, 'Input Power Rating (KW)', isNumber: true)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildInput(_gearRatioController, 'Gear Ratio (i)')),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: _buildInput(_speedController, 'Input Speed (RPM)', isNumber: true)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildInput(_oilCapacityController, 'Oil Capacity (Liters)', isNumber: true)),
                      ],
                    ),
                    _buildInput(_oilTypeController, 'Recommended Oil Type / Grade (e.g. VG320)'),
                    _buildInput(_mountingController, 'Mounting Configuration'),
                    const SizedBox(height: 24),
                ],

                // --- PUMP ---
                if (isPump) ...[
                     _buildSectionTitle('Pump Specifications'),
                     Row(
                       children: [
                         Expanded(child: _buildInput(_pumpPowerController, 'Power Required (KW)', isNumber: true)),
                         const SizedBox(width: 16),
                         Expanded(child: _buildInput(_speedController, 'Speed (RPM)', isNumber: true)),
                       ],
                     ),
                     Row(
                       children: [
                         Expanded(child: _buildInput(_flowRateController, 'Flow Rate (m3/hr)', isNumber: true)),
                         const SizedBox(width: 16),
                         Expanded(child: _buildInput(_headController, 'Head (meters)', isNumber: true)),
                       ],
                     ),
                     _buildInput(_impellerSizeController, 'Impeller Diameter (mm)', isNumber: true),
                     _buildInput(_greaseTypeController, 'Grease Type for Bearings/Coupling'),
                     const SizedBox(height: 24),
                ],
             ],
          ),
        ),
      ),
    );
  }

  // --- Styled Inputs ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.accent,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String label, {bool isNumber = false, bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        validator: required ? (v) => v == null || v.isEmpty ? 'Required' : null : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          filled: true,
          fillColor: Theme.of(context).cardColor.withValues(alpha: 0.5),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent, width: 1)),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<T> items,
    required String label,
    required Function(T?) onChanged,
    required String Function(T) itemLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: Theme.of(context).colorScheme.surface,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              icon: const Icon(Icons.arrow_drop_down, color: AppColors.accent),
              items: items.map((item) {
                return DropdownMenuItem<T>(
                  value: item,
                  child: Text(itemLabel(item)),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
