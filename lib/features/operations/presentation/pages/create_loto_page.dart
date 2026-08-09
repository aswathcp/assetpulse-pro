import 'package:flutter/material.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/loto_service.dart';
import '../../../../core/services/firestore_service.dart'; // To list assets
import '../../data/models/loto_model.dart';
import '../../../../features/assets/data/models/asset_model.dart';
import 'package:uuid/uuid.dart';

class CreateLotoPage extends StatefulWidget {
  const CreateLotoPage({super.key});

  @override
  State<CreateLotoPage> createState() => _CreateLotoPageState();
}

class _CreateLotoPageState extends State<CreateLotoPage> {
  final _formKey = GlobalKey<FormState>();
  final _pointController = TextEditingController();
  final _reasonController = TextEditingController();
  
  AssetModel? _selectedAsset;
  bool _isLoading = false;
  
  // Quick asset search
  List<AssetModel> _allAssets = [];
  
  @override
  void initState() {
    super.initState();
    _loadAssets();
  }
  
  void _loadAssets() async {
     // Ideally fetch only relevant unit assets
     final assets = await FirestoreService().getAssetsList(null, null); // Pass proper context if available
     // Since AuthService doesn't easily expose UnitId here without context, 
     // we'll assume global list or specific query later. For now fetch all.
     // Optimization: Move this to a provider or reusable widget.
     
     if (mounted) {
       setState(() {
         _allAssets = assets;
       });
     }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate() || _selectedAsset == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an asset')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await FirestoreService().getUserProfile(AuthService().currentUser!.uid);
      
      final loto = LotoModel(
        id: const Uuid().v4(),
        assetId: _selectedAsset!.id,
        assetName: _selectedAsset!.name,
        assetTag: _selectedAsset!.tagNo,
        requesterId: user?['uid'] ?? 'unknown',
        requesterName: user?['name'] ?? 'Unknown',
        isolationPoint: _pointController.text,
        reason: _reasonController.text,
        createdAt: DateTime.now(),
        status: LotoStatus.requested,
      );
      
      await LotoService().createRequest(loto);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('LOTO Request Submitted')));
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request Isolation')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Asset Dropdown (Simple for now)
            DropdownButtonFormField<AssetModel>(
              decoration: const InputDecoration(
                labelText: 'Select Asset',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.precision_manufacturing),
              ),
              items: _allAssets.map((asset) => DropdownMenuItem(
                value: asset,
                child: Text('${asset.tagNo} - ${asset.name}'),
              )).toList(),
              onChanged: (v) => setState(() => _selectedAsset = v),
              validator: (v) => v == null ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _pointController,
              decoration: const InputDecoration(
                labelText: 'Isolation Point / Box No',
                hintText: 'e.g. MCC-01 Feeder 4',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.settings_input_component),
              ),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
             const SizedBox(height: 16),
             
            TextFormField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for Isolation',
                hintText: 'e.g. Bearing Replacement',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.work),
              ),
              maxLines: 3,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 32),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Theme.of(context).primaryColor,
              ),
              child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text('Submit Request', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
