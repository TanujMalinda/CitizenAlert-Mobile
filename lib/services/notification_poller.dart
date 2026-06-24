import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';
import 'notification_service.dart';

/// Polls the backend for new "updates to my reports" notifications and pushes
/// them to the device via NotificationService.
///
/// This is the temporary transport that the hybrid design replaces with FCM
/// later — the display layer (NotificationService) stays identical.
class NotificationPoller {
  NotificationPoller(this._api);

  final ApiService _api;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Timer? _timer;
  int _lastSeenId = 0;
  static const _key = 'last_notification_id';
  static const _interval = Duration(seconds: 30);

  /// Called whenever the unread count may have changed, so the UI can refresh
  /// its badge.
  VoidCallback? onChanged;

  Future<void> start() async {
    final saved = await _storage.read(key: _key);
    _lastSeenId = int.tryParse(saved ?? '0') ?? 0;

    // Run once immediately, then on an interval.
    await _check();
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _check());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _check() async {
    try {
      final res = await _api.getNotifications(sinceId: _lastSeenId);
      final list = (res['data'] as List?) ?? [];
      if (list.isEmpty) return;

      // API returns newest-first; show oldest-first so the latest ends on top.
      final items = list.reversed.toList();
      for (final raw in items) {
        final n = raw as Map<String, dynamic>;
        final id = (n['id'] ?? 0) as int;
        if (id <= _lastSeenId) continue;

        await NotificationService.instance.show(
          id: id,
          title: n['title']?.toString() ?? 'CitizenAlert',
          body: n['body']?.toString() ?? '',
          payload: n['alert_id']?.toString(),
        );
        if (id > _lastSeenId) _lastSeenId = id;
      }

      await _storage.write(key: _key, value: _lastSeenId.toString());
      onChanged?.call();
    } catch (e) {
      // Silent — likely just offline / tunnel down; we retry next interval.
      debugPrint('NotificationPoller check failed: $e');
    }
  }
}
