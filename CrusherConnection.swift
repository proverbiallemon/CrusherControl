import Foundation
import IOBluetooth

protocol CrusherConnectionDelegate: AnyObject {
    func connectionStateChanged(_ connected: Bool)
    func ancStateChanged(_ enabled: Bool)
    func transparencyStateChanged(_ enabled: Bool)
    func batteryLevelChanged(_ level: Int)
    func responseReceived(_ response: String)
}

class CrusherConnection: NSObject {
    static let shared = CrusherConnection()

    // Crusher ANC 2 Bluetooth address (update if needed)
    private let deviceAddress = "8E:5D:79:E0:EE:5B"
    private let bosATChannel: UInt8 = 9  // BOS_AT channel for AT commands

    private var device: IOBluetoothDevice?
    private var rfcommChannel: IOBluetoothRFCOMMChannel?

    weak var delegate: CrusherConnectionDelegate?

    var isConnected: Bool = false {
        didSet {
            delegate?.connectionStateChanged(isConnected)
        }
    }

    var ancEnabled: Bool = false
    var transparencyEnabled: Bool = false
    // isMuted removed - now controlled via Mac system
    var batteryLevel: Int = -1

    private var responseBuffer = ""
    private var responseCompletion: ((String) -> Void)?

    override init() {
        super.init()
    }

    // MARK: - Connection

    func connect() {
        guard let device = IOBluetoothDevice(addressString: deviceAddress) else {
            print("[Crusher] Device not found: \(deviceAddress)")
            return
        }

        self.device = device
        print("[Crusher] Found device: \(device.name ?? "Unknown")")

        // Open RFCOMM channel
        var channel: IOBluetoothRFCOMMChannel?
        let result = device.openRFCOMMChannelSync(&channel, withChannelID: bosATChannel, delegate: self)

        if result == kIOReturnSuccess {
            self.rfcommChannel = channel
            print("[Crusher] RFCOMM channel \(bosATChannel) opened")
        } else {
            print("[Crusher] Failed to open RFCOMM channel: \(result)")
        }
    }

    func disconnect() {
        rfcommChannel?.close()
        rfcommChannel = nil
        isConnected = false
        print("[Crusher] Disconnected")
    }

    // MARK: - AT Commands

    func sendATCommand(_ command: String, completion: ((String) -> Void)? = nil) {
        guard let channel = rfcommChannel, isConnected else {
            print("[Crusher] Not connected")
            completion?("ERROR: Not connected")
            return
        }

        let cmdWithCRLF = command.hasSuffix("\r\n") ? command : command + "\r\n"
        guard let data = cmdWithCRLF.data(using: .utf8) else { return }

        responseBuffer = ""
        responseCompletion = completion

        let bytes = [UInt8](data)
        var mutableBytes = bytes
        let result = channel.writeSync(&mutableBytes, length: UInt16(bytes.count))

        if result != kIOReturnSuccess {
            print("[Crusher] Write failed: \(result)")
            completion?("ERROR: Write failed")
        }
    }

    // MARK: - Controls

    func setANC(enabled: Bool) {
        let cmd = enabled ? "AT.UIAUDIO=anc,on" : "AT.UIAUDIO=anc,off"
        sendATCommand(cmd) { [weak self] response in
            if response.contains("OK") {
                self?.ancEnabled = enabled
                self?.delegate?.ancStateChanged(enabled)
            }
        }
    }

    func setTransparency(enabled: Bool) {
        let cmd = enabled ? "AT.UIAUDIO=transparency,on" : "AT.UIAUDIO=transparency,off"
        sendATCommand(cmd) { [weak self] response in
            if response.contains("OK") {
                self?.transparencyEnabled = enabled
                self?.delegate?.transparencyStateChanged(enabled)
            }
        }
    }

    func adjustVolume(up: Bool, steps: Int = 1) {
        let direction = up ? "up" : "down"
        sendATCommand("AT.VOLUME=\(direction),\(steps)")
    }

    // Mute removed - now controlled via Mac system in PopoverViewController

    func queryStatus() {
        // Query ANC status
        sendATCommand("AT.UIAUDIO=anc") { [weak self] response in
            self?.ancEnabled = response.contains(":on")
            self?.delegate?.ancStateChanged(self?.ancEnabled ?? false)
        }

        // Query transparency after a small delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.sendATCommand("AT.UIAUDIO=transparency") { response in
                self?.transparencyEnabled = response.contains(":on")
                self?.delegate?.transparencyStateChanged(self?.transparencyEnabled ?? false)
            }
        }

    }

    func powerOff() {
        // This would use RACE protocol, not AT command
        // For now, just disconnect
        disconnect()
    }

    func setDeviceName(_ name: String) {
        sendATCommand("AT.BLUETOOTH=advcustomname,\(name)")
    }

    func resetDeviceName() {
        sendATCommand("AT.BLUETOOTH=advdefaultname")
    }

    func getBluetoothAddress(completion: @escaping (String) -> Void) {
        sendATCommand("AT.BLUETOOTH=localaddr") { response in
            // Parse address from response like "8E:5D:79:E0:EE:5B\r\nOK"
            let lines = response.components(separatedBy: "\r\n")
            if let address = lines.first(where: { $0.contains(":") && $0.count == 17 }) {
                completion(address)
            } else {
                completion("Unknown")
            }
        }
    }
}

// MARK: - IOBluetoothRFCOMMChannelDelegate

extension CrusherConnection: IOBluetoothRFCOMMChannelDelegate {

    func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, status error: IOReturn) {
        if error == kIOReturnSuccess {
            print("[Crusher] Channel open complete")
            isConnected = true
            queryStatus()
        } else {
            print("[Crusher] Channel open failed: \(error)")
            isConnected = false
        }
    }

    func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
        print("[Crusher] Channel closed")
        isConnected = false
    }

    func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        let data = Data(bytes: dataPointer, count: dataLength)
        if let str = String(data: data, encoding: .utf8) {
            responseBuffer += str
            print("[Crusher] RX: \(str.replacingOccurrences(of: "\r\n", with: "\\r\\n"))")

            // Check for unsolicited state updates (headphone button presses)
            checkForUnsolicitedUpdates(str)

            // Check if response is complete (ends with OK or ERROR)
            if responseBuffer.contains("OK") || responseBuffer.contains("ERROR") {
                let response = responseBuffer
                responseBuffer = ""

                DispatchQueue.main.async { [weak self] in
                    self?.responseCompletion?(response)
                    self?.delegate?.responseReceived(response)
                }
            }
        }
    }

    private func checkForUnsolicitedUpdates(_ data: String) {
        // Listen for unsolicited ANC/Transparency state changes
        // These may come when physical buttons are pressed on the headphones
        DispatchQueue.main.async { [weak self] in
            // Check for ANC state changes
            if data.contains("anc") {
                if data.contains(":on") || data.contains("=on") {
                    self?.ancEnabled = true
                    self?.transparencyEnabled = false  // ANC and transparency are mutually exclusive
                    self?.delegate?.ancStateChanged(true)
                } else if data.contains(":off") || data.contains("=off") {
                    self?.ancEnabled = false
                    self?.delegate?.ancStateChanged(false)
                }
            }

            // Check for Transparency state changes
            if data.contains("transparency") {
                if data.contains(":on") || data.contains("=on") {
                    self?.transparencyEnabled = true
                    self?.ancEnabled = false  // ANC and transparency are mutually exclusive
                    self?.delegate?.transparencyStateChanged(true)
                } else if data.contains(":off") || data.contains("=off") {
                    self?.transparencyEnabled = false
                    self?.delegate?.transparencyStateChanged(false)
                }
            }
        }
    }

    func rfcommChannelWriteComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, refcon: UnsafeMutableRawPointer!, status error: IOReturn) {
        if error != kIOReturnSuccess {
            print("[Crusher] Write error: \(error)")
        }
    }
}
