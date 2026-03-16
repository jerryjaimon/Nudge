import 'package:flutter/services.dart';

class PomodoroService {
  static const MethodChannel _channel = MethodChannel('com.example.nudge/pomodoro');

  static Future<bool> checkOverlayPermission() async {
    try {
      return await _channel.invokeMethod<bool>('checkOverlayPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestOverlayPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestOverlayPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> startBlocker(List<String> apps) async {
    try {
      await _channel.invokeMethod('startBlocker', {'apps': apps});
    } catch (e) {
      print('Failed to start Pomodoro Blocker: $e');
    }
  }

  static Future<void> stopBlocker() async {
    try {
      await _channel.invokeMethod('stopBlocker');
    } catch (e) {
      print('Failed to stop Pomodoro Blocker: $e');
    }
  }
}
