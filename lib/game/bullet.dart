import 'constants.dart';

class Bullet {
  // Position
  double x;
  double y;
  // Direction
  final double directionX;
  final double directionY;
  // Speed
  final double speed = 0.2; // Tiles per frame
  // Owner
  final bool isPlayerBullet;
  // Status
  bool isActive = true;
  
  Bullet({
    required this.x,
    required this.y,
    required this.directionX,
    required this.directionY,
    this.isPlayerBullet = false,
  });
  
  void update() {
    // Move in the specified direction
    x += directionX * speed;
    y += directionY * speed;
    
    // Check if bullet is out of bounds
    if (x < 0 || x >= GameConstants.rows || 
        y < 0 || y >= GameConstants.columns) {
      isActive = false;
    }
  }
  
  bool checkCollision(int tileX, int tileY) {
    // Check if bullet hits this tile
    return isActive && 
           (tileX - 0.5 <= x && x <= tileX + 0.5) && 
           (tileY - 0.5 <= y && y <= tileY + 0.5);
  }
} 