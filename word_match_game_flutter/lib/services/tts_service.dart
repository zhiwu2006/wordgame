import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';

class TTSService {
  // Singleton 实现
  static final TTSService _instance = TTSService._internal();
  factory TTSService() => _instance;
  TTSService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;

  Future<void> init() async {
    if (!_isInitialized) {
      try {
        // 设置 TTS 引擎参数
        await _tts.setLanguage('en-US');
        await _tts.setVolume(1.0);
        await _tts.setSpeechRate(0.4); // 将语速从0.5调整为0.4(原来的0.8倍)
        await _tts.setPitch(1.0);

        // 设置回调
        _tts.setStartHandler(() {
          _isSpeaking = true;
          debugPrint('TTS Started');
        });

        _tts.setCompletionHandler(() {
          _isSpeaking = false;
          debugPrint('TTS Completed');
        });

        _tts.setErrorHandler((msg) {
          _isSpeaking = false;
          debugPrint('TTS Error: $msg');
        });

        // 检查可用语言
        final languages = await _tts.getLanguages;
        debugPrint('Available languages: $languages');

        // 检查默认引擎
        final engine = await _tts.getDefaultEngine;
        debugPrint('Current engine: $engine');

        _isInitialized = true;
        debugPrint('TTS Initialized successfully');
      } catch (e) {
        debugPrint('TTS Init Error: $e');
        _isInitialized = false;
      }
    }
  }

  Future<void> speak(String text) async {
    try {
      if (!_isInitialized) {
        await init();
      }

      if (_isSpeaking) {
        await stop();
      }

      // 设置等待朗读完成
      await _tts.awaitSpeakCompletion(true);
      
      // 开始播放
      final result = await _tts.speak(text);
      if (result == 1) {
        debugPrint('TTS Speak initiated');
      } else {
        debugPrint('TTS Speak failed with result: $result');
      }
      
      // 等待朗读完成
      while (_isSpeaking) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      // 额外等待一小段时间确保完全朗读完成
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('TTS Speak Error: $e');
    }
  }

  Future<void> stop() async {
    try {
      final result = await _tts.stop();
      if (result == 1) {
        _isSpeaking = false;
        debugPrint('TTS Stopped successfully');
      } else {
        debugPrint('TTS Stop failed with result: $result');
      }
    } catch (e) {
      debugPrint('TTS Stop Error: $e');
    }
  }

  Future<void> dispose() async {
    try {
      await stop();
      await _tts.awaitSpeakCompletion(true);
      await _tts.stop();
      debugPrint('TTS Disposed');
    } catch (e) {
      debugPrint('TTS Dispose Error: $e');
    }
  }
}