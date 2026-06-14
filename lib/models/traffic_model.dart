import 'package:flutter/material.dart';

class TrafficModel {
  final int    id;
  final String title;
  final String description;
  final String severity;
  final String status;
  final String tvmStatus;
  final String district;
  final String hazardType;
  final String? roadSegment;
  final int    confirmationCount;
  final String? expectedClearTime;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final String createdAt;

  TrafficModel({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.status,
    required this.tvmStatus,
    required this.district,
    required this.hazardType,
    this.roadSegment,
    required this.confirmationCount,
    this.expectedClearTime,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.createdAt,
  });

  factory TrafficModel.fromJson(Map<String, dynamic> j) => TrafficModel(
        id:                 j['id'] is int ? j['id'] : int.tryParse(j['id'].toString()) ?? 0,
        title:              j['title'] ?? '',
        description:        j['description'] ?? '',
        severity:           j['severity'] ?? 'medium',
        status:             j['status'] ?? 'active',
        tvmStatus:          j['tvm_status'] ?? 'pending_consensus',
        district:           j['district'] ?? '',
        hazardType:         j['hazard_type'] ?? 'other',
        roadSegment:        j['road_segment'],
        confirmationCount:  (j['confirmation_count'] ?? 1) as int,
        expectedClearTime:  j['expected_clear_time']?.toString(),
        latitude:           (j['latitude']    ?? 0).toDouble(),
        longitude:          (j['longitude']   ?? 0).toDouble(),
        distanceKm:         (j['distance_km'] ?? 0).toDouble(),
        createdAt:          j['created_at']?.toString() ?? '',
      );

  IconData get hazardIcon {
    switch (hazardType) {
      case 'accident':     return Icons.car_crash;
      case 'road_closure': return Icons.block;
      case 'flooding':     return Icons.water;
      case 'obstruction':  return Icons.warning_amber;
      case 'construction': return Icons.construction;
      case 'pothole':      return Icons.circle_outlined;
      case 'landslide':    return Icons.terrain;
      default:             return Icons.traffic;
    }
  }

  Color get hazardColor => const Color(0xFFFF9800);

  Color get severityColor {
    switch (severity) {
      case 'extreme': return const Color(0xFFEF5350);
      case 'severe':  return const Color(0xFFFF9800);
      case 'medium':  return const Color(0xFFFFEB3B);
      default:        return const Color(0xFF4FC3F7);
    }
  }
}
