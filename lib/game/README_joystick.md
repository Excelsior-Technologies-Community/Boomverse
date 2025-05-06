# Joystick Control Implementation Guide

This guide explains how to implement the joystick control in your Blasterman game.

## Overview

The joystick implementation is based on the logic from the `MyGame.dart` file but has been separated into its own component for better reusability. It provides the following features:

- Customizable size and appearance
- Positioned on either left or right side of the screen
- Minimum movement threshold to avoid unintended inputs
- Normalized direction vectors for consistent player movement
- Fallback visuals if images can't be loaded

## Implementation

### 1. Required Files

- `joystick.dart` - The core joystick implementation
- `constants.dart` - Game constants including joystick image paths
- `joystick_controller.dart` - Example implementation of joystick usage

### 2. Integration with Your Game

#### Step 1: Add to your game screen

```dart
import 'package:flutter/material.dart';
import 'game/joystick_controller.dart';

class GameScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Your game canvas/widget here
          
          // Add joystick controller (defaults to left side)
          JoystickController(),
          
          // Or right side if needed:
          // JoystickController(rightSide: true),
        ],
      ),
    );
  }
}
```

#### Step 2: Implement player movement

In your game's update method (inside your game class), handle the joystick input:

```dart
@override
void update(double dt) {
  super.update(dt);
  
  // Check if player is alive and game is not over
  if (!gameOver && player.lives > 0) {
    // Get joystick input from the stored direction
    Vector2 moveDirection = joystickDirection;
    
    // Only move if above threshold (joystick handles this, but good to check)
    if (moveDirection.length > 0) {
      player.moveWithJoystick(moveDirection, dt);
    }
    
    // Rest of your game update logic
  }
}
```

#### Step 3: Handle player movement in your Player class

```dart
void moveWithJoystick(Vector2 direction, double dt) {
  if (direction.length < 0.1) {
    // No movement
    currentState = 'idle';
    return;
  }

  // Use move speed with delta time for smooth movement
  final delta = direction * moveSpeed * dt;
  
  // Update player position
  position.x += delta.x;
  position.y += delta.y;
  
  // Collision detection (depends on your implementation)
  handleCollisions();
  
  // Update animation state
  currentState = 'run';
  
  // Update facing direction
  if (direction.x > 0) {
    isFacingRight = true;
  } else if (direction.x < 0) {
    isFacingRight = false;
  }
}
```

### 3. Customizing Appearance

To customize the joystick appearance, edit the following in `constants.dart`:

```dart
// Joystick assets
static const String joystickKnobPath = 'assets/images/joystick_knob.png';
static const String joystickBackgroundPath = 'assets/images/joystick_background.png';
```

Make sure to add these image assets to your project and update the `pubspec.yaml` file to include them:

```yaml
assets:
  - assets/images/joystick_knob.png
  - assets/images/joystick_background.png
```

## Best Practices

1. **Position the joystick appropriately** - The joystick should be positioned to avoid interfering with important game elements.
2. **Test on different screen sizes** - Ensure the joystick works well on various device dimensions.
3. **Add settings to let users choose side** - Allow users to select which side the joystick appears on based on their preference.
4. **Disable when game is paused** - Make sure the joystick doesn't respond to input when the game is paused.

## Troubleshooting

- If the joystick is not responding, check that the `onJoystickChange` callback is properly connected to your player movement.
- If the joystick appears but the images don't load, verify the paths in `constants.dart` and ensure the images are correctly included in your assets.
- If movement feels choppy, ensure you're using the delta time (`dt`) parameter in your movement calculations for smooth motion. 