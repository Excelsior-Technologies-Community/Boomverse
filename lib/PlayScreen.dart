import 'package:flutter/material.dart';
import 'game/game_screen.dart';

class PlayScreen extends StatelessWidget {
  const PlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: GameScreen(),
    );
  }
} 