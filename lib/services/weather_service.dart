import 'package:http/http.dart' as http;
import 'dart:convert';

/// Represents weather data for a location.
class WeatherData {
  final double temperature;
  final int humidity;
  final double windSpeed;
  final String condition;
  final double rainfall;

  WeatherData({
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    required this.condition,
    required this.rainfall,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      temperature: json['current']['temperature_2m']?.toDouble() ?? 25.0,
      humidity: json['current']['relative_humidity_2m'] ?? 60,
      windSpeed: json['current']['wind_speed_10m']?.toDouble() ?? 10.0,
      condition: _mapWeatherCode(json['current']['weather_code'] ?? 0),
      rainfall: json['current']['precipitation']?.toDouble() ?? 0.0,
    );
  }

  static String _mapWeatherCode(int code) {
    if (code == 0) return 'Clear';
    if (code == 1 || code == 2) return 'Partly Cloudy';
    if (code == 3) return 'Overcast';
    if (code == 45 || code == 48) return 'Foggy';
    if (code >= 51 && code <= 67) return 'Drizzle';
    if (code >= 71 && code <= 77) return 'Snow';
    if (code >= 80 && code <= 82) return 'Rain';
    if (code >= 85 && code <= 86) return 'Heavy Snow';
    if (code >= 90 && code <= 99) return 'Thunderstorm';
    return 'Unknown';
  }
}

/// Fetches weather data from Open-Meteo (free, no API key required).
/// Falls back to mock data if API fails (useful for testing on Flutter Web).
class WeatherService {
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  /// Fetches current weather for the given coordinates.
  /// Uses Open-Meteo's free weather API, with mock fallback for testing.
  Future<WeatherData> getWeather(double latitude, double longitude) async {
    try {
      final uri = Uri.parse(_baseUrl).replace(
        queryParameters: {
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
          'current': 'temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,precipitation',
          'timezone': 'auto',
        },
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return WeatherData.fromJson(json);
      } else {
        throw Exception('Failed to fetch weather: ${response.statusCode}');
      }
    } catch (e) {
      // Fallback to mock weather for testing (especially useful on Flutter Web)
      return getMockWeatherData();
    }
  }

  /// Returns realistic mock weather data for testing.
  /// Use this when API is unavailable (e.g., on Flutter Web with CORS issues).
  static WeatherData getMockWeatherData() {
    return WeatherData(
      temperature: 28.5,
      humidity: 65,
      windSpeed: 8.2,
      condition: 'Partly Cloudy',
      rainfall: 0.5,
    );
  }
}
