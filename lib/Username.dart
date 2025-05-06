import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'HomePage.dart';

class UsernamePage extends StatefulWidget {
  const UsernamePage({super.key});
  @override
  _UsernamePageState createState() => _UsernamePageState();
}

class _UsernamePageState extends State<UsernamePage> {
  final TextEditingController _controller = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveUsername() async {
    final username = _controller.text.trim();

    // Validate username
    if (username.isEmpty) {
      setState(() {
        _errorMessage = "Please enter a username";
      });
      return;
    }

    // Clear any previous error
    setState(() {
      _errorMessage = null;
      _isSubmitting = true;
    });

    HapticFeedback.mediumImpact();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseDatabase.instance.ref('users/${user.uid}').update({
          'username': username,
        });

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => HomePage(username: username)),
          );
        }
      } catch (e) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = "Error saving username. Please try again.";
        });
        print("Error saving username: $e");
      }
    } else {
      setState(() {
        _isSubmitting = false;
        _errorMessage = "You must be logged in to continue.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final buttonW = size.width * 0.25;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: size.width,
        height: size.height,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'USERNAME',
                    style: TextStyle(
                      fontFamily: 'Vip',
                      fontSize: 28,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                  SizedBox(height: size.height * 0.03),
                  UsernameInputField(controller: _controller),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red[400],
                          fontFamily: 'Vip',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  SizedBox(height: size.height * 0.03),
                  GestureDetector(
                    onTap: _isSubmitting ? null : _saveUsername,
                    child: Container(
                      width: buttonW * 0.75,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(35),
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 5,
                            offset: Offset(0, 3),
                          ),
                        ],
                        border: Border.all(color: Color(0xFF4C6229), width: 6),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child:
                            _isSubmitting
                                ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF384703),
                                    ),
                                  ),
                                )
                                : Text(
                                  'PLAY',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Vip',
                                    fontSize: 20,
                                    color: Color(0xFF384703),
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                      ),
                    ),
                  ),
                  SizedBox(height: size.height * 0.02),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: Text(
                        'BACK',
                        style: TextStyle(
                          fontFamily: 'Vip',
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
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
    );
  }
}

class UsernameInputField extends StatelessWidget {
  final TextEditingController controller;
  const UsernameInputField({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 45,
      width: MediaQuery.of(context).size.width * 0.45,
      child: Stack(
        children: [
          ClipPath(
            clipper: BannerClipper(),
            child: Container(color: Color(0xFF465919)),
          ),
          Positioned(
            left: 2,
            top: 2,
            right: 2,
            bottom: 2,
            child: ClipPath(
              clipper: BannerClipper(),
              child: Container(
                color: Colors.white,
                child: Row(
                  children: [
                    SizedBox(width: 45),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(5, 0, 40, 0),
                        child: TextField(
                          controller: controller,
                          style: TextStyle(
                            fontSize: 16,
                            fontFamily: 'Vip',
                            color: Colors.grey[800],
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'nickname',
                            hintStyle: TextStyle(
                              color: Colors.grey[350],
                              fontSize: 16,
                              fontFamily: 'Vip',
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF465919),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/noto_bomb.png',
                    width: 25,
                    height: 25,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BannerClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final circleRadius = size.height / 2;
    final arrowWidth = 15.0;
    path.moveTo(circleRadius, 0);
    path.lineTo(size.width - arrowWidth, 0);
    path.lineTo(size.width - 2 * arrowWidth, size.height / 2);
    path.lineTo(size.width - arrowWidth, size.height);
    path.lineTo(circleRadius, size.height);
    path.arcToPoint(
      Offset(circleRadius, 0),
      radius: Radius.circular(circleRadius),
      clockwise: false,
    );
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
