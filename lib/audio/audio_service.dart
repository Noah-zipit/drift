// Central audio manager for the game.
//
// Uses package:audioplayers directly (one looping player for the ambient
// pad, a small round-robin pool for short SFX so placement + clear chimes
// can overlap). Music and SFX have independent volume controls and mute
// toggles, all persisted in shared_preferences.
//
// Autoplay policy: [startMusic] must only be called after the first user
// interaction (the "Begin" button). Nothing plays before that.

import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService {
  static const _kMusicEnabled = 'driftblocks.audio.music_enabled';
  static const _kSfxEnabled = 'driftblocks.audio.sfx_enabled';
  static const _kMusicVolume = 'driftblocks.audio.music_volume';
  static const _kSfxVolume = 'driftblocks.audio.sfx_volume';

  static const _kAmbientAsset = 'audio/ambient_loop.ogg';

  final AudioPlayer _musicPlayer = AudioPlayer();

  /// Round-robin SFX players so rapid taps / overlapping chimes never cut
  /// each other off.
  final List<AudioPlayer> _sfxPool =
      List<AudioPlayer>.generate(4, (_) => AudioPlayer());
  int _sfxCursor = 0;

  final ValueNotifier<bool> musicEnabled = ValueNotifier<bool>(true);
  final ValueNotifier<bool> sfxEnabled = ValueNotifier<bool>(true);
  final ValueNotifier<double> musicVolume = ValueNotifier<double>(0.5);
  final ValueNotifier<double> sfxVolume = ValueNotifier<double>(0.65);

  bool _initialised = false;
  bool _musicStarted = false;

  Future<void> init() async {
    if (_initialised) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    musicEnabled.value = prefs.getBool(_kMusicEnabled) ?? true;
    sfxEnabled.value = prefs.getBool(_kSfxEnabled) ?? true;
    musicVolume.value = prefs.getDouble(_kMusicVolume) ?? 0.5;
    sfxVolume.value = prefs.getDouble(_kSfxVolume) ?? 0.65;

    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    await _applyVolumes();
    _initialised = true;
  }

  Future<void> _applyVolumes() async {
    final musicVol = musicEnabled.value ? musicVolume.value : 0.0;
    await _musicPlayer.setVolume(musicVol);
    final sfxVol = sfxEnabled.value ? sfxVolume.value : 0.0;
    for (final player in _sfxPool) {
      await player.setVolume(sfxVol);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMusicEnabled, musicEnabled.value);
    await prefs.setBool(_kSfxEnabled, sfxEnabled.value);
    await prefs.setDouble(_kMusicVolume, musicVolume.value);
    await prefs.setDouble(_kSfxVolume, sfxVolume.value);
  }

  // ---------------------------------------------------------------- music

  /// Starts the ambient loop. Call only after a user gesture.
  Future<void> startMusic() async {
    if (!_initialised || _musicStarted) {
      return;
    }
    _musicStarted = true;
    try {
      await _musicPlayer.play(AssetSource(_kAmbientAsset));
    } catch (_) {
      // Audio is best-effort ambience; never break the game over it.
    }
  }

  Future<void> pauseMusic() async {
    if (!_musicStarted) {
      return;
    }
    try {
      await _musicPlayer.pause();
    } catch (_) {}
  }

  Future<void> resumeMusic() async {
    if (!_musicStarted || !musicEnabled.value) {
      return;
    }
    try {
      await _musicPlayer.resume();
    } catch (_) {}
  }

  Future<void> toggleMusic() async {
    musicEnabled.value = !musicEnabled.value;
    await _persist();
    await _applyVolumes();
  }

  Future<void> setMusicVolume(double value) async {
    musicVolume.value = value < 0.0 ? 0.0 : (value > 1.0 ? 1.0 : value);
    await _persist();
    await _applyVolumes();
  }

  // ------------------------------------------------------------------ sfx

  Future<void> toggleSfx() async {
    sfxEnabled.value = !sfxEnabled.value;
    await _persist();
    await _applyVolumes();
  }

  Future<void> setSfxVolume(double value) async {
    sfxVolume.value = value < 0.0 ? 0.0 : (value > 1.0 ? 1.0 : value);
    await _persist();
    await _applyVolumes();
  }

  Future<void> _playSfx(String asset, {double rate = 1.0}) async {
    if (!_initialised || !sfxEnabled.value) {
      return;
    }
    final player = _sfxPool[_sfxCursor % _sfxPool.length];
    _sfxCursor++;
    try {
      await player.setPlaybackRate(rate);
      await player.play(AssetSource('audio/$asset'));
    } catch (_) {
      // Best effort.
    }
  }

  /// Quiet soft "tock" when a piece settles onto the board.
  Future<void> playPlace() => _playSfx('place.wav');

  /// Warm swelling chime on line clears; the pitch rises gently with the
  /// combo streak instead of getting louder or harsher.
  Future<void> playClear(int comboStreak) {
    const rates = [1.0, 1.0, 1.12, 1.26, 1.41, 1.59];
    final index =
        comboStreak < 0 ? 0 : min(comboStreak, rates.length - 1);
    return _playSfx('clear.wav', rate: rates[index]);
  }

  /// Soft low tone for game over.
  Future<void> playGameOver() => _playSfx('gameover.wav');

  /// Feather-light tick for UI buttons.
  Future<void> playTap() => _playSfx('tap.wav');

  void dispose() {
    _musicPlayer.dispose();
    for (final player in _sfxPool) {
      player.dispose();
    }
    musicEnabled.dispose();
    sfxEnabled.dispose();
    musicVolume.dispose();
    sfxVolume.dispose();
  }
}
