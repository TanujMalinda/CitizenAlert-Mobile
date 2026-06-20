import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _api          = ApiService();
  final _nameCtrl     = TextEditingController();
  final _descCtrl     = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();

  int?    _age;
  String  _gender     = 'male';
  double? _lat;
  double? _lng;
  bool    _locating   = true;
  String? _locError;
  bool    _submitting = false;
  String? _error;
  bool    _success    = false;

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    setState(() { _locating = true; _locError = null; });
    final res = await LocationService.getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _lat      = res.latitude;
      _lng      = res.longitude;
      _locError = res.error;
      _locating = false;
    });
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Person name is required');
      return;
    }
    if (_descCtrl.text.trim().length < 10) {
      setState(() => _error = 'Description must be at least 10 characters');
      return;
    }
    if (_lat == null || _lng == null) {
      setState(() => _error = 'Location not available — please enable GPS');
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      await _api.createMissingPersonAlert({
        'person_name':            _nameCtrl.text.trim(),
        'description':            _descCtrl.text.trim(),
        'last_seen_location_desc': _locationCtrl.text.trim(),
        'last_seen_lat':          _lat,
        'last_seen_lng':          _lng,
        'age':                    _age,
        'gender':                 _gender,
        'district':               _districtCtrl.text.trim(),
      });
      setState(() { _success = true; _submitting = false; });
    } catch (e) {
      setState(() {
        _error = 'Submission failed. Check your connection.';
        _submitting = false;
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
        title: const Text('Report Missing Person',
            style: TextStyle(color: Colors.white)),
      ),
      body: _success ? _successView() : _form(),
    );
  }

  Widget _successView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.check_circle, color: Color(0xFF66BB6A), size: 72),
        const SizedBox(height: 16),
        const Text('Alert Created',
            style: TextStyle(color: Colors.white,
                fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          'Your missing person alert has been submitted and is now live.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF90A4AE)),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4FC3F7),
            foregroundColor: const Color(0xFF0D1B2A),
            padding: const EdgeInsets.symmetric(
                horizontal: 32, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Back to Map',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ]),
    ),
  );

  Widget _form() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel('Person details'),
        _field('Full name *', _nameCtrl, Icons.person_outline),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _numberField('Age', (v) =>
              setState(() => _age = int.tryParse(v)))),
          const SizedBox(width: 12),
          Expanded(child: _genderDropdown()),
        ]),
        const SizedBox(height: 20),

        _sectionLabel('Last seen'),
        _field('Location description *', _locationCtrl,
            Icons.location_on_outlined),
        const SizedBox(height: 12),
        _field('District', _districtCtrl, Icons.map_outlined),
        const SizedBox(height: 12),
        _gpsStatusBox(),
        const SizedBox(height: 20),

        _sectionLabel('Description'),
        TextField(
          controller: _descCtrl,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: _dec('What were they wearing? Any details...', null),
        ),
        const SizedBox(height: 24),

        if (_error != null) ...[
          Text(_error!,
              style: const TextStyle(color: Color(0xFFEF5350)),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
        ],

        ElevatedButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.add_alert),
          label: Text(_submitting ? 'Submitting...' : 'Submit Alert'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4FC3F7),
            foregroundColor: const Color(0xFF0D1B2A),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    ),
  );

  Widget _gpsStatusBox() {
    final ok = _lat != null;
    final color = ok
        ? const Color(0xFF4FC3F7)
        : _locating
            ? const Color(0xFF90A4AE)
            : const Color(0xFFEF5350);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2F3F),
        borderRadius: BorderRadius.circular(10),
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
                    ? 'GPS: ${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}'
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

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(label,
            style: const TextStyle(color: Color(0xFF4FC3F7),
                fontSize: 13, fontWeight: FontWeight.bold,
                letterSpacing: 0.5)),
      );

  Widget _field(String label, TextEditingController ctrl, IconData icon) =>
      TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white),
        decoration: _dec(label, icon),
      );

  Widget _numberField(String label, Function(String) onChanged) =>
      TextField(
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white),
        onChanged: onChanged,
        decoration: _dec(label, null),
      );

  Widget _genderDropdown() => DropdownButtonFormField<String>(
        value: _gender,
        dropdownColor: const Color(0xFF1C2F3F),
        style: const TextStyle(color: Colors.white),
        decoration: _dec('Gender', null),
        items: ['male', 'female', 'other']
            .map((g) => DropdownMenuItem(value: g, child: Text(g)))
            .toList(),
        onChanged: (v) => setState(() => _gender = v ?? 'male'),
      );

  InputDecoration _dec(String label, IconData? icon) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF90A4AE)),
        prefixIcon: icon != null
            ? Icon(icon, color: const Color(0xFF4FC3F7), size: 20)
            : null,
        filled: true,
        fillColor: const Color(0xFF1C2F3F),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: Color(0xFF4FC3F7))),
      );
}