import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_version.dart';

class VersionCheckResult {
  final bool isSupported;
  final String installedVersion;
  final String minRequiredVersion;
  final String message;

  const VersionCheckResult({
    required this.isSupported,
    required this.installedVersion,
    required this.minRequiredVersion,
    required this.message,
  });
}

class AppVersionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'system_settings';
  static const String _docId = 'app_version';

  /// Verifies if the currently running app version satisfies the minimum required version in Firestore.
  static Future<VersionCheckResult> checkVersion() async {
    const installed = AppVersion.currentVersion;

    try {
      final docRef = _firestore.collection(_collection).doc(_docId);
      
      // Try querying the server directly so devices don't bypass checks using stale cache
      DocumentSnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await docRef.get(const GetOptions(source: Source.server));
      } catch (_) {
        snapshot = await docRef.get(const GetOptions(source: Source.serverAndCache));
      }

      if (!snapshot.exists || snapshot.data() == null) {
        // First-time setup: initialize Firestore with the current installed baseline
        try {
          await docRef.set({
            'min_supported_version': installed,
            'latest_version': installed,
            'force_update_message':
                'A critical update is required. Please update to AssetPulse Pro v$installed or later to access your plant system.',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (_) {}

        return const VersionCheckResult(
          isSupported: true,
          installedVersion: installed,
          minRequiredVersion: installed,
          message: '',
        );
      }

      final data = snapshot.data()!;
      var minRequired = (data['min_supported_version'] ?? installed).toString().trim();
      final customMessage = data['force_update_message']?.toString() ??
          'This version (v$installed) is no longer supported. Please update to v$minRequired to continue using AssetPulse Pro.';

      // Automatically keep Firestore backend synchronized with the newest version release
      // If the installed version is newer than the cloud min_supported_version (e.g., installed 2.5.1 vs cloud 2.5.0),
      // update Firestore so that older versions (2.5.0) are gated immediately across all devices.
      if (AppVersion.isVersionSupported(installed, minRequired) && installed != minRequired) {
        try {
          await docRef.set({
            'min_supported_version': installed,
            'latest_version': installed,
            'force_update_message':
                'A critical update is required. Please update to AssetPulse Pro v$installed or later to access your plant system.',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          minRequired = installed;
        } catch (e) {
          debugPrint('Error updating Firestore app_version: $e');
        }
      }

      final isSupported = AppVersion.isVersionSupported(installed, minRequired);

      return VersionCheckResult(
        isSupported: isSupported,
        installedVersion: installed,
        minRequiredVersion: minRequired,
        message: customMessage,
      );
    } catch (e) {
      debugPrint('AppVersionService check warning: $e');
      // On network failure or offline mode, do not block users who already have valid local sessions
      return const VersionCheckResult(
        isSupported: true,
        installedVersion: installed,
        minRequiredVersion: installed,
        message: '',
      );
    }
  }

  /// Fetch raw system_settings/app_version document data
  static Future<Map<String, dynamic>?> getVersionDoc() async {
    try {
      final snap = await _firestore.collection(_collection).doc(_docId).get();
      return snap.data();
    } catch (e) {
      debugPrint('Error getting version doc: $e');
      return null;
    }
  }

  /// Administrator helper to bump the minimum required version in Firestore.
  static Future<void> setMinSupportedVersion(String minVersion, {String? message, String? latestVersion}) async {
    await _firestore.collection(_collection).doc(_docId).set({
      'min_supported_version': minVersion.trim(),
      'latest_version': (latestVersion ?? minVersion).trim(),
      if (message != null && message.trim().isNotEmpty) 'force_update_message': message.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
