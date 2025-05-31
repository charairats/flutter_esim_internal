// flutter_esim_internal/lib/src/types/esim_installation_result.dart

import 'esim_installation_status.dart';

/// Represents the result of an eSIM installation attempt.
class EsimInstallationResult {
  /// The overall status of the installation attempt.
  final EsimInstallationStatus status;

  /// An optional message providing more details, especially in case of failure.
  /// This might come from the native side or be a predefined message.
  final String? message;

  /// An optional error code, typically from the native platform (e.g., EuiccManager error codes).
  final String? errorCode;

  /// An optional native exception object string, for debugging.
  final String? nativeException;

  EsimInstallationResult({
    required this.status,
    this.message,
    this.errorCode,
    this.nativeException,
  });

  @override
  String toString() {
    return 'EsimInstallationResult(status: $status, message: $message, errorCode: $errorCode, nativeException: $nativeException)';
  }
}