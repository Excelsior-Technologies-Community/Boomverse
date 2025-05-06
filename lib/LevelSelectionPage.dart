import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game/game_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class LevelSelectionPage extends StatefulWidget {
  const LevelSelectionPage({super.key});

  @override
  _LevelSelectionPageState createState() => _LevelSelectionPageState();
}

class _LevelSelectionPageState extends State<LevelSelectionPage>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  final random = math.Random();

  // Player progress data
  int highestUnlockedLevel = 1;
  Map<String, int> levelStars = {};
  int playerCoins = 0;
  int playerKeys = 0;
  int playerTreasures = 0;
  bool isLoading = true;

  // Firebase references
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  @override
  void initState() {
    super.initState();

    // Setup animations
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.elasticOut),
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start animations
    _mainController.forward();

    // Load player data
    _loadPlayerData();
  }

  Future<void> _loadPlayerData() async {
    final prefs = await SharedPreferences.getInstance();

    // First try loading from SharedPreferences for faster initial display
    if (prefs.containsKey('highestLevel')) {
      setState(() {
        highestUnlockedLevel = prefs.getInt('highestLevel') ?? 1;
        playerCoins = prefs.getInt('coins') ?? 0;
        playerKeys = prefs.getInt('keys') ?? 0;
        playerTreasures = prefs.getInt('treasures') ?? 0;
      });
    }

    // Then load from Firebase for the most up-to-date data
    final User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      final uid = currentUser.uid;
      final DatabaseReference userRef = _database
          .ref()
          .child('users')
          .child(uid);

      try {
        final DatabaseEvent event = await userRef.once();
        final DataSnapshot snapshot = event.snapshot;

        if (snapshot.exists) {
          final data = snapshot.value as Map<dynamic, dynamic>;
          final userData = Map<String, dynamic>.from(data);

          setState(() {
            highestUnlockedLevel = userData['level'] ?? 1;
            playerCoins = userData['coins'] ?? 0;
            playerKeys = userData['key'] ?? 0;
            playerTreasures = userData['treasure'] ?? 0;

            if (userData.containsKey('levels') && userData['levels'] is List) {
              final levelsList = userData['levels'] as List<dynamic>;
              levelStars = {};
              for (int i = 1; i < levelsList.length; i++) {
                if (levelsList[i] != null) {
                  levelStars[i.toString()] =
                      levelsList[i] is int
                          ? levelsList[i]
                          : int.tryParse(levelsList[i]?.toString() ?? '0') ?? 0;
                }
              }
            }

            isLoading = false;
          });

          // Save the latest data to SharedPreferences
          await prefs.setInt('highestLevel', highestUnlockedLevel);
          await prefs.setInt('coins', playerCoins);
          await prefs.setInt('keys', playerKeys);
          await prefs.setInt('treasures', playerTreasures);
        }
      } catch (e) {
        print('Error loading player data: $e');
      }
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // Launch the selected level
  void _startLevel(int level) {
    if (level <= highestUnlockedLevel) {
      HapticFeedback.mediumImpact();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(body: GameScreen(level: level)),
        ),
      );
    } else {
      // Level locked feedback
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Complete level ${level - 1} to unlock this level!',
            style: TextStyle(fontFamily: 'Vip'),
          ),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Build a level button with appropriate styling based on unlock status
  Widget _buildLevelButton(int level) {
    final bool isUnlocked = level <= highestUnlockedLevel;
    final int stars = levelStars[level.toString()] ?? 0;

    // Define level features for display
    String difficulty = 'Easy';
    String enemyBehavior = 'Basic';
    bool hasCollectibles = false;
    int enemyCount = 1; // Start with 1 enemy

    // Set difficulty and features based on level
    if (level > 15) {
      difficulty = 'Very Hard';
      enemyBehavior = 'Advanced A*';
      hasCollectibles = true;
      enemyCount = 4 + (level - 15);
    } else if (level > 10) {
      difficulty = 'Hard';
      enemyBehavior = 'A* Pathfinding';
      hasCollectibles = true;
      enemyCount = 3 + (level - 10) ~/ 2;
    } else if (level > 5) {
      difficulty = 'Medium';
      enemyBehavior = 'Advanced';
      hasCollectibles = level > 8;
      enemyCount = 2 + (level - 5) ~/ 2;
    } else {
      // Levels 1-5 are easy
      enemyCount = level <= 2 ? 1 : 1 + (level - 2);
    }

    // Game description based on level features
    String gameDescription = '';
    if (level > 10) {
      gameDescription = "A* pathfinding enemies";
    } else if (level > 5) {
      gameDescription = "Advanced enemies";
    } else {
      gameDescription = "Basic enemies";
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: () => _startLevel(level),
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            // Make the highest unlocked level pulse to guide the player
            final shouldPulse = level == highestUnlockedLevel;

            return Transform.scale(
              scale: shouldPulse ? _pulseAnimation.value : 1.0,
              child: Container(
                width:
                    double
                        .infinity, // Let the parent's constraints determine width
                padding: EdgeInsets.all(6), // Reduced from 8
                decoration: BoxDecoration(
                  color: isUnlocked ? Colors.black54 : Colors.black87,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        isUnlocked
                            ? Color(0xFF7AC74C)
                            : Colors.grey.withOpacity(0.5),
                    width: 2,
                  ),
                  boxShadow:
                      isUnlocked
                          ? [
                            BoxShadow(
                              color: Color(0xFF7AC74C).withOpacity(0.4),
                              blurRadius: 8, // Reduced from 10
                              spreadRadius: 1,
                            ),
                          ]
                          : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Level number
                    Text(
                      'LVL $level',
                      style: TextStyle(
                        fontFamily: 'Vip',
                        fontSize: 13, // Reduced from 15
                        color: isUnlocked ? Colors.white : Colors.grey,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5, // Reduced from 1.0
                        shadows: [
                          Shadow(
                            color:
                                isUnlocked ? Color(0xFF7AC74C) : Colors.black,
                            offset: Offset(0, 1), // Reduced offset
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 3), // Reduced from 5
                    // Difficulty tag
                    Container(
                      margin: EdgeInsets.only(top: 3),
                      padding: EdgeInsets.symmetric(vertical: 2, horizontal: 5),
                      decoration: BoxDecoration(
                        color: _getDifficultyColor(difficulty).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getDifficultyColor(
                            difficulty,
                          ).withOpacity(0.7),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        difficulty,
                        style: TextStyle(
                          fontSize: 8,
                          color: isUnlocked ? Colors.white : Colors.grey,
                        ),
                      ),
                    ),

                    SizedBox(height: 2), // Reduced from 4
                    // Enemies count badge
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ), // Reduced padding
                      decoration: BoxDecoration(
                        color:
                            isUnlocked
                                ? Colors.black38
                                : Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(
                          6,
                        ), // Reduced radius
                      ),
                      child: Text(
                        '$enemyCount Enemy',
                        style: TextStyle(
                          fontFamily: 'Vip',
                          fontSize: 8, // Reduced from 10
                          color: isUnlocked ? Colors.white : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    SizedBox(height: 2), // Reduced from 4
                    // Stars display
                    if (isUnlocked && stars > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (index) {
                          return Icon(
                            index < stars ? Icons.star : Icons.star_border,
                            color:
                                index < stars ? Color(0xFFFFD700) : Colors.grey,
                            size: 10, // Reduced from 14
                          );
                        }),
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (index) {
                          return Icon(
                            Icons.star_border,
                            color: Colors.grey.withOpacity(0.5),
                            size: 10, // Reduced from 14
                          );
                        }),
                      ),

                    // Lock icon for locked levels
                    if (!isUnlocked)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 2.0,
                        ), // Reduced from 4
                        child: Icon(
                          Icons.lock,
                          color: Colors.grey,
                          size: 12, // Reduced from 16
                        ),
                      ),

                    // Features
                    if (hasCollectibles)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/treasure.png',
                              width: 12,
                              height: 12,
                            ),
                            SizedBox(width: 3),
                            Image.asset(
                              'assets/images/key.png',
                              width: 12,
                              height: 12,
                            ),
                          ],
                        ),
                      ),

                    // Game description
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        gameDescription,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 8,
                          color:
                              isUnlocked
                                  ? Colors.white70
                                  : Colors.grey.withOpacity(0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Helper function to get color based on difficulty
  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'Easy':
        return Color(0xFF7AC74C); // Green
      case 'Medium':
        return Color(0xFFFFA500); // Orange
      case 'Hard':
        return Color(0xFFFF7F00); // Darker Orange
      case 'Very Hard':
        return Color(0xFFE74C3C); // Red
      default:
        return Color(0xFF7AC74C);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final isWebPlatform = kIsWeb;

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
        child: SafeArea(
          child:
              isLoading
                  ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isWebPlatform ? Color(0xFFD1A758) : Color(0xFF7AC74C),
                      ),
                    ),
                  )
                  : Column(
                    children: [
                      // Header with title and player stats
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Back button
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).pop();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color:
                                      isWebPlatform
                                          ? const Color(
                                            0xFF2D2B39,
                                          ).withOpacity(0.85)
                                          : Colors.black54,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color:
                                        isWebPlatform
                                            ? const Color(0xFFD1A758)
                                            : const Color(0xFF7AC74C),
                                    width: isWebPlatform ? 2 : 1,
                                  ),
                                ),
                                child: Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),

                            // Title
                            Text(
                              'SELECT LEVEL',
                              style: TextStyle(
                                fontFamily: 'Vip',
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 2,
                                shadows: [
                                  Shadow(
                                    color:
                                        isWebPlatform
                                            ? const Color(0xFFD1A758)
                                            : const Color(0xFF7AC74C),
                                    offset: const Offset(0, 2),
                                    blurRadius: 5,
                                  ),
                                ],
                              ),
                            ),

                            // Player stats
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isWebPlatform
                                        ? const Color(
                                          0xFF2D2B39,
                                        ).withOpacity(0.85)
                                        : Colors.black54,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color:
                                      isWebPlatform
                                          ? const Color(0xFFD1A758)
                                          : Colors.white30,
                                  width: isWebPlatform ? 2 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        isWebPlatform
                                            ? const Color(
                                              0xFFD1A758,
                                            ).withOpacity(0.2)
                                            : const Color(
                                              0xFF7AC74C,
                                            ).withOpacity(0.2),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  // Coins
                                  Row(
                                    children: [
                                      Image.asset(
                                        'assets/images/coin.png',
                                        width: 24,
                                        height: 24,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        '$playerCoins',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  // Keys
                                  Row(
                                    children: [
                                      Image.asset(
                                        'assets/images/key.png',
                                        width: 22,
                                        height: 22,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        '$playerKeys',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  // Treasures
                                  Row(
                                    children: [
                                      Image.asset(
                                        'assets/images/treasure.png',
                                        width: 22,
                                        height: 22,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        '$playerTreasures',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Level grid - different layout for mobile and web
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 10,
                          ),
                          child:
                              isWebPlatform
                                  ? _buildWebLevelGrid(context, size)
                                  : _buildMobileLevelGrid(context),
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }

  // Original mobile grid layout - preserved
  Widget _buildMobileLevelGrid(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    // Determine the optimal crossAxisCount based on screen width
    int crossAxisCount = 5;
    if (size.width < 600) {
      crossAxisCount = 4;
    }

    return GridView.builder(
      padding: EdgeInsets.all(10),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 20, // Show 20 levels
      itemBuilder: (context, index) {
        final level = index + 1;
        return _buildLevelButton(level);
      },
    );
  }

  // New web-specific grid with enhanced visuals and information
  Widget _buildWebLevelGrid(BuildContext context, Size size) {
    return GridView.builder(
      padding: EdgeInsets.all(15),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.1,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: 20, // Show 20 levels
      itemBuilder: (context, index) {
        final level = index + 1;
        return _buildWebLevelCard(level);
      },
    );
  }

  // Enhanced level card for web
  Widget _buildWebLevelCard(int level) {
    final bool isUnlocked = level <= highestUnlockedLevel;
    final int stars = levelStars[level.toString()] ?? 0;

    // Define level features for display
    String difficulty = 'Easy';
    String enemyBehavior = 'Basic';
    bool hasCollectibles = false;
    int enemyCount = 1; // Start with 1 enemy

    // Set difficulty and features based on level
    if (level > 15) {
      difficulty = 'Very Hard';
      enemyBehavior = 'Advanced A*';
      hasCollectibles = true;
      enemyCount = 4 + (level - 15);
    } else if (level > 10) {
      difficulty = 'Hard';
      enemyBehavior = 'A* Pathfinding';
      hasCollectibles = true;
      enemyCount = 3 + (level - 10) ~/ 2;
    } else if (level > 5) {
      difficulty = 'Medium';
      enemyBehavior = 'Advanced';
      hasCollectibles = level > 8;
      enemyCount = 2 + (level - 5) ~/ 2;
    } else {
      // Levels 1-5 are easy
      enemyCount = level <= 2 ? 1 : 1 + (level - 2);
    }

    // Game description based on level features
    String gameDescription = '';
    if (level > 10) {
      gameDescription =
          "Enemies use A* pathfinding to chase you efficiently. Be strategic with your bombs!";
    } else if (level > 5) {
      gameDescription =
          "Enemies use advanced movement to navigate around obstacles. Watch your back!";
    } else {
      gameDescription =
          "Enemies use basic movement patterns. Good for learning the game mechanics.";
    }

    if (hasCollectibles) {
      gameDescription += " Collect keys and treasures for bonus points!";
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: () => _startLevel(level),
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            // Make the highest unlocked level pulse to guide the player
            final shouldPulse = level == highestUnlockedLevel;

            return Transform.scale(
              scale: shouldPulse ? _pulseAnimation.value : 1.0,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2D2B39).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color:
                        isUnlocked
                            ? Color(0xFFD1A758)
                            : Colors.grey.withOpacity(0.5),
                    width: 2,
                  ),
                  boxShadow:
                      isUnlocked
                          ? [
                            BoxShadow(
                              color: Color(0xFFD1A758).withOpacity(0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ]
                          : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Stack(
                    children: [
                      // Background - shader or pattern
                      if (isUnlocked)
                        Positioned.fill(
                          child: Opacity(
                            opacity: 0.05,
                            child: Image.asset(
                              'assets/images/background2.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),

                      // Lock overlay for locked levels
                      if (!isUnlocked)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black54,
                            child: Center(
                              child: Icon(
                                Icons.lock,
                                size: 40,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                          ),
                        ),

                      // Content
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Level number
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(vertical: 5),
                              decoration: BoxDecoration(
                                color: Color(0xFFD1A758).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Color(0xFFD1A758),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'LEVEL $level',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Vip',
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            SizedBox(height: 8),

                            // Difficulty
                            Container(
                              padding: EdgeInsets.symmetric(
                                vertical: 3,
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _getDifficultyColor(
                                  difficulty,
                                ).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _getDifficultyColor(difficulty),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                difficulty.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            SizedBox(height: 6),

                            // Additional difficulty tags in column
                            Column(
                              children: [
                                // Enemy behavior tag
                                Container(
                                  margin: EdgeInsets.only(bottom: 5),
                                  padding: EdgeInsets.symmetric(
                                    vertical: 2,
                                    horizontal: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.blue.withOpacity(0.5),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    enemyBehavior,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),

                                // Collectibles tag (if applicable)
                                if (hasCollectibles)
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 2,
                                      horizontal: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.amber.withOpacity(0.5),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      "Collectibles",
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            SizedBox(height: 8),

                            // Stars
                            if (isUnlocked && stars > 0)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(3, (index) {
                                  return Icon(
                                    index < stars
                                        ? Icons.star
                                        : Icons.star_border,
                                    color:
                                        index < stars
                                            ? Color(0xFFFFD700)
                                            : Colors.white30,
                                    size: 20,
                                  );
                                }),
                              ),

                            // Enemy count
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/images/enemy/idle/1.png',
                                    width: 20,
                                    height: 20,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'x $enemyCount',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Features
                            if (hasCollectibles)
                              Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset(
                                      'assets/images/treasure.png',
                                      width: 16,
                                      height: 16,
                                    ),
                                    SizedBox(width: 5),
                                    Image.asset(
                                      'assets/images/key.png',
                                      width: 16,
                                      height: 16,
                                    ),
                                  ],
                                ),
                              ),

                            // Game description
                            Spacer(),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black38,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                gameDescription,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white70,
                                  height: 1.2,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Helper method to get color based on difficulty
}
