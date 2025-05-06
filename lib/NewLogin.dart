import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'HomePage.dart';
import 'NewSignin.dart';
import 'main.dart';

class NewLoginPage extends StatefulWidget {
  const NewLoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<NewLoginPage> {
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

  Future<void> _onLogin() async {
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
      print('Attempting to sign in with email: $email');
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('User signed in successfully with UID: ${cred.user?.uid}');

      final uid = cred.user!.uid;

      print('Fetching user data from database for UID: $uid');
      final databaseRef = FirebaseDatabase.instance.ref('users/$uid');
      final snapshot = await databaseRef.get();
      String username = "Player";

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>?;
        if (data != null && data.containsKey('username')) {
          username = data['username'] as String;
        }
      }
      print('User data fetched successfully. Username: $username');

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

      print('Updating platform information');
      await databaseRef.update({'platform': platform});
      print('Platform information updated successfully');

      if (mounted) {
        print('Navigating to HomePage');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage(username: username)),
        );
      }
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException during login: ${e.code} - ${e.message}');
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email';
          break;
        case 'wrong-password':
          errorMessage = 'Wrong password provided';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is invalid';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your internet connection';
          break;
        default:
          errorMessage = 'An error occurred during login: ${e.message}';
      }
      setState(() {
        _errorMessage = errorMessage;
        _isLoading = false;
      });
    } catch (e) {
      print('Unexpected error during login: $e');
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

  Widget _buildLoginButton({
    required double fontScale,
    required BoxConstraints constraints,
  }) {
    return GestureDetector(
      onTap: _isLoading ? null : _onLogin,
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
                    'LOGIN',
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
              child: Stack(
                children: [
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
                            constraints: BoxConstraints(
                              maxWidth: containerWidth,
                            ),
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
                                    'LOGIN',
                                    style: TextStyle(
                                      fontFamily: 'Vip',
                                      fontSize: (30 * fontScale).clamp(20, 40),
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  SizedBox(
                                    height: constraints.maxHeight * 0.02,
                                  ),
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
                                          fontSize: (14 * fontScale).clamp(
                                            12,
                                            16,
                                          ),
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  if (_errorMessage != null)
                                    SizedBox(
                                      height: constraints.maxHeight * 0.04,
                                    ),
                                  _buildInputField(
                                    hint: 'EMAIL',
                                    controller: _email,
                                    keyboardType: TextInputType.emailAddress,
                                    fontScale: fontScale,
                                  ),
                                  SizedBox(
                                    height: constraints.maxHeight * 0.04,
                                  ),
                                  _buildInputField(
                                    hint: 'PASSWORD',
                                    controller: _password,
                                    isPassword: true,
                                    fontScale: fontScale,
                                  ),
                                  SizedBox(
                                    height: constraints.maxHeight * 0.04,
                                  ),
                                  _buildLoginButton(
                                    fontScale: fontScale,
                                    constraints: constraints,
                                  ),
                                  SizedBox(
                                    height: constraints.maxHeight * 0.02,
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const NewSignUpPage(),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      "DON'T HAVE AN ACCOUNT? SIGN UP",
                                      style: TextStyle(
                                        fontFamily: 'Vip',
                                        fontSize: (12 * fontScale).clamp(
                                          10,
                                          14,
                                        ),
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
            ),
          ),
        );
      },
    );
  }
}
