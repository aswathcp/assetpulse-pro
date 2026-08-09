import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// One-time migration script to move assets from flat structure to hierarchical
/// Run this once to migrate existing assets to: assets/Unit A/Plant 1/
class AssetMigrationScript {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> migrateAssetsToHierarchical() async {
    debugPrint('🔄 Starting Asset Migration...');
    
    try {
      // 1. Get all assets from old flat collection
      final oldAssetsSnapshot = await _db.collection('assets').get();
      debugPrint('📦 Found ${oldAssetsSnapshot.docs.length} assets to migrate');
      
      if (oldAssetsSnapshot.docs.isEmpty) {
        debugPrint('✅ No assets to migrate');
        return;
      }

      int migratedCount = 0;
      int errorCount = 0;

      // 2. Migrate each asset to new hierarchical structure
      for (var doc in oldAssetsSnapshot.docs) {
        try {
          final assetData = doc.data();
          
          // Add unitId and plantId if missing
          assetData['unitId'] = assetData['unitId'] ?? 'Unit A';
          assetData['plantId'] = assetData['plantId'] ?? 'Plant 1';
          
          // 3. Write to new hierarchical path: assets/{unitId}/{plantId}/{docId}
          await _db
              .collection('assets')
              .doc(assetData['unitId'])
              .collection(assetData['plantId'])
              .doc(doc.id)
              .set(assetData);
          
          debugPrint('✅ Migrated: ${assetData['tagNo']} (${doc.id})');
          migratedCount++;
          
          // 4. Delete from old location
          await doc.reference.delete();
          
        } catch (e) {
          debugPrint('❌ Error migrating ${doc.id}: $e');
          errorCount++;
        }
      }

      debugPrint('');
      debugPrint('🎉 Migration Complete!');
      debugPrint('   ✅ Migrated: $migratedCount assets');
      if (errorCount > 0) {
        debugPrint('   ❌ Errors: $errorCount assets');
      }
      debugPrint('   📍 Location: assets/Unit A/Plant 1/');
      
    } catch (e) {
      debugPrint('💥 Migration failed: $e');
      rethrow;
    }
  }

  /// Rollback migration (move assets back to flat structure)
  Future<void> rollbackMigration() async {
    debugPrint('⏪ Rolling back migration...');
    
    try {
      // Get all assets from Unit A / Plant 1
      final hierarchicalAssets = await _db
          .collection('assets')
          .doc('Unit A')
          .collection('Plant 1')
          .get();
      
      debugPrint('📦 Found ${hierarchicalAssets.docs.length} assets to rollback');
      
      for (var doc in hierarchicalAssets.docs) {
        final assetData = doc.data();
        
        // Move back to flat structure
        await _db.collection('assets').doc(doc.id).set(assetData);
        
        // Delete from hierarchical location
        await doc.reference.delete();
        
        debugPrint('✅ Rolled back: ${assetData['tagNo']}');
      }
      
      debugPrint('🎉 Rollback complete!');
      
    } catch (e) {
      debugPrint('💥 Rollback failed: $e');
      rethrow;
    }
  }
}
