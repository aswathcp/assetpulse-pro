import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:asset_pulse_pro/features/home/presentation/widgets/custom_app_bar.dart';
import 'package:asset_pulse_pro/core/services/firestore_service.dart';
import 'package:asset_pulse_pro/features/assets/presentation/pages/asset_detail_page.dart';
import 'geofenced_checklist_wrapper.dart';
import 'checklists/dynamic_checklist_form.dart';
import 'rccb_checklists_page.dart';

class ChecklistQrScannerPage extends StatefulWidget {
  const ChecklistQrScannerPage({super.key});

  @override
  State<ChecklistQrScannerPage> createState() => _ChecklistQrScannerPageState();
}

class _ChecklistQrScannerPageState extends State<ChecklistQrScannerPage> {
  bool _isScanned = false;
  final MobileScannerController _scannerController = MobileScannerController();

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isScanned) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        _isScanned = true;
        _handleScanResult(barcode.rawValue!);
        break;
      }
    }
  }

  Future<void> _handleScanResult(String rawCode) async {
    final code = rawCode.trim();
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    
    try {
      final firestoreService = FirestoreService();

      // 1. Check if scanned code is an Asset (Tag No / Serial / Document ID)
      final asset = await firestoreService.getAssetByTagNo(code);
      if (asset != null) {
        if (!mounted) return;
        Navigator.pop(context); // Dismiss loading

        // Navigate directly to Asset Details
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AssetDetailPage(asset: asset)),
        );
        return;
      }

      // 2. Check if scanned code is a Custom Checklist
      final query = await FirebaseFirestore.instance
          .collection('custom_checklists')
          .where('name', isEqualTo: code)
          .limit(1)
          .get();
          
      if (!mounted) return;
      
      if (query.docs.isEmpty) {
        // 3. Check if scanned code is an RCCB Safety Board / Outlet / Socket
        String rccbCode = code;
        if (rccbCode.toUpperCase().startsWith('RCCB:')) {
          rccbCode = rccbCode.substring(5).trim();
        }

        DocumentSnapshot? rccbDoc;
        final directRccbDoc = await FirebaseFirestore.instance.collection('rccb_equipments').doc(rccbCode).get();
        if (directRccbDoc.exists) {
          rccbDoc = directRccbDoc;
        } else {
          final queryRccb = await FirebaseFirestore.instance
              .collection('rccb_equipments')
              .where('id', isEqualTo: rccbCode)
              .limit(1)
              .get();
          if (queryRccb.docs.isNotEmpty) {
            rccbDoc = queryRccb.docs.first;
          } else {
            // Fallback for legacy lighting_dbs if still present
            final legacyDoc = await FirebaseFirestore.instance.collection('lighting_dbs').doc(rccbCode).get();
            if (legacyDoc.exists) {
              rccbDoc = legacyDoc;
            }
          }
        }

        if (rccbDoc != null && rccbDoc.exists) {
          if (!mounted) return;
          Navigator.pop(context); // Dismiss loading
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => RccbChecklistsPage(initialScannedCode: rccbCode)),
          );
          return;
        }

        if (!mounted) return;
        Navigator.pop(context); // Dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unrecognized QR Code: $code (Not found in Assets, Checklists, or RCCB boards)')));
        setState(() => _isScanned = false);
        return;
      }
      
      Navigator.pop(context); // Dismiss loading
      
      final checklist = query.docs.first.data();
      final lat = (checklist['latitude'] as num?)?.toDouble() ?? 0.0;
      final lng = (checklist['longitude'] as num?)?.toDouble() ?? 0.0;
      final isLocationRequired = checklist['isLocationRequired'] == true &&
          (lat != 0.0 || lng != 0.0);
      
      if (isLocationRequired) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GeofencedChecklistWrapper(
          targetLatitude: lat,
          targetLongitude: lng,
          targetName: '${checklist['unitId'] ?? ''} ${checklist['name'] ?? ''}',
          builder: (pos, _) => DynamicChecklistForm(checklist: checklist, startPosition: pos),
        )));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DynamicChecklistForm(checklist: checklist)));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error finding QR target: $e')));
        setState(() => _isScanned = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Scan Equipment QR'),
      body: Column(
          children: [
            if (kIsWeb)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.amber.withValues(alpha: 0.9),
                width: double.infinity,
                child: const Text('Web Instance Detected: Ensure camera permissions are granted. For testing, skip scanning using Dev button below.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
              ),
            Expanded(
              child: MobileScanner(
                controller: _scannerController,
                onDetect: _onDetect,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
              child: Column(
                children: [
                   const Text('Align the Equipment QR Code within the frame to access its Verification Checklist.', textAlign: TextAlign.center),
                   const SizedBox(height: 16),
                   if (kIsWeb) // Web Dev Bypass Helper
                     ElevatedButton(
                       style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                       onPressed: () => _handleScanResult('BF1 Battery Room Checklist'),
                       child: const Text('Web Dev Override: Simulate Scan', style: TextStyle(color: Colors.white)),
                     ),
                ],
              ),
            ),
          ],
        ),
    );
  }
}
