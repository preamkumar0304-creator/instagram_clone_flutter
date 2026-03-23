import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppUsageTracker extends ChangeNotifier with WidgetsBindingObserver {
  static const _usageDateKey = "usageDate";
  static const _usageSecondsKey = "usageSeconds";

  SharedPreferences? _prefs;
  DateTime _today = DateTime.now();
  int _storedSeconds = 0;
  DateTime? _sessionStart;
  Timer? _ticker;
  bool _ready = false;

  AppUsageTracker() {
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  bool get isReady => _ready;

  int get todayUsageSeconds {
    final now = DateTime.now();
    _ensureToday(now);
    if (_sessionStart == null) return _storedSeconds;
    return _storedSeconds + now.difference(_sessionStart!).inSeconds;
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadFromPrefs();
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == null || state == AppLifecycleState.resumed) {
      _startSession();
    }
    _ready = true;
    notifyListeners();
  }

  void _loadFromPrefs() {
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    final storedDate = _prefs?.getString(_usageDateKey);
    final parsed = _parseDate(storedDate);
    if (parsed != null && _sameDay(parsed, _today)) {
      _today = parsed;
      _storedSeconds = _prefs?.getInt(_usageSecondsKey) ?? 0;
    } else {
      _storedSeconds = 0;
      _prefs?.setString(_usageDateKey, _formatDate(_today));
      _prefs?.setInt(_usageSecondsKey, 0);
    }
  }

  void _ensureToday(DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    if (_sameDay(day, _today)) return;
    _today = day;
    _storedSeconds = 0;
    _prefs?.setString(_usageDateKey, _formatDate(_today));
    _prefs?.setInt(_usageSecondsKey, 0);
    if (_sessionStart != null) {
      _sessionStart = now;
    }
  }

  void _startSession() {
    if (_sessionStart != null) return;
    _sessionStart = DateTime.now();
    _startTicker();
    notifyListeners();
  }

  void _stopSession() {
    if (_sessionStart == null) return;
    final now = DateTime.now();
    _ensureToday(now);
    final elapsed = now.difference(_sessionStart!).inSeconds;
    if (elapsed > 0) {
      _storedSeconds += elapsed;
      _prefs?.setInt(_usageSecondsKey, _storedSeconds);
    }
    _sessionStart = null;
    _stopTicker();
    notifyListeners();
  }

  void _startTicker() {
    _ticker ??= Timer.periodic(const Duration(seconds: 30), (_) {
      notifyListeners();
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDate(DateTime value) {
    return "${value.year.toString().padLeft(4, '0')}-"
        "${value.month.toString().padLeft(2, '0')}-"
        "${value.day.toString().padLeft(2, '0')}";
  }

  DateTime? _parseDate(String? value) {
    if (value == null) return null;
    final parts = value.split("-");
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_ready) return;
    if (state == AppLifecycleState.resumed) {
      _startSession();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopSession();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopSession();
    super.dispose();
  }
}
