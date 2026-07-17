import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'backend_api_service.dart';

class FirebaseMessagingService {
  FirebaseMessagingService._();

  static final FirebaseMessagingService instance = FirebaseMessagingService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    await _requestPermission();

    final token = await _messaging.getToken();

    if (token == null || token.isEmpty) {
      debugPrint('MindPulse: FCM token was not generated.');

      return;
    }

    debugPrint(
      'MindPulse: Real FCM token generated. '
      'Length = ${token.length}',
    );

    await _registerToken(token);

    FirebaseMessaging.onMessage.listen((message) {
      debugPrint(
        'MindPulse: Foreground notification: '
        '${message.notification?.title}',
      );
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await _registerToken(newToken);
    });
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission();

    debugPrint(
      'MindPulse: Notification permission = '
      '${settings.authorizationStatus}',
    );
  }

  Future<void> _registerToken(String fcmToken) async {
    try {
      await BackendApiService.instance.registerDeviceToken(fcmToken);

      debugPrint('MindPulse: FCM token registration completed.');
    } catch (error) {
      // App startup-এর সময় user login না থাকলে
      // token registration skip হতে পারে।
      // Login-এর পর AuthService আবার register করবে।
      debugPrint(
        'MindPulse: FCM registration skipped or failed: '
        '$error',
      );
    }
  }
}

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint(
    'MindPulse: Background message received: '
    '${message.messageId}',
  );
}
