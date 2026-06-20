import 'package:geolocator/geolocator.dart';

/// Result of a location acquisition attempt.
class LocationResult {
  final double? latitude;
  final double? longitude;
  final String? error; // null when successful

  const LocationResult({this.latitude, this.longitude, this.error});

  bool get ok => latitude != null && longitude != null;
}

/// Centralised GPS acquisition with permission handling and a timeout.
/// Used by every report screen and the home map so behaviour is consistent.
class LocationService {
  /// Acquires the device's current position.
  /// Returns a [LocationResult] with either coordinates or a human-readable error.
  static Future<LocationResult> getCurrentLocation({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    // 1. Is the device's location service (GPS) switched on at all?
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      return const LocationResult(
        error: 'Location services are OFF. Enable GPS/Location on the device '
            '(or set a location in the emulator) and try again.',
      );
    }

    // 2. Check & request permission.
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      return const LocationResult(
        error: 'Location permission denied. Please allow location access to tag your report.',
      );
    }
    if (perm == LocationPermission.deniedForever) {
      return const LocationResult(
        error: 'Location permission permanently denied. '
            'Enable it for CitizenAlert in your device Settings → Apps → Permissions.',
      );
    }

    // 3. Get the position with a timeout so the UI never hangs forever.
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: timeout,
      );
      return LocationResult(latitude: pos.latitude, longitude: pos.longitude);
    } catch (e) {
      // Timed out or no fix — fall back to last known position if available.
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        return LocationResult(latitude: last.latitude, longitude: last.longitude);
      }
      return const LocationResult(
        error: 'Could not get a GPS fix (timed out). '
            'Make sure you are outdoors or have a location set in the emulator, then retry.',
      );
    }
  }

  /// Opens the OS app-settings page so the user can grant permission manually.
  static Future<void> openSettings() => Geolocator.openAppSettings();
}
