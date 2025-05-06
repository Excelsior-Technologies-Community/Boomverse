import 'dart:async';
import 'constants.dart';
import 'game_board.dart';

class Bomb {
  final int gridX;
  final int gridY;
  
  int currentFrame = 0;
  bool isExploding = false;
  bool isComplete = false;
  
  Timer? _explosionTimer;
  Timer? _animationTimer;
  
  List<ExplosionPoint> explosionPoints = [];
  final Function(List<ExplosionPoint>) onExplode;
  final Function() onExplosionComplete;
  
  // Add getter for explosionFrame
  int get explosionFrame => currentFrame;
  
  Bomb({
    required this.gridX,
    required this.gridY,
    required this.onExplode,
    required this.onExplosionComplete,
    GameBoard? gameBoard,
  }) {
    // Start the detonation timer
    _explosionTimer = Timer(
      Duration(seconds: GameConstants.bombDetonationTime),
      () => _explode(gameBoard),
    );
  }
  
  void update() {
    if (isExploding) {
      // Animation logic happens in the separate timer
    }
  }
  
  void dispose() {
    _explosionTimer?.cancel();
    _animationTimer?.cancel();
  }
  
  void _explode(GameBoard? gameBoard) {
    isExploding = true;
    
    // Calculate explosion points in + pattern
    explosionPoints = _calculateExplosionPoints(gameBoard);
    
    // Notify listeners about explosion
    onExplode(explosionPoints);
    
    // Start explosion animation
    currentFrame = 0;
    _startExplosionAnimation();
  }
  
  void _startExplosionAnimation() {
    // Run through all explosion frames
    _animationTimer = Timer.periodic(
      Duration(milliseconds: (GameConstants.explosionDuration * 1000) ~/ GameConstants.explosionFrames),
      (timer) {
        currentFrame++;
        if (currentFrame >= GameConstants.explosionFrames) {
          timer.cancel();
          isExploding = false;
          isComplete = true;
          onExplosionComplete();
        }
      },
    );
  }
  
  List<ExplosionPoint> _calculateExplosionPoints(GameBoard? gameBoard) {
    List<ExplosionPoint> points = [];
    
    // Center point
    points.add(ExplosionPoint(gridX, gridY));
    
    // Check in four directions (up, right, down, left)
    const directions = [
      [-1, 0], // Up
      [0, 1],  // Right
      [1, 0],  // Down
      [0, -1], // Left
    ];
    
    for (var dir in directions) {
      final newX = gridX + dir[0];
      final newY = gridY + dir[1];
      
      // Skip if out of bounds
      if (newX < 0 || newX >= GameConstants.rows || 
          newY < 0 || newY >= GameConstants.columns) {
        continue;
      }
      
      // Skip if it's a wall (explosions can't penetrate walls)
      if (gameBoard != null && 
          gameBoard.getTileType(newX, newY) == GameConstants.wallTile) {
        continue;
      }
      
      // Add to explosion points
      points.add(ExplosionPoint(newX, newY));
    }
    
    return points;
  }
  
  String getCurrentExplosionSpritePath() {
    return '${GameConstants.explosionSpritePath}${currentFrame + 1}.png';
  }
}

class ExplosionPoint {
  final int x;
  final int y;
  
  ExplosionPoint(this.x, this.y);
} 