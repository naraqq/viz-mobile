import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, FlutterStreamHandler {
  private var captureSink: FlutterEventSink?
  private var captureObserver: NSObjectProtocol?
  private var monitoringEnabled = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ScreenSecurity") else { return }
    let messenger = registrar.messenger()

    FlutterMethodChannel(name: "viz/screen_security", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "enable":
          self?.monitoringEnabled = true
          self?.notifySink()
          result(nil)
        case "disable":
          self?.monitoringEnabled = false
          self?.captureSink?(false)
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }

    FlutterEventChannel(name: "viz/screen_security_events", binaryMessenger: messenger)
      .setStreamHandler(self)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    captureSink = events
    captureObserver = NotificationCenter.default.addObserver(
      forName: UIScreen.capturedDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      guard self?.monitoringEnabled == true else { return }
      self?.notifySink()
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    if let observer = captureObserver {
      NotificationCenter.default.removeObserver(observer)
      captureObserver = nil
    }
    captureSink = nil
    return nil
  }

  private func notifySink() {
    captureSink?(UIScreen.main.isCaptured)
  }
}
