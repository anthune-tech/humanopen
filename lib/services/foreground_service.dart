import 'dart:async';
import 'package:flutter/services.dart';

class ForegroundService {
  static const _channel = MethodChannel('com.humanopen/foreground_service');

  Future<void> start() async {
    try {
      await _channel.invokeMethod('startService');
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopService');
    } catch (_) {}
  }
}
