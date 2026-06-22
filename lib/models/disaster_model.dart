import 'package:flutter/material.dart';

class DisasterModel {
  final int    id;
  final String title;
  final String description;
  final String severity;
  final String status;
  final String district;
  final String hazardType;
  final String? affectedArea;
  final String? evacuationRoutes;
  final String? officialSource;
  final int    confirmationCount;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final String createdAt;

  DisasterModel({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.status,
    required this.district,
    required this.hazardType,
    this.affectedArea,
    this.evacuationRoutes,
    this.officialSource,
    required this.confirmationCount,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.createdAt,
  });

  factory DisasterModel.fromJson(Map<String, dynamic> j) => DisasterModel(
        id:               j['id'] is int ? j['id'] : int.tryParse(j['id'].toString()) ?? 0,
        title:            j['title'] ?? '',
        description:      j['description'] ?? '',
        severity:         j['severity'] ?? 'medium',
        status:           j['status'] ?? 'active',
        district:         j['district'] ?? '',
        hazardType:       j['hazard_type'] ?? 'flood',
        affectedArea:     j['affected_area'],
        evacuationRoutes: j['evacuation_routes'],
        officialSource:   j['official_source'],
        confirmationCount: (j['confirmation_count'] ?? 1) is int
                           ? (j['confirmation_count'] ?? 1)
                           : int.tryParse(j['confirmation_count'].toString()) ?? 1,
        latitude:         (j['latitude'] ?? 0).toDouble(),
        longitude:        (j['longitude'] ?? 0).toDouble(),
        distanceKm:       (j['distance_km'] ?? 0).toDouble(),
        createdAt:        j['created_at']?.toString() ?? '',
      );

  IconData get hazardIcon {
    switch (hazardType) {
      case 'flood':       return Icons.water;
      case 'tsunami':     return Icons.waves;
      case 'cyclone':     return Icons.storm;
      case 'earthquake':  return Icons.crisis_alert;
      case 'landslide':   return Icons.terrain;
      case 'fire':        return Icons.local_fire_department;
      case 'drought':     return Icons.wb_sunny;
      default:            return Icons.warning_amber;
    }
  }

  Color get severityColor {
    switch (severity) {
      case 'extreme': return const Color(0xFFEF5350);
      case 'severe':  return const Color(0xFFFF9800);
      case 'medium':  return const Color(0xFFFFEB3B);
      default:        return const Color(0xFF4FC3F7);
    }
  }

  Color get hazardColor {
    switch (hazardType) {
      case 'flood':
      case 'tsunami': return const Color(0xFF29B6F6);
      case 'fire':    return const Color(0xFFFF7043);
      case 'cyclone':
      case 'storm':   return const Color(0xFF78909C);
      default:        return const Color(0xFFFF9800);
    }
  }
}