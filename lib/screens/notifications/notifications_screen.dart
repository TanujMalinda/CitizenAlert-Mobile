import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getNotifications();
      final list = (res['data'] as List?) ?? [];
      _items = list.map((e) => e as Map<String, dynamic>).toList();
      // Mark all read once viewed
      await _api.markAllNotificationsRead();
    } catch (_) {
      _items = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  IconData _icon(String type) {
    switch (type) {
      case 'alert_verified': return Icons.verified;
      case 'alert_rejected': return Icons.cancel_outlined;
      case 'alert_resolved': return Icons.check_circle_outline;
      default:               return Icons.notifications;
    }
  }

  Color _color(String type) {
    switch (type) {
      case 'alert_verified': return const Color(0xFF66BB6A);
      case 'alert_rejected': return const Color(0xFFEF5350);
      case 'alert_resolved': return const Color(0xFF90A4AE);
      default:               return const Color(0xFF4FC3F7);
    }
  }

  String _time(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return DateFormat('MMM d, h:mm a').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        foregroundColor: Colors.white,
        title: const Text('Notifications',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFF2A3F52)),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4FC3F7)))
          : _items.isEmpty
              ? Center(
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.notifications_off,
                        color: Color(0xFF2A3F52), size: 48),
                    SizedBox(height: 12),
                    Text('No notifications yet',
                        style: TextStyle(
                            color: Color(0xFF90A4AE), fontSize: 15)),
                  ],
                ))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: const Color(0xFF4FC3F7),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final n = _items[i];
                      final type = n['type']?.toString() ?? '';
                      final read = n['is_read'] == true;
                      final color = _color(type);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: read
                              ? const Color(0xFF16273a)
                              : const Color(0xFF1C2F3F),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: color.withValues(alpha: read ? 0.2 : 0.45)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(color: color, width: 0.5),
                              ),
                              child: Icon(_icon(type), color: color, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(n['title']?.toString() ?? '',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14)),
                                  const SizedBox(height: 4),
                                  Text(n['body']?.toString() ?? '',
                                      style: const TextStyle(
                                          color: Color(0xFF90A4AE),
                                          fontSize: 12.5)),
                                  const SizedBox(height: 6),
                                  Text(_time(n['created_at']?.toString()),
                                      style: const TextStyle(
                                          color: Color(0xFF4A6070),
                                          fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
