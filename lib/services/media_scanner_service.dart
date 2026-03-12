import 'package:flutter/services.dart';

class MediaScannerService {
  static const MethodChannel _channel =
      MethodChannel('com.example.thesis_system_v4/media_scanner');

  static Future<void> scanFile(String path) async {
    try {
      await _channel.invokeMethod('scanFile', {"path": path});
    } catch (e) {
      print("Media scan error: $e");
    }
  }
}