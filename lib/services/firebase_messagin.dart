import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:radiomr/services/local_notification_service.dart';

class FirebaseMessagingService {
  // Private constructor for singleton pattern
  FirebaseMessagingService._internal();

  // Singleton instance
  static final FirebaseMessagingService _instance =
      FirebaseMessagingService._internal();

  // Factory constructor to provide singleton instance
  factory FirebaseMessagingService.instance() => _instance;

  // Reference to local notifications service for displaying notifications
  LocalNotificationsService? _localNotificationsService;

  /// Initialize Firebase Messaging and sets up all message listeners
  Future<void> init(
      {required LocalNotificationsService localNotificationsService}) async {
    // Init local notifications service
    _localNotificationsService = localNotificationsService;

    // Handle FCM token
    _handlePushNotificationsToken();

    // Request user permission for notifications
    _requestPermission();

    // Register handler for background messages (app terminated)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Listen for messages when the app is in foreground
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // Listen for notification taps when the app is in background but not terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    // Check for initial message that opened the app from terminated state
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _onMessageOpenedApp(initialMessage);
    }
  }

  /// Retrieves and manages the FCM token for push notifications
  Future<void> _handlePushNotificationsToken() async {
    // Request notification permissions first
    NotificationSettings settings =
        await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Notification permission granted.');
      String? apnsToken;

      // Try to obtain APNs token on iOS. On simulators/emulators this may
      // never be set or may throw a FirebaseException. Use a helper that
      // retries for a short period and always catches errors so the app
      // doesn't crash in the emulator.
      try {
        apnsToken = await _getApnsTokenWithTimeout(const Duration(seconds: 5));
        if (apnsToken != null && apnsToken.isNotEmpty) {
          print('APNs token: $apnsToken');
        } else {
          print('APNs token not available (simulator or delayed).');
        }
      } catch (e) {
        // Defensive: log and continue. Emulators often don't provide APNs.
        print('Error obtaining APNs token (ignored): $e');
      }

      if (!Platform.isIOS || (apnsToken != null && apnsToken.isNotEmpty)) {
        await _subscribeToGlobalTopic();
      }

      // Get the FCM token (works on both Android and iOS)
      try {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        print('FCM token: $fcmToken');
      } catch (e) {
        print('Error obtaining FCM token: $e');
      }

      // Listen for token refresh events
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        print('FCM token refreshed: $newToken');
        // TODO: Send token to your backend if needed
      }).onError((error) {
        print('Error refreshing FCM token: $error');
      });
    } else {
      print('Notification permission denied.');
    }
  }

  Future<void> _subscribeToGlobalTopic() async {
    try {
      await FirebaseMessaging.instance
          .subscribeToTopic('all-users')
          .timeout(const Duration(seconds: 10));
      print('Successfully subscribed to the "all-users" topic.');
    } catch (error) {
      print('Error subscribing to topic: $error');
    }
  }

  /// Try to obtain the APNs token for a short timeout period.
  ///
  /// This method will repeatedly call `getAPNSToken()` until a non-null
  /// value is returned or the [timeout] elapses. It catches and ignores
  /// FirebaseExceptions which are commonly thrown on simulators/emulators.
  Future<String?> _getApnsTokenWithTimeout(Duration timeout) async {
    final sw = Stopwatch()..start();
    const retryDelay = Duration(milliseconds: 500);
    while (sw.elapsed < timeout) {
      try {
        final token = await FirebaseMessaging.instance.getAPNSToken();
        if (token != null && token.isNotEmpty) return token;
      } on Exception catch (e) {
        // Common on simulators/emulators; swallow and retry until timeout.
        print('getAPNSToken threw (will retry): ${e.toString()}');
      } catch (e) {
        // Unexpected error — log and break to avoid tight-looping on unknown
        print('Unexpected error while getting APNs token: $e');
        break;
      }

      await Future.delayed(retryDelay);
    }

    return null;
  }

  /// Requests notification permission from the user
  Future<void> _requestPermission() async {
    // Request permission for alerts, badges, and sounds
    final result = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Log the user's permission decision
    print('User granted permission: ${result.authorizationStatus}');
  }

  /// Handles messages received while the app is in the foreground
  void _onForegroundMessage(RemoteMessage message) {
    print('Foreground message received: ${message.data.toString()}');
    final notificationData = message.notification;
    if (notificationData != null) {
      // Display a local notification using the service
      _localNotificationsService?.showNotification(notificationData.title,
          notificationData.body, message.data.toString());
    }
  }

  /// Handles notification taps when app is opened from the background or terminated state
  void _onMessageOpenedApp(RemoteMessage message) {
    print('Notification caused the app to open: ${message.data.toString()}');
    // TODO: Add navigation or specific handling based on message data
  }
}

/// Background message handler (must be top-level function or static)
/// Handles messages when the app is fully terminated
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Background message received: ${message.data.toString()}');
}
