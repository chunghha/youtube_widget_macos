import Cocoa
import FlutterMacOS
import window_manager  // Make sure this import is present

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    self.styleMask = [
      .titled,
      .closable,
      .miniaturizable,
      .resizable,  // This is crucial for native fullscreen behavior
    ]

    self.collectionBehavior = .fullScreenPrimary  // This is crucial for true fullscreen

    self.minFullScreenContentSize = NSSize(width: 300, height: 300)
    self.maxFullScreenContentSize = NSSize(width: 1728, height: 1080)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    // --- NEW DIAGNOSTIC PRINTS (Corrected) ---
    print("--- Native Window Properties after awakeFromNib ---")
    print("Style Mask: \(self.styleMask)")
    print("Collection Behavior: \(self.collectionBehavior)")
    // Removed the problematic line: print("Can Enter Fullscreen Mode: \(self.canEnterFullScreenMode)")
    print("-------------------------------------------------")
    // --- END NEW DIAGNOSTIC PRINTS ---
  }
}
