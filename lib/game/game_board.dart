import 'dart:math';
import 'dart:async';
import 'constants.dart';
import 'bomb.dart';

class GameBoard {
  late List<List<int>> board;
  final Random _random = Random();
  final List<Bomb> bombs = [];
  final List<ExplosionPoint> explosions = [];
  final List<CoinData> coins = [];
  
  // Track pending coins to appear after explosions
  final Map<String, CoinData> pendingCoins = {};
  
  GameBoard() {
    _initializeBoard();
  }
  
  void _initializeBoard() {
    // Create empty board
    board = List.generate(
      GameConstants.rows, 
      (_) => List.filled(GameConstants.columns, GameConstants.emptyTile)
    );
    
    // Place walls at the borders
    for (int x = 0; x < GameConstants.rows; x++) {
      for (int y = 0; y < GameConstants.columns; y++) {
        // Border walls
        if (x == 0 || x == GameConstants.rows - 1 || y == 0 || y == GameConstants.columns - 1) {
          board[x][y] = GameConstants.wallTile;
        }
        // Walls at every position where both x and y are multiples of 3
        else if (x % 3 == 0 && y % 3 == 0) {
          board[x][y] = GameConstants.wallTile;
        }
        // Random hurdles (30% chance)
        else if (_random.nextDouble() < 0.3) {
          board[x][y] = GameConstants.hurdleTile;
        }
      }
    }
    
    // Ensure the spawn point and its immediate surroundings are clear
    _clearSpawnArea();
  }
  
  void _clearSpawnArea() {
    // Clear the spawn point itself
    board[GameConstants.playerSpawnX][GameConstants.playerSpawnY] = GameConstants.emptyTile;
    
    // Clear a small area around the spawn point for initial movement
    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
        int x = GameConstants.playerSpawnX + dx;
        int y = GameConstants.playerSpawnY + dy;
        
        // Make sure we don't clear border walls
        if (x > 0 && x < GameConstants.rows - 1 && y > 0 && y < GameConstants.columns - 1) {
          // Don't clear fixed walls (those at positions where x and y are multiples of 3)
          if (!(x % 3 == 0 && y % 3 == 0)) {
            board[x][y] = GameConstants.emptyTile;
          }
        }
      }
    }
  }
  
  // Find valid spawn positions for enemies
  List<Point<int>> findEnemySpawnPositions(int count) {
    List<Point<int>> validPositions = [];
    
    // Create a list of all possible positions
    List<Point<int>> possiblePositions = [];
    for (int x = 1; x < GameConstants.rows - 1; x++) {
      for (int y = 1; y < GameConstants.columns - 1; y++) {
        // Only consider empty tiles away from player spawn
        if (board[x][y] == GameConstants.emptyTile) {
          // Ensure the position is not too close to player spawn
          int distanceFromPlayer = (x - GameConstants.playerSpawnX).abs() + 
                                  (y - GameConstants.playerSpawnY).abs();
          
          // Enemy should be at least 5 tiles away from player
          if (distanceFromPlayer >= 5) {
            possiblePositions.add(Point(x, y));
          }
        }
      }
    }
    
    // Shuffle the positions to randomize them
    possiblePositions.shuffle(_random);
    
    // Take the first 'count' positions or all if less are available
    int spawnCount = min(count, possiblePositions.length);
    for (int i = 0; i < spawnCount; i++) {
      validPositions.add(possiblePositions[i]);
    }
    
    return validPositions;
  }
  
  int getTileType(int x, int y) {
    if (x < 0 || x >= GameConstants.rows || y < 0 || y >= GameConstants.columns) {
      return GameConstants.wallTile; // Consider out of bounds as walls
    }
    return board[x][y];
  }
  
  void setTile(int x, int y, int tileType) {
    if (x < 0 || x >= GameConstants.rows || y < 0 || y >= GameConstants.columns) {
      return; // Ignore out of bounds
    }
    board[x][y] = tileType;
    
    // If setting a coin tile, add it to the coins list
    if (tileType == GameConstants.coinTile) {
      coins.add(CoinData(x, y, tileType, GameConstants.coinValue));
    } else if (tileType == GameConstants.coinStackTile) {
      coins.add(CoinData(x, y, tileType, GameConstants.coinStackValue));
    } else if (tileType == GameConstants.coinPouchTile) {
      coins.add(CoinData(x, y, tileType, GameConstants.coinPouchValue));
    } else if (tileType == GameConstants.coinBucketTile) {
      coins.add(CoinData(x, y, tileType, GameConstants.coinBucketValue));
    }
  }
  
  String _getPositionKey(int x, int y) {
    return '$x-$y';
  }
  
  void placeBomb(int x, int y, Function() onAllExplosionsComplete, {Function(List<ExplosionPoint>)? onExplode}) {
    // Don't place bombs on walls, hurdles, or other bombs
    if (board[x][y] != GameConstants.emptyTile) return;
    
    // Set tile to bomb
    board[x][y] = GameConstants.bombTile;
    
    final allExplosionPoints = <ExplosionPoint>[];
    final bombX = x;
    final bombY = y;
    final List<CoinSpawn> coinSpawns = [];
    
    // Create bomb object with captured variables to avoid the self-reference problem
    final bomb = Bomb(
      gridX: x,
      gridY: y,
      gameBoard: this,
      onExplode: (points) {
        // Mark explosion tiles and store explosion points
        allExplosionPoints.addAll(points);
        
        // Call the onExplode callback if provided
        if (onExplode != null) {
          onExplode(points);
        }
        
        for (var point in points) {
          // Don't explode walls
          if (getTileType(point.x, point.y) == GameConstants.wallTile) continue;
          
          // If it's a hurdle, try spawning a coin
          if (getTileType(point.x, point.y) == GameConstants.hurdleTile) {
            final coinData = _trySpawnCoin(point.x, point.y);
            if (coinData != null) {
              coinSpawns.add(CoinSpawn(coinData, point.x, point.y));
            }
          }
          
          // Set the tile to explosion
          board[point.x][point.y] = GameConstants.explosionTile;
          explosions.add(point);
        }
        
        // Set a timer to place coins shortly after explosion starts (400ms)
        Timer(const Duration(milliseconds: 400), () {
          for (var spawn in coinSpawns) {
            // Only place the coin if the position is still an explosion
            if (getTileType(spawn.x, spawn.y) == GameConstants.explosionTile) {
              board[spawn.x][spawn.y] = spawn.coin.type;
              coins.add(spawn.coin);
            }
          }
        });
      },
      onExplosionComplete: () {
        // Clean up any remaining explosion tiles
        for (var point in allExplosionPoints) {
          // Only clear if it's still an explosion (not a coin)
          if (getTileType(point.x, point.y) == GameConstants.explosionTile) {
            board[point.x][point.y] = GameConstants.emptyTile;
          }
        }
        
        // Find and remove this specific bomb
        bombs.removeWhere((b) => b.gridX == bombX && b.gridY == bombY);
        
        // If all bombs are gone, trigger callback
        if (bombs.isEmpty) {
          onAllExplosionsComplete();
        }
      },
    );
    
    bombs.add(bomb);
  }
  
  CoinData? _trySpawnCoin(int x, int y) {
    // Check if we should spawn a coin
    if (_random.nextInt(100) < GameConstants.coinDropChance) {
      // Determine coin type with different probabilities
      int randomValue = _random.nextInt(100);
      int coinType;
      int coinValue;
      
      if (randomValue < 70) {
        coinType = GameConstants.coinTile;
        coinValue = GameConstants.coinValue;
      } else if (randomValue < 90) {
        coinType = GameConstants.coinStackTile;
        coinValue = GameConstants.coinStackValue;
      } else if (randomValue < 98) {
        coinType = GameConstants.coinPouchTile;
        coinValue = GameConstants.coinPouchValue;
      } else {
        coinType = GameConstants.coinBucketTile;
        coinValue = GameConstants.coinBucketValue;
      }
      
      return CoinData(x, y, coinType, coinValue);
    }
    return null;
  }
  
  int collectCoin(int x, int y) {
    // Find the coin at this position
    final coinIndex = coins.indexWhere((coin) => coin.x == x && coin.y == y);
    if (coinIndex == -1) return 0;
    
    // Get the coin value
    final coinValue = coins[coinIndex].value;
    
    // Clear the coin
    board[x][y] = GameConstants.emptyTile;
    coins.removeAt(coinIndex);
    
    return coinValue;
  }
  
  void update() {
    // Update all bombs
    for (var bomb in bombs) {
      bomb.update();
    }
  }
  
  void clearExplosions() {
    // Clear all explosion tiles
    for (var point in explosions) {
      if (board[point.x][point.y] == GameConstants.explosionTile) {
        board[point.x][point.y] = GameConstants.emptyTile;
      }
    }
    explosions.clear();
  }
  
  bool isPointInExplosion(int x, int y) {
    return explosions.any((point) => point.x == x && point.y == y);
  }
  
  void dispose() {
    // Dispose all bombs
    for (var bomb in bombs) {
      bomb.dispose();
    }
    bombs.clear();
    explosions.clear();
    coins.clear();
    pendingCoins.clear();
  }
}

class CoinData {
  final int x;
  final int y;
  final int type;
  final int value;
  
  // Constructor that accepts both positional and named parameters
  CoinData(this.x, this.y, this.type, this.value);
  
  // Named constructor for when only type and value are provided
  CoinData.withTypeAndValue({required this.type, required this.value}) : 
    x = 0,  // default values
    y = 0;
}

// Helper class to track coin spawns during explosion
class CoinSpawn {
  final CoinData coin;
  final int x;
  final int y;
  
  CoinSpawn(this.coin, this.x, this.y);
} 