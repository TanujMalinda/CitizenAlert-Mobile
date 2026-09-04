import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

/// A place returned by a location search.
class PlaceResult {
  final String name;      // short label, e.g. "Homagama"
  final String address;   // full address line
  final LatLng point;

  const PlaceResult({
    required this.name,
    required this.address,
    required this.point,
  });
}

/// Place search backed by Nominatim, OpenStreetMap's own geocoder.
///
/// Chosen because it needs no API key and no billing account, which keeps the
/// system deployable on free, open infrastructure — the same reason the maps
/// use OpenStreetMap tiles rather than a commercial provider.
///
/// Nominatim's usage policy requires an identifying User-Agent and allows about
/// one request per second, so callers should debounce typing rather than
/// searching on every keystroke.
class GeocodingService {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://nominatim.openstreetmap.org',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'User-Agent': 'CitizenAlert/1.0 (NSBM research project)',
      'Accept': 'application/json',
    },
  ));

  /// Searches for [query] within Sri Lanka. Returns an empty list on failure —
  /// place search is a convenience, so a network problem must never block the
  /// user from picking a point by tapping the map.
  static Future<List<PlaceResult>> search(String query, {int limit = 6}) async {
    final q = query.trim();
    if (q.length < 2) return [];

    try {
      final res = await _dio.get('/search', queryParameters: {
        'q': q,
        'countrycodes': 'lk',      // Sri Lanka only
        'format': 'json',
        'limit': limit,
        'addressdetails': 1,
      });

      final data = res.data;
      if (data is! List) return [];

      return data.map<PlaceResult?>((item) {
        final lat = double.tryParse('${item['lat']}');
        final lon = double.tryParse('${item['lon']}');
        if (lat == null || lon == null) return null;

        final display = '${item['display_name'] ?? ''}';
        final name = display.split(',').first.trim();

        return PlaceResult(
          name: name.isEmpty ? display : name,
          address: display,
          point: LatLng(lat, lon),
        );
      }).whereType<PlaceResult>().toList();
    } catch (_) {
      return [];
    }
  }

  /// Turns a coordinate back into a readable place name, used to label a point
  /// the user tapped on the map.
  static Future<String?> describe(LatLng point) async {
    try {
      final res = await _dio.get('/reverse', queryParameters: {
        'lat': point.latitude,
        'lon': point.longitude,
        'format': 'json',
        'zoom': 16,
      });
      final name = res.data is Map ? res.data['display_name'] : null;
      return name is String && name.isNotEmpty ? name : null;
    } catch (_) {
      return null;
    }
  }
}
