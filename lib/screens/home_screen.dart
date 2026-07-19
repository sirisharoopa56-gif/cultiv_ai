import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'ai_advisor_screen.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';

/// Dashboard screen showing current weather and farm stats.
/// Loads real farm data from Hive and location-based information.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Box<dynamic> _plotsBox;
  int _activePlots = 0;
  WeatherData? _weatherData;
  String _locationName = 'Detecting...';
  bool _weatherLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFarmStats();
    _loadWeather();
  }

  /// Load farm plot count from Hive.
  Future<void> _loadFarmStats() async {
    try {
      _plotsBox = await Hive.openBox('crop_plots');
      if (mounted) {
        setState(() {
          _activePlots = _plotsBox.length;
        });
      }
    } catch (e) {
      // If Hive isn't ready, show 0
      if (mounted) {
        setState(() {
          _activePlots = 0;
        });
      }
    }
  }

  /// Load real weather data and location.
  Future<void> _loadWeather() async {
    try {
      final locationService = LocationService();
      final pos = await locationService.getCurrentLocation();
      final place = await locationService.getPlaceName(pos.latitude, pos.longitude);
      final weather = await WeatherService().getWeather(pos.latitude, pos.longitude);

      if (mounted) {
        setState(() {
          _weatherData = weather;
          _locationName = place;
          _weatherLoading = false;
        });
      }
    } catch (e) {
      // Fallback to mock data if location/weather fetch fails
      if (mounted) {
        setState(() {
          _weatherData = WeatherService.getMockWeatherData();
          _locationName = 'Location unavailable';
          _weatherLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current Weather',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildWeatherCard(context),
          const SizedBox(height: 24),
          const Text(
            'Quick Stats',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildQuickStatsRow(),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AIAdvisorScreen(),
                ),
              );
            },
            icon: const Icon(Icons.smart_toy),
            label: const Text('Get Crop Recommendations'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                final pos = await LocationService().getCurrentLocation();
                final place = await LocationService()
                    .getPlaceName(pos.latitude, pos.longitude);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Detected: $place (${pos.latitude}, ${pos.longitude})'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            icon: const Icon(Icons.my_location),
            label: const Text('Test Location Detection'),
          ),
        ],
      ),
    );
  }

  IconData _getWeatherIcon(String condition) {
    if (condition.toLowerCase().contains('rain')) return Icons.cloud_queue;
    if (condition.toLowerCase().contains('cloud')) return Icons.wb_cloudy;
    if (condition.toLowerCase().contains('sunny') || condition.toLowerCase().contains('clear')) return Icons.wb_sunny;
    if (condition.toLowerCase().contains('fog')) return Icons.cloud;
    if (condition.toLowerCase().contains('snow')) return Icons.ac_unit;
    if (condition.toLowerCase().contains('storm')) return Icons.flash_on;
    return Icons.wb_sunny;
  }

  Widget _buildWeatherCard(BuildContext context) {
    if (_weatherLoading) {
      return Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }

    final weather = _weatherData ?? WeatherService.getMockWeatherData();
    final icon = _getWeatherIcon(weather.condition);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 48, color: Colors.orange),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${weather.temperature.toStringAsFixed(1)}°C — ${weather.condition}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text('Humidity: ${weather.humidity}%  •  Wind: ${weather.windSpeed.toStringAsFixed(1)} km/h'),
                Text(_locationName, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatsRow() {
    return Row(
      children: [
        Expanded(child: _statCard('Soil Moisture', '54%', Icons.water_drop)),
        const SizedBox(width: 12),
        Expanded(child: _statCard('Active Plots', '$_activePlots', Icons.grid_view)),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.green),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}