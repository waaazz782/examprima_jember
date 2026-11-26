import 'package:appcheck/appcheck.dart';
import 'package:flutter/services.dart';

import '../constants/forbidden_ai_apps.dart';

class AiAppCheckerService {
  AiAppCheckerService({AppCheck? appCheck}) : _appCheck = appCheck ?? AppCheck();

  final AppCheck _appCheck;

  static const MethodChannel _channel =
      MethodChannel('com.examprimajember/kiosk');

  Future<List<ForbiddenAiApp>> findInstalledForbiddenApps() async {
    final List<ForbiddenAiApp> found = [];

    for (final app in kForbiddenAiApps) {
      final bool installed = await _isInstalled(app.packageName);
      if (!installed) continue;

      final bool isPreinstalled = await _isSystemApp(app.packageName);
      if (isPreinstalled) {
        continue;
      }

      found.add(app);
    }

    return found;
  }

  Future<bool> _isInstalled(String packageName) async {
    try {
      return await _appCheck.isAppInstalled(packageName);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _isSystemApp(String packageName) async {
    try {
      final bool? result = await _channel.invokeMethod<bool>(
        'isSystemApp',
        {'packageName': packageName},
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}