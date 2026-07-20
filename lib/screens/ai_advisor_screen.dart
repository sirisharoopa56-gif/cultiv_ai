import 'package:flutter/material.dart';
import '../services/location_service.dart';
import '../services/soil_type_service.dart';
import '../services/weather_service.dart';
import '../services/crop_recommendation_engine.dart';

/// Screen for AI-powered crop recommendations based on location, soil, and weather.
/// Automatically detects location and fetches soil/weather data for smart recommendations.
class AIAdvisorScreen extends StatefulWidget {
  const AIAdvisorScreen({super.key});

  @override
  State<AIAdvisorScreen> createState() => _AIAdvisorScreenState();
}

class _AIAdvisorScreenState extends State<AIAdvisorScreen> {
  List<CropRecommendation>? _recommendations;
  String? _location;
  String? _soilType;
  String? _weather;
  String? _aiRecommendation;
  bool _isLoading = false;
  String? _errorMessage;
  bool _groqAvailable = false;

  @override
  void initState() {
    super.initState();
    _fetchRecommendations();
  }

  /// Main flow: Get location → Fetch soil → Fetch weather → Generate recommendations
  Future<void> _fetchRecommendations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _aiRecommendation = null;
      _groqAvailable = false;
    });

    try {
      // Step 1: Get user's location
      final locationService = LocationService();
      final position = await locationService.getCurrentLocation();
      final placeName = await locationService.getPlaceName(position.latitude, position.longitude);

      // Step 2: Detect soil type using SoilGrids (with AI fallback)
      final soilService = SoilTypeService();
      final soilData = await soilService.detectSoil(position.latitude, position.longitude);

      // Step 3: Fetch weather data
      final weatherService = WeatherService();
      final weatherData = await weatherService.getWeather(position.latitude, position.longitude);

      // Step 4: Generate crop recommendations from local database
      final engine = CropRecommendationEngine();
      final recommendations = engine.generateRecommendations(
        soil: soilData,
        weather: weatherData,
      );

      // Step 5: Get AI-enhanced recommendation from Groq (optional, non-blocking)
      String? aiRec;
      bool groqOk = false;
      try {
        aiRec = await engine.getAIEnhancedRecommendation(
          soil: soilData,
          weather: weatherData,
        );
        if (aiRec != null && aiRec.isNotEmpty) {
          groqOk = true;
        }
      } catch (e) {
        // Groq is optional, continue without it
      }

      if (mounted) {
        setState(() {
          _location = placeName;
          _soilType = '${soilData.soilType} (${soilData.detectionMethod})';
          _weather = '${weatherData.temperature.toStringAsFixed(1)}°C, '
              '${weatherData.humidity}% humidity, '
              '${weatherData.condition}';
          _recommendations = recommendations.isEmpty ? [] : recommendations;
          _aiRecommendation = aiRec;
          _groqAvailable = groqOk;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetchRecommendations,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI Crop Advisor',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            const SizedBox(height: 8),
            const Text(
              'Uses your location to detect soil type and weather for smart recommendations.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorMessage != null)
              _buildErrorCard(_errorMessage!)
            else if (_recommendations != null)
              _buildRecommendationsView()
            else
              ElevatedButton.icon(
                onPressed: _fetchRecommendations,
                icon: const Icon(Icons.refresh),
                label: const Text('Load Recommendations'),
              ),
          ],
        ),
      ),
    );
  }

  /// Builds the full recommendations view with location, soil, and weather info.
  Widget _buildRecommendationsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Location & Soil & Weather Summary
        _buildInfoCard(),
        const SizedBox(height: 24),

        // AI Recommendation from Groq (if available)
        if (_groqAvailable && _aiRecommendation != null) ...[
          _buildGroqRecommendationCard(),
          const SizedBox(height: 24),
        ],

        // Crop Recommendations
        const Text(
          'Recommended Crops',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color : Colors.green),
        ),
        const SizedBox(height: 12),
        if (_recommendations!.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No crops matched current conditions. Try adjusting location or checking weather.',
              ),
            ),
          )
        else
          ..._recommendations!.map((crop) => _buildCropCard(crop)),
      ],
    );
  }

  /// Builds the Groq AI recommendation card.
  Widget _buildGroqRecommendationCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.blue, size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'AI-Powered Recommendations',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _aiRecommendation ?? 'Loading...',
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the info card showing location, soil, and weather.
  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(Icons.location_on, 'Location', _location ?? 'Detecting...'),
            const Divider(),
            _buildInfoRow(Icons.terrain, 'Soil Type', _soilType ?? 'Analyzing...'),
            const Divider(),
            _buildInfoRow(Icons.cloud, 'Weather', _weather ?? 'Fetching...'),
          ],
        ),
      ),
    );
  }

  /// Builds a single info row.
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.green, size: 24),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  /// Builds a single crop recommendation card.
  Widget _buildCropCard(CropRecommendation crop) {
    final isInSeason = CropRecommendationEngine.isInBestSeason(crop);
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Crop name and confidence score
            Row(
              children: [
                Expanded(
                  child: Text(
                    crop.cropName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getConfidenceColor(crop.confidenceScore),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${(crop.confidenceScore * 100).toStringAsFixed(0)}% match',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Reason
            Text(
              crop.reason,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 12),

            // Best months
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Best months: ${crop.bestMonths.map((m) => monthNames[m - 1]).join(', ')}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
                if (isInSeason)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'In Season Now!',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Tips
            ...crop.tips.map((tip) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(child: Text(tip, style: const TextStyle(fontSize: 13))),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  /// Builds error card.
  Widget _buildErrorCard(String error) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    error,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _fetchRecommendations,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns color based on confidence score.
  Color _getConfidenceColor(double score) {
    if (score >= 0.85) return Colors.green;
    if (score >= 0.70) return Colors.orangeAccent;
    return Colors.grey;
  }
}