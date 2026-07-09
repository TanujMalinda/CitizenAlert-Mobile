import 'dart:convert';
import 'package:latlong2/latlong.dart';

/// Parses the outer ring of a GeoJSON Polygon / MultiPolygon string (as
/// returned by PostGIS ST_AsGeoJSON) into map points. Returns null when the
/// alert has no drawn area.
List<LatLng>? parseGeoJsonRing(String? geojson) {
  if (geojson == null || geojson.isEmpty) return null;
  try {
    final obj = jsonDecode(geojson) as Map<String, dynamic>;
    final type = obj['type'];
    List ring;
    if (type == 'Polygon') {
      ring = (obj['coordinates'] as List).first as List;
    } else if (type == 'MultiPolygon') {
      ring = ((obj['coordinates'] as List).first as List).first as List;
    } else {
      return null;
    }
    return ring
        .map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
        .toList();
  } catch (_) {
    return null;
  }
}
