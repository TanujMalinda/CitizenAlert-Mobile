import 'package:flutter/material.dart';

class AlertModel {
  final int id;
  final String personName;
  final int? age;
  final String? gender;
  final String title;
  final String severity;
  final String tvmStatus;
  final double confidenceScore;
  final double distanceKm;
  final double latitude;
  final double longitude;
  final String? lastSeenLocationDesc;
  final String? photoUrl;
  final bool cctv;
  final String createdAt;

  AlertModel({
    required this.id,
    required this.personName,
    this.age,
    this.gender,
    required this.title,
    required this.severity,
    required this.tvmStatus,
    required this.confidenceScore,
    required this.distanceKm,
    required this.latitude,
    required this.longitude,
    this.lastSeenLocationDesc,
    this.photoUrl,
    required this.cctv,
    required this.createdAt,
  });

  factory AlertModel.fromJson(Map<String, dynamic> j) => AlertModel(
        id:                   j['id'] is int ? j['id'] : int.tryParse(j['id'].toString()) ?? 0,
        personName:           j['person_name'] ?? 'Unknown',
        age:                  j['age'],
        gender:               j['gender'],
        title:                j['title'] ?? '',
        severity:             j['severity'] ?? 'medium',
        tvmStatus:            j['tvm_status'] ?? 'pending',
        confidenceScore:      (j['confidence_score'] ?? 0).toDouble(),
        distanceKm:           (j['distance_km'] ?? 0).toDouble(),
        latitude:             (j['latitude'] ?? 0).toDouble(),
        longitude:            (j['longitude'] ?? 0).toDouble(),
        lastSeenLocationDesc: j['last_seen_location_desc'],
        photoUrl:             j['photo_url'],
        cctv:                 j['cctv_corroborated'] ?? false,
        createdAt:            j['created_at'] ?? '',
      );

  Color get severityColor {
    switch (severity) {
      case 'extreme': return const Color(0xFFEF5350);
      case 'severe':  return const Color(0xFFFF9800);
      case 'medium':  return const Color(0xFFFFEB3B);
      default:        return const Color(0xFF4FC3F7);
    }
  }
}