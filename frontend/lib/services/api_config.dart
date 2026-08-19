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

  static const String auth0Domain = String.fromEnvironment(
    'AUTH0_DOMAIN',
    defaultValue: 'b1codes.us.auth0.com',
  );
  static const String auth0ClientId = String.fromEnvironment(
    'AUTH0_CLIENT_ID',
    defaultValue: 'aKyq4Ew0FhtHow6vTmz4IK8WjdJPVt35',
  );
  static const String auth0Audience = String.fromEnvironment(
    'AUTH0_AUDIENCE',
    defaultValue: 'https://api.mapmyfriends.com/',
  );
}
