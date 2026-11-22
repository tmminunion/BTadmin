import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/admin_theme.dart';
import 'bt_admin_api.dart';

@pragma('vm:entry-point')
Future<void> btadminFcmBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

class AdminFcmService {
  AdminFcmService._();

  static bool _initialized = false;
  static String? _lastRegisteredToken;

  static Future<void> initAndRegister({
    required String authToken,
    BuildContext? context,
  }) async {
    if (kIsWeb) return;
    try {
      if (!_initialized) {
        await Firebase.initializeApp();
        FirebaseMessaging.onBackgroundMessage(btadminFcmBackgroundHandler);
        final messaging = FirebaseMessaging.instance;
        await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        await messaging.subscribeToTopic('btadmin_all');

        FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
          final title = msg.notification?.title ?? 'BTadmin';
          final body = msg.notification?.body ?? '';
          if (context != null && context.mounted && body.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$title — $body'),
                backgroundColor: AdminColors.primary,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        });

        messaging.onTokenRefresh.listen((newToken) {
          _sendToken(authToken, newToken);
        });

        _initialized = true;
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _sendToken(authToken, token);
      }
    } catch (e) {
      debugPrint('[AdminFcmService] skip/error: $e');
    }
  }

  static Future<void> _sendToken(String authToken, String fcmToken) async {
    if (fcmToken == _lastRegisteredToken) return;
    try {
      await BtAdminApi().postAction(authToken, 'register_fcm', {
        'fcm_token': fcmToken,
        'platform': 'android',
      });
      _lastRegisteredToken = fcmToken;
    } catch (e) {
      debugPrint('[AdminFcmService] register_fcm failed: $e');
    }
  }
}
