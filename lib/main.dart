import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'SplashScreen.dart';

// Define app-wide theme constants
class AppTheme {
  // Colors
  static const Color primaryColor = Color(0xFF4C6229);
  static const Color secondaryColor = Color(0xFF384703);
  static const Color backgroundColor = Color(0xFF1A472A);
  static const Color textColor = Colors.white;
  static const Color buttonTextColor = Color(0xFF384703);

  // Text Styles
  static const TextStyle headingStyle = TextStyle(
    fontFamily: 'Vip',
    fontSize: 28,
    color: textColor,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.5,
    shadows: [
      Shadow(color: Colors.black54, offset: Offset(2, 2), blurRadius: 3),
    ],
  );

  static const TextStyle buttonStyle = TextStyle(
    fontFamily: 'Vip',
    fontSize: 20,
    color: buttonTextColor,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.0,
  );

  static const TextStyle gameTextStyle = TextStyle(
    fontFamily: 'PressStart2P',
    color: Colors.white,
    fontSize: 12,
    shadows: [Shadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 2)],
  );

  // Button Decoration
  static BoxDecoration buttonDecoration = BoxDecoration(
    borderRadius: BorderRadius.circular(35),
    color: Colors.white,
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.3),
        blurRadius: 5,
        offset: Offset(0, 3),
      ),
    ],
    border: Border.all(color: primaryColor, width: 6),
  );
}

void main() async {
  // This ensures Flutter is initialized correctly before we do anything else
  WidgetsFlutterBinding.ensureInitialized();

  // Set orientation to landscape
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  // Hide system UI
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Initialize Firebase with error handling
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully');
  } catch (e) {
    print('Error initializing Firebase: $e');
    // Continue with app startup even if Firebase fails
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blasterman Game',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
