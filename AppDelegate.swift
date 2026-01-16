import Cocoa
import IOBluetooth

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var crusher: CrusherConnection!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "headphones", accessibilityDescription: "Crusher Control")
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Create the popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 360)
        popover.behavior = .transient
        popover.animates = true

        // Create the view controller
        let viewController = PopoverViewController()
        popover.contentViewController = viewController

        // Initialize Bluetooth connection
        crusher = CrusherConnection.shared
        viewController.crusher = crusher

        // Try to connect on launch
        crusher.connect()

        // Check for updates silently on launch
        UpdateChecker.checkForUpdates(silent: true)
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

                // Activate the app to bring popover to front
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        crusher.disconnect()
    }
}
