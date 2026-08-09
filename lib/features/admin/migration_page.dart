import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/asset_migration.dart';

/// Temporary migration page to run the asset migration script
/// This page can be accessed once to migrate data, then removed
class MigrationPage extends StatefulWidget {
  const MigrationPage({super.key});

  @override
  State<MigrationPage> createState() => _MigrationPageState();
}

class _MigrationPageState extends State<MigrationPage> {
  bool _isMigrating = false;
  String _status = 'Ready to migrate assets';
  final _migration = AssetMigrationScript();

  Future<void> _runMigration() async {
    setState(() {
      _isMigrating = true;
      _status = 'Migrating assets...';
    });

    try {
      await _migration.migrateAssetsToHierarchical();
      setState(() {
        _status = 'Migration completed successfully! ✅';
        _isMigrating = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Migration failed: $e ❌';
        _isMigrating = false;
      });
    }
  }

  Future<void> _runRollback() async {
    setState(() {
      _isMigrating = true;
      _status = 'Rolling back migration...';
    });

    try {
      await _migration.rollbackMigration();
      setState(() {
        _status = 'Rollback completed successfully! ✅';
        _isMigrating = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Rollback failed: $e ❌';
        _isMigrating = false;
      });
    }
  }

  Future<void> _seedBatteryRoomChecklist() async {
    setState(() {
      _isMigrating = true;
      _status = 'Seeding BF1 Battery Room Checklist...';
    });

    try {
      final docData = <String, dynamic>{
        'id': 'bf1_battery_room_id',
        'name': 'BF1 Battery Room Checklist',
        'plantId': 'PID1',
        'unitId': 'VAB',
        'isLocationRequired': true,
        'latitude': 12.345678, // default coordinate
        'longitude': 78.901234, // default coordinate
        'fields': [
          {
            'name': 'Selection',
            'type': 'toggle',
            'options': ['Auto', 'Manual'],
          },
          {
            'name': 'Mode',
            'type': 'toggle',
            'options': ['Float', 'Boost'],
          },
          {
            'name': 'DC Current',
            'type': 'numeric',
          },
          {
            'name': 'DC Voltage',
            'type': 'numeric',
          },
          {
            'name': 'Battery Cell Voltage',
            'type': 'numeric',
          },
          {
            'name': 'H2 %LEL Reading',
            'type': 'numeric',
            'warningMin': 10.0,
            'warningMax': 19.9,
            'criticalMin': 20.0,
            'criticalMax': 100.0,
          },
          {
            'name': 'Exhaust Fan',
            'type': 'toggle',
            'options': ['On', 'Off'],
          }
        ],
      };

      await FirebaseFirestore.instance.collection('custom_checklists').doc('bf1_battery_room_id').set(docData);
      setState(() {
        _status = 'BF1 Battery Room Checklist seeded successfully! ✅';
        _isMigrating = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Seeding failed: $e ❌';
        _isMigrating = false;
      });
    }
  }

  Future<void> _seedCompanyHierarchy() async {
    setState(() {
      _isMigrating = true;
      _status = 'Seeding Vedanta Iron & Steel Ltd Hierarchy...';
    });

    try {
      final docData = <String, dynamic>{
        'businessName': 'Vedanta Iron & Steel Ltd',
        'plants': {
          'IOG': {
            'name': 'Iron Ore Goa',
            'units': {
              'COD': 'Codli Mine',
              'BCM': 'Bicholim Mine',
              'SON': 'Sonshi Mine',
            },
          },
          'IOK': {
            'name': 'Iron Ore Karnataka',
            'units': {
              'CHD': 'Chitradurga Operations',
            },
          },
          'IOO': {
            'name': 'Iron Ore Odisha',
            'units': {
              'OIO': 'Odisha Iron Ore Operations',
            },
          },
          'VAB': {
            'name': 'Value Added Business',
            'units': {
              'PIPL': 'Pig Iron Plant',
              'PIEP': 'Pig Iron Expansion Plant',
              'DIP': 'Ductile Iron Pipe Plant',
              'MCD': 'Metallurgical Coke Division',
              'PP1': 'Power Plant 1',
              'PP2': 'Power Plant 2',
            },
          },
          'ESL': {
            'name': 'Electrosteel Steels Ltd',
            'units': {
              'SMS': 'Steel Melt Shop',
              'BF': 'Blast Furnace',
              'SP': 'Sinter Plant',
              'COP': 'Coke Oven Plant',
              'CPP': 'Power Plant',
              'RM': 'Rolling Mill',
              'WRM': 'Wire Rod Mill',
              'OXY': 'Oxygen Plant',
            },
          },
          'WCL': {
            'name': 'Western Coalfields (Captive Coal)',
            'units': {
              'CM1': 'Coal Mine 1',
              'CM2': 'Coal Mine 2',
              'CHP': 'Coal Handling Plant',
              'WKS': 'Workshop',
            },
          },
        },
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('hierarchy_config').doc('VISL').set(docData);
      setState(() {
        _status = 'VISL Hierarchy seeded successfully! ✅';
        _isMigrating = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Seeding VISL Hierarchy failed: $e ❌';
        _isMigrating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asset Migration'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Asset Data & Checklist Migration',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'This will migrate all existing assets from the flat collection structure to the new hierarchical structure or seed default dynamic checklists.',
            ),
            const SizedBox(height: 32),
            Text(
              _status,
              style: TextStyle(
                fontSize: 16,
                color: _status.contains('✅') ? Colors.green : 
                       _status.contains('❌') ? Colors.red : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isMigrating ? null : _runMigration,
              child: _isMigrating
                  ? const CircularProgressIndicator()
                  : const Text('Run Migration'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _isMigrating ? null : _runRollback,
              child: const Text('Rollback Migration'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: _isMigrating ? null : _seedBatteryRoomChecklist,
              icon: const Icon(Icons.playlist_add_check, color: Colors.white),
              label: const Text('Seed BF1 Battery Room Checklist', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
              onPressed: _isMigrating ? null : _seedCompanyHierarchy,
              icon: const Icon(Icons.account_tree, color: Colors.white),
              label: const Text('Seed Company Hierarchy (VISL)', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 32),
            const Text(
              'Note: After successful migration, you can remove this page from the app.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}
