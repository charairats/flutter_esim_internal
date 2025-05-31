// flutter_esim_internal/lib/src/method_channel_esim.dart

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_esim_internal/src/esim_platform_interface.dart';
import 'package:flutter_esim_internal/src/types/esim_installation_result.dart';
import 'package:flutter_esim_internal/src/types/esim_installation_status.dart';

/// An implementation of [EsimPlatformInterface] that uses method channels.
class MethodChannelEsim extends EsimPlatformInterface {
  /// The method channel used to interact with the native platform.
  /// Make sure this channel name is unique and matches the one used in the native code.
  static const MethodChannel _channel = MethodChannel(
      'next_flutter_esim_internal/esim_channel'); // <--- *** ตั้งชื่อ Channel ให้ไม่ซ้ำใครนะครับ! ***

  @override
  Future<bool> isEsimSupported() async {
    try {
      final bool? isSupported =
          await _channel.invokeMethod<bool>('isEsimSupported');
      return isSupported ?? false;
    } on PlatformException catch (e) {
      // Log the error or handle it as per your app's requirement
      print('Failed to check eSIM support: ${e.message}');
      return false; // Default to false in case of any error
    }
  }

  @override
  Future<EsimInstallationResult> startEsimInstallation({
    required String activationCode,
    Map<String, String>? options,
  }) async {
    try {
      final Map<String, dynamic> arguments = {
        'activationCode': activationCode,
        if (options != null) 'options': options,
      };

      // The native side is expected to return a Map that can be parsed into EsimInstallationResult
      final Map<dynamic, dynamic>? resultData =
          await _channel.invokeMethod<Map<dynamic, dynamic>>(
              'startEsimInstallation', arguments);

      if (resultData != null) {
        return _parseEsimInstallationResult(resultData);
      } else {
        // This case should ideally not happen if native side always returns a map or throws an exception
        return EsimInstallationResult(
          status: EsimInstallationStatus.unknownError,
          message: 'Native method returned null result.',
        );
      }
    } on PlatformException catch (e) {
      // Handle platform exceptions (e.g., native code threw an error)
      print(
          'Failed to start eSIM installation: ${e.code} - ${e.message} - ${e.details}');
      // You might want to map e.code to a specific EsimInstallationStatus
      return EsimInstallationResult(
        status: _mapPlatformExceptionToStatus(e),
        message: e.message ?? 'Platform exception occurred.',
        errorCode: e.code,
        nativeException: e.details?.toString(),
      );
    } catch (e) {
      // Handle any other Dart-side errors
      print('An unexpected error occurred during startEsimInstallation: $e');
      return EsimInstallationResult(
        status: EsimInstallationStatus.unknownError,
        message: 'An unexpected Dart error occurred: ${e.toString()}',
      );
    }
  }

  /// Helper function to parse the Map received from native into an EsimInstallationResult object.
  EsimInstallationResult _parseEsimInstallationResult(
      Map<dynamic, dynamic> resultMap) {
    // It's crucial that the native side sends a 'status' string that matches one of these.
    final String? statusString = resultMap['status'] as String?;
    EsimInstallationStatus status;

    switch (statusString?.toLowerCase()) {
      case 'success':
        status = EsimInstallationStatus.success;
        break;
      case 'failure':
        status = EsimInstallationStatus.failure;
        break;
      case 'usercancelled':
        status = EsimInstallationStatus.userCancelled;
        break;
      case 'notsupportedorpermitted':
        status = EsimInstallationStatus.notSupportedOrPermitted;
        break;
      case 'invalidactivationcode':
        status = EsimInstallationStatus.invalidActivationCode;
        break;
      case 'esimdisabledorunavailable':
        status = EsimInstallationStatus.esimDisabledOrUnavailable;
        break;
      // Add more cases here as needed, matching string values from native code
      default:
        status = EsimInstallationStatus.unknownError;
    }

    return EsimInstallationResult(
      status: status,
      message: resultMap['message'] as String?,
      errorCode: resultMap['errorCode'] as String?,
      nativeException: resultMap['nativeException'] as String?,
    );
  }

  /// Helper to map PlatformException codes to a more specific EsimInstallationStatus if possible.
  EsimInstallationStatus _mapPlatformExceptionToStatus(PlatformException e) {
    // Example: You might define specific error codes on the native side
    // that you can check here.
    // if (e.code == "CARRIER_PRIVILEGES_REQUIRED") {
    //   return EsimInstallationStatus.notSupportedOrPermitted;
    // }
    // if (e.code == "INVALID_ACTIVATION_CODE_FORMAT_NATIVE") {
    //   return EsimInstallationStatus.invalidActivationCode;
    // }
    // For now, default to a general failure or unknown error.
    // The specific error code from PlatformException is already captured in EsimInstallationResult.errorCode.
    return EsimInstallationStatus
        .failure; // Or unknownError, depending on how you want to treat platform exceptions generally
  }
}
