import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  // Check if biometric authentication is available on device
  static Future<bool> isBiometricAvailable() async {
    if (kIsWeb) return false;
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (_) {
      return false;
    }
  }

  // Authenticate user using biometric unlock
  static Future<bool> authenticate() async {
    if (kIsWeb) return false;
    try {
      return await _auth.authenticate(
        localizedReason: 'Please authenticate to log in to AssetPulse Pro',
        biometricOnly: true,
      );
    } catch (_) {
      return false;
    }
  }

  // Save credentials for auto login
  static Future<void> saveCredentials(String email, String password) async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_email', email);
    await prefs.setString('saved_password', password);
    await prefs.setBool('use_biometric', true);
  }

  // Clear credentials on logout
  static Future<void> clearCredentials() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_email');
    await prefs.remove('saved_password');
    await prefs.setBool('use_biometric', false);
  }

  // Check if auto login is set up
  static Future<bool> hasSavedCredentials() async {
    if (kIsWeb) return false;
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('saved_email');
    final password = prefs.getString('saved_password');
    final useBiometric = prefs.getBool('use_biometric') ?? false;
    return useBiometric && email != null && password != null;
  }

  // Retrieve saved credentials
  static Future<Map<String, String>?> getSavedCredentials() async {
    if (kIsWeb) return null;
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('saved_email');
    final password = prefs.getString('saved_password');
    if (email != null && password != null) {
      return {'email': email, 'password': password};
    }
    return null;
  }

  // Get App Lock settings
  static Future<bool> isAppLockBiometricsEnabled() async {
    if (kIsWeb) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('app_lock_biometrics_enabled') ?? false;
  }

  static Future<void> setAppLockBiometricsEnabled(bool enabled) async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_lock_biometrics_enabled', enabled);
  }

  static Future<bool> isAppLockPinEnabled() async {
    if (kIsWeb) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('app_lock_pin_enabled') ?? false;
  }

  static Future<void> setAppLockPinEnabled(bool enabled) async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_lock_pin_enabled', enabled);
  }

  static Future<String?> getAppLockPin() async {
    if (kIsWeb) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('app_lock_pin');
  }

  static Future<void> setAppLockPin(String pin) async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_lock_pin', pin);
    await prefs.setBool('app_lock_pin_enabled', true);
  }

  static Future<void> clearAppLockPin() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('app_lock_pin');
    await prefs.setBool('app_lock_pin_enabled', false);
  }
}
