import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    if (kReleaseMode) {
      // Production URL
      return 'https://your-production-url.com/api/';
    }

    // Debug environment
    if (kIsWeb) {
      return 'http://localhost:8000/api/';
    }

    if (Platform.isAndroid) {
      // Android emulator points to 10.0.2.2 for host's localhost
      return 'http://10.0.2.2:8000/api/';
    } else if (Platform.isIOS) {
      // iOS Simulator points to localhost, but physical devices need the Mac's IP
      // 192.168.1.168 is the Mac's IP address on the local network.
      return 'http://192.168.1.168:8000/api/';
    }

    // Fallback
    return 'http://localhost:8000/api/';
  }
}
