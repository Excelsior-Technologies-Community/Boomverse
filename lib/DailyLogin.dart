import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'services/device_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Helper extension to replace all withValues instances
extension ColorHelpers on Color {
  Color withAlpha(int alpha) => withOpacity(alpha / 255);
}

class DailyLoginScreen extends StatefulWidget {
  const DailyLoginScreen({super.key});

  @override
  _DailyLoginScreenState createState() => _DailyLoginScreenState();
}

class _DailyLoginScreenState extends State<DailyLoginScreen>
    with TickerProviderStateMixin {
  int streakCount = 0;
  String? lastClaimDate;
  late Timer _timer;
  String _remainingTime = "24:00:00";
  final DeviceService _deviceService = DeviceService();

  late AnimationController _frameController;
  late AnimationController _bgParticlesController;
  late Animation<double> _frameScale;
  late Animation<double> _frameFade;
  late AnimationController _claimAnimationController;
  late Animation<double> _claimScale;
  late Animation<double> _claimFade;
  late AnimationController _pulseController;
  late AnimationController _coinBurstController;
  late AnimationController _glowController;
  late AnimationController _shimmerController;
  final List<Map<String, dynamic>> _claimedRewards = [];
  int? _lastClaimedDay;

  @override
  void initState() {
    super.initState();

    // Frame animation
    _frameController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _frameScale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _frameController, curve: Curves.elasticOut),
    );

    _frameFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _frameController,
        curve: Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // Background particles
    _bgParticlesController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();

    // Claim animation
    _claimAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _claimScale = Tween<double>(begin: 0.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _claimAnimationController,
        curve: Curves.easeOutBack,
      ),
    );
    _claimFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _claimAnimationController, curve: Curves.easeIn),
    );

    // Coin burst animation controller
    _coinBurstController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Add glow animation controller with longer duration
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Add shimmer animation controller
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    // Pulse animation for claimable rewards
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _frameController.forward();
    _loadDailyLoginData();
  }

  @override
  void dispose() {
    _frameController.dispose();
    _bgParticlesController.dispose();
    _claimAnimationController.dispose();
    _pulseController.dispose();
    _coinBurstController.dispose();
    _glowController.dispose();
    _shimmerController.dispose();
    _timer.cancel();
    super.dispose();
  }

  Future<void> _loadDailyLoginData() async {
    try {
      // Initialize device ID if not already done
      if (!_deviceService.isInitialized) {
        await _deviceService.initDeviceId();
      }
      
      // Use sanitized device ID for Firebase path
      final deviceId = _deviceService.sanitizedDeviceId;
      print('Loading Daily Login data for device ID: $deviceId');

      // Test database connectivity first
      await _verifyDatabaseConnection();

      final DatabaseReference userRef = FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(deviceId);
      print('Database reference path: ${userRef.path}');

      try {
        final DatabaseEvent event = await userRef.once();
        final DataSnapshot snapshot = event.snapshot;

        if (snapshot.exists) {
          print('User data found in database');
          final data = snapshot.value as Map<dynamic, dynamic>;
          final userData = Map<String, dynamic>.from(data);

          setState(() {
            streakCount = userData['streakCount'] ?? 0;
            lastClaimDate = userData['lastClaimDate'];
            print('Loaded streak count: $streakCount');
            print('Loaded last claim date: $lastClaimDate');
            _updateRemainingTime();
          });
        } else {
          print('No data found for user, initializing as new user');
          // Initialize for new user
          setState(() {
            streakCount = 0;
            lastClaimDate = null; // Allow immediate claim for new user
            _updateRemainingTime();
          });
        }
      } catch (e) {
        print('Error retrieving user data: $e');
        // Set default values so the UI still works
        setState(() {
          streakCount = 0;
          lastClaimDate = null;
          _updateRemainingTime();
        });
      }
    } catch (e) {
      print('Error in _loadDailyLoginData: $e');
      // Handle any errors and make sure UI is still functional
      setState(() {
        streakCount = 0;
        lastClaimDate = null;
        _updateRemainingTime();
      });
    }
    _startTimer();
  }

  // Verify database connection by performing a simple read
  Future<void> _verifyDatabaseConnection() async {
    try {
      print('Verifying database connection...');
      final connRef = FirebaseDatabase.instance.ref('.info/connected');
      final DatabaseEvent event = await connRef.once();
      final connected = event.snapshot.value as bool?;

      if (connected == true) {
        print('Database connection verified');
      } else {
        print('Database not connected');
        // Show a snackbar with connection issue
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Firebase database connection issue. Check your internet connection.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('Error verifying database connection: $e');
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot connect to Firebase. Check your internet connection.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _updateRemainingTime();
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _updateRemainingTime() {
    final now = DateTime.now();
    if (lastClaimDate == null) {
      // New user or first claim, set to 00:00:00 to allow immediate claim
      _remainingTime = "00:00:00";
      return;
    }

    try {
      final lastClaim = DateTime.parse(lastClaimDate!);
      print('Last claim date: $lastClaim');

      // Calculate the next claim time (24 hours after last claim)
      final nextClaimTime = lastClaim.add(Duration(hours: 24));
      final difference = nextClaimTime.difference(now);

      print('Next claim time: $nextClaimTime');
      print('Current time: $now');
      print('Difference in hours: ${difference.inHours}');

      if (difference.isNegative) {
        // If more than 24 hours have passed, the reward is claimable
        _remainingTime = "00:00:00";
        print('Reward is claimable now');
      } else {
        // Show remaining time until next claim
        _remainingTime = _formatDuration(difference);
        print('Time until next claim: $_remainingTime');
      }
    } catch (e) {
      print('Error parsing lastClaimDate: $e');
      // Set to 00:00:00 if parsing fails to allow claiming
      _remainingTime = "00:00:00";
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  Map<String, dynamic> getDailyLoginStatus() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (lastClaimDate == null) {
      print('First time user - can claim immediately');
      return {'canClaim': true, 'day': 1}; // New user can claim immediately
    }

    try {
      final lastClaim = DateTime.parse(lastClaimDate!);
      final lastClaimDay = DateTime(
        lastClaim.year,
        lastClaim.month,
        lastClaim.day,
      );

      print('Today: $today');
      print('Last claim day: $lastClaimDay');
      print('Current streak: $streakCount');

      // Same day - already claimed
      if (lastClaimDay == today) {
        print('Already claimed today');
        return {'canClaim': false, 'day': streakCount};
      } 
      // Next consecutive day
      else if (today.difference(lastClaimDay).inDays == 1) {
        print('Consecutive day - continue streak');
        final nextDay = streakCount >= 7 ? 1 : streakCount + 1;
        print('Next day in streak: $nextDay');
        return {'canClaim': true, 'day': nextDay};
      } 
      // More than one day missed - reset streak
      else if (today.difference(lastClaimDay).inDays > 1) {
        print('Streak broken - reset to day 1');
        return {'canClaim': true, 'day': 1};
      } 
      // Fallback case - shouldn't reach here
      else {
        print('Other case - allow claim with day 1');
        return {'canClaim': true, 'day': 1};
      }
    } catch (e) {
      print('Error in getDailyLoginStatus: $e');
      // Error parsing date - allow claiming with day 1
      return {'canClaim': true, 'day': 1};
    }
  }

  List<Map<String, dynamic>> getDaysList() {
    final status = getDailyLoginStatus();
    final canClaim = status['canClaim'];
    final dayToClaim = status['day'];
    List<Map<String, dynamic>> days = [];
    
    for (int day = 1; day <= 7; day++) {
      String statusStr;
      
      // This current day is unlocked and can be claimed
      if (canClaim && day == dayToClaim) {
        statusStr = 'unlocked';
      } 
      // Days before the current day in the streak are collected
      else if (day < dayToClaim) {
        statusStr = 'collected';
      }
      // If streak was reset (dayToClaim == 1) and this is day 1, it's unlocked
      else if (dayToClaim == 1 && day == 1 && canClaim) {
        statusStr = 'unlocked';
      }
      // All other days are locked (they're in the future)
      else {
        statusStr = 'locked';
      }
      
      days.add({
        'day': day,
        'status': statusStr,
        'reward': day == 7 ? 1000 : day * 50,
        'icon': day == 7 ? 'chest' : 'coin',
      });
    }
    
    // Debug
    print('Current streak: $streakCount, Day to claim: $dayToClaim, Can claim: $canClaim');
    for (var day in days) {
      print('Day ${day['day']}: ${day['status']}');
    }
    
    return days;
  }

  Future<void> _claimReward(String deviceId, int reward, int dayToClaim) async {
    try {
      // Use sanitized device ID
      final sanitizedDeviceId = _deviceService.sanitizedDeviceId;
      final DatabaseReference userRef = FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(sanitizedDeviceId);
      print('Attempting to claim reward for device: $sanitizedDeviceId');
      print('Path: ${userRef.path}');

      final DatabaseEvent event = await userRef.once();
      final DataSnapshot snapshot = event.snapshot;

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final userData = Map<String, dynamic>.from(data);
        int currentCoins =
            userData['coins'] is int
                ? userData['coins']
                : int.tryParse(userData['coins']?.toString() ?? '0') ?? 0;
        
        // Get the username for leaderboard update
        final username = userData['username'] as String? ?? 'Player';
        
        print('Current coins: $currentCoins, Adding reward: $reward');
        final int newCoins = currentCoins + reward;

        // Update user data with new values
        Map<String, dynamic> updates = {
          'coins': newCoins,
          'streakCount': dayToClaim,
          'lastClaimDate': DateTime.now().toIso8601String(),
        };

        // Perform the update with retry logic
        bool updateSuccess = false;
        int retryCount = 0;
        const maxRetries = 3;
        
        while (!updateSuccess && retryCount < maxRetries) {
          try {
            await userRef.update(updates);
            updateSuccess = true;
            print('Database updated successfully');
          } catch (e) {
            retryCount++;
            print('Error updating database (attempt $retryCount): $e');
            if (retryCount >= maxRetries) {
              throw Exception('Failed to update database after $maxRetries attempts');
            }
            await Future.delayed(Duration(milliseconds: 500 * retryCount));
          }
        }
        
        // Update leaderboard entry with new coin count
        final leaderboardRef = FirebaseDatabase.instance.ref('leaderboard/$username');
        
        // Try to get existing leaderboard data first
        final leaderboardSnapshot = await leaderboardRef.get();
        int leaderboardCoins = newCoins;
        
        if (leaderboardSnapshot.exists) {
          final leaderboardData = leaderboardSnapshot.value as Map<dynamic, dynamic>;
          // Only update if current coins are higher than leaderboard
          if (leaderboardData.containsKey('coins') && 
              leaderboardData['coins'] is int && 
              leaderboardData['coins'] > newCoins) {
            leaderboardCoins = leaderboardData['coins'];
          }
        }
        
        await leaderboardRef.update({
          'coins': leaderboardCoins,
          'name': username
        });
        print('Leaderboard updated with new coin value: $leaderboardCoins');

        // Save to SharedPreferences for quick access
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('coins', newCoins);
        await prefs.setInt('streakCount', dayToClaim);
        await prefs.setString('lastClaimDate', DateTime.now().toIso8601String());

        // Verify the update worked
        final DatabaseEvent updatedEvent = await userRef.once();
        final updatedSnapshot = updatedEvent.snapshot;
        if (updatedSnapshot.exists) {
          final updatedData = updatedSnapshot.value as Map<dynamic, dynamic>;
          print('Updated coins for $deviceId: ${updatedData['coins']}');
          
          // Confirm that the update was successful
          int updatedCoins = updatedData['coins'] is int 
              ? updatedData['coins'] 
              : int.tryParse(updatedData['coins']?.toString() ?? '0') ?? 0;
              
          if (updatedCoins != newCoins) {
            print('Warning: Updated coins value ($updatedCoins) does not match expected value ($newCoins)');
          }
        }
      } else {
        print('User does not exist, creating new record');
        // For new users, we need a username first
        // Get current username from shared preferences
        final prefs = await SharedPreferences.getInstance();
        final username = prefs.getString('username') ?? 'Player';
        
        // Create an initial user record
        final initialUserData = {
          'username': username,
          'coins': reward,
          'streakCount': dayToClaim,
          'lastClaimDate': DateTime.now().toIso8601String(),
          'key': 0,
          'level': 1,
          'levels': List.filled(100, 0),
          'platform': 'android',
          'treasure': 0,
        };
        
        // Set the data with retry logic
        bool setSuccess = false;
        int retryCount = 0;
        const maxRetries = 3;
        
        while (!setSuccess && retryCount < maxRetries) {
          try {
            await userRef.set(initialUserData);
            setSuccess = true;
            print('New user data created successfully');
          } catch (e) {
            retryCount++;
            print('Error creating user data (attempt $retryCount): $e');
            if (retryCount >= maxRetries) {
              throw Exception('Failed to create user data after $maxRetries attempts');
            }
            await Future.delayed(Duration(milliseconds: 500 * retryCount));
          }
        }
        
        // Save to SharedPreferences
        await prefs.setInt('coins', reward);
        await prefs.setInt('streakCount', dayToClaim);
        await prefs.setString('lastClaimDate', DateTime.now().toIso8601String());
        
        // Create leaderboard entry
        final leaderboardRef = FirebaseDatabase.instance.ref('leaderboard/$username');
        await leaderboardRef.set({
          'coins': reward,
          'name': username
        });
        
        print('Initialized user $sanitizedDeviceId with coins: $reward');
      }

      // Update local state
      setState(() {
        streakCount = dayToClaim;
        lastClaimDate = DateTime.now().toIso8601String();
        _updateRemainingTime();
        _lastClaimedDay = dayToClaim;
      });

      // Trigger claim animation
      _claimAnimationController.forward(from: 0.0).then((_) {
        _claimAnimationController.reverse();
      });

      // Trigger glow animation
      _glowController.forward(from: 0.0);

      // Trigger shimmer animation with slight delay
      Future.delayed(Duration(milliseconds: 100), () {
        _shimmerController.forward(from: 0.0);
      });

      // Return true to indicate success
      return Future.value();
    } catch (e) {
      print('Error claiming reward: $e');
      // Return false or rethrow to indicate failure
      return Future.error('Failed to claim reward: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWebPlatform = kIsWeb;

    // Simple responsive sizing for web
    final double webScale = _getWebScaleFactor(context);

    // Calculate container size using simple responsive scaling for web
    final containerWidth = size.width * (isWebPlatform ? 0.6 * webScale : 0.67);
    final containerHeight = containerWidth * (isWebPlatform ? 0.45 : 0.4);

    final days = getDaysList();
    final status = getDailyLoginStatus();
    final canClaim = status['canClaim'];

    print('Can claim rewards: $canClaim');
    print('Is web platform: $isWebPlatform');
    print('Web scale factor: $webScale');
    print('Screen size: ${size.width} x ${size.height}');

    // Check if the screen is in landscape mode and is narrow
    final isNarrowLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape &&
        size.height < 500;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _bgParticlesController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: ParticlesPainter(
                      animationValue: _bgParticlesController.value,
                    ),
                  );
                },
              ),
            ),

            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withAlpha(192),
                      Colors.black.withAlpha(224),
                    ],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: isNarrowLandscape ? 0 : 2,
                    ),
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/images/BlasterMan.png',
                          height: 38 * (isWebPlatform ? webScale : 1.0),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'DAILY REWARDS',
                          style: TextStyle(
                            fontFamily: 'Vip',
                            fontSize:
                                (isWebPlatform ? 22 : 16) *
                                (isWebPlatform ? webScale : 1.0),
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFD9A1),
                            letterSpacing: 1.0,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                offset: Offset(1, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: Image(
                              image: AssetImage("assets/images/cancel.png"),
                              height: 40 * (isWebPlatform ? webScale : 1.0),
                              width: 40 * (isWebPlatform ? webScale : 1.0),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _frameController,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _frameFade.value,
                            child: Transform.scale(
                              scale: _frameScale.value,
                              child: child,
                            ),
                          );
                        },
                        child: Container(
                          width: containerWidth,
                          height: containerHeight,
                          decoration: BoxDecoration(
                            color: Color(0xFF212121),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Color(0xFFFFD9A1).withAlpha(128),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(128),
                                blurRadius: 15,
                                spreadRadius: 2,
                                offset: Offset(0, 8),
                              ),
                              BoxShadow(
                                color: Colors.amber.withAlpha(64),
                                blurRadius: 25,
                                spreadRadius: 1,
                                offset: Offset(0, 0),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: CustomPaint(
                                    painter: StripedBackgroundPainter(),
                                  ),
                                ),
                              ),

                              Positioned(
                                top: 3,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: _buildTitleBadge(
                                    'DAILY LOGIN',
                                    (isWebPlatform ? 20 : 14) *
                                        (isWebPlatform ? webScale : 1.0),
                                  ),
                                ),
                              ),

                              Padding(
                                padding: EdgeInsets.all(25),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: GridView.builder(
                                        shrinkWrap: true,
                                        physics: NeverScrollableScrollPhysics(),
                                        gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 3,
                                              crossAxisSpacing: 2,
                                              mainAxisSpacing: 2,
                                              childAspectRatio:
                                                  isNarrowLandscape ? 1.5 : 1.5,
                                            ),
                                        itemCount: 6,
                                        itemBuilder: (context, index) {
                                          return _buildDaySquare(
                                            day: days[index]['day'],
                                            status: days[index]['status'],
                                            reward: days[index]['reward'],
                                            icon: days[index]['icon'],
                                            delay: Duration(
                                              milliseconds: 100 * index,
                                            ),
                                            webScale: webScale,
                                          );
                                        },
                                      ),
                                    ),

                                    SizedBox(width: 2),
                                    Expanded(
                                      flex: 1,
                                      child: AspectRatio(
                                        aspectRatio:
                                            isNarrowLandscape ? 0.55 : 0.75,
                                        child: _buildDaySquare(
                                          day: days[6]['day'],
                                          status: days[6]['status'],
                                          reward: days[6]['reward'],
                                          icon: days[6]['icon'],
                                          isSpecial: true,
                                          delay: Duration(milliseconds: 600),
                                          webScale: webScale,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),


                              Positioned(
                                bottom: -1,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal:
                                          isWebPlatform ? 12 * webScale : 8,
                                      vertical:
                                          isWebPlatform ? 4 * webScale : 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withAlpha(128),
                                      borderRadius: BorderRadius.only(
                                        bottomLeft: Radius.circular(10),
                                        bottomRight: Radius.circular(10),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.timer,
                                          color: Colors.amber,
                                          size:
                                              (isWebPlatform ? 16 : 10) *
                                              (isWebPlatform ? webScale : 1.0),
                                        ),
                                        SizedBox(width: isWebPlatform ? 4 : 2),
                                        Text(
                                          'Next reward in: $_remainingTime',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontFamily: 'Vip',
                                            fontSize:
                                                (isWebPlatform ? 16 : 12) *
                                                (isWebPlatform
                                                    ? webScale
                                                    : 1.0),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 36 * (isWebPlatform ? webScale : 1.0),
                            height: 36 * (isWebPlatform ? webScale : 1.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(32),
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.home,
                              color: Colors.grey[800],
                              size: 18 * (isWebPlatform ? webScale : 1.0),
                            ),
                          ),
                        ),

                        _buildClaimButton(canClaim, webScale),
                      ],
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

  // Simple web scale factor calculation
  double _getWebScaleFactor(BuildContext context) {
    if (!kIsWeb) return 1.0;

    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    // Provide appropriate scaling based on screen size for web
    if (width > 1600) return 1.5;
    if (width > 1200) return 1.3;
    if (width > 900) return 1.2;
    if (width > 600) return 1.1;

    // For very small height screens, reduce the scale to fit content
    if (height < 500) return 0.9;

    return 1.0;
  }

  Widget _buildDaySquare({
    required int day,
    required String status,
    required int reward,
    required String icon,
    bool isSpecial = false,
    required Duration delay,
    required double webScale,
  }) {
    final isWebPlatform = kIsWeb;
    final Color bgColor =
        status == 'collected'
            ? Color(0xFF8FB448)
            : (status == 'unlocked' ? Color(0xFFE0A65B) : Color(0xFFF2D17A));

    final Color borderColor =
        status == 'collected'
            ? Color(0xFF6C9138)
            : (status == 'unlocked' ? Color(0xFFB17B34) : Color(0xFFD1A841));

    // Check if this is the day that was just claimed
    final bool isJustClaimed =
        _lastClaimedDay == day &&
        (_glowController.isAnimating || _shimmerController.isAnimating);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: GestureDetector(
        onTap: status == 'unlocked' ? () => _handleDayTap(day, reward) : null,
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: borderColor, width: 1),
            boxShadow:
                isJustClaimed
                    ? [
                      // Add improved animated glow effect if this day was just claimed
                      BoxShadow(
                        color: Colors.amber.withAlpha(128),
                        blurRadius: 15.0 * _glowController.value,
                        spreadRadius: 5.0 * _glowController.value,
                      ),
                      BoxShadow(
                        color: Colors.orange.withAlpha(64),
                        blurRadius: 20.0 * _glowController.value,
                        spreadRadius: 2.0 * _glowController.value,
                      ),
                      BoxShadow(
                        color: Colors.black.withAlpha(32),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ]
                    : [
                      BoxShadow(
                        color: Colors.black.withAlpha(32),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
          ),
          child: Stack(
            children: [
              // Add subtle scale animation for just claimed days
              if (isJustClaimed)
                AnimatedBuilder(
                  animation: _glowController,
                  builder: (context, child) {
                    // Subtle pulse effect without changing size too dramatically
                    final scale =
                        1.0 +
                        math.sin(_glowController.value * 3 * math.pi) * 0.05;
                    return Positioned.fill(
                      child: Transform.scale(
                        scale: scale,
                        child: Container(color: Colors.transparent),
                      ),
                    );
                  },
                ),

              Padding(
                padding: EdgeInsets.all(isWebPlatform ? 2 : 1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        isSpecial ? 'DAY 7' : 'DAY $day',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Vip',
                          fontSize:
                              (isWebPlatform
                                  ? (isSpecial ? 16 : 14)
                                  : (isSpecial ? 12 : 8)) *
                              (isWebPlatform ? webScale : 1.0),
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8D5A13),
                        ),
                      ),
                    ),

                    SizedBox(height: 1),

                    Expanded(
                      child:
                          isSpecial
                              ? Image.asset(
                                'assets/images/coins_bucket.png',
                                fit: BoxFit.contain,
                              )
                              : Icon(
                                _getIconForType(icon),
                                color: Color(0xFF8D5A13),
                                size:
                                    (isWebPlatform
                                        ? (isSpecial ? 32 : 24)
                                        : (isSpecial ? 24 : 16)) *
                                    (isWebPlatform ? webScale : 1.0),
                              ),
                    ),

                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '+$reward',
                        style: TextStyle(
                          fontFamily: 'Vip',
                          fontSize:
                              (isWebPlatform
                                  ? (isSpecial ? 18 : 14)
                                  : (isSpecial ? 12 : 9)) *
                              (isWebPlatform ? webScale : 1.0),
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8D5A13),
                        ),
                      ),
                    ),

                    Container(
                      margin: EdgeInsets.only(top: 1),
                      padding: EdgeInsets.symmetric(
                        horizontal:
                            (isWebPlatform ? 4 : 2) *
                            (isWebPlatform ? webScale : 1.0),
                        vertical: isWebPlatform ? 2 : 0,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _getStatusText(status),
                          style: TextStyle(
                            fontFamily: 'Vip',
                            fontSize:
                                (isWebPlatform ? 11 : 7) *
                                (isWebPlatform ? webScale : 1.0),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (status == 'locked')
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Image(
                    image: AssetImage("assets/images/lock.png"),
                    width:
                        (isWebPlatform ? 60 : 50) *
                        (isWebPlatform ? webScale * 0.8 : 1.0),
                    height:
                        (isWebPlatform ? 60 : 50) *
                        (isWebPlatform ? webScale * 0.8 : 1.0),
                  ),
                ),

              if (status == 'unlocked')
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Image(
                    image: AssetImage("assets/images/gold.png"),
                    width:
                        (isWebPlatform ? 24 : 16) *
                        (isWebPlatform ? webScale : 1.0),
                    height:
                        (isWebPlatform ? 24 : 16) *
                        (isWebPlatform ? webScale : 1.0),
                  ),
                ),

              if (status == 'collected')
                Positioned(
                  top: 2,
                  right: 2,
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size:
                        (isWebPlatform ? 24 : 16) *
                        (isWebPlatform ? webScale : 1.0),
                  ),
                ),

              if (status == 'unlocked')
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.amber.withAlpha(64),
                            width: 2,
                          ),
                        ),
                      );
                    },
                  ),
                ),

              if (status == 'unlocked')
                Positioned(
                  bottom: -1,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isWebPlatform ? 4 : 2,
                      vertical: isWebPlatform ? 2 : 1,
                    ),
                    color: Colors.black.withAlpha(128),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'TAP TO CLAIM',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Vip',
                          fontSize:
                              (isWebPlatform ? 10 : 6) *
                              (isWebPlatform ? webScale : 1.0),
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

              // Enhanced shimmer effect for the claimed reward
              if (isJustClaimed)
                AnimatedBuilder(
                  animation: _shimmerController,
                  builder: (context, child) {
                    return Positioned.fill(
                      child: ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) {
                          // Create a sweeping gradient shimmer
                          return LinearGradient(
                            begin: Alignment(
                              -1.0 + 2 * _shimmerController.value * 2,
                              -0.5 + _shimmerController.value,
                            ),
                            end: Alignment(
                              0.0 + 2 * _shimmerController.value * 2,
                              0.5 + _shimmerController.value,
                            ),
                            colors: [
                              Colors.transparent,
                              Colors.white.withAlpha(128),
                              Colors.white.withAlpha(128),
                              Colors.transparent,
                            ],
                            stops: [0.0, 0.3, 0.7, 1.0],
                          ).createShader(bounds);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(32),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    );
                  },
                ),

              // Add floating coins/sparkles for just claimed rewards
              if (isJustClaimed && status == 'collected')
                AnimatedBuilder(
                  animation: _glowController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: SparklesPainter(
                        progress: _glowController.value,
                        isWebPlatform: isWebPlatform,
                      ),
                      size: Size.infinite,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'collected':
        return Colors.green.shade800;
      case 'unlocked':
        return Colors.deepOrange;
      default:
        return Colors.black45;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'collected':
        return 'COLLECTED';
      case 'unlocked':
        return 'CLAIM';
      default:
        return 'LOCKED';
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'gem':
        return Icons.diamond;
      case 'chest':
        return Icons.card_giftcard;
      case 'coin':
      default:
        return Icons.monetization_on;
    }
  }

  Widget _buildTitleBadge(String text, double fontSize) {
    return Stack(
      children: [
        Text(
          text,
          style: TextStyle(
            fontFamily: 'Vip',
            fontSize: fontSize + 1,
            fontWeight: FontWeight.bold,
            // foreground:
            //     Paint()
            //       ..style = PaintingStyle.stroke
            //       ..strokeWidth = 20
            //       ..color = Colors.black.withValues(alpha: 0.8),
            letterSpacing: 1.2,
          ),
        ),

        ShaderMask(
          shaderCallback:
              (bounds) => LinearGradient(
                colors: [
                  Color(0xFFFFD9A1),
                  Color(0xFFEAAF7A),
                  Color(0xFFFFFFFF),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ).createShader(bounds),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Vip',
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  // Update to accept webScale parameter
  Widget _buildClaimButton(bool canClaim, double webScale) {
    final isWebPlatform = kIsWeb;
    print('Building claim button. canClaim: $canClaim');

    return AnimatedBuilder(
      animation: _claimAnimationController,
      builder: (context, child) {
        return Opacity(
          opacity: _claimFade.value,
          child: Transform.scale(scale: _claimScale.value, child: child),
        );
      },
      child: Container(
        height: (isWebPlatform ? 48 : 36) * (isWebPlatform ? webScale : 1.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              canClaim ? Color(0xFFE0782B) : Colors.grey,
              canClaim ? Color(0xFFDD5E1A) : Colors.grey.shade700,
            ],
          ),
          borderRadius: BorderRadius.circular(
            (isWebPlatform ? 24 : 18) * (isWebPlatform ? webScale : 1.0),
          ),
          boxShadow: [
            BoxShadow(
              color:
                  canClaim
                      ? Colors.deepOrange.withAlpha(64)
                      : Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed:
              canClaim
                  ? () async {
                    try {
                      final status = getDailyLoginStatus();
                      final dayToClaim = status['day'];
                      final reward = dayToClaim == 7 ? 1000 : dayToClaim * 50;
                      final deviceId = _deviceService.deviceId;

                      // Show loading indicator
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('Claiming reward...'),
                            ],
                          ),
                          duration: Duration(seconds: 1),
                          backgroundColor: Colors.green.shade700,
                        ),
                      );

                      // Claim the reward
                      await _claimReward(deviceId, reward, dayToClaim);

                      // Show success message
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 12),
                              Text('Reward claimed! +$reward coins'),
                            ],
                          ),
                          duration: Duration(seconds: 2),
                          backgroundColor: Colors.green.shade700,
                        ),
                      );

                      // Wait a moment to show the success message before closing
                      await Future.delayed(Duration(milliseconds: 800));
                      Navigator.pop(
                        context,
                        true,
                      ); // Return true to indicate success
                    } catch (e) {
                      print('Error in claim button: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Failed to claim reward. Please try again.',
                          ),
                          backgroundColor: Colors.red.shade700,
                        ),
                      );
                    }
                  }
                  : () {
                    // Not claimable yet, show message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('No rewards available to claim yet.'),
                        backgroundColor: Colors.orange.shade700,
                      ),
                    );
                  },
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: EdgeInsets.symmetric(
              horizontal:
                  (isWebPlatform ? 16 : 10) * (isWebPlatform ? webScale : 1.0),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                (isWebPlatform ? 24 : 18) * (isWebPlatform ? webScale : 1.0),
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.emoji_events,
                color: Colors.white,
                size:
                    (isWebPlatform ? 24 : 18) *
                    (isWebPlatform ? webScale : 1.0),
              ),
              SizedBox(
                width:
                    (isWebPlatform ? 8 : 5) * (isWebPlatform ? webScale : 1.0),
              ),
              Text(
                canClaim ? 'CLAIM ALL' : 'CLAIM ALL',
                style: TextStyle(
                  fontFamily: 'Vip',
                  fontSize:
                      (isWebPlatform ? 18 : 14) *
                      (isWebPlatform ? webScale : 1.0),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  shadows: [
                    Shadow(
                      color: Colors.black.withAlpha(64),
                      offset: Offset(1, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleDayTap(int day, int reward) async {
    try {
      final deviceId = _deviceService.deviceId;

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Claiming day $day reward...'),
            ],
          ),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.green.shade700,
        ),
      );

      // Set the last claimed day
      setState(() {
        _lastClaimedDay = day;
      });

      // Claim the reward
      await _claimReward(deviceId, reward, day);

      // Reset animations just to be safe
      _glowController.reset();
      _shimmerController.reset();

      // Trigger glow animation
      _glowController.forward(from: 0.0);

      // Trigger shimmer with slight delay
      Future.delayed(Duration(milliseconds: 100), () {
        _shimmerController.forward(from: 0.0);
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Day $day reward claimed! +$reward coins'),
            ],
          ),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green.shade700,
        ),
      );

      // Reload data after claiming
      _loadDailyLoginData();
    } catch (e) {
      print('Error claiming individual reward: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to claim reward. Please try again.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }
}

class StripedBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.amber.withAlpha(5)
          ..style = PaintingStyle.fill;

    for (int i = -20; i < 40; i++) {
      final path = Path();
      final offset = i * 30.0;

      path.moveTo(offset, 0);
      path.lineTo(offset + size.width, size.height);
      path.lineTo(offset + size.width - 15, size.height);
      path.lineTo(offset - 15, 0);
      path.close();

      canvas.drawPath(path, paint);
    }

    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 0.8,
      colors: [Colors.amber.withAlpha(10), Colors.transparent],
    ).createShader(rect);

    final gradientPaint =
        Paint()
          ..shader = gradient
          ..style = PaintingStyle.fill;

    canvas.drawRect(rect, gradientPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class ParticlesPainter extends CustomPainter {
  final double animationValue;
  final int particleCount = 50;
  final List<Offset> positions = [];
  final List<double> sizes = [];
  final List<double> speeds = [];
  final List<Color> colors = [];

  ParticlesPainter({required this.animationValue}) {
    if (positions.isEmpty) {
      final random = math.Random(42);
      for (int i = 0; i < particleCount; i++) {
        positions.add(Offset(random.nextDouble(), random.nextDouble()));
        sizes.add(1 + random.nextDouble() * 3);
        speeds.add(0.2 + random.nextDouble() * 0.5);

        final colorRoll = random.nextDouble();
        if (colorRoll < 0.5) {
          colors.add(
            Colors.amber.withAlpha(128),
          );
        } else if (colorRoll < 0.8) {
          colors.add(
            Colors.orange.withAlpha(64),
          );
        } else {
          colors.add(
            Colors.white.withAlpha(64),
          );
        }
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < particleCount; i++) {
      final position = positions[i];
      final particleSize = sizes[i];
      final speed = speeds[i];
      final color = colors[i];

      final y = (position.dy + animationValue * speed) % 1.0;

      final paint =
          Paint()
            ..color = color
            ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(position.dx * size.width, y * size.height),
        particleSize,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(ParticlesPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class CoinBurstPainter extends CustomPainter {
  final double progress;
  final bool isWebPlatform;
  final List<Offset> particleOffsets = [];
  final List<double> particleSizes = [];
  final List<Color> particleColors = [];

  CoinBurstPainter({required this.progress, required this.isWebPlatform}) {
    if (particleOffsets.isEmpty) {
      final random = math.Random(42);
      final count = isWebPlatform ? 20 : 15;

      for (int i = 0; i < count; i++) {
        // Create particles that spread outward from center
        final angle = random.nextDouble() * 2 * math.pi;
        final distance = random.nextDouble() * 0.5;
        particleOffsets.add(
          Offset(math.cos(angle) * distance, math.sin(angle) * distance),
        );

        particleSizes.add(
          isWebPlatform
              ? random.nextDouble() * 5 + 3
              : random.nextDouble() * 3 + 2,
        );

        final colorChoice = random.nextDouble();
        if (colorChoice < 0.7) {
          particleColors.add(Colors.amber.withAlpha(128));
        } else if (colorChoice < 0.9) {
          particleColors.add(Colors.amber.shade200.withAlpha(128));
        } else {
          particleColors.add(Colors.white.withAlpha(128));
        }
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < particleOffsets.length; i++) {
      // Calculate motion path
      final baseOffset = particleOffsets[i];
      final currentDistance = progress * 1.5; // Particles move 1.5x outward
      final currentOpacity = (1.0 - progress) * 0.8; // Fade out as they move

      final currentOffset = Offset(
        center.dx + baseOffset.dx * size.width * currentDistance,
        center.dy + baseOffset.dy * size.height * currentDistance,
      );

      final radius =
          particleSizes[i] * (1.0 - progress * 0.5); // Shrink slightly
      final color = particleColors[i].withAlpha(128);

      canvas.drawCircle(currentOffset, radius, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant CoinBurstPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class SparklesPainter extends CustomPainter {
  final double progress;
  final bool isWebPlatform;
  final List<Map<String, dynamic>> sparkles = [];

  SparklesPainter({required this.progress, required this.isWebPlatform}) {
    if (sparkles.isEmpty) {
      final random = math.Random(42);
      final count = isWebPlatform ? 10 : 7;

      for (int i = 0; i < count; i++) {
        // Small sparkles that float upward
        final xPos = 0.2 + random.nextDouble() * 0.6; // Keep within the box
        final yStart = 0.4 + random.nextDouble() * 0.4; // Start in bottom half
        final size = random.nextDouble() * (isWebPlatform ? 3.0 : 2.0) + 1.0;
        final speed = 0.5 + random.nextDouble() * 0.5;
        final delay = random.nextDouble() * 0.5;

        sparkles.add({
          'x': xPos,
          'y': yStart,
          'size': size,
          'speed': speed,
          'delay': delay,
          'color':
              random.nextDouble() < 0.7
                  ? Colors.amber.withAlpha(128)
                  : Colors.white.withAlpha(128),
        });
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final sparkle in sparkles) {
      // Only start drawing after delay
      final adjustedProgress = math.max(0.0, progress - sparkle['delay']);
      if (adjustedProgress <= 0) continue;

      final normalizedProgress = math.min(
        1.0,
        adjustedProgress / (1.0 - sparkle['delay']),
      );

      // Calculate position with upward movement
      final x = sparkle['x'] * size.width;
      final y =
          sparkle['y'] * size.height -
          (normalizedProgress * sparkle['speed'] * size.height);

      // Fade out near the end
      final opacity =
          normalizedProgress < 0.7
              ? 1.0
              : (1.0 - (normalizedProgress - 0.7) / 0.3);

      // Draw sparkle (simple circle)
      final paint =
          Paint()
            ..color = (sparkle['color'] as Color).withAlpha(128);

      // Size varies slightly for twinkling effect
      final twinkleEffect =
          0.8 + 0.2 * math.sin(normalizedProgress * math.pi * 4);
      final currentSize = sparkle['size'] * twinkleEffect;

      canvas.drawCircle(Offset(x, y), currentSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SparklesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
