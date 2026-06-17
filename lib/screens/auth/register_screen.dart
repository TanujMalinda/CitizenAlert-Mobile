import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../home/home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _api             = ApiService();
  final _nameCtrl        = TextEditingController();
  final _emailCtrl       = TextEditingController();
  final _passwordCtrl    = TextEditingController();
  final _phoneCtrl       = TextEditingController();
  final _designationCtrl = TextEditingController();
  final _employeeIdCtrl  = TextEditingController();

  String  _district    = 'Colombo';
  String  _department  = '';
  String  _role        = 'citizen';
  bool    _loading     = false;
  bool    _obscure     = true;
  bool    _submitted   = false; // authority pending-approval success state
  String? _error;

  final List<String> _districts = [
    'Colombo', 'Gampaha', 'Kalutara', 'Kandy', 'Matale',
    'Nuwara Eliya', 'Galle', 'Matara', 'Hambantota', 'Jaffna',
    'Kilinochchi', 'Mannar', 'Vavuniya', 'Mullaitivu', 'Batticaloa',
    'Ampara', 'Trincomalee', 'Kurunegala', 'Puttalam', 'Anuradhapura',
    'Polonnaruwa', 'Badulla', 'Monaragala', 'Ratnapura', 'Kegalle',
  ];

  final List<String> _departments = [
    'Sri Lanka Police',
    'Ministry of Health',
    'Disaster Management Centre',
    'Sri Lanka Army',
    'Sri Lanka Navy',
    'Sri Lanka Air Force',
    'Municipal Council',
    'National Hospital',
    'Other Government Department',
  ];

  bool get _isAuthority => _role == 'authority';

  String _parseError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      return data['error']?['message'] ??
             data['detail'] ??
             'Registration failed.';
    }
    return 'Registration failed.';
  }

  Future<void> _register() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _passwordCtrl.text.isEmpty) {
      setState(() => _error = 'Name, email and password are required');
      return;
    }
    if (_passwordCtrl.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    if (_isAuthority) {
      if (_designationCtrl.text.trim().isEmpty ||
          _department.isEmpty ||
          _employeeIdCtrl.text.trim().isEmpty) {
        setState(() => _error = 'Designation, department and employee ID are required for authority registration');
        return;
      }
    }

    setState(() { _loading = true; _error = null; });

    try {
      if (_isAuthority) {
        await _api.registerAuthority({
          'full_name':    _nameCtrl.text.trim(),
          'email':        _emailCtrl.text.trim(),
          'password':     _passwordCtrl.text,
          'phone_number': _phoneCtrl.text.trim(),
          'district':     _district,
          'designation':  _designationCtrl.text.trim(),
          'department':   _department,
          'employee_id':  _employeeIdCtrl.text.trim(),
        });
        if (!mounted) return;
        setState(() { _submitted = true; _loading = false; });
      } else {
        await _api.register({
          'full_name':    _nameCtrl.text.trim(),
          'email':        _emailCtrl.text.trim(),
          'password':     _passwordCtrl.text,
          'phone_number': _phoneCtrl.text.trim(),
          'district':     _district,
        });
        if (!mounted) return;
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } on DioException catch (e) {
      setState(() { _error = _parseError(e); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _pendingApprovalScreen();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Create Account',
            style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.shield_outlined,
                color: Color(0xFF4FC3F7), size: 48),
            const SizedBox(height: 8),
            const Text('Join CitizenAlert',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white,
                    fontSize: 22, fontWeight: FontWeight.bold)),
            const Text('Help keep Sri Lanka safe',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF90A4AE), fontSize: 13)),
            const SizedBox(height: 32),

            // Role selector
            _sectionLabel('I am a'),
            Row(children: [
              _roleChip('citizen',   'Citizen',   Icons.person_outline),
              const SizedBox(width: 12),
              _roleChip('authority', 'Authority', Icons.shield_outlined),
            ]),
            const SizedBox(height: 20),

            // Personal details
            _sectionLabel('Personal details'),
            _field('Full name *', _nameCtrl, Icons.person_outline,
                TextInputType.name),
            const SizedBox(height: 12),
            _field('Email *', _emailCtrl, Icons.email_outlined,
                TextInputType.emailAddress),
            const SizedBox(height: 12),

            // Password
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Password *',
                labelStyle: const TextStyle(color: Color(0xFF90A4AE)),
                prefixIcon: const Icon(Icons.lock_outlined,
                    color: Color(0xFF4FC3F7), size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_outlined
                             : Icons.visibility_off_outlined,
                    color: const Color(0xFF90A4AE), size: 20,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                filled: true,
                fillColor: const Color(0xFF1C2F3F),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF4FC3F7))),
              ),
            ),
            const SizedBox(height: 12),
            _field('Phone number', _phoneCtrl, Icons.phone_outlined,
                TextInputType.phone),
            const SizedBox(height: 20),

            // District
            _sectionLabel('Your district'),
            DropdownButtonFormField<String>(
              value: _district,
              dropdownColor: const Color(0xFF1C2F3F),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.map_outlined,
                    color: Color(0xFF4FC3F7), size: 20),
                filled: true,
                fillColor: const Color(0xFF1C2F3F),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF4FC3F7))),
              ),
              items: _districts
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) => setState(() => _district = v ?? _district),
            ),
            const SizedBox(height: 20),

            // Authority-only fields
            if (_isAuthority) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4FC3F7).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF4FC3F7).withOpacity(0.3)),
                ),
                child: const Text(
                  'Authority registration requires admin approval before you can log in. '
                  'Provide your official credentials below.',
                  style: TextStyle(color: Color(0xFF90A4AE), fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),

              _sectionLabel('Authority credentials'),
              _field('Designation *', _designationCtrl, Icons.badge_outlined,
                  TextInputType.text),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _department.isEmpty ? null : _department,
                dropdownColor: const Color(0xFF1C2F3F),
                style: const TextStyle(color: Colors.white),
                hint: const Text('Select department *',
                    style: TextStyle(color: Color(0xFF90A4AE))),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.business_outlined,
                      color: Color(0xFF4FC3F7), size: 20),
                  filled: true,
                  fillColor: const Color(0xFF1C2F3F),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF4FC3F7))),
                ),
                items: _departments
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (v) => setState(() => _department = v ?? ''),
              ),
              const SizedBox(height: 12),
              _field('Employee / Badge ID *', _employeeIdCtrl,
                  Icons.numbers_outlined, TextInputType.text),
              const SizedBox(height: 20),
            ],

            // Error
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF5350).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFFEF5350).withOpacity(0.4)),
                ),
                child: Text(_error!,
                    style: const TextStyle(color: Color(0xFFEF5350),
                        fontSize: 13),
                    textAlign: TextAlign.center),
              ),
              const SizedBox(height: 16),
            ],

            ElevatedButton(
              onPressed: _loading ? null : _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4FC3F7),
                foregroundColor: const Color(0xFF0D1B2A),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(
                      _isAuthority ? 'Submit for Approval' : 'Create Account',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Already have an account? Login',
                  style: TextStyle(color: Color(0xFF4FC3F7))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pendingApprovalScreen() => Scaffold(
    backgroundColor: const Color(0xFF0D1B2A),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.hourglass_top_rounded,
                color: Color(0xFF4FC3F7), size: 72),
            const SizedBox(height: 24),
            const Text('Registration Submitted',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white,
                    fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text(
              'Your authority account is pending admin approval.\n\n'
              'You will be able to log in once a super-admin reviews and approves your registration.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF90A4AE), fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4FC3F7),
                foregroundColor: const Color(0xFF0D1B2A),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Back to Login',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _roleChip(String value, String label, IconData icon) {
    final selected = _role == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() { _role = value; _error = null; }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF4FC3F7).withOpacity(0.15)
                : const Color(0xFF1C2F3F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? const Color(0xFF4FC3F7) : const Color(0xFF2A3F52),
              width: selected ? 1.5 : 0.5,
            ),
          ),
          child: Column(children: [
            Icon(icon,
                color: selected ? const Color(0xFF4FC3F7) : const Color(0xFF90A4AE),
                size: 24),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: selected ? const Color(0xFF4FC3F7) : const Color(0xFF90A4AE),
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13)),
          ]),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(label,
            style: const TextStyle(color: Color(0xFF4FC3F7),
                fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      );

  Widget _field(String label, TextEditingController ctrl,
      IconData icon, TextInputType type) =>
      TextField(
        controller: ctrl,
        keyboardType: type,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF90A4AE)),
          prefixIcon: Icon(icon, color: const Color(0xFF4FC3F7), size: 20),
          filled: true,
          fillColor: const Color(0xFF1C2F3F),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4FC3F7))),
        ),
      );
}
