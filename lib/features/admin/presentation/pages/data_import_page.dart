import 'package:flutter/material.dart';
import 'hierarchy_import_page.dart';
import '../../../assets/presentation/pages/asset_import_page.dart';
import '../../../operations/presentation/pages/checklist/checklist_import_page.dart';

export 'hierarchy_import_page.dart';
export '../../../assets/presentation/pages/asset_import_page.dart';
export '../../../operations/presentation/pages/checklist/checklist_import_page.dart';

/// Unified DataImportPage router that delegates to section-specific import pages:
/// - [AssetImportPage] for technical rotating and electrical assets
/// - [HierarchyImportPage] for database hierarchy levels (Locations, Panels, Feeders, Equipment)
/// - [ChecklistImportPage] for operation registries and compliance checklists
class DataImportPage extends StatelessWidget {
  final String collectionId;
  final String title;
  final String? unitId;
  final String? plantId;

  const DataImportPage({
    super.key,
    required this.collectionId,
    required this.title,
    this.unitId,
    this.plantId,
  });

  @override
  Widget build(BuildContext context) {
    if (collectionId == 'assets') {
      return AssetImportPage(
        unitId: unitId,
        plantId: plantId,
      );
    }

    if (['locations', 'panel_rooms', 'panels', 'feeders', 'transformers', 'master_equipments', 'combined_hierarchy', 'hierarchy_config', 'fault_types', 'odc', 'odc_causes'].contains(collectionId)) {
      return HierarchyImportPage(
        collectionId: collectionId == 'odc_causes' ? 'odc' : collectionId,
        title: title,
        unitId: unitId,
        plantId: plantId,
      );
    }

    return ChecklistImportPage(
      collectionId: collectionId,
      title: title,
      unitId: unitId,
      plantId: plantId,
    );
  }
}
