import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "cn.itbill.bicone/media_muxer",
                                         binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { (call, result) in
        if call.method == "mergeStreams" {
          guard let args = call.arguments as? [String: Any],
                let videoPath = args["videoPath"] as? String,
                let audioPath = args["audioPath"] as? String,
                let outputPath = args["outputPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing required arguments", details: nil))
            return
          }
          StreamMerger.mergeStreams(videoPath: videoPath, audioPath: audioPath, outputPath: outputPath) { error in
            DispatchQueue.main.async {
              if let error = error {
                result(FlutterError(code: "MERGE_FAILED", message: error.localizedDescription, details: nil))
              } else {
                result(nil)
              }
            }
          }
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
