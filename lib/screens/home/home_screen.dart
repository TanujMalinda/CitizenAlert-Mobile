import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/location_service.dart';
import '../../models/alert_model.dart';
import '../../models/disaster_model.dart';
import '../../models/crime_model.dart';
import '../../models/traffic_model.dart';
import '../../models/health_model.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../services/notification_poller.dart';
import '../auth/login_screen.dart';
import '../report/report_screen.dart';
import '../report/crime_report_screen.dart';
import '../report/traffic_report_screen.dart';
import '../report/health_report_screen.dart';
import '../report/disaster_report_screen.dart';
import '../notifications/notifications_screen.dart';
import 'alert_detail_screen.dart';
import 'alert_tip_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _api         = ApiService();
  late TabController _tabController;

  // Data
  List<AlertModel>   _missingAlerts  = [];
  List<DisasterModel> _disasterAlerts = [];
  List<CrimeModel>   _crimeAlerts    = [];
  List<TrafficModel> _trafficAlerts  = [];
  List<HealthModel>  _healthAlerts   = [];

  bool    _loading = true;
  String? _error;

  // Filters
  bool _showMissing  = true;
  bool _showDisaster = true;
  bool _showCrime    = true;
  bool _showTraffic  = true;
  bool _showHealth   = true;

  // Location
  LatLng _userLocation = const LatLng(6.9271, 79.8612);

  // Selected marker
  dynamic _selected;

  // Notifications
  late final NotificationPoller _poller;
  int _unread = 0;
  final Set<String> _knownAlertKeys = {};
  bool _firstAlertLoad = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initNotifications();
    _initLocation();
  }

  @override
  void dispose() {
    _poller.stop();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initNotifications() async {
    await NotificationService.instance.init();
    NotificationService.instance.onTap = (_) => _openNotifications();
    _poller = NotificationPoller(_api);
    _poller.onChanged = _refreshUnread;
    await _poller.start();
    _refreshUnread();
  }

  Future<void> _refreshUnread() async {
    try {
      final n = await _api.getUnreadCount();
      if (mounted) setState(() => _unread = n);
    } catch (_) {/* offline — ignore */}
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    ).then((_) => _refreshUnread());
  }

  // Fire a local notification for newly-appeared nearby alerts (not on first
  // load, to avoid notifying for everything already there).
  void _notifyNewNearby() {
    final current = <String, String>{}; // key -> "Title"
    for (final a in _missingAlerts) { current['m${a.id}'] = a.personName; }
    for (final a in _disasterAlerts) { current['d${a.id}'] = a.title; }
    for (final a in _crimeAlerts)    { current['c${a.id}'] = a.title; }
    for (final a in _trafficAlerts)  { current['t${a.id}'] = a.title; }
    for (final a in _healthAlerts)   { current['h${a.id}'] = a.title; }

    if (_firstAlertLoad) {
      _knownAlertKeys.addAll(current.keys);
      _firstAlertLoad = false;
      return;
    }

    for (final entry in current.entries) {
      if (!_knownAlertKeys.contains(entry.key)) {
        _knownAlertKeys.add(entry.key);
        NotificationService.instance.show(
          id: entry.key.hashCode & 0x7fffffff,
          title: 'New alert near you',
          body: entry.value,
        );
      }
    }
  }

  Future<void> _initLocation() async {
    final res = await LocationService.getCurrentLocation();
    if (mounted && res.ok) {
      setState(() =>
          _userLocation = LatLng(res.latitude!, res.longitude!));
    }
    await _loadAll();
  }

  List<T> _parseList<T>(
    Map<String, dynamic> res,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = res['data'] ?? res['results'] ?? res['items'] ?? [];
    if (raw is! List) return [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(fromJson)
        .toList();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });

    final lat = _userLocation.latitude;
    final lng = _userLocation.longitude;

    final results = await Future.wait([
      _api.getNearbyAlerts(latitude: lat, longitude: lng, radiusKm: 15)
          .catchError((_) => <String, dynamic>{}),
      _api.getNearbyDisasters(latitude: lat, longitude: lng, radiusKm: 50)
          .catchError((_) => <String, dynamic>{}),
      _api.getNearbyCrimes(latitude: lat, longitude: lng, radiusKm: 5)
          .catchError((_) => <String, dynamic>{}),
      _api.getNearbyTraffic(latitude: lat, longitude: lng, radiusKm: 10)
          .catchError((_) => <String, dynamic>{}),
      _api.getNearbyHealth(latitude: lat, longitude: lng, radiusKm: 100)
          .catchError((_) => <String, dynamic>{}),
    ]);

    if (!mounted) return;
    setState(() {
      _missingAlerts  = _parseList(results[0], AlertModel.fromJson);
      _disasterAlerts = _parseList(results[1], DisasterModel.fromJson);
      _crimeAlerts    = _parseList(results[2], CrimeModel.fromJson);
      _trafficAlerts  = _parseList(results[3], TrafficModel.fromJson);
      _healthAlerts   = _parseList(results[4], HealthModel.fromJson);
      _loading = false;
    });

    _notifyNewNearby();
  }

  Future<void> _logout() async {
    await _api.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  int get _totalCount =>
      _missingAlerts.length + _disasterAlerts.length +
      _crimeAlerts.length + _trafficAlerts.length + _healthAlerts.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Column(children: [
        _topBar(),
        _filterChipsRow(),
        Expanded(child: TabBarView(
          controller: _tabController,
          physics: const NeverScrollableScrollPhysics(),
          children: [_mapTab(), _listTab()],
        )),
      ]),
      bottomNavigationBar: _bottomNav(),
      floatingActionButton: _reportFab(),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────
  Widget _topBar() {
    return Container(
      color: const Color(0xFF0D1B2A),
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 8),
      child: Row(children: [
        const Icon(Icons.shield_outlined,
            color: Color(0xFF4FC3F7), size: 24),
        const SizedBox(width: 8),
        const Text('CitizenAlert',
            style: TextStyle(color: Colors.white,
                fontSize: 18, fontWeight: FontWeight.bold)),
        const Spacer(),
        IconButton(
          icon: Icon(
            _tabController.index == 0 ? Icons.map : Icons.list,
            color: const Color(0xFF4FC3F7),
          ),
          onPressed: () {
            setState(() {
              _tabController.index = _tabController.index == 0 ? 1 : 0;
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Color(0xFF4FC3F7)),
          onPressed: _loadAll,
        ),
        _notificationBell(),
        IconButton(
          icon: const Icon(Icons.logout, color: Color(0xFF90A4AE)),
          onPressed: _logout,
        ),
      ]),
    );
  }

  Widget _notificationBell() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined,
              color: Color(0xFF4FC3F7)),
          onPressed: _openNotifications,
        ),
        if (_unread > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFEF5350),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF0D1B2A), width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 16),
              child: Text(
                _unread > 99 ? '99+' : '$_unread',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  // ── Filter chips — two rows for 5 types ───────────────────────────────────
  Widget _filterChipsRow() {
    return Container(
      color: const Color(0xFF0D1B2A),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Column(
        children: [
          // Row 1: Missing, Disaster, Crime
          Row(children: [
            _filterChip(
              'Missing (${_missingAlerts.length})',
              _showMissing, const Color(0xFF4FC3F7), Icons.person_search,
              () => setState(() => _showMissing = !_showMissing),
            ),
            const SizedBox(width: 6),
            _filterChip(
              'Disaster (${_disasterAlerts.length})',
              _showDisaster, const Color(0xFFFF9800), Icons.warning_amber,
              () => setState(() => _showDisaster = !_showDisaster),
            ),
            const SizedBox(width: 6),
            _filterChip(
              'Crime (${_crimeAlerts.length})',
              _showCrime, const Color(0xFFEF5350), Icons.local_police,
              () => setState(() => _showCrime = !_showCrime),
            ),
          ]),
          const SizedBox(height: 6),
          // Row 2: Traffic, Health
          Row(children: [
            _filterChip(
              'Traffic (${_trafficAlerts.length})',
              _showTraffic, const Color(0xFFFF9800), Icons.traffic,
              () => setState(() => _showTraffic = !_showTraffic),
            ),
            const SizedBox(width: 6),
            _filterChip(
              'Health (${_healthAlerts.length})',
              _showHealth, const Color(0xFF66BB6A), Icons.local_hospital,
              () => setState(() => _showHealth = !_showHealth),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool active, Color color,
      IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : const Color(0xFF1C2F3F),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? color : const Color(0xFF2A3F52),
            width: active ? 1.5 : 0.5,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: active ? color : const Color(0xFF90A4AE), size: 13),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                color: active ? color : const Color(0xFF90A4AE),
                fontSize: 11,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              )),
        ]),
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
          initialCenter: _userLocation,
          initialZoom: 12,
          onTap: (_, _) {
            if (mounted) { setState(() => _selected = null); }
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.citizenalert.mobile',
          ),
          MarkerLayer(markers: [
            // User location
            Marker(
              point: _userLocation,
              width: 40, height: 40,
              child: const Icon(Icons.my_location,
                  color: Color(0xFF4FC3F7), size: 32),
            ),

            // Missing persons
            if (_showMissing)
              ..._missingAlerts.map((a) => _buildMarker(
                point:  LatLng(a.latitude, a.longitude),
                color:  a.severityColor,
                icon:   Icons.person_search,
                onTap:  () => setState(() => _selected = a),
              )),

            // Disasters
            if (_showDisaster)
              ..._disasterAlerts.map((a) => _buildMarker(
                point:  LatLng(a.latitude, a.longitude),
                color:  a.hazardColor,
                icon:   a.hazardIcon,
                onTap:  () => setState(() => _selected = a),
              )),

            // Crime reports
            if (_showCrime)
              ..._crimeAlerts.map((a) => _buildMarker(
                point:  LatLng(a.latitude, a.longitude),
                color:  a.incidentColor,
                icon:   a.incidentIcon,
                onTap:  () => setState(() => _selected = a),
              )),

            // Traffic hazards
            if (_showTraffic)
              ..._trafficAlerts.map((a) => _buildMarker(
                point:  LatLng(a.latitude, a.longitude),
                color:  a.hazardColor,
                icon:   a.hazardIcon,
                onTap:  () => setState(() => _selected = a),
              )),

            // Health warnings
            if (_showHealth)
              ..._healthAlerts.map((a) => _buildMarker(
                point:  LatLng(a.latitude, a.longitude),
                color:  a.diseaseColor,
                icon:   a.diseaseIcon,
                onTap:  () => setState(() => _selected = a),
              )),
          ]),
        ],
      ),

      // Selected alert card
      if (_selected != null)
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: _selectedCard(_selected!),
        ),

      // Total count badge
      Positioned(
        top: 12, right: 12,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1C2F3F),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF2A3F52), width: 0.5),
          ),
          child: Text(
            _loading ? 'Loading...' : '$_totalCount alerts nearby',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ),
    ]);
  }

  Marker _buildMarker({
    required LatLng point,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) =>
      Marker(
        point: point,
        width: 44, height: 44,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.5),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
        ),
      );

  // ── Selected marker card ───────────────────────────────────────────────────
  Widget _selectedCard(dynamic a) {
    final isMissing  = a is AlertModel;
    final isDisaster = a is DisasterModel;
    final isCrime    = a is CrimeModel;
    final isTraffic  = a is TrafficModel;
    final isHealth   = a is HealthModel;

    final Color color;
    final IconData icon;
    final String title;
    final String subtitle;
    final String badge;

    if (isMissing) {
      color    = a.severityColor;
      icon     = Icons.person_search;
      title    = a.personName;
      subtitle = a.lastSeenLocationDesc ?? '';
      badge    = 'MISSING PERSON';
    } else if (isDisaster) {
      color    = a.hazardColor;
      icon     = a.hazardIcon;
      title    = a.title;
      subtitle = a.affectedArea ?? a.district;
      badge    = a.hazardType.toUpperCase();
    } else if (isCrime) {
      color    = a.incidentColor;
      icon     = a.incidentIcon;
      title    = a.title;
      subtitle = a.district;
      badge    = a.incidentType.replaceAll('_', ' ').toUpperCase();
    } else if (isTraffic) {
      color    = a.hazardColor;
      icon     = a.hazardIcon;
      title    = a.title;
      subtitle = a.roadSegment ?? a.district;
      badge    = a.hazardType.replaceAll('_', ' ').toUpperCase();
    } else {
      // Health
      color    = a.diseaseColor;
      icon     = a.diseaseIcon;
      title    = a.title;
      subtitle = a.district;
      badge    = a.diseaseType.replaceAll('_', ' ').toUpperCase();
    }

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2F3F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12, offset: const Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 0.5),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 15)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: const TextStyle(
                      color: Color(0xFF90A4AE), fontSize: 12)),
              ],
            )),
            GestureDetector(
              onTap: () => setState(() => _selected = null),
              child: const Icon(Icons.close, color: Color(0xFF90A4AE), size: 20),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 4, children: [
            _chip(badge, color),
            if (isMissing)
              _chip('TVM: ${(a.confidenceScore * 100).toInt()}%',
                  const Color(0xFF4FC3F7)),
            if (isMissing)
              _chip('${a.distanceKm} km', const Color(0xFF90A4AE)),
            if (isDisaster) ...[
              _chip(a.severity.toUpperCase(), a.severityColor),
              _chip('${a.confirmationCount} confirms',
                  const Color(0xFF4FC3F7)),
              _chip('${a.distanceKm} km', const Color(0xFF90A4AE)),
            ],
            if (isCrime)
              _chip(a.tvmStatus == 'verified' ? 'VERIFIED' : 'UNDER REVIEW',
                  a.tvmStatus == 'verified'
                      ? const Color(0xFF66BB6A)
                      : const Color(0xFFFF9800)),
            if (isTraffic)
              _chip('${a.confirmationCount} confirms',
                  const Color(0xFF4FC3F7)),
            if (isHealth && a.caseCount != null)
              _chip('${a.caseCount} cases', const Color(0xFFFF9800)),
          ]),

          // Evacuation routes for disasters
          if (isDisaster && a.evacuationRoutes != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.directions, color: Color(0xFF4FC3F7), size: 14),
              const SizedBox(width: 6),
              Expanded(child: Text(a.evacuationRoutes!,
                  style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 12),
                  maxLines: 2, overflow: TextOverflow.ellipsis)),
            ]),
          ],

          // Prevention protocols for health
          if (isHealth && a.preventionProtocols != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.health_and_safety,
                  color: Color(0xFF66BB6A), size: 14),
              const SizedBox(width: 6),
              Expanded(child: Text(a.preventionProtocols!,
                  style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 12),
                  maxLines: 2, overflow: TextOverflow.ellipsis)),
            ]),
          ],

          // Confirm Hazard button — traffic & disaster
          if (isTraffic) ...[
            const SizedBox(height: 10),
            _confirmButton(
              count: a.confirmationCount,
              onPressed: () => _confirmTraffic(a),
            ),
          ],
          if (isDisaster) ...[
            const SizedBox(height: 10),
            _confirmButton(
              count: a.confirmationCount,
              onPressed: () => _confirmDisaster(a),
            ),
          ],

          // Send Information / tip button — crime & health only
          if (isCrime || isHealth) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openTipSheet(a.id, a.title),
                icon: const Icon(Icons.tips_and_updates, size: 15),
                label: const Text('I have information',
                    style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4FC3F7),
                  side: const BorderSide(color: Color(0xFF4FC3F7)),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],

          // View sighting button for missing
          if (isMissing) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) =>
                        AlertDetailScreen(alert: a))),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4FC3F7),
                  foregroundColor: const Color(0xFF0D1B2A),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('View & Submit Sighting',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openTipSheet(int alertId, String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C2F3F),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => AlertTipSheet(alertId: alertId, alertTitle: title),
    );
  }

  // Shared confirm-hazard button (traffic & disaster) — shows current count.
  Widget _confirmButton({
    required int count,
    required VoidCallback onPressed,
  }) =>
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.thumb_up_outlined, size: 14),
          label: Text('Confirm Hazard · $count confirmed',
              style: const TextStyle(fontSize: 13)),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFFF9800),
            side: const BorderSide(color: Color(0xFFFF9800)),
            padding: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );

  Future<void> _confirmTraffic(TrafficModel a) async {
    try {
      final res = await _api.confirmTrafficHazard(a.id);
      await _afterConfirm(res, a.id, isDisaster: false);
    } catch (_) {
      _confirmFailed();
    }
  }

  Future<void> _confirmDisaster(DisasterModel a) async {
    try {
      final res = await _api.confirmDisaster(a.id);
      await _afterConfirm(res, a.id, isDisaster: true);
    } catch (_) {
      _confirmFailed();
    }
  }

  Future<void> _afterConfirm(
      Map<String, dynamic> res, int alertId,
      {required bool isDisaster}) async {
    if (!mounted) return;
    final already = res['already_confirmed'] == true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(already
            ? 'You have already confirmed this — counted once only.'
            : 'Confirmation recorded — thank you!'),
        backgroundColor: const Color(0xFF1C2F3F),
      ),
    );

    // Refresh data but KEEP the card open, re-pointing the selection to the
    // refreshed alert so the confirmation count updates live.
    await _loadAll();
    if (!mounted) return;
    setState(() {
      if (isDisaster) {
        for (final d in _disasterAlerts) {
          if (d.id == alertId) { _selected = d; return; }
        }
      } else {
        for (final t in _trafficAlerts) {
          if (t.id == alertId) { _selected = t; return; }
        }
      }
    });
  }

  void _confirmFailed() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not confirm hazard'),
          backgroundColor: Color(0xFF1C2F3F)),
    );
  }

  // ── List tab ───────────────────────────────────────────────────────────────
  Widget _listTab() {
    final allAlerts = [
      if (_showMissing)
        ..._missingAlerts.map((a) => _MixedAlert(
              type: 'missing', color: a.severityColor,
              icon: Icons.person_search,
              title: a.personName,
              subtitle: a.lastSeenLocationDesc ?? '',
              badge: a.severity,
              distanceKm: a.distanceKm,
              original: a,
            )),
      if (_showDisaster)
        ..._disasterAlerts.map((a) => _MixedAlert(
              type: 'disaster', color: a.hazardColor,
              icon: a.hazardIcon,
              title: a.title,
              subtitle: a.affectedArea ?? a.district,
              badge: a.hazardType,
              distanceKm: a.distanceKm,
              original: a,
            )),
      if (_showCrime)
        ..._crimeAlerts.map((a) => _MixedAlert(
              type: 'crime', color: a.incidentColor,
              icon: a.incidentIcon,
              title: a.title,
              subtitle: a.district,
              badge: a.incidentType,
              distanceKm: a.distanceKm,
              original: a,
            )),
      if (_showTraffic)
        ..._trafficAlerts.map((a) => _MixedAlert(
              type: 'traffic', color: a.hazardColor,
              icon: a.hazardIcon,
              title: a.title,
              subtitle: a.roadSegment ?? a.district,
              badge: a.hazardType,
              distanceKm: a.distanceKm,
              original: a,
            )),
      if (_showHealth)
        ..._healthAlerts.map((a) => _MixedAlert(
              type: 'health', color: a.diseaseColor,
              icon: a.diseaseIcon,
              title: a.title,
              subtitle: a.district,
              badge: a.diseaseType,
              distanceKm: a.distanceKm,
              original: a,
            )),
    ]..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF4FC3F7)));
    }

    if (allAlerts.isEmpty) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.location_off, color: Color(0xFF2A3F52), size: 48),
            const SizedBox(height: 12),
            const Text('No alerts nearby',
                style: TextStyle(color: Color(0xFF90A4AE), fontSize: 15)),
            const SizedBox(height: 6),
            if (_error != null)
              Text(_error!,
                  style: const TextStyle(
                      color: Color(0xFF4A6070), fontSize: 12)),
          ]));
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      color: const Color(0xFF4FC3F7),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: allAlerts.length,
        itemBuilder: (_, i) => _mixedAlertCard(allAlerts[i]),
      ),
    );
  }

  Widget _mixedAlertCard(_MixedAlert a) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selected = a.original;
          _tabController.index = 0;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C2F3F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: a.color.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: a.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: a.color, width: 0.5),
            ),
            child: Icon(a.icon, color: a.color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.title,
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 3),
              Text(a.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Color(0xFF90A4AE), fontSize: 12)),
              const SizedBox(height: 6),
              _chip(a.badge.replaceAll('_', ' ').toUpperCase(), a.color),
            ],
          )),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${a.distanceKm} km',
                  style: const TextStyle(
                      color: Color(0xFF4FC3F7),
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
              const SizedBox(height: 4),
              const Icon(Icons.chevron_right,
                  color: Color(0xFF90A4AE), size: 18),
            ],
          ),
        ]),
      ),
    );
  }

  // ── Report FAB with options ────────────────────────────────────────────────
  Widget _reportFab() {
    return FloatingActionButton.extended(
      onPressed: () => _showReportOptions(),
      backgroundColor: const Color(0xFF4FC3F7),
      foregroundColor: const Color(0xFF0D1B2A),
      icon: const Icon(Icons.add_alert),
      label: const Text('Report', style: TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  void _showReportOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C2F3F),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A3F52),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Report Incident',
                style: TextStyle(color: Colors.white,
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _reportOption(
              icon: Icons.person_search,
              color: const Color(0xFF4FC3F7),
              title: 'Missing Person',
              subtitle: 'Report someone who is missing',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ReportScreen()))
                    .then((_) => _loadAll());
              },
            ),
            const SizedBox(height: 10),
            _reportOption(
              icon: Icons.local_police,
              color: const Color(0xFFEF5350),
              title: 'Crime Incident',
              subtitle: 'Report theft, assault, or suspicious activity',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const CrimeReportScreen()))
                    .then((_) => _loadAll());
              },
            ),
            const SizedBox(height: 10),
            _reportOption(
              icon: Icons.traffic,
              color: const Color(0xFFFF9800),
              title: 'Traffic Hazard',
              subtitle: 'Report accident, road closure, or obstruction',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const TrafficReportScreen()))
                    .then((_) => _loadAll());
              },
            ),
            const SizedBox(height: 10),
            _reportOption(
              icon: Icons.warning_amber,
              color: const Color(0xFFFFA726),
              title: 'Disaster',
              subtitle: 'Report flood, landslide, fire, or other hazard',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const DisasterReportScreen()))
                    .then((_) => _loadAll());
              },
            ),
            const SizedBox(height: 10),
            _reportOption(
              icon: Icons.local_hospital,
              color: const Color(0xFF66BB6A),
              title: 'Public Health Concern',
              subtitle: 'Flag suspected outbreak or health hazard',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const HealthReportScreen()))
                    .then((_) => _loadAll());
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1B2A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
                Text(subtitle, style: const TextStyle(
                    color: Color(0xFF90A4AE), fontSize: 12)),
              ],
            )),
            Icon(Icons.chevron_right, color: color, size: 20),
          ]),
        ),
      );

  // ── Bottom nav ─────────────────────────────────────────────────────────────
  Widget _bottomNav() {
    return NavigationBar(
      backgroundColor: const Color(0xFF1C2F3F),
      selectedIndex: _tabController.index,
      onDestinationSelected: (i) {
        setState(() => _tabController.index = i);
      },
      destinations: const [
        NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map'),
        NavigationDestination(
            icon: Icon(Icons.list_outlined),
            selectedIcon: Icon(Icons.list),
            label: 'Alerts'),
      ],
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      );
}

// ── Helper class for unified list ─────────────────────────────────────────────
class _MixedAlert {
  final String   type;
  final Color    color;
  final IconData icon;
  final String   title;
  final String   subtitle;
  final String   badge;
  final double   distanceKm;
  final dynamic  original;

  _MixedAlert({
    required this.type,
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.distanceKm,
    required this.original,
  });
}
