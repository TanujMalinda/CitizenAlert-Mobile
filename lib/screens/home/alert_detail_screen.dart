import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/alert_model.dart';
import '../../services/api_service.dart';

class AlertDetailScreen extends StatefulWidget {
  final AlertModel alert;
  const AlertDetailScreen({super.key, required this.alert});

  @override
  State<AlertDetailScreen> createState() => _AlertDetailScreenState();
}

class _AlertDetailScreenState extends State<AlertDetailScreen> {
  final _api         = ApiService();
  final _descCtrl    = TextEditingController();
  bool  _submitting  = false;
  Map<String, dynamic>? _tvmResult;
  String? _error;
  int?    _myUserId;

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  Future<void> _loadMe() async {
    final id = await _api.getUserId();
    if (mounted) setState(() => _myUserId = int.tryParse(id ?? ''));
  }

  bool get _isMine =>
      _myUserId != null && widget.alert.reporterId == _myUserId;

  Future<void> _resolve() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2F3F),
        title: const Text('Mark as found / resolved?',
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
      await _api.resolveMyAlert(widget.alert.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alert resolved — thank you!'),
            backgroundColor: Color(0xFF1C2F3F)),
      );
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not resolve the alert'),
            backgroundColor: Color(0xFF1C2F3F)),
      );
    }
  }

  Future<void> _submitSighting() async {
    if (_descCtrl.text.trim().length < 10) {
      setState(() => _error = 'Description must be at least 10 characters');
      return;
    }
    setState(() { _submitting = true; _error = null; _tvmResult = null; });
    try {
      final res = await _api.submitSighting(widget.alert.id, {
        'latitude':     widget.alert.latitude,
        'longitude':    widget.alert.longitude,
        'description':  _descCtrl.text.trim(),
        'sighting_time': DateTime.now().toIso8601String(),
      });
      setState(() { _tvmResult = res; _submitting = false; });
      _descCtrl.clear();
    } catch (e) {
      setState(() {
        _error = 'Submission failed. Please try again.';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.alert;
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Alert Detail',
            style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ── Person info card ────────────────────────────────────────────
            _card(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: a.severityColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: a.severityColor),
                    ),
                    child: Icon(Icons.person_search,
                        color: a.severityColor, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.personName,
                          style: const TextStyle(color: Colors.white,
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      if (a.age != null || a.gender != null)
                        Text(
                          [if (a.age != null) '${a.age} yrs',
                           if (a.gender != null) a.gender!].join(' · '),
                          style: const TextStyle(
                              color: Color(0xFF90A4AE), fontSize: 13),
                        ),
                    ],
                  )),
                ]),
                const SizedBox(height: 14),
                _infoRow(Icons.location_on_outlined,
                    a.lastSeenLocationDesc ?? 'Unknown location'),
                const SizedBox(height: 8),
                _infoRow(Icons.straighten,
                    '${a.distanceKm} km from your location'),
                const SizedBox(height: 12),
                Wrap(spacing: 8, children: [
                  _chip(a.severity.toUpperCase(), a.severityColor),
                  _chip('TVM: ${(a.confidenceScore * 100).toInt()}%',
                      const Color(0xFF4FC3F7)),
                  _chip(a.tvmStatus.replaceAll('_', ' ').toUpperCase(),
                      const Color(0xFF66BB6A)),
                  if (a.cctv) _chip('CCTV SIGNAL', const Color(0xFF66BB6A)),
                ]),
              ],
            )),

            // ── Reporter-only: mark found / resolved ────────────────────────
            if (_isMine) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _resolve,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Mark as Found / Resolved'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF66BB6A),
                    side: const BorderSide(color: Color(0xFF66BB6A)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            const SizedBox(height: 14),

            // ── Mini map ────────────────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 180,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(a.latitude, a.longitude),
                    initialZoom: 14,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.citizenalert.mobile',
                    ),
                    MarkerLayer(markers: [
                      Marker(
                        point: LatLng(a.latitude, a.longitude),
                        width: 40, height: 40,
                        child: Icon(Icons.location_pin,
                            color: a.severityColor, size: 36),
                      ),
                    ]),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── TVM result ──────────────────────────────────────────────────
            if (_tvmResult != null) _tvmResultCard(_tvmResult!),

            // ── Submit sighting form ────────────────────────────────────────
            _card(child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Submit a Sighting',
                    style: TextStyle(color: Colors.white,
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                  'Seen this person? Your report runs through the TVM pipeline.',
                  style: TextStyle(color: Color(0xFF90A4AE), fontSize: 12),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _descCtrl,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Describe what you saw, where and when...',
                    hintStyle: const TextStyle(color: Color(0xFF90A4AE)),
                    filled: true,
                    fillColor: const Color(0xFF0D1B2A),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(0xFF4FC3F7))),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!,
                      style: const TextStyle(color: Color(0xFFEF5350),
                          fontSize: 12)),
                ],
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _submitting ? null : _submitSighting,
                  icon: _submitting
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                  label: Text(_submitting ? 'Running TVM...' : 'Submit Sighting'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4FC3F7),
                    foregroundColor: const Color(0xFF0D1B2A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            )),
          ],
        ),
      ),
    );
  }

  // ── TVM result card ─────────────────────────────────────────────────────────
  Widget _tvmResultCard(Map<String, dynamic> r) {
    final status = r['tvm_status'] ?? '';
    final score  = ((r['confidence_score'] ?? 0) * 100).toInt();
    final tier   = r['tvm_tier'] ?? 1;

    Color color;
    IconData icon;
    String label;

    switch (status) {
      case 'verified':
        color = const Color(0xFF66BB6A);
        icon  = Icons.verified;
        label = 'Verified — broadcast to authorities';
        break;
      case 'pending_authority_review':
        color = const Color(0xFFFF9800);
        icon  = Icons.hourglass_top;
        label = 'Sent to authority review (Tier 3)';
        break;
      default:
        color = const Color(0xFFEF5350);
        icon  = Icons.cancel;
        label = 'Rejected — score too low';
    }

    final components = r['score_components'] as Map<String, dynamic>? ?? {};

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text(label,
                style: TextStyle(color: color,
                    fontWeight: FontWeight.bold, fontSize: 14))),
          ]),
          const SizedBox(height: 10),
          _scoreRow('TVM Score', '$score%', color),
          _scoreRow('Tier reached', 'Tier $tier', const Color(0xFF4FC3F7)),
          if (components['reporter_trust'] != null)
            _scoreRow('Reporter trust',
                '${((components['reporter_trust'] as num) * 100).toInt()}%',
                const Color(0xFF90A4AE)),
          if (components['location_plausibility'] != null)
            _scoreRow('Location plausibility',
                '${((components['location_plausibility'] as num) * 100).toInt()}%',
                const Color(0xFF90A4AE)),
          if ((components['cctv_boost'] ?? 0) > 0)
            _scoreRow('CCTV boost', '+15%', const Color(0xFF66BB6A)),
          const SizedBox(height: 6),
          Text(r['message'] ?? '',
              style: const TextStyle(
                  color: Color(0xFF90A4AE), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _scoreRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF90A4AE), fontSize: 12)),
          Text(value,
              style: TextStyle(color: color,
                  fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C2F3F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A3F52)),
        ),
        child: child,
      );

  Widget _infoRow(IconData icon, String text) => Row(children: [
        Icon(icon, color: const Color(0xFF4FC3F7), size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(text,
            style: const TextStyle(
                color: Color(0xFF90A4AE), fontSize: 13))),
      ]);

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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