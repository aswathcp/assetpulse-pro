// LOCATION MODEL
class LocationModel {
  final String id;
  final String name;
  final String type; // Substation, Office
  final String plantId;
  final String unitId;

  LocationModel({required this.id, required this.name, required this.type, required this.plantId, required this.unitId});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'type': type, 'plantId': plantId, 'unitId': unitId};

  factory LocationModel.fromMap(Map<String, dynamic> map, String id) {
    return LocationModel(
      id: id,
      name: map['name'] ?? '',
      type: map['type'] ?? '',
      plantId: map['plantId'] ?? '',
      unitId: map['unitId'] ?? '',
    );
  }
}

// PANEL MODEL
class PanelModel {
  final String id; // Tag
  final String name;
  final String type; // PCC, MCC
  final String locationId;
  final String voltage;
  final String plantId;
  final String unitId;

  PanelModel({required this.id, required this.name, required this.type, required this.locationId, required this.voltage, required this.plantId, required this.unitId});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'type': type, 'locationId': locationId, 'voltage': voltage, 'plantId': plantId, 'unitId': unitId};

  factory PanelModel.fromMap(Map<String, dynamic> map, String id) {
    return PanelModel(
      id: id,
      name: map['name'] ?? '',
      type: map['type'] ?? '',
      locationId: map['locationId'] ?? '',
      voltage: map['voltage'] ?? '',
      plantId: map['plantId'] ?? '',
      unitId: map['unitId'] ?? '',
    );
  }
}

// FEEDER MODEL
class FeederModel {
  final String id; // Tag
  final String name;
  final String type;
  final String panelId;
  final bool isIsolatable;
  final String plantId;
  final String unitId;

  FeederModel({required this.id, required this.name, required this.type, required this.panelId, required this.isIsolatable, required this.plantId, required this.unitId});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'type': type, 'panelId': panelId, 'isIsolatable': isIsolatable, 'plantId': plantId, 'unitId': unitId};

  factory FeederModel.fromMap(Map<String, dynamic> map, String id) {
    return FeederModel(
      id: id,
      name: map['name'] ?? '',
      type: map['type'] ?? '',
      panelId: map['panelId'] ?? '',
      isIsolatable: map['isIsolatable'] ?? true, // Default safe
      plantId: map['plantId'] ?? '',
      unitId: map['unitId'] ?? '',
    );
  }
}
