import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();

  factory AudioService() {
    return _instance;
  }

  AudioService._internal();

  // Players for different audio types
  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  // Audio paths - updated to match actual file names in assets
  static const String bgMusic = 'audio/epic-cinematic-trailer-113981.mp3';
  static const String gameMusic = 'audio/game play music.mp3';
  static const String explosionSound = 'audio/explosion.wav';
  static const String coinSound = 'audio/game win (2).mp3';
  static const String walkSound = 'audio/walk sound.mp3';
  static const String bombPlantSound = 'audio/explosion.wav';
  static const String gameOverSound = 'audio/game lose.mp3';
  static const String victorySound = 'audio/game win (2).mp3';
  static const String buttonClickSound = 'audio/game pause.mp3';
  static const String deathSound = 'audio/death.mp3';

  // Settings
  bool _bgmEnabled = true;
  bool _sfxEnabled = true;
  double _bgmVolume = 0.5;
  double _sfxVolume = 0.7;

  // Initialize audio settings from SharedPreferences
  Future<void> init() async {
    print('Initializing AudioService...');
    final prefs = await SharedPreferences.getInstance();
    _bgmEnabled = prefs.getBool('bgm_enabled') ?? true;
    _sfxEnabled = prefs.getBool('sfx_enabled') ?? true;
    _bgmVolume = prefs.getDouble('bgm_volume') ?? 0.5;
    _sfxVolume = prefs.getDouble('sfx_volume') ?? 0.7;

    print('Audio settings loaded - BGM: $_bgmEnabled, SFX: $_sfxEnabled');
    print('Volumes - BGM: $_bgmVolume, SFX: $_sfxVolume');

    // Configure players
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    await _bgmPlayer.setVolume(_bgmEnabled ? _bgmVolume : 0);
    await _sfxPlayer.setVolume(_sfxEnabled ? _sfxVolume : 0);

    // Add player state listener
    _bgmPlayer.onPlayerStateChanged.listen((state) {
      print('Background music player state changed: $state');
    });

    _bgmPlayer.onPlayerComplete.listen((_) {
      print('Background music completed, restarting...');
      playBGM();
    });

    // Start background music
    await playBGM();
  }

  // Save settings to SharedPreferences
  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bgm_enabled', _bgmEnabled);
    await prefs.setBool('sfx_enabled', _sfxEnabled);
    await prefs.setDouble('bgm_volume', _bgmVolume);
    await prefs.setDouble('sfx_volume', _sfxVolume);
  }

  // BGM Controls
  Future<void> playBGM() async {
    if (!_bgmEnabled) {
      print('BGM is disabled, not playing background music');
      return;
    }

    try {
      print('Attempting to play background music: $bgMusic');

      // First check if we need to load the source
      if (_bgmPlayer.source == null) {
        print('Loading background music source...');
        await _bgmPlayer.setSource(AssetSource(bgMusic));
      }

      // Stop any existing playback
      await _bgmPlayer.stop();

      // Start playing
      print('Starting background music playback...');
      await _bgmPlayer.resume();
      await _bgmPlayer.setVolume(_bgmVolume);

      print('Background music started successfully');
    } catch (e) {
      print("Error playing background music: $e");
      // Try to recover by reloading the source
      try {
        print('Attempting to recover by reloading source...');
        await _bgmPlayer.setSource(AssetSource(bgMusic));
        await _bgmPlayer.resume();
        await _bgmPlayer.setVolume(_bgmVolume);
      } catch (recoveryError) {
        print("Failed to recover background music: $recoveryError");
      }
    }
  }

  Future<void> playGameBGM() async {
    if (!_bgmEnabled) return;

    try {
      // Stop any existing BGM first
      await _bgmPlayer.stop();
      // Play the game music
      await _bgmPlayer.play(AssetSource(gameMusic));
      await _bgmPlayer.setVolume(_bgmVolume);
    } catch (e) {
      print("Error playing game music: $e");
    }
  }

  Future<void> stopBGM() async {
    await _bgmPlayer.stop();
  }

  Future<void> pauseBGM() async {
    await _bgmPlayer.pause();
  }

  Future<void> resumeBGM() async {
    if (!_bgmEnabled) return;

    try {
      // First check if player is already playing
      PlayerState state = _bgmPlayer.state;

      if (state == PlayerState.paused) {
        // Resume if paused
        await _bgmPlayer.resume();
      } else if (state == PlayerState.stopped ||
          state == PlayerState.completed) {
        // Restart if stopped
        await _bgmPlayer.play(AssetSource(bgMusic));
      }

      // Ensure volume is set correctly
      await _bgmPlayer.setVolume(_bgmVolume);
    } catch (e) {
      print("Error resuming background music: $e");
    }
  }

  // SFX Controls
  Future<void> playSound(String sound) async {
    if (!_sfxEnabled) {
      print('SFX is disabled, not playing sound: $sound');
      return;
    }

    try {
      print('Attempting to play sound effect: $sound');
      await _sfxPlayer.play(AssetSource(sound));
      print('Sound effect played successfully');
    } catch (e) {
      print("Error playing sound effect: $e");
    }
  }

  Future<void> playExplosion() async {
    await playSound(explosionSound);
  }

  Future<void> playCoin() async {
    await playSound(coinSound);
  }

  Future<void> playWalk() async {
    await playSound(walkSound);
  }

  Future<void> playBombPlant() async {
    await playSound(bombPlantSound);
  }

  Future<void> playGameOver() async {
    await playSound(gameOverSound);
  }

  Future<void> playVictory() async {
    await playSound(victorySound);
  }

  Future<void> playButtonClick() async {
    await playSound(buttonClickSound);
  }

  Future<void> playDeath() async {
    await playSound(deathSound);
  }

  // Settings Getters and Setters
  bool get bgmEnabled => _bgmEnabled;
  set bgmEnabled(bool value) {
    _bgmEnabled = value;
    _bgmPlayer.setVolume(value ? _bgmVolume : 0);
    saveSettings();
  }

  bool get sfxEnabled => _sfxEnabled;
  set sfxEnabled(bool value) {
    _sfxEnabled = value;
    saveSettings();
  }

  double get bgmVolume => _bgmVolume;
  set bgmVolume(double value) {
    _bgmVolume = value;
    if (_bgmEnabled) {
      _bgmPlayer.setVolume(value);
    }
    saveSettings();
  }

  double get sfxVolume => _sfxVolume;
  set sfxVolume(double value) {
    _sfxVolume = value;
    saveSettings();
  }

  // Clean up resources
  Future<void> dispose() async {
    await _bgmPlayer.dispose();
    await _sfxPlayer.dispose();
  }
}
