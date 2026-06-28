import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import 'location_picker_screen.dart';

class DisasterReportScreen extends StatefulWidget {
  const DisasterReportScreen({super.key});

  @override
  State<DisasterReportScreen> createState() => _DisasterReportScreenState();
}

class _DisasterReportScreenState extends State<DisasterReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api     = ApiService();

  final _titleCtrl        = TextEditingController();
  final _descCtrl         = TextEditingController();
  final _affectedAreaCtrl = TextEditingController();
  final _evacuationCtrl   = TextEditingController();

  String  _hazardType = 'flood';
  String  _severity   = 'severe';
  String  _district   = 'Colombo';
  double? _latitude;
  double? _longitude;
  bool    _locating   = true;
  String? _locError;
  bool    _submitting = false;

  static const _hazardTypes = [
    'flood', 'tsunami', 'cyclone', 'earthquake',
    'landslide', 'fire', 'drought', 'storm',
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

  static const _accent = Color(0xFFFFA726); // disaster orange

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _affectedAreaCtrl.dispose();
    _evacuationCtrl.dispose();
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
      final result = await _api.submitDisasterReport({
        'title':             _titleCtrl.text.trim(),
        'description':       _descCtrl.text.trim(),
        'hazard_type':       _hazardType,
        'severity':          _severity,
        'latitude':          _latitude,
        'longitude':         _longitude,
        'district':          _district,
        'affected_area':     _affectedAreaCtrl.text.trim().isEmpty
                             ? null
                             : _affectedAreaCtrl.text.trim(),
        'evacuation_routes': _evacuationCtrl.text.trim().isEmpty
                             ? null
                             : _evacuationCtrl.text.trim(),
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
          const Icon(Icons.warning_amber, color: _accent),
          const SizedBox(width: 8),
          const Text('Report Submitted',
              style: TextStyle(color: Colors.white, fontSize: 16)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _resultRow('Status', 'Pending authority verification', _accent),
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
              child: const Text(
                'Disaster reports are reviewed by authorities before being '
                'broadcast to other citizens, to prevent false alarms.',
                style: TextStyle(color: Color(0xFF90A4AE), fontSize: 12),
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
              style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 13)),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.bold)),
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
          Icon(Icons.warning_amber, color: _accent, size: 20),
          SizedBox(width: 8),
          Text('Report Disaster',
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
            _sectionLabel('DISASTER DETAILS'),
            const SizedBox(height: 8),

            _field(
              controller: _titleCtrl,
              label: 'Title',
              hint: 'e.g. Flash flooding in Kelani valley',
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
              hint: 'Describe what is happening and the danger to people',
              maxLines: 4,
              validator: (v) =>
                  v == null || v.trim().length < 20 ? 'Min 20 characters' : null,
            ),
            const SizedBox(height: 12),

            _field(
              controller: _affectedAreaCtrl,
              label: 'Affected Area (optional)',
              hint: 'e.g. Low-lying areas near the river bank',
              maxLines: 2,
            ),
            const SizedBox(height: 12),

            _field(
              controller: _evacuationCtrl,
              label: 'Evacuation Routes / Safety Info (optional)',
              hint: 'e.g. Move towards higher ground via Main Street',
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
            const SizedBox(height: 16),

            // Review notice
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shield_outlined, color: _accent, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Disaster reports are verified by authorities before being '
                      'broadcast to other citizens, to prevent false alarms.',
                      style: TextStyle(color: Color(0xFF90A4AE), fontSize: 12),
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
                  backgroundColor: _accent,
                  foregroundColor: const Color(0xFF0D1B2A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  disabledBackgroundColor: _accent.withValues(alpha: 0.5),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Color(0xFF0D1B2A), strokeWidth: 2),
                      )
                    : const Text('Submit Disaster Report',
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

  Future<void> _pickLocation() async {
    final LatLng? initial = (_latitude != null && _longitude != null)
        ? LatLng(_latitude!, _longitude!)
        : null;
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initial: initial,
          title: 'Select Affected Location',
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
      });
    }
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
      child: Column(children: [
        Row(children: [
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
                      ? 'Location: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}'
                      : (_locError ?? 'GPS unavailable — pick on map'),
              style: TextStyle(color: color, fontSize: 12.5),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _locating ? null : _getLocation,
              icon: const Icon(Icons.my_location, size: 15),
              label: const Text('Use my location',
                  style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4FC3F7),
                side: const BorderSide(color: Color(0xFF2A3F52)),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _pickLocation,
              icon: const Icon(Icons.map, size: 15),
              label: const Text('Select on map',
                  style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4FC3F7),
                side: const BorderSide(color: Color(0xFF2A3F52)),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ]),
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
            borderSide: const BorderSide(color: _accent),
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
            borderSide: const BorderSide(color: _accent),
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
