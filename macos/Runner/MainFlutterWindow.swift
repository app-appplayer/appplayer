import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Theme-inherit title bar: the launcher pushes its effective brightness
    // over `appplayer/window` so the native title bar matches the app theme
    // (dark content -> dark title bar) instead of staying a fixed system light.
    let windowChannel = FlutterMethodChannel(
      name: "appplayer/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    windowChannel.setMethodCallHandler { [weak self] (call, result) in
      switch call.method {
      case "setBrightness":
        let args = call.arguments as? [String: Any] ?? [:]
        let dark = (args["dark"] as? Bool) ?? false
        self?.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
