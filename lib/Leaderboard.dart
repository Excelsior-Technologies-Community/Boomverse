import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:math' show Random;

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  _LeaderboardScreenState createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  final LeaderboardService _leaderboardService = LeaderboardService();
  late AnimationController _shineController;
  final Random _random = Random();

  // Trophy colors for top ranks
  final List<Color> trophyColors = [
    const Color(0xFFFFD700), // Gold
    const Color(0xFFC0C0C0), // Silver
    const Color(0xFFCD7F32), // Bronze
  ];

  // Background glitter particles (stars)
  final List<Map<String, dynamic>> _particles = List.generate(20, (index) {
    return {
      'x': index * 20.0,
      'y': index * 15.0,
      'size': 1.0 + (index % 3),
      'opacity': 0.2 + (index % 5) * 0.15,
    };
  });

  @override
  void initState() {
    super.initState();

    // Animation controller for the shine effect
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Randomize particles
    for (var particle in _particles) {
      particle['x'] = (_random.nextDouble() * 400);
      particle['y'] = (_random.nextDouble() * 800);
    }
  }

  @override
  void dispose() {
    _shineController.dispose();
    super.dispose();
  }

  Widget _buildIconButton({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 35,
        height: 35,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Image.asset("assets/images/cancel.png", width: 20, height: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          // Background with parallax effect
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Animated particles/stars in background
          ...buildParticles(width, height),

          // Main content
          SafeArea(
            child: Stack(
              children: [
                // Back button
                Positioned(
                  top: 8,
                  right: 12,
                  child: _buildIconButton(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.pop(context);
                    },
                  ),
                ),

                // Game logo
                Positioned(
                  top: 8,
                  left: 12,
                  child: Row(
                    children: [
                      Image.asset('assets/images/BlasterMan.png', width: 50),
                      SizedBox(width: 6),
                      Text(
                        "RANKINGS",
                        style: TextStyle(
                          fontFamily: 'Vip',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          foreground:
                              Paint()
                                ..shader = ui.Gradient.linear(
                                  const Offset(0, 0),
                                  Offset(0, 16),
                                  [Color(0xFFFFD9A1), Color(0xFFEAAF7A)],
                                ),
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.5),
                              offset: Offset(1, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Leaderboard
                Padding(
                  padding: EdgeInsets.only(top: height * 0.1),
                  child: Center(
                    child: Container(
                      width: width * 0.85,
                      height: height * 0.8,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF7AC74C),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7AC74C).withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title
                          Container(
                            width: width * 0.5,
                            transform: Matrix4.translationValues(0, -15, 0),
                            padding: const EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF7AC74C),
                                  const Color(0xFF4A6D00),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                  offset: Offset(0, 2),
                                ),
                              ],
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/images/coin.png',
                                  width: 16,
                                  height: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'LEADERBOARD',
                                  style: TextStyle(
                                    fontFamily: 'Vip',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black,
                                        offset: Offset(1, 1),
                                        blurRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 6),
                                Image.asset(
                                  'assets/images/coin.png',
                                  width: 16,
                                  height: 16,
                                ),
                              ],
                            ),
                          ),

                          // Table header
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF7AC74C).withOpacity(0.7),
                                    const Color(0xFF4A6D00).withOpacity(0.7),
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 50,
                                    child: Text('RANK', style: _headerStyle()),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'PLAYER',
                                      style: _headerStyle(),
                                    ),
                                  ),
                                  Text('SCORE', style: _headerStyle()),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: 6),

                          // Leaderboard items
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: FutureBuilder<List<Map<String, dynamic>>>(
                                future:
                                    _leaderboardService.fetchLeaderboardData(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.amber,
                                        strokeWidth: 2,
                                      ),
                                    );
                                  } else if (snapshot.hasError) {
                                    return Container(
                                      padding: EdgeInsets.all(10),
                                      margin: EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.red.withOpacity(0.5),
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.error_outline,
                                            color: Colors.red,
                                            size: 24,
                                          ),
                                          SizedBox(height: 6),
                                          Text(
                                            'Error: ${snapshot.error}',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontFamily: 'Vip',
                                              fontSize: 12,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  } else if (!snapshot.hasData ||
                                      snapshot.data!.isEmpty) {
                                    return Container(
                                      padding: EdgeInsets.all(10),
                                      margin: EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.emoji_events_outlined,
                                            color: Colors.amber,
                                            size: 24,
                                          ),
                                          SizedBox(height: 6),
                                          Text(
                                            'No leaderboard data available\nBe the first to join!',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontFamily: 'Vip',
                                              fontSize: 12,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  final leaderboard = snapshot.data!;
                                  final currentUserId =
                                      FirebaseAuth.instance.currentUser?.uid;

                                  return ListView.builder(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    itemCount: leaderboard.length,
                                    itemBuilder: (context, index) {
                                      final item = leaderboard[index];
                                      final isCurrentUser =
                                          item['userId'] == currentUserId;
                                      final isTopRank = index < 3;
                                      return _buildLeaderboardItem(
                                        item,
                                        width,
                                        isCurrentUser,
                                        isTopRank ? trophyColors[index] : null,
                                        index,
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ),

                          SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _headerStyle() {
    return TextStyle(
      fontFamily: 'Vip',
      fontSize: 10,
      fontWeight: FontWeight.bold,
      color: Colors.white,
      letterSpacing: 0.5,
      shadows: [
        Shadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 1),
      ],
    );
  }

  Widget _buildLeaderboardItem(
    Map<String, dynamic> item,
    double width,
    bool isCurrentUser,
    Color? trophyColor,
    int index,
  ) {
    return AnimatedBuilder(
      animation: _shineController,
      builder: (context, child) {
        // Create shine animation for top 3 ranks
        final bool isTop3 = index < 3;
        final double shinePosition = _shineController.value * width * 2;

        return Container(
          margin: const EdgeInsets.only(bottom: 5),
          padding: EdgeInsets.all(5),
          height: 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors:
                  isCurrentUser
                      ? [
                        Colors.amber.withOpacity(0.3),
                        Colors.amber.withOpacity(0.1),
                      ]
                      : isTop3
                      ? [
                        trophyColor!.withOpacity(0.3),
                        trophyColor.withOpacity(0.1),
                      ]
                      : [
                        Colors.white.withOpacity(0.15),
                        Colors.white.withOpacity(0.05),
                      ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  isCurrentUser
                      ? Colors.amber
                      : isTop3
                      ? trophyColor!.withOpacity(0.8)
                      : Colors.white.withOpacity(0.3),
              width: isCurrentUser || isTop3 ? 1.5 : 1,
            ),
            boxShadow: [
              if (isCurrentUser || (isTop3 && trophyColor != null))
                BoxShadow(
                  color: (isCurrentUser ? Colors.amber : trophyColor!)
                      .withOpacity(0.3),
                  blurRadius: 4,
                  spreadRadius: 0.5,
                ),
            ],
          ),
          child: Stack(
            children: [
              // Shine effect for top 3
              if (isTop3)
                Positioned(
                  left: shinePosition - width,
                  top: 0,
                  bottom: 0,
                  width: width * 0.5,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0),
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0.2),
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0),
                        ],
                        stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),

              // Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    // Rank with trophy for top 3
                    SizedBox(
                      width: 20,
                      child:
                          isTop3
                              ? Icon(
                                Icons.emoji_events,
                                color: trophyColor,
                                size: 16,
                              )
                              : Text(
                                '${item['rank']}',
                                style: TextStyle(
                                  fontFamily: 'Vip',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white.withOpacity(0.9),
                                  shadows: [
                                    Shadow(
                                      color: Colors.black,
                                      offset: Offset(1, 1),
                                      blurRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                    ),

                    SizedBox(width: 20),

                    // Avatar
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors:
                              isCurrentUser || (isTop3 && trophyColor != null)
                                  ? [
                                    isCurrentUser ? Colors.amber : trophyColor!,
                                    isCurrentUser
                                        ? Colors.amber.shade800
                                        : trophyColor!.withOpacity(0.7),
                                  ]
                                  : [
                                    Colors.grey.shade700,
                                    Colors.grey.shade900,
                                  ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.8),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 2,
                            spreadRadius: 0.5,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),

                    SizedBox(width: 8),

                    // Name
                    Expanded(
                      child: Text(
                        isCurrentUser ? 'You' : (item['name'] ?? 'Unknown'),
                        style: TextStyle(
                          fontFamily: 'Vip',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color:
                              isCurrentUser
                                  ? Colors.amber
                                  : isTop3
                                  ? trophyColor
                                  : Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              offset: Offset(1, 1),
                              blurRadius: 1,
                            ),
                          ],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Score & Coin
                    Row(
                      children: [
                        Text(
                          '${item['score']}',
                          style: TextStyle(
                            fontFamily: 'Vip',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color:
                                isCurrentUser
                                    ? Colors.amber
                                    : isTop3
                                    ? trophyColor
                                    : Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                offset: Offset(1, 1),
                                blurRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 3),
                        Image.asset('assets/images/coin.png', height: 16),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Build background particles
  List<Widget> buildParticles(double width, double height) {
    return _particles.map((particle) {
      return Positioned(
        left: particle['x'],
        top: particle['y'],
        child: Container(
          width: particle['size'],
          height: particle['size'],
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(particle['opacity']),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(particle['opacity'] * 0.5),
                blurRadius: 2,
                spreadRadius: 0.5,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}

class LeaderboardService {
  final DatabaseReference _leaderboardRef = FirebaseDatabase.instance.ref(
    'leaderboard',
  );
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref('users');

  Future<List<Map<String, dynamic>>> fetchLeaderboardData() async {
    try {
      // Fetch all users from the users node
      final DatabaseEvent usersEvent = await _usersRef.once();
      final DataSnapshot usersSnapshot = usersEvent.snapshot;

      if (!usersSnapshot.exists) {
        return [];
      }

      final usersData = usersSnapshot.value as Map<dynamic, dynamic>;
      List<Map<String, dynamic>> leaderboard = [];

      // Iterate through all users
      for (var userEntry in usersData.entries) {
        final userId = userEntry.key.toString();
        final userData = Map<String, dynamic>.from(userEntry.value as Map);

        // Skip users without coins or with zero coins
        final coins =
            userData['coins'] is int
                ? userData['coins']
                : int.tryParse(userData['coins']?.toString() ?? '0') ?? 0;
        if (coins <= 0) continue;

        // Get username from users node
        final name = userData['username']?.toString() ?? 'Unknown';

        // Update leaderboard node to ensure it has the latest data
        await _leaderboardRef.child(userId).update({
          'coins': coins,
          'name': name,
        });

        leaderboard.add({
          'name': name,
          'score': coins, // Map 'coins' to 'score' for compatibility
          'userId': userId,
        });
      }

      // Sort by score (coins) in descending order and assign ranks
      leaderboard.sort((a, b) => b['score'].compareTo(a['score']));
      for (int i = 0; i < leaderboard.length; i++) {
        leaderboard[i]['rank'] = i + 1;
      }

      return leaderboard;
    } catch (e) {
      print('Error fetching leaderboard data: $e');
      throw Exception('Failed to fetch leaderboard data');
    }
  }

  Future<void> updateUserScore(
    String userId,
    int newScore, {
    required String name,
  }) async {
    try {
      final updateData = {'coins': newScore};
      await _leaderboardRef.child(userId).update(updateData);
      print('Score updated for $userId: $newScore');
    } catch (e) {
      print('Error updating user score: $e');
      throw Exception('Failed to update user score');
    }
  }
}
