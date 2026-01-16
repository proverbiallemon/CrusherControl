import Cocoa
import IOBluetooth

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var crusher: CrusherConnection!
    var rightClickMenu: NSMenu!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "headphones", accessibilityDescription: "Crusher Control")
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }

        // Create right-click menu
        rightClickMenu = NSMenu()
        rightClickMenu.addItem(NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: ""))
        rightClickMenu.addItem(NSMenuItem.separator())
        rightClickMenu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

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

    @objc func handleClick(_ sender: AnyObject?) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // Right-click: show menu
            if let button = statusItem.button {
                rightClickMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 5), in: button)
            }
        } else {
            // Left-click: toggle popover
            togglePopover(sender)
        }
    }

    func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    @objc func checkForUpdates() {
        UpdateChecker.checkForUpdates(silent: false)
    }

    @objc func quitApp() {
        crusher.disconnect()
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        crusher.disconnect()
    }
}
