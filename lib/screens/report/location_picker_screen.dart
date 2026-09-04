import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/location_service.dart';
import '../../services/geocoding_service.dart';

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

  // ── Place search ──
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<PlaceResult> _results = [];
  bool _searching = false;
  String? _pickedLabel;   // readable name of the chosen point

  @override
  void initState() {
    super.initState();
    _picked = widget.initial;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Nominatim allows roughly one request per second, so typing is debounced
  /// instead of firing a request per keystroke.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() { _results = []; _searching = false; });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      final found = await GeocodingService.search(value);
      if (!mounted) return;
      setState(() { _results = found; _searching = false; });
    });
  }

  void _selectPlace(PlaceResult p) {
    FocusScope.of(context).unfocus();
    setState(() {
      _picked      = p.point;
      _pickedLabel = p.name;
      _results     = [];
      _searchCtrl.text = p.name;
    });
    // Town-level zoom: close enough to fine-tune by tapping the map.
    _mapController.move(p.point, 15);
  }

  /// Names the point the user tapped, so the confirmation shows a place rather
  /// than only coordinates.
  Future<void> _labelPickedPoint(LatLng point) async {
    final name = await GeocodingService.describe(point);
    if (!mounted) return;
    setState(() => _pickedLabel = name?.split(',').take(2).join(',').trim());
  }

  Future<void> _useMyLocation() async {
    final res = await LocationService.getCurrentLocation();
    if (!mounted) return;
    if (res.ok) {
      final loc = LatLng(res.latitude!, res.longitude!);
      setState(() { _picked = loc; _pickedLabel = null; });
      _mapController.move(loc, 16);
      _labelPickedPoint(loc);
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
            onTap: (_, latlng) {
              FocusScope.of(context).unfocus();
              setState(() {
                _picked = latlng;
                _pickedLabel = null;
                _results = [];
              });
              _labelPickedPoint(latlng);
            },
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

        // Search a city or place, or tap the map directly
        Positioned(
          top: 12, left: 12, right: 12,
          child: Column(children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1C2F3F).withValues(alpha: 0.97),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2A3F52)),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search a city or place — e.g. Kandy, Homagama',
                  hintStyle: const TextStyle(
                      color: Color(0xFF90A4AE), fontSize: 13),
                  prefixIcon: const Icon(Icons.search,
                      color: Color(0xFF4FC3F7), size: 20),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFF4FC3F7)),
                          ),
                        )
                      : (_searchCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close,
                                  color: Color(0xFF90A4AE), size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _results = []);
                                FocusScope.of(context).unfocus();
                              },
                            )),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
            ),

            // Search results
            if (_results.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6),
                constraints: const BoxConstraints(maxHeight: 260),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2F3F).withValues(alpha: 0.98),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF2A3F52)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _results.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: Color(0xFF2A3F52)),
                  itemBuilder: (_, i) {
                    final p = _results[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.place,
                          color: Color(0xFF4FC3F7), size: 20),
                      title: Text(p.name,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13.5)),
                      subtitle: Text(p.address,
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Color(0xFF90A4AE), fontSize: 11)),
                      onTap: () => _selectPlace(p),
                    );
                  },
                ),
              ),

            // Hint — only while nothing is being searched
            if (_results.isEmpty && !_searching)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2F3F).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: const [
                  Icon(Icons.touch_app, color: Color(0xFF4FC3F7), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        'Search above, or tap the map to drop the pin exactly',
                        style: TextStyle(
                            color: Color(0xFF90A4AE), fontSize: 11.5)),
                  ),
                ]),
              ),
          ]),
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
              child: Column(children: [
                if (_pickedLabel != null)
                  Text(
                    _pickedLabel!,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                Text(
                  '${_picked!.latitude.toStringAsFixed(5)}, '
                  '${_picked!.longitude.toStringAsFixed(5)}',
                  style:
                      const TextStyle(color: Color(0xFF90A4AE), fontSize: 12),
                ),
              ]),
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
