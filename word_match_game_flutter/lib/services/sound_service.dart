import 'package:audioplayers/audioplayers.dart';

class SoundService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> playFlipSound() async {
    await _audioPlayer.play(AssetSource('sounds/flip.mp3'));
  }

  Future<void> playMatchSound() async {
    await _audioPlayer.play(AssetSource('sounds/match.mp3'));
  }

  Future<void> playMismatchSound() async {
    await _audioPlayer.play(AssetSource('sounds/mismatch.mp3'));
  }

  Future<void> playWinSound() async {
    await _audioPlayer.play(AssetSource('sounds/win.mp3'));
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
