import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Groq API integration for AI-powered crop recommendations
class GroqService {
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  
  late final String _apiKey;

  GroqService() {
    _apiKey = dotenv.env['GROQ_API_KEY'] ?? '';
    if (_apiKey.isEmpty) {
      throw Exception('GROQ_API_KEY not found in .env file');
    }
  }

  /// Generates AI-powered crop recommendation using Groq API
  Future<String> generateCropRecommendation({
    required String soilType,
    required double temperature,
    required int humidity,
    required double rainfall,
    required int currentMonth,
  }) async {
    try {
      final prompt = _buildPrompt(
        soilType: soilType,
        temperature: temperature,
        humidity: humidity,
        rainfall: rainfall,
        currentMonth: currentMonth,
      );

      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': 'mixtral-8x7b-32768', // Groq's fast model
              'messages': [
                {
                  'role': 'user',
                  'content': prompt,
                }
              ],
              'temperature': 0.7,
              'max_tokens': 500,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final content = json['choices'][0]['message']['content'] as String;
        return content;
      } else {
        throw Exception('Groq API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to get AI recommendation: $e');
    }
  }

  /// Builds the prompt for Groq API
  String _buildPrompt({
    required String soilType,
    required double temperature,
    required int humidity,
    required double rainfall,
    required int currentMonth,
  }) {
    final monthName = _getMonthName(currentMonth);
    
    return '''You are an expert agricultural advisor for Indian farms. Based on the following soil and weather conditions, recommend the TOP 3 crops to plant this season.

Soil Type: $soilType
Current Temperature: ${temperature.toStringAsFixed(1)}°C
Humidity: $humidity%
Expected Rainfall: ${rainfall.toStringAsFixed(1)}mm
Current Month: $monthName

For each crop, provide:
1. Crop name
2. Why it's suitable (1-2 sentences)
3. Best planting time (specific months)
4. Key care tips (2-3 points)

Format your response as a numbered list. Be concise and practical.''';
  }

  /// Converts month number (1-12) to month name
  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  /// Test connection to Groq API
  Future<bool> testConnection() async {
    try {
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': 'mixtral-8x7b-32768',
              'messages': [
                {
                  'role': 'user',
                  'content': 'Say "OK" if you can read this.',
                }
              ],
              'max_tokens': 10,
            }),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
