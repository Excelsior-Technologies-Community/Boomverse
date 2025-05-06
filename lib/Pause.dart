import 'package:flutter/material.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'game/keyboard_controls.dart';
import 'game/constants.dart';

class Pause extends StatefulWidget {
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onExit;
  final int level;
  final int score;
  final Function(double) onMusicVolumeChanged;
  final Function(double) onSfxVolumeChanged;
  final Function(bool) onControlsChanged;
  final double musicVolume;
  final double sfxVolume;
  final bool rightControls;
  final KeyboardControls keyboardControls;
  final String controlType;
  final Function(String) onControlTypeChanged;

  const Pause({
    super.key,
    required this.onResume,
    required this.onRestart,
    required this.onExit,
    required this.level,
    required this.score,
    required this.onMusicVolumeChanged,
    required this.onSfxVolumeChanged,
    required this.onControlsChanged,
    required this.musicVolume,
    required this.sfxVolume,
    required this.rightControls,
    required this.keyboardControls,
    required this.controlType,
    required this.onControlTypeChanged,
  });

  @override
  State<Pause> createState() => _PauseState();
}

class _PauseState extends State<Pause> with TickerProviderStateMixin {
  late AnimationController _animationController;
  bool showSettings = false;
  bool showKeyboardSettings = false;

  // Local state to track settings
  late double musicVolume;
  late double sfxVolume;
  late bool rightControls;
  late String controlType;

  // Keyboard bindings
  late String _upKey;
  late String _downKey;
  late String _leftKey;
  late String _rightKey;
  late String _bombKey;
  String? _pendingKey;
  String _pendingKeyAction = '';

  // Green theme colors
  final Color primaryGreen = const Color(0xFF7AC74C);
  final Color darkGreen = const Color(0xFF1A472A);
  final Color lightGreen = const Color(0xFF9DC427);
  final Color goldColor = const Color(0xFFFFD700);
  final Color bgColor = Colors.black54;

  @override
  void initState() {
    super.initState();

    // Initialize local state with passed values
    musicVolume = widget.musicVolume;
    sfxVolume = widget.sfxVolume;
    rightControls = widget.rightControls;
    controlType = widget.controlType;

    // Initialize keyboard settings
    _upKey = widget.keyboardControls.upKey;
    _downKey = widget.keyboardControls.downKey;
    _leftKey = widget.keyboardControls.leftKey;
    _rightKey = widget.keyboardControls.rightKey;
    _bombKey = widget.keyboardControls.bombKey;

    // Setup animation controller for button effects
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    // Play pause sound
    try {
      FlameAudio.play('game pause.mp3', volume: sfxVolume);
    } catch (e) {
      try {
        FlameAudio.play('audio/game pause.mp3', volume: sfxVolume);
      } catch (e2) {
        // Ignore audio errors
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        widget.onResume();
        return false; // Return false to prevent automatically popping
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: const AssetImage('assets/images/background3.png'),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                darkGreen.withOpacity(0.6),
                BlendMode.multiply,
              ),
            ),
          ),
          child:
              showKeyboardSettings
                  ? _buildKeyboardSettingsMenu()
                  : (showSettings ? _buildSettingsMenu() : _buildPauseMenu()),
        ),
      ),
    );
  }

  Widget _buildPauseMenu() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Different container sizes for web and mobile
    final containerWidth = kIsWeb ? screenWidth * 0.5 : screenWidth * 0.7;
    final containerHeight = kIsWeb ? screenHeight * 0.5 : screenHeight * 0.6;

    return Center(
      child: Container(
        width: containerWidth,
        height: containerHeight,
        decoration: BoxDecoration(
          color: bgColor.withOpacity(0.9),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: primaryGreen.withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: 3,
            ),
          ],
          border: Border.all(color: primaryGreen, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(0.2),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(13),
                  topRight: Radius.circular(13),
                ),
              ),
              child: Text(
                "PAUSED",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: kIsWeb ? 22 : 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: const [
                    Shadow(
                      color: Colors.black,
                      offset: Offset(1, 1),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
            ),

            // Game stats section
            Padding(
              padding: EdgeInsets.symmetric(vertical: kIsWeb ? 15 : 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildGameStat("LEVEL", widget.level.toString()),
                  SizedBox(width: kIsWeb ? 60 : 40),
                  _buildGameStat("SCORE", widget.score.toString()),
                ],
              ),
            ),

            // Divider
            Container(
              width: containerWidth * 0.8,
              height: 2,
              color: primaryGreen.withOpacity(0.3),
            ),

            SizedBox(height: kIsWeb ? 25 : 15),

            // Buttons row
            if (kIsWeb) 
              // Web layout - buttons in a grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildWebButton(
                          "RESUME",
                          goldColor,
                          Icons.play_arrow,
                          () {
                            widget.onResume();
                          },
                        ),
                        const SizedBox(width: 30),
                        _buildWebButton(
                          "SETTINGS",
                          lightGreen,
                          Icons.settings,
                          () {
                            setState(() {
                              showSettings = true;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildWebButton(
                      "EXIT",
                      Colors.white,
                      Icons.exit_to_app,
                      () {
                        showExitConfirmation();
                      },
                    ),
                  ],
                ),
              )
            else 
              // Mobile layout - compact buttons in a row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildCompactButton(
                      "RESUME",
                      goldColor,
                      Icons.play_arrow,
                      () {
                        widget.onResume();
                      },
                    ),
                    const SizedBox(width: 25),
                    _buildCompactButton(
                      "SETTINGS",
                      lightGreen,
                      Icons.settings,
                      () {
                        setState(() {
                          showSettings = true;
                        });
                      },
                    ),
                    const SizedBox(width: 25),
                    _buildCompactButton(
                      "EXIT",
                      Colors.white,
                      Icons.exit_to_app,
                      () {
                        showExitConfirmation();
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 12,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor.withOpacity(0.7),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: primaryGreen.withOpacity(0.5)),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 14,
              color: goldColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactButton(
    String label,
    Color color,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final glowOpacity = 0.15 + (_animationController.value * 0.15);

        return GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 100,
            height: 70,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(glowOpacity),
                  blurRadius: 5,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(height: 5),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 8,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsMenu() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Adjusted container size for web
    final containerWidth = kIsWeb ? screenWidth * 0.5 : screenWidth * 0.7;
    final containerHeight = kIsWeb 
        ? screenHeight * 0.6 
        : (screenHeight * 0.8 - 20); // Reduced height on mobile to prevent overflow

    return Center(
      child: Container(
        width: containerWidth,
        height: containerHeight,
        decoration: BoxDecoration(
          color: bgColor.withOpacity(0.9),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: primaryGreen.withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: 3,
            ),
          ],
          border: Border.all(color: primaryGreen, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header section
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: kIsWeb ? 15 : 10),
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(0.2),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(13),
                  topRight: Radius.circular(13),
                ),
              ),
              child: Text(
                "SETTINGS",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: kIsWeb ? 22 : 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: const [
                    Shadow(
                      color: Colors.black,
                      offset: Offset(1, 1),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
            ),

            // Make content scrollable
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: kIsWeb ? 20 : 10,
                    horizontal: kIsWeb ? 30 : 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (kIsWeb)
                        // Web layout with more space and side-by-side controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left column for volume controls
                            Expanded(
                              child: Column(
                                children: [
                                  _buildVolumeSlider(
                                    "MUSIC",
                                    Icons.music_note,
                                    musicVolume,
                                    (value) {
                                      setState(() {
                                        musicVolume = value;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  _buildVolumeSlider(
                                    "SFX",
                                    Icons.volume_up,
                                    sfxVolume,
                                    (value) {
                                      setState(() {
                                        sfxVolume = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 30),
                            // Right column for control settings
                            Expanded(
                              child: Column(
                                children: [
                                  _buildControlSwitch(),
                                  const SizedBox(height: 20),
                                  _buildControlTypeToggle(),
                                ],
                              ),
                            ),
                          ],
                        )
                      else
                        // Mobile layout (unchanged)
                        Column(
                          children: [
                            // Music volume slider
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildVolumeSlider(
                                  "MUSIC",
                                  Icons.music_note,
                                  musicVolume,
                                  (value) {
                                    setState(() {
                                      musicVolume = value;
                                    });
                                  },
                                ),
                                const SizedBox(width: 15),

                                // SFX volume slider
                                _buildVolumeSlider(
                                  "SFX",
                                  Icons.volume_up,
                                  sfxVolume,
                                  (value) {
                                    setState(() {
                                      sfxVolume = value;
                                    });
                                  },
                                ),
                              ],
                            ),

                            const SizedBox(height: 15),

                            // Controls position switch
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildControlSwitch(),
                                const SizedBox(width: 15),

                                // Control type toggle (Touch/Keyboard)
                                _buildControlTypeToggle(),
                              ],
                            ),

                            const SizedBox(height: 15),
                          ],
                        ),

                      // Web-only section for keyboard settings button
                      if (kIsWeb && controlType == GameConstants.controlTypeKeyboard)
                        Padding(
                          padding: const EdgeInsets.only(top: 25),
                          child: _buildWebButton(
                            "KEYBOARD SETTINGS",
                            primaryGreen,
                            Icons.keyboard,
                            () {
                              setState(() {
                                showKeyboardSettings = true;
                                showSettings = false;
                              });
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Back button always at the bottom
            Padding(
              padding: EdgeInsets.only(
                bottom: kIsWeb ? 20 : 15, 
                top: kIsWeb ? 10 : 5
              ),
              child: kIsWeb
                  ? _buildWebButton(
                      "APPLY & BACK",
                      goldColor,
                      Icons.check_circle,
                      () {
                        _applySettingsChanges();
                        setState(() {
                          showSettings = false;
                        });
                      },
                    )
                  : _buildMenuButton(
                      "APPLY & BACK",
                      goldColor,
                      Icons.check_circle,
                      () {
                        _applySettingsChanges();
                        setState(() {
                          showSettings = false;
                        });
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Apply all settings changes
  void _applySettingsChanges() {
    widget.onMusicVolumeChanged(musicVolume);
    widget.onSfxVolumeChanged(sfxVolume);
    widget.onControlsChanged(rightControls);
    widget.onControlTypeChanged(controlType);

    // Save keyboard settings if they were modified
    _saveKeyboardSettings();
  }

  // Save keyboard settings
  void _saveKeyboardSettings() {
    widget.keyboardControls.upKey = _upKey;
    widget.keyboardControls.downKey = _downKey;
    widget.keyboardControls.leftKey = _leftKey;
    widget.keyboardControls.rightKey = _rightKey;
    widget.keyboardControls.bombKey = _bombKey;

    widget.keyboardControls
        .saveKeySettings()
        .then((_) {
          print('Keyboard settings saved successfully');
        })
        .catchError((e) {
          print('Error saving keyboard settings: $e');
        });

    // Ensure the keyboard controls are immediately applied
    widget.keyboardControls.resetPressedKeys();
  }

  // Handle key event for keyboard rebinding
  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent && _pendingKey != null) {
      // Get key name string from the keyboard controls
      final keyName = widget.keyboardControls.getKeyName(event as KeyEvent);

      // Avoid using Escape and other special keys
      if (keyName == 'Escape' || keyName == 'Tab' || keyName == 'Enter') {
        return;
      }

      setState(() {
        switch (_pendingKeyAction) {
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
        _pendingKey = null;
        _pendingKeyAction = '';
      });
    }
  }

  // Get display name for keyboard key
  String _getKeyDisplayName(String keyName) {
    return widget.keyboardControls.getDisplayKeyName(keyName);
  }

  Widget _buildVolumeSlider(
    String label,
    IconData icon,
    double value,
    Function(double) onChanged,
  ) {
    return Container(
      width: 260,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primaryGreen.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: primaryGreen, size: 16),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                "0%",
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 8,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: primaryGreen,
                    inactiveTrackColor: Colors.grey.withOpacity(0.3),
                    thumbColor: goldColor,
                    overlayColor: primaryGreen.withOpacity(0.2),
                    trackHeight: 6,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                    ),
                  ),
                  child: Slider(
                    value: value,
                    min: 0.0,
                    max: 1.0,
                    onChanged: onChanged,
                  ),
                ),
              ),
              Text(
                "100%",
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 8,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
          Text(
            "${(value * 100).toInt()}%",
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 10,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlSwitch() {
    return Container(
      width: 260,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primaryGreen.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          const Text(
            "CONTROLS POSITION",
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 10,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPositionOption("LEFT", !rightControls),
              const SizedBox(width: 30),
              _buildPositionOption("RIGHT", rightControls),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPositionOption(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          rightControls = label == "RIGHT";
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? primaryGreen.withOpacity(0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? primaryGreen : Colors.grey.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 10,
            color: isSelected ? Colors.white : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(
    String label,
    Color color,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final glowOpacity = 0.15 + (_animationController.value * 0.15);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          child: GestureDetector(
            onTap: onPressed,
            child: Container(
              height: 40,
              width: 200,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(glowOpacity),
                    blurRadius: 6,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: color,
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

  void showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: primaryGreen, width: 2),
        ),
        titlePadding: EdgeInsets.only(top: kIsWeb ? 24 : 16),
        title: Text(
          "EXIT GAME?",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            color: Colors.white,
            fontSize: kIsWeb ? 20 : 16,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: kIsWeb ? 24 : 16,
          vertical: kIsWeb ? 16 : 10,
        ),
        content: Text(
          "Your progress will not be saved.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            color: Colors.white70,
            fontSize: kIsWeb ? 16 : 12,
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actionsPadding: EdgeInsets.only(bottom: kIsWeb ? 24 : 16),
        actions: [
          _buildDialogButton("YES", Colors.red, () {
            Navigator.of(context).pop(); // Close dialog
            widget.onExit();
          }),
          _buildDialogButton("NO", primaryGreen, () {
            Navigator.of(context).pop(); // Close dialog only
          }),
        ],
      ),
    );
  }

  Widget _buildDialogButton(String label, Color color, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: kIsWeb ? 100 : 80,
        height: kIsWeb ? 45 : 36,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: kIsWeb ? 16 : 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // Add the missing keyboard settings menu
  Widget _buildKeyboardSettingsMenu() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final containerWidth = kIsWeb ? screenWidth * 0.5 : screenWidth * 0.7;
    // Adjust container height for web and mobile
    final containerHeight = kIsWeb 
        ? screenHeight * 0.6 
        : (screenHeight * 0.7 - 20);

    return RawKeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKey: _handleKeyEvent,
      child: Center(
        child: Container(
          width: containerWidth,
          height: containerHeight,
          decoration: BoxDecoration(
            color: bgColor.withOpacity(0.9),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: primaryGreen.withOpacity(0.4),
                blurRadius: 12,
                spreadRadius: 3,
              ),
            ],
            border: Border.all(color: primaryGreen, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header section
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: kIsWeb ? 15 : 10),
                decoration: BoxDecoration(
                  color: primaryGreen.withOpacity(0.2),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(13),
                    topRight: Radius.circular(13),
                  ),
                ),
                child: Text(
                  "KEYBOARD SETTINGS",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: kIsWeb ? 22 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: const [
                      Shadow(
                        color: Colors.black,
                        offset: Offset(1, 1),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                ),
              ),

              // Make the content scrollable
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: kIsWeb ? 20 : 10,
                      horizontal: kIsWeb ? 40 : 15
                    ),
                    child: Column(
                      children: [
                        // Instructions
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          child: Text(
                            "Click on a button to reassign the key",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'PressStart2P',
                              fontSize: kIsWeb ? 14 : 10,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ),

                        SizedBox(height: kIsWeb ? 30 : 20),

                        // Keyboard binding list - different spacing for web
                        _buildKeyBindingRow(
                          "UP",
                          _getKeyDisplayName(_upKey),
                          () {
                            setState(() {
                              _pendingKey = _upKey;
                              _pendingKeyAction = 'up';
                            });
                          },
                        ),

                        SizedBox(height: kIsWeb ? 15 : 10),

                        _buildKeyBindingRow(
                          "DOWN",
                          _getKeyDisplayName(_downKey),
                          () {
                            setState(() {
                              _pendingKey = _downKey;
                              _pendingKeyAction = 'down';
                            });
                          },
                        ),

                        SizedBox(height: kIsWeb ? 15 : 10),

                        _buildKeyBindingRow(
                          "LEFT",
                          _getKeyDisplayName(_leftKey),
                          () {
                            setState(() {
                              _pendingKey = _leftKey;
                              _pendingKeyAction = 'left';
                            });
                          },
                        ),

                        SizedBox(height: kIsWeb ? 15 : 10),

                        _buildKeyBindingRow(
                          "RIGHT",
                          _getKeyDisplayName(_rightKey),
                          () {
                            setState(() {
                              _pendingKey = _rightKey;
                              _pendingKeyAction = 'right';
                            });
                          },
                        ),

                        SizedBox(height: kIsWeb ? 15 : 10),

                        _buildKeyBindingRow(
                          "BOMB",
                          _getKeyDisplayName(_bombKey),
                          () {
                            setState(() {
                              _pendingKey = _bombKey;
                              _pendingKeyAction = 'bomb';
                            });
                          },
                        ),

                        SizedBox(height: kIsWeb ? 40 : 30),

                        // Info text for pending key
                        if (_pendingKey != null)
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: goldColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: goldColor),
                            ),
                            child: Text(
                              "Press any key to assign to $_pendingKeyAction",
                              style: TextStyle(
                                fontFamily: 'PressStart2P',
                                fontSize: kIsWeb ? 14 : 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Back button always at the bottom
              Padding(
                padding: EdgeInsets.only(
                  bottom: kIsWeb ? 20 : 15, 
                  top: kIsWeb ? 10 : 5
                ),
                child: kIsWeb
                    ? _buildWebButton(
                        "BACK",
                        goldColor,
                        Icons.arrow_back,
                        () {
                          setState(() {
                            _pendingKey = null;
                            _pendingKeyAction = '';
                            showKeyboardSettings = false;
                            // Return to settings on web
                            if (kIsWeb) showSettings = true;
                          });
                        },
                      )
                    : _buildMenuButton(
                        "BACK",
                        goldColor,
                        Icons.arrow_back,
                        () {
                          setState(() {
                            _pendingKey = null;
                            _pendingKeyAction = '';
                            showKeyboardSettings = false;
                          });
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget to build a key binding row
  Widget _buildKeyBindingRow(
    String label,
    String keyName,
    VoidCallback onPressed,
  ) {
    final isWaiting = _pendingKeyAction == label.toLowerCase();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: kIsWeb ? 30 : 20),
      child: Row(
        children: [
          SizedBox(
            width: kIsWeb ? 100 : 80,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: kIsWeb ? 16 : 12,
                color: Colors.white,
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onPressed,
            child: Container(
              width: kIsWeb ? 150 : 120,
              padding: EdgeInsets.symmetric(
                horizontal: 10, 
                vertical: kIsWeb ? 12 : 8
              ),
              decoration: BoxDecoration(
                color: isWaiting ? goldColor.withOpacity(0.3) : bgColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isWaiting ? goldColor : primaryGreen,
                  width: 1.5,
                ),
              ),
              child: Text(
                isWaiting ? "PRESS KEY..." : keyName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: kIsWeb ? 14 : 10,
                  color: isWaiting ? goldColor : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Control type toggle (Touch/Keyboard)
  Widget _buildControlTypeToggle() {
    return Container(
      width: 270,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primaryGreen.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          const Text(
            "CONTROL TYPE",
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 10,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildControlTypeOption(
                "TOUCH",
                controlType == GameConstants.controlTypeTouch,
              ),
              const SizedBox(width: 10),
              _buildControlTypeOption(
                "KEYBOARD",
                controlType == GameConstants.controlTypeKeyboard,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Widget for control type option
  Widget _buildControlTypeOption(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          controlType =
              label == "TOUCH"
                  ? GameConstants.controlTypeTouch
                  : GameConstants.controlTypeKeyboard;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? primaryGreen.withOpacity(0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? primaryGreen : Colors.grey.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 10,
            color: isSelected ? Colors.white : Colors.grey,
          ),
        ),
      ),
    );
  }

  // Web-optimized button style
  Widget _buildWebButton(
    String label,
    Color color,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final glowOpacity = 0.15 + (_animationController.value * 0.15);

        return GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 300,
            height: 50,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(glowOpacity),
                  blurRadius: 5,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 12),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
