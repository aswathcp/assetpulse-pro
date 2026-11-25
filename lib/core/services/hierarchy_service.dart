class HierarchyService {
  // Singleton
  static final HierarchyService _instance = HierarchyService._internal();
  factory HierarchyService() => _instance;
  HierarchyService._internal();

  String _currentBusinessId = 'VISL';
  String get currentBusinessId => _currentBusinessId;

  /// Initialize the service
  Future<void> init({String? businessId}) async {
    if (businessId != null) {
      _currentBusinessId = businessId;
    }
  }

  /// Force a refresh
  Future<void> refresh({String? businessId}) async {
    await init(businessId: businessId);
  }

  // --- Centralized Corporate Structure Constants ---

  static const Map<String, String> plants = {
    'IOG': 'Iron Ore Goa',
    'IOK': 'Iron Ore Karnataka',
    'IOO': 'Iron Ore Odisha',
    'VAB': 'Value Added Business',
    'ESL': 'Electrosteel Steels Ltd',
    'WCL': 'Western Coalfields (Captive Coal)',
  };

  static const Map<String, Map<String, String>> plantUnits = {
    'IOG': {
      'COD': 'Codli Mine',
      'BCM': 'Bicholim Mine',
      'SON': 'Sonshi Mine',
    },
    'IOK': {
      'CHD': 'Chitradurga Operations',
    },
    'IOO': {
      'OIO': 'Odisha Iron Ore Operations',
    },
    'VAB': {
      'PIPL': 'Pig Iron Plant',
      'PIEP': 'Pig Iron Expansion Plant',
      'DIP': 'Ductile Iron Pipe Plant',
      'MCD': 'Metallurgical Coke Division',
      'PP1': 'Power Plant 1',
      'PP2': 'Power Plant 2',
    },
    'ESL': {
      'SMS': 'Steel Melt Shop',
      'BF': 'Blast Furnace',
      'SP': 'Sinter Plant',
      'COP': 'Coke Oven Plant',
      'CPP': 'Power Plant',
      'RM': 'Rolling Mill',
      'WRM': 'Wire Rod Mill',
      'OXY': 'Oxygen Plant',
    },
    'WCL': {
      'CM1': 'Coal Mine 1',
      'CM2': 'Coal Mine 2',
      'CHP': 'Coal Handling Plant',
      'WKS': 'Workshop',
    },
  };

  // --- Standardized Lists (Case Sensitive) ---
  
  static const List<String> locationTypes = ['Area', 'Panel Room', 'Other'];
  
  static const List<String> panelTypes = ['MCC', 'PCC', 'LDB', 'Control Panel'];
  
  static const List<String> feederTypes = ['Feeder', 'Spare', 'Incomer', 'Bus Coupler', 'Tie'];

  static const List<String> voltageLevels = [
    '415V', '3.3kV', '6.6kV', '11kV', '22kV', '33kV', '66kV', '110kV', '132kV', '220kV'
  ];

  static const List<String> tertiaryVoltageLevels = [
    'None', '415V', '3.3kV', '6.6kV', '11kV', '22kV', '33kV', '66kV', '110kV', '132kV', '220kV'
  ];

  static const List<String> busSectionOptions = ['MAIN', 'SEC-1 & 2'];

  static const List<String> feederBusSectionOptions = ['MAIN', 'SEC-1', 'SEC-2', 'SEC-1 & 2'];

  /// Parses bus sections from any format (List, comma-delimited, ampersand-delimited e.g. "SEC-1 & 2")
  /// into a clean list of section strings, e.g. ['SEC-1', 'SEC-2'] or ['MAIN'].
  static List<String> parseBusSections(dynamic raw) {
    if (raw == null) return const ['MAIN'];
    if (raw is List) {
      if (raw.isEmpty) return const ['MAIN'];
      final flat = <String>[];
      for (final item in raw) {
        final s = item?.toString().trim() ?? '';
        if (s.isEmpty) continue;
        if (s.contains('&') || s.contains(',')) {
          flat.addAll(parseBusSections(s));
        } else {
          flat.add(s);
        }
      }
      return flat.isEmpty ? const ['MAIN'] : flat.toSet().toList();
    }
    final str = raw.toString().trim();
    if (str.isEmpty || str.toUpperCase() == 'MAIN') {
      return const ['MAIN'];
    }
    final upper = str.toUpperCase();
    if (upper.contains('SEC-1') && (upper.contains('SEC-2') || upper.contains('& 2') || upper.contains('&2') || upper.contains(',2') || upper.contains(', 2'))) {
      return const ['SEC-1', 'SEC-2'];
    }
    final parts = str.split(RegExp(r'[,&]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? const ['MAIN'] : parts;
  }

  /// Formats bus sections for UI dropdowns and Excel export (e.g. ['SEC-1', 'SEC-2'] -> 'SEC-1 & 2').
  static String formatBusSectionsForDisplay(dynamic raw) {
    final list = parseBusSections(raw);
    if (list.length > 1 || (list.contains('SEC-1') && list.contains('SEC-2'))) {
      return 'SEC-1 & 2';
    }
    if (list.isNotEmpty && list.first != 'MAIN') {
      return list.first;
    }
    return 'MAIN';
  }

  /// Normalizes feeder bus section string to match feederBusSectionOptions ('MAIN', 'SEC-1', 'SEC-2', 'SEC-1 & 2').
  static String normalizeFeederBusSection(dynamic raw) {
    if (raw == null) return 'MAIN';
    final s = raw.toString().trim();
    final upper = s.toUpperCase();
    if ((upper.contains('SEC-1') && upper.contains('SEC-2')) || upper.contains('& 2') || upper.contains('&2') || upper == 'SEC-1 & 2') {
      return 'SEC-1 & 2';
    }
    if (upper.contains('SEC-1') || upper == '1') return 'SEC-1';
    if (upper.contains('SEC-2') || upper == '2') return 'SEC-2';
    return 'MAIN';
  }

  static const List<String> feederOperatingStates = ['CLOSED', 'OPEN', 'TRIPPED', 'ISOLATED'];

  static const List<String> transformerWindingTypes = ['two_winding', 'three_winding'];
  
  static const List<String> equipmentTypes = [
    'Conveyor', 'Pump', 'Compressor', 'Drier', 'Fan', 'Blower', 'Motor',
    'Valve', 'Sensor', 'Transformer', 'Switchgear', 'Crane', 'Hoist',
    'Heater', 'Cooler', 'Chiller', 'Mixer', 'Agitator', 'Boiler',
    'Turbine', 'Generator', 'Separator', 'Filter', 'Extruder', 'Press',
    'Lathe', 'Mill', 'Robot', 'Other'
  ];
  
  static const List<String> assetTypes = [
    'Motor', 'Gearbox', 'Pump'
  ];

  // --- Accessors ---

  String get businessName => "Vedanta Iron & Steel Ltd";

  List<String> getPlants() {
    return plants.keys.toList();
  }

  List<String> getUnitsForPlant(String plantId) {
    return plantUnits[plantId]?.keys.toList() ?? [];
  }

  Map<String, String> getUnitNamesForPlant(String plantId) {
    final Map<String, String> formatted = {};
    final unitsMap = plantUnits[plantId] ?? {};
    unitsMap.forEach((id, name) {
      formatted[id] = "$name ($id)";
    });
    return formatted;
  }
  
  bool isValidUnit(String plantId, String unitId) {
     return getUnitsForPlant(plantId).contains(unitId);
  }

  Map<String, String> getPlantNames() {
    final Map<String, String> formatted = {};
    plants.forEach((id, name) {
      formatted[id] = "$name ($id)";
    });
    return formatted;
  }

  // --- Prefixing Helpers ---

  /// Format database ID with PLANT-UNIT- prefix.
  static String prefixId(String rawId, String plantId, String unitId) {
    final cleanRaw = rawId.trim().toUpperCase();
    if (plantId.isEmpty || unitId.isEmpty) return cleanRaw;
    final prefix = "${plantId.trim().toUpperCase()}-${unitId.trim().toUpperCase()}-";
    if (cleanRaw.startsWith(prefix)) {
      return cleanRaw;
    }
    return "$prefix$cleanRaw";
  }

  /// Strip prefix from database ID for clean UI displaying.
  static String stripPrefix(String prefixedId, String plantId, String unitId) {
    if (plantId.isEmpty || unitId.isEmpty) return prefixedId;
    final prefix = "${plantId.trim().toUpperCase()}-${unitId.trim().toUpperCase()}-";
    if (prefixedId.toUpperCase().startsWith(prefix)) {
      return prefixedId.substring(prefix.length);
    }
    return prefixedId;
  }
}
