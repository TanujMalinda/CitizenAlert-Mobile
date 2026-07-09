import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'geo_utils.dart';

class HealthModel {
  final int    id;
  final String title;
  final String description;
  final String severity;
  final String status;
  final String tvmStatus;
  final String district;
  final String diseaseType;
  final int?   caseCount;
  final String? preventionProtocols;
  final String? healthFacility;
  final String? officialSource;
  final int? reporterId;
  final double? affectedRadiusKm;
  final List<LatLng>? affectedPolygon;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final String createdAt;

  HealthModel({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.status,
    required this.tvmStatus,
    required this.district,
    required this.diseaseType,
    this.caseCount,
    this.preventionProtocols,
    this.healthFacility,
    this.officialSource,
    this.reporterId,
    this.affectedRadiusKm,
    this.affectedPolygon,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.createdAt,
  });

  factory HealthModel.fromJson(Map<String, dynamic> j) => HealthModel(
        id:                   j['id'] is int ? j['id'] : int.tryParse(j['id'].toString()) ?? 0,
        title:                j['title'] ?? '',
        description:          j['description'] ?? '',
        severity:             j['severity'] ?? 'medium',
        status:               j['status'] ?? 'active',
        tvmStatus:            j['tvm_status'] ?? 'pending_authority_review',
        district:             j['district'] ?? '',
        diseaseType:          j['disease_type'] ?? 'other',
        caseCount:            j['case_count'] as int?,
        preventionProtocols:  j['prevention_protocols'],
        healthFacility:       j['health_facility'],
        officialSource:       j['official_source'],
        reporterId:           j['reporter_id'],
        affectedRadiusKm:     (j['affected_radius_km'] as num?)?.toDouble(),
        affectedPolygon:      parseGeoJsonRing(j['affected_geojson']),
        latitude:             (j['latitude']    ?? 0).toDouble(),
        longitude:            (j['longitude']   ?? 0).toDouble(),
        distanceKm:           (j['distance_km'] ?? 0).toDouble(),
        createdAt:            j['created_at']?.toString() ?? '',
      );

  IconData get diseaseIcon {
    switch (diseaseType) {
      case 'dengue':
      case 'vector_borne': return Icons.bug_report;
      case 'leptospirosis':
      case 'cholera':      return Icons.water_drop;
      case 'covid':
      case 'respiratory':  return Icons.masks;
      case 'food_poisoning': return Icons.no_food;
      default:             return Icons.local_hospital;
    }
  }

  Color get diseaseColor => const Color(0xFF66BB6A);

  Color get severityColor {
    switch (severity) {
      case 'extreme': return const Color(0xFFEF5350);
      case 'severe':  return const Color(0xFFFF9800);
      case 'medium':  return const Color(0xFFFFEB3B);
      default:        return const Color(0xFF66BB6A);
    }
  }
}
