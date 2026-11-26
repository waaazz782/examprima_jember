import 'package:flutter/services.dart';
class AppUninstallerService {
  AppUninstallerService._();

  static final AppUninstallerService instance = AppUninstallerService._();

  static const MethodChannel _channel =
      MethodChannel('com.examprimajember/kiosk');

  Future<String?> uninstall(String packageName) {
    return _channel.invokeMethod<String>('uninstallApp', {
      'packageName': packageName,
    });
  }
}