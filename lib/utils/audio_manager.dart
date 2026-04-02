import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class AudioManager {
  AudioManager._() {
    _positionSub = _player.positionStream.listen(_handlePosition);
    _stateSub = _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      _notify();
    });
  }

  static final AudioManager instance = AudioManager._();

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _stateSub;

  String? _currentPostId;
  String? _currentUrl;
  double _currentStart = 0;
  double _currentEnd = 0;
  bool _isMuted = false;
  bool _isPlaying = false;

  String? get currentPostId => _currentPostId;
  bool get isMuted => _isMuted;
  bool get isPlaying => _isPlaying;

  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback listener) {
    if (_listeners.contains(listener)) return;
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notify() {
    for (final listener in List<VoidCallback>.from(_listeners)) {
      listener();
    }
  }

  void _handlePosition(Duration position) {
    if (!_isPlaying) return;
    if (_currentEnd <= _currentStart) return;
    final seconds = position.inMilliseconds / 1000.0;
    if (seconds >= _currentEnd - 0.05) {
      _player.seek(
        Duration(milliseconds: (_currentStart * 1000).round()),
      );
      _player.play();
    }
  }

  Future<void> playAudio(
    String postId,
    String url,
    double startTime,
    double endTime,
  ) async {
    if (_isMuted) return;
    if (url.isEmpty) return;
    if (_currentPostId == postId && _currentUrl == url && _isPlaying) {
      return;
    }
    final previousUrl = _currentUrl;
    if (_currentPostId != null && _currentPostId != postId) {
      await stopAudio();
    }
    _currentPostId = postId;
    _currentUrl = url;
    _currentStart = startTime < 0 ? 0 : startTime;
    _currentEnd = endTime;
    if (_currentEnd <= _currentStart) {
      _currentEnd = _currentStart + 5;
    }
    try {
      if (_player.processingState == ProcessingState.idle ||
          _player.audioSource == null ||
          previousUrl != url) {
        await _player.setUrl(url);
      }
      await _player.setVolume(1.0);
      await _player.seek(
        Duration(milliseconds: (_currentStart * 1000).round()),
      );
      await _player.play();
      _isPlaying = true;
      _notify();
    } catch (_) {}
  }

  Future<void> stopAudio() async {
    try {
      await _player.stop();
    } catch (_) {}
    _isPlaying = false;
    _currentPostId = null;
    _currentUrl = null;
    _notify();
  }

  Future<void> pauseAudio() async {
    try {
      await _player.pause();
    } catch (_) {}
    _isPlaying = false;
    _notify();
  }

  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    if (_isMuted) {
      await pauseAudio();
    } else {
      if (_currentPostId != null && _currentUrl != null) {
        await playAudio(
          _currentPostId!,
          _currentUrl!,
          _currentStart,
          _currentEnd,
        );
      } else {
        _notify();
      }
    }
  }

  Future<void> dispose() async {
    await _positionSub?.cancel();
    await _stateSub?.cancel();
    await _player.dispose();
  }
}
