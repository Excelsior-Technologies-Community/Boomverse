import 'dart:math';
import 'constants.dart';
import 'game_board.dart';

enum PlayerDirection { up, down, left, right }

enum PlayerState { idle, walk, run, plant, death, respawn }

class Player {
  // Grid position (always integer)
  int gridX;
  int gridY;

  // Visual position for smooth transitions
  double displayX = 0;
  double displayY = 0;

  PlayerDirection direction;
  PlayerState state;
  int currentFrame = 0;
  int totalFrames = 4;
  int frameDuration = 5;
  int frameCounter = 0;
  bool isMoving = false;
  bool isPlantingBomb = false;

  // Player lives
  int lives;
  bool isInvulnerable = false;
  int invulnerabilityFrames = 0;
  final int maxInvulnerabilityFrames =
      60; // Exactly 1 second of invulnerability at 60fps
  bool isRespawning = false; // Track if player is respawning
  int respawnFrames = 0; // Frames counter for respawn animation
  final int maxRespawnFrames = 300; // 5 seconds at 60fps

  // Player score
  int coins = 0;
  bool justCollectedCoin = false;
  int coinAnimationFrames = 0;
  final int maxCoinAnimationFrames = 30; // Half a second of animation

  // Movement animation
  int movementDuration = 15; // Default frames to complete a move (slower)
  int movementCounter = 0;
  int? targetGridX;
  int? targetGridY;

  Player({
    required this.gridX,
    required this.gridY,
    this.direction = PlayerDirection.down,
    this.state = PlayerState.idle,
    this.lives = GameConstants.initialLives,
    this.coins = 0,
  }) {
    displayX = gridX.toDouble();
    displayY = gridY.toDouble();
  }

  // Initialize player at the spawn position
  factory Player.spawn() {
    return Player(
      gridX: GameConstants.playerSpawnX,
      gridY: GameConstants.playerSpawnY,
    );
  }

  void update(GameBoard gameBoard) {
    // Update animation frame
    frameCounter++;
    if (frameCounter >= frameDuration) {
      frameCounter = 0;
      currentFrame = (currentFrame + 1) % totalFrames;
    }

    // Update invulnerability frames
    if (isInvulnerable) {
      invulnerabilityFrames++;
      if (invulnerabilityFrames >= maxInvulnerabilityFrames) {
        isInvulnerable = false;
        invulnerabilityFrames = 0;
      }
    }

    // Update coin animation
    if (justCollectedCoin) {
      coinAnimationFrames++;
      if (coinAnimationFrames >= maxCoinAnimationFrames) {
        justCollectedCoin = false;
        coinAnimationFrames = 0;
      }
    }

    // Handle bomb planting animation
    if (isPlantingBomb) {
      if (frameCounter == 0 && currentFrame == 0) {
        // Bomb planting animation finished
        isPlantingBomb = false;
        setState(PlayerState.idle);
      }
      return; // Don't process movement while planting
    }

    // Handle movement animation
    if (isMoving && targetGridX != null && targetGridY != null) {
      movementCounter++;

      // Calculate smooth transition between tiles
      double progress = _smoothStep(movementCounter / movementDuration);
      if (progress >= 1.0) {
        // Complete the move
        displayX = targetGridX!.toDouble();
        displayY = targetGridY!.toDouble();
        gridX = targetGridX!;
        gridY = targetGridY!;
        targetGridX = null;
        targetGridY = null;
        isMoving = false;
        setState(PlayerState.idle);

        // Check for coin collection after completing the move
        checkCoinCollection(gameBoard);
      } else {
        // Smooth transition
        displayX = gridX + (targetGridX! - gridX) * progress;
        displayY = gridY + (targetGridY! - gridY) * progress;
      }
    }
  }

  // Smoothstep function for more natural movement easing
  double _smoothStep(double x) {
    if (x <= 0) return 0;
    if (x >= 1) return 1;
    return x * x * (3 - 2 * x); // Smoothstep formula
  }

  void checkCoinCollection(GameBoard gameBoard) {
    // Check if we're standing on a coin
    final tileType = gameBoard.getTileType(gridX, gridY);
    if (tileType >= GameConstants.coinTile &&
        tileType <= GameConstants.coinBucketTile) {
      // Collect the coin
      final coinValue = gameBoard.collectCoin(gridX, gridY);
      coins += coinValue;

      // Trigger the coin animation
      justCollectedCoin = true;
      coinAnimationFrames = 0;
    }
  }

  bool move(double dx, double dy, GameBoard gameBoard) {
    // Don't process new movement if already moving or planting
    if (isMoving || isPlantingBomb) return false;

    // Print the input values for debugging
    print('Player move input: dx=$dx, dy=$dy');

    // Determine primary direction from joystick input
    PlayerDirection newDirection;
    int newGridX = gridX;
    int newGridY = gridY;

    // Find the dominant direction (for movement and animation)
    // Note: In our grid system, gridX is rows (vertical) and gridY is columns (horizontal)
    if (dx.abs() > dy.abs()) {
      // Horizontal movement (affects gridY)
      if (dx > 0.3) {
        newDirection = PlayerDirection.right;
        newGridY += 1; // Move right (increase column)
      } else if (dx < -0.3) {
        newDirection = PlayerDirection.left;
        newGridY -= 1; // Move left (decrease column)
      } else {
        return false; // Not enough joystick movement
      }
    } else {
      // Vertical movement (affects gridX)
      if (dy > 0.3) {
        newDirection = PlayerDirection.down;
        newGridX += 1; // Move down (increase row)
      } else if (dy < -0.3) {
        newDirection = PlayerDirection.up;
        newGridX -= 1; // Move up (decrease row)
      } else {
        return false; // Not enough joystick movement
      }
    }

    // Update direction even if we can't move
    direction = newDirection;

    // Debug new target position
    print('Attempting to move to position: ($newGridX, $newGridY)');

    // Check if the move is valid
    if (!_checkCollision(newGridX, newGridY, gameBoard)) {
      // Start movement animation
      targetGridX = newGridX;
      targetGridY = newGridY;
      isMoving = true;
      movementCounter = 0;

      // Set animation state based on input intensity
      double inputMagnitude = sqrt(dx * dx + dy * dy);
      setState(inputMagnitude > 0.7 ? PlayerState.run : PlayerState.walk);

      // Adjust movement speed based on state
      if (state == PlayerState.run) {
        movementDuration = 12; // Medium-fast
      } else {
        movementDuration = 18; // Medium-slow
      }
      return true; // Movement started
    }

    return false; // No movement occurred
  }

  void plantBomb() {
    if (isMoving || isPlantingBomb) return;

    isPlantingBomb = true;
    setState(PlayerState.plant);
    // The actual bomb placement is handled in the game screen
  }

  void damage() {
    if (isInvulnerable) return;

    lives--;
    if (lives > 0) {
      // Show death animation briefly
      setState(PlayerState.death);

      // After a short delay, teleport to spawn point in idle state
      Future.delayed(const Duration(milliseconds: 300), () {
        // Reset position to spawn point
        gridX = GameConstants.playerSpawnX;
        gridY = GameConstants.playerSpawnY;
        displayX = gridX.toDouble();
        displayY = gridY.toDouble();
        direction = PlayerDirection.down;

        // Set player to idle state immediately
        setState(PlayerState.idle);
      });

      // Make player invulnerable
      isInvulnerable = true;
      invulnerabilityFrames = 0;
    }
  }

  bool _checkCollision(int x, int y, GameBoard gameBoard) {
    int tileType = gameBoard.getTileType(x, y);
    return tileType == GameConstants.wallTile ||
        tileType == GameConstants.hurdleTile;
  }

  void setState(PlayerState newState) {
    if (state != newState) {
      state = newState;
      currentFrame = 0;
      frameCounter = 0;

      // Update frames for the current animation
      switch (state) {
        case PlayerState.idle:
          totalFrames = 4;
          frameDuration = 10;
          break;
        case PlayerState.walk:
          totalFrames = 4;
          frameDuration = 8;
          break;
        case PlayerState.run:
          totalFrames = 4;
          frameDuration = 6;
          break;
        case PlayerState.plant:
          totalFrames = 4;
          frameDuration = 7;
          break;
        case PlayerState.death:
          totalFrames = 4;
          frameDuration = 15; // Slower animation for respawn
          break;
        case PlayerState.respawn:
          // TODO: Handle this case.
          throw UnimplementedError();
      }
    }
  }

  String getCurrentSpritePath() {
    String basePath;
    switch (state) {
      case PlayerState.idle:
        basePath = GameConstants.playerIdleSpritePath;
        break;
      case PlayerState.walk:
        basePath = GameConstants.playerWalkSpritePath;
        break;
      case PlayerState.run:
        basePath = GameConstants.playerRunSpritePath;
        break;
      case PlayerState.plant:
        basePath = GameConstants.playerPlantSpritePath;
        break;
      case PlayerState.death:
        basePath = GameConstants.playerDeathSpritePath;
        break;
      case PlayerState.respawn:
        // TODO: Handle this case.
        throw UnimplementedError();
    }

    // Return the current frame for the animation
    return '$basePath${currentFrame + 1}.png';
  }

  bool isAlive() {
    return lives > 0;
  }
}
