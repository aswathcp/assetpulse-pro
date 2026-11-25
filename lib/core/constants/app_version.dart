class AppVersion {
  static const String currentVersion = '2.5.3';
  static const String buildNumber = '2026.2.53-PRO';
  static const String standardCompliance = 'ISO 55000 / IEC 60034 / IEEE 43';

  /// Compare two semantic version strings (e.g. '2.5.0' and '2.4.0').
  /// Returns true if [installedVersion] is greater than or equal to [minRequiredVersion].
  static bool isVersionSupported(String installedVersion, String minRequiredVersion) {
    try {
      final installedParts = _parseVersion(installedVersion);
      final requiredParts = _parseVersion(minRequiredVersion);

      for (int i = 0; i < 3; i++) {
        if (installedParts[i] > requiredParts[i]) return true;
        if (installedParts[i] < requiredParts[i]) return false;
      }
      return true; // Exactly equal
    } catch (_) {
      // In case of parsing failure, fallback to direct string equality
      return installedVersion.trim() == minRequiredVersion.trim();
    }
  }

  static List<int> _parseVersion(String v) {
    // Strip leading 'v' or 'V' and any build metadata (+ or -)
    var cleaned = v.trim();
    if (cleaned.startsWith('v') || cleaned.startsWith('V')) {
      cleaned = cleaned.substring(1);
    }
    if (cleaned.contains('+')) {
      cleaned = cleaned.split('+').first;
    }
    if (cleaned.contains('-')) {
      cleaned = cleaned.split('-').first;
    }

    final segments = cleaned.split('.');
    final major = segments.isNotEmpty ? int.tryParse(segments[0]) ?? 0 : 0;
    final minor = segments.length > 1 ? int.tryParse(segments[1]) ?? 0 : 0;
    final patch = segments.length > 2 ? int.tryParse(segments[2]) ?? 0 : 0;

    return [major, minor, patch];
  }
}
