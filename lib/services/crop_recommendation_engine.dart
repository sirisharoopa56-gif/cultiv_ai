import 'soil_type_service.dart';
import 'weather_service.dart';
import 'groq_service.dart';

/// Represents a crop recommendation with details.
class CropRecommendation {
  final String cropName;
  final String reason;
  final List<int> bestMonths; // e.g., [3, 4, 5] for March, April, May
  final double confidenceScore; // 0.0 to 1.0
  final List<String> tips;

  CropRecommendation({
    required this.cropName,
    required this.reason,
    required this.bestMonths,
    required this.confidenceScore,
    required this.tips,
  });
}

/// Generates crop recommendations based on soil type, weather, and seasonal data.
class CropRecommendationEngine {
  GroqService? _groqService;

  CropRecommendationEngine() {
    try {
      _groqService = GroqService();
    } catch (e) {
      // Groq service initialization failed. Using local database only.
      // This is expected if GROQ_API_KEY is not set in .env
      _groqService = null;
    }
  }
  /// Comprehensive crop database with soil/weather preferences.
  static const Map<String, Map<String, dynamic>> _cropDatabase = {
    'Rice': {
      'soilTypes': ['Clay', 'Clay Loam', 'Loam'],
      'temperatureMin': 20,
      'temperatureMax': 35,
      'humidityMin': 60,
      'rainfallMin': 100,
      'bestMonths': [5, 6, 7], // May-July
      'tips': [
        'Requires waterlogged fields',
        'Plant during monsoon for best yield',
        'Keep field flooded 5-10cm during growth',
      ],
    },
    'Wheat': {
      'soilTypes': ['Silty Loam', 'Loam', 'Clay Loam'],
      'temperatureMin': 7,
      'temperatureMax': 25,
      'humidityMin': 40,
      'rainfallMin': 30,
      'bestMonths': [10, 11, 12], // Oct-Dec
      'tips': [
        'Sow in winter season',
        'Needs cool temperatures to flourish',
        'Well-drained soil preferred',
      ],
    },
    'Maize': {
      'soilTypes': ['Loam', 'Sandy Loam', 'Clay Loam'],
      'temperatureMin': 16,
      'temperatureMax': 30,
      'humidityMin': 50,
      'rainfallMin': 50,
      'bestMonths': [5, 6, 7], // May-July
      'tips': [
        'High nitrogen demand',
        'Thrives in warm season',
        'Regular irrigation needed',
      ],
    },
    'Cotton': {
      'soilTypes': ['Clay', 'Clay Loam', 'Loam'],
      'temperatureMin': 21,
      'temperatureMax': 35,
      'humidityMin': 40,
      'rainfallMin': 50,
      'bestMonths': [4, 5, 6], // Apr-Jun
      'tips': [
        'Requires well-drained soil',
        'Long growing season (180-200 days)',
        'Needs warm climate',
      ],
    },
    'Sugarcane': {
      'soilTypes': ['Clay', 'Clay Loam', 'Loam'],
      'temperatureMin': 20,
      'temperatureMax': 32,
      'humidityMin': 50,
      'rainfallMin': 100,
      'bestMonths': [11, 12, 1], // Nov-Jan
      'tips': [
        'Long crop cycle (10-12 months)',
        'Needs consistent moisture',
        'Rich soil with organic matter recommended',
      ],
    },
    'Potato': {
      'soilTypes': ['Loam', 'Sandy Loam', 'Clay Loam'],
      'temperatureMin': 10,
      'temperatureMax': 25,
      'humidityMin': 50,
      'rainfallMin': 50,
      'bestMonths': [9, 10, 11], // Sept-Nov
      'tips': [
        'Light, loose soil preferred',
        'Good drainage essential',
        'Needs cool season',
      ],
    },
    'Carrot': {
      'soilTypes': ['Sandy Loam', 'Loam'],
      'temperatureMin': 10,
      'temperatureMax': 25,
      'humidityMin': 40,
      'rainfallMin': 30,
      'bestMonths': [7, 8, 9], // Jul-Sep
      'tips': [
        'Well-drained soil needed',
        'Direct sowing recommended',
        'Thin seedlings for better growth',
      ],
    },
    'Broccoli': {
      'soilTypes': ['Loam', 'Clay Loam', 'Silty Loam'],
      'temperatureMin': 10,
      'temperatureMax': 23,
      'humidityMin': 60,
      'rainfallMin': 40,
      'bestMonths': [9, 10, 11], // Sept-Nov
      'tips': [
        'Rich soil with nitrogen needed',
        'Consistent moisture critical',
        'Harvest before flower bud opens',
      ],
    },
    'Tomato': {
      'soilTypes': ['Loam', 'Clay Loam', 'Sandy Loam'],
      'temperatureMin': 15,
      'temperatureMax': 30,
      'humidityMin': 50,
      'rainfallMin': 40,
      'bestMonths': [3, 4, 9, 10], // Mar, Apr, Sep, Oct
      'tips': [
        'Support structures recommended',
        'Regular pruning improves yield',
        'Needs well-drained soil',
      ],
    },
    'Onion': {
      'soilTypes': ['Loam', 'Sandy Loam', 'Clay Loam'],
      'temperatureMin': 12,
      'temperatureMax': 28,
      'humidityMin': 40,
      'rainfallMin': 50,
      'bestMonths': [10, 11, 12], // Oct-Dec
      'tips': [
        'Requires sunlight (14+ hours)',
        'Well-drained soil essential',
        'Avoid waterlogging',
      ],
    },
    'Groundnut': {
      'soilTypes': ['Sandy Loam', 'Loam'],
      'temperatureMin': 20,
      'temperatureMax': 32,
      'humidityMin': 40,
      'rainfallMin': 50,
      'bestMonths': [5, 6, 7], // May-Jul
      'tips': [
        'Sandy, well-drained soil preferred',
        'Good for crop rotation',
        'Drought tolerant crop',
      ],
    },
  };

  /// Generates crop recommendations based on current soil and weather.
  List<CropRecommendation> generateRecommendations({
    required SoilData soil,
    required WeatherData weather,
  }) {
    final List<CropRecommendation> recommendations = [];

    _cropDatabase.forEach((cropName, cropPrefs) {
      // Calculate compatibility score
      double score = 0.0;
      final soilMatch = (cropPrefs['soilTypes'] as List<String>).contains(soil.soilType) ? 0.3 : 0.1;
      final tempMatch = weather.temperature >= (cropPrefs['temperatureMin'] as int) &&
              weather.temperature <= (cropPrefs['temperatureMax'] as int)
          ? 0.25
          : 0.0;
      final humidityMatch = weather.humidity >= (cropPrefs['humidityMin'] as int) ? 0.2 : 0.1;
      final rainfallMatch = weather.rainfall >= (cropPrefs['rainfallMin'] as int) / 100 ? 0.25 : 0.1;

      score = soilMatch + tempMatch + humidityMatch + rainfallMatch;

      // Only include crops with reasonable match (score > 0.5)
      if (score > 0.5) {
        final reason = _generateReason(cropName, soil.soilType, weather, score);

        recommendations.add(
          CropRecommendation(
            cropName: cropName,
            reason: reason,
            bestMonths: List<int>.from(cropPrefs['bestMonths'] as List<int>),
            confidenceScore: (score / 1.0).clamp(0.0, 1.0),
            tips: List<String>.from(cropPrefs['tips'] as List<String>),
          ),
        );
      }
    });

    // Sort by confidence score (highest first)
    recommendations.sort((a, b) => b.confidenceScore.compareTo(a.confidenceScore));

    return recommendations;
  }

  /// Generates a user-friendly recommendation reason.
  String _generateReason(String cropName, String soilType, WeatherData weather, double score) {
    if (score > 0.8) {
      return '$cropName is excellent for your $soilType soil with current weather conditions.';
    } else if (score > 0.65) {
      return '$cropName grows well in $soilType soil. Temperature and humidity are favorable.';
    } else {
      return '$cropName is suitable for $soilType soil with some adaptations needed.';
    }
  }

  /// Gets the current month (1-12).
  static int getCurrentMonth() {
    return DateTime.now().month;
  }

  /// Checks if a crop is in its best planting season.
  static bool isInBestSeason(CropRecommendation crop) {
    return crop.bestMonths.contains(getCurrentMonth());
  }

  /// Gets formatted best months as readable string.
  static String getFormattedMonths(List<int> months) {
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months.map((m) => monthNames[m - 1]).join(', ');
  }

  /// Gets AI-enhanced recommendation from Groq API
  Future<String?> getAIEnhancedRecommendation({
    required SoilData soil,
    required WeatherData weather,
  }) async {
    // If Groq service not initialized, return null
    if (_groqService == null) {
      return null;
    }

    try {
      final recommendation = await _groqService!.generateCropRecommendation(
        soilType: soil.soilType,
        temperature: weather.temperature,
        humidity: weather.humidity,
        rainfall: weather.rainfall,
        currentMonth: getCurrentMonth(),
      );
      return recommendation;
    } catch (e) {
      // Failed to get AI recommendation, return null for fallback
      return null;
    }
  }

  /// Tests Groq API connection
  Future<bool> testGroqConnection() async {
    if (_groqService == null) {
      return false;
    }
    try {
      return await _groqService!.testConnection();
    } catch (e) {
      return false;
    }
  }
}

