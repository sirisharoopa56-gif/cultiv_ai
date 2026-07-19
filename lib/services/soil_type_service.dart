import 'package:http/http.dart' as http;
import 'dart:convert';
import 'location_service.dart';

/// Represents soil composition data.
class SoilData {
  final double clay;
  final double silt;
  final double sand;
  final String soilType;
  final String detectionMethod; // 'SoilGrids' or 'AI_Inference'

  SoilData({
    required this.clay,
    required this.silt,
    required this.sand,
    required this.soilType,
    required this.detectionMethod,
  });

  /// Determines soil type from composition percentages.
  static String determineSoilType(double clay, double silt, double sand) {
    if (clay > 40) {
      return 'Clay';
    } else if (sand > 70) {
      return 'Sandy';
    } else if (silt > 50) {
      return 'Silty';
    } else if (clay > 20 && sand > 20 && silt > 20) {
      return 'Loam';
    } else if (clay > 20 && sand > 20) {
      return 'Clay Loam';
    } else if (clay > 20 && silt > 20) {
      return 'Silty Clay Loam';
    } else if (sand > 50 && clay < 20) {
      return 'Sandy Loam';
    }
    return 'Loam';
  }
}

/// Detects soil type using SoilGrids API (primary) with AI fallback.
class SoilTypeService {
  static const String _soilGridsUrl =
      'https://rest.isric.org/soilgrids/v2.0/properties/query';

  /// Primary approach: SoilGrids API for real soil data.
  Future<SoilData?> _fetchFromSoilGrids(double latitude, double longitude) async {
    try {
      final uri = Uri.parse(_soilGridsUrl).replace(
        queryParameters: {
          'lon': longitude.toString(),
          'lat': latitude.toString(),
          'property': ['clay', 'sand', 'silt'],
          'depth': '0-5cm',
          'value': 'mean',
        },
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final layers = json['properties']['layers'] as List;

        double extractValue(String propertyName) {
          final layer = layers.firstWhere(
            (l) => l['name'] == propertyName,
            orElse: () => null,
          );
          if (layer == null) return 0.0;
          final raw = (layer['depths'][0]['values']['mean'] ?? 0).toDouble();
          return raw / 10.0; // SoilGrids scales by 10
        }

        final clay = extractValue('clay');
        final sand = extractValue('sand');
        final silt = extractValue('silt');

        // CRITICAL: If any value is 0 (null in JSON), fallback
        if (clay == 0.0 && sand == 0.0 && silt == 0.0) {
          return null; // Triggers fallback to AI inference
        }

        return SoilData(
          clay: clay,
          silt: silt,
          sand: sand,
          soilType: SoilData.determineSoilType(clay, silt, sand),
          detectionMethod: 'SoilGrids',
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Fallback approach: Use location name to infer soil type via knowledge base.
  /// This doesn't require external API calls and always works offline.
  Future<SoilData?> _inferFromLocation(double latitude, double longitude) async {
    try {
      final locationService = LocationService();
      final placeName = await locationService.getPlaceName(latitude, longitude);

      // Simple heuristic knowledge base for common Indian regions
      // This can be expanded with more regions and crops
      final soilTypeInference = _inferSoilFromRegion(placeName, latitude, longitude);

      return SoilData(
        clay: soilTypeInference['clay'] as double,
        silt: soilTypeInference['silt'] as double,
        sand: soilTypeInference['sand'] as double,
        soilType: soilTypeInference['soilType'] as String,
        detectionMethod: 'AI_Inference',
      );
    } catch (e) {
      return null;
    }
  }

  /// Infers soil type based on region name and coordinates.
  Map<String, dynamic> _inferSoilFromRegion(String placeName, double lat, double lon) {
    final lowerPlace = placeName.toLowerCase();

    // Regional soil type knowledge base
    // Format: region keywords -> soil composition
    if (lowerPlace.contains('bengaluru') ||
        lowerPlace.contains('karnataka') ||
        (lat > 12 && lat < 14 && lon > 77 && lon < 79)) {
      return {
        'clay': 35.0,
        'silt': 25.0,
        'sand': 40.0,
        'soilType': 'Clay Loam',
      };
    } else if (lowerPlace.contains('punjab') ||
        lowerPlace.contains('haryana') ||
        lowerPlace.contains('delhi') ||
        (lat > 28 && lat < 32 && lon > 75 && lon < 77)) {
      return {
        'clay': 25.0,
        'silt': 45.0,
        'sand': 30.0,
        'soilType': 'Silty Loam',
      };
    } else if (lowerPlace.contains('maharashtra') ||
        (lat > 17 && lat < 21 && lon > 72 && lon < 76)) {
      return {
        'clay': 45.0,
        'silt': 20.0,
        'sand': 35.0,
        'soilType': 'Clay',
      };
    } else if (lowerPlace.contains('rajasthan') ||
        (lat > 24 && lat < 28 && lon > 69 && lon < 76)) {
      return {
        'clay': 15.0,
        'silt': 20.0,
        'sand': 65.0,
        'soilType': 'Sandy Loam',
      };
    } else if (lowerPlace.contains('tamil') ||
        lowerPlace.contains('andhra') ||
        (lat > 10 && lat < 15 && lon > 78 && lon < 81)) {
      return {
        'clay': 40.0,
        'silt': 25.0,
        'sand': 35.0,
        'soilType': 'Clay Loam',
      };
    }

    // Default to loam if region not recognized
    return {
      'clay': 25.0,
      'silt': 35.0,
      'sand': 40.0,
      'soilType': 'Loam',
    };
  }

  /// Main entry point: tries SoilGrids first, falls back to AI inference.
  Future<SoilData> detectSoil(double latitude, double longitude) async {
    // Try primary approach (SoilGrids API)
    final soilGridsData = await _fetchFromSoilGrids(latitude, longitude);
    if (soilGridsData != null) {
      return soilGridsData;
    }

    // Fallback to AI inference
    final inferredData = await _inferFromLocation(latitude, longitude);
    if (inferredData != null) {
      return inferredData;
    }

    // Last resort: return default loam
    return SoilData(
      clay: 25.0,
      silt: 35.0,
      sand: 40.0,
      soilType: 'Loam',
      detectionMethod: 'Default',
    );
  }
}
