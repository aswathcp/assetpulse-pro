import 'dart:io';

void main() {
  final macosDir = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';
  final webIconsDir = 'web/icons';
  
  if (!Directory(webIconsDir).existsSync()) {
    Directory(webIconsDir).createSync(recursive: true);
  }

  // Copy app icon to web icons and favicon
  final icon512 = File('$macosDir/app_icon_512.png');
  final icon256 = File('$macosDir/app_icon_256.png');
  final icon128 = File('$macosDir/app_icon_128.png');
  final icon32 = File('$macosDir/app_icon_32.png');

  if (icon512.existsSync()) {
    icon512.copySync('$webIconsDir/Icon-512.png');
    icon512.copySync('$webIconsDir/Icon-maskable-512.png');
    print('Updated Icon-512.png and Icon-maskable-512.png');
  }

  if (icon256.existsSync()) {
    icon256.copySync('$webIconsDir/Icon-192.png');
    icon256.copySync('$webIconsDir/Icon-maskable-192.png');
    print('Updated Icon-192.png and Icon-maskable-192.png');
  }

  if (icon128.existsSync()) {
    icon128.copySync('web/favicon.png');
    print('Updated web/favicon.png');
  } else if (icon32.existsSync()) {
    icon32.copySync('web/favicon.png');
    print('Updated web/favicon.png');
  }
}
