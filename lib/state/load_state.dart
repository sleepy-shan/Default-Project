/// Explicit load state used by custom [Notifier]s.
///
/// Riverpod's `AsyncValue` covers futures, but browse/search/list screens
/// need extra fields (filters, pagination, error retry), so those screens
/// use this small state machine instead. Every data-driven widget renders
/// one of: initial, loading, success, error — matching the "loading /
/// empty / error / success" requirement from the plan.
enum LoadStatus { initial, loading, success, error }

class LoadState<T> {
  const LoadState({
    this.status = LoadStatus.initial,
    this.data,
    this.errorMessage,
  });

  final LoadStatus status;
  final T? data;
  final String? errorMessage;

  bool get isInitial => status == LoadStatus.initial;
  bool get isLoading => status == LoadStatus.loading;
  bool get isSuccess => status == LoadStatus.success;
  bool get isError => status == LoadStatus.error;

  LoadState<T> copyWith({LoadStatus? status, T? data, String? errorMessage}) {
    return LoadState<T>(
      status: status ?? this.status,
      data: data ?? this.data,
      errorMessage: errorMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoadState<T> &&
          status == other.status &&
          data == other.data &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(status, data, errorMessage);

  static LoadState<T> loading<T>() =>
      const LoadState(status: LoadStatus.loading);

  static LoadState<T> success<T>(T data) =>
      LoadState(status: LoadStatus.success, data: data);

  static LoadState<T> failure<T>(String message) =>
      LoadState(status: LoadStatus.error, errorMessage: message);
}
