import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _player = AudioPlayer();

  // Play a specific asset from assets/audio/ folder
  Future<void> playAsset(String fileName) async {
    try {
      // Stop currently playing sounds first to avoid overlaps
      await _player.stop();
      await _player.play(AssetSource('audio/$fileName'));
    } catch (e) {
      debugPrint("Audio play error for $fileName: $e");
    }
  }

  Future<void> playAlarm() async {
    await playAsset('alarm.mp3');
  }

  Future<void> playNotification() async {
    await playAsset('notification.mp3');
  }

  Future<void> playTick() async {
    await playAsset('tick.mp3');
  }

  Future<void> playSuccess() async {
    await playAsset('success.mp3');
  }

  Future<void> stop() async {
    await _player.stop();
  }
}
