import 'package:flutter/material.dart';

class CrimeModel {
  final int    id;
  final String title;
  final String description;
  final String severity;
  final String status;
  final String tvmStatus;
  final String district;
  final String incidentType;
  final String? suspectDescription;
  final String? policeCase;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final String createdAt;

  CrimeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.status,
    required this.tvmStatus,
    required this.district,
    required this.incidentType,
    this.suspectDescription,
    this.policeCase,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.createdAt,
  });

  factory CrimeModel.fromJson(Map<String, dynamic> j) => CrimeModel(
        id:                  j['id'] is int ? j['id'] : int.tryParse(j['id'].toString()) ?? 0,
        title:               j['title'] ?? '',
        description:         j['description'] ?? '',
        severity:            j['severity'] ?? 'medium',
        status:              j['status'] ?? 'active',
        tvmStatus:           j['tvm_status'] ?? 'pending_authority_review',
        district:            j['district'] ?? '',
        incidentType:        j['incident_type'] ?? 'other',
        suspectDescription:  j['suspect_description'],
        policeCase:          j['police_case_number'],
        latitude:            (j['latitude']    ?? 0).toDouble(),
        longitude:           (j['longitude']   ?? 0).toDouble(),
        distanceKm:          (j['distance_km'] ?? 0).toDouble(),
        createdAt:           j['created_at']?.toString() ?? '',
      );

  IconData get incidentIcon {
    switch (incidentType) {
      case 'assault':            return Icons.personal_injury;
      case 'robbery':            return Icons.money_off;
      case 'theft':              return Icons.no_luggage;
      case 'vandalism':          return Icons.broken_image;
      case 'suspicious_activity': return Icons.visibility;
      case 'burglary':           return Icons.door_back_door;
      case 'fraud':              return Icons.credit_card_off;
      default:                   return Icons.local_police;
    }
  }

  Color get incidentColor => const Color(0xFFEF5350);

  Color get severityColor {
    switch (severity) {
      case 'extreme': return const Color(0xFFB71C1C);
      case 'severe':  return const Color(0xFFEF5350);
      case 'medium':  return const Color(0xFFFF7043);
      default:        return const Color(0xFFFFAB91);
    }
  }
}
