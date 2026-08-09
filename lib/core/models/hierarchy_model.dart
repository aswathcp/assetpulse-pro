
class HierarchyModel {
  final String businessName;
  final Map<String, PlantModel> plants;

  HierarchyModel({
    required this.businessName,
    required this.plants,
  });

  factory HierarchyModel.fromJson(Map<String, dynamic> json) {
    final plantsMap = <String, PlantModel>{};
    if (json['plants'] != null) {
      (json['plants'] as Map<String, dynamic>).forEach((key, value) {
        plantsMap[key] = PlantModel.fromJson(value);
      });
    }
    return HierarchyModel(
      businessName: json['businessName'] ?? '',
      plants: plantsMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'businessName': businessName,
      'plants': plants.map((key, value) => MapEntry(key, value.toJson())),
    };
  }
}

class PlantModel {
  final String name;
  final Map<String, String> units;

  PlantModel({
    required this.name,
    required this.units,
  });

  factory PlantModel.fromJson(Map<String, dynamic> json) {
    final unitsMap = <String, String>{};
    if (json['units'] != null) {
      if (json['units'] is Map) {
        (json['units'] as Map).forEach((key, value) {
          unitsMap[key.toString()] = value.toString();
        });
      } else if (json['units'] is List) {
        for (var u in json['units']) {
          unitsMap[u.toString()] = u.toString();
        }
      }
    }
    return PlantModel(
      name: json['name'] ?? '',
      units: unitsMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'units': units,
    };
  }
}
