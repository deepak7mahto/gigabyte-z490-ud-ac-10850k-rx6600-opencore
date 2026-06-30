import Cocoa
import Foundation

class MenuApp: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem!
    var timer: Timer!
    var coreMenuItems: [NSMenuItem] = []
    var menu: NSMenu!
    var didInitializeCores = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusBarItem.button {
            button.title = "--- MHz"
        }
        
        // Base menu structure
        menu = NSMenu()
        menu.addItem(NSMenuItem(title: "CPU Frequency Monitor", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        // Core items will be dynamically inserted here later
        
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
                    let results = self.parseAllFrequencies(output)
                    
                    DispatchQueue.main.async {
                        // 1. Update overall status button
                        if let systemFreq = results.system, let button = self.statusBarItem.button {
                            button.title = systemFreq
                        }
                        
                        // 2. Initialize core menu items if needed
                        if !self.didInitializeCores && !results.cores.isEmpty {
                            self.initializeCoreMenu(count: results.cores.count)
                        }
                        
                        // 3. Update individual core titles
                        for (i, freqVal) in results.cores.enumerated() {
                            if i < self.coreMenuItems.count {
                                let freqStr: String
                                if freqVal >= 1000.0 {
                                    freqStr = String(format: "%.2f GHz", freqVal / 1000.0)
                                } else {
                                    freqStr = String(format: "%.0f MHz", freqVal)
                                }
                                self.coreMenuItems[i].title = "  Core \(i): \(freqStr)"
                            }
                        }
                    }
                }
            } catch {
                print("Error running task: \(error)")
            }
        }
    }
    
    func initializeCoreMenu(count: Int) {
        // Insert core menu items before the second-to-last item (the quit separator and quit button)
        let insertIndex = 2
        for i in 0..<count {
            let item = NSMenuItem(title: "  Core \(i): --- MHz", action: nil, keyEquivalent: "")
            menu.insertItem(item, at: insertIndex + i)
            coreMenuItems.append(item)
        }
        didInitializeCores = true
    }
    
    func parseAllFrequencies(_ output: String) -> (system: String?, cores: [Double]) {
        let lines = output.components(separatedBy: .newlines)
        var systemFreq: String? = nil
        var threadFrequencies = [Int: Double]()
        
        var currentCPU: Int? = nil
        
        for line in lines {
            // Find overall system average
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
                                    systemFreq = String(format: "%.2f GHz", val / 1000.0)
                                } else {
                                    systemFreq = String(format: "%.0f MHz", val)
                                }
                            }
                        }
                    }
                }
            }
            
            // Detect CPU thread headers (e.g. "CPU 0 duty cycles/s:")
            if line.hasPrefix("CPU ") && line.contains("duty cycles/s:") {
                let parts = line.split(separator: " ")
                if parts.count >= 2 {
                    let numStr = parts[1]
                    if let idx = Int(numStr) {
                        currentCPU = idx
                    }
                }
            }
            
            // Parse CPU thread frequency if we have a active CPU index
            if let cpuIdx = currentCPU, line.contains("CPU Average frequency as fraction of nominal:") {
                if let openParen = line.firstIndex(of: "("), let closeParen = line.firstIndex(of: ")") {
                    let start = line.index(after: openParen)
                    let sub = String(line[start..<closeParen])
                    let parts = sub.split(separator: " ")
                    if parts.count >= 2 {
                        let valStr = parts[0]
                        if let val = Double(valStr) {
                            threadFrequencies[cpuIdx] = val
                        }
                    }
                }
                currentCPU = nil // Reset
            }
        }
        
        // Group threads into physical cores
        var coreFrequencies = [Double]()
        if !threadFrequencies.isEmpty {
            let maxThreadIdx = threadFrequencies.keys.max() ?? 0
            let coreCount = (maxThreadIdx + 1) / 2
            
            for i in 0..<coreCount {
                let t1 = threadFrequencies[i * 2] ?? 0.0
                let t2 = threadFrequencies[i * 2 + 1] ?? 0.0
                let avg = (t1 + t2) / 2.0
                coreFrequencies.append(avg)
            }
        }
        
        return (systemFreq, coreFrequencies)
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
