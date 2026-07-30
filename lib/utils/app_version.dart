import 'package:package_info_plus/package_info_plus.dart';

class AppVersion {
  static String _version = '';

  static Future<void> init() async {
    final info = await PackageInfo.fromPlatform();
    _version = info.version;
  }

  static String get version => _version.isEmpty ? '' : 'v$_version';
}