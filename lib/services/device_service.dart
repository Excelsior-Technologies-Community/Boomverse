import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';

class DeviceService {
  static const String _deviceIdKey = 'device_id';
  static DeviceService? _instance;
  late String _deviceId;
  bool _isInitialized = false;

  // Static getter to access current device ID (might be null if not initialized)
  static String? get uid => DeviceService()._isInitialized ? DeviceService()._deviceId : null;

  // Private constructor
  DeviceService._();

  // Factory constructor to return the singleton instance
  factory DeviceService() {
    _instance ??= DeviceService._();
    return _instance!;
  }

  bool get isInitialized => _isInitialized;
  String get deviceId => _deviceId;
  
  // Get sanitized version of device ID for Firebase paths
  String get sanitizedDeviceId => sanitizeDatabasePath(_deviceId);

  // Sanitize any string for use in Firebase database paths
  String sanitizeDatabasePath(String path) {
    // Replace invalid Firebase path characters
    return path.replaceAll('.', '_')
              .replaceAll('#', '_')
              .replaceAll('\$', '_')
              .replaceAll('[', '_')
              .replaceAll(']', '_');
  }

  Future<String> initDeviceId() async {
    if (_isInitialized) return _deviceId;

    // Try to get device ID from SharedPreferences first
    final prefs = await SharedPreferences.getInstance();
    String? storedId = prefs.getString(_deviceIdKey);

    if (storedId != null && storedId.isNotEmpty) {
      _deviceId = storedId;
      _isInitialized = true;
      return _deviceId;
    }

    // If not found, generate a new device ID
    _deviceId = await _generateDeviceId();
    
    // Store the new device ID
    await prefs.setString(_deviceIdKey, _deviceId);
    _isInitialized = true;
    
    return _deviceId;
  }

  Future<String> _generateDeviceId() async {
    String deviceId = '';
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

    try {
      if (kIsWeb) {
        // Web platform
        final webInfo = await deviceInfo.webBrowserInfo;
        deviceId = webInfo.browserName.toString() + '-' + const Uuid().v4();
      } else if (Platform.isAndroid) {
        // Android platform
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        // iOS platform
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? const Uuid().v4();
      } else {
        // Other platforms
        deviceId = const Uuid().v4();
      }
    } on PlatformException {
      // Fallback to UUID in case of errors
      deviceId = const Uuid().v4();
    }

    // Make sure we have a value
    if (deviceId.isEmpty) {
      deviceId = const Uuid().v4();
    }

    return deviceId;
  }

  Future<String> getUserId() async {
    if (!_isInitialized) {
      await initDeviceId();
    }
    return _deviceId;
  }
  
  // Check if this is likely a new device (no data migration needed)
  Future<bool> isNewDevice() async {
    if (!_isInitialized) {
      await initDeviceId();
    }
    
    final prefs = await SharedPreferences.getInstance();
    return !prefs.containsKey('coins'); // If no saved coins, probably new device
  }
} 