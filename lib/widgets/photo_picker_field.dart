import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Reusable photo-evidence picker. Lets the user take a photo or choose one
/// from the gallery, resizes/compresses it, and hands back a base64 data URI
/// via [onChanged] (or null when removed).
class PhotoPickerField extends StatefulWidget {
  final ValueChanged<String?> onChanged;
  final String label;
  final String hint;
  /// A photo already captured elsewhere (e.g. the Snap Incident flow), shown as
  /// the initial preview. Base64 data URI.
  final String? initialDataUri;

  const PhotoPickerField({
    super.key,
    required this.onChanged,
    this.label = 'Add a photo (optional)',
    this.hint = 'Camera or gallery',
    this.initialDataUri,
  });

  @override
  State<PhotoPickerField> createState() => _PhotoPickerFieldState();
}

class _PhotoPickerFieldState extends State<PhotoPickerField> {
  final ImagePicker _picker = ImagePicker();
  File? _file;
  Uint8List? _initialBytes; // preview for a pre-supplied photo

  @override
  void initState() {
    super.initState();
    final uri = widget.initialDataUri;
    if (uri != null && uri.startsWith('data:image')) {
      try {
        _initialBytes = base64Decode(uri.split(',').last);
      } catch (_) {/* ignore bad data */}
    }
  }

  bool get _hasImage => _file != null || _initialBytes != null;

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 55,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final uri = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      if (!mounted) return;
      setState(() { _file = File(picked.path); _initialBytes = null; });
      widget.onChanged(uri);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load image'),
            backgroundColor: Color(0xFF1C2F3F)),
      );
    }
  }

  void _showSourceSheet() {
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
            onTap: () { Navigator.pop(ctx); _pick(ImageSource.camera); },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: Color(0xFF4FC3F7)),
            title: const Text('Choose from gallery',
                style: TextStyle(color: Colors.white)),
            onTap: () { Navigator.pop(ctx); _pick(ImageSource.gallery); },
          ),
          if (_hasImage)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Color(0xFFEF5350)),
              title: const Text('Remove photo',
                  style: TextStyle(color: Color(0xFFEF5350))),
              onTap: () {
                Navigator.pop(ctx);
                setState(() { _file = null; _initialBytes = null; });
                widget.onChanged(null);
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showSourceSheet,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: const Color(0xFF1C2F3F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hasImage
                ? const Color(0xFF4FC3F7)
                : const Color(0xFF2A3F52),
            width: _hasImage ? 1.5 : 0.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: _hasImage
            ? Stack(fit: StackFit.expand, children: [
                _file != null
                    ? Image.file(_file!, fit: BoxFit.cover)
                    : Image.memory(_initialBytes!, fit: BoxFit.cover),
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    decoration: const BoxDecoration(
                        color: Colors.black54, shape: BoxShape.circle),
                    child: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                      onPressed: _showSourceSheet,
                    ),
                  ),
                ),
              ])
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo_outlined,
                      color: Color(0xFF4FC3F7), size: 32),
                  const SizedBox(height: 8),
                  Text(widget.label,
                      style: const TextStyle(
                          color: Color(0xFF90A4AE), fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(widget.hint,
                      style: const TextStyle(
                          color: Color(0xFF4A6070), fontSize: 11)),
                ],
              ),
      ),
    );
  }
}
