import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';

class CrimeReportScreen extends StatefulWidget {
  const CrimeReportScreen({super.key});

  @override
  State<CrimeReportScreen> createState() => _CrimeReportScreenState();
}

class _CrimeReportScreenState extends State<CrimeReportScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _api      = ApiService();

  final _titleCtrl           = TextEditingController();
  final _descCtrl            = TextEditingController();
  final _suspectCtrl         = TextEditingController();

  String  _incidentType = 'theft';
  String  _severity     = 'medium';
  String  _district     = 'Colombo';
  double? _latitude;
  double? _longitude;
  bool    _locating     = true;
  String? _locError;
  bool    _submitting   = false;
  bool    _anonymous    = false;

  static const _incidentTypes = [
    'theft', 'assault', 'robbery', 'vandalism',
    'fraud', 'suspicious_activity', 'burglary', 'other',
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
    _suspectCtrl.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    setState(() { _locating = true; _locError = null; });
    final res = await LocationService.getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _latitude  = res.latitude;
      _longitude = res.longitude;
      _locError  = res.error;
      _locating  = false;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_latitude == null || _longitude == null) {
      _showSnack('Location not available — please enable GPS');
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await _api.submitCrimeReport({
        'title':               _titleCtrl.text.trim(),
        'description':         _descCtrl.text.trim(),
        'incident_type':       _incidentType,
        'severity':            _severity,
        'latitude':            _latitude,
        'longitude':           _longitude,
        'district':            _district,
        'incident_time':       DateTime.now().toIso8601String(),
        'suspect_description': _suspectCtrl.text.trim().isEmpty
                               ? null
                               : _suspectCtrl.text.trim(),
        'anonymous':           _anonymous,
      });

      if (!mounted) return;
      _showResult(result);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Submission failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: const Color(0xFF1C2F3F)),
      );

  void _showResult(Map<String, dynamic> result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C2F3F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.local_police, color: Color(0xFFEF5350)),
          const SizedBox(width: 8),
          const Text('Report Submitted',
              style: TextStyle(color: Colors.white, fontSize: 16)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _resultRow('Status', 'Under authority review',
                const Color(0xFFFF9800)),
            const SizedBox(height: 8),
            _resultRow('CAP ID',
                result['cap_identifier']?.toString() ?? '—',
                const Color(0xFF90A4AE)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1B2A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'High-sensitivity alert — your report will be reviewed by '
                'authorities before public dissemination.',
                style: const TextStyle(
                    color: Color(0xFF90A4AE), fontSize: 12),
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
          Text('$label: ',
              style: const TextStyle(
                  color: Color(0xFF90A4AE), fontSize: 13)),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ),
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
          Icon(Icons.local_police, color: Color(0xFFEF5350), size: 20),
          SizedBox(width: 8),
          Text('Report Crime Incident',
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
            _sectionLabel('INCIDENT DETAILS'),
            const SizedBox(height: 8),

            // Title
            _field(
              controller: _titleCtrl,
              label: 'Incident Title',
              hint: 'e.g. Theft near Pettah Bus Stand',
              validator: (v) =>
                  v == null || v.trim().length < 5 ? 'Min 5 characters' : null,
            ),
            const SizedBox(height: 12),

            // Incident type + severity row
            Row(children: [
              Expanded(
                child: _dropdown(
                  label: 'Incident Type',
                  value: _incidentType,
                  items: _incidentTypes,
                  onChanged: (v) => setState(() => _incidentType = v!),
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

            // Description
            _field(
              controller: _descCtrl,
              label: 'Description',
              hint: 'Describe what happened in detail',
              maxLines: 4,
              validator: (v) =>
                  v == null || v.trim().length < 20
                      ? 'Min 20 characters'
                      : null,
            ),
            const SizedBox(height: 12),

            // Suspect description (optional)
            _field(
              controller: _suspectCtrl,
              label: 'Suspect Description (optional)',
              hint: 'Physical description, clothing, vehicle, etc.',
              maxLines: 2,
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

            _gpsStatusBox(),
            const SizedBox(height: 20),

            _sectionLabel('PRIVACY'),
            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1C2F3F),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2A3F52)),
              ),
              child: SwitchListTile(
                title: const Text('Submit Anonymously',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: Text(
                  _anonymous
                      ? 'Your identity will not be shared with authorities'
                      : 'Your account will be linked to this report',
                  style: const TextStyle(
                      color: Color(0xFF90A4AE), fontSize: 12),
                ),
                value: _anonymous,
                activeThumbColor: const Color(0xFF4FC3F7),
                onChanged: (v) => setState(() => _anonymous = v),
              ),
            ),
            const SizedBox(height: 16),

            // TVM notice
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF5350).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFFEF5350).withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shield_outlined,
                      color: Color(0xFFEF5350), size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'TVM Tier 3 applies — crime reports undergo '
                      'mandatory authority review before public dissemination.',
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
                  backgroundColor: const Color(0xFFEF5350),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  disabledBackgroundColor:
                      const Color(0xFFEF5350).withValues(alpha: 0.5),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Submit Crime Report',
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

  Widget _gpsStatusBox() {
    final ok = _latitude != null;
    final color = ok
        ? const Color(0xFF4FC3F7)
        : _locating
            ? const Color(0xFF90A4AE)
            : const Color(0xFFEF5350);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2F3F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        if (_locating)
          const SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Color(0xFF4FC3F7)),
          )
        else
          Icon(ok ? Icons.location_on : Icons.location_off,
              color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _locating
                ? 'Acquiring GPS location...'
                : ok
                    ? 'GPS: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}'
                    : (_locError ?? 'GPS unavailable'),
            style: TextStyle(color: color, fontSize: 12.5),
          ),
        ),
        if (!_locating && !ok)
          TextButton(
            onPressed: _getLocation,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Retry',
                style: TextStyle(color: Color(0xFF4FC3F7), fontSize: 12)),
          ),
      ]),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            color: Color(0xFF4FC3F7),
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
            borderSide: const BorderSide(color: Color(0xFFEF5350)),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFEF5350)),
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
            borderSide: const BorderSide(color: Color(0xFFEF5350)),
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
