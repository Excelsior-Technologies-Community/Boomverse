import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game/game_screen.dart';

class GameLostPage extends StatefulWidget {
  final String difficulty;
  final int score;
  final int level;

  const GameLostPage({
    super.key,
    required this.difficulty,
    required this.score,
    required this.level,
  });

  @override
  _GameLostPageState createState() => _GameLostPageState();
}

class _GameLostPageState extends State<GameLostPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Setup animations
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.width < 600;
    final bool isVerySmallScreen = size.width < 400;

    // Calculate responsive sizes - adjusted to prevent overflow
    final containerWidth =
        isVerySmallScreen
            ? size.width *
                0.9 // Increased to 90% for very small screens
            : (isSmallScreen ? size.width * 0.75 : 400.0);

    final iconSize = isVerySmallScreen ? 40.0 : (isSmallScreen ? 50.0 : 60.0);
    final titleFontSize =
        isVerySmallScreen ? 18.0 : (isSmallScreen ? 20.0 : 24.0);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          fit: StackFit.expand, // Ensures stack takes all available space
          children: [
            // Dark overlay with scanlines
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withOpacity(0.7),
              child: CustomPaint(painter: ScanlinePainter(), size: size),
            ),

            // Content - static layout
            Center(
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: containerWidth,
                  padding: EdgeInsets.all(
                    isVerySmallScreen ? 10 : (isSmallScreen ? 12 : 15),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFE74C3C),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFE74C3C).withOpacity(0.6),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Game over icon
                      Icon(
                        Icons.warning_amber_rounded,
                        size: iconSize,
                        color: Color(0xFFE74C3C),
                      ),

                      SizedBox(height: isVerySmallScreen ? 4 : 10),

                      // Game Over text with animated glow
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          return Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: isVerySmallScreen ? 4 : 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Color(0xFFE74C3C).withOpacity(
                                0.3 +
                                    0.2 *
                                        (0.5 +
                                            0.5 *
                                                sin(_controller.value * 6.28)),
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFFE74C3C).withOpacity(
                                    0.3 +
                                        0.4 *
                                            (0.5 +
                                                0.5 *
                                                    sin(
                                                      _controller.value * 6.28,
                                                    )),
                                  ),
                                  blurRadius: 15,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'GAME OVER',
                                style: TextStyle(
                                  fontFamily: 'Vip',
                                  fontSize: titleFontSize,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                  shadows: [
                                    Shadow(
                                      color: Color(0xFFE74C3C),
                                      offset: Offset(0, 2),
                                      blurRadius: 7,
                                    ),
                                    Shadow(
                                      color: Colors.black,
                                      offset: Offset(2, 2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      SizedBox(height: isVerySmallScreen ? 4 : 10),

                      // Score
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Color(0xFFFFD700).withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.attach_money,
                              color: Color(0xFFFFD700),
                              size: 16,
                            ),
                            SizedBox(width: 2),
                            Text(
                              '${widget.score}',
                              style: TextStyle(
                                fontFamily: 'Vip',
                                fontSize: isVerySmallScreen ? 12 : 14,
                                color: Color(0xFFFFD700),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isVerySmallScreen ? 4 : 6),

                      // Level info
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'LEVEL ${widget.level}',
                          style: TextStyle(
                            fontFamily: 'Vip',
                            fontSize: isVerySmallScreen ? 12 : 14,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),

                      SizedBox(height: isVerySmallScreen ? 8 : 10),

                      // Buttons row - use Expanded to prevent overflow and ensure spacing
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 5),
                              child: _buildRetroButton(
                                label: 'RETRY',
                                icon: Icons.refresh,
                                color: Color(0xFFE74C3C),
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => Scaffold(
                                            body: GameScreen(
                                              level: widget.level,
                                            ),
                                          ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 5),
                              child: _buildRetroButton(
                                label: 'HOME',
                                icon: Icons.home,
                                color: Colors.white.withOpacity(0.7),
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  Navigator.popUntil(
                                    context,
                                    (route) => route.isFirst,
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: isVerySmallScreen ? 8 : 10),

                      // Hint text
                      Text(
                        'DON\'T GIVE UP!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Vip',
                          fontSize: isVerySmallScreen ? 10 : 12,
                          color: Colors.white.withOpacity(0.7),
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Logo at bottom left - smaller and positioned closer to edge
            Positioned(
              bottom: 5,
              left: 5,
              child: Image.asset(
                'assets/images/BlasterMan.png',
                width: isVerySmallScreen ? 50 : (isSmallScreen ? 70 : 80),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRetroButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40, // Reduced height
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.5),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Button highlight
            Positioned(
              top: 2,
              left: 2,
              right: 2,
              height: 12,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [color.withOpacity(0.4), Colors.transparent],
                  ),
                ),
              ),
            ),

            // Button content
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: color,
                    size: 16, // Smaller icon
                  ),
                  SizedBox(width: 5), // Smaller gap
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Vip',
                      fontSize: 16,
                      color: color,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0, // Reduced letter spacing
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for CRT scanlines - with improved performance
class ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.black.withOpacity(0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;

    // Draw fewer lines on small screens
    final lineSpacing = size.width < 500 ? 8.0 : 6.0;
    for (double y = 0; y < size.height; y += lineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
