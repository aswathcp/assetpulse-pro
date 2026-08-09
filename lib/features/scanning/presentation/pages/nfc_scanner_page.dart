import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:nfc_manager/nfc_manager.dart';
// import 'package:nfc_manager_ndef/nfc_manager_ndef.dart'; // Commented out to check if it's needed or if nfc_manager exports it
// Actually I will add it directly.
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart'; // Speculative import based on search
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';

class NFCScannerPage extends StatefulWidget {
  const NFCScannerPage({super.key});

  @override
  State<NFCScannerPage> createState() => _NFCScannerPageState();
}

class _NFCScannerPageState extends State<NFCScannerPage> {
  bool _isScanning = false;
  String _status = 'Ready to scan';

  @override
  void initState() {
    super.initState();
    _checkNFCAvailability();
  }

  Future<void> _checkNFCAvailability() async {
    if (kIsWeb) {
      setState(() => _status = 'NFC not supported on web');
      return;
    }

    bool isAvailable = (await NfcManager.instance.checkAvailability()) == NfcAvailability.enabled;
    if (!isAvailable) {
      setState(() => _status = 'NFC not available on this device');
    }
  }

  Future<void> _startNFCScan() async {
    if (kIsWeb) return;

    setState(() {
      _isScanning = true;
      _status = 'Hold your device near an NFC tag...';
    });

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693, NfcPollingOption.iso18092},
        onDiscovered: (NfcTag tag) async {
          // Extract NFC data
          String tagData = '';
          // ignore: invalid_use_of_protected_member
          final Map<String, dynamic> data = Map<String, dynamic>.from(tag.data as Map);
          
          // Try to read NDEF data
          final ndef = Ndef.from(tag);
          if (ndef != null) {
            if (ndef.cachedMessage != null) {
              for (var record in ndef.cachedMessage!.records) {
                tagData += String.fromCharCodes(record.payload);
              }
            }
          }
          
          // If no NDEF, get tag identifier from available tech
          if (tagData.isEmpty) {
            // Try different tag technologies
            final tagId = data['nfca']?['identifier'] ?? 
                         data['nfcb']?['identifier'] ??
                         data['nfcf']?['identifier'] ??
                         data['nfcv']?['identifier'];
            
            if (tagId != null && tagId is List) {
              tagData = tagId.map((e) => e.toRadixString(16).padLeft(2, '0')).join(':');
            }
          }

          await NfcManager.instance.stopSession();
          
          if (mounted) {
            Navigator.pop(context, tagData);
          }
        },
      );
    } catch (e) {
      setState(() {
        _isScanning = false;
        _status = 'Error: $e';
      });
    }
  }

  void _stopNFCScan() {
    NfcManager.instance.stopSession();
    setState(() {
      _isScanning = false;
      _status = 'Scan cancelled';
    });
  }

  @override
  void dispose() {
    if (_isScanning) {
      NfcManager.instance.stopSession();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('NFC Scanner'),
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
                    Icons.nfc,
                    size: 80,
                    color: AppColors.accent,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'NFC Not Supported on Web',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Please use the mobile application for NFC scanning',
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
        title: const Text('NFC Scanner'),
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
                height: 400,
                borderRadius: 24,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.nfc,
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
                    const SizedBox(height: 48),
                    if (!_isScanning)
                      ElevatedButton.icon(
                        onPressed: _startNFCScan,
                        icon: const Icon(Icons.nfc),
                        label: const Text('Start NFC Scan'),
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
                        onPressed: _stopNFCScan,
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
