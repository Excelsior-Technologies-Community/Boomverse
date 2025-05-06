// Game Constants
class GameConstants {
  // Game board dimensions
  static const int rows = 13;
  static const int columns = 18;
  static const double tileSize = 32.0;

  // Tile types
  static const int emptyTile = 0;
  static const int wallTile = 1;
  static const int hurdleTile = 2;
  static const int bombTile = 3;
  static const int explosionTile = 4;
  static const int playerTile = 5;
  static const int coinTile = 6;
  static const int coinStackTile = 7;
  static const int coinPouchTile = 8;
  static const int coinBucketTile = 9;
  static const int enemyTile = 10; // Added enemy tile type
  static const int bulletTile = 11; // Added bullet tile type
  static const int keyTile = 12; // Added key tile type
  static const int treasureTile = 13; // Added treasure tile type

  // Player spawn position
  static const int playerSpawnX = 1;
  static const int playerSpawnY = 1;

  // Enemy settings
  static const int enemyCount = 2; // Number of enemies to spawn
  static const int enemyDetectionRadius =
      5; // Tiles radius for detecting player
  static const int enemyShootingRadius = 4; // Maximum tiles away to shoot
  static const int enemyShootCooldown =
      90; // Frames between shots (1.5 seconds)

  // Player movement speed
  static const double playerMovementSpeed = 2.5;

  // Player lives
  static const int initialLives = 3;

  // Bomb settings
  static const int bombDetonationTime = 3; // seconds
  static const int explosionDuration = 1; // seconds
  static const int explosionFrames = 7;

  // Coin values
  static const int coinValue = 1;
  static const int coinStackValue = 10;
  static const int coinPouchValue = 100;
  static const int coinBucketValue = 1000;

  // Coin drop chance (%)
  static const int coinDropChance = 20;

  // Default keyboard controls
  static const String defaultUpKey = 'ArrowUp';
  static const String defaultDownKey = 'ArrowDown';
  static const String defaultLeftKey = 'ArrowLeft';
  static const String defaultRightKey = 'ArrowRight';
  static const String defaultBombKey = 'Space';

  // Control types
  static const String controlTypeTouch = 'touch';
  static const String controlTypeKeyboard = 'keyboard';

  // Asset paths
  static const String backgroundImage = 'assets/images/background3.png';
  static const String gameBoardBackgroundImage =
      'assets/images/background2.png';
  static const String wallImage = 'assets/images/wall.png';
  static const String hurdleImage = 'assets/images/hurdle.png';
  static const String bombButtonImage = 'assets/images/bomb.png';
  static const String bombImage = 'assets/images/bomb2.png';
  static const String heartImage = 'assets/images/heart.png';
  static const String bulletImage = 'assets/images/bullet.png';

  // Coin images
  static const String coinImage = 'assets/images/coin.png';
  static const String coinStackImage = 'assets/images/coins_stack.png';
  static const String coinPouchImage = 'assets/images/coins_pouch.png';
  static const String coinBucketImage = 'assets/images/coins_bucket.png';

  // Player sprites
  static const String playerIdleSpritePath = 'assets/images/Player/idle/';
  static const String playerRunSpritePath = 'assets/images/Player/run/';
  static const String playerWalkSpritePath = 'assets/images/Player/walk/';
  static const String playerPlantSpritePath = 'assets/images/Player/plant/';
  static const String playerDeathSpritePath = 'assets/images/Player/death/';

  // Enemy sprites
  static const String enemyIdleSpritePath = 'assets/images/enemy/idle/';
  static const String enemyRunSpritePath = 'assets/images/enemy/run/';
  static const String enemyWalkSpritePath = 'assets/images/enemy/walk/';
  static const String enemyAlertSpritePath = 'assets/images/enemy/alert/';

  // Explosion sprites
  static const String explosionSpritePath = 'assets/images/explosion/';

  // Joystick assets
  static const String joystickKnobPath = 'assets/images/joystick_knob.png';
  static const String joystickBackgroundPath =
      'assets/images/joystick_background.png';
}
