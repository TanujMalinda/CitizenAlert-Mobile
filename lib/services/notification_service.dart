import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Single display layer for all device notifications.
///
/// Right now it is fed by polling (see NotificationPoller). It is intentionally
/// source-agnostic: when Firebase Cloud Messaging is added later, the FCM
/// `onMessage` handler just calls `show(...)` here — no other UI code changes.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;

  /// Optional callback when a notification is tapped (payload = alert id text).
  void Function(String? payload)? onTap;

  static const _channel = AndroidNotificationChannel(
    'citizenalert_alerts',
    'CitizenAlert Notifications',
    description: 'New nearby alerts and updates to your reports',
    importance: Importance.high,
  );

  Future<void> init() async {
    if (_ready) return;

    const android = AndroidInitializationSettings('@drawable/ic_notification');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (resp) => onTap?.call(resp.payload),
    );

    // Android 8+ notification channel
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Android 13+ runtime permission
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _ready = true;
  }

  /// Display a notification. `id` should be unique per logical notification so
  /// the OS doesn't collapse distinct alerts into one.
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_ready) await init();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'citizenalert_alerts',
        'CitizenAlert Notifications',
        channelDescription: 'New nearby alerts and updates to your reports',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@drawable/ic_notification',
      ),
    );

    try {
      await _plugin.show(id, title, body, details, payload: payload);
    } catch (e) {
      debugPrint('NotificationService.show failed: $e');
    }
  }
}
