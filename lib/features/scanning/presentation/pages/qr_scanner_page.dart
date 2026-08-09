import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        // Analyze image for QR code
        final BarcodeCapture? barcodes = await cameraController.analyzeImage(image.path);
        if (barcodes != null && barcodes.barcodes.isNotEmpty) {
          _handleBarcode(barcodes.barcodes.first);
        } else {
          _showMessage('No QR code found in image');
        }
      }
    } catch (e) {
      _showMessage('Error picking image: $e');
    }
  }

  void _handleBarcode(Barcode barcode) {
    if (_isProcessing) return;
    
    setState(() => _isProcessing = true);
    
    final String code = barcode.rawValue ?? '';
    
    if (code.isNotEmpty) {
      // Return the scanned code
      Navigator.pop(context, code);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('QR Scanner'),
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
                    Icons.qr_code_scanner,
                    size: 80,
                    color: AppColors.accent,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'QR Scanning Not Supported on Web',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Please use the mobile application for QR code scanning',
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
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library),
            onPressed: _pickFromGallery,
            tooltip: 'Pick from gallery',
          ),
          IconButton(
            icon: const Icon(Icons.flash_off),
            onPressed: () => cameraController.toggleTorch(),
            tooltip: 'Toggle flash',
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                _handleBarcode(barcodes.first);
              }
            },
          ),
          // Scanning overlay
          Positioned.fill(
            child: CustomPaint(
              painter: ScannerOverlayPainter(),
            ),
          ),
          // Instructions
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: GlassContainer(
                width: null,
                height: null,
                borderRadius: 12,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Text(
                    'Align QR code within the frame',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.fill;

    final scanArea = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: 250,
      height: 250,
    );

    // Draw dark overlay with transparent center
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()
          ..addRRect(RRect.fromRectAndRadius(scanArea, const Radius.circular(12))),
      ),
      paint,
    );

    // Draw corner brackets
    final cornerPaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final cornerLength = 30.0;
    
    // Top-left
    canvas.drawLine(scanArea.topLeft, scanArea.topLeft + Offset(cornerLength, 0), cornerPaint);
    canvas.drawLine(scanArea.topLeft, scanArea.topLeft + Offset(0, cornerLength), cornerPaint);
    
    // Top-right
    canvas.drawLine(scanArea.topRight, scanArea.topRight + Offset(-cornerLength, 0), cornerPaint);
    canvas.drawLine(scanArea.topRight, scanArea.topRight + Offset(0, cornerLength), cornerPaint);
    
    // Bottom-left
    canvas.drawLine(scanArea.bottomLeft, scanArea.bottomLeft + Offset(cornerLength, 0), cornerPaint);
    canvas.drawLine(scanArea.bottomLeft, scanArea.bottomLeft + Offset(0, -cornerLength), cornerPaint);
    
    // Bottom-right
    canvas.drawLine(scanArea.bottomRight, scanArea.bottomRight + Offset(-cornerLength, 0), cornerPaint);
    canvas.drawLine(scanArea.bottomRight, scanArea.bottomRight + Offset(0, -cornerLength), cornerPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
