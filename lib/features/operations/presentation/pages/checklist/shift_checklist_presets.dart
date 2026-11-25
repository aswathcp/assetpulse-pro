import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

/// Asset & equipment checklist preset based directly on plant configuration.
class StandardChecklistPreset {
  final String key;
  final String name;
  final String category;
  final String checklistTypeKey;
  final String description;
  final bool isLocationRequired;
  final List<Map<String, dynamic>> fields;

  const StandardChecklistPreset({
    required this.key,
    required this.name,
    required this.category,
    required this.checklistTypeKey,
    required this.description,
    this.isLocationRequired = false,
    required this.fields,
  });

  Map<String, dynamic> toCustomChecklistMap({
    required String plantId,
    required String unitId,
    required String businessId,
    double latitude = 0.0,
    double longitude = 0.0,
  }) {
    return {
      'id': const Uuid().v4(),
      'name': name,
      'checklistTypeKey': checklistTypeKey,
      'plantId': plantId,
      'unitId': unitId,
      'businessId': businessId,
      'isLocationRequired': isLocationRequired,
      'latitude': latitude,
      'longitude': longitude,
      'fields': fields,
      'category': category,
      'description': description,
      'presetKey': key,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }
}

/// Exact standard unit checklist presets corresponding directly to plant configuration.
const List<StandardChecklistPreset> kStandardUnitChecklistPresets = [
  // ─── Section 0: Personnel Details ─────────────────────────────────────
  StandardChecklistPreset(
    key: 'section0_personnel',
    name: 'Personnel Details',
    category: 'Personnel',
    checklistTypeKey: 'personnel',
    description: 'Shift duty engineer, electrician, superintendents & technicians.',
    fields: [
      {'name': 'Shift Engineer', 'type': 'text'},
      {'name': 'Electrician', 'type': 'text'},
      {'name': 'Shift Superintendent', 'type': 'text'},
      {'name': 'BF1 Control Room', 'type': 'text'},
      {'name': 'BF2 Control Room', 'type': 'text'},
      {'name': 'Mechanical Engineer', 'type': 'text'},
      {'name': 'Instrumentation Technician', 'type': 'text'},
    ],
  ),

  // ─── Section 1: Cooling Tower Pumps (CTP) ────────────────────────────
  StandardChecklistPreset(
    key: 'section1_ctp',
    name: 'Cooling Tower Pumps (CTP)',
    category: 'Motor & Pumps',
    checklistTypeKey: 'motor_status',
    description: 'Running status, mode, current, RPM and bearing temperatures for CTP 1–5.',
    fields: [
      {'name': 'CTP-1 Running', 'type': 'toggle', 'options': ['Running', 'Stopped']},
      {'name': 'CTP-1 Mode', 'type': 'toggle', 'options': ['SS', 'VFD']},
      {'name': 'CTP-1 Auto Mode', 'type': 'toggle', 'options': ['Auto', 'Manual', 'Off']},
      {'name': 'CTP-1 Current (A)', 'type': 'numeric'},
      {'name': 'CTP-1 RPM', 'type': 'numeric'},
      {'name': 'CTP-1 PU Temp (°C)', 'type': 'numeric'},
      {'name': 'CTP-1 PM Temp (°C)', 'type': 'numeric'},
      {'name': 'CTP-1 VFD Fan Status', 'type': 'toggle', 'options': ['Running', 'Stopped']},
      {'name': 'CTP-2 Running', 'type': 'toggle', 'options': ['Running', 'Stopped']},
      {'name': 'CTP-2 Mode', 'type': 'toggle', 'options': ['SS', 'VFD']},
      {'name': 'CTP-2 Auto Mode', 'type': 'toggle', 'options': ['Auto', 'Manual', 'Off']},
      {'name': 'CTP-2 Current (A)', 'type': 'numeric'},
      {'name': 'CTP-2 RPM', 'type': 'numeric'},
      {'name': 'CTP-2 PU Temp (°C)', 'type': 'numeric'},
      {'name': 'CTP-2 PM Temp (°C)', 'type': 'numeric'},
      {'name': 'CTP-2 VFD Fan Status', 'type': 'toggle', 'options': ['Running', 'Stopped']},
      {'name': 'CTP-3 Running', 'type': 'toggle', 'options': ['Running', 'Stopped']},
      {'name': 'CTP-3 Current (A)', 'type': 'numeric'},
      {'name': 'CTP-4 Running', 'type': 'toggle', 'options': ['Running', 'Stopped']},
      {'name': 'CTP-4 Current (A)', 'type': 'numeric'},
      {'name': 'CTP-5 Running', 'type': 'toggle', 'options': ['Running', 'Stopped']},
      {'name': 'CTP-5 Current (A)', 'type': 'numeric'},
      {'name': 'CT AC 1 Status', 'type': 'toggle', 'options': ['Running', 'Stopped']},
      {'name': 'CT AC 2 Status', 'type': 'toggle', 'options': ['Running', 'Stopped']},
    ],
  ),

  // ─── Section 2: Return Water Pumps (RWP) ─────────────────────────────
  StandardChecklistPreset(
    key: 'section2_rwp',
    name: 'Return Water Pumps (RWP)',
    category: 'Motor & Pumps',
    checklistTypeKey: 'motor_status',
    description: 'Running status, mode, auto mode and VFD fan for RWP 1–4.',
    fields: [
      {'name': 'RWP-1 Running', 'type': 'toggle', 'options': ['Running', 'Stopped']},
      {'name': 'RWP-1 Mode', 'type': 'toggle', 'options': ['Star-Delta', 'VFD']},
      {'name': 'RWP-1 Auto Mode', 'type': 'toggle', 'options': ['Auto', 'Manual', 'Off']},
      {'name': 'RWP-1 VFD Fan Status', 'type': 'toggle', 'options': ['Running', 'Stopped']},
      {'name': 'RWP-2 Running', 'type': 'toggle', 'options': ['Running', 'Stopped']},
      {'name': 'RWP-2 Mode', 'type': 'toggle', 'options': ['Star-Delta', 'VFD']},
      {'name': 'RWP-2 Auto Mode', 'type': 'toggle', 'options': ['Auto', 'Manual', 'Off']},
      {'name': 'RWP-2 VFD Fan Status', 'type': 'toggle', 'options': ['Running', 'Stopped']},
      {'name': 'RWP-3 Running', 'type': 'toggle', 'options': ['Running', 'Stopped']},
      {'name': 'RWP-4 Running', 'type': 'toggle', 'options': ['Running', 'Stopped']},
    ],
  ),

  // ─── Section 3: Fire Hydrant ──────────────────────────────────────────
  StandardChecklistPreset(
    key: 'section3_fire_hydrant',
    name: 'Fire Hydrant Pumps',
    category: 'Motor & Pumps',
    checklistTypeKey: 'motor_status',
    description: 'Main pump, jockey pump and diesel pump running and auto mode.',
    fields: [
      {'name': 'Main Pump Running', 'type': 'toggle', 'options': ['Running', 'Stopped']},
      {'name': 'Main Pump Auto Mode', 'type': 'toggle', 'options': ['Auto', 'Manual', 'Off']},
      {'name': 'Jockey Pump Running', 'type': 'toggle', 'options': ['Running', 'Stopped']},
      {'name': 'Jockey Pump Auto Mode', 'type': 'toggle', 'options': ['Auto', 'Manual', 'Off']},
      {'name': 'Diesel Pump Running', 'type': 'toggle', 'options': ['Running', 'Stopped']},
      {'name': 'Diesel Pump Auto Mode', 'type': 'toggle', 'options': ['Auto', 'Manual', 'Off']},
    ],
  ),

  // ─── Section 4: Fire Hydrant Charger ──────────────────────────────────
  StandardChecklistPreset(
    key: 'section4_fire_hydrant_charger',
    name: 'Fire Hydrant Charger',
    category: 'Battery & Charger',
    checklistTypeKey: 'battery_charger',
    description: 'Fire hydrant battery charger selection, mode, voltage and current.',
    fields: [
      {'name': 'Charger Selection', 'type': 'toggle', 'options': ['Auto', 'Manual']},
      {'name': 'Charger Mode', 'type': 'toggle', 'options': ['Float', 'Boost']},
      {'name': 'DC Current (A)', 'type': 'numeric'},
      {
        'name': 'DC Voltage (V)',
        'type': 'numeric',
        'nominalValue': 24.0,
        'warningMin': 22.0,
        'warningMax': 26.0,
        'criticalMin': 20.0,
        'criticalMax': 28.0,
      },
    ],
  ),

  // ─── Section 5: INTAC DG Charger ──────────────────────────────────────
  StandardChecklistPreset(
    key: 'section5_intac_dg_charger',
    name: 'INTAC DG Charger',
    category: 'Battery & Charger',
    checklistTypeKey: 'battery_charger',
    description: 'INTAC DG battery charger selection, mode, voltage selection, current and voltage.',
    fields: [
      {'name': 'Charger Selection', 'type': 'toggle', 'options': ['Auto', 'Manual']},
      {'name': 'Charger Mode', 'type': 'toggle', 'options': ['Float', 'Boost']},
      {'name': 'Voltage Selection', 'type': 'toggle', 'options': ['12V', '24V']},
      {'name': 'DC Current (A)', 'type': 'numeric'},
      {
        'name': 'DC Voltage (V)',
        'type': 'numeric',
        'nominalValue': 24.0,
        'warningMin': 22.0,
        'warningMax': 26.0,
        'criticalMin': 20.0,
        'criticalMax': 28.0,
      },
    ],
  ),

  // ─── Section 6: Diesel Stock ──────────────────────────────────────────
  StandardChecklistPreset(
    key: 'section6_diesel_stock',
    name: 'Diesel Stock',
    category: 'Diesel Stock',
    checklistTypeKey: 'diesel_stock',
    description: 'Main tank diesel level and DG day tank fuel levels.',
    fields: [
      {'name': 'Main Tank (Litre)', 'type': 'numeric'},
      {'name': 'CAT DG1 (cm)', 'type': 'numeric'},
      {'name': 'CAT DG2 (cm)', 'type': 'numeric'},
      {'name': 'CAT DG3 (cm)', 'type': 'numeric'},
      {'name': 'INTAC DG (cm)', 'type': 'numeric'},
    ],
  ),

  // ─── Section 7: Transformers ──────────────────────────────────────────
  StandardChecklistPreset(
    key: 'section7_transformers',
    name: 'Transformers (4 MVA & 55 MVA)',
    category: 'Transformers',
    checklistTypeKey: 'transformer',
    description: 'Oil temp, winding temp, oil level %, silica gel color and oil leakage.',
    fields: [
      {'name': '4 MVA Oil Temp (°C)', 'type': 'numeric'},
      {'name': '4 MVA Winding Temp (°C)', 'type': 'numeric'},
      {'name': '4 MVA Oil Level (%)', 'type': 'numeric'},
      {'name': '4 MVA Silica Gel Color', 'type': 'toggle', 'options': ['Blue', 'Pink', 'White']},
      {'name': '4 MVA Oil Leakage', 'type': 'toggle', 'options': ['No Leakage', 'Minor', 'Major']},
      {'name': '55 MVA-1 Oil Temp (°C)', 'type': 'numeric'},
      {'name': '55 MVA-1 Winding Temp (°C)', 'type': 'numeric'},
      {'name': '55 MVA-1 Oil Level (%)', 'type': 'numeric'},
      {'name': '55 MVA-1 Silica Gel Color', 'type': 'toggle', 'options': ['Blue', 'Pink', 'White']},
      {'name': '55 MVA-1 Oil Leakage', 'type': 'toggle', 'options': ['No Leakage', 'Minor', 'Major']},
      {'name': '55 MVA-2 Oil Temp (°C)', 'type': 'numeric'},
      {'name': '55 MVA-2 Winding LV1 (°C)', 'type': 'numeric'},
      {'name': '55 MVA-2 Winding LV2 (°C)', 'type': 'numeric'},
      {'name': '55 MVA-2 Winding HV (°C)', 'type': 'numeric'},
      {'name': '55 MVA-2 Oil Level (%)', 'type': 'numeric'},
      {'name': '55 MVA-2 Silica Gel Color', 'type': 'toggle', 'options': ['Blue', 'Pink', 'White']},
      {'name': '55 MVA-2 Oil Leakage', 'type': 'toggle', 'options': ['No Leakage', 'Minor', 'Major']},
    ],
  ),

  // ─── Section 8: BF1 Battery Charger ───────────────────────────────────
  StandardChecklistPreset(
    key: 'section8_bf1_battery_charger',
    name: 'BF1 Battery Charger',
    category: 'Battery & Charger',
    checklistTypeKey: 'battery_charger',
    description: 'BF1 charger selection, mode, DC current, DC voltage, battery current, H2 %LEL and fan.',
    fields: [
      {'name': 'Charger Selection', 'type': 'toggle', 'options': ['Auto', 'Manual']},
      {'name': 'Charger Mode', 'type': 'toggle', 'options': ['Float', 'Boost']},
      {'name': 'DC Current (A)', 'type': 'numeric'},
      {
        'name': 'DC Voltage (V)',
        'type': 'numeric',
        'nominalValue': 24.0,
        'warningMin': 22.0,
        'warningMax': 26.0,
        'criticalMin': 20.0,
        'criticalMax': 28.0,
      },
      {'name': 'Battery Current (A)', 'type': 'numeric'},
      {
        'name': 'H2 %LEL',
        'type': 'numeric',
        'warningMin': 10.0,
        'warningMax': 19.9,
        'criticalMin': 20.0,
        'criticalMax': 100.0,
      },
      {'name': 'Exhaust Fan', 'type': 'toggle', 'options': ['On', 'Off']},
    ],
  ),

  // ─── Section 9: BF2 Battery Charger ───────────────────────────────────
  StandardChecklistPreset(
    key: 'section9_bf2_battery_charger',
    name: 'BF2 Battery Charger',
    category: 'Battery & Charger',
    checklistTypeKey: 'battery_charger',
    description: 'BF2 charger selection, mode, DC current, DC voltage, battery current, H2 %LEL and fan.',
    fields: [
      {'name': 'Charger Selection', 'type': 'toggle', 'options': ['Auto', 'Manual']},
      {'name': 'Charger Mode', 'type': 'toggle', 'options': ['Float', 'Boost']},
      {'name': 'DC Current (A)', 'type': 'numeric'},
      {
        'name': 'DC Voltage (V)',
        'type': 'numeric',
        'nominalValue': 24.0,
        'warningMin': 22.0,
        'warningMax': 26.0,
        'criticalMin': 20.0,
        'criticalMax': 28.0,
      },
      {'name': 'Battery Current (A)', 'type': 'numeric'},
      {
        'name': 'H2 %LEL',
        'type': 'numeric',
        'warningMin': 10.0,
        'warningMax': 19.9,
        'criticalMin': 20.0,
        'criticalMax': 100.0,
      },
      {'name': 'Exhaust Fan', 'type': 'toggle', 'options': ['On', 'Off']},
    ],
  ),

  // ─── Section 10: CAT DG Battery Charger ───────────────────────────────
  StandardChecklistPreset(
    key: 'section10_cat_dg_battery_charger',
    name: 'CAT DG Battery Charger',
    category: 'Battery & Charger',
    checklistTypeKey: 'battery_charger',
    description: 'CAT DG charger parameters, 24V source and CAT DG 1/2/3 mode and idle status.',
    fields: [
      {'name': 'Charger Selection', 'type': 'toggle', 'options': ['Auto', 'Manual']},
      {'name': 'Charger Mode', 'type': 'toggle', 'options': ['Float', 'Boost']},
      {'name': 'DC Current (A)', 'type': 'numeric'},
      {
        'name': 'DC Voltage (V)',
        'type': 'numeric',
        'nominalValue': 24.0,
        'warningMin': 22.0,
        'warningMax': 26.0,
        'criticalMin': 20.0,
        'criticalMax': 28.0,
      },
      {'name': '24V Source', 'type': 'toggle', 'options': ['CAT DC Battery Charger', 'Alternate Source']},
      {'name': 'CAT DG-1 Mode', 'type': 'toggle', 'options': ['Manual', 'Auto']},
      {'name': 'CAT DG-1 Idle', 'type': 'toggle', 'options': ['Low Idle', 'High Idle']},
      {'name': 'CAT DG-2 Mode', 'type': 'toggle', 'options': ['Manual', 'Auto']},
      {'name': 'CAT DG-2 Idle', 'type': 'toggle', 'options': ['Low Idle', 'High Idle']},
      {'name': 'CAT DG-3 Mode', 'type': 'toggle', 'options': ['Manual', 'Auto']},
      {'name': 'CAT DG-3 Idle', 'type': 'toggle', 'options': ['Low Idle', 'High Idle']},
    ],
  ),

  // ─── Section 11: PCC Status ───────────────────────────────────────────
  StandardChecklistPreset(
    key: 'section11_pcc_status',
    name: 'PCC Status',
    category: 'PCC & MCC',
    checklistTypeKey: 'pcc_mcc',
    description: 'Transformers 1/2 incomers, bus coupler, neutral grounding and PCC exhaust fan.',
    fields: [
      {'name': 'TF1 Incomer', 'type': 'toggle', 'options': ['ON', 'OFF']},
      {'name': 'TF2 Incomer', 'type': 'toggle', 'options': ['ON', 'OFF']},
      {'name': 'Bus Coupler', 'type': 'toggle', 'options': ['ON', 'OFF']},
      {'name': 'TF1 Neutral', 'type': 'toggle', 'options': ['ON', 'OFF']},
      {'name': 'TF2 Neutral', 'type': 'toggle', 'options': ['ON', 'OFF']},
      {'name': 'INTAC DG 1', 'type': 'toggle', 'options': ['ON', 'OFF']},
      {'name': 'INTAC DG 2', 'type': 'toggle', 'options': ['ON', 'OFF']},
      {'name': 'PCC Exhaust Fan', 'type': 'toggle', 'options': ['Running', 'Stopped']},
    ],
  ),

  // ─── Section 12: HMC Panel ────────────────────────────────────────────
  StandardChecklistPreset(
    key: 'section12_hmc_panel',
    name: 'HMC Panel',
    category: 'PCC & MCC',
    checklistTypeKey: 'pcc_mcc',
    description: 'BF1 HMC and BF2 HMC air conditioning status.',
    fields: [
      {'name': 'BF1 HMC AC Main', 'type': 'toggle', 'options': ['Running', 'Stopped']},
      {'name': 'BF2 HMC AC Entrance', 'type': 'toggle', 'options': ['Running', 'Stopped']},
      {'name': 'BF2 HMC AC End', 'type': 'toggle', 'options': ['Running', 'Stopped']},
    ],
  ),

  // ─── Section 13: HBS ──────────────────────────────────────────────────
  StandardChecklistPreset(
    key: 'section13_hbs',
    name: 'HBS',
    category: 'Panel Room',
    checklistTypeKey: 'panel_room',
    description: 'BF1 and BF2 HBS starter modes and VFD fan status.',
    fields: [
      {'name': 'BF1 HBS Mode', 'type': 'toggle', 'options': ['Star Delta', 'VFD']},
      {'name': 'BF1 VFD Fan Status', 'type': 'toggle', 'options': ['Running', 'Stopped']},
      {'name': 'BF2 HBS Mode', 'type': 'toggle', 'options': ['Star Delta', 'VFD']},
      {'name': 'BF2 VFD Fan Status', 'type': 'toggle', 'options': ['Running', 'Stopped']},
    ],
  ),

  // ─── Section 14: Blower 1 Dampers ─────────────────────────────────────
  StandardChecklistPreset(
    key: 'section14_blower_1_dampers',
    name: 'Blower 1 Dampers',
    category: 'Motor & Pumps',
    checklistTypeKey: 'motor_status',
    description: 'BF1 & BF2 Blower dampers, control mode, spring charge, mode and ABB relay.',
    fields: [
      {'name': 'BF1 Blower 1 Outlet Damper', 'type': 'toggle', 'options': ['Close', 'Open']},
      {'name': 'BF1 Blower 1 Bypass Damper', 'type': 'toggle', 'options': ['Open', 'Close']},
      {'name': 'BF1 Blower 1 Inlet Damper', 'type': 'toggle', 'options': ['Open', 'Close']},
      {'name': 'BF1 Blower 1 Newline Damper', 'type': 'toggle', 'options': ['Close', 'Open']},
      {'name': 'BF1 Blower 1 Control Mode', 'type': 'toggle', 'options': ['PLC', 'Manual']},
      {'name': 'BF1 Blower 1 Spring Charge', 'type': 'toggle', 'options': ['NA', 'Charged', 'Discharged']},
      {'name': 'BF1 Blower 1 Mode', 'type': 'toggle', 'options': ['Auto', 'Manual', 'Off']},
      {'name': 'BF1 Blower 1 ABB Relay', 'type': 'toggle', 'options': ['In Line', 'Tripped']},
      {'name': 'BF2 Blower 1 Outlet Damper', 'type': 'toggle', 'options': ['Close', 'Open']},
      {'name': 'BF2 Blower 1 Bypass Damper', 'type': 'toggle', 'options': ['Open', 'Close']},
      {'name': 'BF2 Blower 1 Inlet Damper', 'type': 'toggle', 'options': ['Open', 'Close']},
      {'name': 'BF2 Blower 1 Newline Damper', 'type': 'toggle', 'options': ['Close', 'Open']},
      {'name': 'BF2 Blower 1 Control Mode', 'type': 'toggle', 'options': ['PLC', 'Manual']},
      {'name': 'BF2 Blower 1 Spring Charge', 'type': 'toggle', 'options': ['NA', 'Charged', 'Discharged']},
      {'name': 'BF2 Blower 1 Mode', 'type': 'toggle', 'options': ['Auto', 'Manual', 'Off']},
      {'name': 'BF2 Blower 1 ABB Relay', 'type': 'toggle', 'options': ['In Line', 'Tripped']},
    ],
  ),

  // ─── Section 15: Tools Checking ───────────────────────────────────────
  StandardChecklistPreset(
    key: 'section15_tools_checking',
    name: 'Tools Checking',
    category: 'Tools & Safety',
    checklistTypeKey: 'tools_safety',
    description: 'Quantities of shift electrical tools and safety gear.',
    fields: [
      {'name': 'Clamp Meter', 'type': 'numeric'},
      {'name': 'Sealent (Anaboard)', 'type': 'numeric'},
      {'name': 'Torch', 'type': 'numeric'},
      {'name': 'Voltmeter', 'type': 'numeric'},
      {'name': 'HV Non Contact Voltage Detecter', 'type': 'numeric'},
      {'name': 'Contact Lubricant (AC-90)', 'type': 'numeric'},
      {'name': 'Megger', 'type': 'numeric'},
      {'name': 'DSAR Rod', 'type': 'numeric'},
      {'name': 'Leakage Tester', 'type': 'numeric'},
      {'name': 'CO Monitor', 'type': 'numeric'},
      {'name': 'Walkie Talkie', 'type': 'numeric'},
      {'name': 'Shift mobile', 'type': 'numeric'},
      {'name': 'Shift Mobile Charger', 'type': 'numeric'},
    ],
  ),

  // ─── Section 16: Power Plant Monitoring ───────────────────────────────
  StandardChecklistPreset(
    key: 'section16_power_plant_monitoring',
    name: 'Power Plant Monitoring',
    category: 'Power Plant',
    checklistTypeKey: 'power_plant',
    description: 'PP-1 (GEPL) & PP-2 (NPP) Generation (MW), Export (MW) and Gas (KNm³/Hr).',
    fields: [
      {'name': 'PP-1 (GEPL) Generation (MW)', 'type': 'numeric'},
      {'name': 'PP-1 (GEPL) Export (MW)', 'type': 'numeric'},
      {'name': 'PP-1 (GEPL) Gas (KNm³/Hr)', 'type': 'numeric'},
      {'name': 'PP-2 (NPP) Generation (MW)', 'type': 'numeric'},
      {'name': 'PP-2 (NPP) Export (MW)', 'type': 'numeric'},
      {'name': 'PP-2 (NPP) Gas (KNm³/Hr)', 'type': 'numeric'},
    ],
  ),

  // ─── Section 17: Panel Room Observations ─────────────────────────────
  StandardChecklistPreset(
    key: 'section17_panel_room_observations',
    name: 'Panel Room Observations',
    category: 'Panel Room',
    checklistTypeKey: 'panel_room',
    description: 'Door status, EMS report, shutdown report, 5S status, safety pep talk and remarks.',
    fields: [
      {'name': 'Panel Room Door Status', 'type': 'toggle', 'options': ['Fully locked', 'Locked (Key Box)', 'Unlocked']},
      {'name': 'EMS Report', 'type': 'toggle', 'options': ['Available', 'Not Available']},
      {'name': 'Electrical Shutdown Report', 'type': 'toggle', 'options': ['Updated', 'Not Updated']},
      {'name': '5S Status (1–5)', 'type': 'numeric'},
      {'name': 'Pep Talk Given', 'type': 'toggle', 'options': ['Yes', 'No']},
      {'name': 'Wind Reduction Electrical', 'type': 'toggle', 'options': ['No', 'Yes']},
      {'name': 'Near Miss or Accident', 'type': 'toggle', 'options': ['None', 'Reported']},
      {'name': 'Absenteeism', 'type': 'toggle', 'options': ['None', 'Reported']},
      {'name': 'Resource Constraint', 'type': 'toggle', 'options': ['None', 'Reported']},
      {'name': 'Shift Remarks / Details', 'type': 'text'},
    ],
  ),

  // ─── Section 18: First Aid Box ────────────────────────────────────────
  StandardChecklistPreset(
    key: 'section18_first_aid_box',
    name: 'First Aid Box',
    category: 'Tools & Safety',
    checklistTypeKey: 'tools_safety',
    description: 'Dressings, cotton wool, eye pads, burn ointment, antiseptic solution levels.',
    fields: [
      {'name': 'Small sterilised dressing (Qty)', 'type': 'numeric'},
      {'name': 'Medium size sterilised dressing (Qty)', 'type': 'numeric'},
      {'name': 'Large size sterilised dressing (Qty)', 'type': 'numeric'},
      {'name': 'Large size sterilised burn dressing (Qty)', 'type': 'numeric'},
      {'name': 'Packets (15g) of sterilised cotton wool (Qty)', 'type': 'numeric'},
      {'name': 'Scissors (Qty)', 'type': 'numeric'},
      {'name': 'Pieces of sterilised eye pads (Qty)', 'type': 'numeric'},
      {'name': 'Pack (20g) potassium permanganate crystals (Qty)', 'type': 'numeric'},
      {'name': 'First-aid leaflets (Qty)', 'type': 'numeric'},
      {'name': 'Cetrimide solution (1%) / Antiseptic (%)', 'type': 'numeric'},
      {'name': 'Mercurochrome (2%) solution (%)', 'type': 'numeric'},
      {'name': 'Ointment for burn (%)', 'type': 'numeric'},
      {'name': 'Roll of adhesive plaster (6cm x 5m) (%)', 'type': 'numeric'},
      {'name': 'Roll of adhesive plaster (2cm x 1m) (%)', 'type': 'numeric'},
    ],
  ),

  // ─── Section 19: Shift Specific ───────────────────────────────────────
  StandardChecklistPreset(
    key: 'section19_shift_specific',
    name: 'Shift Specific & Space Heaters',
    category: 'Panel Room',
    checklistTypeKey: 'panel_room',
    description: 'EV charger consumption, motor space heaters status and currents, daily consumption.',
    fields: [
      {'name': 'EV Charger Consumption (kWh)', 'type': 'numeric'},
      {'name': 'CT Motor 1 Space Heater Status', 'type': 'toggle', 'options': ['ON', 'OFF']},
      {'name': 'CT Motor 1 Space Heater Current (mA)', 'type': 'numeric'},
      {'name': 'CT Motor 2 Space Heater Status', 'type': 'toggle', 'options': ['ON', 'OFF']},
      {'name': 'CT Motor 2 Space Heater Current (mA)', 'type': 'numeric'},
      {'name': 'HT Motor 1 Space Heater Status', 'type': 'toggle', 'options': ['ON', 'OFF']},
      {'name': 'HT Motor 1 Space Heater Current (A)', 'type': 'numeric'},
      {'name': 'HT Motor 2 Space Heater Status', 'type': 'toggle', 'options': ['ON', 'OFF']},
      {'name': 'HT Motor 2 Space Heater Current (A)', 'type': 'numeric'},
      {'name': 'HT Motor 3 Space Heater Status', 'type': 'toggle', 'options': ['ON', 'OFF']},
      {'name': 'HT Motor 4 Space Heater Status', 'type': 'toggle', 'options': ['ON', 'OFF']},
      {'name': 'Daily Consumption (kWh)', 'type': 'numeric'},
      {'name': 'Shift Remarks', 'type': 'text'},
    ],
  ),
];

/// Service to batch-seed standard checklist presets or import/export configuration.
class ShiftChecklistPresetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Batch-insert all or selected presets for a given plant & unit into `custom_checklists`.
  Future<int> seedPresetsForUnit({
    required String plantId,
    required String unitId,
    required String businessId,
    List<String>? selectedKeys,
    bool overwrite = false,
  }) async {
    final presetsToSeed = selectedKeys == null
        ? kStandardUnitChecklistPresets
        : kStandardUnitChecklistPresets
            .where((p) => selectedKeys.contains(p.key))
            .toList();

    if (presetsToSeed.isEmpty) return 0;

    final existingSnapshot = await _firestore
        .collection('custom_checklists')
        .where('plantId', isEqualTo: plantId)
        .where('unitId', isEqualTo: unitId)
        .get();

    final existingNames = {
      for (final doc in existingSnapshot.docs)
        (doc.data()['name'] as String? ?? '').toLowerCase(): doc.id,
    };

    final batch = _firestore.batch();
    int count = 0;

    for (final preset in presetsToSeed) {
      final docNameKey = preset.name.toLowerCase();
      if (!overwrite && existingNames.containsKey(docNameKey)) {
        continue;
      }

      final docId = existingNames[docNameKey] ?? const Uuid().v4();
      final docRef = _firestore.collection('custom_checklists').doc(docId);

      final checklistData = preset.toCustomChecklistMap(
        plantId: plantId,
        unitId: unitId,
        businessId: businessId,
      );
      checklistData['id'] = docId;

      batch.set(docRef, checklistData, SetOptions(merge: true));
      count++;
    }

    if (count > 0) {
      await batch.commit();
    }

    return count;
  }

  /// Export current unit checklists as a formatted JSON string.
  Future<String> exportUnitChecklistsAsJson({
    required String plantId,
    required String unitId,
  }) async {
    final snapshot = await _firestore
        .collection('custom_checklists')
        .where('plantId', isEqualTo: plantId)
        .where('unitId', isEqualTo: unitId)
        .get();

    final list = snapshot.docs.map((d) => d.data()).toList();
    return const JsonEncoder.withIndent('  ').convert({
      'exportVersion': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'plantId': plantId,
      'unitId': unitId,
      'checklists': list,
    });
  }

  /// Import checklists from a JSON string into `custom_checklists`.
  Future<int> importChecklistsFromJson(
    String jsonString, {
    required String plantId,
    required String unitId,
    required String businessId,
  }) async {
    final Map<String, dynamic> data = jsonDecode(jsonString);
    final rawList = data['checklists'] as List? ?? [];
    if (rawList.isEmpty) return 0;

    final batch = _firestore.batch();
    int count = 0;

    for (final raw in rawList) {
      final item = Map<String, dynamic>.from(raw as Map);
      final id = const Uuid().v4();
      item['id'] = id;
      item['plantId'] = plantId;
      item['unitId'] = unitId;
      item['businessId'] = businessId;

      final docRef = _firestore.collection('custom_checklists').doc(id);
      batch.set(docRef, item, SetOptions(merge: true));
      count++;
    }

    if (count > 0) {
      await batch.commit();
    }

    return count;
  }
}
