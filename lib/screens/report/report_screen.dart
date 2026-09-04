import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../services/api_service.dart';
import '../../services/draft_service.dart';
import '../../services/location_service.dart';
import 'location_picker_screen.dart';

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
  final _ageCtrl      = TextEditingController();

  final _draft = FormDraft('missing_person_report');

  int?    _age;
  String  _gender     = 'male';
  // Selected last-seen location (null until the user picks it on the map).
  double? _lat;
  double? _lng;
  // Current GPS — used only to centre the map picker initially.
  double? _gpsLat;
  double? _gpsLng;
  bool    _submitting = false;
  String? _error;
  bool    _success    = false;

  // Photo of the missing person (optional)
  File?      _photoFile;
  Uint8List? _photoBytes;  // preview for a photo restored from a saved draft
  String? _photoDataUri; // "data:image/jpeg;base64,..." sent as photo_url
  final ImagePicker _picker = ImagePicker();

  bool get _hasPhoto => _photoFile != null || _photoBytes != null;

  @override
  void initState() {
    super.initState();
    for (final c in [_nameCtrl, _descCtrl, _locationCtrl, _districtCtrl, _ageCtrl]) {
      c.addListener(_saveDraft);
    }
    _restoreDraft();
    _getLocation();
  }

  @override
  void dispose() {
    _draft.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _districtCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _collectDraft() => {
        'name':     _nameCtrl.text,
        'desc':     _descCtrl.text,
        'location': _locationCtrl.text,
        'district': _districtCtrl.text,
        'age':      _ageCtrl.text,
        'gender':   _gender,
        'lat':      _lat,
        'lng':      _lng,
        'photo':    _photoDataUri,
      };

  void _saveDraft() => _draft.scheduleSave(_collectDraft);

  Future<void> _restoreDraft() async {
    final d = await _draft.load(meaningfulFields: [
      'name', 'desc', 'location', 'district', 'age', 'photo',
    ]);
    if (d == null || !mounted) return;
    setState(() {
      _nameCtrl.text     = d['name'] ?? '';
      _descCtrl.text     = d['desc'] ?? '';
      _locationCtrl.text = d['location'] ?? '';
      _districtCtrl.text = d['district'] ?? '';
      _ageCtrl.text      = d['age'] ?? '';
      _age               = int.tryParse(_ageCtrl.text);
      if (['male', 'female', 'other'].contains(d['gender'])) _gender = d['gender'];
      _lat = (d['lat'] as num?)?.toDouble();
      _lng = (d['lng'] as num?)?.toDouble();
      final photo = d['photo'] as String?;
      if (photo != null && photo.startsWith('data:image')) {
        try {
          _photoBytes   = base64Decode(photo.split(',').last);
          _photoDataUri = photo;
        } catch (_) {/* ignore unreadable draft photo */}
      }
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Unfinished report restored'),
        backgroundColor: const Color(0xFF1C2F3F),
        action: SnackBarAction(
          label: 'Discard',
          textColor: const Color(0xFF4FC3F7),
          onPressed: _discardDraft,
        ),
      ),
    );
  }

  Future<void> _discardDraft() async {
    await _draft.clear();
    if (!mounted) return;
    setState(() {
      _nameCtrl.clear();
      _descCtrl.clear();
      _locationCtrl.clear();
      _districtCtrl.clear();
      _ageCtrl.clear();
      _age = null;
      _gender = 'male';
      _lat = null;
      _lng = null;
      _photoFile = null;
      _photoBytes = null;
      _photoDataUri = null;
    });
  }

  Future<void> _getLocation() async {
    // Fetch current GPS only to seed the map picker's starting position.
    final res = await LocationService.getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _gpsLat = res.latitude;
      _gpsLng = res.longitude;
    });
  }

  Future<void> _pickLocation() async {
    final LatLng? initial = (_lat != null && _lng != null)
        ? LatLng(_lat!, _lng!)
        : (_gpsLat != null && _gpsLng != null)
            ? LatLng(_gpsLat!, _gpsLng!)
            : null;
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initial: initial,
          title: 'Select Last Seen Location',
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _lat = result.latitude;
        _lng = result.longitude;
        _error = null;
      });
      _saveDraft();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 800,      // resize down — keeps the base64 small
        maxHeight: 800,
        imageQuality: 55,   // compress
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final b64 = base64Encode(bytes);
      if (!mounted) return;
      setState(() {
        _photoFile = File(picked.path);
        _photoBytes = null;
        _photoDataUri = 'data:image/jpeg;base64,$b64';
      });
      _saveDraft();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load image');
    }
  }

  void _showPhotoSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C2F3F),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.photo_camera, color: Color(0xFF4FC3F7)),
            title: const Text('Take a photo',
                style: TextStyle(color: Colors.white)),
            onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: Color(0xFF4FC3F7)),
            title: const Text('Choose from gallery',
                style: TextStyle(color: Colors.white)),
            onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); },
          ),
          if (_hasPhoto)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Color(0xFFEF5350)),
              title: const Text('Remove photo',
                  style: TextStyle(color: Color(0xFFEF5350))),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _photoFile = null;
                  _photoBytes = null;
                  _photoDataUri = null;
                });
                _saveDraft();
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
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
      setState(() => _error = 'Please select the last seen location on the map');
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
        'photo_url':              _photoDataUri,
      });
      await _draft.clear();
      if (!mounted) return;
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
        _photoPicker(),
        const SizedBox(height: 12),
        _field('Full name *', _nameCtrl, Icons.person_outline),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _numberField('Age', _ageCtrl, (v) =>
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
        _locationBox(),
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

  Widget _photoPicker() {
    return GestureDetector(
      onTap: _showPhotoSourceSheet,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: const Color(0xFF1C2F3F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hasPhoto
                ? const Color(0xFF4FC3F7)
                : const Color(0xFF2A3F52),
            width: _hasPhoto ? 1.5 : 0.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: _hasPhoto
            ? Stack(fit: StackFit.expand, children: [
                _photoFile != null
                    ? Image.file(_photoFile!, fit: BoxFit.cover)
                    : Image.memory(_photoBytes!, fit: BoxFit.cover),
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54, shape: BoxShape.circle),
                    child: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                      onPressed: _showPhotoSourceSheet,
                    ),
                  ),
                ),
              ])
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.add_a_photo_outlined,
                      color: Color(0xFF4FC3F7), size: 34),
                  SizedBox(height: 8),
                  Text('Add a photo of the person',
                      style: TextStyle(color: Color(0xFF90A4AE), fontSize: 13)),
                  SizedBox(height: 2),
                  Text('Camera or gallery (optional)',
                      style: TextStyle(color: Color(0xFF4A6070), fontSize: 11)),
                ],
              ),
      ),
    );
  }

  Widget _locationBox() {
    final ok = _lat != null && _lng != null;
    final color = ok ? const Color(0xFF4FC3F7) : const Color(0xFF90A4AE);
    return GestureDetector(
      onTap: _pickLocation,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C2F3F),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: ok ? color : const Color(0xFF2A3F52),
              width: ok ? 1.2 : 0.5),
        ),
        child: Row(children: [
          Icon(ok ? Icons.location_on : Icons.add_location_alt_outlined,
              color: const Color(0xFF4FC3F7), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ok ? 'Last seen location set' : 'Select last seen location *',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  ok
                      ? '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}'
                      : 'Tap to choose the spot on the map',
                  style: const TextStyle(
                      color: Color(0xFF90A4AE), fontSize: 12),
                ),
              ],
            ),
          ),
          Text(ok ? 'Change' : 'Select',
              style: const TextStyle(
                  color: Color(0xFF4FC3F7),
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Color(0xFF4FC3F7), size: 18),
        ]),
      ),
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

  Widget _numberField(String label, TextEditingController ctrl,
          Function(String) onChanged) =>
      TextField(
        controller: ctrl,
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
        onChanged: (v) {
          setState(() => _gender = v ?? 'male');
          _saveDraft();
        },
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