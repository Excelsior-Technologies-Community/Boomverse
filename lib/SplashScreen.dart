import 'HomePage.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'NewLogin.dart';
import 'main.dart'; // For AppTheme

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
    print('Starting user check and navigation');

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      print('Current user: ${user?.uid ?? 'null'}');

      if (user != null) {
        try {
          print('Fetching user data from Firebase');
          final DatabaseReference userRef = FirebaseDatabase.instance.ref(
            'users/${user.uid}',
          );
          final snapshot = await userRef.get();

          String username = "Player";

          if (snapshot.exists) {
            final userData = snapshot.value as Map<dynamic, dynamic>?;
            if (userData != null && userData.containsKey('username')) {
              username = userData['username'] as String;
            }
          }

          print('Navigating to HomePage with username: $username');
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => HomePage(username: username)),
            );
          }
        } catch (e) {
          print('Error fetching user data: $e');
          _navigateToLogin();
        }
      } else {
        _navigateToLogin();
      }
    } catch (e) {
      print('Error in navigation: $e');
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    print('Navigating to login page');
    if (mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => NewLoginPage()));
    }
  }

  @override
  void dispose() {
    if (_controller != null) {
      _controller.dispose();
    }
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
