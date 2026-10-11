import 'dart:async';

/// Collapses rapid events (e.g. keystrokes in a search box) into a single
/// callback fired after [duration] of quiet.
///
/// Resource-safe: [dispose] cancels the pending timer and marks the
/// debouncer disposed so a later [run] is a no-op instead of a
/// use-after-dispose.
class Debouncer {
  Debouncer({this.duration = const Duration(milliseconds: 400)});

  final Duration duration;
  Timer? _timer;
  bool _disposed = false;

  void run(void Function() action) {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer(duration, () {
      _timer = null;
      if (!_disposed) action();
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }
}
