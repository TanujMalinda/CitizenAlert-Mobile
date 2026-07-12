import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
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
import '../report/snap_incident_screen.dart';
import '../notifications/notifications_screen.dart';
import 'alert_detail_screen.dart';
import 'alert_tip_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiService();
  // 0 = Map, 1 = Alerts list, 2 = Review (authority only)
  int _navIndex = 0;

  // Alerts-list scrolling + "jump to this alert" highlight
  final ScrollController _listScroll = ScrollController();
  final Map<String, GlobalKey> _listItemKeys = {};
  String? _highlightedKey;

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

  // Current user id — used to show "resolve my alert" on alerts I reported.
  int? _myUserId;

  // Authority review queue (role-gated)
  bool _isAuthority = false;
  List<Map<String, dynamic>> _pendingReviews = [];
  bool _reviewLoading = false;
  int? _reviewBusyId; // alert id currently being verified/rejected

  // Only crime & health require authority verification.
  static const _reviewableTypes = {'crime', 'health'};

  @override
  void initState() {
    super.initState();
    _initRole();
    _initNotifications();
    _initLocation();
  }

  Future<void> _initRole() async {
    final idStr = await _api.getUserId();
    final role  = await _api.getUserRole();
    if (!mounted) return;
    setState(() => _myUserId = int.tryParse(idStr ?? ''));
    if (role == 'authority') {
      setState(() => _isAuthority = true);
      _loadPendingReviews();
    }
  }

  Future<void> _resolveMine(int alertId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2F3F),
        title: const Text('Mark as resolved?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text(
          'This will close the alert and remove it from everyone\'s feed. '
          'You can\'t undo this.',
          style: TextStyle(color: Color(0xFF90A4AE), fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF90A4AE))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF66BB6A),
              foregroundColor: const Color(0xFF0D1B2A),
            ),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.resolveMyAlert(alertId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alert resolved — thank you!'),
            backgroundColor: Color(0xFF1C2F3F)),
      );
      setState(() => _selected = null);
      await _loadAll();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not resolve the alert'),
            backgroundColor: Color(0xFF1C2F3F)),
      );
    }
  }

  // True if the given alert was reported by the logged-in user.
  bool _isMine(dynamic a) {
    if (_myUserId == null) return false;
    try {
      return a.reporterId == _myUserId;
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadPendingReviews() async {
    if (!_isAuthority) return;
    setState(() => _reviewLoading = true);
    try {
      final res = await _api.getPendingReviews();
      final raw = (res['data'] as List?) ?? [];
      final list = raw
          .whereType<Map<String, dynamic>>()
          .where((a) => _reviewableTypes.contains(a['alert_type']))
          .toList();
      if (mounted) setState(() => _pendingReviews = list);
    } catch (_) {
      if (mounted) setState(() => _pendingReviews = []);
    } finally {
      if (mounted) setState(() => _reviewLoading = false);
    }
  }

  Future<void> _reviewAction(
      Map<String, dynamic> item, String action) async {
    final id = item['id'] as int;
    setState(() => _reviewBusyId = id);
    try {
      await _api.reviewAlert(id, action);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(action == 'verify'
              ? 'Verified — now visible to citizens'
              : 'Rejected — removed from public feed'),
          backgroundColor: const Color(0xFF1C2F3F),
        ),
      );
      await _loadPendingReviews();
      await _loadAll(); // newly-verified alerts appear on the map too
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action failed — try again'),
            backgroundColor: Color(0xFF1C2F3F)),
      );
    } finally {
      if (mounted) setState(() => _reviewBusyId = null);
    }
  }

  @override
  void dispose() {
    _poller.stop();
    _listScroll.dispose();
    super.dispose();
  }

  // Unique key per alert (matches the notify scheme: m/d/c/t/h + id).
  String _alertKey(dynamic a) {
    if (a is AlertModel) return 'm${a.id}';
    if (a is DisasterModel) return 'd${a.id}';
    if (a is CrimeModel) return 'c${a.id}';
    if (a is TrafficModel) return 't${a.id}';
    if (a is HealthModel) return 'h${a.id}';
    return '';
  }

  // Jump from the map's selected-alert card to that alert in the list tab,
  // scroll it into view, and briefly highlight it. Uses the item's index so it
  // works even for items far down the list that aren't built yet (a lazy
  // ListView.builder doesn't render off-screen items, so ensureVisible alone
  // can't reach them).
  void _goToAlertInList(dynamic original) {
    final key = _alertKey(original);
    final index = _sortedMixedAlerts()
        .indexWhere((m) => _alertKey(m.original) == key);
    setState(() {
      _selected = null;
      _navIndex = 1;
      _highlightedKey = key;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_listScroll.hasClients) return;
      if (index >= 0) {
        // Estimated card height (margin + padding + content). Scrolling here
        // forces the target item to build, so the fine-correction below lands.
        const estExtent = 86.0;
        const topPad = 12.0;
        final target = (topPad + index * estExtent)
            .clamp(0.0, _listScroll.position.maxScrollExtent);
        await _listScroll.animateTo(target,
            duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
      }
      // Now the item is rendered — precisely align it near the top.
      final ctx = _listItemKeys[key]?.currentContext;
      if (ctx != null && ctx.mounted) {
        await Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 200),
            alignment: 0.15, curve: Curves.easeInOut);
      }
    });

    // Fade the highlight after a moment.
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _highlightedKey == key) {
        setState(() => _highlightedKey = null);
      }
    });
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
        // Filter chips only apply to the citizen map/list tabs.
        if (_navIndex < 2) _filterChipsRow(),
        Expanded(child: IndexedStack(
          index: _navIndex,
          children: [
            _mapTab(),
            _listTab(),
            if (_isAuthority) _reviewTab(),
          ],
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
        if (_navIndex < 2)
          IconButton(
            icon: Icon(
              _navIndex == 0 ? Icons.map : Icons.list,
              color: const Color(0xFF4FC3F7),
            ),
            onPressed: () {
              setState(() => _navIndex = _navIndex == 0 ? 1 : 0);
            },
          ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Color(0xFF4FC3F7)),
          onPressed: () {
            _loadAll();
            if (_isAuthority) _loadPendingReviews();
          },
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
          // Affected areas (CAP-style): drawn polygon when present,
          // otherwise a severity-default circle. Rendered under the markers.
          PolygonLayer(polygons: _affectedPolygons()),
          CircleLayer(circles: _affectedCircles()),
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

  // ── Affected-area overlays ───────────────────────────────────────────────────
  // Each visible alert contributes either its drawn polygon (river floods etc.)
  // or a severity-default circle. (type, color, polygon?, center, radiusKm?)
  List<(Color, List<LatLng>?, LatLng, double?)> _areaSources() {
    final out = <(Color, List<LatLng>?, LatLng, double?)>[];
    if (_showDisaster) {
      for (final a in _disasterAlerts) {
        out.add((a.severityColor, a.affectedPolygon,
                 LatLng(a.latitude, a.longitude), a.affectedRadiusKm));
      }
    }
    if (_showCrime) {
      for (final a in _crimeAlerts) {
        out.add((a.incidentColor, a.affectedPolygon,
                 LatLng(a.latitude, a.longitude), a.affectedRadiusKm));
      }
    }
    if (_showTraffic) {
      for (final a in _trafficAlerts) {
        out.add((a.hazardColor, a.affectedPolygon,
                 LatLng(a.latitude, a.longitude), a.affectedRadiusKm));
      }
    }
    if (_showHealth) {
      for (final a in _healthAlerts) {
        out.add((a.diseaseColor, a.affectedPolygon,
                 LatLng(a.latitude, a.longitude), a.affectedRadiusKm));
      }
    }
    return out;
  }

  List<Polygon> _affectedPolygons() => [
        for (final (color, poly, _, _) in _areaSources())
          if (poly != null && poly.length >= 3)
            Polygon(
              points: poly,
              isFilled: true,
              color: color.withValues(alpha: 0.15),
              borderColor: color.withValues(alpha: 0.6),
              borderStrokeWidth: 1.5,
            ),
      ];

  List<CircleMarker> _affectedCircles() => [
        for (final (color, poly, center, radiusKm) in _areaSources())
          if (poly == null && radiusKm != null && radiusKm > 0)
            CircleMarker(
              point: center,
              radius: radiusKm * 1000,
              useRadiusInMeter: true,
              color: color.withValues(alpha: 0.12),
              borderColor: color.withValues(alpha: 0.5),
              borderStrokeWidth: 1.2,
            ),
      ];

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
                // Tap the name → jump to this alert in the Alerts list.
                GestureDetector(
                  onTap: () => _goToAlertInList(a),
                  child: Row(children: [
                    Flexible(
                      child: Text(title,
                          style: const TextStyle(color: Color(0xFF4FC3F7),
                              fontWeight: FontWeight.bold, fontSize: 15,
                              decoration: TextDecoration.underline,
                              decorationColor: Color(0xFF4FC3F7))),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_outward,
                        color: Color(0xFF4FC3F7), size: 14),
                  ]),
                ),
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

  // ── Alert details bottom sheet ───────────────────────────────────────────────
  void _showAlertDetails(dynamic a) {
    final isMissing  = a is AlertModel;
    final isDisaster = a is DisasterModel;
    final isCrime    = a is CrimeModel;
    final isTraffic  = a is TrafficModel;
    final isHealth   = a is HealthModel;

    final Color color;
    final IconData icon;
    final String title;
    final String badge;
    final String description;
    String? photoUrl;
    final rows = <Widget>[];

    if (isMissing) {
      color = a.severityColor; icon = Icons.person_search;
      title = a.personName; badge = 'MISSING PERSON';
      description = a.title;
      photoUrl = a.photoUrl;
      if (a.age != null) rows.add(_detailRow(Icons.cake, 'Age', '${a.age}'));
      if (a.gender != null) rows.add(_detailRow(Icons.wc, 'Gender', a.gender!));
      if (a.lastSeenLocationDesc != null) {
        rows.add(_detailRow(Icons.place, 'Last seen', a.lastSeenLocationDesc!));
      }
      rows.add(_detailRow(Icons.verified_user, 'TVM confidence',
          '${(a.confidenceScore * 100).toInt()}%'));
      if (a.cctv) rows.add(_detailRow(Icons.videocam, 'CCTV', 'Corroborated'));
    } else if (isDisaster) {
      color = a.hazardColor; icon = a.hazardIcon;
      title = a.title; badge = a.hazardType.toUpperCase();
      description = a.description;
      photoUrl = a.photoUrl;
      if (a.affectedArea != null) {
        rows.add(_detailRow(Icons.map, 'Affected area', a.affectedArea!));
      }
      if (a.evacuationRoutes != null) {
        rows.add(_detailRow(Icons.directions, 'Evacuation', a.evacuationRoutes!));
      }
      rows.add(_detailRow(Icons.thumb_up, 'Confirmations',
          '${a.confirmationCount}'));
      if (a.officialSource != null) {
        rows.add(_detailRow(Icons.source, 'Source', a.officialSource!));
      }
    } else if (isCrime) {
      color = a.incidentColor; icon = a.incidentIcon;
      title = a.title; badge = a.incidentType.replaceAll('_', ' ').toUpperCase();
      description = a.description;
      photoUrl = a.photoUrl;
      rows.add(_detailRow(
          a.tvmStatus == 'verified' ? Icons.verified : Icons.pending,
          'Status', a.tvmStatus == 'verified' ? 'Verified' : 'Under review'));
      if (a.suspectDescription != null) {
        rows.add(_detailRow(Icons.person, 'Suspect', a.suspectDescription!));
      }
      if (a.policeCase != null) {
        rows.add(_detailRow(Icons.badge, 'Police case', a.policeCase!));
      }
    } else if (isTraffic) {
      color = a.hazardColor; icon = a.hazardIcon;
      title = a.title; badge = a.hazardType.replaceAll('_', ' ').toUpperCase();
      description = a.description;
      photoUrl = a.photoUrl;
      if (a.roadSegment != null) {
        rows.add(_detailRow(Icons.add_road, 'Road', a.roadSegment!));
      }
      rows.add(_detailRow(Icons.thumb_up, 'Confirmations',
          '${a.confirmationCount}'));
      if (a.expectedClearTime != null) {
        rows.add(_detailRow(Icons.schedule, 'Expected clear',
            a.expectedClearTime!));
      }
    } else if (isHealth) {
      color = a.diseaseColor; icon = a.diseaseIcon;
      title = a.title; badge = a.diseaseType.replaceAll('_', ' ').toUpperCase();
      description = a.description;
      if (a.caseCount != null) {
        rows.add(_detailRow(Icons.coronavirus, 'Cases', '${a.caseCount}'));
      }
      if (a.preventionProtocols != null) {
        rows.add(_detailRow(Icons.health_and_safety, 'Prevention',
            a.preventionProtocols!));
      }
      if (a.healthFacility != null) {
        rows.add(_detailRow(Icons.local_hospital, 'Facility',
            a.healthFacility!));
      }
    } else {
      return;
    }

    // Common rows (AlertModel/missing has no `district` field)
    if (!isMissing) {
      rows.add(_detailRow(Icons.location_city, 'District', a.district ?? '—'));
      if (a.affectedPolygon != null) {
        rows.add(_detailRow(Icons.radar, 'Affected area', 'Marked zone (see map)'));
      } else if (a.affectedRadiusKm != null) {
        rows.add(_detailRow(Icons.radar, 'Affected area',
            '~${(a.affectedRadiusKm as double).toStringAsFixed(1)} km radius'));
      }
    }
    rows.add(_detailRow(Icons.near_me, 'Distance',
        '${a.distanceKm.toStringAsFixed(1)} km away'));
    if (a.severity != null && (a.severity as String).isNotEmpty) {
      rows.add(_detailRow(Icons.priority_high, 'Severity',
          (a.severity as String).toUpperCase()));
    }
    if (a.createdAt != null && (a.createdAt as String).isNotEmpty) {
      rows.add(_detailRow(Icons.access_time, 'Reported',
          _fmtDate(a.createdAt as String)));
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C2F3F),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) => Column(
          children: [
            // Scrollable info section
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
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
                    Row(children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: color, width: 0.5),
                        ),
                        child: Icon(icon, color: color, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(color: Colors.white,
                              fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 6),
                          _chip(badge, color),
                        ],
                      )),
                    ]),
                    if (photoUrl != null && photoUrl.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _alertPhoto(photoUrl, color),
                      ),
                    ],
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(description,
                          style: const TextStyle(
                              color: Color(0xFFB0BEC5), fontSize: 13.5,
                              height: 1.4)),
                    ],
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFF2A3F52), height: 1),
                    const SizedBox(height: 8),
                    ...rows,
                  ],
                ),
              ),
            ),

            // Pinned action bar — always visible, no scrolling needed
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: const BoxDecoration(
                color: Color(0xFF1C2F3F),
                border: Border(
                    top: BorderSide(color: Color(0xFF2A3F52), width: 0.5)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Reporter-only: close my own alert
                  if (_isMine(a)) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _resolveMine(a.id);
                        },
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('Mark as Resolved',
                            style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF66BB6A),
                          side: const BorderSide(color: Color(0xFF66BB6A)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (isTraffic)
                    _confirmButton(count: a.confirmationCount, onPressed: () {
                      Navigator.pop(ctx);
                      _confirmTraffic(a);
                    }),
                  if (isDisaster)
                    _confirmButton(count: a.confirmationCount, onPressed: () {
                      Navigator.pop(ctx);
                      _confirmDisaster(a);
                    }),
                  if (isCrime || isHealth)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openTipSheet(a.id, a.title);
                        },
                        icon: const Icon(Icons.tips_and_updates, size: 15),
                        label: const Text('I have information',
                            style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4FC3F7),
                          side: const BorderSide(color: Color(0xFF4FC3F7)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  if (isMissing)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(context, MaterialPageRoute(
                              builder: (_) => AlertDetailScreen(alert: a)))
                              .then((_) { if (mounted) _loadAll(); });
                        },
                        icon: const Icon(Icons.visibility, size: 15),
                        label: const Text('View & Submit Sighting',
                            style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4FC3F7),
                          side: const BorderSide(color: Color(0xFF4FC3F7)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _goToMapLocation(a);
                      },
                      icon: const Icon(Icons.map, size: 16),
                      label: const Text('View on Map',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4FC3F7),
                        foregroundColor: const Color(0xFF0D1B2A),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Renders a person photo from either a base64 data URI or an http(s) URL.
  Widget _alertPhoto(String url, Color color) {
    const double height = 220;
    Widget fallback() => Container(
          height: height,
          color: const Color(0xFF0D1B2A),
          child: Icon(Icons.person, color: color.withValues(alpha: 0.4), size: 60),
        );

    if (url.startsWith('data:image')) {
      try {
        final bytes = base64Decode(url.split(',').last);
        return Image.memory(bytes,
            height: height, width: double.infinity, fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback());
      } catch (_) {
        return fallback();
      }
    }
    return Image.network(url,
        height: height, width: double.infinity, fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
        loadingBuilder: (ctx, child, progress) =>
            progress == null ? child : Container(
              height: height,
              color: const Color(0xFF0D1B2A),
              child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFF4FC3F7))),
            ));
  }

  Widget _detailRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF4FC3F7), size: 16),
            const SizedBox(width: 10),
            SizedBox(
              width: 96,
              child: Text(label,
                  style: const TextStyle(
                      color: Color(0xFF90A4AE), fontSize: 12.5)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12.5,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );

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
  // The alerts list in display order (respects filter toggles, sorted by
  // distance). Shared by the list tab and the map "jump to alert" scroll.
  List<_MixedAlert> _sortedMixedAlerts() {
    return [
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
  }

  Widget _listTab() {
    final allAlerts = _sortedMixedAlerts();

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
        controller: _listScroll,
        padding: const EdgeInsets.all(12),
        itemCount: allAlerts.length,
        itemBuilder: (_, i) => _mixedAlertCard(allAlerts[i]),
      ),
    );
  }

  Widget _mixedAlertCard(_MixedAlert a) {
    final key = _alertKey(a.original);
    final itemKey = _listItemKeys.putIfAbsent(key, () => GlobalKey());
    final highlighted = _highlightedKey == key;
    return GestureDetector(
      key: itemKey,
      // Tap the card body → show full details.
      onTap: () => _showAlertDetails(a.original),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: highlighted
              ? a.color.withValues(alpha: 0.18)
              : const Color(0xFF1C2F3F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: a.color.withValues(alpha: highlighted ? 0.9 : 0.3),
              width: highlighted ? 1.5 : 1),
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
          // Tap the arrow → jump to the alert's location on the map.
          GestureDetector(
            onTap: () => _goToMapLocation(a.original),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${a.distanceKm} km',
                      style: const TextStyle(
                          color: Color(0xFF4FC3F7),
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                  const SizedBox(height: 4),
                  const Icon(Icons.map_outlined,
                      color: Color(0xFF4FC3F7), size: 18),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  void _goToMapLocation(dynamic original) {
    setState(() {
      _selected = original;
      _navIndex = 0;
    });
  }

  String _fmtDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return DateFormat('MMM d, yyyy · h:mm a').format(dt.toLocal());
  }

  // ── Authority review tab ─────────────────────────────────────────────────────
  Widget _reviewTab() {
    if (_reviewLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF4FC3F7)));
    }
    if (_pendingReviews.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadPendingReviews,
        color: const Color(0xFF4FC3F7),
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Icon(Icons.task_alt, color: Color(0xFF66BB6A), size: 48),
            SizedBox(height: 12),
            Center(
              child: Text('No alerts pending review',
                  style: TextStyle(color: Color(0xFF90A4AE), fontSize: 15)),
            ),
            SizedBox(height: 4),
            Center(
              child: Text('Crime & health reports appear here for verification',
                  style: TextStyle(color: Color(0xFF4A6070), fontSize: 12)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPendingReviews,
      color: const Color(0xFF4FC3F7),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _pendingReviews.length,
        itemBuilder: (_, i) => _reviewCard(_pendingReviews[i]),
      ),
    );
  }

  Widget _reviewCard(Map<String, dynamic> a) {
    final type     = (a['alert_type'] ?? '').toString();
    final isCrime  = type == 'crime';
    final color    = isCrime ? const Color(0xFFEF5350) : const Color(0xFF66BB6A);
    final icon     = isCrime ? Icons.local_police : Icons.local_hospital;
    final severity = (a['severity'] ?? '').toString();
    final busy     = _reviewBusyId == a['id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2F3F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
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
                Text(a['title']?.toString() ?? '',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text('${a['district'] ?? '—'} · '
                     'by ${a['reporter_name'] ?? 'Anonymous'}',
                    style: const TextStyle(
                        color: Color(0xFF90A4AE), fontSize: 12)),
              ],
            )),
          ]),
          if ((a['description']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(a['description'].toString(),
                maxLines: 3, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 12.5)),
          ],
          if ((a['photo_url']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _alertPhoto(a['photo_url'].toString(), color),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: [
            _chip(type.toUpperCase(), color),
            if (severity.isNotEmpty)
              _chip(severity.toUpperCase(), const Color(0xFFFF9800)),
            _chip('PENDING REVIEW', const Color(0xFF90A4AE)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : () => _reviewAction(a, 'reject'),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Reject', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF5350),
                  side: const BorderSide(color: Color(0xFFEF5350)),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: busy ? null : () => _reviewAction(a, 'verify'),
                icon: busy
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check, size: 16),
                label: const Text('Verify', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF66BB6A),
                  foregroundColor: const Color(0xFF0D1B2A),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ]),
        ],
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
              icon: Icons.camera_alt,
              color: const Color(0xFF7E57C2),
              title: 'Snap Incident (AI)',
              subtitle: 'Take a photo — AI identifies the incident type',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SnapIncidentScreen()))
                    .then((_) => _loadAll());
              },
            ),
            const SizedBox(height: 10),
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
      selectedIndex: _navIndex,
      onDestinationSelected: (i) {
        setState(() => _navIndex = i);
      },
      destinations: [
        const NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map'),
        const NavigationDestination(
            icon: Icon(Icons.list_outlined),
            selectedIcon: Icon(Icons.list),
            label: 'Alerts'),
        if (_isAuthority)
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _pendingReviews.isNotEmpty,
              label: Text('${_pendingReviews.length}'),
              backgroundColor: const Color(0xFFEF5350),
              child: const Icon(Icons.fact_check_outlined),
            ),
            selectedIcon: const Icon(Icons.fact_check),
            label: 'Review',
          ),
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
