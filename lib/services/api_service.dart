import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // Using adb reverse tunnel (USB) — bypasses university WiFi client isolation.
  // Tunnel set up with: adb reverse tcp:8000 tcp:8000
  // The phone's localhost:8000 is forwarded to the laptop's backend over USB.
  static const String baseUrl = 'http://localhost:8000/api';

  final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ApiService() : _dio = Dio(BaseOptions(baseUrl: baseUrl)) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'jwt_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ));
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _dio.post('/auth/login',
        data: {'email': email, 'password': password});
    await _storage.write(key: 'jwt_token', value: res.data['token']);
    await _storage.write(key: 'user_id',   value: res.data['user']['id'].toString());
    await _storage.write(key: 'user_role', value: res.data['user']['role']);
    await _storage.write(key: 'user_name', value: res.data['user']['full_name']);
    return res.data;
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    final res = await _dio.post('/auth/register', data: data);
    await _storage.write(key: 'jwt_token', value: res.data['token']);
    return res.data;
  }

  Future<Map<String, dynamic>> registerAuthority(Map<String, dynamic> data) async {
    // Does NOT store a token — account is pending_approval, cannot log in yet
    final res = await _dio.post('/auth/register-authority', data: data);
    return res.data;
  }

  Future<void> logout() async {
    await _storage.deleteAll();
  }

  Future<String?> getToken() => _storage.read(key: 'jwt_token');
  Future<String?> getUserName() => _storage.read(key: 'user_name');
  Future<String?> getUserRole() => _storage.read(key: 'user_role');

  /// Returns true only if a token exists AND the server accepts it.
  /// On network errors the token is preserved so the user doesn't have to
  /// re-login just because the backend was temporarily unreachable.
  Future<bool> isTokenValid() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token == null) return false;
    try {
      await _dio.get('/auth/me');
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Token is genuinely expired or invalid — clear it.
        await _storage.deleteAll();
      }
      // Any other status (network down, 500, etc.) — keep the token and show login.
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── Missing Persons ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getNearbyAlerts({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
  }) async {
    final res = await _dio.get('/missing-persons/nearby', queryParameters: {
      'latitude':  latitude,
      'longitude': longitude,
      'radius_km': radiusKm,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> createMissingPersonAlert(
      Map<String, dynamic> data) async {
    final res = await _dio.post('/missing-persons/', data: data);
    return res.data;
  }

  Future<Map<String, dynamic>> submitSighting(
      int alertId, Map<String, dynamic> data) async {
    final res = await _dio.post('/missing-persons/$alertId/sightings',
        data: data);
    return res.data;
  }
  // ── Disaster Alerts ───────────────────────────────────────────────────────

Future<Map<String, dynamic>> getNearbyDisasters({
  required double latitude,
  required double longitude,
  double radiusKm = 50.0,
}) async {
  final res = await _dio.get('/disaster-alerts/nearby', queryParameters: {
    'latitude':  latitude,
    'longitude': longitude,
    'radius_km': radiusKm,
  });
  return res.data;
}

Future<Map<String, dynamic>> getDisasterAlert(int alertId) async {
  final res = await _dio.get('/disaster-alerts/$alertId');
  return res.data;
}

/// Citizen reports a disaster — routed to authority review (not auto-verified).
Future<Map<String, dynamic>> submitDisasterReport(
    Map<String, dynamic> data) async {
  final res = await _dio.post('/disaster-alerts/report', data: data);
  return res.data;
}

/// Citizen confirms an existing disaster — increments its confirmation count.
Future<Map<String, dynamic>> confirmDisaster(int alertId) async {
  final res = await _dio.post('/disaster-alerts/$alertId/confirm', data: {});
  return res.data;
}

  // ── Crime Reports ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getNearbyCrimes({
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
    String? incidentType,
  }) async {
    final params = <String, dynamic>{
      'latitude':      latitude,
      'longitude':     longitude,
      'radius_km':     radiusKm,
      'incident_type': incidentType,
    }..removeWhere((_, v) => v == null);
    final res = await _dio.get('/crime-reports/nearby', queryParameters: params);
    return res.data;
  }

  Future<Map<String, dynamic>> submitCrimeReport(
      Map<String, dynamic> data) async {
    final res = await _dio.post('/crime-reports/', data: data);
    return res.data;
  }

  // ── Traffic Hazards ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getNearbyTraffic({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
    String? hazardType,
  }) async {
    final params = <String, dynamic>{
      'latitude':   latitude,
      'longitude':  longitude,
      'radius_km':  radiusKm,
      'hazard_type': hazardType,
    }..removeWhere((_, v) => v == null);
    final res = await _dio.get('/traffic-hazards/nearby', queryParameters: params);
    return res.data;
  }

  Future<Map<String, dynamic>> submitTrafficHazard(
      Map<String, dynamic> data) async {
    final res = await _dio.post('/traffic-hazards/', data: data);
    return res.data;
  }

  Future<Map<String, dynamic>> confirmTrafficHazard(int alertId) async {
    final res = await _dio.post('/traffic-hazards/$alertId/confirm', data: {});
    return res.data;
  }

  // ── Public Health ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getNearbyHealth({
    required double latitude,
    required double longitude,
    double radiusKm = 100.0,
    String? diseaseType,
  }) async {
    final params = <String, dynamic>{
      'latitude':    latitude,
      'longitude':   longitude,
      'radius_km':   radiusKm,
      'disease_type': diseaseType,
    }..removeWhere((_, v) => v == null);
    final res = await _dio.get('/public-health/nearby', queryParameters: params);
    return res.data;
  }

  Future<Map<String, dynamic>> submitHealthReport(
      Map<String, dynamic> data) async {
    final res = await _dio.post('/public-health/', data: data);
    return res.data;
  }

  // ── Alert Tips / Responses ────────────────────────────────────────────────

  /// Send information / a tip about an existing alert (any alert type).
  /// e.g. "I saw the reported bicycle near Pettah market".
  Future<Map<String, dynamic>> submitAlertResponse(
      int alertId, Map<String, dynamic> data) async {
    final res = await _dio.post('/alerts/$alertId/responses', data: data);
    return res.data;
  }

  /// List tips on an alert (authority or the alert's original reporter only).
  Future<Map<String, dynamic>> getAlertResponses(int alertId) async {
    final res = await _dio.get('/alerts/$alertId/responses');
    return res.data;
  }

  // ── Notifications ───────────────────────────────────────────────────────────

  /// Fetch this user's notifications. Pass [sinceId] to only get newer ones.
  Future<Map<String, dynamic>> getNotifications({
    int sinceId = 0,
    bool unreadOnly = false,
  }) async {
    final res = await _dio.get('/notifications/', queryParameters: {
      'since_id': sinceId,
      'unread_only': unreadOnly,
    });
    return res.data;
  }

  Future<int> getUnreadCount() async {
    final res = await _dio.get('/notifications/unread-count');
    return (res.data['unread'] ?? 0) as int;
  }

  Future<void> markNotificationRead(int id) async {
    await _dio.post('/notifications/$id/read', data: {});
  }

  Future<void> markAllNotificationsRead() async {
    await _dio.post('/notifications/read-all', data: {});
  }
}