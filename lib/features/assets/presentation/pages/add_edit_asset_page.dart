// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/widgets/pulse_loading.dart';
import '../../../../core/utils/permission_helper.dart';
import '../../data/models/asset_model.dart';
import '../../data/models/master_equipment_model.dart';

class AddEditAssetPage extends StatefulWidget {
  final AssetModel? asset;
  final String? unitId;
  final String? plantId;

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
  final _spareLocationController = TextEditingController();

  // Motor Technical Specs (FLC, Power, etc.)
  final _powerController = TextEditingController();
  final _voltageController = TextEditingController();
  final _flcCurrentController = TextEditingController(); // FLC (Full Load Current)
  final _noLoadCurrentController = TextEditingController();
  final _speedController = TextEditingController();
  final _frequencyController = TextEditingController();
  final _frameController = TextEditingController();
  final _mountingController = TextEditingController();
  final _polesController = TextEditingController();
  final _pfController = TextEditingController();
  final _efficiencyController = TextEditingController();
  final _motorGreaseTypeController = TextEditingController();
  final _motorTypeController = TextEditingController();
  final _dutyCycleController = TextEditingController();
  final _insulationClassController = TextEditingController();
  String _couplingAvailable = 'NO';
  final _couplingTypeController = TextEditingController();
  final _efficiencyClassController = TextEditingController();
  final _ipRatingController = TextEditingController();

  // Gearbox Dynamic Specs
  final _gearboxPowerController = TextEditingController();
  final _inputSpeedController = TextEditingController();
  final _outputSpeedController = TextEditingController();
  final _gearRatioController = TextEditingController();
  final _oilTypeController = TextEditingController();
  final _oilCapacityController = TextEditingController();
  final _inputShaftController = TextEditingController();
  final _outputShaftController = TextEditingController();
  final _lubricationMethodController = TextEditingController();
  final _gearboxMountingController = TextEditingController();

  // Pump Dynamic Specs
  final _flowRateController = TextEditingController();
  final _headController = TextEditingController();
  final _pumpSpeedController = TextEditingController();
  final _impellerSizeController = TextEditingController();
  final _pumpPowerController = TextEditingController();
  final _suctionFlangeController = TextEditingController();
  final _dischargeFlangeController = TextEditingController();
  final _sealTypeController = TextEditingController();
  final _casingMaterialController = TextEditingController();
  final _pumpGreaseTypeController = TextEditingController();

  // Brake Dynamic Specs
  final _brakeTypeController = TextEditingController();
  final _thrusterCapacityController = TextEditingController();
  final _brakeVoltageTypeController = TextEditingController();
  final _brakeVoltageRatingController = TextEditingController();
  final _drumDiaController = TextEditingController();
  final _drumWidthController = TextEditingController();
  final _drumInstallationController = TextEditingController();
  final _mountingBoltSizeController = TextEditingController();
  final _mountingBoltCountController = TextEditingController();
  final _mountingLengthController = TextEditingController();
  final _mountingWidthController = TextEditingController();
  final _brakingTorqueController = TextEditingController();
  final _brakeShoeLiningController = TextEditingController();

  // Actuator Dynamic Specs
  final _actuatorTypeController = TextEditingController();
  final _torqueOrThrustController = TextEditingController();
  final _operatingTimeController = TextEditingController();
  final _controlSignalController = TextEditingController();
  final _valveFlangeStandardController = TextEditingController();
  final _valveTypeController = TextEditingController();
  final _valveSizeController = TextEditingController();

  // Construction Bearings (Common)
  final _bearingDEController = TextEditingController();
  final _bearingNDEController = TextEditingController();

  // Lifecycle Dates
  DateTime? _installationDate;
  DateTime? _lastServiceDate;
  DateTime? _nextServiceDue;

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

  String get _currentPlantId => widget.plantId ?? (_currentUnitId.isNotEmpty ? widget.asset?.id.split('-').firstOrNull : null) ?? _userPlantId ?? 'PLANT';
  String get _currentUnitId =>
      widget.unitId ?? (_currentPlantId.isNotEmpty ? widget.asset?.id.split('-').skip(1).firstOrNull : null) ?? _userUnitId ?? 'UNIT';

  String _getTypeCode(AssetType type) {
    switch (type) {
      case AssetType.motor:
        return 'MTR';
      case AssetType.gearbox:
        return 'GBX';
      case AssetType.pump:
        return 'PMP';
      case AssetType.brake:
        return 'BRK';
      case AssetType.actuator:
        return 'ACT';
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
    _spareLocationController.text = a.spareLocation ?? '';

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

    // Motor Specs
    _powerController.text = a.powerKw?.toString() ?? '';
    _voltageController.text = a.voltage?.toString() ?? '';
    _flcCurrentController.text = a.fullLoadCurrent?.toString() ?? '';
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
    _motorTypeController.text = a.motorType ?? '';
    _dutyCycleController.text = a.dutyCycle ?? '';
    _insulationClassController.text = a.insulationClass ?? '';
    _couplingAvailable = (a.couplingAvailable?.toUpperCase() == 'YES' || a.couplingAvailable == 'true') ? 'YES' : 'NO';
    _couplingTypeController.text = a.couplingType ?? '';
    _efficiencyClassController.text = a.efficiencyClass ?? '';
    _ipRatingController.text = a.ipRating ?? '';

    _installationDate = a.installationDate;
    _lastServiceDate = a.lastServiceDate;
    _nextServiceDue = a.nextServiceDue;

    // Direct & Dynamic Specs
    _motorGreaseTypeController.text = a.greaseType ?? a.specs?['greaseType']?.toString() ?? '';

    // Gearbox
    _gearboxPowerController.text = a.powerKw?.toString() ?? a.specs?['inputPowerKw']?.toString() ?? '';
    _inputSpeedController.text = a.inputSpeedRpm?.toString() ?? a.specs?['inputSpeedRpm']?.toString() ?? '';
    _outputSpeedController.text = a.outputSpeedRpm?.toString() ?? a.specs?['outputSpeedRpm']?.toString() ?? '';
    _gearRatioController.text = a.gearRatio ?? a.specs?['gearRatio']?.toString() ?? '';
    _oilTypeController.text = a.oilType ?? a.specs?['oilType']?.toString() ?? '';
    _oilCapacityController.text = a.oilCapacity?.toString() ?? a.specs?['oilCapacity']?.toString() ?? '';
    _inputShaftController.text = a.inputShaftMm?.toString() ?? a.specs?['inputShaftMm']?.toString() ?? '';
    _outputShaftController.text = a.outputShaftMm?.toString() ?? a.specs?['outputShaftMm']?.toString() ?? '';
    _lubricationMethodController.text = a.lubricationMethod ?? a.specs?['lubricationMethod']?.toString() ?? '';
    _gearboxMountingController.text = a.mountingOrientation ?? a.specs?['mountingOrientation']?.toString() ?? '';

    // Pump
    _flowRateController.text = a.flowRate?.toString() ?? a.specs?['flowRate']?.toString() ?? '';
    _headController.text = a.head?.toString() ?? a.specs?['head']?.toString() ?? '';
    _pumpSpeedController.text = a.speedRpm?.toString() ?? a.specs?['pumpSpeedRpm']?.toString() ?? '';
    _impellerSizeController.text = a.impellerSize ?? a.specs?['impellerSize']?.toString() ?? '';
    _pumpPowerController.text = a.pumpPower?.toString() ?? a.powerKw?.toString() ?? a.specs?['pumpPower']?.toString() ?? '';
    _suctionFlangeController.text = a.suctionFlangeMm?.toString() ?? a.specs?['suctionFlangeMm']?.toString() ?? '';
    _dischargeFlangeController.text = a.dischargeFlangeMm?.toString() ?? a.specs?['dischargeFlangeMm']?.toString() ?? '';
    _sealTypeController.text = a.sealType ?? a.specs?['sealType']?.toString() ?? '';
    _casingMaterialController.text = a.casingMaterial ?? a.specs?['casingMaterial']?.toString() ?? '';
    _pumpGreaseTypeController.text = a.greaseType ?? a.specs?['greaseType']?.toString() ?? '';

    // Brake
    _brakeTypeController.text = a.brakeType ?? a.specs?['brakeType']?.toString() ?? '';
    _thrusterCapacityController.text = a.thrusterCapacityKg?.toString() ?? a.specs?['thrusterCapacityKg']?.toString() ?? '';
    _brakeVoltageTypeController.text = a.voltageType ?? a.specs?['voltageType']?.toString() ?? '';
    _brakeVoltageRatingController.text = a.voltageRating?.toString() ?? a.voltage?.toString() ?? a.specs?['voltageRating']?.toString() ?? '';
    _drumDiaController.text = a.drumDiaMm?.toString() ?? a.specs?['drumDiaMm']?.toString() ?? '';
    _drumWidthController.text = a.drumWidthMm?.toString() ?? a.specs?['drumWidthMm']?.toString() ?? '';
    _drumInstallationController.text = a.drumInstallation ?? a.specs?['drumInstallation']?.toString() ?? '';
    _mountingBoltSizeController.text = a.mountingBoltSize ?? a.specs?['mountingBoltSize']?.toString() ?? '';
    _mountingBoltCountController.text = a.mountingBoltCount?.toString() ?? a.specs?['mountingBoltCount']?.toString() ?? '';
    _mountingLengthController.text = a.mountingLengthMm?.toString() ?? a.specs?['mountingLengthMm']?.toString() ?? '';
    _mountingWidthController.text = a.mountingWidthMm?.toString() ?? a.specs?['mountingWidthMm']?.toString() ?? '';
    _brakingTorqueController.text = a.brakingTorqueNm?.toString() ?? a.specs?['brakingTorqueNm']?.toString() ?? '';
    _brakeShoeLiningController.text = a.brakeShoeLining ?? a.specs?['brakeShoeLining']?.toString() ?? '';

    // Actuator
    _actuatorTypeController.text = a.actuatorType ?? a.specs?['actuatorType']?.toString() ?? '';
    _torqueOrThrustController.text = a.torqueOrThrust?.toString() ?? a.specs?['torqueOrThrust']?.toString() ?? '';
    _operatingTimeController.text = a.operatingTimeSeconds?.toString() ?? a.specs?['operatingTimeSeconds']?.toString() ?? '';
    _controlSignalController.text = a.controlSignal ?? a.specs?['controlSignal']?.toString() ?? '';
    _valveFlangeStandardController.text = a.valveFlangeStandard ?? a.specs?['valveFlangeStandard']?.toString() ?? '';
    _valveTypeController.text = a.valveType ?? a.specs?['valveType']?.toString() ?? '';
    _valveSizeController.text = a.valveSize ?? a.specs?['valveSize']?.toString() ?? '';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _seqController.dispose();
    _nameController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _serialController.dispose();
    _yearController.dispose();
    _imageController.dispose();
    _powerController.dispose();
    _voltageController.dispose();
    _flcCurrentController.dispose();
    _speedController.dispose();
    _frameController.dispose();
    _frequencyController.dispose();
    _noLoadCurrentController.dispose();
    _rfidController.dispose();
    _poController.dispose();
    _spareLocationController.dispose();
    _motorGreaseTypeController.dispose();
    _gearboxPowerController.dispose();
    _inputSpeedController.dispose();
    _outputSpeedController.dispose();
    _gearRatioController.dispose();
    _oilTypeController.dispose();
    _oilCapacityController.dispose();
    _inputShaftController.dispose();
    _outputShaftController.dispose();
    _lubricationMethodController.dispose();
    _gearboxMountingController.dispose();
    _flowRateController.dispose();
    _headController.dispose();
    _pumpSpeedController.dispose();
    _impellerSizeController.dispose();
    _pumpPowerController.dispose();
    _suctionFlangeController.dispose();
    _dischargeFlangeController.dispose();
    _sealTypeController.dispose();
    _casingMaterialController.dispose();
    _pumpGreaseTypeController.dispose();
    _brakeTypeController.dispose();
    _thrusterCapacityController.dispose();
    _brakeVoltageTypeController.dispose();
    _brakeVoltageRatingController.dispose();
    _drumDiaController.dispose();
    _drumWidthController.dispose();
    _drumInstallationController.dispose();
    _mountingBoltSizeController.dispose();
    _mountingBoltCountController.dispose();
    _mountingLengthController.dispose();
    _mountingWidthController.dispose();
    _brakingTorqueController.dispose();
    _brakeShoeLiningController.dispose();
    _actuatorTypeController.dispose();
    _torqueOrThrustController.dispose();
    _operatingTimeController.dispose();
    _controlSignalController.dispose();
    _valveFlangeStandardController.dispose();
    _valveTypeController.dispose();
    _valveSizeController.dispose();
    _mountingController.dispose();
    _polesController.dispose();
    _pfController.dispose();
    _efficiencyController.dispose();
    _bearingDEController.dispose();
    _bearingNDEController.dispose();
    _descController.dispose();

    super.dispose();
  }

  // --- DIRECT IN-SITU NFC SCANNER MODAL ---
  Future<void> _startInSituNfcScan() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('NFC scanning is supported on mobile devices (Android/iOS). Please enter manually.')),
      );
      return;
    }

    bool isAvailable = false;
    try {
      isAvailable = (await NfcManager.instance.checkAvailability()) == NfcAvailability.enabled;
    } catch (_) {
      isAvailable = false;
    }

    if (!isAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('NFC is not enabled or not available on this device.')),
        );
      }
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return GlassContainer(
          borderRadius: 24,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blueAccent.withValues(alpha: 0.15),
                    border: Border.all(color: Colors.blueAccent, width: 2),
                  ),
                  child: const Icon(Icons.nfc, size: 44, color: Colors.blueAccent),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 900.ms),
                const SizedBox(height: 20),
                const Text(
                  'Ready to Scan NFC / RFID Tag',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Hold your phone near the asset RFID/NFC tag...',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade800),
                  onPressed: () {
                    NfcManager.instance.stopSession();
                    Navigator.pop(modalCtx);
                  },
                  child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693, NfcPollingOption.iso18092},
        onDiscovered: (NfcTag tag) async {
          String tagData = '';
          // ignore: invalid_use_of_protected_member
          final Map<String, dynamic> data = Map<String, dynamic>.from(tag.data as Map);

          final ndef = Ndef.from(tag);
          if (ndef != null && ndef.cachedMessage != null) {
            for (var record in ndef.cachedMessage!.records) {
              tagData += String.fromCharCodes(record.payload);
            }
          }

          if (tagData.isEmpty) {
            final tagId = data['nfca']?['identifier'] ??
                data['nfcb']?['identifier'] ??
                data['nfcf']?['identifier'] ??
                data['nfcv']?['identifier'];

            if (tagId != null && tagId is List) {
              tagData = tagId.map((e) => e.toRadixString(16).padLeft(2, '0')).join(':').toUpperCase();
            }
          }

          await NfcManager.instance.stopSession();

          if (mounted) {
            Navigator.pop(context); // Close bottom sheet
            setState(() {
              _rfidController.text = tagData;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('NFC Tag Captured: $tagData'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        },
      );
    } catch (e) {
      debugPrint('NFC Error: $e');
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
                            subtitle: Text('${eq.id} • Location: ${eq.locationId}', style: const TextStyle(fontSize: 11)),
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
      final duplicateQuery = await _firestore.collection('assets').where('tagNo', isEqualTo: targetTagId).get();

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

      final primaryParentId = _selectedParentId ?? (_selectedParentIdsForSpares.isNotEmpty ? _selectedParentIdsForSpares.first : '');

      final double? effectivePowerKw = _selectedType == AssetType.motor
          ? double.tryParse(_powerController.text)
          : _selectedType == AssetType.gearbox
              ? double.tryParse(_gearboxPowerController.text)
              : double.tryParse(_pumpPowerController.text);

      final double? effectiveSpeedRpm = _selectedType == AssetType.motor
          ? double.tryParse(_speedController.text)
          : _selectedType == AssetType.gearbox
              ? double.tryParse(_inputSpeedController.text)
              : double.tryParse(_pumpSpeedController.text);

      final String? directGreaseType = _selectedType == AssetType.motor
          ? (_motorGreaseTypeController.text.trim().isNotEmpty ? _motorGreaseTypeController.text.trim() : null)
          : _selectedType == AssetType.pump
              ? (_pumpGreaseTypeController.text.trim().isNotEmpty ? _pumpGreaseTypeController.text.trim() : null)
              : null;

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
        powerKw: effectivePowerKw,
        voltage: double.tryParse(_voltageController.text),
        fullLoadCurrent: double.tryParse(_flcCurrentController.text),
        noLoadCurrent: double.tryParse(_noLoadCurrentController.text),
        speedRpm: effectiveSpeedRpm,
        poles: int.tryParse(_polesController.text),
        frequency: double.tryParse(_frequencyController.text),
        efficiency: double.tryParse(_efficiencyController.text),
        powerFactor: double.tryParse(_pfController.text),
        frameSize: _frameController.text.trim().isNotEmpty ? _frameController.text.trim() : null,
        mountingType: _mountingController.text.trim().isNotEmpty ? _mountingController.text.trim() : null,
        greaseType: directGreaseType,
        motorType: _selectedType == AssetType.motor && _motorTypeController.text.trim().isNotEmpty ? _motorTypeController.text.trim() : null,
        dutyCycle: _selectedType == AssetType.motor && _dutyCycleController.text.trim().isNotEmpty ? _dutyCycleController.text.trim() : null,
        insulationClass: _selectedType == AssetType.motor && _insulationClassController.text.trim().isNotEmpty ? _insulationClassController.text.trim() : null,
        couplingAvailable: _selectedType == AssetType.motor ? _couplingAvailable : null,
        couplingType: _selectedType == AssetType.motor && _couplingAvailable == 'YES' && _couplingTypeController.text.trim().isNotEmpty ? _couplingTypeController.text.trim() : null,
        efficiencyClass: _selectedType == AssetType.motor && _efficiencyClassController.text.trim().isNotEmpty ? _efficiencyClassController.text.trim() : null,
        ipRating: _selectedType == AssetType.motor && _ipRatingController.text.trim().isNotEmpty ? _ipRatingController.text.trim() : null,

        gearRatio: _gearRatioController.text.trim().isNotEmpty ? _gearRatioController.text.trim() : null,
        oilType: _oilTypeController.text.trim().isNotEmpty ? _oilTypeController.text.trim() : null,
        oilCapacity: double.tryParse(_oilCapacityController.text),
        inputSpeedRpm: double.tryParse(_inputSpeedController.text),
        outputSpeedRpm: double.tryParse(_outputSpeedController.text),
        inputShaftMm: double.tryParse(_inputShaftController.text),
        outputShaftMm: double.tryParse(_outputShaftController.text),
        lubricationMethod: _lubricationMethodController.text.trim().isNotEmpty ? _lubricationMethodController.text.trim() : null,
        mountingOrientation: _gearboxMountingController.text.trim().isNotEmpty ? _gearboxMountingController.text.trim() : null,

        flowRate: double.tryParse(_flowRateController.text),
        head: double.tryParse(_headController.text),
        impellerSize: _impellerSizeController.text.trim().isNotEmpty ? _impellerSizeController.text.trim() : null,
        pumpPower: double.tryParse(_pumpPowerController.text),
        suctionFlangeMm: double.tryParse(_suctionFlangeController.text),
        dischargeFlangeMm: double.tryParse(_dischargeFlangeController.text),
        sealType: _sealTypeController.text.trim().isNotEmpty ? _sealTypeController.text.trim() : null,
        casingMaterial: _casingMaterialController.text.trim().isNotEmpty ? _casingMaterialController.text.trim() : null,

        // Brake Specs
        brakeType: _selectedType == AssetType.brake && _brakeTypeController.text.trim().isNotEmpty ? _brakeTypeController.text.trim() : null,
        thrusterCapacityKg: _selectedType == AssetType.brake ? double.tryParse(_thrusterCapacityController.text) : null,
        voltageType: _selectedType == AssetType.brake && _brakeVoltageTypeController.text.trim().isNotEmpty ? _brakeVoltageTypeController.text.trim() : null,
        voltageRating: _selectedType == AssetType.brake ? double.tryParse(_brakeVoltageRatingController.text) : null,
        drumDiaMm: _selectedType == AssetType.brake ? double.tryParse(_drumDiaController.text) : null,
        drumWidthMm: _selectedType == AssetType.brake ? double.tryParse(_drumWidthController.text) : null,
        drumInstallation: _selectedType == AssetType.brake && _drumInstallationController.text.trim().isNotEmpty ? _drumInstallationController.text.trim() : null,
        mountingBoltSize: _selectedType == AssetType.brake && _mountingBoltSizeController.text.trim().isNotEmpty ? _mountingBoltSizeController.text.trim() : null,
        mountingBoltCount: _selectedType == AssetType.brake ? int.tryParse(_mountingBoltCountController.text) : null,
        mountingLengthMm: _selectedType == AssetType.brake ? double.tryParse(_mountingLengthController.text) : null,
        mountingWidthMm: _selectedType == AssetType.brake ? double.tryParse(_mountingWidthController.text) : null,
        brakingTorqueNm: _selectedType == AssetType.brake ? double.tryParse(_brakingTorqueController.text) : null,
        brakeShoeLining: _selectedType == AssetType.brake && _brakeShoeLiningController.text.trim().isNotEmpty ? _brakeShoeLiningController.text.trim() : null,

        // Actuator Specs
        actuatorType: _selectedType == AssetType.actuator && _actuatorTypeController.text.trim().isNotEmpty ? _actuatorTypeController.text.trim() : null,
        torqueOrThrust: _selectedType == AssetType.actuator ? double.tryParse(_torqueOrThrustController.text) : null,
        operatingTimeSeconds: _selectedType == AssetType.actuator ? double.tryParse(_operatingTimeController.text) : null,
        controlSignal: _selectedType == AssetType.actuator && _controlSignalController.text.trim().isNotEmpty ? _controlSignalController.text.trim() : null,
        valveFlangeStandard: _selectedType == AssetType.actuator && _valveFlangeStandardController.text.trim().isNotEmpty ? _valveFlangeStandardController.text.trim() : null,
        valveType: _selectedType == AssetType.actuator && _valveTypeController.text.trim().isNotEmpty ? _valveTypeController.text.trim() : null,
        valveSize: _selectedType == AssetType.actuator && _valveSizeController.text.trim().isNotEmpty ? _valveSizeController.text.trim() : null,

        bearingDE: _bearingDEController.text.trim().isNotEmpty ? _bearingDEController.text.trim() : null,
        bearingNDE: _bearingNDEController.text.trim().isNotEmpty ? _bearingNDEController.text.trim() : null,
        isCritical: _isCritical,
        applicableParentEquipmentIds: _selectedParentIdsForSpares.isNotEmpty ? _selectedParentIdsForSpares : null,
        spareLocation: _selectedStatus == AssetStatus.spare ? _spareLocationController.text.trim() : null,
        seqNo: _seqController.text.trim(),
        installationDate: _installationDate,
        lastServiceDate: _lastServiceDate,
        nextServiceDue: _nextServiceDue,
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
                    // --- COMPACT OPTIMIZED STATUS & CONTEXT HEADER (SPACE EFFICIENT) ---
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                      child: GlassContainer(
                        borderRadius: 14,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              // 1. Asset Status Dropdown
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<AssetStatus>(
                                  value: _selectedStatus,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Status',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  items: AssetStatus.values.map((st) {
                                    Color c = Colors.grey;
                                    if (st == AssetStatus.active) c = Colors.greenAccent;
                                    if (st == AssetStatus.spare) c = Colors.cyanAccent;
                                    if (st == AssetStatus.underMaintenance) c = Colors.orangeAccent;
                                    if (st == AssetStatus.scrapped) c = Colors.redAccent;

                                    return DropdownMenuItem(
                                      value: st,
                                      child: Row(
                                        children: [
                                          Icon(Icons.circle, color: c, size: 10),
                                          const SizedBox(width: 6),
                                          Text(st.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedStatus = val);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),

                              // 2. Asset Classification Dropdown
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<AssetType>(
                                  value: _selectedType,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Type',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  items: AssetType.values.map((tp) {
                                    return DropdownMenuItem(
                                      value: tp,
                                      child: Text(tp.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedType = val;
                                        _calculateNextSeqNo();
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),

                              // 3. Critical Toggle Pill
                              InkWell(
                                onTap: () => setState(() => _isCritical = !_isCritical),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _isCritical ? Colors.redAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: _isCritical ? Colors.redAccent : Colors.grey.shade700),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.warning_amber, size: 16, color: _isCritical ? Colors.redAccent : Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        'CRITICAL',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: _isCritical ? Colors.redAccent : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.tag, color: AppColors.accent, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('LOCKED ASSET TAG ID', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.accent)),
                                  Text(_computedTagId, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 80,
                              child: TextFormField(
                                controller: _seqController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Seq No',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                ),
                                onChanged: (_) => _updateComputedTagId(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 2 Clean Tabs (Diagnostics Removed)
                    TabBar(
                      controller: _tabController,
                      indicatorColor: AppColors.accent,
                      tabs: const [
                        Tab(text: "Identity & General"),
                        Tab(text: "Technical Specs"),
                      ],
                    ),

                    // Tab Views
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildIdentityTab(),
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
  Widget _buildIdentityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location & Parent Linking (Universal across Active, Spare, and Under Maintenance)
          if (_selectedStatus == AssetStatus.spare || _selectedStatus == AssetStatus.underMaintenance) ...[
            TextFormField(
              controller: _spareLocationController,
              decoration: InputDecoration(
                labelText: _selectedStatus == AssetStatus.spare ? 'Spare Storage Location / Rack / Bay *' : 'Workshop / Maintenance Bay Location',
                hintText: _selectedStatus == AssetStatus.spare ? 'e.g. Central Warehouse - Bay 3, Rack A2' : 'e.g. Electrical Maintenance Bay 1',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(_selectedStatus == AssetStatus.spare ? Icons.warehouse : Icons.build_circle, color: Colors.cyanAccent),
              ),
              validator: (v) {
                if (_selectedStatus == AssetStatus.spare && (v == null || v.trim().isEmpty)) {
                  return 'Please specify spare storage location';
                }
                return null;
              },
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
                  child: Text('${e.name} (${e.id})', overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedParentId = val;
                  if (val != null && !_selectedParentIdsForSpares.contains(val)) {
                    _selectedParentIdsForSpares.add(val);
                  }
                });
              },
              validator: (val) {
                if (_selectedStatus == AssetStatus.active && (val == null || val.isEmpty)) {
                  return 'Please select parent equipment';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
          ],

          // Applicable / Compatible Parent Machines (Available for ANY status!)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.cyan.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedStatus == AssetStatus.active
                          ? 'COMPATIBLE SPARE MACHINES POOL'
                          : 'APPLICABLE / COMPATIBLE MACHINES',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.cyanAccent),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add_link, size: 16, color: Colors.cyanAccent),
                      label: const Text('Select Machines', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                      onPressed: _showSpareParentsSelector,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _selectedParentIdsForSpares.isEmpty
                    ? const Text('No parent machines linked. Tap "Select Machines" above to assign compatible equipments.',
                        style: TextStyle(fontSize: 11, color: Colors.grey))
                    : Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _selectedParentIdsForSpares.map((pid) {
                          final eq = _masterEquipments.firstWhere(
                            (e) => e.id == pid,
                            orElse: () => MasterEquipmentModel(
                              id: pid,
                              name: pid,
                              plantId: '',
                              unitId: '',
                              locationId: '',
                              area: '',
                              type: 'mechanical',
                              createdAt: DateTime.now(),
                            ),
                          );
                          return Chip(
                            label: Text('${eq.name} (${eq.id})', style: const TextStyle(fontSize: 11)),
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

          // Name (Optional / Auto-generated from specs)
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Asset Name / Tag Description (Optional)',
              hintText: 'Leave blank to auto-generate from rating (e.g. 75kW SCIM)',
              helperText: 'Auto-derived from power, motor type & make if left blank',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),

          // Site Installation Date (For Active Assets at Site)
          if (_selectedStatus == AssetStatus.active) ...[
            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _installationDate ?? DateTime.now(),
                  firstDate: DateTime(1980),
                  lastDate: DateTime(2050),
                );
                if (d != null) setState(() => _installationDate = d);
              },
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Site Installation Date',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_month, color: AppColors.accent),
                ),
                child: Text(
                  _installationDate != null
                      ? '${_installationDate!.day.toString().padLeft(2, '0')}/${_installationDate!.month.toString().padLeft(2, '0')}/${_installationDate!.year}'
                      : 'Tap to set site installation date',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _installationDate != null ? Colors.white : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Make & Model
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _makeController,
                  decoration: const InputDecoration(labelText: 'Manufacturer / Make (Optional)', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _modelController,
                  decoration: const InputDecoration(labelText: 'Model (Optional)', border: OutlineInputBorder()),
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
                  decoration: const InputDecoration(labelText: 'Serial No (Optional)', border: OutlineInputBorder()),
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

          // Direct In-Situ NFC Scanning
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
                onPressed: _startInSituNfcScan,
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),

          // PO Number & Image URL
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _poController,
                  decoration: const InputDecoration(labelText: 'Purchase Order (PO) No', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _imageController,
                  decoration: const InputDecoration(labelText: 'Image URL', border: OutlineInputBorder()),
                ),
              ),
            ],
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

  // Standard Industrial Motor Dropdown Lists
  static const List<String> _motorTypeOptions = [
    'Squirrel Cage Induction Motor (SCIM)',
    'Slip Ring Induction Motor (SRIM)',
    'Synchronous Motor',
    'Permanent Magnet Motor (PMSM)',
    'DC Shunt / Series Motor',
    'Single Phase Motor',
    'Flameproof / Ex-Proof Motor',
    'Other / Custom',
  ];

  static const List<String> _dutyCycleOptions = [
    'S1 Continuous',
    'S2 Short-time',
    'S3 Intermittent',
    'S4 Intermittent with Starting',
    'S6 Continuous Periodic',
    'S8 Periodic with Speed/Load Changes',
  ];

  static const List<String> _insulationClassOptions = [
    'Class F',
    'Class H',
    'Class B',
    'Class A',
    'Class C',
  ];

  static const List<String> _efficiencyClassOptions = [
    'IE4 Super Premium',
    'IE3 Premium',
    'IE2 High',
    'IE1 Standard',
    'Non-Standard / Legacy',
  ];

  static const List<String> _ipRatingOptions = [
    'IP55',
    'IP56',
    'IP65',
    'IP66',
    'IP23',
    'IP67',
  ];

  static const List<String> _mountingTypeOptions = [
    'B3 Foot Mounted',
    'B5 Flange Mounted',
    'B35 Foot & Flange Mounted',
    'V1 Vertical Flange Mounted',
    'V5 Vertical Foot Mounted',
    'B14 Face Mounted',
  ];  static const List<String> _couplingTypeOptions = [
    'Flexible Pin-Bush',
    'Tyre Coupling',
    'Gear Coupling',
    'Fluid / Hydraulic',
    'Spider / Star (Jaw)',
    'Grid Coupling',
    'Rigid / Flanged Sleeve',
    'Direct Driven / Solid',
  ];

  // Standard Industrial Brake Dropdown Lists
  static const List<String> _brakeTypeOptions = [
    'AC Electro-Hydraulic Thruster (EHT) Brake',
    'DC Electromagnetic Disc Brake',
    'DC Solenoid Drum Brake',
    'Fail-Safe Spring Applied DC Brake',
    'Pneumatic Disc Brake',
    'Hydraulic Caliper Disc Brake',
    'Other / Custom',
  ];

  static const List<String> _voltageTypeOptions = [
    'AC',
    'DC',
  ];

  static const List<String> _drumInstallationOptions = [
    '1-M 1-GB (Dual Drive)',
    'Motor Shaft (M)',
    'Gearbox Input Shaft (GB)',
    'Direct Coupling Mounted',
    'NA / Standalone',
  ];

  static const List<String> _mountingBoltSizeOptions = [
    'M10',
    'M12',
    'M16',
    'M20',
    'M24',
    'M30',
  ];

  static const List<String> _thrusterCapacityOptions = [
    '18 kg (180 N)',
    '23 kg (230 N - Ed 23/5)',
    '30 kg (300 N - Ed 30/5)',
    '34 kg (340 N)',
    '50 kg (500 N - Ed 50/6)',
    '80 kg (800 N - Ed 80/6)',
    '125 kg (1250 N - Ed 121/6)',
    '200 kg (2000 N - Ed 201/6)',
    '300 kg (3000 N - Ed 301/6)',
    'NA (Electromagnetic)',
  ];

  // Standard Industrial Actuator Dropdown Lists
  static const List<String> _actuatorTypeOptions = [
    'Electric Multi-Turn Actuator (Rotork IQ / Auma SA)',
    'Electric Part-Turn / Quarter-Turn (Rotork IQT / Auma SG)',
    'Pneumatic Single-Acting (Spring Return)',
    'Pneumatic Double-Acting',
    'Electro-Hydraulic Actuator',
    'Hydraulic Cylinder Actuator',
    'Linear Electric Actuator',
  ];

  static const List<String> _controlSignalOptions = [
    '4-20 mA Analog (Modulating / Inching)',
    'ON-OFF (24V DC / 110V AC Command)',
    'Profibus DP',
    'Modbus RTU',
    'HART Protocol',
    'Foundation Fieldbus',
  ];

  static const List<String> _valveTypeOptions = [
    'Butterfly Valve',
    'Gate Valve',
    'Knife Gate Valve',
    'Ball Valve',
    'Globe Valve',
    'Louver / Guillotine Damper',
    'Hopper Sector Gate',
    'Control Valve',
  ];

  static const List<String> _valveFlangeOptions = [
    'ISO 5211 - F05 / F07',
    'ISO 5211 - F10 / F12',
    'ISO 5211 - F14 / F16',
    'ISO 5211 - F25 / F30',
    'ISO 5210 (Multi-Turn)',
    'Custom Flange',
  ];

  Widget _buildDropdownSelectionField({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
    String? hint,
  }) {
    final List<String> effectiveOptions = List<String>.from(options);
    if (value.isNotEmpty && !effectiveOptions.contains(value)) {
      effectiveOptions.insert(0, value);
    }

    return DropdownButtonFormField<String>(
      value: (value.isNotEmpty && effectiveOptions.contains(value)) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      isExpanded: true,
      items: effectiveOptions.map((opt) {
        return DropdownMenuItem(
          value: opt,
          child: Text(opt, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) {
          onChanged(val);
        }
      },
    );
  }

  // --- TAB 2: TECHNICAL SPECIFICATIONS (CUSTOM PER ASSET TYPE) ---
  Widget _buildSpecsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. MOTOR SPECIFICATIONS
          if (_selectedType == AssetType.motor) ...[
            const Text('Motor Electrical & Mechanical Specifications',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accent)),
            const SizedBox(height: 10),

            // Motor Sub-Type Dropdown
            _buildDropdownSelectionField(
              label: 'Motor Type / Technology',
              value: _motorTypeController.text,
              options: _motorTypeOptions,
              onChanged: (val) => setState(() => _motorTypeController.text = val),
              hint: 'Select Motor Type',
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _powerController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Rated Power (kW) *', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _voltageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Rated Voltage (V) *',
                      hintText: 'e.g. 415 / 690 / 3300',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _flcCurrentController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'FLC (Amps) *', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _noLoadCurrentController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'No Load Current (A)', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _speedController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Rated Speed (RPM) *', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _polesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Poles (e.g. 2, 4, 6, 8)', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _frequencyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Frequency (Hz)', hintText: '50', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _pfController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Power Factor (cos φ)', hintText: '0.88', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _efficiencyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Efficiency (%)', hintText: '95.2', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _frameController,
                    decoration: const InputDecoration(labelText: 'Frame Size', hintText: 'e.g. 280M / 160L', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Mounting & Grease
            Row(
              children: [
                Expanded(
                  child: _buildDropdownSelectionField(
                    label: 'Mounting Type',
                    value: _mountingController.text,
                    options: _mountingTypeOptions,
                    onChanged: (val) => setState(() => _mountingController.text = val),
                    hint: 'Select Mounting',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _motorGreaseTypeController,
                    decoration: const InputDecoration(labelText: 'Grease Type / Grade', hintText: 'e.g. Mobilith SHC 100', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Duty Cycle & Insulation Class Dropdowns
            Row(
              children: [
                Expanded(
                  child: _buildDropdownSelectionField(
                    label: 'Duty Cycle',
                    value: _dutyCycleController.text,
                    options: _dutyCycleOptions,
                    onChanged: (val) => setState(() => _dutyCycleController.text = val),
                    hint: 'Select Duty',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdownSelectionField(
                    label: 'Insulation Class',
                    value: _insulationClassController.text,
                    options: _insulationClassOptions,
                    onChanged: (val) => setState(() => _insulationClassController.text = val),
                    hint: 'Select Insulation',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Efficiency Class & IP Rating Dropdowns
            Row(
              children: [
                Expanded(
                  child: _buildDropdownSelectionField(
                    label: 'Efficiency Class',
                    value: _efficiencyClassController.text,
                    options: _efficiencyClassOptions,
                    onChanged: (val) => setState(() => _efficiencyClassController.text = val),
                    hint: 'Select Class',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdownSelectionField(
                    label: 'IP Rating (Enclosure)',
                    value: _ipRatingController.text,
                    options: _ipRatingOptions,
                    onChanged: (val) => setState(() => _ipRatingController.text = val),
                    hint: 'Select IP',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Coupling Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Coupler / Coupling Available',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('YES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            selected: _couplingAvailable == 'YES',
                            onSelected: (val) {
                              if (val) setState(() => _couplingAvailable = 'YES');
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('NO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            selected: _couplingAvailable == 'NO',
                            onSelected: (val) {
                              if (val) setState(() => _couplingAvailable = 'NO');
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_couplingAvailable == 'YES') ...[
                    const SizedBox(height: 10),
                    _buildDropdownSelectionField(
                      label: 'Coupling Type',
                      value: _couplingTypeController.text,
                      options: _couplingTypeOptions,
                      onChanged: (val) => setState(() => _couplingTypeController.text = val),
                      hint: 'Select Coupling Type',
                    ),
                  ],
                ],
              ),
            ),
          ]

          // 2. GEARBOX SPECIFICATIONS
          else if (_selectedType == AssetType.gearbox) ...[
            const Text('Gearbox Transmission & Lubrication Specifications',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accent)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _gearboxPowerController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Input Power Rating (kW) *', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _gearRatioController,
                    decoration: const InputDecoration(labelText: 'Gear Ratio (e.g. 25:1) *', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _inputSpeedController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Input Speed (RPM)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _outputSpeedController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Output Speed (RPM)', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _oilTypeController,
                    decoration: const InputDecoration(labelText: 'Oil Grade (VG 320 / 460) *', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _oilCapacityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Oil Sump Capacity (Liters)', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _inputShaftController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Input Shaft Ø (mm)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _outputShaftController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Output Shaft Ø (mm)', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _lubricationMethodController,
                    decoration: const InputDecoration(labelText: 'Lubrication (Splash / Forced)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _gearboxMountingController,
                    decoration: const InputDecoration(labelText: 'Mounting (Horizontal / Vertical)', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
          ]

          // 3. PUMP SPECIFICATIONS
          else if (_selectedType == AssetType.pump) ...[
            const Text('Pump Hydraulic & Mechanical Specifications',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accent)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _flowRateController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Flow Rate / Capacity (m³/hr) *', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _headController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Total Head (Meters) *', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _pumpSpeedController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Pump Speed (RPM)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _pumpPowerController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Pump Shaft Power (kW)', border: OutlineInputBorder()),
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
                    decoration: const InputDecoration(labelText: 'Impeller Diameter (mm)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _sealTypeController,
                    decoration: const InputDecoration(labelText: 'Seal Type (Mechanical / Gland)', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _suctionFlangeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Suction Flange Ø (mm)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _dischargeFlangeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Discharge Flange Ø (mm)', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _casingMaterialController,
                    decoration: const InputDecoration(labelText: 'Casing Material (CI / SS / Bronze)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _pumpGreaseTypeController,
                    decoration: const InputDecoration(labelText: 'Grease / Lubricant Grade', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
          ]

          // 4. BRAKE SPECIFICATIONS (DC Electromagnetic / AC Thruster EHT)
          else if (_selectedType == AssetType.brake) ...[
            const Text('Brake Operating & Mounting Specifications',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accent)),
            const SizedBox(height: 10),

            // Brake Type Dropdown
            _buildDropdownSelectionField(
              label: 'Brake Technology / Type *',
              value: _brakeTypeController.text,
              options: _brakeTypeOptions,
              onChanged: (val) => setState(() => _brakeTypeController.text = val),
              hint: 'Select Brake Type',
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildDropdownSelectionField(
                    label: 'Voltage Type',
                    value: _brakeVoltageTypeController.text,
                    options: _voltageTypeOptions,
                    onChanged: (val) => setState(() => _brakeVoltageTypeController.text = val),
                    hint: 'AC / DC',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _brakeVoltageRatingController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Voltage Rating (V) *',
                      hintText: 'e.g. 110 / 415 / 190 / 220',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildDropdownSelectionField(
                    label: 'Thruster Capacity',
                    value: _thrusterCapacityController.text.isNotEmpty ? '${_thrusterCapacityController.text} kg' : '',
                    options: _thrusterCapacityOptions,
                    onChanged: (val) {
                      final numStr = RegExp(r'(\d+)').firstMatch(val)?.group(1) ?? '';
                      setState(() => _thrusterCapacityController.text = numStr);
                    },
                    hint: 'Thruster (kg / N)',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _brakingTorqueController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Braking Torque (Nm)', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Drum Specifications
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _drumDiaController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Drum / Disc Diameter (mm) *', hintText: 'e.g. 200 / 250 / 300 / 400', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _drumWidthController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Drum Width (mm)', hintText: 'e.g. 100 / 120 / 150', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Drum Installation Location
            _buildDropdownSelectionField(
              label: 'Drum Installation Location',
              value: _drumInstallationController.text,
              options: _drumInstallationOptions,
              onChanged: (val) => setState(() => _drumInstallationController.text = val),
              hint: 'e.g. Motor Shaft / Gearbox Input',
            ),
            const SizedBox(height: 12),

            // Mounting Details
            Row(
              children: [
                Expanded(
                  child: _buildDropdownSelectionField(
                    label: 'Mounting Bolt Size',
                    value: _mountingBoltSizeController.text,
                    options: _mountingBoltSizeOptions,
                    onChanged: (val) => setState(() => _mountingBoltSizeController.text = val),
                    hint: 'e.g. M12',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _mountingBoltCountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'No. of Mounting Bolts', hintText: '4 / 6 / 8', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _mountingLengthController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Mounting Length (mm)', hintText: 'e.g. 350 / 490 / 680', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _mountingWidthController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Mounting Width (mm)', hintText: 'e.g. 65 / 120 / 165', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _brakeShoeLiningController,
              decoration: const InputDecoration(labelText: 'Brake Shoe Lining Material / Notes', hintText: 'e.g. Organic Non-Asbestos / Semi-Metallic', border: OutlineInputBorder()),
            ),
          ]

          // 5. ACTUATOR SPECIFICATIONS (Electric / Pneumatic / Hydraulic)
          else if (_selectedType == AssetType.actuator) ...[
            const Text('Actuator Automation & Valve Specifications',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accent)),
            const SizedBox(height: 10),

            _buildDropdownSelectionField(
              label: 'Actuator Technology / Type *',
              value: _actuatorTypeController.text,
              options: _actuatorTypeOptions,
              onChanged: (val) => setState(() => _actuatorTypeController.text = val),
              hint: 'Select Actuator Type',
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _torqueOrThrustController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Output Torque / Thrust (Nm / kN)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _operatingTimeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Operating Time (Seconds)', hintText: 'e.g. 15 / 30s', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _buildDropdownSelectionField(
              label: 'Control Signal / Protocol',
              value: _controlSignalController.text,
              options: _controlSignalOptions,
              onChanged: (val) => setState(() => _controlSignalController.text = val),
              hint: 'e.g. 4-20mA Modulating',
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildDropdownSelectionField(
                    label: 'Valve / Damper Type',
                    value: _valveTypeController.text,
                    options: _valveTypeOptions,
                    onChanged: (val) => setState(() => _valveTypeController.text = val),
                    hint: 'Select Valve Type',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _valveSizeController,
                    decoration: const InputDecoration(labelText: 'Valve Size (DN / Inch)', hintText: 'e.g. DN 200 / 8"', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _buildDropdownSelectionField(
              label: 'Valve Mounting Flange (ISO)',
              value: _valveFlangeStandardController.text,
              options: _valveFlangeOptions,
              onChanged: (val) => setState(() => _valveFlangeStandardController.text = val),
              hint: 'e.g. ISO 5211 (F10 / F12)',
            ),
          ],
          const SizedBox(height: 16),

          // Common Bearing Specifications
          if (_selectedType == AssetType.motor || _selectedType == AssetType.gearbox || _selectedType == AssetType.pump) ...[
            const Text('Bearing Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accent)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _bearingDEController,
                    decoration: const InputDecoration(labelText: 'Drive End (DE) Bearing (e.g. 6314 C3)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _bearingNDEController,
                    decoration: const InputDecoration(labelText: 'Non-Drive End (NDE) Bearing (e.g. 6312 C3)', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}
