import Cocoa
import Foundation

struct TelemetryResults {
    var system: String?
    var power: String?
    var thermal: String?
    var sleep: String?
    var cores: [Double]
}

class MenuApp: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem!
    var timer: Timer!
    var coreMenuItems: [NSMenuItem] = []
    var menu: NSMenu!
    var didInitializeCores = false
    
    var powerMenuItem: NSMenuItem!
    var thermalMenuItem: NSMenuItem!
    var sleepMenuItem: NSMenuItem!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusBarItem.button {
            button.title = "--- MHz"
        }
        
        // Base menu structure
        menu = NSMenu()
        menu.autoenablesItems = false
        
        let titleItem = NSMenuItem(title: "CPU Monitor", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())
        
        // Advanced Stats
        powerMenuItem = NSMenuItem(title: "Package Power: --- W", action: nil, keyEquivalent: "")
        powerMenuItem.isEnabled = true
        menu.addItem(powerMenuItem)
        
        thermalMenuItem = NSMenuItem(title: "Thermal Level: ---", action: nil, keyEquivalent: "")
        thermalMenuItem.isEnabled = true
        menu.addItem(thermalMenuItem)
        
        sleepMenuItem = NSMenuItem(title: "Core Sleep Avg: ---", action: nil, keyEquivalent: "")
        sleepMenuItem.isEnabled = true
        menu.addItem(sleepMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Cores Header
        let coreHeaderItem = NSMenuItem(title: "Core Frequencies:", action: nil, keyEquivalent: "")
        coreHeaderItem.isEnabled = false
        menu.addItem(coreHeaderItem)
        
        // Core items will be dynamically inserted here later
        
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        quitItem.isEnabled = true
        menu.addItem(quitItem)
        statusBarItem.menu = menu
        
        // Timer to update frequency every 2.0 seconds
        // Add to .common run loop mode so it keeps running while the menu is open (tracking mode)
        timer = Timer(timeInterval: 2.0, target: self, selector: #selector(updateFrequency), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        
        // Run update immediately
        updateFrequency()
    }
    
    @objc func updateFrequency() {
        DispatchQueue.global(qos: .background).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
            task.arguments = ["/usr/bin/powermetrics", "-n", "1", "-i", "100", "--samplers", "cpu_power,thermal"]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = FileHandle.nullDevice
            
            do {
                try task.run()
                task.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    let results = self.parseAllTelemetry(output)
                    
                    DispatchQueue.main.async {
                        // 1. Update overall status button
                        if let systemFreq = results.system, let button = self.statusBarItem.button {
                            button.title = systemFreq
                        }
                        
                        // 2. Update telemetry labels
                        if let power = results.power {
                            self.powerMenuItem.title = "Package Power: \(power)"
                        }
                        if let thermal = results.thermal {
                            self.thermalMenuItem.title = "Thermal Level: \(thermal)"
                        }
                        if let sleep = results.sleep {
                            self.sleepMenuItem.title = "Core Sleep Avg: \(sleep)"
                        }
                        
                        // 3. Initialize core menu items if needed
                        if !self.didInitializeCores && !results.cores.isEmpty {
                            self.initializeCoreMenu(count: results.cores.count)
                        }
                        
                        // 4. Update individual core titles
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
        // Insert core menu items right after the "Core Frequencies:" header (index 6)
        let insertIndex = 7
        for i in 0..<count {
            let item = NSMenuItem(title: "  Core \(i): --- MHz", action: nil, keyEquivalent: "")
            item.isEnabled = true
            menu.insertItem(item, at: insertIndex + i)
            coreMenuItems.append(item)
        }
        didInitializeCores = true
    }
    
    func parseAllTelemetry(_ output: String) -> TelemetryResults {
        let lines = output.components(separatedBy: .newlines)
        var systemFreq: String? = nil
        var powerStr: String? = nil
        var thermalStr: String? = nil
        var sleepStr: String? = nil
        
        var threadFrequencies = [Int: Double]()
        var c6Residencies = [Double]()
        
        var currentCPU: Int? = nil
        
        for line in lines {
            // 1. Average system frequency
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
            
            // 2. Package power
            if line.contains("derived package power") {
                let parts = line.split(separator: ":")
                if parts.count >= 2 {
                    var valPart = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    if valPart.hasSuffix("W") {
                        valPart = String(valPart.dropLast())
                    }
                    powerStr = "\(valPart) W"
                }
            }
            
            // 3. Thermal pressure
            if line.contains("Current pressure level:") {
                let parts = line.split(separator: ":")
                if parts.count >= 2 {
                    thermalStr = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            // 4. Core C-state residency
            if line.contains("C-state residency:") {
                if let c6Range = line.range(of: "C6: ") {
                    let sub = line[c6Range.upperBound...]
                    if let percentIdx = sub.firstIndex(of: "%") {
                        let valStr = sub[..<percentIdx].trimmingCharacters(in: .whitespaces)
                        if let val = Double(valStr) {
                            c6Residencies.append(val)
                        }
                    }
                }
            }
            
            // 5. Core frequencies
            if line.hasPrefix("CPU ") && line.contains("duty cycles/s:") {
                let parts = line.split(separator: " ")
                if parts.count >= 2 {
                    let numStr = parts[1]
                    if let idx = Int(numStr) {
                        currentCPU = idx
                    }
                }
            }
            
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
                currentCPU = nil
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
        
        // Average the sleep states
        if !c6Residencies.isEmpty {
            let total = c6Residencies.reduce(0.0, +)
            let avg = total / Double(c6Residencies.count)
            sleepStr = String(format: "%.0f%% (C6)", avg)
        } else {
            sleepStr = "---"
        }
        
        return TelemetryResults(system: systemFreq, power: powerStr, thermal: thermalStr, sleep: sleepStr, cores: coreFrequencies)
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
