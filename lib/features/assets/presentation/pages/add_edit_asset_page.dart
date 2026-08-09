// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/widgets/pulse_loading.dart';
import '../../../../core/utils/permission_helper.dart';
import '../../data/models/asset_model.dart';
import '../../data/models/master_equipment_model.dart';
import '../../../scanning/presentation/pages/nfc_scanner_page.dart';

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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;
  bool _isLoading = false;
  
  List<MasterEquipmentModel> _masterEquipments = [];
  String? _selectedParentId;
  List<String> _selectedParentIdsForSpares = [];

  String _userRole = '';
  bool _isAdmin = false;
  String? _userPlantId;
  String? _userUnitId;

  // Context & Top Level
  AssetStatus _selectedStatus = AssetStatus.active;
  AssetType _selectedType = AssetType.motor;
  bool _isCritical = false;

  // Tag ID & Sequence
  final _seqController = TextEditingController();
  String _computedTagId = '';

  // Identity Controllers
  final _nameController = TextEditingController();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _serialController = TextEditingController();
  final _poController = TextEditingController();
  final _yearController = TextEditingController();
  final _imageController = TextEditingController();
  final _descController = TextEditingController();
  final _rfidController = TextEditingController();

  // Specs Controllers
  final _powerController = TextEditingController();
  final _voltageController = TextEditingController();
  final _currentController = TextEditingController();
  final _speedController = TextEditingController();
  final _frequencyController = TextEditingController();
  final _noLoadCurrentController = TextEditingController();
  final _frameController = TextEditingController();
  final _mountingController = TextEditingController();
  final _polesController = TextEditingController();
  final _pfController = TextEditingController();
  final _efficiencyController = TextEditingController();
  
  // Gearbox Specs
  final _gearRatioController = TextEditingController();
  final _oilTypeController = TextEditingController();
  final _oilCapacityController = TextEditingController();
  
  // Pump Specs
  final _flowRateController = TextEditingController();
  final _headController = TextEditingController();
  final _impellerSizeController = TextEditingController();
  final _pumpPowerController = TextEditingController();
  final _greaseTypeController = TextEditingController();

  // Common Motor/Electrical Types
  final _bearingDEController = TextEditingController();
  final _bearingNDEController = TextEditingController();

  // Health
  final _resRYController = TextEditingController();
  final _resYBController = TextEditingController();
  final _resRBController = TextEditingController();
  
  final _irRyController = TextEditingController();
  final _irYbController = TextEditingController();
  final _irBrController = TextEditingController();
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    _loadUserProfile();
    _loadMasterData();

    if (widget.asset != null) {
      _populateControllers();
    } else {
      _seqController.text = '001';
      _calculateNextSeqNo();
    }

    _updateComputedTagId();
  }

  String get _currentPlantId => widget.plantId ?? widget.asset?.id.split('-').first ?? _userPlantId ?? 'PLANT';
  String get _currentUnitId => widget.unitId ?? (_currentPlantId.isNotEmpty ? widget.asset?.id.split('-').skip(1).firstOrNull : null) ?? _userUnitId ?? 'UNIT';

  String _getTypeCode(AssetType type) {
    switch (type) {
      case AssetType.motor:
        return 'MTR';
      case AssetType.gearbox:
        return 'GBX';
      case AssetType.pump:
        return 'PMP';
    }
  }

  void _updateComputedTagId() {
    final prefix = '$_currentPlantId-$_currentUnitId-${_getTypeCode(_selectedType)}-';
    final seq = _seqController.text.trim().isEmpty ? '001' : _seqController.text.trim().padLeft(3, '0');
    setState(() {
      _computedTagId = '$prefix$seq';
    });
  }

  Future<void> _calculateNextSeqNo() async {
    try {
      final snap = await _firestore.collection('assets').get();
      final typeCode = _getTypeCode(_selectedType);
      final prefix = '$_currentPlantId-$_currentUnitId-$typeCode-';
      
      int maxSeq = 0;
      for (var doc in snap.docs) {
        final tag = doc.data()['tagNo']?.toString() ?? doc.id;
        if (tag.startsWith(prefix)) {
          final parts = tag.split('-');
          if (parts.isNotEmpty) {
            final seqNum = int.tryParse(parts.last) ?? 0;
            if (seqNum > maxSeq) maxSeq = seqNum;
          }
        }
      }

      if (mounted) {
        setState(() {
          _seqController.text = (maxSeq + 1).toString().padLeft(3, '0');
          _updateComputedTagId();
        });
      }
    } catch (e) {
      debugPrint('Error calculating seq no: $e');
    }
  }

  Future<void> _loadUserProfile() async {
    final user = AuthService().currentUser;
    if (user != null) {
      final profile = await FirestoreService().getUserProfile(user.uid);
      if (profile != null && mounted) {
        setState(() {
          _userRole = profile['role'] ?? 'Guest';
          _isAdmin = profile['isAdmin'] == true;
          _userPlantId = profile['plantId'] as String?;
          _userUnitId = profile['unitId'] as String?;
        });
      }
    }
  }

  Future<void> _loadMasterData() async {
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
    _selectedStatus = a.status;
    _selectedType = a.type;
    _isCritical = a.isCritical;
    _selectedParentId = a.masterEquipmentId;
    _selectedParentIdsForSpares = List<String>.from(a.applicableParentEquipmentIds ?? []);

    // Extract sequence number from tag
    final parts = a.tagNo.split('-');
    if (parts.length >= 4) {
      _seqController.text = parts.last;
    } else {
      _seqController.text = a.seqNo ?? '001';
    }

    _nameController.text = a.name;
    _descController.text = a.description; 
    _makeController.text = a.make;
    _modelController.text = a.model;
    _serialController.text = a.serialNo;
    _poController.text = a.poNo ?? '';
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
      _oilCapacityController.text = a.specs!['oilCapacity']?.toString() ?? '';
      _flowRateController.text = a.specs!['flowRate']?.toString() ?? '';
      _headController.text = a.specs!['head']?.toString() ?? '';
      _impellerSizeController.text = a.specs!['impellerSize']?.toString() ?? '';
      _pumpPowerController.text = a.specs!['pumpPower']?.toString() ?? '';
      _greaseTypeController.text = a.specs!['greaseType']?.toString() ?? '';
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
  }

  @override
  void dispose() {
    _tabController.dispose();
    _seqController.dispose();
    _nameController.dispose(); _makeController.dispose();
    _modelController.dispose(); _serialController.dispose(); _yearController.dispose();
    _imageController.dispose(); _powerController.dispose(); _voltageController.dispose();
    _currentController.dispose(); _speedController.dispose(); _frameController.dispose();
    _frequencyController.dispose(); _noLoadCurrentController.dispose(); _rfidController.dispose(); 
    _poController.dispose(); _greaseTypeController.dispose();
    _oilCapacityController.dispose(); _pumpPowerController.dispose();
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
    _descController.dispose();

    super.dispose();
  }

  // --- NFC SCANNER INTEGRATION ---
  Future<void> _scanNfcTag() async {
    final scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const NFCScannerPage()),
    );

    if (scannedCode != null && scannedCode.isNotEmpty) {
      setState(() {
        _rfidController.text = scannedCode;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('NFC/RFID Tag Captured: $scannedCode'), backgroundColor: AppColors.success),
        );
      }
    }
  }

  // --- MULTIPLE PARENT EQUIPMENT SELECTOR FOR SPARES ---
  void _showSpareParentsSelector() {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Select Applicable Parent Machines', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              content: SizedBox(
                width: double.maxFinite,
                child: _masterEquipments.isEmpty
                    ? const Text('No master equipments registered in this unit yet.')
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _masterEquipments.length,
                        itemBuilder: (context, idx) {
                          final eq = _masterEquipments[idx];
                          final isSelected = _selectedParentIdsForSpares.contains(eq.id);

                          return CheckboxListTile(
                            title: Text(eq.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                            subtitle: Text('${eq.equipmentCode} • Location: ${eq.locationId}', style: const TextStyle(fontSize: 11)),
                            value: isSelected,
                            activeColor: AppColors.primary,
                            onChanged: (checked) {
                              setDialogState(() {
                                if (checked == true) {
                                  _selectedParentIdsForSpares.add(eq.id);
                                } else {
                                  _selectedParentIdsForSpares.remove(eq.id);
                                }
                              });
                              setState(() {});
                            },
                          );
                        },
                      ),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveAsset() async {
    if (!_formKey.currentState!.validate()) return;
    _updateComputedTagId();

    final targetTagId = _computedTagId;

    setState(() => _isLoading = true);

    try {
      // 1. Duplicate Asset Tag ID Check
      final duplicateQuery = await _firestore
          .collection('assets')
          .where('tagNo', isEqualTo: targetTagId)
          .get();

      final isDuplicate = duplicateQuery.docs.any((doc) => doc.id != widget.asset?.id);
      if (isDuplicate) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: Asset with Tag ID "$targetTagId" already exists. Duplicates are not allowed!'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final canEdit = PermissionHelper.canEditDatabaseItem(
        userRole: _userRole,
        isAdmin: _isAdmin,
        userPlantId: _userPlantId,
        userUnitId: _userUnitId,
        itemPlantId: _currentPlantId,
        itemUnitId: _currentUnitId,
      );

      if (!canEdit) {
        throw Exception("You do not have permission to modify database items in this scope.");
      }

      // Build Specs Map
      final Map<String, dynamic> dynamicSpecs = {};
      if (_selectedType == AssetType.gearbox) {
        if (_gearRatioController.text.isNotEmpty) dynamicSpecs['gearRatio'] = _gearRatioController.text.trim();
        if (_oilTypeController.text.isNotEmpty) dynamicSpecs['oilType'] = _oilTypeController.text.trim();
        if (_oilCapacityController.text.isNotEmpty) dynamicSpecs['oilCapacity'] = double.tryParse(_oilCapacityController.text.trim());
      } else if (_selectedType == AssetType.pump) {
        if (_flowRateController.text.isNotEmpty) dynamicSpecs['flowRate'] = double.tryParse(_flowRateController.text.trim());
        if (_headController.text.isNotEmpty) dynamicSpecs['head'] = double.tryParse(_headController.text.trim());
        if (_impellerSizeController.text.isNotEmpty) dynamicSpecs['impellerSize'] = _impellerSizeController.text.trim();
        if (_pumpPowerController.text.isNotEmpty) dynamicSpecs['pumpPower'] = double.tryParse(_pumpPowerController.text.trim());
        if (_greaseTypeController.text.isNotEmpty) dynamicSpecs['greaseType'] = _greaseTypeController.text.trim();
      }

      // Resistance Maps
      final Map<String, dynamic> windingRes = {};
      if (_resRYController.text.isNotEmpty) windingRes['R-Y'] = double.tryParse(_resRYController.text);
      if (_resYBController.text.isNotEmpty) windingRes['Y-B'] = double.tryParse(_resYBController.text);
      if (_resRBController.text.isNotEmpty) windingRes['R-B'] = double.tryParse(_resRBController.text);

      final Map<String, dynamic> insulationRes = {};
      if (_irRyController.text.isNotEmpty) insulationRes['R-Y'] = double.tryParse(_irRyController.text);
      if (_irYbController.text.isNotEmpty) insulationRes['Y-B'] = double.tryParse(_irYbController.text);
      if (_irBrController.text.isNotEmpty) insulationRes['B-R'] = double.tryParse(_irBrController.text);
      if (_irReController.text.isNotEmpty) insulationRes['R-E'] = double.tryParse(_irReController.text);
      if (_irYeController.text.isNotEmpty) insulationRes['Y-E'] = double.tryParse(_irYeController.text);
      if (_irBeController.text.isNotEmpty) insulationRes['B-E'] = double.tryParse(_irBeController.text);

      // Vibration Map
      final Map<String, dynamic> vibData = {};
      if (_vibDeHController.text.isNotEmpty) vibData['DE_H'] = double.tryParse(_vibDeHController.text);
      if (_vibDeVController.text.isNotEmpty) vibData['DE_V'] = double.tryParse(_vibDeVController.text);
      if (_vibDeAController.text.isNotEmpty) vibData['DE_A'] = double.tryParse(_vibDeAController.text);
      if (_vibNdeHController.text.isNotEmpty) vibData['NDE_H'] = double.tryParse(_vibNdeHController.text);
      if (_vibNdeVController.text.isNotEmpty) vibData['NDE_V'] = double.tryParse(_vibNdeVController.text);
      if (_vibNdeAController.text.isNotEmpty) vibData['NDE_A'] = double.tryParse(_vibNdeAController.text);
      if (_vibGController.text.isNotEmpty) vibData['G_Value'] = double.tryParse(_vibGController.text);

      final primaryParentId = _selectedParentId ?? (_selectedParentIdsForSpares.isNotEmpty ? _selectedParentIdsForSpares.first : '');

      final asset = AssetModel(
        id: widget.asset?.id ?? targetTagId,
        masterEquipmentId: primaryParentId,
        tagNo: targetTagId,
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        make: _makeController.text.trim(),
        model: _modelController.text.trim(),
        serialNo: _serialController.text.trim(),
        rfidTag: _rfidController.text.trim().isNotEmpty ? _rfidController.text.trim() : null,
        poNo: _poController.text.trim().isNotEmpty ? _poController.text.trim() : null,
        manufacturingYear: int.tryParse(_yearController.text),
        imageUrl: _imageController.text.trim(),
        
        type: _selectedType,
        status: _selectedStatus,
        specs: dynamicSpecs.isNotEmpty ? dynamicSpecs : null,
        
        powerKw: double.tryParse(_powerController.text),
        voltage: double.tryParse(_voltageController.text),
        fullLoadCurrent: double.tryParse(_currentController.text),
        noLoadCurrent: double.tryParse(_noLoadCurrentController.text),
        speedRpm: double.tryParse(_speedController.text),
        poles: int.tryParse(_polesController.text),
        frequency: double.tryParse(_frequencyController.text),
        efficiency: double.tryParse(_efficiencyController.text),
        powerFactor: double.tryParse(_pfController.text),
        frameSize: _frameController.text.trim().isNotEmpty ? _frameController.text.trim() : null,
        mountingType: _mountingController.text.trim().isNotEmpty ? _mountingController.text.trim() : null,
        
        windingResistance: windingRes.isNotEmpty ? windingRes : null,
        insulationResistance: insulationRes.isNotEmpty ? insulationRes : null,
        polarizationIndex: double.tryParse(_piController.text),
        vibration: vibData.isNotEmpty ? vibData : null,
        
        bearingDE: _bearingDEController.text.trim().isNotEmpty ? _bearingDEController.text.trim() : null,
        bearingNDE: _bearingNDEController.text.trim().isNotEmpty ? _bearingNDEController.text.trim() : null,
        
        isCritical: _isCritical,
        applicableParentEquipmentIds: _selectedParentIdsForSpares.isNotEmpty ? _selectedParentIdsForSpares : null,
        seqNo: _seqController.text.trim(),
        
        createdAt: widget.asset?.createdAt,
        createdBy: widget.asset?.createdBy ?? AuthService().currentUser?.email,
        modifiedAt: DateTime.now(),
        modifiedBy: AuthService().currentUser?.email,
      );

      if (widget.asset != null) {
        await _firestore.collection('assets').doc(widget.asset!.id).set(asset.toMap());
      } else {
        await _firestore.collection('assets').doc(targetTagId).set(asset.toMap());
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.asset != null ? 'Asset updated successfully' : 'Asset $targetTagId registered successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save asset: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefix = '$_currentPlantId-$_currentUnitId-${_getTypeCode(_selectedType)}-';

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: Text(widget.asset != null ? 'Edit Asset (${widget.asset!.tagNo})' : 'Add New Asset'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: AnimatedGradientBackground(
        child: _isLoading 
          ? const Center(child: PulseLoading(size: 60))
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  // --- TOP SECTION: STATUS, TYPE & CRITICALITY CONTEXT ---
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: GlassContainer(
                      borderRadius: 16,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Status Selector
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Asset Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accent)),
                                // Criticality Switch
                                Row(
                                  children: [
                                    const Icon(Icons.warning_amber, color: Colors.orangeAccent, size: 16),
                                    const SizedBox(width: 4),
                                    const Text('Critical Asset', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    Switch(
                                      value: _isCritical,
                                      activeColor: Colors.redAccent,
                                      onChanged: (val) => setState(() => _isCritical = val),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              children: AssetStatus.values.map((st) {
                                final isSelected = _selectedStatus == st;
                                Color stColor = Colors.grey;
                                if (st == AssetStatus.active) stColor = Colors.greenAccent;
                                if (st == AssetStatus.spare) stColor = Colors.cyanAccent;
                                if (st == AssetStatus.underMaintenance) stColor = Colors.orangeAccent;
                                if (st == AssetStatus.scrapped) stColor = Colors.redAccent;

                                return ChoiceChip(
                                  label: Text(st.name.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.black : Colors.white)),
                                  selected: isSelected,
                                  selectedColor: stColor,
                                  onSelected: (val) {
                                    if (val) setState(() => _selectedStatus = st);
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 12),

                            // 2. Type Selector
                            const Text('Asset Classification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accent)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              children: AssetType.values.map((tp) {
                                final isSelected = _selectedType == tp;
                                return ChoiceChip(
                                  label: Text(tp.name.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.black : Colors.white)),
                                  selected: isSelected,
                                  selectedColor: AppColors.primary,
                                  onSelected: (val) {
                                    if (val) {
                                      setState(() {
                                        _selectedType = tp;
                                        _calculateNextSeqNo();
                                      });
                                    }
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // --- LOCKED PREFIX & AUTO TAG ID BAR ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.tag, color: AppColors.accent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('LOCKED ASSET TAG ID', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.accent)),
                                Text(_computedTagId, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          // Sequence Number Input
                          SizedBox(
                            width: 90,
                            child: TextFormField(
                              controller: _seqController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Seq No',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => _updateComputedTagId(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Tab Bar
                  TabBar(
                    controller: _tabController,
                    indicatorColor: AppColors.accent,
                    tabs: const [
                      Tab(text: "Identity & General"),
                      Tab(text: "Specifications"),
                    ],
                  ),

                  // Tab Views
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildIdentityTab(prefix),
                        _buildSpecsTab(),
                      ],
                    ),
                  ),

                  // Save Action
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _saveAsset,
                        child: Text(
                          widget.asset != null ? 'UPDATE ASSET RECORD' : 'REGISTER ASSET TO REGISTRY',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  // --- TAB 1: IDENTITY & GENERAL ---
  Widget _buildIdentityTab(String prefix) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Parent Machine / Spare Linking
          if (_selectedStatus == AssetStatus.spare) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.cyan.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('SPARE POOL: APPLICABLE PARENT MACHINES',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.cyanAccent)),
                      TextButton.icon(
                        icon: const Icon(Icons.add_link, size: 16, color: Colors.cyanAccent),
                        label: const Text('Select Machines', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                        onPressed: _showSpareParentsSelector,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _selectedParentIdsForSpares.isEmpty
                      ? const Text('No parent machines linked yet. Tap above to assign multiple compatible parent equipments.', style: TextStyle(fontSize: 11, color: Colors.grey))
                      : Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: _selectedParentIdsForSpares.map((pid) {
                            final eq = _masterEquipments.firstWhere((e) => e.id == pid, orElse: () => MasterEquipmentModel(id: pid, name: pid, equipmentCode: pid, plantId: '', unitId: '', locationId: '', isCritical: false, createdAt: DateTime.now()));
                            return Chip(
                              label: Text('${eq.name} (${eq.equipmentCode})', style: const TextStyle(fontSize: 11)),
                              deleteIcon: const Icon(Icons.close, size: 14),
                              onDeleted: () {
                                setState(() {
                                  _selectedParentIdsForSpares.remove(pid);
                                });
                              },
                            );
                          }).toList(),
                        ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ] else ...[
            DropdownButtonFormField<String>(
              value: _masterEquipments.any((e) => e.id == _selectedParentId) ? _selectedParentId : null,
              decoration: const InputDecoration(
                labelText: 'Installed Parent Equipment / Machine *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.precision_manufacturing),
              ),
              items: _masterEquipments.map((e) {
                return DropdownMenuItem(
                  value: e.id,
                  child: Text('${e.name} (${e.equipmentCode})', overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedParentId = val),
              validator: (val) {
                if (_selectedStatus != AssetStatus.spare && (val == null || val.isEmpty)) {
                  return 'Please select parent equipment';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
          ],

          // Name
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Equipment / Asset Name *', border: OutlineInputBorder()),
            validator: (v) => v!.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 14),

          // Make & Model
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _makeController,
                  decoration: const InputDecoration(labelText: 'Manufacturer / Make *', border: OutlineInputBorder()),
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _modelController,
                  decoration: const InputDecoration(labelText: 'Model *', border: OutlineInputBorder()),
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Serial No & Year
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _serialController,
                  decoration: const InputDecoration(labelText: 'Serial No *', border: OutlineInputBorder()),
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _yearController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Mfg Year', border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // RFID Tag with Scan NFC Integration
          TextFormField(
            controller: _rfidController,
            decoration: InputDecoration(
              labelText: 'RFID / NFC Tag ID',
              hintText: 'e.g. E28011700000020F',
              prefixIcon: const Icon(Icons.nfc, color: Colors.blueAccent),
              suffixIcon: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                icon: const Icon(Icons.sensors, size: 16, color: Colors.blueAccent),
                label: const Text('Scan NFC', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                onPressed: _scanNfcTag,
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),

          // PO Number
          TextFormField(
            controller: _poController,
            decoration: const InputDecoration(labelText: 'Purchase Order (PO) No', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 14),

          // Description
          TextFormField(
            controller: _descController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Asset Description / Observations', border: OutlineInputBorder()),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: TECHNICAL SPECIFICATIONS ---
  Widget _buildSpecsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedType == AssetType.motor) ...[
            const Text('Motor Electrical Specifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accent)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _powerController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Power (kW)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _voltageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Voltage (V)', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _currentController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'FLA (Amps)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _speedController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Speed (RPM)', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _polesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Poles', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _frequencyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Frequency (Hz)', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _frameController,
                    decoration: const InputDecoration(labelText: 'Frame Size', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _mountingController,
                    decoration: const InputDecoration(labelText: 'Mounting Type (B3/B5)', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
          ] else if (_selectedType == AssetType.gearbox) ...[
            const Text('Gearbox Specifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accent)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _gearRatioController,
                    decoration: const InputDecoration(labelText: 'Gear Ratio (e.g. 1:25)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _oilTypeController,
                    decoration: const InputDecoration(labelText: 'Oil Grade (VG 320)', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _oilCapacityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Oil Capacity (Liters)', border: OutlineInputBorder()),
            ),
          ] else if (_selectedType == AssetType.pump) ...[
            const Text('Pump Hydraulic Specifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accent)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _flowRateController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Flow Rate (m³/hr)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _headController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Head (Meters)', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _impellerSizeController,
                    decoration: const InputDecoration(labelText: 'Impeller Size (mm)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _pumpPowerController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Pump Power (kW)', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),

          // Bearings
          const Text('Bearing Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accent)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _bearingDEController,
                  decoration: const InputDecoration(labelText: 'Drive End (DE) Bearing', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _bearingNDEController,
                  decoration: const InputDecoration(labelText: 'Non-Drive End (NDE) Bearing', border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Diagnostics
          const Text('Diagnostics: Insulation Resistance (MΩ)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accent)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: TextFormField(controller: _irRyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'R-Y', border: OutlineInputBorder()))),
              const SizedBox(width: 8),
              Expanded(child: TextFormField(controller: _irYbController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Y-B', border: OutlineInputBorder()))),
              const SizedBox(width: 8),
              Expanded(child: TextFormField(controller: _irBrController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'B-R', border: OutlineInputBorder()))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: TextFormField(controller: _irReController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'R-E', border: OutlineInputBorder()))),
              const SizedBox(width: 8),
              Expanded(child: TextFormField(controller: _irYeController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Y-E', border: OutlineInputBorder()))),
              const SizedBox(width: 8),
              Expanded(child: TextFormField(controller: _irBeController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'B-E', border: OutlineInputBorder()))),
            ],
          ),
        ],
      ),
    );
  }
}
