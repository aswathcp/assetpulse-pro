import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../widgets/modern_bottom_nav_bar.dart';
import '../widgets/scan_menu_overlay.dart';
import 'dashboard_tab.dart';
import '../../../assets/data/models/asset_model.dart';
import '../../../assets/presentation/pages/assets_tab.dart';
import '../../../assets/presentation/pages/asset_detail_page.dart';
import '../../../operations/presentation/pages/operations_tab.dart';
import '../../../operations/presentation/pages/checklist/geofenced_checklist_wrapper.dart';
import '../../../operations/presentation/pages/checklist/checklists/dynamic_checklist_form.dart';
import '../../../analytics/presentation/pages/analytics_tab.dart';
import '../../../scanning/presentation/pages/qr_scanner_page.dart';
import '../../../scanning/presentation/pages/nfc_scanner_page.dart';
import '../../../scanning/presentation/pages/rfid_scanner_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  bool _showScanMenu = false;

  List<Widget> _buildPages(BuildContext context) {
    return [
      const DashboardTab(),
      const AssetsTab(),
      Center(child: Text('Scan', style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
      const OperationsTab(),
      const AnalyticsTab(),
    ];
  }

  void _handleNavTap(int index) {
    if (index == 2) {
      // Scan button tapped - toggle menu
      setState(() {
        _showScanMenu = !_showScanMenu;
      });
    } else {
      setState(() {
        _currentIndex = index;
        _showScanMenu = false;
      });
    }
  }

  Future<void> _handleScanOptionSelected(String option) async {
    setState(() => _showScanMenu = false);

    String? result;
    if (option == 'QR') {
      result = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (context) => const QRScannerPage()),
      );
    } else if (option == 'NFC') {
      result = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (context) => const NFCScannerPage()),
      );
    } else if (option == 'RFID') {
      result = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (context) => const RFIDScannerPage()),
      );
    }

    if (result != null && result.isNotEmpty && mounted) {
      await _processScanResult(result, option);
    }
  }

  Future<void> _processScanResult(String rawCode, String scanType) async {
    final code = rawCode.trim();
    if (code.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Locating Asset / Checklist...'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final firestoreService = FirestoreService();

      // 1. Check if scanned code is an Asset (Tag No, Serial, Doc ID, RFID)
      AssetModel? asset;
      if (scanType == 'RFID') {
        asset = await firestoreService.getAssetByRfid(code);
      } else {
        asset = await firestoreService.getAssetByTagNo(code);
        asset ??= await firestoreService.getAsset(code);
      }

      if (!mounted) return;

      if (asset != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AssetDetailPage(asset: asset!)),
        );
        return;
      }

      // 2. Check if scanned code is a Custom Checklist
      final checklistQuery = await FirebaseFirestore.instance
          .collection('custom_checklists')
          .where('name', isEqualTo: code)
          .limit(1)
          .get();

      if (!mounted) return;

      if (checklistQuery.docs.isNotEmpty) {
        final checklist = checklistQuery.docs.first.data();
        final isLocationRequired = checklist['isLocationRequired'] == true;

        if (isLocationRequired) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GeofencedChecklistWrapper(
                targetLatitude: (checklist['latitude'] as num).toDouble(),
                targetLongitude: (checklist['longitude'] as num).toDouble(),
                targetName: '${checklist['unitId'] ?? ''} ${checklist['name'] ?? ''}',
                builder: (pos, verified) => DynamicChecklistForm(
                  checklist: checklist,
                  startPosition: pos,
                  isVerified: verified,
                ),
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
        return;
      }

      // Not found
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unrecognized code: "$code" (Not found in Assets or Checklists)'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching code: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          AnimatedGradientBackground(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: KeyedSubtree(
                key: ValueKey<int>(_currentIndex),
                child: _buildPages(context)[_currentIndex],
              ),
            ),
          ),
          // Scan Menu Overlay
          if (_showScanMenu)
            ScanMenuOverlay(
              onClose: () => setState(() => _showScanMenu = false),
              onOptionSelected: _handleScanOptionSelected,
              buttonPosition: Offset(
                MediaQuery.of(context).size.width / 2 - 35,
                110, // Distance from bottom of screen
              ),
            ),
        ],
      ),
      bottomNavigationBar: ModernBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _handleNavTap,
        isScanMenuOpen: _showScanMenu,
      ),
    );
  }
}
