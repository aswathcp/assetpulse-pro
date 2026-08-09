import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../scanning/presentation/pages/qr_scanner_page.dart';
import '../../../scanning/presentation/pages/nfc_scanner_page.dart';
import '../../../scanning/presentation/pages/rfid_scanner_page.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../assets/data/models/asset_model.dart';
import '../../../assets/presentation/pages/asset_detail_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../operations/presentation/pages/checklist/geofenced_checklist_wrapper.dart';
import '../../../operations/presentation/pages/checklist/checklists/dynamic_checklist_form.dart';

class ScanMenuOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final Offset buttonPosition;

  const ScanMenuOverlay({
    super.key,
    required this.onClose,
    required this.buttonPosition,
  });

  @override
  State<ScanMenuOverlay> createState() => _ScanMenuOverlayState();
}

class _ScanMenuOverlayState extends State<ScanMenuOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() {
    _controller.reverse().then((_) => widget.onClose());
  }

  Future<void> _handleScanOption(String option) async {
    _close();
    
    // Navigate to appropriate scanner page
    String? result;
    
    switch (option) {
      case 'QR':
        result = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (context) => const QRScannerPage(),
          ),
        );
        break;
      case 'NFC':
        result = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (context) => const NFCScannerPage(),
          ),
        );
        break;
      case 'RFID':
        result = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (context) => const RFIDScannerPage(),
          ),
        );
        break;
    }
    
    // Handle scanned result
    if (result != null && result.isNotEmpty) {
      _processScanResult(result, option);
    }
  }
  
  Future<void> _processScanResult(String code, String scanType) async {
    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Searching...'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final firestoreService = FirestoreService();

      // 1. Check if scanned code is a Checklist Name!
      if (scanType == 'QR') {
        final checklistQuery = await FirebaseFirestore.instance
            .collection('custom_checklists')
            .where('name', isEqualTo: code)
            .limit(1)
            .get();
            
        if (checklistQuery.docs.isNotEmpty) {
          final checklist = checklistQuery.docs.first.data();
          final isLocationRequired = checklist['isLocationRequired'] == true;
          
          if (!mounted) return;
          
          if (isLocationRequired) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GeofencedChecklistWrapper(
                  targetLatitude: (checklist['latitude'] as num).toDouble(),
                  targetLongitude: (checklist['longitude'] as num).toDouble(),
                  targetName: '${checklist['unitId'] ?? ''} ${checklist['name'] ?? ''}',
                  builder: (pos, verified) => DynamicChecklistForm(checklist: checklist, startPosition: pos, isVerified: verified),
                ),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DynamicChecklistForm(checklist: checklist),
              ),
            );
          }
          return; // Successfully handled!
        }
      }

      // 2. Otherwise assume it is a standard Asset Tag as normal
      AssetModel? asset;
      if (scanType == 'QR') {
        asset = await firestoreService.getAssetByTagNo(code);
      } else {
        asset = await firestoreService.getAssetByRfid(code);
      }

      if (!mounted) return;

      if (asset != null) {
        // Asset Found - Navigate
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AssetDetailPage(asset: asset!),
          ),
        );
      } else {
        // Not Found
        _showMessage('Not found in Assets or Checklists: $code', isError: true);
      }
    } catch (e) {
      if (mounted) _showMessage('Error searching: $e', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _close,
      child: Container(
        color: Colors.black54,
        child: Stack(
          children: [
            // NFC Option (Left)
            Positioned(
              left: widget.buttonPosition.dx - 80,
              bottom: widget.buttonPosition.dy + 5,
              child: _buildScanOption(
                icon: Icons.nfc,
                delay: 0,
                onTap: () => _handleScanOption('NFC'),
              ),
            ),
            // QR Option (Center-Top)
            Positioned(
              left: widget.buttonPosition.dx,
              bottom: widget.buttonPosition.dy + 70,
              child: _buildScanOption(
                icon: Icons.qr_code_scanner,
                delay: 30,
                onTap: () => _handleScanOption('QR'),
              ),
            ),
            // RFID Option (Right)
            Positioned(
              left: widget.buttonPosition.dx + 80,
              bottom: widget.buttonPosition.dy + 5,
              child: _buildScanOption(
                icon: Icons.sensors,
                delay: 60,
                onTap: () => _handleScanOption('RFID'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanOption({
    required IconData icon,
    required int delay,
    required VoidCallback onTap,
  }) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Calculate delayed animation value with improved dynamics
        final rawValue = (_controller.value * 350 - delay) / 350;
        final delayedValue = Curves.easeOutBack.transform(
          rawValue.clamp(0.0, 1.0),
        );
        
        return Transform.scale(
          scale: delayedValue,
          child: Opacity(
            opacity: delayedValue.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 65,
          height: 65,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryLight, AppColors.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
    );
  }
}
