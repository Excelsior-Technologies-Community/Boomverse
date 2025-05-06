import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

class KeyboardControls {
  // Singleton pattern
  static final KeyboardControls _instance = KeyboardControls._internal();
  factory KeyboardControls() => _instance;
  KeyboardControls._internal();

  // Key configuration
  String upKey = GameConstants.defaultUpKey;
  String downKey = GameConstants.defaultDownKey;
  String leftKey = GameConstants.defaultLeftKey;
  String rightKey = GameConstants.defaultRightKey;
  String bombKey = GameConstants.defaultBombKey;

  // WASD alternative keys (automatically available)
  final String _wKey = 'KeyW';
  final String _aKey = 'KeyA';
  final String _sKey = 'KeyS';
  final String _dKey = 'KeyD';

  // Key state tracking
  final Set<LogicalKeyboardKey> _pressedKeys = {};
  
  // Focus node for key events
  final FocusNode focusNode = FocusNode();

  // Callbacks
  Function(double dx, double dy)? onDirectionChanged;
  VoidCallback? onBombPressed;

  // Initialize and load saved key configurations
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      upKey = prefs.getString('upKey') ?? GameConstants.defaultUpKey;
      downKey = prefs.getString('downKey') ?? GameConstants.defaultDownKey;
      leftKey = prefs.getString('leftKey') ?? GameConstants.defaultLeftKey;
      rightKey = prefs.getString('rightKey') ?? GameConstants.defaultRightKey;
      bombKey = prefs.getString('bombKey') ?? GameConstants.defaultBombKey;
    } catch (e) {
      // Fallback to defaults if there's an error
      resetToDefaults();
    }
  }

  // Save key configurations
  Future<void> saveKeySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('upKey', upKey);
      await prefs.setString('downKey', downKey);
      await prefs.setString('leftKey', leftKey);
      await prefs.setString('rightKey', rightKey);
      await prefs.setString('bombKey', bombKey);
    } catch (e) {
      print("Error saving keyboard settings: $e");
    }
  }

  // Reset keys to default values
  void resetToDefaults() {
    upKey = GameConstants.defaultUpKey;
    downKey = GameConstants.defaultDownKey;
    leftKey = GameConstants.defaultLeftKey;
    rightKey = GameConstants.defaultRightKey;
    bombKey = GameConstants.defaultBombKey;
  }

  // Converts a key event to its string representation
  String getKeyName(KeyEvent event) {
    // Get the key label or code
    String keyName = '';
    
    // Try to get useful representation first
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      keyName = 'ArrowUp';
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      keyName = 'ArrowDown';
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      keyName = 'ArrowLeft';
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      keyName = 'ArrowRight';
    } else if (event.logicalKey == LogicalKeyboardKey.space) {
      keyName = 'Space';
    } else if (event.logicalKey == LogicalKeyboardKey.keyW || 
               event.character?.toLowerCase() == 'w') {
      keyName = 'KeyW';
    } else if (event.logicalKey == LogicalKeyboardKey.keyA || 
               event.character?.toLowerCase() == 'a') {
      keyName = 'KeyA';
    } else if (event.logicalKey == LogicalKeyboardKey.keyS || 
               event.character?.toLowerCase() == 's') {
      keyName = 'KeyS';
    } else if (event.logicalKey == LogicalKeyboardKey.keyD || 
               event.character?.toLowerCase() == 'd') {
      keyName = 'KeyD';
    } else {
      // Try to use the key label
      keyName = event.logicalKey.keyLabel;
      
      // If the key label is empty, use the key id as a string
      if (keyName.isEmpty) {
        keyName = event.logicalKey.keyId.toString();
      }
      
      // Special handling for special keys
      if (keyName.isEmpty || keyName == 'Arrow Up') keyName = 'ArrowUp';
      if (keyName == 'Arrow Down') keyName = 'ArrowDown';
      if (keyName == 'Arrow Left') keyName = 'ArrowLeft';
      if (keyName == 'Arrow Right') keyName = 'ArrowRight';
      if (keyName == ' ') keyName = 'Space';
      
      // Handle WASD keys
      if (keyName == 'w' || keyName == 'W') keyName = 'KeyW';
      if (keyName == 'a' || keyName == 'A') keyName = 'KeyA';
      if (keyName == 's' || keyName == 'S') keyName = 'KeyS';
      if (keyName == 'd' || keyName == 'D') keyName = 'KeyD';
    }
    
    print("Key detected: $keyName from ${event.logicalKey}");
    return keyName;
  }

  // Handle key events
  bool handleKeyEvent(KeyEvent event) {
    final key = event.logicalKey;
    
    // Log key events for debugging
    print("Keyboard event: ${event.runtimeType} - Key: ${key.keyLabel}");

    // Update pressed keys set
    if (event is KeyDownEvent) {
      _pressedKeys.add(key);
      
      // Check for bomb key
      String keyName = getKeyName(event);
      if (keyName == bombKey) {
        print("Bomb key pressed: $bombKey");
        onBombPressed?.call();
        return true;
      }
    } else if (event is KeyUpEvent) {
      _pressedKeys.remove(key);
    }

    // Update direction based on currently pressed keys
    _updateDirection();
    
    // Always return true to indicate the event was handled
    return true;
  }

  // Update direction based on pressed keys
  void _updateDirection() {
    double dx = 0;
    double dy = 0;

    // Check for horizontal movement keys (including WASD alternatives)
    if (_isKeyPressed(leftKey) || _isKeyPressed(_aKey)) {
      dx = -1;
    } else if (_isKeyPressed(rightKey) || _isKeyPressed(_dKey)) {
      dx = 1;
    }

    // Check for vertical movement keys (including WASD alternatives)
    if (_isKeyPressed(upKey) || _isKeyPressed(_wKey)) {
      dy = -1;
    } else if (_isKeyPressed(downKey) || _isKeyPressed(_sKey)) {
      dy = 1;
    }

    // Normalize diagonal movement
    if (dx != 0 && dy != 0) {
      dx = dx * 0.7071; // 1/sqrt(2)
      dy = dy * 0.7071; // 1/sqrt(2)
    }

    // Notify direction change
    onDirectionChanged?.call(dx, dy);
  }

  // Check if a key is currently pressed
  bool _isKeyPressed(String keyName) {
    for (var key in _pressedKeys) {
      String currentKeyName = key.keyLabel;
      
      // Convert to standardized key names
      if (currentKeyName.isEmpty || currentKeyName == 'Arrow Up') currentKeyName = 'ArrowUp';
      if (currentKeyName == 'Arrow Down') currentKeyName = 'ArrowDown';
      if (currentKeyName == 'Arrow Left') currentKeyName = 'ArrowLeft';
      if (currentKeyName == 'Arrow Right') currentKeyName = 'ArrowRight';
      if (currentKeyName == ' ') currentKeyName = 'Space';
      
      // Handle WASD keys
      if (currentKeyName == 'w' || currentKeyName == 'W') currentKeyName = 'KeyW';
      if (currentKeyName == 'a' || currentKeyName == 'A') currentKeyName = 'KeyA';
      if (currentKeyName == 's' || currentKeyName == 'S') currentKeyName = 'KeyS';
      if (currentKeyName == 'd' || currentKeyName == 'D') currentKeyName = 'KeyD';
      
      if (currentKeyName == keyName) return true;
    }
    return false;
  }
  
  // Get human-readable key name for display
  String getDisplayKeyName(String keyName) {
    switch (keyName) {
      case 'ArrowUp': return '↑';
      case 'ArrowDown': return '↓';
      case 'ArrowLeft': return '←';
      case 'ArrowRight': return '→';
      case 'Space': return 'Space';
      case 'KeyW': return 'W';
      case 'KeyA': return 'A';
      case 'KeyS': return 'S';
      case 'KeyD': return 'D';
      default: return keyName;
    }
  }
  
  // Create a keyboard key detector widget
  Widget buildKeyDetectorWidget({required Widget child}) {
    return Focus(
      focusNode: focusNode,
      autofocus: true,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        print("Focus node key event: ${event.runtimeType} - ${event.logicalKey.keyLabel}");
        final result = handleKeyEvent(event);
        return KeyEventResult.handled;
      },
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (KeyEvent event) {
          print("KeyboardListener key event: ${event.runtimeType} - ${event.logicalKey.keyLabel}");
          handleKeyEvent(event);
        },
        child: child,
      ),
    );
  }

  // Reset pressed keys (useful when key mappings changed)
  void resetPressedKeys() {
    _pressedKeys.clear();
    // Reset direction to stop any movement
    onDirectionChanged?.call(0, 0);
  }
} 