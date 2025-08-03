import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'package:word_match_game_flutter/models/word_pair.dart';
import 'package:word_match_game_flutter/services/sound_service.dart';
import 'package:word_match_game_flutter/services/tts_service.dart';
import 'package:word_match_game_flutter/services/settings_service.dart';
import 'package:word_match_game_flutter/providers/settings_provider.dart';

// ------------------- Models -------------------

class GameCard {
  final String id;
  final String text;
  final int pairId;
  CardStatus status;

  GameCard({
    required this.id,
    required this.text,
    required this.pairId,
    this.status = CardStatus.visible,
  });
}

enum CardStatus { visible, selected, mismatched, matched }

enum GameState { idle, playing, finished, paused }

enum Difficulty { easy, normal, hard }

enum GameMode { classic, timeAttack }

// ------------------- State Management -------------------
class GameController with ChangeNotifier {
  GameState _gameState = GameState.idle;
  bool _isLoading = true;
  List<GameCard> _cards = [];
  Timer? _timer;
  int _seconds = 0;
  Difficulty _difficulty = Difficulty.normal;
  GameMode _gameMode = GameMode.classic;
  Map<Difficulty, int> _pairCounts = {
    Difficulty.easy: 8,
    Difficulty.normal: 16,
    Difficulty.hard: 32,
  };
  Map<String, List<WordPair>> _wordLists = {};
  String _currentListKey = '';
  List<int> _selectedIndices = [];
  
  // Statistics
  int _matchedPairs = 0;
  int _mismatchedAttempts = 0;
  int _score = 0;
  int _streak = 0;
  int _highScore = 0;
  int _timeAttackHighScore = 0;
  int _gamesPlayed = 0;
  bool _newHighScore = false;
  Set<WordPair> _unfamiliarWords = {};
  static const String _unfamiliarWordsKey = 'Unfamiliar Words';
  static const String _unfamiliarPrefsKey = 'unfamiliar_words';
  static const String _highScorePrefsKey = 'high_score';
  static const String _timeAttackHighScorePrefsKey = 'time_attack_high_score';
  static const String _gamesPlayedPrefsKey = 'games_played';

  // Services
  final TTSService _ttsService = TTSService();
  final SoundService _soundService = SoundService();
  final SettingsProvider _settingsProvider;

  // Getters
  bool get isLoading => _isLoading;
  GameState get gameState => _gameState;
  List<GameCard> get cards => _cards;
  int get seconds => _seconds;
  Difficulty get difficulty => _difficulty;
  GameMode get gameMode => _gameMode;
  int get selectedPairCount => _pairCounts[_difficulty]!;
  int get matchedPairs => _matchedPairs;
  int get mismatchedAttempts => _mismatchedAttempts;
  int get score => _score;
  int get streak => _streak;
  int get highScore => _gameMode == GameMode.classic ? _highScore : _timeAttackHighScore;
  int get gamesPlayed => _gamesPlayed;
  bool get newHighScore => _newHighScore;
  List<WordPair> get unfamiliarWords => _unfamiliarWords.toList();
  String get accuracy {
    final totalAttempts = _matchedPairs + _mismatchedAttempts;
    if (totalAttempts == 0) return "100%";
    return '${((_matchedPairs / totalAttempts) * 100).toStringAsFixed(1)}%';
  }
  String get timerText {
    if (_gameMode == GameMode.timeAttack) {
      return (60 - _seconds).toString();
    }
    final minutes = (_seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }
  Map<String, List<WordPair>> get wordLists => _wordLists;
  String get currentListKey => _currentListKey;

  GameController(this._settingsProvider) {
    _ttsService.init();
    _initializeGame();
  }

  Future<void> _initializeGame() async {
    await _loadPersistentData();
    await _loadWordListsFromAssets();
  }

  @override
  void dispose() {
    _ttsService.dispose();
    _soundService.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadPersistentData() async {
    final prefs = await SharedPreferences.getInstance();
    _highScore = prefs.getInt(_highScorePrefsKey) ?? 0;
    _timeAttackHighScore = prefs.getInt(_timeAttackHighScorePrefsKey) ?? 0;
    _gamesPlayed = prefs.getInt(_gamesPlayedPrefsKey) ?? 0;
    final List<String>? wordsJson = prefs.getStringList(_unfamiliarPrefsKey);
    if (wordsJson != null) {
      _unfamiliarWords = wordsJson
          .map((json) => WordPair.fromJson(jsonDecode(json)))
          .toSet();
    }
  }

  Future<void> _saveHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    if (_gameMode == GameMode.classic) {
      await prefs.setInt(_highScorePrefsKey, _highScore);
    } else {
      await prefs.setInt(_timeAttackHighScorePrefsKey, _timeAttackHighScore);
    }
  }

  Future<void> _saveGamesPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_gamesPlayedPrefsKey, _gamesPlayed);
  }

  Future<void> _saveUnfamiliarWords() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> wordsJson = _unfamiliarWords
        .map((word) => jsonEncode(word.toJson()))
        .toList();
    await prefs.setStringList(_unfamiliarPrefsKey, wordsJson);
  }

  void removeUnfamiliarWord(WordPair word) {
    _unfamiliarWords.remove(word);
    _updateUnfamiliarWordsList();
    _saveUnfamiliarWords();
    notifyListeners();
  }
  
  void _updateUnfamiliarWordsList() {
    if (_unfamiliarWords.isNotEmpty) {
      _wordLists[_unfamiliarWordsKey] = _unfamiliarWords.toList();
    } else {
      _wordLists.remove(_unfamiliarWordsKey);
      if (_currentListKey == _unfamiliarWordsKey) {
        _currentListKey = _wordLists.keys.isNotEmpty ? _wordLists.keys.first : '';
      }
    }
  }

  Future<void> _loadWordListsFromAssets() async {
    _isLoading = true;
    notifyListeners();
    try {
      final List<String> assetFiles = [
        'word-a.json', 'word-aa.json', 'word-b.json', 'word-c.json',
        'word-d.json', 'word-e.json', 'word-f.json', 'word-g.json'
      ];

      for (var fileName in assetFiles) {
        try {
          final path = 'assets/$fileName';
          final String fileContent = await rootBundle.loadString(path);
          final List<dynamic> jsonList = json.decode(fileContent);
          if (jsonList.isEmpty) continue;

          List<WordPair> wordPairs;
          if (jsonList.first is List) {
            wordPairs = jsonList.map((item) => WordPair(item[0], item[1])).toList();
          } else if (jsonList.first is Map) {
            wordPairs = jsonList.map((item) => WordPair(item['english'], item['chinese'])).toList();
          } else {
            continue;
          }
          final String key = fileName.replaceAll('.json', '');
          _wordLists[key] = wordPairs;
        } catch (e) {
          print("Error loading or parsing asset $fileName: $e");
        }
      }
      
      _updateUnfamiliarWordsList();

      if (_currentListKey.isEmpty && _wordLists.isNotEmpty) {
        _currentListKey = _wordLists.keys.last;
      }
    } catch (e) {
      print('An error occurred while loading word lists: $e');
    } finally {
      _isLoading = false;
      _resetGame();
    }
  }

  void switchWordList(String key) {
    if (_wordLists.containsKey(key)) {
      _currentListKey = key;
      _resetGame();
    }
  }

  void setDifficulty(Difficulty difficulty) {
    _difficulty = difficulty;
    _resetGame();
  }

  void setGameMode(GameMode mode) {
    _gameMode = mode;
    _resetGame();
  }

  void _resetGame({bool notify = true}) {
    _gameState = GameState.idle;
    _cards.clear();
    _selectedIndices.clear();
    _matchedPairs = 0;
    _mismatchedAttempts = 0;
    _seconds = 0;
    _score = 0;
    _streak = 0;
    _newHighScore = false;
    _timer?.cancel();
    _generateCards();
    if (notify) {
      notifyListeners();
    }
  }

  void startGame() {
    _resetGame(notify: false);
    _gameState = GameState.playing;
    _gamesPlayed++;
    _saveGamesPlayed();
    for (var card in _cards) {
      card.status = CardStatus.visible;
    }
    _startTimer();
    notifyListeners();
  }

  void pauseGame() {
    if (_gameState == GameState.playing) {
      _timer?.cancel();
      _gameState = GameState.paused;
      notifyListeners();
    }
  }
  
  void resumeGame() {
    if (_gameState == GameState.paused) {
      _gameState = GameState.playing;
      _startTimer();
      notifyListeners();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_gameState == GameState.playing) {
        _seconds++;
        if (_gameMode == GameMode.timeAttack && _seconds >= 60) {
          _gameState = GameState.finished;
          _timer?.cancel();
          if(_settingsProvider.soundEnabled) _soundService.playWinSound();
          if (_score > _timeAttackHighScore) {
            _timeAttackHighScore = _score;
            _newHighScore = true;
            _saveHighScore();
          }
        }
        notifyListeners();
      }
    });
  }

  void _generateCards() {
    _cards.clear();
    if (_currentListKey.isEmpty || _wordLists[_currentListKey] == null || _wordLists[_currentListKey]!.isEmpty) return;

    List<WordPair> sourceList = _wordLists[_currentListKey]!;
    sourceList.shuffle();
    final pairs = sourceList.take(min(selectedPairCount, sourceList.length)).toList();

    int pairId = 0;
    for (var pair in pairs) {
      _cards.add(GameCard(id: 'en-$pairId', text: pair.english, pairId: pairId));
      _cards.add(GameCard(id: 'cn-$pairId', text: pair.chinese, pairId: pairId));
      pairId++;
    }
    _cards.shuffle();
  }

  void onCardTapped(int index) {
    if (_gameState != GameState.playing) return;

    final card = _cards[index];
    if(_settingsProvider.ttsEnabled) _ttsService.speak(card.text);
    if(_settingsProvider.soundEnabled) _soundService.playFlipSound();
    if(_settingsProvider.vibrationEnabled) Vibration.vibrate(duration: 50);

    if (card.status == CardStatus.matched || _selectedIndices.length >= 2) {
      return;
    }
    if (_selectedIndices.isNotEmpty && _selectedIndices[0] == index) {
      card.status = CardStatus.visible;
      _selectedIndices.clear();
      notifyListeners();
      return;
    }

    card.status = CardStatus.selected;
    _selectedIndices.add(index);
    notifyListeners();

    if (_selectedIndices.length == 2) {
      _checkMatch();
    }
  }

  void _checkMatch() {
    final index1 = _selectedIndices[0];
    final index2 = _selectedIndices[1];
    final card1 = _cards[index1];
    final card2 = _cards[index2];

    if (card1.pairId == card2.pairId) {
      card1.status = CardStatus.matched;
      card2.status = CardStatus.matched;
      _matchedPairs++;
      _streak++;
      _score += 100 + (_streak * 10);
      if(_settingsProvider.soundEnabled) _soundService.playMatchSound();
      if(_settingsProvider.vibrationEnabled) Vibration.vibrate(duration: 100);

      if (_gameMode == GameMode.classic && _matchedPairs == min(selectedPairCount, _wordLists[_currentListKey]!.length)) {
        _gameState = GameState.finished;
        _timer?.cancel();
        if(_settingsProvider.soundEnabled) _soundService.playWinSound();
        if (_score > _highScore) {
          _highScore = _score;
          _newHighScore = true;
          _saveHighScore();
        }
      }
    } else {
      _mismatchedAttempts++;
      _streak = 0;
      card1.status = CardStatus.mismatched;
      card2.status = CardStatus.mismatched;
      if(_settingsProvider.soundEnabled) _soundService.playMismatchSound();
      if(_settingsProvider.vibrationEnabled) Vibration.vibrate(duration: 200);
      final sourceList = _wordLists[_currentListKey]!;
      final wordPair = sourceList.firstWhere((p) {
          final text1 = card1.text;
          final text2 = card2.text;
          return p.english == text1 || p.chinese == text1 || p.english == text2 || p.chinese == text2;
      });
      
      if (_unfamiliarWords.add(wordPair)) {
        _updateUnfamiliarWordsList();
        _saveUnfamiliarWords();
      }
    }
    _selectedIndices.clear();
    notifyListeners();
  }

  void setCardStatus(int index, CardStatus status) {
    _cards[index].status = status;
    notifyListeners();
  }

  void restartGame() {
    startGame();
  }
}

// ------------------- UI -------------------
void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => SettingsProvider()),
        ChangeNotifierProvider(create: (context) => GameController(context.read<SettingsProvider>())),
      ],
      child: const WordMatchGame(),
    ),
  );
}

// ------------------- Themes -------------------
class AppThemes {
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.grey[200],
    cardColor: Colors.white,
    primaryColor: Colors.deepPurple,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
    textTheme: GoogleFonts.nunitoTextTheme(ThemeData.light().textTheme).apply(
      bodyColor: Colors.black87,
      displayColor: Colors.black87,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: Colors.black87,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.black87),
      iconTheme: IconThemeData(color: Colors.black87),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF1A1A2E),
    cardColor: const Color(0xFF2A2A4E),
    primaryColor: const Color(0xFFE94560),
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE94560), brightness: Brightness.dark),
    textTheme: GoogleFonts.nunitoTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFE94560),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: Colors.white,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white),
      iconTheme: IconThemeData(color: Colors.white),
    ),
  );
}

class WordMatchGame extends StatelessWidget {
  const WordMatchGame({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return MaterialApp(
      title: 'Word Match Game',
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      themeMode: settings.themeMode,
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameController>();
    final isPlaying = game.gameState == GameState.playing;

    return Scaffold(
      body: SafeArea(
          child: Column(
            children: [
              if (!isPlaying)
                AppBar(
                  title: Text('Word Match Game', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 24)),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.list_alt_rounded),
                      tooltip: 'Manage Unfamiliar Words',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => UnfamiliarWordsScreen()),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_rounded),
                      tooltip: 'Settings',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => SettingsScreen()),
                        );
                      },
                    ),
                  ],
                ),
              if (isPlaying || game.gameState == GameState.finished)
                StatisticsPanel(),
              if (!isPlaying)
                Expanded(
                  child: MainMenu(),
                ),
              if (isPlaying || game.gameState == GameState.paused)
                Expanded(child: GameGrid()),
              if (game.gameState == GameState.finished)
                Expanded(child: GameFinishedView()),
            ],
          ),
        ),
      floatingActionButton: isPlaying
          ? FloatingActionButton(
              onPressed: game.pauseGame,
              backgroundColor: const Color(0xFF0F3460),
              child: const Icon(Icons.pause),
            )
          : null,
    );
  }
}

class MainMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameController>();

    if (game.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        FloatingWordsBackground(),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              BreathingButton(onPressed: game.startGame),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  StatCard(label: 'High Score', value: game.highScore.toString(), icon: Icons.star_rounded, color: Colors.amber),
                  StatCard(label: 'Games Played', value: game.gamesPlayed.toString(), icon: Icons.gamepad_rounded, color: Colors.lightBlueAccent),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class BreathingButton extends StatefulWidget {
  final VoidCallback onPressed;
  const BreathingButton({Key? key, required this.onPressed}) : super(key: key);

  @override
  _BreathingButtonState createState() => _BreathingButtonState();
}

class _BreathingButtonState extends State<BreathingButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.play_arrow_rounded, size: 32),
        onPressed: widget.onPressed,
        label: Text('Start Game', style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const StatCard({Key? key, required this.label, required this.value, required this.icon, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(value, style: GoogleFonts.nunito(fontSize: 28, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
            Text(label, style: GoogleFonts.nunito(fontSize: 14, color: theme.textTheme.bodyMedium?.color)),
          ],
        ),
      ),
    );
  }
}

class FloatingWordsBackground extends StatefulWidget {
  @override
  _FloatingWordsBackgroundState createState() => _FloatingWordsBackgroundState();
}

class _FloatingWordsBackgroundState extends State<FloatingWordsBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<FloatingWord> _words = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 20), vsync: this)..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWords();
    });
  }

  void _initializeWords() {
    final game = context.read<GameController>();
    if (game.wordLists.isEmpty || game.currentListKey.isEmpty) return;

    final wordList = game.wordLists[game.currentListKey]!;
    final screen_size = MediaQuery.of(context).size;

    _words = List.generate(30, (index) {
      final word = wordList[_random.nextInt(wordList.length)];
      return FloatingWord(
        text: word.english,
        x: _random.nextDouble() * screen_size.width,
        y: _random.nextDouble() * screen_size.height,
        speed: _random.nextDouble() * 0.5 + 0.2,
        size: _random.nextDouble() * 20 + 10,
        opacity: _random.nextDouble() * 0.1 + 0.05,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: FloatingWordsPainter(words: _words, animationValue: _controller.value),
          child: Container(),
        );
      },
    );
  }
}

class FloatingWordsPainter extends CustomPainter {
  final List<FloatingWord> words;
  final double animationValue;

  FloatingWordsPainter({required this.words, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    for (var word in words) {
      final y = (word.y - animationValue * size.height * word.speed) % size.height;
      final textStyle = GoogleFonts.nunito(
        color: Colors.white.withOpacity(word.opacity),
        fontSize: word.size,
      );
      final textSpan = TextSpan(text: word.text, style: textStyle);
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(canvas, Offset(word.x, y));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class FloatingWord {
  String text;
  double x, y, speed, size, opacity;

  FloatingWord({
    required this.text,
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.opacity,
  });
}


class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final game = context.watch<GameController>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: theme.appBarTheme.titleTextStyle),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: theme.appBarTheme.iconTheme,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text('Appearance', style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.bold, color: theme.primaryColor)),
          const SizedBox(height: 16),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.wb_sunny_rounded)),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.nightlight_round)),
              ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto_rounded)),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (newSelection) {
              settings.setThemeMode(newSelection.first);
            },
            style: SegmentedButton.styleFrom(
              backgroundColor: theme.cardColor,
              foregroundColor: theme.textTheme.bodyLarge?.color,
              selectedBackgroundColor: theme.primaryColor,
              selectedForegroundColor: theme.colorScheme.onPrimary,
            ),
          ),
          const Divider(height: 48, color: Colors.white24),
          Text('Game Settings', style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.bold, color: theme.primaryColor)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButton<String>(
              value: game.currentListKey,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  game.switchWordList(newValue);
                }
              },
              items: game.wordLists.keys.map<DropdownMenuItem<String>>((String key) {
                return DropdownMenuItem<String>(
                  value: key,
                  child: Text(key, style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
                );
              }).toList(),
              dropdownColor: theme.cardColor,
              icon: const Icon(Icons.arrow_drop_down_rounded),
              isExpanded: true,
              underline: const SizedBox(),
            ),
          ),
          const SizedBox(height: 24),
          Text('Game Mode', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: GameMode.values.map((mode) {
              final isSelected = game.gameMode == mode;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: ChoiceChip(
                  label: Text(mode.name.toUpperCase()),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      game.setGameMode(mode);
                    }
                  },
                  backgroundColor: theme.cardColor,
                  selectedColor: theme.primaryColor,
                  labelStyle: GoogleFonts.nunito(
                    color: isSelected ? theme.colorScheme.onPrimary : theme.textTheme.bodyLarge?.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Text('Difficulty', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: Difficulty.values.map((difficulty) {
              final isSelected = game.difficulty == difficulty;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: ChoiceChip(
                  label: Text(difficulty.name.toUpperCase()),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      game.setDifficulty(difficulty);
                    }
                  },
                  backgroundColor: theme.cardColor,
                  selectedColor: theme.primaryColor,
                  labelStyle: GoogleFonts.nunito(
                    color: isSelected ? theme.colorScheme.onPrimary : theme.textTheme.bodyLarge?.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
          ),
          const Divider(height: 48, color: Colors.grey),
          Text('Audio & Feedback', style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.bold, color: theme.primaryColor)),
          const SizedBox(height: 8),
          SwitchListTile(
            title: Text('Sound Effects', style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
            value: settings.soundEnabled,
            onChanged: (value) => settings.setSoundEnabled(value),
            activeColor: theme.primaryColor,
            tileColor: theme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: Text('Vibration', style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
            value: settings.vibrationEnabled,
            onChanged: (value) => settings.setVibrationEnabled(value),
            activeColor: theme.primaryColor,
            tileColor: theme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: Text('Word Pronunciation (TTS)', style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
            value: settings.ttsEnabled,
            onChanged: (value) => settings.setTtsEnabled(value),
            activeColor: theme.primaryColor,
            tileColor: theme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ],
      ),
    );
  }
}

class UnfamiliarWordsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Unfamiliar Words', style: theme.appBarTheme.titleTextStyle),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: theme.appBarTheme.iconTheme,
      ),
      body: Consumer<GameController>(
        builder: (context, game, child) {
          if (game.unfamiliarWords.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sentiment_satisfied_alt_rounded, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No unfamiliar words yet. Keep playing!',
                    style: GoogleFonts.nunito(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: game.unfamiliarWords.length,
            itemBuilder: (context, index) {
              final wordPair = game.unfamiliarWords[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: Text(wordPair.english, style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
                  subtitle: Text(wordPair.chinese),
                  trailing: IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
                    onPressed: () {
                      game.removeUnfamiliarWord(wordPair);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Removed "${wordPair.english}" from your list.'),
                          backgroundColor: Colors.redAccent,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}


class StatisticsPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameController>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 8,
        children: [
          StatItem(label: 'Score', value: game.score.toString(), icon: Icons.star_border_rounded, color: Colors.amber),
          StreakStatItem(),
          StatItem(label: 'Time', value: game.timerText, icon: Icons.timer_rounded, color: Colors.lightBlueAccent),
          StatItem(label: 'Mistakes', value: game.mismatchedAttempts.toString(), icon: Icons.error_outline_rounded, color: Colors.redAccent),
        ],
      ),
    );
  }
}

class StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const StatItem({Key? key, required this.label, required this.value, required this.icon, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(label, style: GoogleFonts.nunito(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ],
    );
  }
}

class StreakStatItem extends StatefulWidget {
  @override
  _StreakStatItemState createState() => _StreakStatItemState();
}

class _StreakStatItemState extends State<StreakStatItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  int _previousStreak = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 200), vsync: this);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut)
    );
    final game = context.read<GameController>();
    _previousStreak = game.streak;
    game.addListener(_onStreakChanged);
  }

  void _onStreakChanged() {
    final game = context.read<GameController>();
    if (game.streak > _previousStreak) {
      _controller.forward(from: 0.0);
    }
    _previousStreak = game.streak;
  }

  @override
  void dispose() {
    context.read<GameController>().removeListener(_onStreakChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameController>();
    return ScaleTransition(
      scale: _scaleAnimation,
      child: StatItem(label: 'Streak', value: 'x${game.streak}', icon: Icons.whatshot_rounded, color: Colors.deepOrangeAccent),
    );
  }
}

class GameGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameController>();
    final theme = Theme.of(context);

    if (game.gameState == GameState.paused) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pause_circle_filled_rounded, size: 80, color: theme.primaryColor.withOpacity(0.5)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow_rounded),
              onPressed: game.resumeGame,
              label: Text('Resume Game'),
            ),
          ],
        ),
      );
    }

    return OrientationBuilder(
      builder: (context, orientation) {
        final crossAxisCount = orientation == Orientation.landscape ? 8 : 4;
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.0,
          ),
          itemCount: game.cards.length,
          itemBuilder: (context, index) {
            return GameCardWidget(cardIndex: index);
          },
        );
      },
    );
  }
}

class GameFinishedView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameController>();
    final theme = Theme.of(context);

    return Center(
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 10,
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Congratulations!', style: GoogleFonts.nunito(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.amber)),
              if (game.newHighScore)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text('New High Score!', style: GoogleFonts.nunito(fontSize: 22, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                ),
              const SizedBox(height: 24),
              Text('Your Score: ${game.score}', style: GoogleFonts.nunito(fontSize: 22)),
              if (game.gameMode == GameMode.classic)
                Text('Time: ${game.timerText}', style: GoogleFonts.nunito(fontSize: 18, color: theme.textTheme.bodyMedium?.color)),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.replay_rounded),
                onPressed: game.restartGame,
                label: const Text('Play Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GameCardWidget extends StatefulWidget {
  final int cardIndex;
  const GameCardWidget({Key? key, required this.cardIndex}) : super(key: key);

  @override
  _GameCardWidgetState createState() => _GameCardWidgetState();
}

class _GameCardWidgetState extends State<GameCardWidget> with TickerProviderStateMixin {
  late AnimationController _shakeController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _pulseController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
  }

  @override
  void didUpdateWidget(GameCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final game = context.read<GameController>();
    final status = game.cards[widget.cardIndex].status;

    if (status == CardStatus.mismatched) {
      _shakeController.forward(from: 0.0);
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          game.setCardStatus(widget.cardIndex, CardStatus.visible);
        }
      });
    }
    if (status == CardStatus.matched) {
      _pulseController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameController>();
    final card = game.cards[widget.cardIndex];
    final status = card.status;

    return AnimatedBuilder(
      animation: Listenable.merge([_shakeController, _pulseController]),
      builder: (context, child) {
        double shakeOffset = 0;
        if (_shakeController.isAnimating) {
          shakeOffset = sin(_shakeController.value * pi * 4) * 8;
        }

        double pulseScale = 1.0;
        if (_pulseController.isAnimating) {
          pulseScale = 1.0 + sin(_pulseController.value * pi) * 0.2;
        }

        return Transform.translate(
          offset: Offset(shakeOffset, 0),
          child: Transform.scale(
            scale: pulseScale,
            child: child,
          ),
        );
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: status == CardStatus.matched ? 0 : 1,
        child: InkWell(
          onTap: () => game.onCardTapped(widget.cardIndex),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: _getCardColor(context, status),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _getBorderColor(context, status), width: status == CardStatus.selected ? 3 : 1),
              boxShadow: [
                if (status == CardStatus.matched)
                  BoxShadow(
                    color: Colors.greenAccent.withOpacity(0.8),
                    blurRadius: 12,
                    spreadRadius: 4,
                  ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ]
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  card.text,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getCardColor(BuildContext context, CardStatus status) {
    final theme = Theme.of(context);
    switch (status) {
      case CardStatus.selected:
        return theme.primaryColor;
      case CardStatus.mismatched:
        return theme.colorScheme.error;
      default:
        return theme.cardColor;
    }
  }

  Color _getBorderColor(BuildContext context, CardStatus status) {
    final theme = Theme.of(context);
    if (status == CardStatus.selected) {
      return theme.colorScheme.onPrimary;
    }
    return theme.colorScheme.secondary.withOpacity(0.5);
  }
}
