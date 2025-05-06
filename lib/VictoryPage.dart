import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'game/game_screen.dart';

class VictoryPage extends StatefulWidget {
  final String difficulty;
  final int stars;
  final int score;
  final int level;

  const VictoryPage({
    super.key,
    required this.difficulty,
    this.stars = 3,
    required this.score,
    required this.level,
  });

  @override
  _VictoryPageState createState() => _VictoryPageState();
}

class _VictoryPageState extends State<VictoryPage>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _starsController;
  late Animation<double> _scaleAnimation;
  final random = math.Random();

  @override
  void initState() {
    super.initState();

    // Setup main animation
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: _mainController, curve: Curves.elasticOut));

    // Setup stars animation
    _starsController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Start animations
    _mainController.forward();
    Future.delayed(Duration(milliseconds: 300), () {
      _starsController.forward();
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _starsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.width < 600;
    final bool isVerySmallScreen = size.width < 400;

    // Calculate responsive sizes - adjusted to prevent overflow
    final containerWidth = isVerySmallScreen
        ? size.width * 0.9 // Increased to 90% for very small screens
        : (isSmallScreen ? size.width * 0.75 : 450.0); // Adjusted for better fit

    final iconSize = isVerySmallScreen ? 40.0 : (isSmallScreen ? 50.0 : 60.0); // Reduced sizes
    final titleFontSize =
    isVerySmallScreen ? 18.0 : (isSmallScreen ? 20.0 : 24.0);
    final starSize = isVerySmallScreen ? 20.0 : (isSmallScreen ? 24.0 : 28.0);

    // Calculate how many confetti particles to show based on screen size
    final confettiCount = isVerySmallScreen ? 15 : (isSmallScreen ? 25 : 40);

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
            // Static confetti - reduce count for smaller screens
            ...List.generate(confettiCount, (index) {
              return Positioned(
                top: random.nextDouble() * size.height,
                left: random.nextDouble() * size.width,
                child: Container(
                  width: 3 + random.nextInt(5).toDouble(),
                  height: 3 + random.nextInt(5).toDouble(),
                  color: [
                    Color(0xFFFFD700),
                    Color(0xFF7AC74C),
                    Color(0xFFFFFFFF),
                    Color(0xFF4C6229),
                  ][random.nextInt(4)],
                ),
              );
            }),

            // Dark overlay with vignette
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.5,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                  stops: [0.6, 1.0],
                ),
              ),
            ),

            // Content
            Center(
              child: Container(
                width: containerWidth,
                padding: EdgeInsets.all(
                    isVerySmallScreen ? 10 : (isSmallScreen ? 12 : 15)), // Reduced padding
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Color(0xFF7AC74C),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF7AC74C).withOpacity(0.6),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Trophy icon
                    Icon(
                      Icons.emoji_events,
                      size: iconSize,
                      color: Color(0xFFFFD700),
                    ),

                    SizedBox(height: isVerySmallScreen ? 4 : 10),

                    // Victory text with glow
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                          horizontal: isVerySmallScreen ? 4 : 10,
                          vertical: 6),
                      decoration: BoxDecoration(
                        color: Color(0xFF7AC74C).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF7AC74C).withOpacity(0.5),
                            blurRadius: 15,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'VICTORY!',
                          style: TextStyle(
                            fontFamily: 'Vip',
                            fontSize: titleFontSize,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            shadows: [
                              Shadow(
                                color: Color(0xFF7AC74C),
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
                    ),

                    SizedBox(height: isVerySmallScreen ? 4 : 10),

                    // Level info
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'LEVEL ${widget.level} COMPLETED',
                        style: TextStyle(
                          fontFamily: 'Vip',
                          fontSize: isVerySmallScreen ? 12 : 14,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),

                    SizedBox(height: 4),

                    // Score
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
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

                    SizedBox(height: 5),

                    // Stars
                    _buildStarsRow(starSize),

                    SizedBox(height: 8),

                    // Buttons row - use Expanded to prevent overflow
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 5),
                            child: _buildRetroButton(
                              label: 'RETRY',
                              icon: Icons.refresh,
                              color: Color(0xFFFFD700),
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => Scaffold(
                                      body: GameScreen(level: widget.level),
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
                              label: 'NEXT',
                              icon: Icons.arrow_forward,
                              color: Color(0xFF7AC74C),
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => Scaffold(
                                      body: GameScreen(level: widget.level + 1),
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
                                    context, (route) => route.isFirst);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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

  Widget _buildStarsRow(double starSize) {
    return AnimatedBuilder(
        animation: _starsController,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              // Staggered animation for each star
              final delay = index * 0.2;
              final starProgress = _starsController.value > delay
                  ? math.min(
                  1.0, (_starsController.value - delay) / (1.0 - delay))
                  : 0.0;

              final starOpacity = starProgress;
              final starScale = Curves.elasticOut.transform(starProgress);

              return Opacity(
                opacity: starOpacity,
                child: Transform.scale(
                  scale: starScale,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5.0),
                    child: Icon(
                      index < widget.stars ? Icons.star : Icons.star_border,
                      color: Color(0xFFFFD700),
                      size: starSize,
                    ),
                  ),
                ),
              );
            }),
          );
        });
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
          border: Border.all(
            color: color,
            width: 2,
          ),
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
                    colors: [
                      color.withOpacity(0.4),
                      Colors.transparent,
                    ],
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
                    size: 14, // Smaller icon
                  ),
                  SizedBox(width: 4), // Smaller gap
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Vip',
                      fontSize: 14, // Smaller text
                      color: color,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8, // Reduced letter spacing
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