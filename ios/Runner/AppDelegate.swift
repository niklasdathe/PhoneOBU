import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var rideBackgroundTask: UIBackgroundTaskIdentifier = .invalid

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    let channel = FlutterMethodChannel(
      name: "org.bicycleobu/backgroundRide",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "start":
        result(self?.beginRideBackgroundTask() ?? false)
      case "stop":
        self?.endRideBackgroundTask()
        result(true)
      case "capability":
        result("core_bluetooth_and_location_background_modes")
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func beginRideBackgroundTask() -> Bool {
    endRideBackgroundTask()
    rideBackgroundTask = UIApplication.shared.beginBackgroundTask(
      withName: "BicycleOBURide"
    ) { [weak self] in
      self?.endRideBackgroundTask()
    }
    return rideBackgroundTask != .invalid
  }

  private func endRideBackgroundTask() {
    guard rideBackgroundTask != .invalid else { return }
    UIApplication.shared.endBackgroundTask(rideBackgroundTask)
    rideBackgroundTask = .invalid
  }
}
