/// Uniform error type surfaced by [ApiClient] to the rest of the app —
/// wraps both transport failures (timeout, offline) and API-level failures
/// (`{"success": false, ...}` envelopes, validation errors).
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.errors});

  final String message;
  final int? statusCode;
  final Map<String, List<String>>? errors;

  bool get isUnauthorized => statusCode == 401;
  bool get isValidationError => statusCode == 422;
  bool get isNetworkError => statusCode == null;

  /// First validation message for [field], if any.
  String? errorFor(String field) => errors?[field]?.firstOrNull;

  @override
  String toString() => message;
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
