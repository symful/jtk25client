import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/schedule.dart';
import 'time_slot.dart';

class LiveScheduleTracker {
  Timer? _timer;
  String? _activeClassName;
  Session? _activeSession;
  DateTime? _sessionStartedAt;

  final void Function(String className, Session session)? onSessionStarted;
  final VoidCallback? onSessionEnded;

  LiveScheduleTracker({this.onSessionStarted, this.onSessionEnded});

  String? get activeClassName => _activeClassName;
  Session? get activeSession => _activeSession;
  DateTime? get sessionStartedAt => _sessionStartedAt;
  bool get isClassOngoing => _activeSession != null;

  Duration get elapsedTime {
    if (_sessionStartedAt == null) return Duration.zero;
    return DateTime.now().difference(_sessionStartedAt!);
  }

  String get elapsedTimeText {
    final elapsed = elapsedTime;
    final h = elapsed.inHours;
    final m = elapsed.inMinutes % 60;
    if (h > 0) return '${h}j ${m}m';
    return '${m}m';
  }

  void start(List<ScheduleClass> schedules) {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _check(schedules),
    );
    _check(schedules);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    if (_activeSession != null) {
      _activeSession = null;
      _activeClassName = null;
      _sessionStartedAt = null;
      onSessionEnded?.call();
    }
  }

  void _check(List<ScheduleClass> schedules) {
    final now = DateTime.now();
    final weekday = now.weekday;
    if (weekday < 1 || weekday > 5) {
      if (_activeSession != null) {
        _activeSession = null;
        _activeClassName = null;
        _sessionStartedAt = null;
        onSessionEnded?.call();
      }
      return;
    }

    final dayEnum = Day.values[weekday - 1];
    final minutes = wibMinutes(now);

    for (final cls in schedules) {
      final daySchedule = cls.schedule.firstWhere(
        (d) => d.day == dayEnum,
        orElse: () => DaySchedule(day: dayEnum, sessions: []),
      );

      for (final session in daySchedule.sessions) {
        final slot = TimeSlot.parse(session.time);
        if (slot == null) continue;

        if (slot.containsMinutes(minutes)) {
          if (_activeClassName != cls.className ||
              _activeSession?.time != session.time) {
            _activeClassName = cls.className;
            _activeSession = session;
            _sessionStartedAt = DateTime(
              now.year,
              now.month,
              now.day,
              slot.start.hour,
              slot.start.minute,
            );
            onSessionStarted?.call(cls.className, session);
          }
          return;
        }
      }
    }

    if (_activeSession != null) {
      _activeSession = null;
      _activeClassName = null;
      _sessionStartedAt = null;
      onSessionEnded?.call();
    }
  }
}
