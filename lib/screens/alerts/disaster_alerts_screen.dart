import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/disaster_model.dart';
import '../../services/api_service.dart';

class DisasterAlertsScreen extends StatefulWidget {
  const DisasterAlertsScreen({super.key});
  @override
  State<DisasterAlertsScreen> createState() => _DisasterAlertsScreenState();
}

class _DisasterAlertsScreenState extends State<DisasterAlertsScreen>
    with SingleTickerProviderStateMixin {
  final _api            = ApiService();
  late TabController    _tabController;
  List<DisasterModel>   _alerts  = [];
  bool                  _loading = true;
  String?               _error;
  DisasterModel?        _selected;

  final double _lat = 6.9271;
  final double _lng = 79.8612;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _api.getNearbyDisasters(
        latitude: _lat, longitude: _lng, radiusKm: 100,
      );
      final list = (res['data'] as List)
          .map((e) => DisasterModel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() { _alerts = list; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error   = 'Could not load disaster alerts';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Disaster Alerts',
            style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF4FC3F7)),
            onPressed: _load,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4FC3F7),
          unselectedLabelColor: const Color(0xFF90A4AE),
          indicatorColor: const Color(0xFF4FC3F7),
          tabs: const [
            Tab(icon: Icon(Icons.map_outlined),  text: 'Map'),
            Tab(icon: Icon(Icons.list_outlined), text: 'List'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _mapTab(),
          _listTab(),
        ],
      ),
    );
  }

  // ── Map tab ────────────────────────────────────────────────────────────────
  Widget _mapTab() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF4FC3F7)));
    }

    return Stack(children: [
      FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(_lat, _lng),
          initialZoom: 10,
          onTap: (_, __) {
            if (mounted) setState(() => _selected = null);
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.citizenalert.mobile',
          ),
          MarkerLayer(
            markers: _alerts.map((a) => Marker(
              point: LatLng(a.latitude, a.longitude),
              width: 48, height: 48,
              child: GestureDetector(
                onTap: () {
                  if (mounted) setState(() => _selected = a);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: a.hazardColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: a.hazardColor, width: 1.5),
                  ),
                  child: Icon(a.hazardIcon, color: a.hazardColor, size: 24),
                ),
              ),
            )).toList(),
          ),
        ],
      ),

      // Selected popup
      if (_selected != null)
        Positioned(
          bottom: 16, left: 16, right: 16,
          child: _alertPopup(_selected!),
        ),

      // Empty state
      if (_alerts.isEmpty)
        const Center(
          child: Text('No active disaster alerts nearby',
              style: TextStyle(color: Color(0xFF90A4AE))),
        ),
    ]);
  }

  Widget _alertPopup(DisasterModel a) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2F3F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: a.hazardColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Icon(a.hazardIcon, color: a.hazardColor, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text(a.title,
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 14))),
            GestureDetector(
              onTap: () => setState(() => _selected = null),
              child: const Icon(Icons.close,
                  color: Color(0xFF90A4AE), size: 18),
            ),
          ]),
          const SizedBox(height: 8),
          if (a.affectedArea != null)
            _infoRow(Icons.location_on_outlined, a.affectedArea!),
          if (a.evacuationRoutes != null) ...[
            const SizedBox(height: 4),
            _infoRow(Icons.directions, a.evacuationRoutes!),
          ],
          const SizedBox(height: 8),
          Wrap(spacing: 6, children: [
            _chip(a.severity.toUpperCase(), a.severityColor),
            _chip(a.hazardType.toUpperCase(), a.hazardColor),
            _chip('${a.distanceKm} km', const Color(0xFF90A4AE)),
          ]),
        ],
      ),
    );
  }

  // ── List tab ───────────────────────────────────────────────────────────────
  Widget _listTab() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF4FC3F7)));
    }
    if (_error != null) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline,
              color: Color(0xFFEF5350), size: 48),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Color(0xFFEF5350))),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _load,
              child: const Text('Retry')),
        ],
      ));
    }
    if (_alerts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
                color: Color(0xFF66BB6A), size: 48),
            SizedBox(height: 12),
            Text('No active disaster alerts',
                style: TextStyle(color: Color(0xFF90A4AE))),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _alerts.length,
        itemBuilder: (_, i) => _alertCard(_alerts[i]),
      ),
    );
  }

  Widget _alertCard(DisasterModel a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2F3F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: a.hazardColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: a.hazardColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: a.hazardColor, width: 0.5),
              ),
              child: Icon(a.hazardIcon, color: a.hazardColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title,
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(a.district,
                    style: const TextStyle(
                        color: Color(0xFF90A4AE), fontSize: 12)),
              ],
            )),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${a.distanceKm} km',
                  style: const TextStyle(color: Color(0xFF4FC3F7),
                      fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 4),
              _chip(a.severity, a.severityColor),
            ]),
          ]),
          const SizedBox(height: 10),
          Text(a.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Color(0xFF90A4AE), fontSize: 12)),
          if (a.affectedArea != null) ...[
            const SizedBox(height: 8),
            _infoRow(Icons.location_on_outlined,
                'Affected: ${a.affectedArea!}'),
          ],
          if (a.evacuationRoutes != null) ...[
            const SizedBox(height: 4),
            _infoRow(Icons.directions,
                'Evacuate: ${a.evacuationRoutes!}'),
          ],
          const SizedBox(height: 8),
          Wrap(spacing: 6, children: [
            _chip(a.hazardType.toUpperCase(), a.hazardColor),
            if (a.officialSource != null)
              _chip('OFFICIAL SOURCE', const Color(0xFF66BB6A)),
          ]),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF4FC3F7), size: 14),
        const SizedBox(width: 6),
        Expanded(child: Text(text,
            style: const TextStyle(
                color: Color(0xFF90A4AE), fontSize: 12))),
      ],
    ),
  );

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withOpacity(0.5), width: 0.5),
    ),
    child: Text(label,
        style: TextStyle(color: color, fontSize: 10,
            fontWeight: FontWeight.bold)),
  );
}