import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_database/firebase_database.dart';
import 'game_board.dart';
import 'constants.dart';
import 'player.dart';
import 'enemy.dart';
import 'keyboard_controls.dart';
import 'bomb.dart';
import 'bullet.dart';
import '../VictoryPage.dart';
import '../GameLost.dart';
import '../Pause.dart';
import '../services/audio_service.dart';
import '../services/device_service.dart';
import 'unified_joystick.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GameScreen extends StatefulWidget {
  final int level;

  const GameScreen({super.key, this.level = 1});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late GameBoard gameBoard;
  late Player player;
  late List<Enemy> enemies = []; // List to hold enemies
  late List<Bullet> bullets = []; // List to hold active bullets
  late Timer _gameTimer;
  bool _isGameRunning = true;
  int _frameCount = 0;
  int _gameTime = 0; // Time elapsed in frames (60fps)
  final int _updateInterval =
      1; // Update visuals every frame for smoother animations

  // Level-specific settings
  late int _enemyCount;
  late bool _useAdvancedMovement;
  late bool _usePathfinding;
  late bool _hasCollectibles;
  late int _chanceOfCollectibles;
  late int _keyChance;
  late int _treasureChance;

  // Game state tracking
  int _remainingEnemies = 0;

  // Animation controllers
  double _coinScaleEffect = 1.0;

  // Firebase references
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  // New properties
  late int _bulletRange;
  late int _detectionRadius;
  late int _enemyMovementDuration;

  // Variables to track collectibles
  int _collectedKeys = 0;
  int _collectedTreasures = 0;

  // Pause menu state
  bool _isPaused = false;
  bool _joystickOnLeft = true;

  // Control settings
  String _controlType = GameConstants.controlTypeTouch;
  final KeyboardControls _keyboardControls = KeyboardControls();

  // Audio service
  final AudioService _audioService = AudioService();

  // Walk sound cooldown
  int _walkSoundCooldown = 0;

  @override
  void initState() {
    super.initState();
    // Only keep the system UI mode setting
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Initialize audio
    _initAudio();

    // Configure level-specific settings
    _configureLevelSettings();

    // Initialize game components
    gameBoard = GameBoard();
    player = Player.spawn();

    // Initialize keyboard controls
    _initKeyboardControls();

    // Spawn enemies for this level
    _spawnEnemies();

    // Start game loop at 60fps
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), _gameLoop);
  }

  Future<void> _initAudio() async {
    await _audioService.init();
    await _audioService.playGameBGM();
  }

  Future<void> _initKeyboardControls() async {
    await _keyboardControls.init();

    // Setup callbacks
    _keyboardControls.onDirectionChanged = (dx, dy) {
      if (!_isGameRunning || _isPaused) return;
      player.move(dx, dy, gameBoard);
    };

    _keyboardControls.onBombPressed = () {
      if (!_isGameRunning || _isPaused) return;
      _plantBomb();
    };

    // Set default control type based on platform
    _setDefaultControlType();
  }

  void _setDefaultControlType() {
    // Default to touch controls for mobile and keyboard for web
    if (kIsWeb) {
      _controlType = GameConstants.controlTypeKeyboard;
    } else {
      _controlType = GameConstants.controlTypeTouch;
    }
  }

  // Check if the device has a physical keyboard
  bool get _hasPhysicalKeyboard {
    // Web is assumed to have a keyboard
    if (kIsWeb) return true;

    // Mobile devices generally don't have physical keyboards
    return false;
  }

  void _configureLevelSettings() {
    // Base number of enemies (increases with level)
    if (widget.level <= 2) {
      _enemyCount = 1; // First 2 levels have only 1 enemy
    } else if (widget.level <= 5) {
      _enemyCount = 1 + (widget.level - 2); // Levels 3-5: 2-3 enemies
    } else if (widget.level <= 10) {
      _enemyCount = 2 + (widget.level - 5) ~/ 2; // Levels 6-10: 3-4 enemies
    } else if (widget.level <= 15) {
      _enemyCount = 3 + (widget.level - 10) ~/ 2; // Levels 11-15: 5-6 enemies
    } else {
      _enemyCount = 4 + (widget.level - 15); // Levels 16-20: 5-9 enemies
    }

    // Advanced movement begins gradually
    _useAdvancedMovement = widget.level >= 6;

    // A* pathfinding begins at level 11
    _usePathfinding = widget.level >= 11;

    // Collectibles appear from level 8
    _hasCollectibles = widget.level >= 8;

    // Chance of collectibles appearing increases with level
    _chanceOfCollectibles = widget.level > 8 ? 10 + (widget.level * 1) : 0;

    // Keys are rarer than treasures
    _keyChance = _chanceOfCollectibles ~/ 4;
    _treasureChance = _chanceOfCollectibles ~/ 3;

    // Bullet range increases with level
    _bulletRange =
        widget.level <= 3
            ? 2
            : widget.level <= 7
            ? 5
            : widget.level <= 12
            ? 7
            : 10;

    // Detection radius increases with level
    _detectionRadius =
        widget.level <= 4
            ? 3
            : widget.level <= 8
            ? 4
            : widget.level <= 12
            ? 5
            : 6;

    // Enemy speed decreases with lower levels (higher duration = slower)
    _enemyMovementDuration =
        widget.level <= 3
            ? 24
            : widget.level <= 7
            ? 20
            : widget.level <= 12
            ? 16
            : widget.level <= 16
            ? 12
            : 10;
  }

  void _spawnEnemies() {
    // Find valid spawn positions for enemies
    List<Point<int>> spawnPositions = gameBoard.findEnemySpawnPositions(
      _enemyCount,
    );

    // Create enemies at those positions
    for (var position in spawnPositions) {
      enemies.add(
        Enemy(
          gridX: position.x,
          gridY: position.y,
          useAdvancedMovement: _useAdvancedMovement,
          usePathfinding: _usePathfinding,
          level:
              widget.level, // Pass the level to make enemies more challenging
          detectionRadius: _detectionRadius, // Pass custom detection radius
          shootingRadius: _bulletRange, // Pass custom shooting radius
          movementDuration:
              _enemyMovementDuration, // Pass custom movement speed
        ),
      );
    }

    _remainingEnemies = enemies.length;
  }

  @override
  void dispose() {
    // Clean up audio
    _audioService.stopBGM();

    // Don't reset the system UI mode here to keep the immersive mode
    _gameTimer.cancel();
    gameBoard.dispose();
    super.dispose();
  }

  void _gameLoop(Timer timer) {
    if (!_isGameRunning || _isPaused) return;

    // Increment game time counter
    _gameTime++;

    // Update walk sound cooldown
    if (_walkSoundCooldown > 0) {
      _walkSoundCooldown--;
    }

    // Update game components with frame skipping for better performance on lower-end devices
    final bool shouldUpdateVisuals = _frameCount % _updateInterval == 0;

    // Always update player
    _updatePlayer();

    // Only update enemy AI at a reduced interval if there are many enemies to reduce CPU load
    final shouldUpdateEnemyAI = _frameCount % (enemies.length > 3 ? 2 : 1) == 0;

    // Update all bullets
    _updateBullets();

    // Update all enemies (with conditional AI update to improve performance)
    for (var enemy in enemies) {
      if (shouldUpdateEnemyAI) {
        enemy.update(gameBoard, player, bullets);
      } else {
        // Just update position/animation without AI pathfinding
        enemy.updatePosition();
      }
    }

    gameBoard.update();

    // Check if player is in explosion area or hit by bullets
    bool playerHit = _checkPlayerCollisions();

    // Damage player if hit
    if (playerHit) {
      damage();
    }

    // Check for victory condition (all enemies defeated)
    if (_remainingEnemies <= 0) {
      _isGameRunning = false;
      _handleGameOver(true); // Player won
    }

    // Update coin animation effect
    if (player.justCollectedCoin) {
      _coinScaleEffect =
          1.5 -
          (player.coinAnimationFrames / player.maxCoinAnimationFrames) * 0.5;
    } else {
      _coinScaleEffect = 1.0;
    }

    // Update UI at a consistent rate for smoother animations
    _frameCount++;
    if (shouldUpdateVisuals) {
      setState(() {});
    }
  }

  void _updateBullets() {
    // Update bullet positions
    for (int i = bullets.length - 1; i >= 0; i--) {
      bullets[i].update();

      // Remove inactive bullets
      if (!bullets[i].isActive) {
        bullets.removeAt(i);
        continue;
      }

      // Check collisions with walls and hurdles
      int gridX = bullets[i].x.floor();
      int gridY = bullets[i].y.floor();

      // Check if bullet hit a wall or hurdle
      if (gameBoard.getTileType(gridX, gridY) == GameConstants.wallTile ||
          gameBoard.getTileType(gridX, gridY) == GameConstants.hurdleTile) {
        bullets[i].isActive = false;

        // Random chance to spawn collectibles when destroying hurdles (if enabled)
        if (_hasCollectibles &&
            gameBoard.getTileType(gridX, gridY) == GameConstants.hurdleTile) {
          _trySpawnCollectible(gridX, gridY);
        }
      }
    }
  }

  void _trySpawnCollectible(int x, int y) {
    final random = Random();
    // Check if we should spawn a collectible
    if (random.nextInt(100) < _chanceOfCollectibles) {
      // Determine which collectible to spawn (key, treasure, or coins)
      int roll = random.nextInt(100);
      if (roll < _keyChance) {
        // Spawn key (rare) - use tile type 12 for keys
        gameBoard.setTile(x, y, GameConstants.keyTile);
        print('Spawned a key at $x,$y');
      } else if (roll < _treasureChance) {
        // Spawn treasure (uncommon) - use tile type 13 for treasures
        gameBoard.setTile(x, y, GameConstants.treasureTile);
        print('Spawned a treasure at $x,$y');
      } else {
        // Spawn coins (common)
        gameBoard.setTile(x, y, GameConstants.coinTile);
      }
    }
  }

  bool _checkPlayerCollisions() {
    // Check explosions
    bool playerHit = false;

    // Check all bombs that are exploding
    for (var bomb in gameBoard.bombs) {
      if (bomb.isExploding) {
        // Check if player is on any of the explosion points
        if (bomb.explosionPoints.any(
          (point) => point.x == player.gridX && point.y == player.gridY,
        )) {
          playerHit = true;
          break;
        }

        // Check if any enemy is on an explosion point
        for (int i = enemies.length - 1; i >= 0; i--) {
          if (bomb.explosionPoints.any(
            (point) =>
                point.x == enemies[i].gridX && point.y == enemies[i].gridY,
          )) {
            // Remove the enemy - it was caught in the explosion
            enemies.removeAt(i);
            _remainingEnemies--;
          }
        }
      }
    }

    // Check collision between player and enemies
    for (var enemy in enemies) {
      if (player.gridX == enemy.gridX && player.gridY == enemy.gridY) {
        playerHit = true;
        break;
      }
    }

    // Check bullet collisions with player
    for (int i = bullets.length - 1; i >= 0; i--) {
      if (bullets[i].checkCollision(player.gridX, player.gridY)) {
        // Player hit by bullet
        playerHit = true;
        // Remove the bullet
        bullets[i].isActive = false;
        bullets.removeAt(i);
      }
    }

    return playerHit;
  }

  void _handleJoystickInput(double dx, double dy) {
    // Only process input when game is running and not paused
    if (!_isGameRunning || _isPaused) return;

    // Print joystick input for debugging
    print('Game received joystick input: dx=$dx, dy=$dy');

    // Calculate magnitude of the input vector
    double magnitude = sqrt(dx * dx + dy * dy);

    // If magnitude is below threshold, explicitly stop the player
    if (magnitude < 0.2) {
      // Lowered from 0.3 to be more responsive
      player.move(0, 0, gameBoard);
      return;
    }

    // Move the player directly with dx, dy values
    bool moved = player.move(dx, dy, gameBoard);

    // Print whether movement occurred
    print('Player movement result: $moved');

    // Play walk sound with cooldown
    if (moved && _walkSoundCooldown <= 0) {
      _audioService.playWalk();
      _walkSoundCooldown = 15; // Add cooldown to prevent sound spam
    }
  }

  void _handleBombButtonPressed() {
    if (!_isGameRunning || _isPaused || player.isPlantingBomb) return;

    // Start bomb planting animation
    player.plantBomb();

    // Play bomb plant sound
    _audioService.playBombPlant();

    // Place the bomb after a short delay (when animation is underway)
    Timer(const Duration(milliseconds: 300), () {
      gameBoard.placeBomb(player.gridX, player.gridY, () {
        // This callback is called when all explosions are complete
        setState(() {});
      });
      setState(() {});
    });
  }

  void _handlePausePressed() {
    HapticFeedback.mediumImpact();
    _audioService.playButtonClick();

    setState(() {
      _isPaused = true;
    });

    // Pause the background music
    _audioService.pauseBGM();
  }

  void _handleResumeGame() {
    setState(() {
      _isPaused = false;
    });

    // Resume the background music
    _audioService.resumeBGM();
  }

  void _handleExitGame() {
    Navigator.of(context).pop();
  }

  void _handleControlsChanged(bool joystickOnLeft) {
    setState(() {
      _joystickOnLeft = joystickOnLeft;
    });
  }

  Future<void> _handleGameOver(bool playerWon) async {
    // Short delay before showing game over/victory screen
    await Future.delayed(Duration(milliseconds: 1000));

    if (playerWon) {
      // Play victory sound
      _audioService.playVictory();

      // Calculate stars based on performance (lives remaining and time)
      int stars = _calculateStars();

      // Save progress to Firebase
      await saveGameResult(widget.level, stars, player.coins);

      // Navigate to victory page
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder:
              (context) => VictoryPage(
                difficulty: _getDifficultyName(),
                stars: stars,
                score: player.coins,
                level: widget.level,
              ),
        ),
      );
    } else {
      // Play game over sound
      _audioService.playGameOver();

      // Navigate to game lost page
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder:
              (context) => GameLostPage(
                difficulty: _getDifficultyName(),
                score: player.coins,
                level: widget.level,
              ),
        ),
      );
    }
  }

  String _getDifficultyName() {
    if (widget.level <= 3) return 'Easy';
    if (widget.level <= 7) return 'Medium';
    return 'Hard';
  }

  int _calculateStars() {
    // Base stars on lives remaining and time taken
    if (player.lives == 3) {
      return 3; // Perfect run
    } else if (player.lives == 2) {
      return 2; // Good run
    } else {
      return 1; // Completed but struggled
    }
  }

  Future<void> saveGameResult(
      int levelCompleted, int stars, int coinsCollected) async {
    final deviceService = DeviceService();
    
    // Make sure device ID is initialized
    if (!deviceService.isInitialized) {
      await deviceService.initDeviceId();
    }
    
    try {
      // Get sanitized device ID for Firebase paths
      final sanitizedDeviceId = deviceService.sanitizedDeviceId;
      print("Saving game result for device ID: $sanitizedDeviceId, Level: $levelCompleted, Stars: $stars, Coins: $coinsCollected");
      
      final userRef = FirebaseDatabase.instance.ref('users/$sanitizedDeviceId');
      
      // Get current user data
      final snapshot = await userRef.get();
      if (snapshot.exists) {
        // Update level progression logic
        final data = snapshot.value as Map<dynamic, dynamic>;
        final userData = Map<String, dynamic>.from(data);
        
        // Get current values
        final username = userData['username'] as String? ?? 'Player';
        final currentCoins = userData['coins'] is int 
            ? userData['coins'] as int 
            : int.tryParse(userData['coins']?.toString() ?? '0') ?? 0;
        final currentLevel = userData['level'] is int 
            ? userData['level'] as int 
            : int.tryParse(userData['level']?.toString() ?? '1') ?? 1;
        final newCoins = currentCoins + coinsCollected;
        
        // Get levels array to update stars
        var levelsArray = List<int>.filled(100, 0);
        if (userData.containsKey('levels') && userData['levels'] is List) {
          final dynamicList = userData['levels'] as List<dynamic>;
          levelsArray = List<int>.filled(100, 0);
          
          for (int i = 0; i < dynamicList.length && i < levelsArray.length; i++) {
            if (dynamicList[i] != null) {
              levelsArray[i] = dynamicList[i] is int 
                  ? dynamicList[i] as int 
                  : int.tryParse(dynamicList[i]?.toString() ?? '0') ?? 0;
            }
          }
        }
        
        // Update the stars for this level if better than previous
        if (levelCompleted < levelsArray.length) {
          levelsArray[levelCompleted] = stars > levelsArray[levelCompleted] 
              ? stars 
              : levelsArray[levelCompleted];
        }
        
        // Check if next level should be unlocked
        int newHighestLevel = currentLevel;
        if (stars > 0 && levelCompleted + 1 > currentLevel) {
          newHighestLevel = levelCompleted + 1;
        }
        
        // Create update map
        final updates = {
          'coins': newCoins,
          'level': newHighestLevel,
        };
        
        // Create a separate update for the levels array since it needs a different structure
        await userRef.child('levels').set(levelsArray);
        
        // Update user data (without levels field)
        await userRef.update(updates);
        print("Updated user data with new coins: $newCoins, level: $newHighestLevel");
        
        // Update leaderboard
        final leaderboardRef = FirebaseDatabase.instance.ref('leaderboard/$username');
        
        // Get existing leaderboard data first
        final leaderboardSnapshot = await leaderboardRef.get();
        int leaderboardCoins = newCoins;
        
        if (leaderboardSnapshot.exists) {
          final leaderboardData = leaderboardSnapshot.value as Map<dynamic, dynamic>;
          // Only update if current coins are higher than leaderboard
          if (leaderboardData.containsKey('coins') && 
              leaderboardData['coins'] is int && 
              leaderboardData['coins'] > newCoins) {
            leaderboardCoins = leaderboardData['coins'];
          }
        }
        
        await leaderboardRef.set({
          'coins': leaderboardCoins,
          'name': username
        });
        print("Updated leaderboard for $username with coins: $leaderboardCoins");
        
        // Save to SharedPreferences for quick access
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('coins', newCoins);
        await prefs.setInt('highestLevel', newHighestLevel);
        
        print("Game result saved successfully!");
      } else {
        print("User data not found, cannot save game result");
      }
    } catch (e) {
      print("Error saving game result: $e");
    }
  }

  void _updatePlayer() {
    // Check if player collected a key or treasure
    int tileType = gameBoard.getTileType(player.gridX, player.gridY);
    if (tileType == GameConstants.keyTile) {
      // Key tile
      gameBoard.setTile(player.gridX, player.gridY, GameConstants.emptyTile);
      _collectedKeys++;
      player.justCollectedCoin = true;
      player.coinAnimationFrames = player.maxCoinAnimationFrames;
      _audioService.playCoin();
    } else if (tileType == GameConstants.treasureTile) {
      // Treasure tile
      gameBoard.setTile(player.gridX, player.gridY, GameConstants.emptyTile);
      _collectedTreasures++;
      player.justCollectedCoin = true;
      player.coinAnimationFrames = player.maxCoinAnimationFrames;
      _audioService.playCoin();
    } else if (tileType == GameConstants.coinTile ||
        tileType == GameConstants.coinStackTile ||
        tileType == GameConstants.coinPouchTile ||
        tileType == GameConstants.coinBucketTile) {
      // Play coin sound for regular coins too
      _audioService.playCoin();
    }

    // Regular player update
    player.update(gameBoard);
  }

  // Plant bomb method called when bomb button is pressed or keyboard key is used
  void _plantBomb() {
    // Check if player is alive and not currently planting a bomb
    if (!player.isAlive() || player.isPlantingBomb) return;

    // Start the bomb planting animation
    player.plantBomb();

    // Play bomb plant sound
    _audioService.playBombPlant();

    // Wait for the animation to complete before actually placing the bomb
    Future.delayed(const Duration(milliseconds: 400), () {
      if (player.isAlive()) {
        // Place bomb at player's position
        gameBoard.placeBomb(player.gridX, player.gridY, () {
          // This is the callback for when all explosions are complete
          setState(() {
            // Update the UI when explosions are finished
          });
        }, onExplode: _handleExplosion);
      }
    });
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });

    if (_isPaused) {
      _audioService.pauseBGM();
    } else {
      _audioService.resumeBGM();
    }
  }

  void _resumeGame() {
    setState(() {
      _isPaused = false;
    });
    _audioService.resumeBGM();

    // Make sure keyboard controls focus is restored
    if (_controlType == GameConstants.controlTypeKeyboard) {
      _keyboardControls.focusNode.requestFocus();
    }
  }

  void _exitGame() {
    _isGameRunning = false;
    _audioService.stopBGM();
    Navigator.of(context).pop();
  }

  // Handle when control type is changed in settings
  void _onControlTypeChanged(String newControlType) {
    setState(() {
      _controlType = newControlType;
    });

    // Focus keyboard if switching to keyboard controls
    if (_controlType == GameConstants.controlTypeKeyboard) {
      _keyboardControls.focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine which set of controls to show based on control type and platform
    bool showTouchControls =
        _controlType == GameConstants.controlTypeTouch || !_hasPhysicalKeyboard;

    // Check if we're on web platform for UI adjustments
    bool isWebPlatform = kIsWeb;

    return _keyboardControls.buildKeyDetectorWidget(
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(GameConstants.backgroundImage),
              fit: BoxFit.cover,
            ),
          ),
          child: Stack(
            children: [
              // Game content
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isWebPlatform ? 60.0 : 40.0,
                  vertical: 0,
                ),
                child: Stack(
                  children: [
                    // Game board
                    Center(
                      child: AspectRatio(
                        aspectRatio: GameConstants.columns / GameConstants.rows,
                        child: Container(
                          decoration: BoxDecoration(
                            image: const DecorationImage(
                              image: AssetImage(
                                GameConstants.gameBoardBackgroundImage,
                              ),
                              fit: BoxFit.cover,
                            ),
                            border: Border.all(
                              color:
                                  isWebPlatform
                                      ? const Color(0xFFD1A758)
                                      : Colors.white,
                              width: isWebPlatform ? 3 : 2,
                            ),
                            boxShadow:
                                isWebPlatform
                                    ? [
                                      BoxShadow(
                                        color: Colors.black45,
                                        blurRadius: 15,
                                        spreadRadius: 5,
                                      ),
                                    ]
                                    : null,
                          ),
                          child: GameBoardWidget(
                            gameBoard: gameBoard,
                            player: player,
                            enemies: enemies,
                            bullets: bullets,
                          ),
                        ),
                      ),
                    ),

                    // Lives and coins display - positioned at left side
                    Positioned(
                      top: 20,
                      left: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isWebPlatform
                                  ? const Color(0xFF2D2B39).withOpacity(0.85)
                                  : Colors.black54,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                isWebPlatform
                                    ? const Color(0xFFD1A758)
                                    : Colors.white30,
                            width: isWebPlatform ? 1 : 1,
                          ),
                          boxShadow:
                              isWebPlatform
                                  ? [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                  : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Lives row
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  GameConstants.heartImage,
                                  width: 24,
                                  height: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'x ${player.lives}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isWebPlatform ? 18 : 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Coins row
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Animated coin size when collected
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: 24 * _coinScaleEffect,
                                  height: 24 * _coinScaleEffect,
                                  child: Center(
                                    child: Image.asset(
                                      GameConstants.coinImage,
                                      width: 24 * _coinScaleEffect,
                                      height: 24 * _coinScaleEffect,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${player.coins}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isWebPlatform ? 18 : 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),

                            // Show keys and treasures (for both mobile and web)
                            if (_collectedKeys > 0 ||
                                _collectedTreasures > 0 ||
                                isWebPlatform)
                              const SizedBox(height: 8),

                            // Keys row
                          ],
                        ),
                      ),
                    ),

                    // Show current control mode
                    if (kIsWeb)
                      Positioned(
                        top: 20,
                        right: 100,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D2B39).withOpacity(0.85),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFD1A758),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _controlType ==
                                        GameConstants.controlTypeKeyboard
                                    ? Icons.keyboard
                                    : Icons.touch_app,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _controlType ==
                                        GameConstants.controlTypeKeyboard
                                    ? 'Keyboard Controls'
                                    : 'Touch Controls',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Keyboard controls hint (only when keyboard controls are active)
                    if (_controlType == GameConstants.controlTypeKeyboard)
                      Positioned(
                        bottom: 30,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isWebPlatform
                                      ? const Color(
                                        0xFF2D2B39,
                                      ).withOpacity(0.85)
                                      : Colors.black54,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color:
                                    isWebPlatform
                                        ? const Color(0xFFD1A758)
                                        : Colors.white30,
                                width: isWebPlatform ? 2 : 1,
                              ),
                              boxShadow:
                                  isWebPlatform
                                      ? [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                      : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                keyDisplayWidget(
                                  label: "Move",
                                  keyNames: [
                                    _keyboardControls.getDisplayKeyName(
                                      _keyboardControls.upKey,
                                    ),
                                    _keyboardControls.getDisplayKeyName(
                                      _keyboardControls.leftKey,
                                    ),
                                    _keyboardControls.getDisplayKeyName(
                                      _keyboardControls.downKey,
                                    ),
                                    _keyboardControls.getDisplayKeyName(
                                      _keyboardControls.rightKey,
                                    ),
                                  ],
                                  showWASD: isWebPlatform,
                                ),
                                const SizedBox(width: 20),
                                keyDisplayWidget(
                                  label: "Bomb",
                                  keyNames: [
                                    _keyboardControls.getDisplayKeyName(
                                      _keyboardControls.bombKey,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Bomb button (only for touch controls)
              if (showTouchControls)
                Positioned(
                  bottom: 100,
                  right: _joystickOnLeft ? 40 : null,
                  left: _joystickOnLeft ? null : 40,
                  child: GestureDetector(
                    onTap: () {
                      if (!_isGameRunning || _isPaused) return;
                      _plantBomb();
                    },
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 2),
                      ),
                      child: Center(
                        child: Image.asset(
                          GameConstants.bombButtonImage,
                          width: 45,
                          height: 45,
                        ),
                      ),
                    ),
                  ),
                ),

              // Pause button
              Positioned(
                top: 20,
                right: 20,
                child: GestureDetector(
                  onTap: () {
                    _togglePause();
                  },
                  child: Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color:
                          isWebPlatform
                              ? const Color(0xFF2D2B39).withOpacity(0.85)
                              : Colors.black38,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            isWebPlatform
                                ? const Color(0xFFD1A758)
                                : Colors.white24,
                        width: isWebPlatform ? 2 : 1,
                      ),
                      boxShadow:
                          isWebPlatform
                              ? [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                              : null,
                    ),
                    child: const Icon(
                      Icons.pause,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),

              // Key and Treasure display box (beside pause button)
              Positioned(
                top: 20,
                right: 80,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF7AC74C),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Keys
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/images/key.png',
                            width: 18,
                            height: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'x $_collectedKeys',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Treasures
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/images/treasure.png',
                            width: 18,
                            height: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'x $_collectedTreasures',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Level indicator (below pause and treasure box)
              Positioned(
                top: 100,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D2B39).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFD1A758),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Text(
                    'LEVEL ${widget.level}',
                    style: const TextStyle(
                      fontFamily: 'Vip',
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Pause menu overlay
              if (_isPaused)
                Container(
                  color: Colors.black54,
                  child: Pause(
                    level: widget.level,
                    score: player.coins,
                    onResume: _resumeGame,
                    onRestart: () {
                      // Restart the current level
                      _resumeGame();
                      // Note: Implement restart functionality if needed
                    },
                    onExit: _exitGame,
                    onMusicVolumeChanged: (volume) {
                      _audioService.bgmVolume = volume;
                    },
                    onSfxVolumeChanged: (volume) {
                      _audioService.sfxVolume = volume;
                    },
                    onControlsChanged: (rightControls) {
                      setState(() {
                        _joystickOnLeft = !rightControls;
                      });
                    },
                    musicVolume: _audioService.bgmVolume,
                    sfxVolume: _audioService.sfxVolume,
                    rightControls: !_joystickOnLeft,
                    keyboardControls: _keyboardControls,
                    controlType: _controlType,
                    onControlTypeChanged: _onControlTypeChanged,
                  ),
                ),

              // Add the joystick controller here
              _buildJoystickControl(),
            ],
          ),
        ),
      ),
    );
  }

  // Widget to display keyboard controls
  Widget keyDisplayWidget({
    required String label,
    required List<String> keyNames,
    bool showWASD = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "$label: ",
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children:
              keyNames.map((key) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: Text(
                    key,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
        ),
        if (showWASD && label == "Move")
          const Row(
            children: [
              SizedBox(width: 10),
              Text(
                "or WASD",
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
      ],
    );
  }

  // Add handleExplosion method implementation
  void _handleExplosion(List<ExplosionPoint> points) {
    // Play explosion sound
    _audioService.playExplosion();

    // Handle any game logic needed when an explosion occurs
    // Check if any enemies or the player are in the explosion
    for (var point in points) {
      // Check if any enemy is at this point
      for (int i = enemies.length - 1; i >= 0; i--) {
        if (enemies[i].gridX == point.x && enemies[i].gridY == point.y) {
          // Enemy is hit by explosion
          enemies.removeAt(i);
          _remainingEnemies--;
        }
      }

      // Check if player is at this point
      if (player.gridX == point.x &&
          player.gridY == point.y &&
          !player.isInvulnerable) {
        damage();
      }
    }
  }

  void damage() {
    if (player.isInvulnerable) return;

    player.damage();
    _audioService.playDeath();

    if (player.lives <= 0) {
      _isGameRunning = false;
      _handleGameOver(false); // Player lost
    } else {
      // Reposition enemies away from spawn point to give player a chance
      _repositionEnemiesAwayFromSpawn();
    }
  }

  // Add this new method to reposition enemies
  void _repositionEnemiesAwayFromSpawn() {
    // Minimum safe distance from spawn point (Manhattan distance)
    final int safeDistance = 5;

    for (int i = 0; i < enemies.length; i++) {
      // Calculate Manhattan distance from spawn point
      int distanceToSpawn =
          (enemies[i].gridX - GameConstants.playerSpawnX).abs() +
          (enemies[i].gridY - GameConstants.playerSpawnY).abs();

      // If enemy is too close to spawn, reposition it
      if (distanceToSpawn < safeDistance) {
        // Find valid new positions far from spawn
        List<Point<int>> validPositions = [];

        // Check potential positions around the board
        for (int x = 0; x < GameConstants.rows; x++) {
          for (int y = 0; y < GameConstants.columns; y++) {
            // Skip walls, hurdles, and other invalid tiles
            if (gameBoard.getTileType(x, y) != GameConstants.emptyTile) {
              continue;
            }

            // Calculate distance to spawn
            int distance =
                (x - GameConstants.playerSpawnX).abs() +
                (y - GameConstants.playerSpawnY).abs();

            // Only consider positions sufficiently far from spawn
            if (distance >= safeDistance) {
              validPositions.add(Point(x, y));
            }
          }
        }

        // If we found valid positions, randomly choose one
        if (validPositions.isNotEmpty) {
          final Random random = Random();
          final newPos = validPositions[random.nextInt(validPositions.length)];

          // Reset enemy to new position
          enemies[i].gridX = newPos.x;
          enemies[i].gridY = newPos.y;
          enemies[i].displayX = newPos.x.toDouble();
          enemies[i].displayY = newPos.y.toDouble();

          // Reset enemy state
          enemies[i].setState(EnemyState.idle);

          print(
            'Repositioned enemy to ${newPos.x},${newPos.y} away from spawn',
          );
        }
      }
    }
  }

  Widget _buildJoystickControl() {
    if (_controlType != GameConstants.controlTypeTouch || _isPaused) {
      return const SizedBox.shrink(); // Don't show joystick for keyboard control or when paused
    }

    // Make position fixed by using static values that don't change
    // This ensures joystick position remains consistent throughout gameplay
    return Positioned(
      bottom: 90, // Fixed bottom position
      right: _joystickOnLeft ? null : 40, // Fixed side position
      left: _joystickOnLeft ? 0 : null, // Fixed side position
      child: SizedBox(
        width: 180,
        height: 180,
        // Adding a container with a fixed size to maintain position stability
        child: UnifiedJoystick(
          rightSide: !_joystickOnLeft,
          size: 180,
          baseColor: Colors.black.withOpacity(0.5),
          stickColor: Colors.white54,
          borderColor: Colors.white30,
          deadzone:
              0.2, // Increased deadzone from 0.15 to 0.2 to prevent small movements
          onMove: _handleJoystickInput,
        ),
      ),
    );
  }

  // Calculate coins earned based on stars and level
  int _calculateCoinsEarned(int stars) {
    // Base reward is 10 coins per star, plus level bonus
    int baseReward = stars * 10;
    int levelBonus = widget.level * 5;
    
    // Scale up rewards for higher levels
    if (widget.level > 10) {
      levelBonus *= 2;
    }
    
    return baseReward + levelBonus;
  }
}

class GameBoardWidget extends StatelessWidget {
  final GameBoard gameBoard;
  final Player player;
  final List<Enemy> enemies;
  final List<Bullet> bullets;

  const GameBoardWidget({
    super.key,
    required this.gameBoard,
    required this.player,
    required this.enemies,
    required this.bullets,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: GameBoardPainter(
        gameBoard: gameBoard,
        player: player,
        enemies: enemies,
        bullets: bullets,
      ),
    );
  }
}

class GameBoardPainter extends CustomPainter {
  final GameBoard gameBoard;
  final Player player;
  final List<Enemy> enemies;
  final List<Bullet> bullets;

  // Cache for images to avoid reloading
  static final Map<String, ui.Image> _imageCache = {};

  // Track if asset loading is complete
  bool _isLoaded = false;

  // Image loading counter
  int _loadingCounter = 0;

  GameBoardPainter({
    required this.gameBoard,
    required this.player,
    required this.enemies,
    required this.bullets,
  }) {
    _loadImages();
  }

  Future<void> _loadImages() async {
    if (_imageCache.isNotEmpty) {
      _isLoaded = true;
      return;
    }

    // Load all necessary images
    await Future.wait([
      _loadImage(GameConstants.wallImage, 'wall'),
      _loadImage(GameConstants.hurdleImage, 'hurdle'),
      _loadImage(GameConstants.bombImage, 'bomb'),
      _loadImage(GameConstants.bulletImage, 'bullet'),

      // Load coin images
      _loadImage(GameConstants.coinImage, 'coin'),
      _loadImage(GameConstants.coinStackImage, 'coinStack'),
      _loadImage(GameConstants.coinPouchImage, 'coinPouch'),
      _loadImage(GameConstants.coinBucketImage, 'coinBucket'),

      // Load key and treasure images (use placeholder images from assets)
      _loadImage('assets/images/key.png', 'key'),
      _loadImage('assets/images/treasure.png', 'treasure'),

      // Load all player frames
      ...List.generate(
        4,
        (i) => _loadImage(
          '${GameConstants.playerIdleSpritePath}${i + 1}.png',
          'playerIdle${i + 1}',
        ),
      ),
      ...List.generate(
        4,
        (i) => _loadImage(
          '${GameConstants.playerWalkSpritePath}${i + 1}.png',
          'playerWalk${i + 1}',
        ),
      ),
      ...List.generate(
        4,
        (i) => _loadImage(
          '${GameConstants.playerRunSpritePath}${i + 1}.png',
          'playerRun${i + 1}',
        ),
      ),
      ...List.generate(
        4,
        (i) => _loadImage(
          '${GameConstants.playerPlantSpritePath}${i + 1}.png',
          'playerPlant${i + 1}',
        ),
      ),
      // Load player death frames (previously respawn)
      ...List.generate(
        4,
        (i) => _loadImage(
          '${GameConstants.playerDeathSpritePath}${i + 1}.png',
          'playerDeath${i + 1}',
        ),
      ),

      // Load all enemy frames
      ...List.generate(
        5,
        (i) => _loadImage(
          '${GameConstants.enemyIdleSpritePath}${i + 1}.png',
          'enemyIdle${i + 1}',
        ),
      ),
      ...List.generate(
        8,
        (i) => _loadImage(
          '${GameConstants.enemyWalkSpritePath}${i + 1}.png',
          'enemyWalk${i + 1}',
        ),
      ),
      ...List.generate(
        5,
        (i) => _loadImage(
          '${GameConstants.enemyRunSpritePath}${i + 1}.png',
          'enemyRun${i + 1}',
        ),
      ),
      // Load enemy alert frames
      ...List.generate(
        3,
        (i) => _loadImage(
          '${GameConstants.enemyAlertSpritePath}${i + 1}.png',
          'enemyAlert${i + 1}',
        ),
      ),

      // Load all explosion frames
      ...List.generate(
        GameConstants.explosionFrames,
        (i) => _loadImage(
          '${GameConstants.explosionSpritePath}${i + 1}.png',
          'explosion${i + 1}',
        ),
      ),
    ]);
  }

  Future<void> _loadImage(String path, String key) async {
    if (_imageCache.containsKey(key)) return;

    _loadingCounter++;
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    _imageCache[key] = frame.image;
    _loadingCounter--;

    if (_loadingCounter == 0) {
      _isLoaded = true;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final tileWidth = size.width / GameConstants.columns;
    final tileHeight = size.height / GameConstants.rows;

    // Draw board tiles
    for (int x = 0; x < GameConstants.rows; x++) {
      for (int y = 0; y < GameConstants.columns; y++) {
        final tile = gameBoard.getTileType(x, y);
        final rect = Rect.fromLTWH(
          y * tileWidth,
          x * tileHeight,
          tileWidth,
          tileHeight,
        );

        // Draw different tiles based on the type
        switch (tile) {
          case GameConstants.wallTile:
            if (_imageCache.containsKey('wall')) {
              _drawImage(canvas, _imageCache['wall']!, rect);
            } else {
              canvas.drawRect(rect, Paint()..color = Colors.grey);
            }
            break;

          case GameConstants.hurdleTile:
            if (_imageCache.containsKey('hurdle')) {
              _drawImage(canvas, _imageCache['hurdle']!, rect);
            } else {
              canvas.drawRect(rect, Paint()..color = Colors.brown);
            }
            break;

          case GameConstants.bombTile:
            if (_imageCache.containsKey('bomb')) {
              _drawImage(canvas, _imageCache['bomb']!, rect);
            } else {
              canvas.drawRect(rect, Paint()..color = Colors.black);
            }
            break;

          case GameConstants.explosionTile:
            // Find the active bomb with this explosion tile
            Bomb? activeBomb;
            int frameIndex = 0;

            for (var bomb in gameBoard.bombs) {
              if (bomb.isExploding &&
                  bomb.explosionPoints.any((p) => p.x == x && p.y == y)) {
                activeBomb = bomb;
                frameIndex = bomb.explosionFrame;
                break;
              }
            }

            if (activeBomb != null &&
                _imageCache.containsKey('explosion${frameIndex + 1}')) {
              _drawImage(
                canvas,
                _imageCache['explosion${frameIndex + 1}']!,
                rect,
              );
            } else {
              canvas.drawRect(rect, Paint()..color = Colors.orange);
            }
            break;

          case GameConstants.coinTile:
            if (_imageCache.containsKey('coin')) {
              _drawImage(canvas, _imageCache['coin']!, rect);
            } else {
              canvas.drawRect(rect, Paint()..color = Colors.yellow);
            }
            break;

          case GameConstants.coinStackTile:
            if (_imageCache.containsKey('coinStack')) {
              _drawImage(canvas, _imageCache['coinStack']!, rect);
            } else {
              canvas.drawRect(rect, Paint()..color = Colors.amber);
            }
            break;

          case GameConstants.coinPouchTile:
            if (_imageCache.containsKey('coinPouch')) {
              _drawImage(canvas, _imageCache['coinPouch']!, rect);
            } else {
              canvas.drawRect(rect, Paint()..color = Colors.amber.shade800);
            }
            break;

          case GameConstants.coinBucketTile:
            if (_imageCache.containsKey('coinBucket')) {
              _drawImage(canvas, _imageCache['coinBucket']!, rect);
            } else {
              canvas.drawRect(rect, Paint()..color = Colors.amber.shade900);
            }
            break;

          case GameConstants.keyTile:
            if (_imageCache.containsKey('key')) {
              _drawImage(canvas, _imageCache['key']!, rect);
            } else {
              // Fallback if image isn't loaded yet
              canvas.drawRect(rect, Paint()..color = Colors.blue);
            }
            break;

          case GameConstants.treasureTile:
            if (_imageCache.containsKey('treasure')) {
              _drawImage(canvas, _imageCache['treasure']!, rect);
            } else {
              // Fallback if image isn't loaded yet
              canvas.drawRect(rect, Paint()..color = Colors.purple);
            }
            break;

          default:
            // Empty tile (transparent)
            break;
        }
      }
    }

    // Draw bullets
    if (_isLoaded && _imageCache.containsKey('bullet')) {
      for (var bullet in bullets) {
        if (bullet.isActive) {
          final bulletRect = Rect.fromLTWH(
            bullet.y * tileWidth - tileWidth / 4,
            bullet.x * tileHeight - tileHeight / 4,
            tileWidth / 2,
            tileHeight / 2,
          );

          // Calculate rotation angle for the bullet based on direction
          double angle = 0;
          if (bullet.directionX != 0) {
            angle = bullet.directionX > 0 ? pi / 2 : -pi / 2;
          } else if (bullet.directionY != 0) {
            angle = bullet.directionY > 0 ? 0 : pi;
          }

          // Draw rotated bullet
          _drawRotatedImage(canvas, _imageCache['bullet']!, bulletRect, angle);
        }
      }
    }

    // Draw player
    final playerRect = Rect.fromLTWH(
      player.displayY * tileWidth,
      player.displayX * tileHeight,
      tileWidth,
      tileHeight,
    );

    if (_isLoaded) {
      // Determine which sprite to use based on player state and frame
      String playerKey = '';
      switch (player.state) {
        case PlayerState.idle:
          playerKey = 'playerIdle${player.currentFrame + 1}';
          break;
        case PlayerState.walk:
          playerKey = 'playerWalk${player.currentFrame + 1}';
          break;
        case PlayerState.run:
          playerKey = 'playerRun${player.currentFrame + 1}';
          break;
        case PlayerState.plant:
          playerKey = 'playerPlant${player.currentFrame + 1}';
          break;
        case PlayerState.death:
          // Use death animation
          int frame = player.currentFrame % 4; // Limit to 4 frames
          playerKey = 'playerDeath${frame + 1}';
          break;
        case PlayerState.respawn:
          // TODO: Handle this case.
          throw UnimplementedError();
      }

      if (_imageCache.containsKey(playerKey)) {
        final image = _imageCache[playerKey]!;

        // Draw with horizontal flip based on direction
        final shouldFlip = player.direction == PlayerDirection.left;
        _drawImage(canvas, image, playerRect, flipHorizontally: shouldFlip);

        // If player is invulnerable, add a blinking halo effect
        if (player.isInvulnerable) {
          // Create a blinking effect by alternating opacity based on frame count
          final blinkAlpha =
              (player.invulnerabilityFrames % 10 < 5)
                  ? 179
                  : 77; // ~0.7 and ~0.3

          // Draw a more visible halo around the player
          canvas.drawCircle(
            playerRect.center,
            (playerRect.width + playerRect.height) / 3.5,
            Paint()
              ..color = Colors.lightBlueAccent.withAlpha(blinkAlpha)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6,
          );

          // Add a second inner halo for better effect
          canvas.drawCircle(
            playerRect.center,
            (playerRect.width + playerRect.height) / 5,
            Paint()
              ..color = Colors.white.withAlpha(blinkAlpha)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3,
          );
        }
      }
    } else {
      // Fallback if images are not yet loaded
      canvas.drawRect(playerRect, Paint()..color = Colors.blue);
    }

    // Draw enemies
    for (var enemy in enemies) {
      final enemyRect = Rect.fromLTWH(
        enemy.displayY * tileWidth,
        enemy.displayX * tileHeight,
        tileWidth,
        tileHeight,
      );

      if (_isLoaded) {
        // Determine which sprite to use based on enemy state and frame
        String enemyKey = '';
        int frameIndex = enemy.currentFrame;

        // Ensure the frame index is within bounds for each animation
        switch (enemy.state) {
          case EnemyState.idle:
            // Idle has 5 frames
            frameIndex = frameIndex % 5;
            enemyKey = 'enemyIdle${frameIndex + 1}';
            break;
          case EnemyState.walk:
            // Walk has 8 frames
            frameIndex = frameIndex % 8;
            enemyKey = 'enemyWalk${frameIndex + 1}';
            break;
          case EnemyState.run:
            // Run has 5 frames
            frameIndex = frameIndex % 5;
            enemyKey = 'enemyRun${frameIndex + 1}';
            break;
          case EnemyState.alert:
            // Alert has 3 frames
            frameIndex = frameIndex % 3;
            enemyKey = 'enemyAlert${frameIndex + 1}';
            break;
        }

        if (_imageCache.containsKey(enemyKey)) {
          final image = _imageCache[enemyKey]!;

          // Draw with horizontal flip based on direction
          final shouldFlip = enemy.direction == EnemyDirection.left;
          _drawImage(canvas, image, enemyRect, flipHorizontally: shouldFlip);
        } else {
          // Fallback if specific frame isn't loaded
          canvas.drawRect(enemyRect, Paint()..color = Colors.red);
        }
      } else {
        // Fallback if images are not yet loaded
        canvas.drawRect(enemyRect, Paint()..color = Colors.red);
      }
    }
  }

  void _drawImage(
    Canvas canvas,
    ui.Image image,
    Rect rect, {
    bool flipHorizontally = false,
  }) {
    if (flipHorizontally) {
      // Save the canvas state
      canvas.save();

      // Apply transformations to flip image horizontally
      final scale =
          Matrix4.identity()
            ..translate(rect.left + rect.width / 2, rect.top + rect.height / 2)
            ..scale(-1.0, 1.0)
            ..translate(
              -(rect.left + rect.width / 2),
              -(rect.top + rect.height / 2),
            );

      canvas.transform(scale.storage);

      // Draw the image
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        rect,
        Paint(),
      );

      // Restore the canvas state
      canvas.restore();
    } else {
      // Normal drawing without flipping
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        rect,
        Paint(),
      );
    }
  }

  void _drawRotatedImage(
    Canvas canvas,
    ui.Image image,
    Rect rect,
    double angle,
  ) {
    // Save the canvas state
    canvas.save();

    // Translate to center of the rect
    canvas.translate(rect.center.dx, rect.center.dy);

    // Rotate
    canvas.rotate(angle);

    // Draw the image centered on the origin
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCenter(
        center: Offset.zero,
        width: rect.width,
        height: rect.height,
      ),
      Paint(),
    );

    // Restore the canvas state
    canvas.restore();
  }

  @override
  bool shouldRepaint(GameBoardPainter oldDelegate) {
    // Always repaint since the game state changes frequently
    return true;
  }
}
