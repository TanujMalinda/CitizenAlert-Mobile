import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/location_service.dart';

/// Full-screen map for choosing a point. Returns the picked [LatLng] via
/// Navigator.pop, or null if cancelled.
class LocationPickerScreen extends StatefulWidget {
  final LatLng? initial;
  final String title;
  const LocationPickerScreen({
    super.key,
    this.initial,
    this.title = 'Select Location',
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  LatLng? _picked;
  // Geographic centre of Sri Lanka — fallback when no GPS/initial point.
  static const _slCenter = LatLng(7.8731, 80.7718);

  @override
  void initState() {
    super.initState();
    _picked = widget.initial;
  }

  Future<void> _useMyLocation() async {
    final res = await LocationService.getCurrentLocation();
    if (!mounted) return;
    if (res.ok) {
      final loc = LatLng(res.latitude!, res.longitude!);
      setState(() => _picked = loc);
      _mapController.move(loc, 16);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not get your location'),
            backgroundColor: Color(0xFF1C2F3F)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = _picked ?? widget.initial ?? _slCenter;
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.title,
            style: const TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: Stack(children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: widget.initial != null ? 15 : 8,
            onTap: (_, latlng) => setState(() => _picked = latlng),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.citizenalert.mobile',
            ),
            if (_picked != null)
              MarkerLayer(markers: [
                Marker(
                  point: _picked!,
                  width: 50, height: 50,
                  alignment: Alignment.topCenter,
                  child: const Icon(Icons.location_on,
                      color: Color(0xFFEF5350), size: 46),
                ),
              ]),
          ],
        ),

        // Instruction banner
        Positioned(
          top: 12, left: 12, right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1C2F3F).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF2A3F52)),
            ),
            child: Row(children: const [
              Icon(Icons.touch_app, color: Color(0xFF4FC3F7), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text('Tap the map to mark where the person was last seen',
                    style: TextStyle(color: Colors.white, fontSize: 12.5)),
              ),
            ]),
          ),
        ),

        // Use my location
        Positioned(
          bottom: 96, right: 16,
          child: FloatingActionButton.small(
            heroTag: 'myloc',
            backgroundColor: const Color(0xFF1C2F3F),
            foregroundColor: const Color(0xFF4FC3F7),
            onPressed: _useMyLocation,
            child: const Icon(Icons.my_location),
          ),
        ),
      ]),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_picked != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Selected: ${_picked!.latitude.toStringAsFixed(5)}, '
                '${_picked!.longitude.toStringAsFixed(5)}',
                style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 12),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _picked == null
                  ? null
                  : () => Navigator.pop(context, _picked),
              icon: const Icon(Icons.check),
              label: const Text('Confirm Location',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4FC3F7),
                foregroundColor: const Color(0xFF0D1B2A),
                disabledBackgroundColor: const Color(0xFF2A3F52),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
