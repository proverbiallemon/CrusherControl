import Foundation
import Cocoa

class UpdateChecker {
    static let githubOwner = "proverbiallemon"
    static let githubRepo = "CrusherControl"

    static func checkForUpdates(silent: Bool = true) {
        guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return
        }

        let urlString = "https://api.github.com/repos/\(githubOwner)/\(githubRepo)/releases/latest"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                if !silent {
                    DispatchQueue.main.async {
                        showAlert(title: "Update Check Failed", message: "Could not connect to GitHub.")
                    }
                }
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let tagName = json["tag_name"] as? String,
                   let assets = json["assets"] as? [[String: Any]],
                   let htmlUrl = json["html_url"] as? String {

                    // Remove 'v' prefix from tag if present
                    let latestVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

                    if isNewerVersion(latestVersion, than: currentVersion) {
                        DispatchQueue.main.async {
                            promptForUpdate(
                                currentVersion: currentVersion,
                                newVersion: latestVersion,
                                releaseUrl: htmlUrl,
                                assets: assets
                            )
                        }
                    } else if !silent {
                        DispatchQueue.main.async {
                            showAlert(title: "No Updates", message: "You're running the latest version (\(currentVersion)).")
                        }
                    }
                }
            } catch {
                if !silent {
                    DispatchQueue.main.async {
                        showAlert(title: "Update Check Failed", message: "Could not parse response.")
                    }
                }
            }
        }.resume()
    }

    private static func isNewerVersion(_ new: String, than current: String) -> Bool {
        let newParts = new.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(newParts.count, currentParts.count) {
            let newPart = i < newParts.count ? newParts[i] : 0
            let currentPart = i < currentParts.count ? currentParts[i] : 0

            if newPart > currentPart { return true }
            if newPart < currentPart { return false }
        }
        return false
    }

    private static func promptForUpdate(currentVersion: String, newVersion: String, releaseUrl: String, assets: [[String: Any]]) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = "A new version of Crusher Control is available.\n\nCurrent: v\(currentVersion)\nLatest: v\(newVersion)\n\nWould you like to download it?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            // Find the zip asset
            if let zipAsset = assets.first(where: { ($0["name"] as? String)?.hasSuffix(".zip") == true }),
               let downloadUrl = zipAsset["browser_download_url"] as? String,
               let url = URL(string: downloadUrl) {
                downloadAndInstall(from: url)
            } else if let url = URL(string: releaseUrl) {
                // Fallback to opening release page
                NSWorkspace.shared.open(url)
            }
        }
    }

    private static func downloadAndInstall(from url: URL) {
        let downloadTask = URLSession.shared.downloadTask(with: url) { tempUrl, response, error in
            guard let tempUrl = tempUrl, error == nil else {
                DispatchQueue.main.async {
                    showAlert(title: "Download Failed", message: "Could not download the update.")
                }
                return
            }

            DispatchQueue.main.async {
                installUpdate(from: tempUrl)
            }
        }
        downloadTask.resume()

        showAlert(title: "Downloading...", message: "The update is being downloaded. The app will restart when ready.")
    }

    private static func installUpdate(from zipUrl: URL) {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("CrusherControlUpdate")

        do {
            // Clean up any previous temp directory
            if fileManager.fileExists(atPath: tempDir.path) {
                try fileManager.removeItem(at: tempDir)
            }
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

            // Unzip
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-o", zipUrl.path, "-d", tempDir.path]
            try process.run()
            process.waitUntilExit()

            // Find the .app in the unzipped contents
            let contents = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            guard let newApp = contents.first(where: { $0.pathExtension == "app" }) else {
                showAlert(title: "Install Failed", message: "Could not find app in downloaded archive.")
                return
            }

            // Get current app location
            guard let currentAppUrl = Bundle.main.bundleURL as URL? else {
                showAlert(title: "Install Failed", message: "Could not determine current app location.")
                return
            }

            // Replace app (move current to trash, move new to location)
            let trashedUrl = try fileManager.url(for: .trashDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                .appendingPathComponent("CrusherControl-old-\(Date().timeIntervalSince1970).app")

            try fileManager.moveItem(at: currentAppUrl, to: trashedUrl)
            try fileManager.moveItem(at: newApp, to: currentAppUrl)

            // Relaunch
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            task.arguments = [currentAppUrl.path]
            try task.run()

            NSApp.terminate(nil)

        } catch {
            showAlert(title: "Install Failed", message: "Error: \(error.localizedDescription)")
        }
    }

    private static func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }
}
