import 'package:flutter/material.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../widgets/modern_bottom_nav_bar.dart';
import '../widgets/scan_menu_overlay.dart';
import 'dashboard_tab.dart';
import '../../../assets/presentation/pages/assets_tab.dart';
import '../../../operations/presentation/pages/operations_tab.dart';
import '../../../analytics/presentation/pages/analytics_tab.dart';

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
      ),
    );
  }
}
