import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'HomePage.dart';
import 'services/device_service.dart';
import 'services/audio_service.dart';
import 'dart:async';

class SimpleUsernamePage extends StatefulWidget {
  const SimpleUsernamePage({super.key});

  @override
  _SimpleUsernamePageState createState() => _SimpleUsernamePageState();
}

class _SimpleUsernamePageState extends State<SimpleUsernamePage> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;
  final DeviceService _deviceService = DeviceService();
  final AudioService _audioService = AudioService();

  late AnimationController _buttonAnimationController;
  late Animation<double> _buttonScaleAnimation;

  @override
  void initState() {
    super.initState();

    _buttonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _buttonAnimationController, curve: Curves.easeInOut),
    );

    _initAudio();
    _initializeDeviceService();
    _checkForExistingUsername();
    _checkForLegacyAccount();
  }

  Future<void> _initAudio() async {
    await _audioService.init();
    await _audioService.playBGM();
  }

  Future<void> _initializeDeviceService() async {
    try {
      if (!_deviceService.isInitialized) {
        await _deviceService.initDeviceId();
        print('Device ID initialized: ${_deviceService.deviceId}');
      }
    } catch (e) {
      print('Error initializing device service: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _buttonAnimationController.dispose();
    super.dispose();
  }

  Future<void> _checkForExistingUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('username');

    if (savedUsername != null && savedUsername.isNotEmpty) {
      _controller.text = savedUsername;
    }
  }

  String _sanitizePathSegment(String path) {
    return path.replaceAll('.', '_')
        .replaceAll('#', '_')
        .replaceAll('\$', '_')
        .replaceAll('[', '_')
        .replaceAll(']', '_');
  }

  Future<void> _checkForLegacyAccount() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        print('Found legacy account: ${currentUser.uid}');
        setState(() {
          _isSubmitting = true;
        });

        await _deviceService.initDeviceId();
        final deviceId = _deviceService.deviceId;
        final sanitizedDeviceId = _sanitizePathSegment(deviceId);

        final legacyUserRef = FirebaseDatabase.instance.ref('users/${currentUser.uid}');
        final snapshot = await legacyUserRef.get();

        if (snapshot.exists) {
          final userData = snapshot.value as Map<dynamic, dynamic>;
          final username = userData['username'] as String? ?? 'Player';

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('username', username);

          setState(() {
            _controller.text = username;
          });

          final userRef = FirebaseDatabase.instance.ref('users/$sanitizedDeviceId');
          await userRef.set(userData);

          final leaderboardRef = FirebaseDatabase.instance.ref('leaderboard/$username');
          await leaderboardRef.set({
            'coins': userData['coins'] ?? 0,
            'name': username,
            'deviceId': sanitizedDeviceId,
          });

          setState(() {
            _isSubmitting = false;
            _successMessage = "Account migration completed!";
          });

          Timer(Duration(seconds: 2), () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => HomePage(username: username)),
            );
          });
        } else {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    } catch (e) {
      print('Error checking for legacy account: $e');
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _saveUsername() async {
    _audioService.playButtonClick();

    final username = _controller.text.trim();

    if (username.isEmpty) {
      setState(() {
        _errorMessage = "Please enter a username";
      });
      return;
    }

    if (username.length < 3) {
      setState(() {
        _errorMessage = "Username must be at least 3 characters";
      });
      return;
    }

    if (username.length > 12) {
      setState(() {
        _errorMessage = "Username must be at most 12 characters";
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _successMessage = null;
      _isSubmitting = true;
    });

    HapticFeedback.mediumImpact();

    try {
      if (!_deviceService.isInitialized) {
        await _deviceService.initDeviceId();
      }
      final deviceId = _deviceService.deviceId;
      final sanitizedDeviceId = _sanitizePathSegment(deviceId);

      print('Current device ID: $sanitizedDeviceId');

      final leaderboardRef = FirebaseDatabase.instance.ref('leaderboard/$username');
      final leaderboardSnapshot = await leaderboardRef.get();

      if (leaderboardSnapshot.exists) {
        final userData = leaderboardSnapshot.value as Map<dynamic, dynamic>;
        final String? associatedDeviceId = userData['deviceId']?.toString();
        print('Associated device ID for $username: $associatedDeviceId');

        if (associatedDeviceId != null && associatedDeviceId != sanitizedDeviceId) {
          print('Device IDs do not match: $associatedDeviceId != $sanitizedDeviceId');
          setState(() {
            _isSubmitting = false;
            _errorMessage = "This username is already taken by another device. Please try another.";
          });
          return;
        }
        print('Username $username is available or belongs to this device');
      } else {
        print('Username $username is new and available');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', username);
      print('Username saved to preferences: $username');

      String platform = 'unknown';
      if (Theme.of(context).platform == TargetPlatform.android) {
        platform = 'android';
      } else if (Theme.of(context).platform == TargetPlatform.iOS) {
        platform = 'ios';
      } else if (Theme.of(context).platform == TargetPlatform.windows) {
        platform = 'windows';
      } else if (Theme.of(context).platform == TargetPlatform.macOS) {
        platform = 'macos';
      } else if (Theme.of(context).platform == TargetPlatform.linux) {
        platform = 'linux';
      } else if (Theme.of(context).platform == TargetPlatform.fuchsia) {
        platform = 'fuchsia';
      }

      final now = DateTime.now().toIso8601String();
      final userRef = FirebaseDatabase.instance.ref('users/$sanitizedDeviceId');
      print('User reference path: ${userRef.path}');

      try {
        final userSnapshot = await userRef.get();

        if (!userSnapshot.exists) {
          print('Creating new user data for $username with device ID $sanitizedDeviceId');
          await userRef.set({
            'username': username,
            'coins': 0,
            'level': 1,
            'levels': List.filled(100, 0),
            'platform': platform,
            'streakCount': 1,
            'treasure': 0,
            'key': 0,
            'lastClaimDate': now,
          });
        } else {
          print('Updating existing user data with new username: $username');
          await userRef.update({
            'username': username,
          });
        }

        final userData = userSnapshot.exists
            ? (userSnapshot.value as Map<dynamic, dynamic>)
            : {'coins': 0};
        final coins = userData['coins'] ?? 0;

        print('Updating leaderboard for $username');
        await leaderboardRef.set({
          'coins': coins,
          'name': username,
          'deviceId': sanitizedDeviceId,
        });

        print('Username saved successfully!');

        setState(() {
          _isSubmitting = false;
          _successMessage = "Username saved successfully!";
        });

        _audioService.playVictory();

        Timer(Duration(milliseconds: 800), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => HomePage(username: username)),
            );
          }
        });
      } catch (dbError) {
        print('Database error: $dbError');
        setState(() {
          _isSubmitting = false;
          _errorMessage = "Database error. Please try again.";
        });
      }
    } catch (e) {
      print("Error saving username: $e");
      setState(() {
        _isSubmitting = false;
        _errorMessage = "Error saving username. Please try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final bool isSmallDevice = size.height < 600;
    final bool isWebPlatform = size.width > 650;

    final double logoHeight = isSmallDevice
        ? size.height * 0.10
        : isWebPlatform
        ? size.height * 0.20
        : size.height * 0.15;
    final double fontSize = isSmallDevice
        ? 16.0
        : isWebPlatform
        ? 24.0
        : 20.0;
    final double buttonHeight = isSmallDevice
        ? 40.0
        : isWebPlatform
        ? 60.0
        : 50.0;
    final double contentWidth = isWebPlatform
        ? size.width * 0.5
        : size.width * 0.85;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                      horizontal: isWebPlatform ? 48 : 16,
                      vertical: isSmallDevice ? 10 : 20
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 600,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isKeyboardVisible)
                          Image.asset(
                            'assets/images/BlasterMan.png',
                            height: logoHeight,
                          ),
                        SizedBox(height: isSmallDevice ? 10 : 20),
                        if (!isKeyboardVisible || isWebPlatform)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Text(
                              'WELCOME TO BOOMVERSE',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Vip',
                                fontSize: fontSize + 2,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: Color(0xFF7AC74C),
                                    offset: Offset(1, 1),
                                    blurRadius: 4,
                                  ),
                                  Shadow(
                                    color: Colors.black,
                                    offset: Offset(1, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Container(
                          width: contentWidth,
                          padding: EdgeInsets.all(isSmallDevice ? 12 : 16),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Color(0xFF7AC74C),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF7AC74C).withOpacity(0.3),
                                blurRadius: 15,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                'ENTER YOUR NICKNAME',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Vip',
                                  fontSize: fontSize * 0.7,
                                  color: Color(0xFF7AC74C),
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
                              SizedBox(height: isSmallDevice ? 10 : 16),
                              Container(
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xFF7AC74C).withOpacity(0.5),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Container(
                                  height: isSmallDevice ? 40 : 50,
                                  padding: EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF8FB448),
                                        Color(0xFF7AC74C),
                                        Color(0xFF4C6229),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                    child: TextField(
                                      controller: _controller,
                                      style: TextStyle(
                                        fontSize: isSmallDevice ? 16 : 18,
                                        fontFamily: 'Vip',
                                        color: Colors.grey[800],
                                        fontWeight: FontWeight.bold,
                                      ),
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        hintText: 'Enter nickname',
                                        hintStyle: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: isSmallDevice ? 14 : 16,
                                          fontFamily: 'Vip',
                                        ),
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: isSmallDevice ? 8 : 12
                                        ),
                                      ),
                                      maxLength: 12,
                                      textAlign: TextAlign.center,
                                      textCapitalization: TextCapitalization.words,
                                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: isSmallDevice ? 8 : 12),
                              AnimatedSwitcher(
                                duration: Duration(milliseconds: 300),
                                child: _errorMessage != null
                                    ? Container(
                                  key: ValueKey('error'),
                                  padding: EdgeInsets.symmetric(
                                      vertical: isSmallDevice ? 6 : 8,
                                      horizontal: isSmallDevice ? 8 : 12
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.red.withOpacity(0.5)),
                                  ),
                                  child: Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Vip',
                                      fontSize: isSmallDevice ? 12 : 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                                    : _successMessage != null
                                    ? Container(
                                  key: ValueKey('success'),
                                  padding: EdgeInsets.symmetric(
                                      vertical: isSmallDevice ? 6 : 8,
                                      horizontal: isSmallDevice ? 8 : 12
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green.withOpacity(0.5)),
                                  ),
                                  child: Text(
                                    _successMessage!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Vip',
                                      fontSize: isSmallDevice ? 12 : 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                                    : SizedBox(
                                    height: isSmallDevice ? 30 : 40,
                                    key: ValueKey('empty')
                                ),
                              ),
                              SizedBox(height: isSmallDevice ? 10 : 16),
                              GestureDetector(
                                onTap: _isSubmitting ? null : _saveUsername,
                                onTapDown: (_) => _buttonAnimationController.forward(),
                                onTapUp: (_) => _buttonAnimationController.reverse(),
                                onTapCancel: () => _buttonAnimationController.reverse(),
                                child: AnimatedBuilder(
                                  animation: _buttonAnimationController,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: _buttonScaleAnimation.value,
                                      child: child,
                                    );
                                  },
                                  child: Container(
                                    width: isWebPlatform
                                        ? 200
                                        : isSmallDevice
                                        ? 150
                                        : 180,
                                    height: buttonHeight,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFF8FB448),
                                          Color(0xFF7AC74C),
                                          Color(0xFF4C6229),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(buttonHeight / 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0xFF7AC74C).withOpacity(0.5),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                          offset: Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: _isSubmitting
                                          ? SizedBox(
                                        height: isSmallDevice ? 20 : 24,
                                        width: isSmallDevice ? 20 : 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                          : Text(
                                        'START GAME',
                                        style: TextStyle(
                                          fontFamily: 'Vip',
                                          fontSize: isSmallDevice
                                              ? 16
                                              : isWebPlatform
                                              ? 22
                                              : 18,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.0,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black.withOpacity(0.5),
                                              offset: Offset(1, 1),
                                              blurRadius: 2,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isKeyboardVisible || isWebPlatform)
                          Padding(
                            padding: EdgeInsets.only(
                                top: isSmallDevice ? 12 : 20,
                                bottom: isSmallDevice ? 8 : 16
                            ),
                            child: Wrap(
                              spacing: isSmallDevice ? 8 : 16,
                              runSpacing: isSmallDevice ? 8 : 16,
                              alignment: WrapAlignment.center,
                              children: [
                                _gameFeatureItem(
                                  'assets/images/bomb.png',
                                  'PLANT BOMBS',
                                  isSmallDevice: isSmallDevice,
                                ),
                                _gameFeatureItem(
                                  'assets/images/enemy/idle/1.png',
                                  'DEFEAT ENEMIES',
                                  isSmallDevice: isSmallDevice,
                                ),
                                _gameFeatureItem(
                                  'assets/images/coin.png',
                                  'COLLECT COINS',
                                  isSmallDevice: isSmallDevice,
                                ),
                                _gameFeatureItem(
                                  'assets/images/treasure.png',
                                  'FIND TREASURES',
                                  isSmallDevice: isSmallDevice,
                                ),
                              ],
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
    );
  }

  Widget _gameFeatureItem(String imagePath, String text, {bool isSmallDevice = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isSmallDevice ? 8 : 12,
          vertical: isSmallDevice ? 6 : 8
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Color(0xFF7AC74C).withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            imagePath,
            width: isSmallDevice ? 16 : 20,
            height: isSmallDevice ? 16 : 20,
          ),
          SizedBox(width: isSmallDevice ? 5 : 8),
          Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Vip',
              fontSize: isSmallDevice ? 10 : 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}