import 'dart:async';

import 'package:flutter/foundation.dart';

import 'audio_player_service.dart';

class SleepTimerService {
  SleepTimerService._();

  static final SleepTimerService instance = SleepTimerService._();

  Timer? _timer;
  final ValueNotifier<Duration?> remainingTimeNotifier =
      ValueNotifier<Duration?>(null);

  Duration? get remainingTime => remainingTimeNotifier.value;

  bool get isActive => remainingTime != null;

  @visibleForTesting
  Future<void> Function()? onTimerComplete;

  void startTimer(Duration duration) {
    cancelTimer();

    if (duration <= Duration.zero) {
      return;
    }

    remainingTimeNotifier.value = duration;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final current = remainingTimeNotifier.value;
      if (current == null) {
        timer.cancel();
        _timer = null;
        return;
      }

      final next = current - const Duration(seconds: 1);
      if (next <= Duration.zero) {
        _triggerCompletion();
      } else {
        remainingTimeNotifier.value = next;
      }
    });
  }

  void cancelTimer() {
    _timer?.cancel();
    _timer = null;
    remainingTimeNotifier.value = null;
  }

  void _triggerCompletion() {
    cancelTimer();
    if (onTimerComplete != null) {
      onTimerComplete!();
    } else {
      AudioPlayerService.instance.pause();
    }
  }

  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
  }

  String get formattedRemainingTime =>
      remainingTime != null ? formatDuration(remainingTime!) : '';

  @visibleForTesting
  void tickForTesting() {
    final current = remainingTimeNotifier.value;
    if (current == null) return;
    final next = current - const Duration(seconds: 1);
    if (next <= Duration.zero) {
      _triggerCompletion();
    } else {
      remainingTimeNotifier.value = next;
    }
  }

  @visibleForTesting
  void resetForTesting() {
    cancelTimer();
    onTimerComplete = null;
  }

  @visibleForTesting
  void setRemainingTimeForTesting(Duration? duration) {
    _timer?.cancel();
    _timer = null;
    remainingTimeNotifier.value = duration;
  }
}
