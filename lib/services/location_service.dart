import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// Handles getting the device's current GPS coordinates and
/// converting them into a human-readable place name.
class LocationService {
  /// Requests permission and returns the current position.
  /// Throws an exception if permission is denied or location
  /// services are disabled — the calling UI should catch this
  /// and show a friendly error/fallback.
  Future<Position> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable GPS.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied. Enable it in settings.');
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
    );
  }

  /// Converts coordinates into a readable place name, e.g.
  /// "Doddaballapur, Karnataka, India"
  Future<String> getPlaceName(double lat, double lon) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        return '${p.locality ?? p.subAdministrativeArea ?? ''}, ${p.administrativeArea ?? ''}'
            .trim();
      }
      return 'Unknown location';
    } catch (e) {
      return 'Unknown location';
    }
  }
}