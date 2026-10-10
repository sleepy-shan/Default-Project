import 'dart:async';

/// Collapses rapid events (e.g. keystrokes in a search box) into a single
/// callback fired after [duration] of quiet.
class Debouncer {
  Debouncer({this.duration = const Duration(milliseconds: 400)});

  final Duration duration;
  Timer? _timer;

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  void dispose() => _timer?.cancel();
}
