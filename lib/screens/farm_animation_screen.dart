// lib/screens/farm_animation_screen.dart

import 'package:flutter/material.dart';

/// A decorative, farm-themed animated scene — sun moving across the sky,
/// drifting clouds, occasional rain, and a crop growing from seed to
/// full plant. Purely visual, no data dependencies, so it always works
/// even offline — good as a fun "about" or loading-adjacent page.
class FarmAnimationScreen extends StatefulWidget {
  const FarmAnimationScreen({super.key});

  @override
  State<FarmAnimationScreen> createState() => _FarmAnimationScreenState();
}

class _FarmAnimationScreenState extends State<FarmAnimationScreen>
    with TickerProviderStateMixin {
  late final AnimationController _sunController;
  late final AnimationController _cloudController;
  late final AnimationController _growController;
  late final AnimationController _rainController;

  @override
  void initState() {
    super.initState();

    _sunController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _cloudController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    _growController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: false);
    _growController.repeat(period: const Duration(seconds: 6));

    _rainController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _sunController.dispose();
    _cloudController.dispose();
    _growController.dispose();
    _rainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Sky gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF87CEEB), Color(0xFFE0F7E0)],
                stops: [0.0, 0.6],
              ),
            ),
          ),

          // Sun arcing across the sky
          AnimatedBuilder(
            animation: _sunController,
            builder: (context, child) {
              final width = MediaQuery.of(context).size.width;
              final t = _sunController.value; // 0..1
              final x = width * t;
              final y = 80 + 40 * (1 - (2 * t - 1).abs()); // simple arc
              return Positioned(
                left: x - 30,
                top: y,
                child: child!,
              );
            },
            child: const Icon(Icons.wb_sunny, size: 60, color: Colors.orangeAccent),
          ),

          // Drifting clouds (two, offset)
          _buildDriftingCloud(topOffset: 60, sizeFactor: 1.0, delay: 0.0),
          _buildDriftingCloud(topOffset: 130, sizeFactor: 0.7, delay: 0.4),

          // Occasional rain drops falling
          AnimatedBuilder(
            animation: _rainController,
            builder: (context, child) {
              return CustomPaint(
                size: Size(MediaQuery.of(context).size.width, 250),
                painter: _RainPainter(progress: _rainController.value),
              );
            },
          ),

          // Growing crop, bottom center
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 60),
              child: AnimatedBuilder(
                animation: _growController,
                builder: (context, child) {
                  final t = _growController.value; // 0..1, loops
                  return _buildGrowingCrop(t);
                },
              ),
            ),
          ),

          // Ground
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 60,
              width: double.infinity,
              color: const Color(0xFF8D6E63),
            ),
          ),

          // Title overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Growing with you 🌱',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriftingCloud({required double topOffset, required double sizeFactor, required double delay}) {
    return AnimatedBuilder(
      animation: _cloudController,
      builder: (context, child) {
        final width = MediaQuery.of(context).size.width;
        var t = (_cloudController.value + delay) % 1.0;
        final x = -100 + (width + 200) * t;
        return Positioned(
          left: x,
          top: topOffset,
          child: Opacity(
            opacity: 0.85,
            child: Icon(Icons.cloud, size: 70 * sizeFactor, color: Colors.white),
          ),
        );
      },
    );
  }

  /// Grows a simple sprout: stem gets taller, then leaves fade in,
  /// looping back to a seed once fully grown.
  Widget _buildGrowingCrop(double t) {
    final stemHeight = 20 + 100 * (t < 0.7 ? (t / 0.7) : 1.0);
    final leafOpacity = t < 0.4 ? 0.0 : ((t - 0.4) / 0.3).clamp(0.0, 1.0);

    return SizedBox(
      height: 140,
      width: 120,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Stem
          Container(
            width: 6,
            height: stemHeight,
            decoration: BoxDecoration(
              color: Colors.green.shade700,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          // Leaves, fade in once stem is tall enough
          Positioned(
            bottom: stemHeight * 0.6,
            child: Opacity(
              opacity: leafOpacity,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.eco, color: Colors.green.shade600, size: 28),
                  const SizedBox(width: 4),
                  Icon(Icons.eco, color: Colors.green.shade400, size: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lightweight rain-drop painter — a handful of falling lines that
/// loop continuously. Purely decorative.
class _RainPainter extends CustomPainter {
  final double progress;
  _RainPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.lightBlue.withOpacity(0.4)
      ..strokeWidth = 2;

    const dropCount = 14;
    for (int i = 0; i < dropCount; i++) {
      final xSeed = (i * 37) % 100 / 100.0;
      final x = xSeed * size.width;
      final yStart = ((progress + i * 0.15) % 1.0) * size.height;
      canvas.drawLine(Offset(x, yStart), Offset(x, yStart + 12), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RainPainter oldDelegate) => true;
}