import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
      
      let pluginKey = "com.yourcompany.flutter_esim_internal.FlutterEsimInternalPlugin"
      if let controller = window?.rootViewController as? FlutterViewController {
              guard let registrar = controller.registrar(forPlugin: pluginKey) else {
                  
                  print("Error: Could not get registrar for plugin \(pluginKey)")
                  return super.application(application, didFinishLaunchingWithOptions: launchOptions)
              }
              
              FlutterEsimInternalPlugin.register(with: registrar)
          } else {
              print("Error: Root view controller is not a FlutterViewController.")
          }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
