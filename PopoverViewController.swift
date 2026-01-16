import Cocoa

class PopoverViewController: NSViewController, CrusherConnectionDelegate {

    var crusher: CrusherConnection!

    // UI Elements
    private var visualEffectView: NSVisualEffectView!
    private var themeToggle: NSButton!
    private var connectionStatusView: NSView!
    private var connectionStatusDot: NSView!
    private var connectionStatusLabel: NSTextField!
    private var ancButton: NSButton!
    private var transparencyButton: NSButton!
    private var muteButton: NSButton!
    private var ancIndicator: NSView!
    private var transparencyIndicator: NSView!
    private var muteIndicator: NSView!
    private var volumeSlider: NSSlider!
    private var volumeValueLabel: NSTextField!
    private var volumeTrack: NSView!
    private var volumeFill: NSView!
    private var statusLabel: NSTextField!

    // Theme state
    private var isGlassTheme = false

    // Dark theme colors
    private let bgColor = NSColor(red: 0.118, green: 0.118, blue: 0.133, alpha: 1.0) // #1E1E22
    private let cardColor = NSColor(red: 0.141, green: 0.141, blue: 0.157, alpha: 1.0) // #242428
    private let borderColor = NSColor(red: 0.220, green: 0.220, blue: 0.239, alpha: 1.0) // #38383D
    private let dimBorderColor = NSColor(red: 0.165, green: 0.165, blue: 0.180, alpha: 1.0) // #2A2A2E
    private let textColor = NSColor.white
    private let dimTextColor = NSColor(red: 0.431, green: 0.431, blue: 0.451, alpha: 1.0) // #6E6E73
    private let greenColor = NSColor(red: 0.188, green: 0.820, blue: 0.345, alpha: 1.0) // #30D158
    private let redColor = NSColor(red: 1.0, green: 0.271, blue: 0.227, alpha: 1.0) // #FF453A

    // Glass theme colors
    private let glassCardColor = NSColor(white: 1.0, alpha: 0.1)
    private let glassBorderColor = NSColor(white: 1.0, alpha: 0.2)
    private let glassDimBorderColor = NSColor(white: 1.0, alpha: 0.1)
    private let glassTextColor = NSColor.white
    private let glassDimTextColor = NSColor(white: 1.0, alpha: 0.6)

    // Timer for volume sync
    private var volumeSyncTimer: Timer?

    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 360))
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = bgColor.cgColor

        // Add visual effect view for glass theme (hidden by default)
        visualEffectView = NSVisualEffectView(frame: view.bounds)
        visualEffectView.autoresizingMask = [.width, .height]
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.material = .hudWindow
        visualEffectView.state = .active
        visualEffectView.isHidden = true
        view.addSubview(visualEffectView)

        setupUI()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        crusher?.delegate = self
        updateUI()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        syncVolumeSlider()

        // Sync headphone state when popover opens (fallback if unsolicited updates don't work)
        crusher?.queryStatus()

        volumeSyncTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.syncVolumeSlider()
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        volumeSyncTimer?.invalidate()
        volumeSyncTimer = nil
    }

    private func syncVolumeSlider() {
        let currentVolume = getMacVolume()
        if abs(Int(volumeSlider.doubleValue) - currentVolume) > 1 {
            volumeSlider.doubleValue = Double(currentVolume)
            volumeValueLabel.stringValue = "\(currentVolume)%"
            updateVolumeFill()
        }
        updateMuteButton()
    }

    private func setupUI() {
        var yOffset: CGFloat = 295

        // === HEADER ===
        let headerView = NSView(frame: NSRect(x: 0, y: yOffset, width: 280, height: 56))
        headerView.wantsLayer = true
        view.addSubview(headerView)

        // Divider line under header
        let headerDivider = NSView(frame: NSRect(x: 0, y: yOffset, width: 280, height: 1))
        headerDivider.wantsLayer = true
        headerDivider.layer?.backgroundColor = dimBorderColor.cgColor
        view.addSubview(headerDivider)

        // Device icon
        let iconBg = NSView(frame: NSRect(x: 16, y: yOffset + 12, width: 32, height: 32))
        iconBg.wantsLayer = true
        iconBg.layer?.backgroundColor = cardColor.cgColor
        iconBg.layer?.cornerRadius = 8
        iconBg.layer?.borderWidth = 1
        iconBg.layer?.borderColor = borderColor.cgColor
        view.addSubview(iconBg)

        let iconImageView = NSImageView(frame: NSRect(x: 22, y: yOffset + 18, width: 20, height: 20))
        if let headphonesImage = NSImage(systemSymbolName: "headphones", accessibilityDescription: "Headphones") {
            iconImageView.image = headphonesImage
            iconImageView.contentTintColor = dimTextColor
        }
        view.addSubview(iconImageView)

        // Theme toggle button (top right)
        themeToggle = NSButton(frame: NSRect(x: 244, y: yOffset + 16, width: 24, height: 24))
        themeToggle.bezelStyle = .regularSquare
        themeToggle.isBordered = false
        themeToggle.wantsLayer = true
        themeToggle.layer?.cornerRadius = 6
        themeToggle.image = NSImage(systemSymbolName: "drop.fill", accessibilityDescription: "Theme")
        themeToggle.contentTintColor = dimTextColor
        themeToggle.target = self
        themeToggle.action = #selector(toggleTheme)
        themeToggle.toolTip = "Toggle glass theme"
        view.addSubview(themeToggle)

        // Device name
        let titleLabel = NSTextField(labelWithString: "Crusher ANC 2")
        titleLabel.frame = NSRect(x: 56, y: yOffset + 26, width: 150, height: 18)
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = textColor
        titleLabel.isBordered = false
        titleLabel.isEditable = false
        titleLabel.backgroundColor = .clear
        view.addSubview(titleLabel)

        // Connection status
        connectionStatusView = NSView(frame: NSRect(x: 56, y: yOffset + 10, width: 100, height: 14))
        view.addSubview(connectionStatusView)

        connectionStatusDot = NSView(frame: NSRect(x: 0, y: 4, width: 6, height: 6))
        connectionStatusDot.wantsLayer = true
        connectionStatusDot.layer?.cornerRadius = 3
        connectionStatusDot.layer?.backgroundColor = greenColor.cgColor
        connectionStatusView.addSubview(connectionStatusDot)

        connectionStatusLabel = NSTextField(labelWithString: "Connected")
        connectionStatusLabel.frame = NSRect(x: 11, y: -1, width: 80, height: 14)
        connectionStatusLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        connectionStatusLabel.textColor = greenColor
        connectionStatusLabel.isBordered = false
        connectionStatusLabel.isEditable = false
        connectionStatusLabel.backgroundColor = .clear
        connectionStatusView.addSubview(connectionStatusLabel)

        yOffset -= 80

        // === TOGGLE BUTTONS ===
        let buttonWidth: CGFloat = 76
        let buttonSpacing: CGFloat = 12
        let buttonStartX: CGFloat = 16

        // ANC Button
        ancButton = createToggleButton(frame: NSRect(x: buttonStartX, y: yOffset, width: buttonWidth, height: 64))
        ancButton.title = "ANC"
        ancButton.action = #selector(toggleANC)
        ancButton.target = self
        view.addSubview(ancButton)

        ancIndicator = createIndicator(for: ancButton)
        view.addSubview(ancIndicator)

        // Ambient Button
        transparencyButton = createToggleButton(frame: NSRect(x: buttonStartX + buttonWidth + buttonSpacing, y: yOffset, width: buttonWidth, height: 64))
        transparencyButton.title = "Ambient"
        transparencyButton.action = #selector(toggleTransparency)
        transparencyButton.target = self
        view.addSubview(transparencyButton)

        transparencyIndicator = createIndicator(for: transparencyButton)
        view.addSubview(transparencyIndicator)

        // Mute Button
        muteButton = createToggleButton(frame: NSRect(x: buttonStartX + (buttonWidth + buttonSpacing) * 2, y: yOffset, width: buttonWidth, height: 64))
        muteButton.title = "Mute"
        muteButton.action = #selector(muteTapped)
        muteButton.target = self
        view.addSubview(muteButton)

        muteIndicator = createIndicator(for: muteButton)
        view.addSubview(muteIndicator)

        yOffset -= 90

        // === VOLUME SECTION ===
        let volumeHeaderLabel = NSTextField(labelWithString: "VOLUME")
        volumeHeaderLabel.frame = NSRect(x: 16, y: yOffset + 30, width: 100, height: 14)
        volumeHeaderLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        volumeHeaderLabel.textColor = dimTextColor
        volumeHeaderLabel.isBordered = false
        volumeHeaderLabel.isEditable = false
        volumeHeaderLabel.backgroundColor = .clear
        view.addSubview(volumeHeaderLabel)

        let currentVolume = getMacVolume()
        volumeValueLabel = NSTextField(labelWithString: "\(currentVolume)%")
        volumeValueLabel.frame = NSRect(x: 220, y: yOffset + 30, width: 44, height: 14)
        volumeValueLabel.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
        volumeValueLabel.textColor = textColor
        volumeValueLabel.alignment = .right
        volumeValueLabel.isBordered = false
        volumeValueLabel.isEditable = false
        volumeValueLabel.backgroundColor = .clear
        view.addSubview(volumeValueLabel)

        // Custom volume track
        volumeTrack = NSView(frame: NSRect(x: 16, y: yOffset + 6, width: 248, height: 8))
        volumeTrack.wantsLayer = true
        volumeTrack.layer?.backgroundColor = NSColor(red: 0.102, green: 0.102, blue: 0.118, alpha: 1.0).cgColor
        volumeTrack.layer?.cornerRadius = 4
        volumeTrack.layer?.borderWidth = 1
        volumeTrack.layer?.borderColor = dimBorderColor.cgColor
        view.addSubview(volumeTrack)

        volumeFill = NSView(frame: NSRect(x: 0, y: 0, width: CGFloat(currentVolume) / 100.0 * 248, height: 8))
        volumeFill.wantsLayer = true
        volumeFill.layer?.backgroundColor = greenColor.cgColor
        volumeFill.layer?.cornerRadius = 4
        volumeTrack.addSubview(volumeFill)

        // Invisible slider on top for interaction
        volumeSlider = NSSlider(value: Double(currentVolume), minValue: 0, maxValue: 100, target: self, action: #selector(volumeSliderChanged))
        volumeSlider.frame = NSRect(x: 12, y: yOffset, width: 256, height: 20)
        volumeSlider.isContinuous = true
        volumeSlider.controlSize = .small
        volumeSlider.alphaValue = 0.01 // Nearly invisible
        view.addSubview(volumeSlider)

        yOffset -= 60

        // Divider
        let divider = NSView(frame: NSRect(x: 16, y: yOffset + 20, width: 248, height: 1))
        divider.wantsLayer = true
        divider.layer?.backgroundColor = dimBorderColor.cgColor
        view.addSubview(divider)

        // === STATUS LABEL ===
        statusLabel = NSTextField(labelWithString: "Ready")
        statusLabel.frame = NSRect(x: 16, y: yOffset - 15, width: 248, height: 30)
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = dimTextColor
        statusLabel.alignment = .center
        statusLabel.isBordered = false
        statusLabel.isEditable = false
        statusLabel.backgroundColor = .clear
        statusLabel.maximumNumberOfLines = 2
        view.addSubview(statusLabel)

        yOffset -= 50

        // === FOOTER BUTTONS ===
        let quitButton = createFooterButton(title: "Quit", frame: NSRect(x: 100, y: yOffset - 10, width: 80, height: 32))
        quitButton.action = #selector(quitApp)
        quitButton.target = self
        view.addSubview(quitButton)
    }

    private func createToggleButton(frame: NSRect) -> NSButton {
        let button = NSButton(frame: frame)
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = cardColor.cgColor
        button.layer?.cornerRadius = 12
        button.layer?.borderWidth = 1
        button.layer?.borderColor = borderColor.cgColor
        button.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        button.contentTintColor = dimTextColor
        button.alignment = .center
        return button
    }

    private func createIndicator(for button: NSButton) -> NSView {
        let indicator = NSView(frame: NSRect(x: button.frame.origin.x, y: button.frame.origin.y + button.frame.height - 2, width: button.frame.width, height: 2))
        indicator.wantsLayer = true
        indicator.layer?.backgroundColor = NSColor.clear.cgColor
        indicator.layer?.cornerRadius = 1
        indicator.isHidden = true
        return indicator
    }

    private func createFooterButton(title: String, frame: NSRect) -> NSButton {
        let button = NSButton(frame: frame)
        button.title = title
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.clear.cgColor
        button.layer?.cornerRadius = 8
        button.layer?.borderWidth = 1
        button.layer?.borderColor = borderColor.cgColor
        button.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        button.contentTintColor = dimTextColor
        return button
    }

    private func updateVolumeFill() {
        let percentage = CGFloat(volumeSlider.doubleValue) / 100.0
        volumeFill.frame = NSRect(x: 0, y: 0, width: percentage * 248, height: 8)
    }

    private func updateUI() {
        guard let crusher = crusher else { return }

        // Update connection status
        if crusher.isConnected {
            connectionStatusLabel.stringValue = "Connected"
            connectionStatusLabel.textColor = greenColor
            connectionStatusDot.layer?.backgroundColor = greenColor.cgColor
            addGlow(to: connectionStatusDot, color: greenColor)
        } else {
            connectionStatusLabel.stringValue = "Disconnected"
            connectionStatusLabel.textColor = redColor
            connectionStatusDot.layer?.backgroundColor = redColor.cgColor
            addGlow(to: connectionStatusDot, color: redColor)
        }

        // Update toggle buttons
        updateToggleButton(ancButton, indicator: ancIndicator, active: crusher.ancEnabled, color: greenColor)
        updateToggleButton(transparencyButton, indicator: transparencyIndicator, active: crusher.transparencyEnabled, color: greenColor)
        updateMuteButton()

        // Enable/disable headphone controls based on connection
        let enabled = crusher.isConnected
        ancButton.isEnabled = enabled
        transparencyButton.isEnabled = enabled
    }

    private func updateToggleButton(_ button: NSButton, indicator: NSView, active: Bool, color: NSColor) {
        let inactiveBorder = isGlassTheme ? glassBorderColor : borderColor
        let inactiveText = isGlassTheme ? glassDimTextColor : dimTextColor

        if active {
            button.layer?.borderColor = color.cgColor
            button.contentTintColor = color
            indicator.layer?.backgroundColor = color.cgColor
            indicator.isHidden = false
            addGlow(to: indicator, color: color)
        } else {
            button.layer?.borderColor = inactiveBorder.cgColor
            button.contentTintColor = inactiveText
            indicator.isHidden = true
            indicator.layer?.shadowOpacity = 0
        }
    }

    private func addGlow(to view: NSView, color: NSColor) {
        view.layer?.shadowColor = color.cgColor
        view.layer?.shadowRadius = 8
        view.layer?.shadowOpacity = 0.8
        view.layer?.shadowOffset = .zero
    }

    // MARK: - Actions

    @objc private func toggleANC() {
        guard let crusher = crusher else { return }
        let newState = !crusher.ancEnabled

        if newState && crusher.transparencyEnabled {
            crusher.setTransparency(enabled: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.crusher?.setANC(enabled: newState)
                self?.statusLabel.stringValue = "ANC enabled"
            }
            return
        }

        crusher.setANC(enabled: newState)
        statusLabel.stringValue = newState ? "ANC enabled" : "ANC disabled"
    }

    @objc private func toggleTransparency() {
        guard let crusher = crusher else { return }
        let newState = !crusher.transparencyEnabled

        if newState && crusher.ancEnabled {
            crusher.setANC(enabled: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.crusher?.setTransparency(enabled: newState)
                self?.statusLabel.stringValue = "Ambient enabled"
            }
            return
        }

        crusher.setTransparency(enabled: newState)
        statusLabel.stringValue = newState ? "Ambient enabled" : "Ambient disabled"
    }

    @objc private func muteTapped() {
        let currentlyMuted = getMacMuted()
        setMacMuted(!currentlyMuted)
        statusLabel.stringValue = !currentlyMuted ? "Muted" : "Unmuted"
        updateMuteButton()
    }

    private func updateMuteButton() {
        let muted = getMacMuted()
        updateToggleButton(muteButton, indicator: muteIndicator, active: muted, color: redColor)
    }

    private func getMacMuted() -> Bool {
        let script = "output muted of (get volume settings)"
        if let result = runAppleScript(script) {
            return result == "true"
        }
        return false
    }

    private func setMacMuted(_ muted: Bool) {
        let script = "set volume output muted \(muted)"
        _ = runAppleScript(script)
    }

    @objc private func volumeSliderChanged() {
        let value = Int(volumeSlider.doubleValue)
        volumeValueLabel.stringValue = "\(value)%"
        updateVolumeFill()
        setMacVolume(value)
    }

    // MARK: - Mac Volume Control

    private func getMacVolume() -> Int {
        let script = "output volume of (get volume settings)"
        if let result = runAppleScript(script) {
            return Int(result) ?? 50
        }
        return 50
    }

    private func setMacVolume(_ volume: Int) {
        let script = "set volume output volume \(volume)"
        _ = runAppleScript(script)
    }

    private func runAppleScript(_ script: String) -> String? {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let result = scriptObject.executeAndReturnError(&error)
            if error == nil {
                return result.stringValue
            }
        }
        return nil
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func toggleTheme() {
        isGlassTheme.toggle()
        applyTheme()
    }

    private func applyTheme() {
        if isGlassTheme {
            // Glass theme
            view.layer?.backgroundColor = NSColor.clear.cgColor
            visualEffectView.isHidden = false
            themeToggle.contentTintColor = greenColor

            // Update button colors
            ancButton.layer?.backgroundColor = glassCardColor.cgColor
            ancButton.layer?.borderColor = glassBorderColor.cgColor
            transparencyButton.layer?.backgroundColor = glassCardColor.cgColor
            transparencyButton.layer?.borderColor = glassBorderColor.cgColor
            muteButton.layer?.backgroundColor = glassCardColor.cgColor
            muteButton.layer?.borderColor = glassBorderColor.cgColor

            // Update volume track
            volumeTrack.layer?.backgroundColor = NSColor(white: 0, alpha: 0.3).cgColor
            volumeTrack.layer?.borderColor = glassDimBorderColor.cgColor
        } else {
            // Dark theme
            view.layer?.backgroundColor = bgColor.cgColor
            visualEffectView.isHidden = true
            themeToggle.contentTintColor = dimTextColor

            // Update button colors
            ancButton.layer?.backgroundColor = cardColor.cgColor
            ancButton.layer?.borderColor = borderColor.cgColor
            transparencyButton.layer?.backgroundColor = cardColor.cgColor
            transparencyButton.layer?.borderColor = borderColor.cgColor
            muteButton.layer?.backgroundColor = cardColor.cgColor
            muteButton.layer?.borderColor = borderColor.cgColor

            // Update volume track
            volumeTrack.layer?.backgroundColor = NSColor(red: 0.102, green: 0.102, blue: 0.118, alpha: 1.0).cgColor
            volumeTrack.layer?.borderColor = dimBorderColor.cgColor
        }

        // Re-apply active states
        updateUI()
    }

    // MARK: - CrusherConnectionDelegate

    func connectionStateChanged(_ connected: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.updateUI()
            self?.statusLabel.stringValue = connected ? "Connected!" : "Disconnected"
        }
    }

    func ancStateChanged(_ enabled: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.updateUI()
        }
    }

    func transparencyStateChanged(_ enabled: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.updateUI()
        }
    }

    func batteryLevelChanged(_ level: Int) {
        // Battery not displayed - Apple doesn't expose this data for third-party devices
    }

    func responseReceived(_ response: String) {
        // Could log responses for debugging
    }
}
