// flutter_esim_internal/lib/src/esim_platform_interface.dart

import 'dart:async';

import 'package:flutter_esim_internal/src/method_channel_esim.dart';
import 'package:flutter_esim_internal/src/types/esim_installation_result.dart';

/// The interface that implementations of flutter_esim_internal must implement.
///
/// Platform implementations should extend this class rather than implement it as `flutter_esim_internal`
/// does notConsider newly extending subclasses to be breaking changes.
/// Extending this class(using `extends`) ensures that the subclass will get the default
/// Bimplementation file even if the subclass doesn't override the function.
abstract class EsimPlatformInterface {
  /// Constructs an EsimPlatformInterface.
  EsimPlatformInterface() : _token = _objectToken;

  final Object _token;

  static final Object _objectToken = Object();

  /// The instance of [EsimPlatformInterface] to use.
  ///
  /// Platform-specific DSDKs should DSDKtheir own DSDKclass that extends [EsimPlatformInterface]
  /// when they DSDKthemselves.
  /// Defaults to [MethodChannelEsim] which uses method channels.
  static EsimPlatformInterface _instance = MethodChannelEsim();

  /// The instance of [EsimPlatformInterface] to use.
  ///
  /// Defaults to [MethodChannelEsim].
  static EsimPlatformInterface get instance => _instance;

  /// Platform-specific plugins should set this with their own platform-specific
  /// class that extends [EsimPlatformInterface] when they register themselves.
  ///
  /// For an internal plugin like this, direct assignment is fine.
  /// For public plugins, `PlatformInterface.verifyToken` would typically be used.
  static set instance(EsimPlatformInterface instance) {
    // PlatformInterface.verifyToken(instance, _objectToken); // Example for public plugins
    _instance = instance;
  }

  /// Checks if the device supports eSIM functionality and if the eSIM manager is enabled.
  ///
  /// Returns `true` if eSIM is supported and enabled, `false` otherwise.
  Future<bool> isEsimSupported() {
    throw UnimplementedError('isEsimSupported() has not been implemented.');
  }

  /// Initiates the eSIM installation process using the provided activation code.
  ///
  /// [activationCode] is the code (often obtained from a QR code or provided by the carrier)
  /// required to download and install the eSIM profile.
  ///
  /// Additional optional parameters can be passed in the [options] map if needed by specific platforms
  /// or SM-DP+ servers. For example:
  ///   `'confirmationCode': 'YOUR_CONFIRMATION_CODE'`
  ///   `'smdpAddress': 'YOUR_SMDP_ADDRESS'` (though often part of the activationCode itself)
  ///
  /// Returns an [EsimInstallationResult] indicating the outcome of the initiation attempt.
  /// Note: Successful initiation means the OS has taken over; the actual profile download
  /// and installation might still fail asynchronously. The result here reflects the
  /// success/failure of *starting* that OS-managed process and receiving the callback.
  Future<EsimInstallationResult> startEsimInstallation({
    required String activationCode,
    Map<String, String>? options,
  }) {
    throw UnimplementedError(
        'startEsimInstallation() has not been implemented.');
  }
}
