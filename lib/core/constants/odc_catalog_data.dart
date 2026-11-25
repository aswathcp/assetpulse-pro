class OdcItem {
  final String discipline;
  final String equipmentCategory;
  final String objectCode;
  final String objectName;
  final String damageCode;
  final String damageName;
  final String causeCode;
  final String causeName;
  final String isoCode;
  final String defaultSeverity;
  final String recommendedAction;

  const OdcItem({
    required this.discipline,
    required this.equipmentCategory,
    required this.objectCode,
    required this.objectName,
    required this.damageCode,
    required this.damageName,
    required this.causeCode,
    required this.causeName,
    required this.isoCode,
    required this.defaultSeverity,
    required this.recommendedAction,
  });
}

class OdcCatalogData {
  static const List<OdcItem> allCatalog = [
    // --- ELECTRICAL: MOTORS ---
    OdcItem(
      discipline: 'electrical',
      equipmentCategory: 'Electric Motor',
      objectCode: 'MOT-BRG-DE',
      objectName: 'Drive-End (DE) Bearing',
      damageCode: 'DMG-VIB',
      damageName: 'High Vibration & Abnormal Noise',
      causeCode: 'CAU-LUB-STARV',
      causeName: 'Lack of Lubrication / Grease Starvation',
      isoCode: 'M-1.1',
      defaultSeverity: 'high',
      recommendedAction: 'Purge old grease, refill with Mobilgrease 28 to OEM spec',
    ),
    OdcItem(
      discipline: 'electrical',
      equipmentCategory: 'Electric Motor',
      objectCode: 'MOT-BRG-DE',
      objectName: 'Drive-End (DE) Bearing',
      damageCode: 'DMG-TEMP',
      damageName: 'Overheating (>90°C)',
      causeCode: 'CAU-LUB-OVER',
      causeName: 'Over-Greasing / Churning Friction',
      isoCode: 'M-1.2',
      defaultSeverity: 'high',
      recommendedAction: 'Remove drain plug, run motor 30 mins to expel excess grease',
    ),
    OdcItem(
      discipline: 'electrical',
      equipmentCategory: 'Electric Motor',
      objectCode: 'MOT-BRG-DE',
      objectName: 'Drive-End (DE) Bearing',
      damageCode: 'DMG-SZ',
      damageName: 'Bearing Seizure / Locked Rotor',
      causeCode: 'CAU-BRG-FATG',
      causeName: 'Spalling / Fatigue from Dynamic Misalignment',
      isoCode: 'M-1.3',
      defaultSeverity: 'critical',
      recommendedAction: 'Replace bearing, laser-align shaft to <0.05mm',
    ),
    OdcItem(
      discipline: 'electrical',
      equipmentCategory: 'Electric Motor',
      objectCode: 'MOT-BRG-NDE',
      objectName: 'Non-Drive-End (NDE) Bearing',
      damageCode: 'DMG-VIB',
      damageName: 'Abnormal Squealing & Cage Rattle',
      causeCode: 'CAU-LUB-CONTAM',
      causeName: 'Contamination (Dust / Moisture Ingress)',
      isoCode: 'M-1.4',
      defaultSeverity: 'medium',
      recommendedAction: 'Replace NDE bearing, renew V-ring dust seal',
    ),
    OdcItem(
      discipline: 'electrical',
      equipmentCategory: 'Electric Motor',
      objectCode: 'MOT-WND-ST',
      objectName: 'Stator Winding',
      damageCode: 'DMG-BRN',
      damageName: 'Burnt Winding / Insulation Breakdown',
      causeCode: 'CAU-ELEC-SPH',
      causeName: 'Single Phasing / Supply Phase Loss',
      isoCode: 'E-2.1',
      defaultSeverity: 'critical',
      recommendedAction: 'Rewind stator with Class H insulation; inspect contactor',
    ),
    OdcItem(
      discipline: 'electrical',
      equipmentCategory: 'Electric Motor',
      objectCode: 'MOT-WND-ST',
      objectName: 'Stator Winding',
      damageCode: 'DMG-EF',
      damageName: 'Earth Fault / Low IR (<1 MΩ)',
      causeCode: 'CAU-ENV-MOIST',
      causeName: 'Moisture & Condensation Ingress',
      isoCode: 'E-2.2',
      defaultSeverity: 'high',
      recommendedAction: 'Bake winding with halogen heater, apply varnish, check space heater',
    ),
    OdcItem(
      discipline: 'electrical',
      equipmentCategory: 'Electric Motor',
      objectCode: 'MOT-TB-LUG',
      objectName: 'Terminal Box & Studs',
      damageCode: 'DMG-FLSH',
      damageName: 'Flashover / Burnt Power Terminal',
      causeCode: 'CAU-ELEC-LOOS',
      causeName: 'Loose Cable Lug / High Contact Resistance',
      isoCode: 'E-3.1',
      defaultSeverity: 'critical',
      recommendedAction: 'Crimp heavy-duty bimetallic lugs, torque studs with torque wrench',
    ),
    OdcItem(
      discipline: 'electrical',
      equipmentCategory: 'Electric Motor',
      objectCode: 'MOT-FAN',
      objectName: 'Cooling Fan & Cowl',
      damageCode: 'DMG-BRK',
      damageName: 'Fan Blade Broken / Damaged',
      causeCode: 'CAU-EXT-IMPT',
      causeName: 'Foreign Object Ingress / Impact',
      isoCode: 'M-2.1',
      defaultSeverity: 'medium',
      recommendedAction: 'Replace cooling fan blade and secure cowl guard',
    ),

    // --- ELECTRICAL: POWER TRANSFORMERS ---
    OdcItem(
      discipline: 'electrical',
      equipmentCategory: 'Power Transformer',
      objectCode: 'TRF-BSH-HV',
      objectName: 'HV Bushing (11kV / 33kV)',
      damageCode: 'DMG-CRK',
      damageName: 'Hairline Crack / Tracking Flashover',
      causeCode: 'CAU-ENV-POLL',
      causeName: 'Surface Pollution & High Humidity',
      isoCode: 'E-4.1',
      defaultSeverity: 'critical',
      recommendedAction: 'De-energize, clean and dry bushing, replace cracked bushing',
    ),
    OdcItem(
      discipline: 'electrical',
      equipmentCategory: 'Power Transformer',
      objectCode: 'TRF-OIL-DK',
      objectName: 'Transformer Mineral Oil',
      damageCode: 'DMG-BDV',
      damageName: 'Low Dielectric BDV (<30 kV)',
      causeCode: 'CAU-OIL-MOIST',
      causeName: 'Moisture Absorption & Sludge Degradation',
      isoCode: 'E-4.3',
      defaultSeverity: 'high',
      recommendedAction: 'Vacuum oil filtration / dehydration until BDV > 60 kV',
    ),
    OdcItem(
      discipline: 'electrical',
      equipmentCategory: 'Power Transformer',
      objectCode: 'TRF-BCH-RL',
      objectName: 'Buchholz Relay',
      damageCode: 'DMG-GAS',
      damageName: 'Gas Collection / Alarm Trip',
      causeCode: 'CAU-INT-ARC',
      causeName: 'Internal Incipient Arcing / Hotspot Pyrolysis',
      isoCode: 'E-4.4',
      defaultSeverity: 'critical',
      recommendedAction: 'Collect gas sample for DGA (Dissolved Gas Analysis)',
    ),
    OdcItem(
      discipline: 'electrical',
      equipmentCategory: 'Power Transformer',
      objectCode: 'TRF-BRTH-SL',
      objectName: 'Silica Gel Breather',
      damageCode: 'DMG-SAT',
      damageName: 'Silica Gel Saturated (Pink)',
      causeCode: 'CAU-OIL-SEAL',
      causeName: 'Oil Cup Seal Empty / Atmospheric Air Leak',
      isoCode: 'M-4.1',
      defaultSeverity: 'medium',
      recommendedAction: 'Replace pink silica gel with fresh blue beads, top up oil cup',
    ),

    // --- ELECTRICAL: SWITCHGEAR & BREAKERS ---
    OdcItem(
      discipline: 'electrical',
      equipmentCategory: 'Switchgear & VCB',
      objectCode: 'SWG-VCB-BOT',
      objectName: 'Vacuum Interrupter Bottle',
      damageCode: 'DMG-VAC',
      damageName: 'Loss of Vacuum / Contact Arcing',
      causeCode: 'CAU-CYC-LIFE',
      causeName: 'Vacuum Bellows Micro-Leak after Life Expiry',
      isoCode: 'E-5.1',
      defaultSeverity: 'critical',
      recommendedAction: 'Perform high-pot vacuum integrity test; replace bottle',
    ),
    OdcItem(
      discipline: 'electrical',
      equipmentCategory: 'Switchgear & VCB',
      objectCode: 'SWG-TRP-CL',
      objectName: 'Trip Coil / Shunt Release',
      damageCode: 'DMG-OPEN',
      damageName: 'Trip Coil Open Circuit / Burnt',
      causeCode: 'CAU-COIL-CONT',
      causeName: 'Continuous DC Energization due to Stuck Aux Switch',
      isoCode: 'E-5.2',
      defaultSeverity: 'critical',
      recommendedAction: 'Replace 110V DC trip coil; replace 52a/52b aux switch',
    ),
    OdcItem(
      discipline: 'electrical',
      equipmentCategory: 'Switchgear & VCB',
      objectCode: 'SWG-BUS-JNT',
      objectName: 'Busbar Joint (PCC/MCC)',
      damageCode: 'DMG-HOT',
      damageName: 'Thermal Hotspot (>110°C on Thermography)',
      causeCode: 'CAU-TORQ-LOSS',
      causeName: 'Loose Belleville Washer / Plating Oxidation',
      isoCode: 'E-5.3',
      defaultSeverity: 'critical',
      recommendedAction: 'Wire-brush joint, apply silver contact grease, retorque to 55 Nm',
    ),

    // --- MECHANICAL: PUMPS ---
    OdcItem(
      discipline: 'mechanical',
      equipmentCategory: 'Centrifugal Pump',
      objectCode: 'PMP-IMP-SL',
      objectName: 'Pump Impeller',
      damageCode: 'DMG-CAV',
      damageName: 'Impeller Vane Cavitation Pitting',
      causeCode: 'CAU-HYD-NPSH',
      causeName: 'Inadequate NPSH / Starved Suction Strainer',
      isoCode: 'M-6.1',
      defaultSeverity: 'high',
      recommendedAction: 'Replace impeller with High Chrome; clean suction strainer',
    ),
    OdcItem(
      discipline: 'mechanical',
      equipmentCategory: 'Centrifugal Pump',
      objectCode: 'PMP-SEAL-MC',
      objectName: 'Mechanical Seal',
      damageCode: 'DMG-LEAK',
      damageName: 'Continuous Slurry / Water Leakage',
      causeCode: 'CAU-SEAL-FACE',
      causeName: 'Silicon Carbide Face Scored by Abrasive Slurry',
      isoCode: 'M-6.2',
      defaultSeverity: 'high',
      recommendedAction: 'Replace mechanical seal cartridge; flush quench water line',
    ),
    OdcItem(
      discipline: 'mechanical',
      equipmentCategory: 'Centrifugal Pump',
      objectCode: 'PMP-SLV-SFT',
      objectName: 'Shaft Sleeve',
      damageCode: 'DMG-WEAR',
      damageName: 'Deep Grooving under Gland Packing',
      causeCode: 'CAU-PCK-TIGHT',
      causeName: 'Over-Tightened PTFE Packing without Drops',
      isoCode: 'M-6.3',
      defaultSeverity: 'medium',
      recommendedAction: 'Replace ceramic-coated sleeve; repack with graphite packing',
    ),
    OdcItem(
      discipline: 'mechanical',
      equipmentCategory: 'Centrifugal Pump',
      objectCode: 'PMP-CAS-VOL',
      objectName: 'Pump Casing / Volute',
      damageCode: 'DMG-THIN',
      damageName: 'Severe Wall Thinning (<3mm residual)',
      causeCode: 'CAU-ABR-WEAR',
      causeName: 'Erosive Slurry Velocity / Acidic Attack',
      isoCode: 'M-6.4',
      defaultSeverity: 'critical',
      recommendedAction: 'UT thickness gauge; replace casing or coat with ceramic epoxy',
    ),

    // --- MECHANICAL: GEARBOXES ---
    OdcItem(
      discipline: 'mechanical',
      equipmentCategory: 'Industrial Gearbox',
      objectCode: 'GBX-PIN-IN',
      objectName: 'Input Pinion Gear',
      damageCode: 'DMG-PITT',
      damageName: 'Surface Pitting / Micropitting on Tooth Face',
      causeCode: 'CAU-OIL-VISC',
      causeName: 'Low Oil Viscosity / Degraded EP Additive',
      isoCode: 'M-7.1',
      defaultSeverity: 'high',
      recommendedAction: 'Flush housing, refill with ISO VG 320 synthetic gear oil',
    ),
    OdcItem(
      discipline: 'mechanical',
      equipmentCategory: 'Industrial Gearbox',
      objectCode: 'GBX-WHL-OUT',
      objectName: 'Output Bull Gear',
      damageCode: 'DMG-TOOTH',
      damageName: 'Broken Tooth / Chipped Tip',
      causeCode: 'CAU-SHK-LOAD',
      causeName: 'Heavy Shock Load / Crusher Feed Jam',
      isoCode: 'M-7.2',
      defaultSeverity: 'critical',
      recommendedAction: 'Replace matched gearset; inspect crusher shear toggle plate',
    ),
    OdcItem(
      discipline: 'mechanical',
      equipmentCategory: 'Industrial Gearbox',
      objectCode: 'GBX-SEAL-OIL',
      objectName: 'Input / Output Oil Seal',
      damageCode: 'DMG-LEAK',
      damageName: 'Heavy Oil Leakage around Shaft',
      causeCode: 'CAU-SEAL-HARD',
      causeName: 'Viton Lip Seal Hardened by Heat',
      isoCode: 'M-7.3',
      defaultSeverity: 'medium',
      recommendedAction: 'Replace Viton double-lip oil seal; polish shaft seal track',
    ),

    // --- MECHANICAL: CONVEYORS ---
    OdcItem(
      discipline: 'mechanical',
      equipmentCategory: 'Belt Conveyor',
      objectCode: 'CNV-BLT-RUB',
      objectName: 'Conveyor Rubber Belt',
      damageCode: 'DMG-TEAR',
      damageName: 'Longitudinal Belt Rip / Slit',
      causeCode: 'CAU-TRP-IRON',
      causeName: 'Tramp Iron / Chute Liner Piercing Belt',
      isoCode: 'M-8.1',
      defaultSeverity: 'critical',
      recommendedAction: 'Cold vulcanizing patch repair; inspect overband tramp magnet',
    ),
    OdcItem(
      discipline: 'mechanical',
      equipmentCategory: 'Belt Conveyor',
      objectCode: 'CNV-IDL-ROL',
      objectName: 'Idler Roller',
      damageCode: 'DMG-SZ',
      damageName: 'Roller Seized / Shell Knife-Cut',
      causeCode: 'CAU-IDL-BRG',
      causeName: 'Internal Bearing Seizure from Fine Dust',
      isoCode: 'M-8.2',
      defaultSeverity: 'high',
      recommendedAction: 'Replace seized roller to prevent conveyor belt underside wear',
    ),
    OdcItem(
      discipline: 'mechanical',
      equipmentCategory: 'Belt Conveyor',
      objectCode: 'CNV-PLY-DRV',
      objectName: 'Drive Head Pulley',
      damageCode: 'DMG-LAG',
      damageName: 'Pulley Ceramic Lagging Debonded',
      causeCode: 'CAU-LAG-WEAR',
      causeName: 'Severe Belt Slip under Wet Starting Conditions',
      isoCode: 'M-8.3',
      defaultSeverity: 'high',
      recommendedAction: 'Re-lag drive pulley with cold-bonded ceramic lagging',
    ),

    // --- INSTRUMENTATION & AUTOMATION ---
    OdcItem(
      discipline: 'instrumentation',
      equipmentCategory: 'Field Transmitter',
      objectCode: 'INS-XMT-DPS',
      objectName: 'Differential Pressure Transmitter',
      damageCode: 'DMG-ZERO',
      damageName: 'Zero Shift / Unstable Reading',
      causeCode: 'CAU-IMP-CHOK',
      causeName: 'Impulse Sensing Line Clogged with Slurry',
      isoCode: 'I-1.1',
      defaultSeverity: 'medium',
      recommendedAction: 'Purge impulse line with water/air; recalibrate transmitter zero',
    ),
    OdcItem(
      discipline: 'instrumentation',
      equipmentCategory: 'Temperature Sensor',
      objectCode: 'INS-RTD-EL',
      objectName: 'RTD Pt100 Sensor',
      damageCode: 'DMG-OPEN',
      damageName: 'Open Loop / Showing 850°C Max',
      causeCode: 'CAU-WIR-VIB',
      causeName: 'Lead Wire Snapped Due to Heavy Vibration',
      isoCode: 'I-1.2',
      defaultSeverity: 'high',
      recommendedAction: 'Replace mineral-insulated 3-wire RTD probe; damp flex conduit',
    ),
    OdcItem(
      discipline: 'instrumentation',
      equipmentCategory: 'Control Valve',
      objectCode: 'INS-POS-ELP',
      objectName: 'Smart Valve Positioner',
      damageCode: 'DMG-CAL',
      damageName: 'Valve Hunting / Fails to Reach 100% Stroke',
      causeCode: 'CAU-AIR-DIRT',
      causeName: 'Instrument Air Filter Regulator Contaminated',
      isoCode: 'I-2.1',
      defaultSeverity: 'high',
      recommendedAction: 'Drain air filter regulator; clean nozzle-flapper; run autotune',
    ),
    OdcItem(
      discipline: 'instrumentation',
      equipmentCategory: 'PLC & Control',
      objectCode: 'AUT-PLC-DI',
      objectName: 'PLC Digital Input Module (24VDC)',
      damageCode: 'DMG-CHN',
      damageName: 'Channel Blown / LED Off during Signal',
      causeCode: 'CAU-24V-SURG',
      causeName: 'Field 24VDC Short Circuit / Ground Surge',
      isoCode: 'I-3.1',
      defaultSeverity: 'critical',
      recommendedAction: 'Replace 16-channel DI module; verify field isolator barrier & fuse',
    ),
  ];

  /// Get distinct Object Parts, optionally filtered by discipline or category
  static List<String> getObjectParts({String? discipline, String? category}) {
    var items = allCatalog;
    if (discipline != null && discipline.isNotEmpty) {
      items = items.where((i) => i.discipline.toLowerCase() == discipline.toLowerCase()).toList();
    }
    if (category != null && category.isNotEmpty) {
      items = items.where((i) => i.equipmentCategory.toLowerCase().contains(category.toLowerCase())).toList();
    }
    return items.map((i) => i.objectName).toSet().toList();
  }

  /// Get Damages for a selected Object Part (or all damages if none selected)
  static List<String> getDamagesForObject(String? objectName) {
    if (objectName == null || objectName.isEmpty) {
      return allCatalog.map((i) => i.damageName).toSet().toList();
    }
    final filtered = allCatalog.where((i) => i.objectName.toLowerCase() == objectName.toLowerCase()).map((i) => i.damageName).toSet().toList();
    if (filtered.isNotEmpty) return filtered;
    return allCatalog.map((i) => i.damageName).toSet().toList();
  }

  /// Get Causes for a selected Damage (or all causes if none selected)
  static List<String> getCausesForDamage(String? damageName) {
    if (damageName == null || damageName.isEmpty) {
      return allCatalog.map((i) => i.causeName).toSet().toList();
    }
    final filtered = allCatalog.where((i) => i.damageName.toLowerCase() == damageName.toLowerCase()).map((i) => i.causeName).toSet().toList();
    if (filtered.isNotEmpty) return filtered;
    return allCatalog.map((i) => i.causeName).toSet().toList();
  }
}
