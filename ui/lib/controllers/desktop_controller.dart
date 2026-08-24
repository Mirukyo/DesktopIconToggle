import 'package:flutter/services.dart';

import '../bridge.dart';

class DesktopController {
  static const String channelName =
      'desktop_icon_toggle/native';

  bool desktopIconsHidden = false;

  VoidCallback? _onStateChanged;

  // ==========================================================
  // Start native state listener
  // ==========================================================

  void startListening(
    VoidCallback onStateChanged,
  ) {
    _onStateChanged =
        onStateChanged;

    const channel =
        MethodChannel(channelName);

    channel.setMethodCallHandler(
      _handleNativeMethodCall,
    );
  }

  // ==========================================================
  // Stop native state listener
  // ==========================================================

  void stopListening() {
    const channel =
        MethodChannel(channelName);

    channel.setMethodCallHandler(null);

    _onStateChanged = null;
  }

  // ==========================================================
  // Native -> Flutter
  // ==========================================================

  Future<dynamic> _handleNativeMethodCall(
    MethodCall call,
  ) async {
    if (call.method !=
        'desktopIconStateChanged') {
      return null;
    }

    final arguments =
        call.arguments;

    if (arguments is bool) {
      desktopIconsHidden =
          arguments;

      _onStateChanged?.call();
    }

    return null;
  }

  // ==========================================================
  // Load current desktop state
  // ==========================================================

  Future<void> loadState() async {
    desktopIconsHidden =
        await NativeBridge
            .getDesktopIconState();
  }

  // ==========================================================
  // Synchronize current desktop state
  // ==========================================================

  Future<bool> syncState() async {
    final hidden =
        await NativeBridge
            .getDesktopIconState();

    desktopIconsHidden =
        hidden;

    return hidden;
  }

  // ==========================================================
  // Toggle desktop icons
  // ==========================================================

  Future<bool> toggle() async {
    final success =
        await NativeBridge
            .toggleDesktopIcons();

    if (!success) {
      return false;
    }

    await syncState();

    return true;
  }
}