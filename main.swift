import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Run as accessory (menu bar only, no dock icon)
app.setActivationPolicy(.accessory)

app.run()
