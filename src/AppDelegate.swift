import AppKit
import SwiftUI
import Combine

public class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var eventMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    
    private let service = HomeAssistantService.shared
    private let settings = AppSettings.shared
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent window from appearing in dock
        NSApp.setActivationPolicy(.accessory)
        
        // Setup Status Bar Item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.title = "⚡ PanelPower"
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        
        // Setup Popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 510)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: DashboardView())
        
        // Close popover on outside clicks
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let popover = self?.popover, popover.isShown {
                self?.closePopover(event)
            }
        }
        
        // Subscribe to live reading changes and update menu bar button title
        Publishers.CombineLatest(service.$currentReading, settings.$menuBarFormat)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] reading, format in
                self?.updateMenuBarTitle(reading: reading, format: format)
            }
            .store(in: &cancellables)
    }
    
    private func updateMenuBarTitle(reading: PowerReading, format: MenuBarFormat) {
        guard let button = statusItem.button else { return }
        
        switch format {
        case .totalPower:
            button.title = "⚡ " + formatWatts(reading.totalWatts)
        case .dualPhase:
            let aStr = formatWattsShort(reading.phaseAWatts)
            let bStr = formatWattsShort(reading.phaseBWatts)
            button.title = "A: \(aStr) | B: \(bStr)"
        case .both:
            let totalStr = formatWattsShort(reading.totalWatts)
            let aStr = formatWattsShort(reading.phaseAWatts)
            let bStr = formatWattsShort(reading.phaseBWatts)
            button.title = "⚡ \(totalStr) [\(aStr) | \(bStr)]"
        case .totalAmps:
            button.title = String(format: "⚡ %.1f A", reading.totalAmps)
        case .iconOnly:
            button.title = "⚡"
        }
    }
    
    private func formatWatts(_ w: Double) -> String {
        if w >= 1000.0 {
            return String(format: "%.2f kW", w / 1000.0)
        } else {
            return "\(Int(w)) W"
        }
    }
    
    private func formatWattsShort(_ w: Double) -> String {
        if w >= 1000.0 {
            return String(format: "%.1fk", w / 1000.0)
        } else {
            return "\(Int(w))"
        }
    }
    
    @objc private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover(sender)
        }
    }
    
    private func showPopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            service.fetchLatestData() // Refresh on open
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    private func closePopover(_ sender: AnyObject?) {
        popover.performClose(sender)
    }
}
