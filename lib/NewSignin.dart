import 'dart:io';
import 'Username.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'NewLogin.dart';
import 'main.dart';

class NewSignUpPage extends StatefulWidget {
  const NewSignUpPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<NewSignUpPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _onSignUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    HapticFeedback.lightImpact();
    final email = _email.text.trim();
    final password = _password.text.trim();

    try {
      print('Attempting to create user with email: $email');
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('User created successfully with UID: ${cred.user?.uid}');

      final uid = cred.user!.uid;

      String platform;
      if (kIsWeb) {
        platform = 'web';
      } else if (Platform.isAndroid) {
        platform = 'android';
      } else if (Platform.isIOS) {
        platform = 'ios';
      } else {
        platform = 'unknown';
      }

      print('Setting up user data in database for UID: $uid');
      await FirebaseDatabase.instance.ref('users/$uid').set({
        'email': email,
        'platform': platform,
        'coins': 0,
        'key': 0,
        'treasure': 0,
        'level': 1,
        'levels': List.filled(100, 0),
      });
      print('User data set up successfully');

      if (mounted) {
        print('Navigating to UsernamePage');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => UsernamePage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException during signup: ${e.code} - ${e.message}');
      String errorMessage;
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'The password provided is too weak';
          break;
        case 'email-already-in-use':
          errorMessage = 'An account already exists with this email';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is invalid';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email/password accounts are not enabled';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your internet connection';
          break;
        default:
          errorMessage = 'An error occurred during signup: ${e.message}';
      }
      setState(() {
        _errorMessage = errorMessage;
        _isLoading = false;
      });
    } catch (e) {
      print('Unexpected error during signup: $e');
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
        _isLoading = false;
      });
    }
  }

  Widget _buildInputField({
    required String hint,
    required TextEditingController controller,
    bool isPassword = false,
    TextInputType? keyboardType,
    required double fontScale,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        style: TextStyle(
          fontFamily: 'Vip',
          fontSize: (16 * fontScale).clamp(14, 18),
          color: Colors.white,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontFamily: 'Vip',
            fontSize: (16 * fontScale).clamp(14, 18),
            color: Colors.white.withOpacity(0.7),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $hint';
          }
          if (hint == 'EMAIL' && !value.contains('@')) {
            return 'Please enter a valid email';
          }
          if (hint == 'PASSWORD' && value.length < 6) {
            return 'Password must be at least 6 characters';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildSignUpButton({
    required double fontScale,
    required BoxConstraints constraints,
  }) {
    return GestureDetector(
      onTap: _isLoading ? null : _onSignUp,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: constraints.maxHeight * 0.02),
        decoration: AppTheme.buttonDecoration,
        child: Center(
          child:
              _isLoading
                  ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: AppTheme.buttonTextColor,
                      strokeWidth: 2,
                    ),
                  )
                  : Text(
                    'SIGN UP',
                    style: AppTheme.buttonStyle.copyWith(
                      fontSize: (20 * fontScale).clamp(16, 24),
                    ),
                  ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MediaQuery.of(context).size;
        final double maxContainerWidth = constraints.maxWidth * 0.5;
        final double minContainerWidth = 300.0;
        final double containerWidth =
            (maxContainerWidth > minContainerWidth)
                ? maxContainerWidth
                : minContainerWidth.clamp(300, constraints.maxWidth * 0.9);

        final double logoHeight = constraints.maxHeight * 0.15;
        final double fontScale = constraints.maxHeight / 600;

        return Scaffold(
          resizeToAvoidBottomInset: true,
          body: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/background.png',
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Image.asset(
                  'assets/images/BlasterMan.png',
                  height: logoHeight.clamp(50, 100),
                ),
              ),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: constraints.maxWidth * 0.05,
                      vertical: constraints.maxHeight * 0.05,
                    ),
                    child: Form(
                      key: _formKey,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: containerWidth),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: constraints.maxHeight * 0.03,
                            horizontal: constraints.maxWidth * 0.05,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'SIGN UP',
                                style: TextStyle(
                                  fontFamily: 'Vip',
                                  fontSize: (30 * fontScale).clamp(20, 40),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 2,
                                ),
                              ),
                              SizedBox(height: constraints.maxHeight * 0.02),
                              if (_errorMessage != null)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Vip',
                                      fontSize: (14 * fontScale).clamp(12, 16),
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              if (_errorMessage != null)
                                SizedBox(height: constraints.maxHeight * 0.04),
                              _buildInputField(
                                hint: 'EMAIL',
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                fontScale: fontScale,
                              ),
                              SizedBox(height: constraints.maxHeight * 0.04),
                              _buildInputField(
                                hint: 'PASSWORD',
                                controller: _password,
                                isPassword: true,
                                fontScale: fontScale,
                              ),
                              SizedBox(height: constraints.maxHeight * 0.04),
                              _buildSignUpButton(
                                fontScale: fontScale,
                                constraints: constraints,
                              ),
                              SizedBox(height: constraints.maxHeight * 0.04),
                              TextButton(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const NewLoginPage(),
                                    ),
                                  );
                                },
                                child: Text(
                                  "ALREADY HAVE AN ACCOUNT? SIGN IN",
                                  style: TextStyle(
                                    fontFamily: 'Vip',
                                    fontSize: (12 * fontScale).clamp(10, 14),
                                    color: Color(0xFFD4AF37),
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
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
