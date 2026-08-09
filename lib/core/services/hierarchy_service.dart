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
  
  static const List<String> feederTypes = ['Feeder', 'Spare', 'Incomer', 'Bus Coupler'];
  
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
