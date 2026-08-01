import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import 'crime_report_screen.dart';
import 'disaster_report_screen.dart';
import 'traffic_report_screen.dart';

/// Snap Incident — take a photo, the trained model identifies the incident type,
/// then it hands off to the matching report form with the type pre-selected.
class SnapIncidentScreen extends StatefulWidget {
  const SnapIncidentScreen({super.key});

  @override
  State<SnapIncidentScreen> createState() => _SnapIncidentScreenState();
}

class _SnapIncidentScreenState extends State<SnapIncidentScreen> {
  final _api = ApiService();
  final ImagePicker _picker = ImagePicker();

  File?   _photo;
  String? _dataUri;
  bool    _analyzing = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Jump straight to the camera when the screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) => _capture(ImageSource.camera));
  }

  Future<void> _capture(ImageSource source) async {
    setState(() { _error = null; _result = null; });
    try {
      final picked = await _picker.pickImage(
        source: source, maxWidth: 800, maxHeight: 800, imageQuality: 60,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final uri = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      if (!mounted) return;
      setState(() { _photo = File(picked.path); _dataUri = uri; });
      await _analyze();
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open the camera');
    }
  }

  Future<void> _analyze() async {
    if (_dataUri == null) return;
    setState(() { _analyzing = true; _error = null; });
    try {
      final res = await _api.classifyIncident(_dataUri!);
      if (!mounted) return;
      setState(() { _result = res; _analyzing = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not analyze the photo. Check your connection.';
        _analyzing = false;
      });
    }
  }

  void _continueToReport() {
    final r = _result;
    if (r == null) return;
    final alertType = r['alert_type'] as String?;
    final subType   = r['sub_type'] as String?;

    Widget? screen;
    if (alertType == 'traffic') {
      screen = TrafficReportScreen(initialPhoto: _dataUri, initialType: subType);
    } else if (alertType == 'disaster') {
      screen = DisasterReportScreen(initialPhoto: _dataUri, initialType: subType);
    } else if (alertType == 'crime') {
      screen = CrimeReportScreen(initialPhoto: _dataUri, initialType: subType);
    }
    if (screen == null) return;

    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => screen!));
  }

  // Route to a chosen alert type (the low-confidence "report as … anyway"
  // path) — keeps the photo, but doesn't pre-select a sub-type we're unsure of.
  void _continueToReportAs(String? alertType) {
    Widget? screen;
    if (alertType == 'traffic') {
      screen = TrafficReportScreen(initialPhoto: _dataUri);
    } else if (alertType == 'disaster') {
      screen = DisasterReportScreen(initialPhoto: _dataUri);
    } else if (alertType == 'crime') {
      screen = CrimeReportScreen(initialPhoto: _dataUri);
    }
    if (screen == null) { _reportManually(); return; }
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => screen!));
  }

  // Manual fallback — let the user pick the form themselves, keeping the photo.
  void _reportManually() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C2F3F),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          _manualTile(ctx, Icons.traffic, 'Traffic Hazard',
              () => TrafficReportScreen(initialPhoto: _dataUri)),
          _manualTile(ctx, Icons.warning_amber, 'Disaster',
              () => DisasterReportScreen(initialPhoto: _dataUri)),
          _manualTile(ctx, Icons.local_police, 'Crime Incident',
              () => CrimeReportScreen(initialPhoto: _dataUri)),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _manualTile(BuildContext ctx, IconData icon, String label,
      Widget Function() build) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF4FC3F7)),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: () {
        Navigator.pop(ctx);
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => build()));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Snap Incident',
            style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_photo != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(_photo!, height: 240, fit: BoxFit.cover),
              )
            else
              Container(
                height: 240,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2F3F),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF2A3F52)),
                ),
                child: const Center(
                  child: Icon(Icons.photo_camera_outlined,
                      color: Color(0xFF4FC3F7), size: 48),
                ),
              ),
            const SizedBox(height: 16),

            if (_analyzing) ...[
              const Center(
                  child: CircularProgressIndicator(color: Color(0xFF4FC3F7))),
              const SizedBox(height: 12),
              const Center(
                child: Text('Analyzing photo with the incident model…',
                    style: TextStyle(color: Color(0xFF90A4AE), fontSize: 13)),
              ),
            ],

            if (_error != null)
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFEF5350))),

            if (_result != null && !_analyzing) _resultCard(_result!),

            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _capture(ImageSource.camera),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retake'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4FC3F7),
                    side: const BorderSide(color: Color(0xFF2A3F52)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _capture(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library, size: 16),
                  label: const Text('Gallery'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4FC3F7),
                    side: const BorderSide(color: Color(0xFF2A3F52)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  String _typeLabel(String? t) =>
      t == 'traffic' ? 'Traffic' : t == 'disaster' ? 'Disaster'
      : t == 'crime' ? 'Crime' : 'Incident';

  Widget _resultCard(Map<String, dynamic> r) {
    final alertType     = r['alert_type'] as String?;       // null unless confident
    final suggestedType = r['suggested_type'] as String?;   // raw guess (may be null)
    final predicted     = (r['predicted'] ?? '').toString().replaceAll('_', ' ');
    final confidence    = ((r['confidence'] ?? 0) * 100).toInt();
    final confident     = (r['confident'] ?? r['reliable']) == true;
    final isPlaceholder = r['engine'] == 'placeholder';

    // Three states:
    //  confident  → auto-route (green)
    //  uncertain  → a weak guess exists but below the floor (amber)
    //  none       → model says normal / not an incident (grey)
    final bool confidentIncident = confident && alertType != null;
    final bool uncertain = !confidentIncident && suggestedType != null;

    final Color color = confidentIncident
        ? const Color(0xFF66BB6A)
        : uncertain
            ? const Color(0xFFFF9800)
            : const Color(0xFF90A4AE);

    final String heading = confidentIncident
        ? 'Detected: ${predicted[0].toUpperCase()}${predicted.substring(1)}'
        : uncertain
            ? 'Not sure — this might be ${_typeLabel(suggestedType)}'
            : 'No incident detected';

    final String body = confidentIncident
        ? 'Model confidence: $confidence%'
        : uncertain
            ? 'Only $confidence% confident — too low to auto-select. Please '
              'choose the correct report type yourself.'
            : 'This doesn\'t look like a reportable incident. Retake the photo, '
              'or choose a report type manually.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
              confidentIncident
                  ? Icons.check_circle
                  : uncertain ? Icons.help_outline : Icons.info_outline,
              color: color, size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(heading,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(body,
              style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 12.5)),
          if (isPlaceholder) ...[
            const SizedBox(height: 6),
            const Text('(demo prediction — trained model not installed yet)',
                style: TextStyle(color: Color(0xFF4A6070), fontSize: 11)),
          ],
          if (r['fusion'] == 'clip_veto') ...[
            const SizedBox(height: 6),
            const Text('Cross-checked by a second AI model, which disagreed — '
                'suggestion updated accordingly.',
                style: TextStyle(color: Color(0xFF4A6070), fontSize: 11)),
          ],
          if (r['fusion'] == 'agree') ...[
            const SizedBox(height: 6),
            const Text('Confirmed by a second AI model ✓',
                style: TextStyle(color: Color(0xFF4A6070), fontSize: 11)),
          ],
          const SizedBox(height: 14),

          // Confident → primary green Continue button
          if (confidentIncident)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _continueToReport,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: Text('Continue to ${_typeLabel(alertType)} report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: const Color(0xFF0D1B2A),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),

          // Uncertain → manual is primary; the weak guess is a secondary option
          if (uncertain) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _reportManually,
                icon: const Icon(Icons.list_alt, size: 16),
                label: const Text('Choose report type'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4FC3F7),
                  foregroundColor: const Color(0xFF0D1B2A),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _continueToReportAs(suggestedType),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF9800),
                  side: const BorderSide(color: Color(0xFFFF9800)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                child: Text('Report as ${_typeLabel(suggestedType)} anyway',
                    style: const TextStyle(fontSize: 13)),
              ),
            ),
          ],

          // Normal / no guess → just the manual link
          if (!confidentIncident && !uncertain)
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _reportManually,
                child: const Text('Choose report type manually',
                    style: TextStyle(color: Color(0xFF4FC3F7), fontSize: 13)),
              ),
            ),
        ],
      ),
    );
  }
}
