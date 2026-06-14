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
  final _api          = ApiService();
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl    = TextEditingController();

  String  _district   = 'Colombo';
  String  _role       = 'citizen';
  bool    _loading    = false;
  bool    _obscure    = true;
  String? _error;

  final List<String> _districts = [
    'Colombo', 'Gampaha', 'Kalutara', 'Kandy', 'Matale',
    'Nuwara Eliya', 'Galle', 'Matara', 'Hambantota', 'Jaffna',
    'Kilinochchi', 'Mannar', 'Vavuniya', 'Mullaitivu', 'Batticaloa',
    'Ampara', 'Trincomalee', 'Kurunegala', 'Puttalam', 'Anuradhapura',
    'Polonnaruwa', 'Badulla', 'Monaragala', 'Ratnapura', 'Kegalle',
  ];

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
    setState(() { _loading = true; _error = null; });
    try {
      await _api.register({
        'full_name':    _nameCtrl.text.trim(),
        'email':        _emailCtrl.text.trim(),
        'password':     _passwordCtrl.text,
        'phone_number': _phoneCtrl.text.trim(),
        'district':     _district,
        'role':         _role,
      });
      if (!mounted) return;
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?['detail'] ?? 'Registration failed.';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              _roleChip('citizen', 'Citizen', Icons.person_outline),
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

            // Location
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
            const SizedBox(height: 24),

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

            // Register button
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
                  : const Text('Create Account',
                      style: TextStyle(fontSize: 16,
                          fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),

            // Back to login
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

  Widget _roleChip(String value, String label, IconData icon) {
    final selected = _role == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _role = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF4FC3F7).withOpacity(0.15)
                : const Color(0xFF1C2F3F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFF4FC3F7)
                  : const Color(0xFF2A3F52),
              width: selected ? 1.5 : 0.5,
            ),
          ),
          child: Column(children: [
            Icon(icon,
                color: selected
                    ? const Color(0xFF4FC3F7)
                    : const Color(0xFF90A4AE),
                size: 24),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: selected
                        ? const Color(0xFF4FC3F7)
                        : const Color(0xFF90A4AE),
                    fontWeight: selected
                        ? FontWeight.bold
                        : FontWeight.normal,
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
                fontSize: 12, fontWeight: FontWeight.bold,
                letterSpacing: 0.5)),
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