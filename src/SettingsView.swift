import SwiftUI

public struct SettingsView: View {
    @Binding var isPresented: Bool
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var service = HomeAssistantService.shared
    
    @State private var testStatus: String? = nil
    @State private var isTesting: Bool = false
    @State private var testSuccess: Bool = false
    
    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("PanelPower Settings")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button("Done") {
                    isPresented = false
                    service.startPolling()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color.primary.opacity(0.04))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Source Selector
                    Picker("Data Source", selection: $settings.dataSource) {
                        ForEach(DataSourceType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    if settings.dataSource == .homeAssistant {
                        // Section 1: Home Assistant Server
                        connectionSection
                        
                        // Section 2: Sensor Entity Mapping
                        entitiesSection
                    } else {
                        // Hubitat Direct Connection
                        hubitatConnectionSection
                    }
                    
                    // Section 3: Panel & Display Options
                    panelOptionsSection
                    
                    // Section 4: Demo / Simulation
                    demoSection
                }
                .padding()
            }
        }
        .frame(width: 480, height: 560)
    }
    
    // MARK: - Connection Section
    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("1. Home Assistant Connection")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Server URL:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("http://homeassistant.local:8123", text: $settings.haURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Long-Lived Access Token:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                SecureField("Bearer Token (generate in HA Profile -> Long-Lived Access Tokens)", text: $settings.haToken)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            HStack {
                Button(action: runTestConnection) {
                    if isTesting {
                        ProgressView().scaleEffect(0.6).frame(width: 14, height: 14)
                    } else {
                        Text("Test Connection")
                    }
                }
                .disabled(isTesting || settings.haToken.isEmpty)
                
                if let status = testStatus {
                    HStack(spacing: 4) {
                        Image(systemName: testSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(testSuccess ? .green : .red)
                        Text(status)
                            .font(.caption)
                            .foregroundColor(testSuccess ? .green : .red)
                    }
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.03)))
    }
    
    private func runTestConnection() {
        isTesting = true
        testStatus = nil
        service.testConnection(url: settings.haURL, token: settings.haToken) { success, msg in
            self.isTesting = false
            self.testSuccess = success
            self.testStatus = msg
            if success {
                self.service.startPolling()
            }
        }
    }
    
    // MARK: - Entities Section
    private var entitiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("2. Zigbee CT Clamp Sensors")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: autoDiscover) {
                    if service.isSearchingSensors {
                        ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
                    } else {
                        Label("Auto-Discover Sensors", systemImage: "sparkles")
                    }
                }
                .disabled(service.isSearchingSensors || settings.haToken.isEmpty)
            }
            
            if !service.discoveredSensors.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Found \(service.discoveredSensors.count) energy/power sensors in your Home Assistant:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(service.discoveredSensors.prefix(8)) { s in
                                sensorChip(s)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            
            VStack(spacing: 8) {
                entityRow(label: "Phase A Power (W/kW):", binding: $settings.phaseAPowerEntity, placeholder: "sensor.phase_a_power")
                entityRow(label: "Phase A Current (A, optional):", binding: $settings.phaseACurrentEntity, placeholder: "sensor.phase_a_current")
                entityRow(label: "Phase B Power (W/kW):", binding: $settings.phaseBPowerEntity, placeholder: "sensor.phase_b_power")
                entityRow(label: "Phase B Current (A, optional):", binding: $settings.phaseBCurrentEntity, placeholder: "sensor.phase_b_current")
                entityRow(label: "Total Power (optional):", binding: $settings.totalPowerEntity, placeholder: "sensor.main_panel_total_power")
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.03)))
    }
    
    private func sensorChip(_ s: DiscoveredSensor) -> some View {
        Button(action: {
            if s.inferredPhase == "A" {
                if s.kind == "power" { settings.phaseAPowerEntity = s.entityId }
                else if s.kind == "current" { settings.phaseACurrentEntity = s.entityId }
            } else if s.inferredPhase == "B" {
                if s.kind == "power" { settings.phaseBPowerEntity = s.entityId }
                else if s.kind == "current" { settings.phaseBCurrentEntity = s.entityId }
            } else if s.inferredPhase == "Total" {
                settings.totalPowerEntity = s.entityId
            } else {
                // If unassigned, assign to Phase A if empty else B
                if settings.phaseAPowerEntity.isEmpty {
                    settings.phaseAPowerEntity = s.entityId
                } else if settings.phaseBPowerEntity.isEmpty {
                    settings.phaseBPowerEntity = s.entityId
                }
            }
        }) {
            HStack(spacing: 4) {
                if let p = s.inferredPhase {
                    Text(p)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(p == "A" ? Color.blue : (p == "B" ? Color.orange : Color.green))
                        .foregroundColor(.white)
                        .cornerRadius(3)
                }
                Text(s.friendlyName)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.06))
            .cornerRadius(5)
        }
        .buttonStyle(PlainButtonStyle())
        .help("Click to assign to matching phase")
    }
    
    private func autoDiscover() {
        service.discoverEnergySensors { sensors in
            for s in sensors {
                if s.inferredPhase == "A" && s.kind == "power" && settings.phaseAPowerEntity.isEmpty {
                    settings.phaseAPowerEntity = s.entityId
                } else if s.inferredPhase == "A" && s.kind == "current" && settings.phaseACurrentEntity.isEmpty {
                    settings.phaseACurrentEntity = s.entityId
                } else if s.inferredPhase == "B" && s.kind == "power" && settings.phaseBPowerEntity.isEmpty {
                    settings.phaseBPowerEntity = s.entityId
                } else if s.inferredPhase == "B" && s.kind == "current" && settings.phaseBCurrentEntity.isEmpty {
                    settings.phaseBCurrentEntity = s.entityId
                } else if s.inferredPhase == "Total" && s.kind == "power" && settings.totalPowerEntity.isEmpty {
                    settings.totalPowerEntity = s.entityId
                }
            }
        }
    }
    
    private func entityRow(label: String, binding: Binding<String>, placeholder: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 170, alignment: .leading)
            TextField(placeholder, text: binding)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 11, design: .monospaced))
        }
    }
    
    // MARK: - Panel Options Section
    private var panelOptionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("3. Panel Rating & Menu Bar Appearance")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
            
            HStack {
                Text("Main Service Rating:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 150, alignment: .leading)
                
                Picker("", selection: $settings.mainBreakerAmps) {
                    Text("100 Amp Service").tag(100.0)
                    Text("125 Amp Service").tag(125.0)
                    Text("150 Amp Service").tag(150.0)
                    Text("200 Amp Service").tag(200.0)
                    Text("400 Amp Service").tag(400.0)
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            HStack {
                Text("Menu Bar Text Format:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 150, alignment: .leading)
                
                Picker("", selection: $settings.menuBarFormat) {
                    ForEach(MenuBarFormat.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            HStack {
                Text("Polling Interval:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 150, alignment: .leading)
                
                Picker("", selection: $settings.refreshInterval) {
                    Text("1 second").tag(1.0)
                    Text("2 seconds").tag(2.0)
                    Text("3 seconds (Default)").tag(3.0)
                    Text("5 seconds").tag(5.0)
                    Text("10 seconds").tag(10.0)
                }
                .pickerStyle(MenuPickerStyle())
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.03)))
    }
    
    // MARK: - Demo Section
    private var demoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $settings.demoMode) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable Simulation / Demo Mode")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Generates realistic live fluctuating electrical panel readings for previewing the widget without connecting to Home Assistant.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.03)))
    }
    
    // MARK: - Hubitat Connection Section
    private var hubitatConnectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("1. Hubitat Hub Connection")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Hubitat Hub URL or IP:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("http://192.168.4.254", text: $settings.hubitatURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Device ID (from device URL on Hubitat, e.g. 693):")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("693", text: $settings.hubitatDeviceID)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Maker API App ID (Optional - for initial state polling):")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("e.g. 76", text: $settings.hubitatMakerAppID)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Maker API Access Token (Optional):")
                    .font(.caption)
                    .foregroundColor(.secondary)
                SecureField("Access Token from Maker API app", text: $settings.hubitatMakerToken)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            HStack {
                Button(action: runTestHubitatConnection) {
                    if isTesting {
                        ProgressView().scaleEffect(0.6).frame(width: 14, height: 14)
                    } else {
                        Text("Test Connection")
                    }
                }
                .disabled(isTesting || settings.hubitatURL.isEmpty || settings.hubitatDeviceID.isEmpty)
                
                if let status = testStatus {
                    HStack(spacing: 4) {
                        Image(systemName: testSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(testSuccess ? .green : .red)
                        Text(status)
                            .font(.caption)
                            .foregroundColor(testSuccess ? .green : .red)
                    }
                }
            }
            
            Text("⚡ EventSocket live streaming connects to ws://<hub>/eventsocket for real-time sub-second updates directly from Hubitat.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.03)))
    }
    
    private func runTestHubitatConnection() {
        isTesting = true
        testStatus = nil
        service.testHubitatConnection(
            url: settings.hubitatURL,
            deviceID: settings.hubitatDeviceID,
            appID: settings.hubitatMakerAppID,
            token: settings.hubitatMakerToken
        ) { success, message in
            self.isTesting = false
            self.testSuccess = success
            self.testStatus = message
            if success {
                self.service.startPolling()
            }
        }
    }
}
