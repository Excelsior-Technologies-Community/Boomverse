import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/audio_service.dart';
import 'game/constants.dart';
import 'game/keyboard_controls.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class PauseMenu extends StatefulWidget {
  final int level;
  final VoidCallback onResume;
  final VoidCallback onExit;
  final Function(bool joystickOnLeft) onControlsChanged;
  final Function(String controlType) onControlTypeChanged;
  final bool joystickOnLeft;
  final String controlType;
  final KeyboardControls keyboardControls;

  const PauseMenu({
    super.key,
    required this.level,
    required this.onResume,
    required this.onExit,
    required this.onControlsChanged,
    required this.joystickOnLeft,
    required this.onControlTypeChanged,
    required this.controlType,
    required this.keyboardControls,
  });

  @override
  _PauseMenuState createState() => _PauseMenuState();
}

class _PauseMenuState extends State<PauseMenu> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  
  // Settings values
  bool _sfxEnabled = true;
  bool _bgmEnabled = true;
  double _sfxVolume = 0.7;
  double _bgmVolume = 0.5;
  bool _joystickOnLeft = true;
  String _controlType = GameConstants.controlTypeTouch;
  
  // Key mapping
  late String _upKey;
  late String _downKey;
  late String _leftKey;
  late String _rightKey;
  late String _bombKey;
  
  // Key remapping state
  bool _isRemappingKey = false;
  String? _keyBeingRemapped;
  
  // Pages
  int _currentPage = 0; // 0 = main, 1 = settings, 2 = keyboard settings
  
  final AudioService _audioService = AudioService();

  // Add a member variable for a dedicated focus node for key remapping
  late FocusNode _keyRemappingFocusNode;

  @override
  void initState() {
    super.initState();
    _joystickOnLeft = widget.joystickOnLeft;
    _controlType = widget.controlType;
    _loadSettings();
    
    // Load keyboard settings
    _upKey = widget.keyboardControls.upKey;
    _downKey = widget.keyboardControls.downKey;
    _leftKey = widget.keyboardControls.leftKey;
    _rightKey = widget.keyboardControls.rightKey;
    _bombKey = widget.keyboardControls.bombKey;
    
    // Initialize focus node for key remapping
    _keyRemappingFocusNode = FocusNode();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    
    _animationController.forward();
  }
  
  Future<void> _loadSettings() async {
    await _audioService.init();
    setState(() {
      _sfxEnabled = _audioService.sfxEnabled;
      _bgmEnabled = _audioService.bgmEnabled;
      _sfxVolume = _audioService.sfxVolume;
      _bgmVolume = _audioService.bgmVolume;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _keyRemappingFocusNode.dispose();
    super.dispose();
  }
  
  void _handleResume() {
    _audioService.playButtonClick();
    HapticFeedback.mediumImpact();
    widget.onResume();
  }
  
  void _handleExit() {
    _audioService.playButtonClick();
    HapticFeedback.mediumImpact();
    widget.onExit();
  }
  
  void _goToSettings() {
    _audioService.playButtonClick();
    HapticFeedback.mediumImpact();
    setState(() {
      _currentPage = 1;
    });
  }
  
  void _goToKeyboardSettings() {
    _audioService.playButtonClick();
    HapticFeedback.mediumImpact();
    setState(() {
      _currentPage = 2;
    });
  }
  
  void _goToMain() {
    _audioService.playButtonClick();
    HapticFeedback.mediumImpact();
    setState(() {
      _currentPage = 0;
    });
  }
  
  void _saveSettings() {
    _audioService.sfxEnabled = _sfxEnabled;
    _audioService.bgmEnabled = _bgmEnabled;
    _audioService.sfxVolume = _sfxVolume;
    _audioService.bgmVolume = _bgmVolume;
    
    // Apply control changes
    if (_joystickOnLeft != widget.joystickOnLeft) {
      widget.onControlsChanged(_joystickOnLeft);
    }
    
    // Apply control type changes
    if (_controlType != widget.controlType) {
      widget.onControlTypeChanged(_controlType);
    }
    
    _goToMain();
  }
  
  void _saveKeyboardSettings() {
    print("Saving keyboard settings...");
    print("Up key: $_upKey");
    print("Down key: $_downKey");
    print("Left key: $_leftKey");
    print("Right key: $_rightKey");
    print("Bomb key: $_bombKey");

    // Update keyboard control settings
    widget.keyboardControls.upKey = _upKey;
    widget.keyboardControls.downKey = _downKey;
    widget.keyboardControls.leftKey = _leftKey;
    widget.keyboardControls.rightKey = _rightKey;
    widget.keyboardControls.bombKey = _bombKey;
    
    // Save the settings
    widget.keyboardControls.saveKeySettings().then((_) {
      print("Settings saved successfully!");
      
      // Add haptic feedback
      HapticFeedback.mediumImpact();
      
      // Show a quick confirmation message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Keyboard controls updated!'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.green,
        ),
      );
      
      // Ensure the keyboard controls are immediately applied
      widget.keyboardControls.resetPressedKeys();
    });
    
    // Return to settings page
    setState(() {
      _currentPage = 1;
      _isRemappingKey = false;
      _keyBeingRemapped = null;
    });
  }
  
  void _startRemappingKey(String keyType) {
    // Add haptic feedback to indicate entering remapping mode
    HapticFeedback.selectionClick();
    
    // Focus on the remapping node
    Future.delayed(Duration(milliseconds: 50), () {
      setState(() {
        _isRemappingKey = true;
        _keyBeingRemapped = keyType;
        
        // Log for debugging
        print("Started remapping key: $keyType");
        print("Press any key to assign to $_keyBeingRemapped");
      });
      
      // Request focus after state change
      _keyRemappingFocusNode.requestFocus();
    });
  }
  
  void _handleKeyPress(KeyEvent event) {
    if (!_isRemappingKey || _keyBeingRemapped == null) return;
    
    // Log key press for debugging
    print("Key pressed: ${event.logicalKey.keyLabel}");
    
    // Get the key name
    String keyName = widget.keyboardControls.getKeyName(event);
    print("Key name mapped to: $keyName");
    
    // Update the key being remapped
    setState(() {
      switch (_keyBeingRemapped) {
        case 'up':
          _upKey = keyName;
          break;
        case 'down':
          _downKey = keyName;
          break;
        case 'left':
          _leftKey = keyName;
          break;
        case 'right':
          _rightKey = keyName;
          break;
        case 'bomb':
          _bombKey = keyName;
          break;
      }
      
      // End remapping mode
      _isRemappingKey = false;
      _keyBeingRemapped = null;
      
      // Add haptic feedback to confirm the remapping
      HapticFeedback.mediumImpact();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    
    // Check if we're on web platform for UI adjustments
    final isWebPlatform = kIsWeb;
    
    // Calculate scale factor based on screen width and platform
    // Reduce scale to fix overflowing text issue
    double scaleFactor;
    if (isWebPlatform) {
      scaleFactor = isLandscape ? (size.width / 1600) * 0.65 : 0.65;
    } else {
      scaleFactor = isLandscape ? (size.width / 1400) * 0.85 : 0.85;
    }
    
    // Calculate container width with 20% increase and ensure it's not too large for small screens
    double maxWidth = size.width * 0.8;
    double containerWidth = isWebPlatform ? 420 * scaleFactor : 360 * scaleFactor;
    containerWidth = containerWidth > maxWidth ? maxWidth : containerWidth;
    
    return Focus(
      focusNode: _isRemappingKey ? _keyRemappingFocusNode : null,
      autofocus: _isRemappingKey,
      onKeyEvent: (node, event) {
        print("PauseMenu Focus key event: ${event.runtimeType} - ${event.logicalKey.keyLabel}");
        if (event is KeyDownEvent && _isRemappingKey) {
          _handleKeyPress(event);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Center(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: containerWidth, // Increased width
                padding: EdgeInsets.all(20 * scaleFactor),
                decoration: BoxDecoration(
                  color: isWebPlatform 
                    ? const Color(0xFF2D2B39).withOpacity(0.95)
                    : Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isWebPlatform 
                      ? const Color(0xFFD1A758)
                      : const Color(0xFF7AC74C),
                    width: isWebPlatform ? 3 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isWebPlatform
                        ? const Color(0xFFD1A758).withOpacity(0.3)
                        : const Color(0xFF7AC74C).withOpacity(0.3),
                      blurRadius: isWebPlatform ? 15 : 10,
                      spreadRadius: isWebPlatform ? 3 : 2,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  physics: NeverScrollableScrollPhysics(), // Prevent scrolling but allow content to be properly sized
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: size.height * 0.8, // Limit height to prevent overflow
                    ),
                    child: _currentPage == 0
                        ? _buildMainMenu(scaleFactor, isWebPlatform)
                        : _currentPage == 1 
                            ? _buildSettingsMenu(scaleFactor, isWebPlatform)
                            : _buildKeyboardSettingsMenu(scaleFactor, isWebPlatform),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildMainMenu(double scaleFactor, bool isWebPlatform) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title
        Text(
          'GAME PAUSED',
          style: TextStyle(
            fontFamily: 'Vip',
            fontSize: isWebPlatform ? 28 * scaleFactor : 24 * scaleFactor,
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            shadows: [
              Shadow(
                color: isWebPlatform ? const Color(0xFFD1A758) : const Color(0xFF7AC74C),
                offset: Offset(0, 2),
                blurRadius: 5,
              ),
            ],
          ),
        ),
        
        SizedBox(height: 10 * scaleFactor),
        
        // Level info
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 16 * scaleFactor, 
            vertical: 6 * scaleFactor
          ),
          decoration: BoxDecoration(
            color: isWebPlatform ? const Color(0xFF1E1C29) : Colors.black38,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isWebPlatform ? const Color(0xFFD1A758).withOpacity(0.5) : Colors.white30,
              width: isWebPlatform ? 2 : 1,
            ),
          ),
          child: Text(
            'LEVEL ${widget.level}',
            style: TextStyle(
              fontFamily: 'Vip',
              fontSize: 16 * scaleFactor,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        
        SizedBox(height: 25 * scaleFactor),
        
        // Resume button
        _buildButton(
          icon: Icons.play_arrow,
          label: 'RESUME',
          color: isWebPlatform ? const Color(0xFFD1A758) : const Color(0xFF7AC74C),
          onTap: _handleResume,
          scaleFactor: scaleFactor,
          isWebPlatform: isWebPlatform,
        ),
        
        SizedBox(height: 15 * scaleFactor),
        
        // Settings button
        _buildButton(
          icon: Icons.settings,
          label: 'SETTINGS',
          color: Colors.amber,
          onTap: _goToSettings,
          scaleFactor: scaleFactor,
          isWebPlatform: isWebPlatform,
        ),
        
        SizedBox(height: 15 * scaleFactor),
        
        // Exit button
        _buildButton(
          icon: Icons.exit_to_app,
          label: 'EXIT',
          color: const Color(0xFFE74C3C),
          onTap: _handleExit,
          scaleFactor: scaleFactor,
          isWebPlatform: isWebPlatform,
        ),
      ],
    );
  }
  
  Widget _buildSettingsMenu(double scaleFactor, bool isWebPlatform) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title
        Text(
          'SETTINGS',
          style: TextStyle(
            fontFamily: 'Vip',
            fontSize: isWebPlatform ? 28 * scaleFactor : 24 * scaleFactor,
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            shadows: [
              Shadow(
                color: isWebPlatform ? const Color(0xFFD1A758) : const Color(0xFF7AC74C),
                offset: Offset(0, 2),
                blurRadius: 5,
              ),
            ],
          ),
        ),
        
        SizedBox(height: 20 * scaleFactor),
        
        // Sound FX Toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SOUND FX',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16 * scaleFactor,
                fontWeight: FontWeight.bold,
              ),
            ),
            Switch(
              value: _sfxEnabled,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() {
                  _sfxEnabled = value;
                });
              },
              activeColor: isWebPlatform ? const Color(0xFFD1A758) : const Color(0xFF7AC74C),
            ),
          ],
        ),
        
        SizedBox(height: 10 * scaleFactor),
        
        // SFX Volume Slider
        Row(
          children: [
            Icon(
              Icons.volume_up,
              color: Colors.white.withOpacity(_sfxEnabled ? 1 : 0.5),
              size: 20 * scaleFactor,
            ),
            SizedBox(width: 10 * scaleFactor),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 5 * scaleFactor,
                  thumbShape: RoundSliderThumbShape(
                    enabledThumbRadius: 6 * scaleFactor,
                  ),
                ),
                child: Slider(
                  value: _sfxVolume,
                  min: 0.0,
                  max: 1.0,
                  activeColor: (isWebPlatform ? const Color(0xFFD1A758) : const Color(0xFF7AC74C))
                    .withOpacity(_sfxEnabled ? 1 : 0.5),
                  inactiveColor: Colors.grey.withOpacity(0.3),
                  onChanged: (value) {
                    if (!_sfxEnabled) return;
                    setState(() {
                      _sfxVolume = value;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
        
        SizedBox(height: 20 * scaleFactor),
        
        // Background Music Toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'MUSIC',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16 * scaleFactor,
                fontWeight: FontWeight.bold,
              ),
            ),
            Switch(
              value: _bgmEnabled,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() {
                  _bgmEnabled = value;
                });
              },
              activeColor: isWebPlatform ? const Color(0xFFD1A758) : const Color(0xFF7AC74C),
            ),
          ],
        ),
        
        SizedBox(height: 10 * scaleFactor),
        
        // BGM Volume Slider
        Row(
          children: [
            Icon(
              Icons.music_note,
              color: Colors.white.withOpacity(_bgmEnabled ? 1 : 0.5),
              size: 20 * scaleFactor,
            ),
            SizedBox(width: 10 * scaleFactor),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 5 * scaleFactor,
                  thumbShape: RoundSliderThumbShape(
                    enabledThumbRadius: 6 * scaleFactor,
                  ),
                ),
                child: Slider(
                  value: _bgmVolume,
                  min: 0.0,
                  max: 1.0,
                  activeColor: (isWebPlatform ? const Color(0xFFD1A758) : const Color(0xFF7AC74C))
                    .withOpacity(_bgmEnabled ? 1 : 0.5),
                  inactiveColor: Colors.grey.withOpacity(0.3),
                  onChanged: (value) {
                    if (!_bgmEnabled) return;
                    setState(() {
                      _bgmVolume = value;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
        
        SizedBox(height: 20 * scaleFactor),
        
        // Control type toggle (Touch/Keyboard)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CONTROL TYPE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16 * scaleFactor,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8 * scaleFactor),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Touch controls button
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _controlType = GameConstants.controlTypeTouch;
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10 * scaleFactor, 
                      vertical: 6 * scaleFactor
                    ),
                    decoration: BoxDecoration(
                      color: _controlType == GameConstants.controlTypeTouch 
                          ? (isWebPlatform ? const Color(0xFFD1A758) : const Color(0xFF7AC74C)).withOpacity(0.5) 
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _controlType == GameConstants.controlTypeTouch 
                            ? (isWebPlatform ? const Color(0xFFD1A758) : const Color(0xFF7AC74C)) 
                            : Colors.white30,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.touch_app,
                          color: Colors.white,
                          size: 16 * scaleFactor,
                        ),
                        SizedBox(width: 5 * scaleFactor),
                        Text(
                          'TOUCH',
                          style: TextStyle(
                            fontFamily: 'Vip',
                            fontSize: 12 * scaleFactor,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(width: 10 * scaleFactor),
                
                // Keyboard controls button
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _controlType = GameConstants.controlTypeKeyboard;
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10 * scaleFactor, 
                      vertical: 6 * scaleFactor
                    ),
                    decoration: BoxDecoration(
                      color: _controlType == GameConstants.controlTypeKeyboard 
                          ? (isWebPlatform ? const Color(0xFFD1A758) : const Color(0xFF7AC74C)).withOpacity(0.5) 
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _controlType == GameConstants.controlTypeKeyboard 
                            ? (isWebPlatform ? const Color(0xFFD1A758) : const Color(0xFF7AC74C)) 
                            : Colors.white30,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.keyboard,
                          color: Colors.white,
                          size: 16 * scaleFactor,
                        ),
                        SizedBox(width: 5 * scaleFactor),
                        Text(
                          'KEYBOARD',
                          style: TextStyle(
                            fontFamily: 'Vip',
                            fontSize: 12 * scaleFactor,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        
        SizedBox(height: 15 * scaleFactor),
        
        // Keyboard controls settings button (only visible when keyboard controls are enabled)
        if (_controlType == GameConstants.controlTypeKeyboard)
          _buildButton(
            icon: Icons.keyboard,
            label: 'KEYBOARD SETTINGS',
            color: isWebPlatform ? const Color(0xFF5D9CEC) : Colors.blue,
            onTap: _goToKeyboardSettings,
            scaleFactor: scaleFactor,
            isWebPlatform: isWebPlatform,
          ),
        
        if (_controlType == GameConstants.controlTypeKeyboard)
          SizedBox(height: 15 * scaleFactor),
        
        // Joystick position toggle (only visible when touch controls are enabled)
        if (_controlType == GameConstants.controlTypeTouch)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'JOYSTICK POSITION',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16 * scaleFactor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8 * scaleFactor),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Left side button
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _joystickOnLeft = true;
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10 * scaleFactor, 
                        vertical: 6 * scaleFactor
                      ),
                      decoration: BoxDecoration(
                        color: _joystickOnLeft 
                            ? (isWebPlatform ? const Color(0xFFD1A758) : const Color(0xFF7AC74C)).withOpacity(0.5) 
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _joystickOnLeft 
                              ? (isWebPlatform ? const Color(0xFFD1A758) : const Color(0xFF7AC74C)) 
                              : Colors.white30,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'LEFT',
                        style: TextStyle(
                          fontFamily: 'Vip',
                          fontSize: 12 * scaleFactor,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  
                  SizedBox(width: 10 * scaleFactor),
                  
                  // Right side button
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _joystickOnLeft = false;
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10 * scaleFactor, 
                        vertical: 6 * scaleFactor
                      ),
                      decoration: BoxDecoration(
                        color: !_joystickOnLeft 
                            ? (isWebPlatform ? const Color(0xFFD1A758) : const Color(0xFF7AC74C)).withOpacity(0.5) 
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: !_joystickOnLeft 
                              ? (isWebPlatform ? const Color(0xFFD1A758) : const Color(0xFF7AC74C)) 
                              : Colors.white30,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'RIGHT',
                        style: TextStyle(
                          fontFamily: 'Vip',
                          fontSize: 12 * scaleFactor,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        
        SizedBox(height: 25 * scaleFactor),
        
        // Save button
        _buildButton(
          icon: Icons.save,
          label: 'SAVE',
          color: isWebPlatform ? const Color(0xFFD1A758) : const Color(0xFF7AC74C),
          onTap: _saveSettings,
          scaleFactor: scaleFactor,
          isWebPlatform: isWebPlatform,
        ),
        
        SizedBox(height: 15 * scaleFactor),
        
        // Back button
        _buildButton(
          icon: Icons.arrow_back,
          label: 'BACK',
          color: Colors.grey,
          onTap: _goToMain,
          scaleFactor: scaleFactor,
          isWebPlatform: isWebPlatform,
        ),
      ],
    );
  }
  
  Widget _buildKeyboardSettingsMenu(double scaleFactor, bool isWebPlatform) {
    // Reduce font size for smaller screens
    final double keyLabelFontSize = isWebPlatform ? 14 * scaleFactor : 12 * scaleFactor;
    final double keyButtonFontSize = isWebPlatform ? 14 * scaleFactor : 12 * scaleFactor;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title
        Text(
          'KEYBOARD SETTINGS',
          style: TextStyle(
            fontFamily: 'Vip',
            fontSize: isWebPlatform ? 26 * scaleFactor : 22 * scaleFactor,
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            shadows: [
              Shadow(
                color: isWebPlatform ? const Color(0xFFD1A758) : const Color(0xFF7AC74C),
                offset: Offset(0, 2),
                blurRadius: 5,
              ),
            ],
          ),
        ),
        
        SizedBox(height: 15 * scaleFactor),
        
        // Show message if in remapping mode
        if (_isRemappingKey)
          Container(
            padding: EdgeInsets.all(10 * scaleFactor),
            margin: EdgeInsets.only(bottom: 15 * scaleFactor),
            decoration: BoxDecoration(
              color: isWebPlatform 
                ? const Color(0xFFD1A758).withOpacity(0.3)
                : Colors.amber.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isWebPlatform ? const Color(0xFFD1A758) : Colors.amber, 
                width: 1
              ),
            ),
            child: Text(
              'Press any key to assign to ${_keyBeingRemapped?.toUpperCase()}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14 * scaleFactor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        
        // Key mappings
        ..._buildKeyMappingRow('UP', _upKey, 'up', scaleFactor, isWebPlatform, keyLabelFontSize, keyButtonFontSize),
        ..._buildKeyMappingRow('DOWN', _downKey, 'down', scaleFactor, isWebPlatform, keyLabelFontSize, keyButtonFontSize),
        ..._buildKeyMappingRow('LEFT', _leftKey, 'left', scaleFactor, isWebPlatform, keyLabelFontSize, keyButtonFontSize),
        ..._buildKeyMappingRow('RIGHT', _rightKey, 'right', scaleFactor, isWebPlatform, keyLabelFontSize, keyButtonFontSize),
        ..._buildKeyMappingRow('PLANT BOMB', _bombKey, 'bomb', scaleFactor, isWebPlatform, keyLabelFontSize, keyButtonFontSize),
        
        SizedBox(height: 15 * scaleFactor),
        
        // Reset to defaults button
        _buildButton(
          icon: Icons.refresh,
          label: 'RESET TO DEFAULTS',
          color: isWebPlatform ? const Color(0xFFFF9800) : Colors.orange,
          onTap: () {
            setState(() {
              _upKey = GameConstants.defaultUpKey;
              _downKey = GameConstants.defaultDownKey;
              _leftKey = GameConstants.defaultLeftKey;
              _rightKey = GameConstants.defaultRightKey;
              _bombKey = GameConstants.defaultBombKey;
            });
          },
          scaleFactor: scaleFactor,
          isWebPlatform: isWebPlatform,
        ),
        
        SizedBox(height: 15 * scaleFactor),
        
        // Save button
        _buildButton(
          icon: Icons.save,
          label: 'SAVE',
          color: isWebPlatform ? const Color(0xFFD1A758) : const Color(0xFF7AC74C),
          onTap: _saveKeyboardSettings,
          scaleFactor: scaleFactor,
          isWebPlatform: isWebPlatform,
        ),
        
        SizedBox(height: 15 * scaleFactor),
        
        // Back button
        _buildButton(
          icon: Icons.arrow_back,
          label: 'BACK',
          color: Colors.grey,
          onTap: () {
            setState(() {
              _currentPage = 1;
              _isRemappingKey = false;
              _keyBeingRemapped = null;
            });
          },
          scaleFactor: scaleFactor,
          isWebPlatform: isWebPlatform,
        ),
      ],
    );
  }
  
  List<Widget> _buildKeyMappingRow(String label, String keyValue, String keyType, double scaleFactor, bool isWebPlatform, 
      double labelFontSize, double buttonFontSize) {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: labelFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          GestureDetector(
            onTap: _isRemappingKey ? null : () => _startRemappingKey(keyType),
            child: Container(
              constraints: BoxConstraints(minWidth: 45 * scaleFactor, maxWidth: 80 * scaleFactor), // Ensure proper sizing
              padding: EdgeInsets.symmetric(
                horizontal: 8 * scaleFactor, 
                vertical: 5 * scaleFactor
              ),
              decoration: BoxDecoration(
                color: _keyBeingRemapped == keyType
                    ? (isWebPlatform ? const Color(0xFFD1A758) : Colors.amber).withOpacity(0.5)
                    : (isWebPlatform ? const Color(0xFF5D9CEC) : Colors.blue).withOpacity(0.3),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: _keyBeingRemapped == keyType
                      ? (isWebPlatform ? const Color(0xFFD1A758) : Colors.amber)
                      : (isWebPlatform ? const Color(0xFF5D9CEC) : Colors.blue),
                  width: 1,
                ),
              ),
              child: Text(
                widget.keyboardControls.getDisplayKeyName(keyValue),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: buttonFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      SizedBox(height: 10 * scaleFactor),
    ];
  }
  
  Widget _buildButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required double scaleFactor,
    required bool isWebPlatform,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          vertical: 12 * scaleFactor, 
          horizontal: 15 * scaleFactor
        ),
        decoration: BoxDecoration(
          color: isWebPlatform ? const Color(0xFF1E1C29) : Colors.black38,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withOpacity(isWebPlatform ? 0.8 : 0.5),
            width: isWebPlatform ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(isWebPlatform ? 0.3 : 0.2),
              blurRadius: isWebPlatform ? 8 : 5,
              spreadRadius: isWebPlatform ? 2 : 1,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: isWebPlatform ? 24 * scaleFactor : 20 * scaleFactor,
            ),
            SizedBox(width: 10 * scaleFactor),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Vip',
                color: Colors.white,
                fontSize: isWebPlatform ? 18 * scaleFactor : 16 * scaleFactor,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 