import 'package:flutter/material.dart';

/// A selectable base map (tile source). All sources are free and need no API key.
class MapBaseLayer {
  final String name;
  final IconData icon;
  final String urlTemplate;
  final List<String> subdomains;
  final int maxZoom;

  const MapBaseLayer({
    required this.name,
    required this.icon,
    required this.urlTemplate,
    this.subdomains = const [],
    this.maxZoom = 19,
  });
}

const kBaseLayers = <MapBaseLayer>[
  MapBaseLayer(
    name: 'Street',
    icon: Icons.map_outlined,
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  ),
  MapBaseLayer(
    name: 'Satellite',
    icon: Icons.satellite_alt_outlined,
    urlTemplate:
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
  ),
  MapBaseLayer(
    name: 'Terrain',
    icon: Icons.terrain_outlined,
    urlTemplate:
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}',
  ),
  MapBaseLayer(
    name: 'Dark',
    icon: Icons.dark_mode_outlined,
    urlTemplate:
        'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
    subdomains: ['a', 'b', 'c', 'd'],
  ),
];
