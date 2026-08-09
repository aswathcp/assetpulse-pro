import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class LocationVerificationService {
  static final LocationVerificationService _instance = LocationVerificationService._internal();
  factory LocationVerificationService() => _instance;
  LocationVerificationService._internal();

  /// Checks if location services are enabled and if the app has permission.
  /// Requests permission if needed. This is optimized for both mobile and web.
  Future<bool> _checkAndRequestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the 
      // App to enable the location services.
      debugPrint('Location services are disabled.');
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale 
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        debugPrint('Location permissions are denied');
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately. 
      debugPrint('Location permissions are permanently denied, we cannot request permissions.');
      return false;
    } 

    return true;
  }

  /// Gets the current location if permissions are granted.
  Future<Position?> getCurrentLocation() async {
    final hasPermission = await _checkAndRequestPermission();
    if (!hasPermission) return null;

    try {
      // Use lower accuracy for web to speed up and avoid timeout issues, 
      // but keep high for mobile devices requiring tight geofencing.
      final accuracy = kIsWeb ? LocationAccuracy.medium : LocationAccuracy.high;
      
      // Implement rigid timeout to prevent the Android/Web emulator stalling bugs
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: accuracy, timeLimit: const Duration(seconds: 15))
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint("Geolocator request forcefully timed out.");
          throw Exception("Location Request Timed Out.");
        },
      );
    } catch (e) {
      debugPrint("Error fetching location: $e");
      return null;
    }
  }

  /// Calculates if the current location is within a given radius in meters of the target.
  bool isWithinRadius(Position current, double targetLat, double targetLng, {double radiusInMeters = 20.0}) {
    final distanceInMeters = Geolocator.distanceBetween(
      current.latitude, current.longitude,
      targetLat, targetLng
    );
    
    debugPrint("Distance to target is: $distanceInMeters meters. Allowed: $radiusInMeters");
    return distanceInMeters <= radiusInMeters;
  }
}
