import 'HomePage.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'SimpleUsername.dart';
import 'main.dart'; // For AppTheme
import 'services/device_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _controller;
  bool _navigated = false;
  bool _isInitialized = false;
  String _errorMsg = '';
  bool _showError = false;
  final DeviceService _deviceService = DeviceService();

  @override
  void initState() {
    super.initState();
    _setupApp();
  }

  Future<void> _setupApp() async {
    try {
      await _initializeVideo();

      // Add a short timeout to ensure we navigate even if there are issues
      Future.delayed(const Duration(seconds: 5), () {
        if (!_navigated) {
          print('Timeout reached, forcing navigation');
          _handleNavigation();
        }
      });
    } catch (e) {
      print('Error in setup: $e');
      setState(() {
        _errorMsg = 'Error initializing app: $e';
        _showError = true;
      });

      // Still try to navigate after showing error
      Future.delayed(const Duration(seconds: 3), () {
        _handleNavigation();
      });
    }
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.asset(
        'assets/images/splashscreen.mp4',
      );

      await _controller.initialize();
      print('Video initialized successfully');

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }

      _controller.setLooping(false);
      await _controller.play();

      // Add listener to check video completion
      _controller.addListener(() {
        if (_controller.value.position >= _controller.value.duration) {
          print('Video completed, checking navigation');
          _handleNavigation();
        }
      });

      // Fallback timer in case video completion listener fails
      Future.delayed(_controller.value.duration + Duration(seconds: 1), () {
        print('Fallback timer triggered');
        _handleNavigation();
      });
    } catch (e) {
      print('Error initializing video: $e');
      // Continue with navigation even if video fails
      _handleNavigation();
      rethrow;
    }
  }

  void _handleNavigation() {
    if (_navigated) {
      print('Already navigated, returning');
      return;
    }
    _navigated = true;
    _checkUserAndNavigate();
  }

  Future<void> _checkUserAndNavigate() async {
    print('Starting user check with device ID');

    try {
      // Initialize deviceId
      await _deviceService.initDeviceId();
      final deviceId = _deviceService.deviceId;
      final sanitizedDeviceId = _sanitizePathSegment(deviceId); // Use the sanitize function from SimpleUsernamePage if available or re-implement

      print('Checking for user with device ID: $sanitizedDeviceId');

      // Check if user exists in database using device ID
      final userRef = FirebaseDatabase.instance.ref('users/$sanitizedDeviceId');
      final snapshot = await userRef.get();

      if (snapshot.exists) {
        final userData = snapshot.value as Map<dynamic, dynamic>;
        final username = userData['username'] as String?;

        if (username != null && username.isNotEmpty) {
          // User exists and has a username, navigate to HomePage
          print('User found with deviceId: $sanitizedDeviceId and username: $username, navigating to HomePage');
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => HomePage(username: username)),
            );
            return;
          }
        }
      }

      // If we got here, either no username or user doesn't exist in database
      print('No user found with device ID or missing username, navigating to SimpleUsernamePage');
      _navigateToUsernameScreen();
    } catch (e) {
      print('Error during user check: $e');
      _navigateToUsernameScreen();
    }
  }

  // This function would ideally be in a shared utility or base class
  // Re-implementing here for demonstration purposes based on SimpleUsername.dart
  String _sanitizePathSegment(String path) {
    return path.replaceAll('.', '_')
        .replaceAll('#', '_')
        .replaceAll('\$', '_').replaceAll('[', '_').replaceAll(']', '_');
  }

  void _navigateToUsernameScreen() {
    print('Navigating to username page');
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => SimpleUsernamePage()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Video player
          _isInitialized
              ? FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller.value.size.width,
              height: _controller.value.size.height,
              child: VideoPlayer(_controller),
            ),
          )
              : Container(
            color: AppTheme.backgroundColor,
            child: Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            ),
          ),

          // Error message if needed
          if (_showError)
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                color: Colors.red.withOpacity(0.8),
                child: Text(
                  _errorMsg,
                  style: TextStyle(color: Colors.white, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
