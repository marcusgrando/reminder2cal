import Cocoa

/// Window that closes on ESC key press
class EscapableWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) {
        close()
    }
}