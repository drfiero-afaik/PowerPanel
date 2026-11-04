import SwiftUI

public struct DashboardView: View {
    @ObservedObject var service = HomeAssistantService.shared
    @ObservedObject var settings = AppSettings.shared
    
    @State private var displayUnit: DisplayUnit = .watts
    @State private var showingSettings: Bool = false
    @State private var showingQuitConfirmation: Bool = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 12) {
            // Header
            headerBar
            
            // Total Power Hero Card
            totalPowerCard
            
            // Dual Phase Cards (Phase A & Phase B)
            dualPhaseCards
            
            // Phase Balance Indicator
            phaseBalanceCard
            
            // Live 60-Second Trend Chart
            LiveChartView(history: service.readingHistory, showAmps: displayUnit == .amps)
            
            Divider()
                .padding(.vertical, 2)
            
            // Footer
            footerBar
        }
        .padding(14)
        .frame(width: 360)
        .sheet(isPresented: $showingSettings) {
            SettingsView(isPresented: $showingSettings)
        }
    }
    
    // MARK: - Header
    private var headerBar: some View {
        HStack {
            Image(systemName: "bolt.batteryblock.fill")
                .foregroundColor(.yellow)
                .font(.system(size: 16))
            
            VStack(alignment: .leading, spacing: 1) {
                Text("PanelPower")
                    .font(.system(size: 13, weight: .bold))
                Text("Main Service Monitor")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Status Pill
            statusPill
            
            // Unit Switcher
            Picker("", selection: $displayUnit) {
                Text("Watts").tag(DisplayUnit.watts)
                Text("Amps").tag(DisplayUnit.amps)
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(width: 105)
        }
    }
    
    private var statusPill: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            Text(statusText)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(statusColor.opacity(0.12)))
    }
    
    private var statusColor: Color {
        if settings.demoMode {
            return .orange
        } else if service.isConnected {
            return .green
        } else {
            return .red
        }
    }
    
    private var statusText: String {
        if settings.demoMode {
            return "Demo"
        } else if service.isConnected {
            return "Live"
        } else {
            return "Offline"
        }
    }
    
    // MARK: - Total Power Hero Card
    private var totalPowerCard: some View {
        let reading = service.currentReading
        let maxPanelWatts = settings.mainBreakerAmps * 240.0 // 240V split-phase capacity
        let loadPercent = maxPanelWatts > 0 ? min(100.0, (reading.totalWatts / maxPanelWatts) * 100.0) : 0
        let capacityAmps = settings.mainBreakerAmps
        let usedAmps = reading.totalAmps
        
        return VStack(spacing: 6) {
            HStack {
                Text("TOTAL PANEL DEMAND")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(capacityAmps))A Main Service")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            
            HStack(alignment: .firstTextBaseline) {
                if displayUnit == .watts {
                    if reading.totalWatts >= 1000 {
                        Text(String(format: "%.2f", reading.totalWatts / 1000.0))
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                        Text("kW")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(Int(reading.totalWatts))")
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                        Text("W")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(String(format: "%.1f A", usedAmps))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                } else {
                    Text(String(format: "%.1f", usedAmps))
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                    Text("A")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(formatWatts(reading.totalWatts))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            
            // Service Capacity Bar
            VStack(spacing: 2) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                            .frame(height: 7)
                        
                        Capsule()
                            .fill(capacityColor(loadPercent))
                            .frame(width: geo.size.width * CGFloat(loadPercent / 100.0), height: 7)
                    }
                }
                .frame(height: 7)
                
                HStack {
                    Text(String(format: "%.1f%% of Service Capacity", loadPercent))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.0f A remaining", max(0, capacityAmps - usedAmps)))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08), lineWidth: 1))
    }
    
    private func capacityColor(_ percent: Double) -> Color {
        if percent < 60 {
            return .green
        } else if percent < 80 {
            return .orange
        } else {
            return .red
        }
    }
    
    // MARK: - Dual Phase Cards
    private var dualPhaseCards: some View {
        let reading = service.currentReading
        
        return HStack(spacing: 10) {
            // Phase A Card
            phaseCard(
                title: "PHASE A",
                subtitle: "Leg 1",
                watts: reading.phaseAWatts,
                amps: reading.phaseAAmps,
                volts: reading.phaseAVolts,
                sharePercent: reading.balanceA,
                accentColor: .blue
            )
            
            // Phase B Card
            phaseCard(
                title: "PHASE B",
                subtitle: "Leg 2",
                watts: reading.phaseBWatts,
                amps: reading.phaseBAmps,
                volts: reading.phaseBVolts,
                sharePercent: reading.balanceB,
                accentColor: .orange
            )
        }
    }
    
    private func phaseCard(title: String, subtitle: String, watts: Double, amps: Double, volts: Double, sharePercent: Double, accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(accentColor)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                Spacer()
                Text(String(format: "%.0f%%", sharePercent))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(accentColor)
            }
            
            if displayUnit == .watts {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(formatWattsOnly(watts))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(accentColor)
                    Text(watts >= 1000 ? "kW" : "W")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text(String(format: "%.1f A", amps))
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    Text(String(format: "%.0f V", volts))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.1f", amps))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(accentColor)
                    Text("A")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text(formatWatts(watts))
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    Text(String(format: "%.0f V", volts))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 10).fill(accentColor.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(accentColor.opacity(0.2), lineWidth: 1))
    }
    
    // MARK: - Phase Balance Indicator
    private var phaseBalanceCard: some View {
        let reading = service.currentReading
        let aPercent = reading.balanceA
        let bPercent = reading.balanceB
        let diff = abs(aPercent - bPercent)
        
        let statusString: String
        let statusCol: Color
        if diff < 15.0 {
            statusString = "Balanced (Δ \(Int(diff))%)"
            statusCol = .green
        } else if diff < 30.0 {
            statusString = "Moderate Delta (Δ \(Int(diff))%)"
            statusCol = .orange
        } else {
            statusString = "High Imbalance (Δ \(Int(diff))%)"
            statusCol = .red
        }
        
        return VStack(spacing: 4) {
            HStack {
                Text("PHASE LOAD BALANCE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Text(statusString)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(statusCol)
            }
            
            // Dual bar
            GeometryReader { geo in
                let w = geo.size.width
                let aWidth = w * CGFloat(aPercent / 100.0)
                let bWidth = w * CGFloat(bPercent / 100.0)
                
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.blue)
                        .frame(width: max(2, aWidth))
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.orange)
                        .frame(width: max(2, bWidth))
                }
            }
            .frame(height: 6)
            
            HStack {
                Text("A: \(Int(aPercent))%")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.blue)
                Spacer()
                Text("B: \(Int(bPercent))%")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.orange)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.03)))
    }
    
    // MARK: - Footer
    private var footerBar: some View {
        HStack {
            if let error = service.lastError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 11))
                Text(error)
                    .font(.system(size: 10))
                    .foregroundColor(.red)
                    .lineLimit(1)
                    .truncationMode(.tail)
            } else if let updated = service.lastUpdated {
                Text("Updated \(timeAgoString(from: updated))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: { service.fetchLatestData() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
            }
            .buttonStyle(BorderlessButtonStyle())
            .help("Refresh now")
            
            Button(action: { showingSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
            }
            .buttonStyle(BorderlessButtonStyle())
            .help("Settings & HA Entities")
            .padding(.leading, 6)
            
            Button(action: { showingQuitConfirmation = true }) {
                Image(systemName: "power")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(BorderlessButtonStyle())
            .help("Quit PanelPower")
            .padding(.leading, 6)
            .confirmationDialog("Quit PanelPower?", isPresented: $showingQuitConfirmation, titleVisibility: .visible) {
                Button("Quit PanelPower", role: .destructive) {
                    NSApplication.shared.terminate(nil)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove the live energy monitor from your menu bar until you reopen it.")
            }
        }
    }
    
    private func formatWatts(_ w: Double) -> String {
        if w >= 1000.0 {
            return String(format: "%.2f kW", w / 1000.0)
        } else {
            return "\(Int(w)) W"
        }
    }
    
    private func formatWattsOnly(_ w: Double) -> String {
        if w >= 1000.0 {
            return String(format: "%.2f", w / 1000.0)
        } else {
            return "\(Int(w))"
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 5 { return "just now" }
        return "\(seconds)s ago"
    }
}
