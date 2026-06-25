import 'dart:async';
import 'package:flutter/services.dart';

class SttService {
  static final SttService _instance = SttService._();
  factory SttService() => _instance;
  SttService._();

  static const _channel = MethodChannel('com.humanopen/stt');
  bool _isListening = false;

  bool get isListening => _isListening;

  bool _initialized = false;

  Future<bool> initialize() async {
    try {
      final available = await _channel.invokeMethod<bool>('initialize') ?? false;
      if (available) {
        _initialized = true;
      }
      return available;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<String> listenOnce() async {
    try {
      if (!_initialized) {
        final ok = await initialize();
        if (!ok) return '';
      }
      if (!await hasPermission()) {
        final granted = await requestPermission();
        if (!granted) return '';
      }
      _isListening = true;
      final result = await _channel.invokeMethod<String>('listen',
          {'durationSeconds': 15}) ?? '';
      return result;
    } catch (e) {
      return '';
    } finally {
      _isListening = false;
    }
  }

  void cancel() {
    _isListening = false;
    try {
      _channel.invokeMethod('cancel');
    } catch (_) {}
  }

  void dispose() {
    cancel();
  }
}
