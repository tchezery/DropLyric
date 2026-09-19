import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private let spotify = SpotifyDesktopBridge()
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    spotify.register(with: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}
