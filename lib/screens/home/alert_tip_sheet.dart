import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';

/// Bottom sheet that lets a citizen send information / a tip about an alert.
/// Works for any alert type (crime, traffic, health, missing person…).
///
/// Usage:
///   showModalBottomSheet(
///     context: context, isScrollControlled: true,
///     builder: (_) => AlertTipSheet(alertId: a.id, alertTitle: a.title),
///   );
class AlertTipSheet extends StatefulWidget {
  final int alertId;
  final String alertTitle;
  const AlertTipSheet({
    super.key,
    required this.alertId,
    required this.alertTitle,
  });

  @override
  State<AlertTipSheet> createState() => _AlertTipSheetState();
}

class _AlertTipSheetState extends State<AlertTipSheet> {
  final _api         = ApiService();
  final _msgCtrl     = TextEditingController();
  final _contactCtrl = TextEditingController();

  bool    _attachLocation = true;
  bool    _submitting     = false;
  bool    _done           = false;
  String? _error;

  @override
  void dispose() {
    _msgCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final msg = _msgCtrl.text.trim();
    if (msg.length < 5) {
      setState(() => _error = 'Please describe what you saw (min 5 characters).');
      return;
    }
    setState(() { _submitting = true; _error = null; });

    double? lat, lng;
    if (_attachLocation) {
      final loc = await LocationService.getCurrentLocation();
      if (loc.ok) { lat = loc.latitude; lng = loc.longitude; }
    }

    try {
      await _api.submitAlertResponse(widget.alertId, {
        'message':      msg,
        'latitude':     lat,
        'longitude':    lng,
        'contact_info': _contactCtrl.text.trim().isEmpty
                        ? null
                        : _contactCtrl.text.trim(),
      });
      if (!mounted) return;
      setState(() { _done = true; _submitting = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not send your tip. Check your connection and try again.';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: _done ? _successView() : _form(),
    );
  }

  Widget _successView() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.verified, color: Color(0xFF66BB6A), size: 56),
      const SizedBox(height: 12),
      const Text('Information Sent',
          style: TextStyle(color: Colors.white,
              fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text(
        'Thank you. Your tip has been sent to the authorities and the original reporter.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF90A4AE), fontSize: 13),
      ),
      const SizedBox(height: 18),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4FC3F7),
            foregroundColor: const Color(0xFF0D1B2A),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Done',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    ],
  );

  Widget _form() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Center(
        child: Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFF2A3F52),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Row(children: [
        const Icon(Icons.tips_and_updates, color: Color(0xFF4FC3F7), size: 20),
        const SizedBox(width: 8),
        const Expanded(
          child: Text('Send Information',
              style: TextStyle(color: Colors.white,
                  fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ]),
      const SizedBox(height: 4),
      Text('Re: ${widget.alertTitle}',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 12)),
      const SizedBox(height: 16),

      TextField(
        controller: _msgCtrl,
        maxLines: 3,
        style: const TextStyle(color: Colors.white),
        decoration: _dec('What did you see? Where and when?'),
      ),
      const SizedBox(height: 12),

      TextField(
        controller: _contactCtrl,
        keyboardType: TextInputType.text,
        style: const TextStyle(color: Colors.white),
        decoration: _dec('Your phone/email (optional — for follow-up)'),
      ),
      const SizedBox(height: 8),

      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Attach my current location',
            style: TextStyle(color: Colors.white, fontSize: 14)),
        subtitle: const Text('Helps authorities locate the sighting',
            style: TextStyle(color: Color(0xFF90A4AE), fontSize: 12)),
        value: _attachLocation,
        activeThumbColor: const Color(0xFF4FC3F7),
        onChanged: (v) => setState(() => _attachLocation = v),
      ),

      if (_error != null) ...[
        const SizedBox(height: 4),
        Text(_error!,
            style: const TextStyle(color: Color(0xFFEF5350), fontSize: 13)),
      ],
      const SizedBox(height: 12),

      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF0D1B2A)))
              : const Icon(Icons.send, size: 16),
          label: Text(_submitting ? 'Sending...' : 'Send to Authorities'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4FC3F7),
            foregroundColor: const Color(0xFF0D1B2A),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    ],
  );

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF4A6070), fontSize: 13),
        filled: true,
        fillColor: const Color(0xFF0D1B2A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2A3F52)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2A3F52)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF4FC3F7)),
        ),
      );
}
