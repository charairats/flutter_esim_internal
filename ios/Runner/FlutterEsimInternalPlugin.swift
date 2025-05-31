// FlutterEsimInternalPlugin.swift
// This file should be placed within the Runner target in your Xcode project.

import CoreTelephony
import Flutter
import UIKit

public class FlutterEsimInternalPlugin: NSObject, FlutterPlugin {

    // This is the method channel name that must match the one used in Dart and Android.
    // Please ensure this is identical to the one in MethodChannelEsim.dart and FlutterEsimInternalPlugin.kt
    static let channelName = "next.myais.mobile_and_device/esim_channel"  // <<<*** MAKE SURE THIS MATCHES DART/ANDROID ***>>>

    public static func register(with registrar: FlutterPluginRegistrar) {
        // Create a method channel instance.
        let channel = FlutterMethodChannel(
            name: channelName, binaryMessenger: registrar.messenger())

        // Create an instance of the plugin class.
        // The registrar is passed to the instance if needed, but for now, our instance doesn't need it directly.
        let instance = FlutterEsimInternalPlugin()

        // Set the instance to handle method calls on this channel.
        registrar.addMethodCallDelegate(instance, channel: channel)

        // If your plugin also needs to handle application lifecycle events,
        // you can add an application delegate here.
        // registrar.addApplicationDelegate(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // This method is called when a method is invoked on the channel from the Dart side.
        // We will identify the method called and execute the appropriate Swift code.

        switch call.method {
        case "isEsimSupported":
            // Call a function to handle the 'isEsimSupported' method.
            self.handleIsEsimSupported(result: result)
        case "startEsimInstallation":
            // Call a function to handle the 'startEsimInstallation' method.
            // We'll need to extract arguments from 'call.arguments'.
            guard let args = call.arguments as? [String: Any],
                let activationCode = args["activationCode"] as? String
            else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENTS",
                        message: "Activation code is required and must be a string.",
                        details: nil))
                return
            }
            let options = args["options"] as? [String: String]  // Optional options
            self.handleStartEsimInstallation(
                activationCode: activationCode, options: options, result: result)
        default:
            // If the method call is not recognized, send 'notImplemented'.
            result(FlutterMethodNotImplemented)
        }
    }

    // Placeholder for isEsimSupported logic
    private func handleIsEsimSupported(result: @escaping FlutterResult) {
        // Log that the method was called
        print("iOS: handleIsEsimSupported called")

        // CTCellularPlanProvisioning is available from iOS 12.0 and later.
        if #available(iOS 12.0, *) {
            let planProvisioning: CTCellularPlanProvisioning = CTCellularPlanProvisioning()

            // The 'supportsCellularPlan' method checks if the device generally supports adding new cellular plans.
            // This is a good indication of eSIM capability.
            let supported: Bool = planProvisioning.supportsCellularPlan()

            print("iOS: CTCellularPlanProvisioning().supportsCellularPlan() returned: \(supported)")
            result(supported)
        } else {
            // If the iOS version is older than 12.0, eSIM provisioning APIs are not available.
            print("iOS: eSIM functionality is not available on iOS versions older than 12.0")
            result(false)
        }
    }

    // Placeholder for startEsimInstallation logic
    private func handleStartEsimInstallation(
        activationCode: String, options: [String: String]?, result: @escaping FlutterResult
    ) {
        print("iOS: handleStartEsimInstallation called with activationCode: \(activationCode)")

        // CTCellularPlanProvisioning is available from iOS 12.0 and later.
        guard #available(iOS 12.0, *) else {
            print("iOS: eSIM functionality is not available on iOS versions older than 12.0")
            let resultMap: [String: Any?] = [
                "status": "notsupportedorpermitted", // Matches EsimInstallationStatus.notSupportedOrPermitted
                "message": "eSIM functionality requires iOS 12.0 or higher.",
                "errorCode": "UNSUPPORTED_OS_VERSION"
            ]
            result(resultMap)
            return
        }

        let planProvisioning: CTCellularPlanProvisioning = CTCellularPlanProvisioning()
        let request: CTCellularPlanProvisioningRequest = CTCellularPlanProvisioningRequest()

        // The activationCode from Dart is typically the full string scanned from a QR code.
        // This string is usually assigned to the 'address' property of the request.
        // Example QR Code format: LPA:1$smdp.example.com$MATCHING_ID
        // 'address' would be the full string.
        request.address = activationCode

        // You can use the 'options' map from Dart to populate other request properties if needed.
        // For example, if your SM-DP+ server requires a confirmation code or a specific matching ID
        // that is not part of the main activation code string.
        if let confirmationCode = options?["confirmationCode"] {
            request.confirmationCode = confirmationCode
        }

        // This method will present a system UI to the user to add the cellular plan.
        // The completionHandler will be called when the process is finished.
        planProvisioning.addPlan(with: request) { (addPlanResult) in
            // This completion handler might be called on a background thread.
            // Ensure UI updates (if any were to be done here, though we are just sending a result)
            // are dispatched to the main thread if needed. For just calling `result()`, it's usually fine.
            
            var statusString: String
            var message: String? = nil
            var errorCode: String? = nil

            switch addPlanResult.rawValue {
                case 0: // This corresponds to .success
                    statusString = "success"
                    message = "eSIM plan provisioning initiated successfully by OS."
                    print("iOS: addPlan result is .success (rawValue 0)")
                case 1: // This corresponds to .unknown
                    statusString = "unknownError"
                    message = "Failed to add eSIM plan. The outcome is unknown."
                    errorCode = "ADD_PLAN_UNKNOWN"
                    print("iOS: addPlan result is .unknown (rawValue 1)")
                case 2: // This corresponds to .fail
                    statusString = "failure"
                    message = "Failed to add eSIM plan. The OS reported a failure."
                    errorCode = "ADD_PLAN_FAILED"
                    print("iOS: addPlan result is .fail (rawValue 2)")
                case 3: // This rawValue (3) corresponds to .userCancelled on iOS 16.0+
                    if #available(iOS 16.0, *) {
                        // If on iOS 16.0 or later, rawValue 3 means .userCancelled
                        statusString = "userCancelled"
                        message = "User cancelled the eSIM installation process."
                        errorCode = "USER_CANCELLED_IOS"
                        print("iOS: addPlan result is .userCancelled (rawValue 3 on iOS 16+)")
                    } else {
                        // This case should theoretically not happen on iOS < 16.0 if the enum definition
                        // for those versions doesn't include a case with rawValue 3.
                        // However, as a fallback, treat it as an unknown error.
                        statusString = "unknownError"
                        message = "Received unexpected rawValue 3 for addPlanResult on pre-iOS 16 system."
                        errorCode = "ADD_PLAN_UNEXPECTED_RAW_VALUE_3"
                        print("iOS: addPlan result is unexpected rawValue 3 on pre-iOS 16")
                    }
                default: // Handles any other rawValues that might appear in future iOS versions
                    statusString = "unknownError"
                    message = "Failed to add eSIM plan due to an unknown or new result rawValue: \(addPlanResult.rawValue)."
                    errorCode = "ADD_PLAN_UNHANDLED_RAW_VALUE"
                    print("iOS: addPlan result is unhandled rawValue: \(addPlanResult.rawValue)")
                }

            let resultMap: [String: Any?] = [
                "status": statusString,
                "message": message,
                "errorCode": errorCode,
                "nativeException": nil // You could add error.localizedDescription if an Error object was available
            ]
            result(resultMap)
        }
    }


}
