import 'package:flutter/material.dart';
import 'dart:math';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final Color _oliveGreen = const Color(0xFF556B2F);
  final Color _lightOlive = Color(0xFF6B8E23);
  final Color _darkOlive = Color(0xFF2F4F2F);

  int _currentDot = 0;
  double _iconOffset = 0.0;
  late List<FloatingElement> _floatingElements;

  @override
  void initState() {
    super.initState();
    _initializeFloatingElements();
    _startAnimations();
  }

  void _initializeFloatingElements() {
    _floatingElements = [
      FloatingElement(size: 40, x: 0.1, y: 0.2, speed: 1.2),
      FloatingElement(size: 25, x: 0.8, y: 0.4, speed: 0.8),
      FloatingElement(size: 35, x: 0.2, y: 0.7, speed: 1.0),
      FloatingElement(size: 30, x: 0.7, y: 0.1, speed: 1.1),
      FloatingElement(size: 20, x: 0.9, y: 0.8, speed: 0.9),
      FloatingElement(size: 28, x: 0.3, y: 0.9, speed: 1.3),
    ];
  }

  void _startAnimations() {
    // Icon floating animation
    _startIconAnimation();

    // Dot animation
    _startDotAnimation();

    // Floating elements animation
    _animateFloatingElements();
  }

  void _startIconAnimation() {
    Future.delayed(Duration.zero, () {
      _animateIcon();
    });
  }

  void _animateIcon() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _iconOffset = -10.0;
        });

        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            setState(() {
              _iconOffset = 0.0;
            });
            // Continue the animation loop
            _animateIcon();
          }
        });
      }
    });
  }

  void _startDotAnimation() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _currentDot = (_currentDot + 1) % 3;
        });
        _startDotAnimation();
      }
    });
  }

  void _animateFloatingElements() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        setState(() {
          for (var element in _floatingElements) {
            element.animate();
          }
        });
        _animateFloatingElements();
      }
    });
  }

  void _navigateToLogin() {
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Radial Gradient Background
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topLeft,
                radius: 1.5,
                colors: [
                  _darkOlive.withOpacity(0.9),
                  _oliveGreen.withOpacity(0.8),
                  _darkOlive,
                ],
                stops: [0.1, 0.5, 1.0],
              ),
            ),
          ),

          // Geometric Pattern Overlay
          _buildGeometricPattern(),

          // Floating Elements
          ..._floatingElements.map((element) => _buildFloatingElement(element)),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Animated Icon
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeInOut,
                          transform: Matrix4.translationValues(0, _iconOffset, 0),
                          child: Image.asset(
                            'assets/images/brain1.png',
                            width: 120,
                            height: 120,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 30),

                        // App Name
                        const Text(
                          'EmotionAI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // App Tagline
                        const Text(
                          'Understanding Your Emotions',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Dot Loader
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (index) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _currentDot == index
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                            );
                          }),
                        ),
                        // const SizedBox(height: 20),
                        //
                        // // Loading Text
                        // Text(
                        //   'Loading${List.filled(_currentDot + 1, '.').join()}',
                        //   style: TextStyle(
                        //     color: Colors.white.withOpacity(0.8),
                        //     fontSize: 14,
                        //   ),
                        // ),
                      ],
                    ),
                  ),
                ),

                // Bottom Section with Get Started Button
                Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: Column(
                    children: [
                      // Get Started Button with Gradient Border
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF667F35),
                              Color(0xFF8A9A5B),
                              Color(0xFF667F35),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(2), // Border width
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ElevatedButton(
                            onPressed: _navigateToLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: _oliveGreen,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Get Started',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Powered by text
                      const Text(
                        'Powered by Emotions AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeometricPattern() {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.1,
        child: CustomPaint(
          size: Size.infinite,
          painter: GeometricPatternPainter(),
        ),
      ),
    );
  }

  Widget _buildFloatingElement(FloatingElement element) {
    return Positioned(
      left: element.x * MediaQuery.of(context).size.width,
      top: element.y * MediaQuery.of(context).size.height,
      child: Opacity(
        opacity: element.opacity,
        child: Container(
          width: element.size,
          height: element.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.white.withOpacity(0.3),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GeometricPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw grid pattern
    final spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw circles at intersections
    final circlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (double x = 0; x < size.width; x += spacing * 2) {
      for (double y = 0; y < size.height; y += spacing * 2) {
        canvas.drawCircle(Offset(x, y), 2, circlePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class FloatingElement {
  double x;
  double y;
  final double size;
  final double speed;
  double opacity = 0.6;
  double _direction = 1.0;
  final double _amplitude = 0.02;
  final Random _random = Random();

  FloatingElement({
    required this.size,
    required this.x,
    required this.y,
    required this.speed,
  });

  void animate() {
    // Move in a gentle floating motion
    y += _direction * _amplitude * speed;

    // Change direction when reaching bounds
    if (y > 1.0 || y < 0.0) {
      _direction *= -1;
    }

    // Pulsating opacity using sine wave
    final time = DateTime.now().millisecondsSinceEpoch * 0.001 * speed;
    opacity = 0.3 + 0.4 * (0.5 + 0.5 * sin(time));

    // Add some random horizontal movement for more natural floating
    x += (_random.nextDouble() - 0.5) * 0.005 * speed;
    x = x.clamp(0.0, 1.0);
  }
}