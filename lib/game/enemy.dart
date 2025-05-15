import 'dart:math';
import 'constants.dart';
import 'game_board.dart';
import 'player.dart';
import 'bullet.dart';

enum EnemyDirection { up, down, left, right }

enum EnemyState { idle, walk, run, alert }

// Helper class for A* pathfinding
class _Node {
  final Point<int> point;
  final double gScore;
  final double fScore;

  _Node(this.point, this.gScore, this.fScore);
}

class Enemy {
  // Grid position (always integer)
  int gridX;
  int gridY;

  // Visual position for smooth transitions
  double displayX = 0;
  double displayY = 0;

  EnemyDirection direction;
  EnemyState state;
  int currentFrame = 0;
  int totalFrames = 4;
  int frameDuration = 5;
  int frameCounter = 0;
  bool isMoving = false;

  // Movement animation
  int movementDuration = 15; // Default frames to complete a move
  int movementCounter = 0;
  int? targetGridX;
  int? targetGridY;

  // AI variables
  int movementCooldown = 0;
  final Random _random = Random();
  List<Point<int>> _pathToPlayer = [];
  bool _isFollowingPlayer = false;
  bool _isAlertActive = false; // Flag to track alert state
  int _alertDuration = 0; // Counter for alert animation
  final int _maxAlertDuration =
      6; // 0.1 seconds at 60fps (changed from 0.5 seconds)

  // Difficulty settings
  final bool useAdvancedMovement;
  final bool usePathfinding;
  final int level;

  // Detection radius increases with level
  final int detectionRadius;

  // Shooting
  int shootCooldown = 0;
  final int shootingRadius;
  late int shootingCooldown;

  // Animation speed
  int _animationCounter = 0;
  final int _idleAnimationSpeed = 10;
  final int _walkAnimationSpeed = 8;
  final int _runAnimationSpeed = 6;

  // Movement speed
  final double _moveProgress = 0.0;
  final double _movementSpeed = 0.02;

  Enemy({
    required this.gridX,
    required this.gridY,
    this.direction = EnemyDirection.down,
    this.state = EnemyState.idle,
    this.useAdvancedMovement = false,
    this.usePathfinding = false,
    this.level = 1,
    this.detectionRadius = GameConstants.enemyDetectionRadius,
    this.shootingRadius = GameConstants.enemyShootingRadius,
    this.movementDuration = 15,
  }) {
    displayX = gridX.toDouble();
    displayY = gridY.toDouble();

    // Configure enemy based on level
    _configureDifficulty();

    // Random initial movement cooldown to prevent enemies moving in sync
    movementCooldown = _random.nextInt(30);

    // Random initial shoot cooldown
    shootCooldown = _random.nextInt(shootingCooldown);
  }

  void _configureDifficulty() {
    // Shooting cooldown decreases with level (faster shooting)
    shootingCooldown = max(30, GameConstants.enemyShootCooldown - (level * 5));
  }

  void update(GameBoard gameBoard, Player player, List<Bullet> bullets) {
    // Update animation frame
    frameCounter++;
    if (frameCounter >= frameDuration) {
      frameCounter = 0;
      currentFrame = (currentFrame + 1) % totalFrames;

      // Handle alert animation
      if (state == EnemyState.alert) {
        _alertDuration++;
        if (_alertDuration >= _maxAlertDuration) {
          _isAlertActive = false;
          setState(EnemyState.run); // Switch to run after alert

          // Immediately follow path after alert ends
          if (_pathToPlayer.isNotEmpty && !isMoving) {
            _followPath(gameBoard);
          }
        }
      }
    }

    // Update shooting cooldown
    if (shootCooldown > 0) {
      shootCooldown--;
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
        setState(EnemyState.idle);

        // If we were following player, continue following the path
        if (_isFollowingPlayer &&
            _pathToPlayer.isNotEmpty &&
            state != EnemyState.alert) {
          _followPath(gameBoard);
        }
      } else {
        // Smooth transition
        displayX = gridX + (targetGridX! - gridX) * progress;
        displayY = gridY + (targetGridY! - gridY) * progress;
      }
    } else {
      // Check if we can see and shoot the player
      _tryShootPlayer(player, gameBoard, bullets);

      // AI behavior - decide when to move
      if (movementCooldown > 0) {
        movementCooldown--;
      } else {
        // Check if player is within detection radius
        double distanceToPlayer = sqrt(
          pow(gridX - player.gridX, 2) + pow(gridY - player.gridY, 2),
        );

        if (distanceToPlayer <= detectionRadius) {
          if (usePathfinding) {
            // Advanced AI with A* pathfinding
            if (!_isFollowingPlayer) {
              // Just found the player, show alert animation
              _isAlertActive = true;
              _alertDuration = 0; // Reset alert duration
              setState(EnemyState.alert);
            }

            _isFollowingPlayer = true;
            _pathToPlayer = _findPathToPlayer(gameBoard, player);

            // Only follow path if not in alert state
            if (state != EnemyState.alert) {
              _followPath(gameBoard);
            }
          } else if (useAdvancedMovement) {
            // Advanced movement - try to move toward player
            _moveTowardPlayer(gameBoard, player);
          } else {
            // Basic movement - just make more frequent random moves
            _makeRandomMove(gameBoard);
            movementCooldown = max(
              15,
              30 - level,
            ); // More frequent moves at higher levels
          }
        } else if (_isFollowingPlayer) {
          // Player moved out of range, clear path
          _isFollowingPlayer = false;
          _pathToPlayer.clear();
          // Make random move after a short cooldown
          movementCooldown = 30;
        } else {
          // Make a random move
          _makeRandomMove(gameBoard);

          // Set a cooldown based on level
          movementCooldown = _random.nextInt(60) + max(15, 30 - level);
        }
      }
    }
  }

  void _moveTowardPlayer(GameBoard gameBoard, Player player) {
    // Simple chase behavior - try to move directly toward player
    List<Point<int>> possibleMoves = [];

    // Calculate horizontal and vertical distance to player
    int horizontalDistance = player.gridX - gridX;
    int verticalDistance = player.gridY - gridY;

    // Determine which direction to prioritize
    bool prioritizeHorizontal =
        horizontalDistance.abs() > verticalDistance.abs();

    if (prioritizeHorizontal) {
      // Try horizontal move first
      if (horizontalDistance < 0) {
        // Try move left
        _tryAddMove(gameBoard, gridX - 1, gridY, possibleMoves);
      } else if (horizontalDistance > 0) {
        // Try move right
        _tryAddMove(gameBoard, gridX + 1, gridY, possibleMoves);
      }

      // Then try vertical
      if (verticalDistance < 0) {
        // Try move up
        _tryAddMove(gameBoard, gridX, gridY - 1, possibleMoves);
      } else if (verticalDistance > 0) {
        // Try move down
        _tryAddMove(gameBoard, gridX, gridY + 1, possibleMoves);
      }
    } else {
      // Try vertical move first
      if (verticalDistance < 0) {
        // Try move up
        _tryAddMove(gameBoard, gridX, gridY - 1, possibleMoves);
      } else if (verticalDistance > 0) {
        // Try move down
        _tryAddMove(gameBoard, gridX, gridY + 1, possibleMoves);
      }

      // Then try horizontal
      if (horizontalDistance < 0) {
        // Try move left
        _tryAddMove(gameBoard, gridX - 1, gridY, possibleMoves);
      } else if (horizontalDistance > 0) {
        // Try move right
        _tryAddMove(gameBoard, gridX + 1, gridY, possibleMoves);
      }
    }

    // If we can't move in the preferred directions, try any valid move
    if (possibleMoves.isEmpty) {
      _tryAddMove(gameBoard, gridX - 1, gridY, possibleMoves); // Left
      _tryAddMove(gameBoard, gridX + 1, gridY, possibleMoves); // Right
      _tryAddMove(gameBoard, gridX, gridY - 1, possibleMoves); // Up
      _tryAddMove(gameBoard, gridX, gridY + 1, possibleMoves); // Down
    }

    // Choose a move if possible
    if (possibleMoves.isNotEmpty) {
      Point<int> nextMove =
          possibleMoves[_random.nextInt(possibleMoves.length)];
      _startMove(nextMove.x, nextMove.y);
    }
  }

  void _startMove(int newX, int newY) {
    // Set target position
    targetGridX = newX;
    targetGridY = newY;
    isMoving = true;
    movementCounter = 0;

    // Determine direction
    if (newX < gridX) {
      direction = EnemyDirection.up;
    } else if (newX > gridX) {
      direction = EnemyDirection.down;
    } else if (newY < gridY) {
      direction = EnemyDirection.left;
    } else if (newY > gridY) {
      direction = EnemyDirection.right;
    }

    // Set animation state
    setState(EnemyState.walk);
  }

  void _tryAddMove(
    GameBoard gameBoard,
    int x,
    int y,
    List<Point<int>> possibleMoves,
  ) {
    if (x >= 0 &&
        x < GameConstants.columns &&
        y >= 0 &&
        y < GameConstants.rows &&
        gameBoard.getTileType(x, y) == GameConstants.emptyTile) {
      possibleMoves.add(Point(x, y));
    }
  }

  void _tryShootPlayer(
    Player player,
    GameBoard gameBoard,
    List<Bullet> bullets,
  ) {
    // Don't shoot if cooldown is active
    if (shootCooldown > 0) return;

    // Check if player is in same row or column
    bool sameRow = gridX == player.gridX;  // Same X = same row (vertical alignment)
    bool sameColumn = gridY == player.gridY;  // Same Y = same column (horizontal alignment)

    if (!sameRow && !sameColumn) return; // Not aligned

    // Calculate distance to player
    double distance =
        sameRow
            ? (gridY - player.gridY).abs().toDouble()  // If in same row, check Y distance
            : (gridX - player.gridX).abs().toDouble();  // If in same column, check X distance

    // Check if player is within shooting range
    if (distance > shootingRadius) return;

    // Determine correct facing direction
    EnemyDirection requiredDirection;
    if (sameRow) {
      // Same row (X) - need to face up or down
      requiredDirection =
          player.gridY < gridY ? EnemyDirection.up : EnemyDirection.down;
    } else {
      // Same column (Y) - need to face left or right
      requiredDirection =
          player.gridX < gridX ? EnemyDirection.left : EnemyDirection.right;
    }

    // Check if we're facing the right direction
    if (direction != requiredDirection) {
      // Face toward player
      direction = requiredDirection;
      return; // Don't shoot yet, just face the player first
    }

    // Check for obstacles in the way
    bool pathClear = true;
    if (sameRow) {
      // Same row (X) - check along Y axis
      int startY = min(gridY, player.gridY);
      int endY = max(gridY, player.gridY);
      for (int y = startY + 1; y < endY; y++) {
        if (gameBoard.getTileType(gridX, y) == GameConstants.wallTile ||
            gameBoard.getTileType(gridX, y) == GameConstants.hurdleTile) {
          pathClear = false;
          break;
        }
      }
    } else {
      // Same column (Y) - check along X axis
      int startX = min(gridX, player.gridX);
      int endX = max(gridX, player.gridX);
      for (int x = startX + 1; x < endX; x++) {
        if (gameBoard.getTileType(x, gridY) == GameConstants.wallTile ||
            gameBoard.getTileType(x, gridY) == GameConstants.hurdleTile) {
          pathClear = false;
          break;
        }
      }
    }

    if (!pathClear) return; // Don't shoot if something's in the way

    // All conditions met, fire bullet!
    double dirX = 0;
    double dirY = 0;

    switch (direction) {
      case EnemyDirection.up:
        dirY = -1;
        break;
      case EnemyDirection.down:
        dirY = 1;
        break;
      case EnemyDirection.left:
        dirX = -1;
        break;
      case EnemyDirection.right:
        dirX = 1;
        break;
    }

    // Calculate the exact vector to the player for more accurate firing
    double exactDirX = 0;
    double exactDirY = 0;

    if (sameRow) {
      // Player is in the same row (vertical alignment - X coordinates match)
      exactDirX = 0;
      exactDirY = (player.gridY > gridY) ? 1 : -1;
    } else if (sameColumn) {
      // Player is in the same column (horizontal alignment - Y coordinates match)
      exactDirX = (player.gridX > gridX) ? 1 : -1;
      exactDirY = 0;
    }

    // Create bullet with the exact direction
    bullets.add(
      Bullet(
        x: gridX.toDouble(),
        y: gridY.toDouble(),
        directionX: exactDirX,
        directionY: exactDirY,
      ),
    );

    // Reset cooldown
    shootCooldown = shootingCooldown;
  }

  void _followPath(GameBoard gameBoard) {
    if (isMoving) return;
    if (_pathToPlayer.isEmpty) return;

    // Get the next point in the path
    Point<int> nextPoint = _pathToPlayer.removeAt(0);
    int newGridX = nextPoint.x;
    int newGridY = nextPoint.y;

    // Determine direction
    if (newGridX < gridX) {
      direction = EnemyDirection.up;
    } else if (newGridX > gridX) {
      direction = EnemyDirection.down;
    } else if (newGridY < gridY) {
      direction = EnemyDirection.left;
    } else if (newGridY > gridY) {
      direction = EnemyDirection.right;
    }

    // Start movement
    targetGridX = newGridX;
    targetGridY = newGridY;
    isMoving = true;
    movementCounter = 0;

    // Set animation to run when following player
    setState(EnemyState.run);
    movementDuration = 30; // Slower movement when chasing (was 12)
  }

  List<Point<int>> _findPathToPlayer(GameBoard gameBoard, Player player) {
    // A* pathfinding algorithm
    final start = Point(gridX, gridY);
    final goal = Point(player.gridX, player.gridY);

    if (start == goal) return []; // Already at goal

    // Create a manually sorted list instead of a PriorityQueue
    var openList = <_Node>[];
    openList.add(_Node(start, 0, _heuristic(start, goal)));

    // Keep track of visited nodes and their scores
    var cameFrom = <String, Point<int>>{};
    var gScore = <String, double>{};
    gScore[_getNodeKey(start)] = 0;

    // Find the path
    while (openList.isNotEmpty) {
      // Sort by fScore and get the first item
      openList.sort((a, b) => a.fScore.compareTo(b.fScore));
      var current = openList.removeAt(0);

      if (current.point == goal) {
        // Reconstruct the path
        return _reconstructPath(cameFrom, current.point);
      }

      // Check all adjacent tiles
      for (var dir in [
        [-1, 0],
        [1, 0],
        [0, -1],
        [0, 1],
      ]) {
        var neighbor = Point(
          current.point.x + dir[0],
          current.point.y + dir[1],
        );

        // Skip invalid or blocked neighbors
        if (neighbor.x < 0 ||
            neighbor.x >= GameConstants.rows ||
            neighbor.y < 0 ||
            neighbor.y >= GameConstants.columns ||
            _checkCollision(neighbor.x, neighbor.y, gameBoard)) {
          continue;
        }

        // Calculate new gScore
        var tentativeGScore = gScore[_getNodeKey(current.point)]! + 1;

        // If we found a better path to this neighbor
        if (!gScore.containsKey(_getNodeKey(neighbor)) ||
            tentativeGScore < gScore[_getNodeKey(neighbor)]!) {
          // Update the path
          cameFrom[_getNodeKey(neighbor)] = current.point;
          gScore[_getNodeKey(neighbor)] = tentativeGScore;

          // Add to priority queue
          var fScore = tentativeGScore + _heuristic(neighbor, goal);
          var node = _Node(neighbor, tentativeGScore, fScore);

          // Check if this node is already in the open list
          bool exists = false;
          for (int i = 0; i < openList.length; i++) {
            if (_getNodeKey(openList[i].point) == _getNodeKey(neighbor)) {
              // Replace with better path
              openList[i] = node;
              exists = true;
              break;
            }
          }

          // Add if not already in the open list
          if (!exists) {
            openList.add(node);
          }
        }
      }
    }

    // No path found, return empty list
    return [];
  }

  String _getNodeKey(Point<int> point) {
    return '${point.x},${point.y}';
  }

  double _heuristic(Point<int> a, Point<int> b) {
    // Manhattan distance
    return ((a.x - b.x).abs() + (a.y - b.y).abs()).toDouble();
  }

  List<Point<int>> _reconstructPath(
    Map<String, Point<int>> cameFrom,
    Point<int> current,
  ) {
    var path = <Point<int>>[current];
    var currentKey = _getNodeKey(current);

    while (cameFrom.containsKey(currentKey)) {
      current = cameFrom[currentKey]!;
      currentKey = _getNodeKey(current);
      path.insert(0, current);
    }

    // Remove the start position (current enemy position)
    if (path.isNotEmpty) {
      path.removeAt(0);
    }

    return path;
  }

  // Smoothstep function for more natural movement easing
  double _smoothStep(double x) {
    if (x <= 0) return 0;
    if (x >= 1) return 1;
    return x * x * (3 - 2 * x); // Smoothstep formula
  }

  void _makeRandomMove(GameBoard gameBoard) {
    if (isMoving) return;

    // Choose a random direction
    List<EnemyDirection> directions = [
      EnemyDirection.up,
      EnemyDirection.down,
      EnemyDirection.left,
      EnemyDirection.right,
    ];
    directions.shuffle(_random);

    // Try each direction until we find a valid move
    for (var dir in directions) {
      int newGridX = gridX;
      int newGridY = gridY;

      switch (dir) {
        case EnemyDirection.up:
          newGridX = gridX - 1;
          break;
        case EnemyDirection.down:
          newGridX = gridX + 1;
          break;
        case EnemyDirection.left:
          newGridY = gridY - 1;
          break;
        case EnemyDirection.right:
          newGridY = gridY + 1;
          break;
      }

      // Check if the move is valid
      if (!_checkCollision(newGridX, newGridY, gameBoard)) {
        // Set direction
        direction = dir;

        // Start movement animation
        targetGridX = newGridX;
        targetGridY = newGridY;
        isMoving = true;
        movementCounter = 0;

        // Set animation state (randomly choose walk or run)
        setState(_random.nextBool() ? EnemyState.run : EnemyState.walk);

        // Adjust movement speed based on state
        if (state == EnemyState.run) {
          movementDuration = 62; // Medium-fast
        } else {
          movementDuration = 128; // Medium-slow
        }

        // We found a valid move, so stop trying
        break;
      }
    }
  }

  bool _checkCollision(int x, int y, GameBoard gameBoard) {
    int tileType = gameBoard.getTileType(x, y);
    return tileType == GameConstants.wallTile ||
        tileType == GameConstants.hurdleTile ||
        tileType == GameConstants.bombTile;
  }

  void setState(EnemyState newState) {
    if (state != newState) {
      state = newState;
      currentFrame = 0;
      frameCounter = 0;

      // Update frames for the current animation
      switch (state) {
        case EnemyState.idle:
          totalFrames = 5; // Based on idle having 5 frames
          frameDuration = 10;
          break;
        case EnemyState.walk:
          totalFrames = 8; // Based on walk having 8 frames
          frameDuration = 8;
          break;
        case EnemyState.run:
          totalFrames = 5; // Based on run having 5 frames
          frameDuration = 6;
          break;
        case EnemyState.alert:
          totalFrames = 3; // Alert has 3 frames
          frameDuration = 2; // Very fast animation for alert (was 8)
          break;
      }
    }
  }

  // Add updatePosition method that only updates animation and position without expensive AI logic
  void updatePosition() {
    // Only update animation and position, without pathfinding
    _animationCounter++;

    // Slow down animation based on state
    final animationSpeed =
        state == EnemyState.idle
            ? _idleAnimationSpeed
            : state == EnemyState.walk
            ? _walkAnimationSpeed
            : state == EnemyState.alert
            ? 2 // Alert animation speed (was 8)
            : _runAnimationSpeed;

    if (_animationCounter >= animationSpeed) {
      _animationCounter = 0;

      // Update animation frame
      currentFrame++;

      // Reset animation when it reaches the end based on state
      if (state == EnemyState.idle && currentFrame >= 5) {
        currentFrame = 0;
      } else if (state == EnemyState.walk && currentFrame >= 8) {
        currentFrame = 0;
      } else if (state == EnemyState.run && currentFrame >= 5) {
        currentFrame = 0;
      } else if (state == EnemyState.alert && currentFrame >= 3) {
        currentFrame = 0;
      }

      // Handle alert animation duration
      if (state == EnemyState.alert) {
        _alertDuration++;
        if (_alertDuration >= _maxAlertDuration) {
          _isAlertActive = false;
          setState(EnemyState.run);

          // When using updatePosition, we can't immediately follow the path
          // but we should set the cooldown to 0 so movement can resume immediately
          movementCooldown = 0;
        }
      }
    }

    // If moving, update display position to smooth out movement
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
        setState(EnemyState.idle);

        // Reset movement cooldown to ensure immediate action on next update
        if (_isFollowingPlayer) {
          movementCooldown = 0;
        }
      } else {
        // Smooth transition
        displayX = gridX + (targetGridX! - gridX) * progress;
        displayY = gridY + (targetGridY! - gridY) * progress;
      }
    }
  }
}
