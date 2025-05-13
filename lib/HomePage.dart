import 'dart:async';

import 'DailyLogin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'LevelSelectionPage.dart';
import 'main.dart';
import 'package:firebase_database/firebase_database.dart';
import 'Leaderboard.dart';
import 'SimpleUsername.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/audio_service.dart';
import 'services/device_service.dart';

class HomePage extends StatefulWidget {
  final String username;
  const HomePage({super.key, required this.username});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final DeviceService _deviceService = DeviceService();
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  int coins = 0;
  int keys = 0;
  int treasures = 0;
  int highestLevel = 0;
  Map<String, int> levelStars = {};
  bool isLoading = true;
  late AnimationController _buttonController;
  late Animation<double> _buttonScale;
  bool _dataMigrated = false;

  // Audio service
  final AudioService _audioService = AudioService();

  // Stream subscription for real-time updates
  StreamSubscription<DatabaseEvent>? _userDataSubscription;

  @override
  void initState() {
    super.initState();
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _buttonScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );

    // Initialize audio
    _initAudio();

    _initData();
  }

  Future<void> _initAudio() async {
    await _audioService.init();
    await _audioService.playBGM();
  }

  Future<void> _initData() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      // Make sure device ID is initialized
      if (!_deviceService.isInitialized) {
        await _deviceService.initDeviceId();
      }
      
      final prefs = await SharedPreferences.getInstance();
      
      // First try loading from SharedPreferences for faster initial display
      if (prefs.containsKey('coins')) {
        setState(() {
          coins = prefs.getInt('coins') ?? 0;
          keys = prefs.getInt('keys') ?? 0;
          treasures = prefs.getInt('treasures') ?? 0;
          highestLevel = prefs.getInt('highestLevel') ?? 0;
        });
      }
      
      // Then load from Firebase for accurate data
      await _loadPlayerData();
      
      // Setup real-time listener for updates
      _setupRealTimeListener();
    } catch (e) {
      print('Error in initData: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _setupRealTimeListener() async {
    try {
      // Cancel any existing subscription
      await _userDataSubscription?.cancel();
      
      // Make sure we have a device ID
      if (!_deviceService.isInitialized) {
        await _deviceService.initDeviceId();
      }
      
      final sanitizedDeviceId = _deviceService.sanitizedDeviceId;
      final DatabaseReference userRef = _database.ref().child('users').child(sanitizedDeviceId);
      
      _userDataSubscription = userRef.onValue.listen(
        (DatabaseEvent event) {
          final DataSnapshot snapshot = event.snapshot;
          if (snapshot.exists) {
            final data = snapshot.value as Map<dynamic, dynamic>;
            final userData = Map<String, dynamic>.from(data);
            
            setState(() {
              coins = userData['coins'] ?? 0;
              keys = userData['key'] ?? 0;
              treasures = userData['treasure'] ?? 0;
              highestLevel = userData['level'] ?? 0;
              
              // Parse levels data (stars for each level)
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
              _saveToPrefs(); // Save updated data to SharedPreferences
            });
            
            // Also make sure leaderboard entry is up to date
            _updateLeaderboard();
          } else {
            print('No data found for user: $sanitizedDeviceId');
            setState(() {
              isLoading = false;
            });
          }
        },
        onError: (error) {
          print('Error listening to user data: $error');
          setState(() {
            isLoading = false;
          });
        },
      );
    } catch (e) {
      print('Error setting up real-time listener: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadPlayerData() async {
    try {
      // Make sure device ID is initialized
      if (!_deviceService.isInitialized) {
        await _deviceService.initDeviceId();
      }
      
      final sanitizedDeviceId = _deviceService.sanitizedDeviceId;
      print('Loading player data for sanitized device ID: $sanitizedDeviceId');
      
      final DatabaseReference userRef = _database.ref().child('users').child(sanitizedDeviceId);
      
      final DatabaseEvent event = await userRef.once();
      final DataSnapshot snapshot = event.snapshot;
      
      if (snapshot.exists) {
        print('Found existing user data');
        final data = snapshot.value as Map<dynamic, dynamic>;
        final userData = Map<String, dynamic>.from(data);
        
        setState(() {
          coins = userData['coins'] ?? 0;
          keys = userData['key'] ?? 0;
          treasures = userData['treasure'] ?? 0;
          highestLevel = userData['level'] ?? 0;
          
          // Parse levels data (stars for each level)
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
        
        await _saveToPrefs();
        
        // Check if username needs to be updated
        if (userData['username'] != widget.username) {
          await userRef.update({'username': widget.username});
        }
        
        // Also make sure leaderboard entry exists
        await _updateLeaderboard();
      } else {
        print('No user data found, creating new profile');
        
        // Create new user data with default values
        await userRef.set({
          'username': widget.username,
          'coins': 0,
          'key': 0,
          'treasure': 0,
          'level': 1,
          'levels': List.filled(100, 0), // Initialize with 0 stars for all levels
          'platform': _getPlatform(),
          'streakCount': 0,
          'lastClaimDate': DateTime.now().subtract(Duration(days: 1)).toIso8601String(), // Allow immediate claim
        });
        
        // Create leaderboard entry
        await _updateLeaderboard();
        
        setState(() {
          isLoading = false;
        });
      }
      
      // Check if we need to migrate data from the old non-sanitized ID
      await _checkDataMigration();
    } catch (e) {
      print('Error loading player data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }
  
  Future<void> _checkDataMigration() async {
    if (_dataMigrated) return; // Only attempt migration once
    
    try {
      // Only attempt migration if we have a different sanitized ID
      final deviceId = _deviceService.deviceId;
      final sanitizedDeviceId = _deviceService.sanitizedDeviceId;
      
      // If they're the same, no migration needed
      if (deviceId == sanitizedDeviceId) return;
      
      print('Checking for data migration from $deviceId to $sanitizedDeviceId');
      
      // Check if there's data under the old non-sanitized ID
      final oldDataRef = _database.ref().child('users').child(deviceId);
      final oldDataSnapshot = await oldDataRef.get();
      
      if (oldDataSnapshot.exists) {
        print('Found data under old ID, migrating...');
        
        // Copy data to new sanitized path
        final newDataRef = _database.ref().child('users').child(sanitizedDeviceId);
        final newDataSnapshot = await newDataRef.get();
        
        // Only migrate if new location doesn't already have data
        if (!newDataSnapshot.exists) {
          final oldData = oldDataSnapshot.value as Map<dynamic, dynamic>;
          await newDataRef.set(oldData);
          
          print('Data migration complete. Updating leaderboard...');
          
          // Update username if changed
          if (oldData['username'] != widget.username) {
            await newDataRef.update({'username': widget.username});
          }
          
          // Update leaderboard
          await _updateLeaderboard();
          
          // Reload data
          await _loadPlayerData();
        }
        
        _dataMigrated = true;
      }
    } catch (e) {
      print('Error during data migration: $e');
    }
  }
  
  String _getPlatform() {
    if (Theme.of(context).platform == TargetPlatform.android) {
      return 'android';
    } else if (Theme.of(context).platform == TargetPlatform.iOS) {
      return 'ios';
    } else if (Theme.of(context).platform == TargetPlatform.windows) {
      return 'windows';
    } else if (Theme.of(context).platform == TargetPlatform.macOS) {
      return 'macos';
    } else if (Theme.of(context).platform == TargetPlatform.linux) {
      return 'linux';
    } else if (Theme.of(context).platform == TargetPlatform.fuchsia) {
      return 'fuchsia';
    }
    return 'unknown';
  }
  
  Future<void> _updateLeaderboard() async {
    try {
      // Update leaderboard with username as key
      final leaderboardRef = FirebaseDatabase.instance.ref('leaderboard/${widget.username}');
      
      // Update leaderboard with latest coin count
      await leaderboardRef.set({
        'coins': coins,
        'name': widget.username
      });
      
      print('Leaderboard updated for ${widget.username} with $coins coins');
    } catch (e) {
      print('Error updating leaderboard: $e');
    }
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('coins', coins);
    await prefs.setInt('keys', keys);
    await prefs.setInt('treasures', treasures);
    await prefs.setInt('highestLevel', highestLevel);
    
    // Store username too for easy access
    await prefs.setString('username', widget.username);
  }

  @override
  void dispose() {
    _buttonController.dispose();
    _userDataSubscription?.cancel(); // Clean up the subscription
    _audioService.stopBGM(); // Stop background music
    super.dispose();
  }

  Widget _buildDialogButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        _buttonController.forward().then((_) => _buttonController.reverse());
        _audioService.playButtonClick(); // Play button click sound
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: AnimatedBuilder(
        animation: _buttonController,
        builder: (context, child) {
          return Transform.scale(
            scale: _buttonScale.value,
            child: child,
          );
        },
        child: Container(
          width: 100,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: const Color(0xFF1A2541),
            border: Border.all(color: Color(0xFF9DC427), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9DC427).withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Vip',
              fontSize: 18,
              color: Colors.amber,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black,
                  offset: Offset(1, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final logoW = size.width * 0.25;
    final buttonW = size.width * 0.25 > 200 ? size.width * 0.25 : 200.0;

    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          width: size.width,
          height: size.height,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/background.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 10,
                right: 20,
                child: _buildIconButton(
                  onTap: () {
                    _audioService.playButtonClick(); // Play button click sound
                    HapticFeedback.mediumImpact();
                    _showLogoutConfirmationDialog();
                  },
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primaryColor, width: 2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        widget.username,
                        style: const TextStyle(
                          fontFamily: 'Vip',
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black,
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
              Positioned(
                top: 10,
                left: size.width * 0.3,
                right: size.width * 0.3,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primaryColor, width: 2),
                  ),
                  child:
                      isLoading
                          ? const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          )
                          : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatItem('🪙 $coins', 'Coins'),
                              _buildStatItem('🔑 $keys', 'Keys'),
                              _buildStatItem('📦 $treasures', 'Treasures'),
                              _buildStatItem('🏆 $highestLevel', 'Level'),
                            ],
                          ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: size.height * 0.13),
                    Image.asset(
                      'assets/images/BlasterMan.png',
                      width: logoW * 0.8,
                    ),
                    SizedBox(height: size.height * 0.02),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildMenuButton(context, 'PLAY', buttonW, () {
                          _audioService
                              .playButtonClick(); // Play button click sound
                          HapticFeedback.mediumImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LevelSelectionPage(),
                            ),
                          );
                        }),
                        const SizedBox(width: 20),
                        _buildLockedMultiplayerButton(context, buttonW),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildMenuButton(context, 'LEADERBOARD', buttonW, () {
                          _audioService
                              .playButtonClick(); // Play button click sound
                          HapticFeedback.mediumImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LeaderboardScreen(),
                            ),
                          );
                        }),
                        const SizedBox(width: 20),
                        _buildMenuButton(context, 'DAILY REWARD', buttonW, () {
                          _audioService
                              .playButtonClick(); // Play button click sound
                          HapticFeedback.mediumImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DailyLoginScreen(),
                            ),
                          ).then((result) {
                            if (result == true) {
                              // Immediately update coins from the reward result if available
                              _loadPlayerData(); // Reload player data to reflect changes
                            }
                          });
                        }),
                      ],
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

  Widget _buildIconButton({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.white.withOpacity(0.9),
            ],
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: Colors.red.shade300,
            width: 1.5,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: Icon(
                  Icons.logout_rounded, 
                  color: Colors.red.shade700, 
                  size: 26,
                ),
              ),
            ),
            // Subtle glow effect around the icon
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.transparent,
                      Colors.red.withOpacity(0.05),
                    ],
                    stops: const [0.7, 1.0],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context,
    String text,
    double width,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(35),
          color: Colors.white,
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
          border: Border.all(color: const Color(0xFF4C6229), width: 6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Vip',
              fontSize: 16,
              color: Color(0xFF384703),
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLockedMultiplayerButton(BuildContext context, double width) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Base button with gray/disabled appearance
        Container(
          width: width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(35),
            color: Colors.white.withOpacity(0.7),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 5,
                offset: Offset(0, 3),
              ),
            ],
            border: Border.all(
              color: const Color(0xFF4C6229).withOpacity(0.7),
              width: 6,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'MULTIPLAYER',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Vip',
                fontSize: 16,
                color: Color(0xFF384703),
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ),

        // Lock icon overlay
        Positioned(
          right: width * 0.05,
          top: 0,
          bottom: 0,
          child: Center(
            child: Icon(
              Icons.lock,
              color: const Color(0xFF384703).withOpacity(0.8),
              size: 22,
            ),
          ),
        ),

        // Coming soon banner
        Positioned(
          top: -10,
          right: -10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(color: Colors.orange.shade800, width: 1.5),
            ),
            child: Text(
              'COMING SOON',
              style: TextStyle(
                fontFamily: 'Vip',
                fontSize: 10,
                color: Colors.orange.shade900,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showLogoutConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            width: 300,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Color(0xFF9DC427), width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 15,
                  spreadRadius: 2,
                  offset: Offset(0, 8),
                ),
                BoxShadow(
                  color: const Color(0xFF9DC427).withOpacity(0.3),
                  blurRadius: 25,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Logout?',
                  style: TextStyle(
                    fontFamily: 'Vip',
                    fontSize: 24,
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        offset: Offset(1, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your progress is saved to the cloud',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Vip',
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildDialogButton('YES', () async {
                      HapticFeedback.mediumImpact();
                      
                      // Show loading indicator
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (BuildContext context) {
                          return Dialog(
                            backgroundColor: Colors.transparent,
                            child: Center(
                              child: Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.amber,
                                      ),
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Logging out...',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Vip',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                      
                      // Perform actual logout operations
                      try {
                        // Cancel any data subscriptions
                        await _userDataSubscription?.cancel();
                        
                        // Clear username from SharedPreferences
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('username');
                        
                        // Stop any audio that might be playing
                        await _audioService.stopBGM();
                        
                        // Close all dialogs
                        Navigator.pop(context); // Close loading dialog
                        Navigator.pop(context); // Close confirmation dialog
                        
                        // Navigate to username screen
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const SimpleUsernamePage()),
                        );
                      } catch (e) {
                        print('Error during logout: $e');
                        // Close loading dialog if there was an error
                        Navigator.pop(context);
                        Navigator.pop(context);
                        
                        // Show error message
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error during logout: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }),
                    _buildDialogButton('NO', () {
                      HapticFeedback.mediumImpact();
                      Navigator.pop(context);
                    }),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showComingSoonDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            width: 350,
            height: 230,
            decoration: BoxDecoration(
              image: const DecorationImage(
                image: AssetImage('assets/images/Frame.png'),
                fit: BoxFit.fill,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  child: const Icon(
                    Icons.rocket_launch,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'COMING SOON!',
                  style: TextStyle(
                    fontFamily: 'Vip',
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        offset: Offset(2, 2),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '$feature will be available in\nthe next update!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Vip',
                    fontSize: 16,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 20),
                _buildDialogButton('YES', () {
                  HapticFeedback.mediumImpact();
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Vip',
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Vip',
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}
