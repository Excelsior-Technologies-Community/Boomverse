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

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  void _initializeVideo() async {
    try {
      _controller = VideoPlayerController.asset(
        'assets/images/splashscreen.mp4',
      );

      await _controller.initialize();
      print('Video initialized successfully');

      setState(() {
        _isInitialized = true;
      });

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
      _handleNavigation();
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

          // Loading indicator at bottom
          if (!_isInitialized || !_controller.value.isPlaying)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'LOADING...',
                  style: AppTheme.headingStyle.copyWith(fontSize: 18),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
