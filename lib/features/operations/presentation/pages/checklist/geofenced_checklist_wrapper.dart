import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:asset_pulse_pro/core/services/location_verification_service.dart';
import 'package:asset_pulse_pro/core/widgets/pulse_loading.dart';
import 'package:asset_pulse_pro/features/home/presentation/widgets/custom_app_bar.dart';
import 'package:asset_pulse_pro/core/constants/app_colors.dart';


class GeofencedChecklistWrapper extends StatefulWidget {
  final double targetLatitude;
  final double targetLongitude;
  final String targetName;
  final Widget Function(Position startPosition, bool isVerified) builder;

  const GeofencedChecklistWrapper({
    super.key,
    required this.targetLatitude,
    required this.targetLongitude,
    required this.targetName,
    required this.builder,
  });

  @override
  State<GeofencedChecklistWrapper> createState() => _GeofencedChecklistWrapperState();
}

class _GeofencedChecklistWrapperState extends State<GeofencedChecklistWrapper> {
  bool _isLoading = true;
  bool _isVerified = false;
  bool _isVerifiedByGps = false;
  Position? _startPosition;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _verifyLocation();
  }

  Future<void> _verifyLocation() async {
    final locationService = LocationVerificationService();
    final currentPos = await locationService.getCurrentLocation();

    if (currentPos == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not fetch location. Please ensure location permissions are enabled. For Web, ensure you are allowing location access in your browser.';
        });
      }
      return;
    }

    final isWithin = locationService.isWithinRadius(
      currentPos,
      widget.targetLatitude,
      widget.targetLongitude,
      radiusInMeters: 50.0, // Initial leniency for GPS drift
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _startPosition = currentPos;
        _isVerified = isWithin;
        _isVerifiedByGps = isWithin;
        if (!isWithin) {
          _errorMessage = 'You are not within the required range (50m) of ${widget.targetName}. Please move closer and try again.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'Verifying Location'),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const PulseLoading(size: 80),
              const SizedBox(height: 24),
              Text(
                'Verifying your presence at ${widget.targetName}...',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (!_isVerified) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'Verification Failed'),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_off, color: Colors.orangeAccent, size: 80),
              const SizedBox(height: 24),
              Text(
                _errorMessage,
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text('Try Again', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _errorMessage = '';
                      });
                      _verifyLocation();
                    },
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.orangeAccent),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    icon: const Icon(Icons.warning_amber_outlined, color: Colors.orangeAccent),
                    label: const Text('Proceed Without Verification', style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      setState(() {
                        _startPosition = _startPosition ?? Position(
                          longitude: widget.targetLongitude,
                          latitude: widget.targetLatitude,
                          timestamp: DateTime.now(),
                          accuracy: 1000, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0
                        );
                        _isVerified = true;
                        _isVerifiedByGps = false;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: CustomAppBar(title: widget.targetName),
      body: widget.builder(_startPosition!, _isVerifiedByGps),
    );
  }
}
