import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Saves [bytes] as [fileName] to the public Downloads folder on mobile.
/// Returns the full saved path on success, or null on failure.
Future<String?> downloadFile(List<int> bytes, String fileName) async {
  try {
    Directory? dir;

    if (Platform.isAndroid) {
      // Try public Downloads folder inside Assetpulse-pro folder first
      final publicDir = Directory('/storage/emulated/0/Download/Assetpulse-pro');
      try {
        if (!await publicDir.exists()) {
          await publicDir.create(recursive: true);
        }
        dir = publicDir;
      } catch (e) {
        debugPrint('Failed to write to public Download/Assetpulse-pro directory, falling back: $e');
        dir = await getDownloadsDirectory();
      }
    } else if (Platform.isIOS) {
      // On iOS, Documents directory is visible via the Files app
      dir = await getApplicationDocumentsDirectory();
    }

    if (dir == null) {
      debugPrint('Could not resolve download directory for: $fileName');
      return null;
    }

    final path = '${dir.path}/$fileName';
    final file = File(path);
    await file.writeAsBytes(bytes);
    debugPrint('File saved to: $path');
    return path;
  } catch (e) {
    debugPrint('Error saving file: $e');
    return null;
  }
}
