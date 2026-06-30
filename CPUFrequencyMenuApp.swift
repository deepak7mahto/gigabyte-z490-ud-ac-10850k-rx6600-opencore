import Cocoa
import Foundation

class MenuApp: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem!
    var timer: Timer!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusBarItem.button {
            button.title = "--- MHz"
        }
        
        // Add a menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "CPU Frequency Monitor", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusBarItem.menu = menu
        
        // Timer to update frequency every 2 seconds
        timer = Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(updateFrequency), userInfo: nil, repeats: true)
        
        // Run update immediately
        updateFrequency()
    }
    
    @objc func updateFrequency() {
        DispatchQueue.global(qos: .background).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
            task.arguments = ["/usr/bin/powermetrics", "-n", "1", "-i", "100", "--samplers", "cpu_power"]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = FileHandle.nullDevice
            
            do {
                try task.run()
                task.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    if let freq = self.parseFrequency(output) {
                        DispatchQueue.main.async {
                            if let button = self.statusBarItem.button {
                                button.title = freq
                            }
                        }
                    }
                }
            } catch {
                print("Error running task: \(error)")
            }
        }
    }
    
    func parseFrequency(_ output: String) -> String? {
        // Expected format: "System Average frequency as fraction of nominal: 74.90% (2696.44 Mhz)"
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("System Average frequency") {
                if let openParen = line.firstIndex(of: "("), let closeParen = line.firstIndex(of: ")") {
                    let start = line.index(after: openParen)
                    let sub = String(line[start..<closeParen])
                    let parts = sub.split(separator: " ")
                    if parts.count >= 2 {
                        let valStr = parts[0]
                        let unit = parts[1]
                        if let val = Double(valStr) {
                            if unit.lowercased().contains("mhz") {
                                if val >= 1000.0 {
                                    return String(format: "%.2f GHz", val / 1000.0)
                                } else {
                                    return String(format: "%.0f MHz", val)
                                }
                            }
                        }
                    }
                    return sub
                }
            }
        }
        return nil
    }
    
    @objc func quit() {
        NSApplication.shared.terminate(self)
    }
}

// Set up the application
let app = NSApplication.shared
let delegate = MenuApp()
app.delegate = delegate

// Run as accessory app (no dock icon, but shows menu bar item)
app.setActivationPolicy(.accessory)

app.run()
