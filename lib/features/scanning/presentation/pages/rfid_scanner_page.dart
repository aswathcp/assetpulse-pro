import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';

class RFIDScannerPage extends StatefulWidget {
  const RFIDScannerPage({super.key});

  @override
  State<RFIDScannerPage> createState() => _RFIDScannerPageState();
}

class _RFIDScannerPageState extends State<RFIDScannerPage> {
  bool _isScanning = false;
  String _status = 'Ready to scan';
  final String _scannedTag = '';

  // This is a placeholder for RFID scanning
  // In production, you would integrate with specific RFID reader SDKs
  // like Chainway UHF RFID or Bluetooth RFID modules
  
  Future<void> _startRFIDScan() async {
    setState(() {
      _isScanning = true;
      _status = 'Scanning for RFID tags...';
    });

    // TODO: Integrate with actual RFID reader SDK
    // For Chainway devices: Use their SDK
    // For Bluetooth RFID: Use flutter_blue_plus or similar
    
    // Placeholder simulation
    await Future.delayed(const Duration(seconds: 2));
    
    setState(() {
      _isScanning = false;
      _status = 'RFID reader not connected';
    });
  }

  void _stopRFIDScan() {
    setState(() {
      _isScanning = false;
      _status = 'Scan cancelled';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('RFID Scanner'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GlassContainer(
              width: 400,
              height: 300,
              borderRadius: 24,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.sensors,
                    size: 80,
                    color: AppColors.accent,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'RFID Not Supported on Web',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Please use the mobile application with a compatible RFID reader',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                    ),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('RFID Scanner'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GlassContainer(
                width: double.infinity,
                height: 450,
                borderRadius: 24,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.sensors,
                      size: 120,
                      color: _isScanning ? AppColors.accent : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      _status,
                      style: TextStyle(
                        fontSize: 18,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_scannedTag.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Tag: $_scannedTag',
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Supports:\n• Chainway UHF RFID Readers\n• Bluetooth RFID Modules',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).disabledColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (!_isScanning)
                      ElevatedButton.icon(
                        onPressed: _startRFIDScan,
                        icon: const Icon(Icons.sensors),
                        label: const Text('Start RFID Scan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: _stopRFIDScan,
                        icon: const Icon(Icons.stop),
                        label: const Text('Cancel'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
