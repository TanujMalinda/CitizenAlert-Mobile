import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/api_service.dart';

class TrafficReportScreen extends StatefulWidget {
  const TrafficReportScreen({super.key});

  @override
  State<TrafficReportScreen> createState() => _TrafficReportScreenState();
}

class _TrafficReportScreenState extends State<TrafficReportScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _api           = ApiService();
  final _titleCtrl     = TextEditingController();
  final _descCtrl      = TextEditingController();
  final _roadCtrl      = TextEditingController();

  String  _hazardType = 'accident';
  String  _severity   = 'medium';
  String  _district   = 'Colombo';
  double? _latitude;
  double? _longitude;
  bool    _submitting = false;

  static const _hazardTypes = [
    'accident', 'road_closure', 'flooding',
    'obstruction', 'construction', 'pothole', 'landslide', 'other',
  ];
  static const _severities = ['extreme', 'severe', 'medium', 'low'];
  static const _districts = [
    'Colombo', 'Gampaha', 'Kalutara', 'Kandy', 'Matale',
    'Nuwara Eliya', 'Galle', 'Matara', 'Hambantota', 'Jaffna',
    'Kilinochchi', 'Mannar', 'Mullaitivu', 'Vavuniya', 'Puttalam',
    'Kurunegala', 'Anuradhapura', 'Polonnaruwa', 'Badulla',
    'Moneragala', 'Ratnapura', 'Kegalle', 'Trincomalee',
    'Batticaloa', 'Ampara',
  ];

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _roadCtrl.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.whileInUse ||
          perm == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition();
        if (mounted) {
          setState(() {
            _latitude  = pos.latitude;
            _longitude = pos.longitude;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) { return; }
    if (_latitude == null || _longitude == null) {
      _showSnack('Location not available — please enable GPS');
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await _api.submitTrafficHazard({
        'title':       _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'hazard_type': _hazardType,
        'severity':    _severity,
        'latitude':    _latitude,
        'longitude':   _longitude,
        'district':    _district,
        'road_segment': _roadCtrl.text.trim().isEmpty
                        ? null
                        : _roadCtrl.text.trim(),
      });

      if (!mounted) { return; }
      _showResult(result);
    } catch (e) {
      if (!mounted) { return; }
      _showSnack('Submission failed: $e');
    } finally {
      if (mounted) { setState(() => _submitting = false); }
    }
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: const Color(0xFF1C2F3F)),
      );

  void _showResult(Map<String, dynamic> result) {
    final confirmCount = result['confirmation_count'] ?? 1;
    final threshold    = result['consensus_threshold'] ?? 3;
    final isDuplicate  = result['action'] == 'confirmation_added';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C2F3F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.traffic, color: Color(0xFFFF9800)),
          const SizedBox(width: 8),
          Text(
            isDuplicate ? 'Confirmation Added' : 'Hazard Reported',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _resultRow('Confirmations',
                '$confirmCount / $threshold', const Color(0xFFFF9800)),
            const SizedBox(height: 8),
            _resultRow('TVM Status',
                result['tvm_status']?.toString().replaceAll('_', ' ') ?? '—',
                result['tvm_status'] == 'verified'
                    ? const Color(0xFF66BB6A)
                    : const Color(0xFFFF9800)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1B2A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                confirmCount >= threshold
                    ? 'Hazard auto-verified via community consensus!'
                    : '${threshold - confirmCount} more confirmation(s) needed for auto-verification.',
                style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Done',
                style: TextStyle(color: Color(0xFF4FC3F7))),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value, Color color) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(
              color: Color(0xFF90A4AE), fontSize: 13)),
          Expanded(child: Text(value, style: TextStyle(
              color: color, fontSize: 13, fontWeight: FontWeight.bold))),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        foregroundColor: Colors.white,
        title: const Row(children: [
          Icon(Icons.traffic, color: Color(0xFFFF9800), size: 20),
          SizedBox(width: 8),
          Text('Report Traffic Hazard',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFF2A3F52)),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionLabel('HAZARD DETAILS'),
            const SizedBox(height: 8),

            _field(
              controller: _titleCtrl,
              label: 'Hazard Title',
              hint: 'e.g. Road accident near Kadawatha junction',
              validator: (v) =>
                  v == null || v.trim().length < 5 ? 'Min 5 characters' : null,
            ),
            const SizedBox(height: 12),

            Row(children: [
              Expanded(
                child: _dropdown(
                  label: 'Hazard Type',
                  value: _hazardType,
                  items: _hazardTypes,
                  onChanged: (v) => setState(() => _hazardType = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dropdown(
                  label: 'Severity',
                  value: _severity,
                  items: _severities,
                  onChanged: (v) => setState(() => _severity = v!),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            _field(
              controller: _descCtrl,
              label: 'Description',
              hint: 'Describe the hazard and impact on traffic',
              maxLines: 3,
              validator: (v) =>
                  v == null || v.trim().length < 15 ? 'Min 15 characters' : null,
            ),
            const SizedBox(height: 12),

            _field(
              controller: _roadCtrl,
              label: 'Road / Segment (optional)',
              hint: 'e.g. A1 Highway, Kandy Road near Kelaniya',
            ),
            const SizedBox(height: 20),

            _sectionLabel('LOCATION'),
            const SizedBox(height: 8),

            _dropdown(
              label: 'District',
              value: _district,
              items: _districts,
              onChanged: (v) => setState(() => _district = v!),
            ),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1C2F3F),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2A3F52)),
              ),
              child: Row(children: [
                Icon(
                  _latitude != null ? Icons.location_on : Icons.location_off,
                  color: _latitude != null
                      ? const Color(0xFF4FC3F7)
                      : const Color(0xFF90A4AE),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  _latitude != null
                      ? 'GPS: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}'
                      : 'Acquiring GPS location...',
                  style: TextStyle(
                    color: _latitude != null
                        ? const Color(0xFF4FC3F7)
                        : const Color(0xFF90A4AE),
                    fontSize: 13,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // Consensus note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9800).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFFFF9800).withValues(alpha: 0.3)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.people_outline,
                      color: Color(0xFFFF9800), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Low-sensitivity: auto-verified after 3 community '
                      'confirmations (crowdsourced consensus).',
                      style: TextStyle(
                          color: Color(0xFF90A4AE), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9800),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  disabledBackgroundColor:
                      const Color(0xFFFF9800).withValues(alpha: 0.5),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Report Traffic Hazard',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            color: Color(0xFFFF9800),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2),
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: Color(0xFF90A4AE)),
          hintStyle: const TextStyle(color: Color(0xFF4A6070), fontSize: 13),
          filled: true,
          fillColor: const Color(0xFF1C2F3F),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF2A3F52)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF2A3F52)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFFF9800)),
          ),
        ),
        validator: validator,
      );

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) =>
      DropdownButtonFormField<String>(
        initialValue: value,
        style: const TextStyle(color: Colors.white),
        dropdownColor: const Color(0xFF1C2F3F),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF90A4AE)),
          filled: true,
          fillColor: const Color(0xFF1C2F3F),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF2A3F52)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF2A3F52)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFFF9800)),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        items: items
            .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(e.replaceAll('_', ' '),
                      style: const TextStyle(fontSize: 13)),
                ))
            .toList(),
        onChanged: onChanged,
      );
}
