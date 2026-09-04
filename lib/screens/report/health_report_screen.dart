import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../services/api_service.dart';
import '../../services/draft_service.dart';
import '../../services/location_service.dart';
import 'location_picker_screen.dart';

class HealthReportScreen extends StatefulWidget {
  const HealthReportScreen({super.key});

  @override
  State<HealthReportScreen> createState() => _HealthReportScreenState();
}

class _HealthReportScreenState extends State<HealthReportScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _api           = ApiService();
  final _titleCtrl     = TextEditingController();
  final _descCtrl      = TextEditingController();
  final _preventionCtrl = TextEditingController();
  final _facilityCtrl  = TextEditingController();

  String  _diseaseType = 'dengue';
  String  _severity    = 'medium';
  String  _district    = 'Colombo';
  double? _latitude;
  double? _longitude;
  bool    _locating    = true;
  String? _locError;
  bool    _submitting  = false;

  final _draft = FormDraft('health_report');

  static const _diseaseTypes = [
    'dengue', 'leptospirosis', 'cholera', 'covid',
    'food_poisoning', 'respiratory', 'vector_borne', 'other',
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
    for (final c in [_titleCtrl, _descCtrl, _preventionCtrl, _facilityCtrl]) {
      c.addListener(_saveDraft);
    }
    _restoreDraft();
    _getLocation();
  }

  @override
  void dispose() {
    _draft.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _preventionCtrl.dispose();
    _facilityCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _collectDraft() => {
        'title':        _titleCtrl.text,
        'description':  _descCtrl.text,
        'prevention':   _preventionCtrl.text,
        'facility':     _facilityCtrl.text,
        'disease_type': _diseaseType,
        'severity':     _severity,
        'district':     _district,
      };

  void _saveDraft() => _draft.scheduleSave(_collectDraft);

  Future<void> _restoreDraft() async {
    final d = await _draft.load(meaningfulFields: [
      'title', 'description', 'prevention', 'facility',
    ]);
    if (d == null || !mounted) return;
    setState(() {
      _titleCtrl.text      = d['title'] ?? '';
      _descCtrl.text       = d['description'] ?? '';
      _preventionCtrl.text = d['prevention'] ?? '';
      _facilityCtrl.text   = d['facility'] ?? '';
      if (_diseaseTypes.contains(d['disease_type'])) {
        _diseaseType = d['disease_type'];
      }
      if (_severities.contains(d['severity'])) _severity = d['severity'];
      if (_districts.contains(d['district']))  _district = d['district'];
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Unfinished report restored'),
        backgroundColor: const Color(0xFF1C2F3F),
        action: SnackBarAction(
          label: 'Discard',
          textColor: const Color(0xFF66BB6A),
          onPressed: _discardDraft,
        ),
      ),
    );
  }

  Future<void> _discardDraft() async {
    await _draft.clear();
    if (!mounted) return;
    setState(() {
      _titleCtrl.clear();
      _descCtrl.clear();
      _preventionCtrl.clear();
      _facilityCtrl.clear();
      _diseaseType = 'dengue';
      _severity    = 'medium';
      _district    = 'Colombo';
    });
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

  Future<void> _pickLocation() async {
    final LatLng? initial = (_latitude != null && _longitude != null)
        ? LatLng(_latitude!, _longitude!)
        : null;
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initial: initial,
          title: 'Select Location',
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) { return; }
    if (_latitude == null || _longitude == null) {
      _showSnack('Location not available — please enable GPS');
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await _api.submitHealthReport({
        'title':                _titleCtrl.text.trim(),
        'description':          _descCtrl.text.trim(),
        'disease_type':         _diseaseType,
        'severity':             _severity,
        'latitude':             _latitude,
        'longitude':            _longitude,
        'district':             _district,
        'prevention_protocols': _preventionCtrl.text.trim().isEmpty
                                ? null
                                : _preventionCtrl.text.trim(),
        'health_facility':      _facilityCtrl.text.trim().isEmpty
                                ? null
                                : _facilityCtrl.text.trim(),
      });

      await _draft.clear();
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C2F3F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.local_hospital, color: Color(0xFF66BB6A)),
          SizedBox(width: 8),
          Text('Health Report Submitted',
              style: TextStyle(color: Colors.white, fontSize: 16)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _resultRow('Status',
                result['tvm_status'] == 'verified'
                    ? 'Published'
                    : 'Pending medical review',
                result['tvm_status'] == 'verified'
                    ? const Color(0xFF66BB6A)
                    : const Color(0xFFFF9800)),
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
                'Critical sensitivity — citizen health reports require '
                'mandatory medical authority review before public dissemination.',
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
          Icon(Icons.local_hospital, color: Color(0xFF66BB6A), size: 20),
          SizedBox(width: 8),
          Text('Report Health Concern',
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
            _sectionLabel('HEALTH CONCERN DETAILS'),
            const SizedBox(height: 8),

            _field(
              controller: _titleCtrl,
              label: 'Report Title',
              hint: 'e.g. Dengue fever cluster near Wellawatte',
              validator: (v) =>
                  v == null || v.trim().length < 5 ? 'Min 5 characters' : null,
            ),
            const SizedBox(height: 12),

            Row(children: [
              Expanded(
                child: _dropdown(
                  label: 'Disease / Hazard Type',
                  value: _diseaseType,
                  items: _diseaseTypes,
                  onChanged: (v) {
                    setState(() => _diseaseType = v!);
                    _saveDraft();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dropdown(
                  label: 'Severity',
                  value: _severity,
                  items: _severities,
                  onChanged: (v) {
                    setState(() => _severity = v!);
                    _saveDraft();
                  },
                ),
              ),
            ]),
            const SizedBox(height: 12),

            _field(
              controller: _descCtrl,
              label: 'Description',
              hint: 'Describe the health concern, symptoms, or affected area',
              maxLines: 4,
              validator: (v) =>
                  v == null || v.trim().length < 20 ? 'Min 20 characters' : null,
            ),
            const SizedBox(height: 12),

            _field(
              controller: _preventionCtrl,
              label: 'Prevention Advice (optional)',
              hint: 'Any known prevention steps (boil water, avoid area, etc.)',
              maxLines: 2,
            ),
            const SizedBox(height: 12),

            _field(
              controller: _facilityCtrl,
              label: 'Nearest Health Facility (optional)',
              hint: 'e.g. Colombo National Hospital',
            ),
            const SizedBox(height: 20),

            _sectionLabel('AFFECTED AREA'),
            const SizedBox(height: 8),

            _dropdown(
              label: 'District',
              value: _district,
              items: _districts,
              onChanged: (v) {
                setState(() => _district = v!);
                _saveDraft();
              },
            ),
            const SizedBox(height: 8),

            _gpsStatusBox(),
            const SizedBox(height: 16),

            // TVM notice
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF66BB6A).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFF66BB6A).withValues(alpha: 0.3)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined,
                      color: Color(0xFF66BB6A), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'TVM Tier 3 applies — health reports undergo '
                      'mandatory medical authority review before public dissemination.',
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
                  backgroundColor: const Color(0xFF66BB6A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  disabledBackgroundColor:
                      const Color(0xFF66BB6A).withValues(alpha: 0.5),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Submit Health Report',
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
            color: Color(0xFF66BB6A),
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
            borderSide: const BorderSide(color: Color(0xFF66BB6A)),
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
            borderSide: const BorderSide(color: Color(0xFF66BB6A)),
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
