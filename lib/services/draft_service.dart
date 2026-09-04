import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Auto-saves an in-progress report form to local storage so leaving the screen
/// (back button, app switch, accidental navigation) doesn't lose what was typed.
///
/// One instance per form, identified by [key]. Call [scheduleSave] whenever a
/// field changes, [load] on startup to restore, and [clear] after a successful
/// submit so the next report starts blank.
class FormDraft {
  final String key;
  Timer? _debounce;

  FormDraft(this.key);

  String get _storageKey => 'draft_$key';

  /// Writes after a short idle gap so rapid typing doesn't hit disk per keystroke.
  void scheduleSave(Map<String, dynamic> Function() collect) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(collect()));
    });
  }

  /// Writes immediately — used when the form is being disposed and a pending
  /// debounced write would otherwise be lost.
  Future<void> saveNow(Map<String, dynamic> data) async {
    _debounce?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(data));
  }

  /// Returns the saved draft, or null if there isn't one worth restoring.
  ///
  /// [meaningfulFields] are the keys that represent real user input (typed
  /// text, an attached photo). A draft where all of them are blank is treated
  /// as absent, so merely touching a dropdown doesn't resurrect an empty form.
  Future<Map<String, dynamic>?> load({List<String> meaningfulFields = const []}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      if (meaningfulFields.isNotEmpty) {
        final hasContent = meaningfulFields.any((k) {
          final v = decoded[k];
          return v != null && v.toString().trim().isNotEmpty;
        });
        if (!hasContent) return null;
      }
      return decoded;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    _debounce?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  void dispose() => _debounce?.cancel();
}
