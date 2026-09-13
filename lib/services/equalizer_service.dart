import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider_windows/path_provider_windows.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_windows/shared_preferences_windows.dart';

class EqualizerService {
  EqualizerService._() {
    _init();
  }

  static final EqualizerService instance = EqualizerService._();

  static const String _storageKey = 'equalizer_settings';

  static const Map<String, List<double>> presets = {
    'Flat': [0.0, 0.0, 0.0, 0.0, 0.0],
    'Bass Boost': [5.0, 3.5, 1.0, 0.0, 0.0],
    'Treble Boost': [0.0, 0.0, 1.0, 3.5, 5.0],
    'Vocal': [-1.5, 1.5, 4.0, 2.0, -1.0],
    'Rock': [4.5, 2.5, -1.0, 2.5, 4.0],
    'Classical': [3.0, 1.5, 0.0, 2.0, 2.5],
  };

  static const List<String> availablePresets = [
    'Flat',
    'Bass Boost',
    'Treble Boost',
    'Vocal',
    'Rock',
    'Classical',
    'Custom',
  ];

  static const List<double> defaultCenterFrequencies = [
    60.0,
    230.0,
    910.0,
    3600.0,
    14000.0,
  ];

  bool _enabled = false;
  String _preset = 'Flat';
  List<double> _gains = [0.0, 0.0, 0.0, 0.0, 0.0];
  double _minDecibels = -10.0;
  double _maxDecibels = 10.0;
  List<double> _centerFrequencies = List.from(defaultCenterFrequencies);

  bool? _overrideIsSupported;
  AndroidEqualizer? _androidEqualizer;
  AndroidEqualizerParameters? _parameters;

  final ValueNotifier<int> changes = ValueNotifier<int>(0);

  Future<void>? _initFuture;
  Future<void>? _saveFuture;

  bool get isSupported =>
      _overrideIsSupported ?? (!kIsWeb && Platform.isAndroid);

  bool get enabled => _enabled;
  String get preset => _preset;
  List<double> get gains => List.unmodifiable(_gains);
  double get minDecibels => _minDecibels;
  double get maxDecibels => _maxDecibels;
  List<double> get centerFrequencies => List.unmodifiable(_centerFrequencies);

  List<String> get formattedFrequencies =>
      _centerFrequencies.map(formatFrequency).toList();

  static String formatFrequency(double freqHz) {
    if (freqHz >= 1000) {
      final kHz = freqHz / 1000;
      if (kHz == kHz.roundToDouble()) {
        return '${kHz.toInt()} kHz';
      }
      return '${kHz.toStringAsFixed(1)} kHz';
    }
    return '${freqHz.toInt()} Hz';
  }

  static void ensurePlatformInitialized() {
    if (Platform.isWindows &&
        SharedPreferencesStorePlatform.instance
            is! InMemorySharedPreferencesStore) {
      PathProviderWindows.registerWith();
      SharedPreferencesWindows.registerWith();
    }
  }

  Future<void> _init() {
    return _initFuture ??= _loadSettings();
  }

  Future<void> init() => _init();

  @visibleForTesting
  Future<void>? get lastSaveOperation => _saveFuture;

  @visibleForTesting
  void clearForTesting() {
    _enabled = false;
    _preset = 'Flat';
    _gains = [0.0, 0.0, 0.0, 0.0, 0.0];
    _minDecibels = -10.0;
    _maxDecibels = 10.0;
    _centerFrequencies = List.from(defaultCenterFrequencies);
    _overrideIsSupported = null;
    _androidEqualizer = null;
    _parameters = null;
    _initFuture = null;
    _saveFuture = null;
  }

  @visibleForTesting
  void setIsSupportedForTesting(bool? supported) {
    _overrideIsSupported = supported;
    changes.value++;
  }

  @visibleForTesting
  void setGainsForTesting(List<double> gains) {
    _gains = List.from(gains);
    changes.value++;
  }

  void setAndroidEqualizer(AndroidEqualizer? equalizer) {
    _androidEqualizer = equalizer;
    if (_androidEqualizer != null && isSupported) {
      _initAndroidEqualizer();
    }
  }

  Future<void> _initAndroidEqualizer() async {
    if (_androidEqualizer == null || !isSupported) return;
    try {
      final params = await _androidEqualizer!.parameters;
      _parameters = params;
      _minDecibels = params.minDecibels;
      _maxDecibels = params.maxDecibels;

      if (params.bands.length >= 5) {
        _centerFrequencies = params.bands
            .take(5)
            .map((b) => b.centerFrequency)
            .toList();
      }

      for (int i = 0; i < _gains.length; i++) {
        _gains[i] = _gains[i].clamp(_minDecibels, _maxDecibels);
      }

      if (_enabled) {
        await _androidEqualizer!.setEnabled(true);
        for (int i = 0; i < params.bands.length && i < _gains.length; i++) {
          await params.bands[i].setGain(_gains[i]);
        }
      } else {
        await _androidEqualizer!.setEnabled(false);
      }

      changes.value++;
    } catch (e) {
      debugPrint('EqualizerService: Error initializing Android equalizer: $e');
    }
  }

  Future<void> _loadSettings() async {
    try {
      ensurePlatformInitialized();
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);

      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(jsonStr);

        final loadedEnabled = data['enabled'] as bool? ?? false;
        final rawPreset = data['preset'] as String? ?? 'Flat';
        final loadedPreset = availablePresets.contains(rawPreset)
            ? rawPreset
            : 'Flat';

        List<double> loadedGains = [0.0, 0.0, 0.0, 0.0, 0.0];
        if (data['gains'] is List) {
          final rawList = data['gains'] as List;
          for (int i = 0; i < 5; i++) {
            if (i < rawList.length && rawList[i] is num) {
              loadedGains[i] = (rawList[i] as num).toDouble().clamp(
                _minDecibels,
                _maxDecibels,
              );
            }
          }
        }

        _enabled = loadedEnabled;
        _preset = loadedPreset;
        _gains = loadedGains;
        changes.value++;
      }
    } catch (e) {
      debugPrint('EqualizerService: Error loading settings: $e');
      _enabled = false;
      _preset = 'Flat';
      _gains = [0.0, 0.0, 0.0, 0.0, 0.0];
    }
  }

  Future<void> _saveSettings() async {
    try {
      ensurePlatformInitialized();
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode({
        'enabled': _enabled,
        'preset': _preset,
        'gains': _gains,
      });
      await prefs.setString(_storageKey, jsonStr);
    } catch (e) {
      debugPrint('EqualizerService: Error saving settings: $e');
    }
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    changes.value++;
    _saveFuture = _saveSettings();

    if (isSupported && _androidEqualizer != null) {
      try {
        await _androidEqualizer!.setEnabled(value);
        if (value && _parameters != null) {
          for (
            int i = 0;
            i < _parameters!.bands.length && i < _gains.length;
            i++
          ) {
            await _parameters!.bands[i].setGain(_gains[i]);
          }
        }
      } catch (e) {
        debugPrint('EqualizerService: Error setting enabled: $e');
      }
    }
  }

  Future<void> setPreset(String presetName) async {
    if (!presets.containsKey(presetName)) return;

    final presetGains = presets[presetName]!;
    _preset = presetName;
    _gains = presetGains
        .map((g) => g.clamp(_minDecibels, _maxDecibels))
        .toList();
    changes.value++;
    _saveFuture = _saveSettings();

    if (isSupported &&
        _enabled &&
        _androidEqualizer != null &&
        _parameters != null) {
      try {
        for (
          int i = 0;
          i < _parameters!.bands.length && i < _gains.length;
          i++
        ) {
          await _parameters!.bands[i].setGain(_gains[i]);
        }
      } catch (e) {
        debugPrint('EqualizerService: Error applying preset: $e');
      }
    }
  }

  Future<void> setBandGain(int bandIndex, double gain) async {
    if (bandIndex < 0 || bandIndex >= _gains.length) return;

    final clampedGain = gain.clamp(_minDecibels, _maxDecibels);
    _gains[bandIndex] = clampedGain;
    _preset = 'Custom';
    changes.value++;
    _saveFuture = _saveSettings();

    if (isSupported &&
        _enabled &&
        _androidEqualizer != null &&
        _parameters != null) {
      try {
        if (bandIndex < _parameters!.bands.length) {
          await _parameters!.bands[bandIndex].setGain(clampedGain);
        }
      } catch (e) {
        debugPrint('EqualizerService: Error setting band gain: $e');
      }
    }
  }

  Future<void> reset() async {
    _gains = [0.0, 0.0, 0.0, 0.0, 0.0];
    _preset = 'Flat';
    changes.value++;
    _saveFuture = _saveSettings();

    if (isSupported &&
        _enabled &&
        _androidEqualizer != null &&
        _parameters != null) {
      try {
        for (
          int i = 0;
          i < _parameters!.bands.length && i < _gains.length;
          i++
        ) {
          await _parameters!.bands[i].setGain(0.0);
        }
      } catch (e) {
        debugPrint('EqualizerService: Error resetting equalizer: $e');
      }
    }
  }
}
