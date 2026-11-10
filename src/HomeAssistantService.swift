import Foundation
import Combine

public class HomeAssistantService: ObservableObject {
    public static let shared = HomeAssistantService()
    
    @Published public var currentReading: PowerReading = .empty
    @Published public var readingHistory: [PowerReading] = []
    @Published public var isConnected: Bool = false
    @Published public var lastUpdated: Date? = nil
    @Published public var lastError: String? = nil
    @Published public var discoveredSensors: [DiscoveredSensor] = []
    @Published public var isSearchingSensors: Bool = false
    
    private var timer: AnyCancellable?
    private let settings = AppSettings.shared
    private var cancellables = Set<AnyCancellable>()
    private var webSocketTask: URLSessionWebSocketTask?
    
    // Hubitat cache
    private var hubitatWattsA: Double = 0
    private var hubitatWattsB: Double = 0
    private var hubitatAmpsA: Double = 0
    private var hubitatAmpsB: Double = 0
    private var hubitatVoltsA: Double = 120
    private var hubitatVoltsB: Double = 120
    private var hubitatTotalW: Double = 0
    private var hubitatTotalA: Double = 0
    
    // Demo simulation state
    private var demoStep: Double = 0
    private var simulatedSpikeTicks: Int = 0
    
    public init() {
        startPolling()
        
        // Restart polling if refresh interval or demo mode changes
        settings.$refreshInterval
            .dropFirst()
            .sink { [weak self] _ in self?.startPolling() }
            .store(in: &cancellables)
            
        settings.$demoMode
            .dropFirst()
            .sink { [weak self] _ in self?.startPolling() }
            .store(in: &cancellables)
            
        settings.$dataSource
            .dropFirst()
            .sink { [weak self] _ in self?.startPolling() }
            .store(in: &cancellables)
            
        settings.$hubitatDeviceID
            .dropFirst()
            .sink { [weak self] _ in self?.startPolling() }
            .store(in: &cancellables)
    }
    
    public func startPolling() {
        timer?.cancel()
        
        if settings.dataSource == .hubitat && !settings.demoMode {
            connectHubitatWebSocket()
        } else {
            disconnectHubitatWebSocket()
        }
        
        let interval = max(1.0, settings.refreshInterval)
        timer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.fetchLatestData()
            }
        
        // Initial fetch immediately
        fetchLatestData()
    }
    
    public func fetchLatestData() {
        if settings.demoMode {
            runSimulationStep()
            return
        }
        
        if settings.dataSource == .homeAssistant {
            fetchHomeAssistantData()
        } else {
            fetchHubitatData()
        }
    }
    
    public func fetchHomeAssistantData() {
        if settings.haToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            runSimulationStep()
            return
        }
        
        guard let baseURL = URL(string: settings.haURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            self.lastError = "Invalid Home Assistant URL"
            self.isConnected = false
            return
        }
        
        let statesURL = baseURL.appendingPathComponent("api/states")
        var request = URLRequest(url: statesURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(settings.haToken.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 4.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    self.lastError = error.localizedDescription
                    self.isConnected = false
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.lastError = "Invalid server response"
                    self.isConnected = false
                    return
                }
                
                guard httpResponse.statusCode == 200, let data = data else {
                    if httpResponse.statusCode == 401 {
                        self.lastError = "401 Unauthorized: Check Long-Lived Access Token"
                    } else {
                        self.lastError = "HTTP Error \(httpResponse.statusCode)"
                    }
                    self.isConnected = false
                    return
                }
                
                do {
                    let entities = try JSONDecoder().decode([HAEntityState].self, from: data)
                    self.processEntities(entities)
                    self.isConnected = true
                    self.lastError = nil
                    self.lastUpdated = Date()
                } catch {
                    self.lastError = "JSON Decode Error: \(error.localizedDescription)"
                    self.isConnected = false
                }
            }
        }.resume()
    }
    
    public func fetchHubitatData() {
        // If Maker API is configured, poll device details
        let appID = settings.hubitatMakerAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = settings.hubitatMakerToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let devID = settings.hubitatDeviceID.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let baseURL = URL(string: settings.hubitatURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            self.lastError = "Invalid Hubitat URL"
            return
        }
        
        // Ensure WebSocket is connected for live pushes
        if webSocketTask == nil || webSocketTask?.state != .running {
            connectHubitatWebSocket()
        }
        
        // Sample current live reading into history at a steady, rhythmic cadence
        if currentReading != .empty {
            self.recordHistory(self.currentReading)
        }
        
        if !appID.isEmpty && !token.isEmpty && !devID.isEmpty {
            let makerURL = baseURL.appendingPathComponent("apps/api/\(appID)/devices/\(devID)").appending(queryItems: [URLQueryItem(name: "access_token", value: token)])
            var req = URLRequest(url: makerURL)
            req.timeoutInterval = 4.0
            
            URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
                guard let self = self, let data = data,
                      let details = try? JSONDecoder().decode(HubitatDeviceDetails.self, from: data),
                      let attributes = details.attributes else { return }
                
                DispatchQueue.main.async {
                    for attr in attributes {
                        if let val = attr.currentValue {
                            self.applyHubitatValue(name: attr.name, value: val)
                        }
                    }
                }
            }.resume()
        }
    }
    
    private func processEntities(_ entities: [HAEntityState]) {
        let stateMap = Dictionary(uniqueKeysWithValues: entities.map { ($0.entity_id, $0) })
        
        let defaultV = settings.defaultVoltage > 0 ? settings.defaultVoltage : 120.0
        
        // Extract Phase A values
        var wattsA: Double = 0
        var ampsA: Double = 0
        var voltsA: Double = defaultV
        
        if !settings.phaseAVoltageEntity.isEmpty,
           let vState = stateMap[settings.phaseAVoltageEntity]?.state,
           let val = Double(vState), val > 0 {
            voltsA = val
        }
        
        if !settings.phaseAPowerEntity.isEmpty,
           let pState = stateMap[settings.phaseAPowerEntity]?.state,
           let val = Double(pState) {
            wattsA = max(0, val)
        }
        
        if !settings.phaseACurrentEntity.isEmpty,
           let cState = stateMap[settings.phaseACurrentEntity]?.state,
           let val = Double(cState) {
            ampsA = max(0, val)
        } else if wattsA > 0 && voltsA > 0 {
            ampsA = wattsA / voltsA
        }
        
        if wattsA == 0 && ampsA > 0 {
            wattsA = ampsA * voltsA
        }
        
        // Extract Phase B values
        var wattsB: Double = 0
        var ampsB: Double = 0
        var voltsB: Double = defaultV
        
        if !settings.phaseBVoltageEntity.isEmpty,
           let vState = stateMap[settings.phaseBVoltageEntity]?.state,
           let val = Double(vState), val > 0 {
            voltsB = val
        }
        
        if !settings.phaseBPowerEntity.isEmpty,
           let pState = stateMap[settings.phaseBPowerEntity]?.state,
           let val = Double(pState) {
            wattsB = max(0, val)
        }
        
        if !settings.phaseBCurrentEntity.isEmpty,
           let cState = stateMap[settings.phaseBCurrentEntity]?.state,
           let val = Double(cState) {
            ampsB = max(0, val)
        } else if wattsB > 0 && voltsB > 0 {
            ampsB = wattsB / voltsB
        }
        
        if wattsB == 0 && ampsB > 0 {
            wattsB = ampsB * voltsB
        }
        
        // Total values
        var totalW = wattsA + wattsB
        if !settings.totalPowerEntity.isEmpty,
           let tState = stateMap[settings.totalPowerEntity]?.state,
           let val = Double(tState), val > 0 {
            totalW = val
        }
        
        let avgVolts = (voltsA + voltsB) / 2.0
        let totalA = avgVolts > 0 ? (totalW / avgVolts) : (ampsA + ampsB)
        
        let newReading = PowerReading(
            timestamp: Date(),
            phaseAWatts: wattsA,
            phaseAAmps: ampsA,
            phaseAVolts: voltsA,
            phaseBWatts: wattsB,
            phaseBAmps: ampsB,
            phaseBVolts: voltsB,
            totalWatts: totalW,
            totalAmps: totalA
        )
        
        self.currentReading = newReading
        self.recordHistory(newReading)
    }
    
    private func runSimulationStep() {
        demoStep += 0.2
        
        // Base household load fluctuating
        let baseA = 750.0 + sin(demoStep * 0.8) * 120.0 + Double.random(in: -25...25)
        var baseB = 1100.0 + cos(demoStep * 0.5) * 180.0 + Double.random(in: -30...30)
        
        // Periodically simulate an appliance cycling (e.g. microwave or kettle on Phase B)
        if simulatedSpikeTicks > 0 {
            simulatedSpikeTicks -= 1
            baseB += 1400.0
        } else if Int.random(in: 1...25) == 7 {
            simulatedSpikeTicks = 6 // lasts ~18 seconds
        }
        
        let voltsA = 120.2 + sin(demoStep * 0.2) * 0.6
        let voltsB = 119.8 - cos(demoStep * 0.2) * 0.5
        
        let wattsA = max(50, baseA)
        let wattsB = max(50, baseB)
        let ampsA = wattsA / voltsA
        let ampsB = wattsB / voltsB
        let totalW = wattsA + wattsB
        let totalA = ampsA + ampsB
        
        let newReading = PowerReading(
            timestamp: Date(),
            phaseAWatts: wattsA,
            phaseAAmps: ampsA,
            phaseAVolts: voltsA,
            phaseBWatts: wattsB,
            phaseBAmps: ampsB,
            phaseBVolts: voltsB,
            totalWatts: totalW,
            totalAmps: totalA
        )
        
        self.currentReading = newReading
        self.isConnected = true
        self.lastError = nil
        self.lastUpdated = Date()
        self.recordHistory(newReading)
    }
    
    private func recordHistory(_ reading: PowerReading) {
        readingHistory.append(reading)
        if readingHistory.count > 60 {
            readingHistory.removeFirst(readingHistory.count - 60)
        }
    }
    
    public func testConnection(url: String, token: String, completion: @escaping (Bool, String) -> Void) {
        guard let baseURL = URL(string: url.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            completion(false, "Invalid URL format.")
            return
        }
        
        let apiURL = baseURL.appendingPathComponent("api/")
        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 5.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, "Connection error: \(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false, "Invalid server response.")
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    completion(true, "Successfully connected to Home Assistant API!")
                } else if httpResponse.statusCode == 401 {
                    completion(false, "Authentication Failed (401): Check Long-Lived Access Token.")
                } else {
                    completion(false, "Server returned HTTP status \(httpResponse.statusCode).")
                }
            }
        }.resume()
    }
    
    public func discoverEnergySensors(completion: @escaping ([DiscoveredSensor]) -> Void) {
        guard let baseURL = URL(string: settings.haURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            completion([])
            return
        }
        
        self.isSearchingSensors = true
        let statesURL = baseURL.appendingPathComponent("api/states")
        var request = URLRequest(url: statesURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(settings.haToken.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 8.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isSearchingSensors = false
                guard let data = data,
                      let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    completion([])
                    return
                }
                
                guard let entities = try? JSONDecoder().decode([HAEntityState].self, from: data) else {
                    completion([])
                    return
                }
                
                var results: [DiscoveredSensor] = []
                
                for item in entities {
                    let entityId = item.entity_id.lowercased()
                    let unit = item.attributes?.unit_of_measurement?.lowercased() ?? ""
                    let deviceClass = item.attributes?.device_class?.lowercased() ?? ""
                    let name = item.attributes?.friendly_name ?? item.entity_id
                    
                    var isCandidate = false
                    var kind = "other"
                    
                    if deviceClass == "power" || unit == "w" || unit == "kw" {
                        isCandidate = true
                        kind = "power"
                    } else if deviceClass == "current" || unit == "a" {
                        isCandidate = true
                        kind = "current"
                    } else if deviceClass == "voltage" || unit == "v" {
                        isCandidate = true
                        kind = "voltage"
                    } else if deviceClass == "energy" || unit == "kwh" {
                        isCandidate = true
                        kind = "energy"
                    } else if entityId.contains("power") || entityId.contains("current") || entityId.contains("clamp") || entityId.contains("phase") || entityId.contains("energy") {
                        isCandidate = true
                        kind = "energy"
                    }
                    
                    if isCandidate {
                        // Infer phase A, B, or Total
                        var phase: String? = nil
                        let idAndName = (entityId + " " + name).lowercased()
                        if idAndName.contains("phase_a") || idAndName.contains("phase a") || idAndName.contains("leg_a") || idAndName.contains("leg a") || idAndName.contains("channel_1") || idAndName.contains("clamp_1") || idAndName.contains("clamp a") || idAndName.contains("ct_1") || idAndName.contains("ct a") || idAndName.contains("line_1") || idAndName.contains("line a") {
                            phase = "A"
                        } else if idAndName.contains("phase_b") || idAndName.contains("phase b") || idAndName.contains("leg_b") || idAndName.contains("leg b") || idAndName.contains("channel_2") || idAndName.contains("clamp_2") || idAndName.contains("clamp b") || idAndName.contains("ct_2") || idAndName.contains("ct b") || idAndName.contains("line_2") || idAndName.contains("line b") {
                            phase = "B"
                        } else if idAndName.contains("total") || idAndName.contains("sum") || idAndName.contains("panel") || idAndName.contains("grid") || idAndName.contains("main") {
                            phase = "Total"
                        }
                        
                        results.append(DiscoveredSensor(
                            entityId: item.entity_id,
                            friendlyName: name,
                            unit: item.attributes?.unit_of_measurement ?? "",
                            kind: kind,
                            inferredPhase: phase
                        ))
                    }
                }
                
                // Sort by inferred phase then friendly name
                results.sort {
                    ($0.inferredPhase ?? "Z", $0.friendlyName) < ($1.inferredPhase ?? "Z", $1.friendlyName)
                }
                
                self?.discoveredSensors = results
                completion(results)
            }
        }.resume()
    }
    
    // MARK: - Hubitat Direct Integration
    public func connectHubitatWebSocket() {
        disconnectHubitatWebSocket()
        
        guard let url = URL(string: settings.hubitatURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = url.host else {
            self.lastError = "Invalid Hubitat URL"
            return
        }
        
        let port = url.port ?? 80
        guard let wsURL = URL(string: "ws://\(host):\(port)/eventsocket") else { return }
        
        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: wsURL)
        self.webSocketTask = task
        task.resume()
        
        self.isConnected = true
        self.lastError = nil
        listenWebSocket(task)
    }
    
    public func disconnectHubitatWebSocket() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }
    
    private func listenWebSocket(_ task: URLSessionWebSocketTask) {
        task.receive { [weak self, weak task] result in
            guard let self = self, let task = task, self.webSocketTask === task else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8) {
                        self.handleHubitatWebSocketData(data)
                    }
                case .data(let data):
                    self.handleHubitatWebSocketData(data)
                @unknown default:
                    break
                }
                self.listenWebSocket(task)
                
            case .failure(let error):
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if self.settings.dataSource == .hubitat && !self.settings.demoMode {
                        self.lastError = "EventSocket: \(error.localizedDescription)"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                            if self?.settings.dataSource == .hubitat {
                                self?.connectHubitatWebSocket()
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func handleHubitatWebSocketData(_ data: Data) {
        guard let event = try? JSONDecoder().decode(HubitatWebSocketEvent.self, from: data) else { return }
        let targetId = settings.hubitatDeviceID.trimmingCharacters(in: .whitespacesAndNewlines)
        if let devId = event.deviceId, !targetId.isEmpty, devId != targetId {
            return
        }
        
        guard let name = event.name, let valueStr = event.value, let val = Double(valueStr) else { return }
        DispatchQueue.main.async {
            self.applyHubitatValue(name: name, value: val)
        }
    }
    
    private func applyHubitatValue(name: String, value: Double) {
        let defaultV = settings.defaultVoltage > 0 ? settings.defaultVoltage : 120.0
        if hubitatVoltsA == 0 { hubitatVoltsA = defaultV }
        if hubitatVoltsB == 0 { hubitatVoltsB = defaultV }
        
        switch name.lowercased() {
        case "power_a", "powera":
            hubitatWattsA = max(0, value)
        case "power_b", "powerb":
            hubitatWattsB = max(0, value)
        case "amperage_a", "amperagea":
            hubitatAmpsA = max(0, value)
        case "amperage_b", "amperageb":
            hubitatAmpsB = max(0, value)
        case "voltage":
            if value > 0 {
                hubitatVoltsA = value
                hubitatVoltsB = value
            }
        case "power", "power_total", "powertotal", "power_ab":
            if value > 0 {
                hubitatTotalW = value
            }
        case "amperage":
            if value > 0 {
                hubitatTotalA = value
            }
        default:
            return
        }
        
        // Calculate currents if not reported directly
        if hubitatAmpsA == 0 && hubitatWattsA > 0 && hubitatVoltsA > 0 {
            hubitatAmpsA = hubitatWattsA / hubitatVoltsA
        }
        if hubitatAmpsB == 0 && hubitatWattsB > 0 && hubitatVoltsB > 0 {
            hubitatAmpsB = hubitatWattsB / hubitatVoltsB
        }
        
        let totalW = hubitatTotalW > 0 ? hubitatTotalW : (hubitatWattsA + hubitatWattsB)
        let totalA = hubitatTotalA > 0 ? hubitatTotalA : (hubitatAmpsA + hubitatAmpsB)
        
        let newReading = PowerReading(
            timestamp: Date(),
            phaseAWatts: hubitatWattsA,
            phaseAAmps: hubitatAmpsA,
            phaseAVolts: hubitatVoltsA,
            phaseBWatts: hubitatWattsB,
            phaseBAmps: hubitatAmpsB,
            phaseBVolts: hubitatVoltsB,
            totalWatts: totalW,
            totalAmps: totalA
        )
        
        self.currentReading = newReading
        self.isConnected = true
        self.lastError = nil
        self.lastUpdated = Date()
    }
    
    public func testHubitatConnection(url: String, deviceID: String, appID: String, token: String, completion: @escaping (Bool, String) -> Void) {
        guard let baseURL = URL(string: url.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            completion(false, "Invalid Hubitat URL format.")
            return
        }
        
        if !appID.isEmpty && !token.isEmpty {
            guard let makerURL = URL(string: "\(baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/apps/api/\(appID)/devices/\(deviceID)?access_token=\(token)") else {
                completion(false, "Invalid Maker API URL.")
                return
            }
            var req = URLRequest(url: makerURL)
            req.timeoutInterval = 4.0
            URLSession.shared.dataTask(with: req) { data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(false, "Maker API Error: \(error.localizedDescription)")
                        return
                    }
                    guard let http = response as? HTTPURLResponse else {
                        completion(false, "Invalid response from Hubitat.")
                        return
                    }
                    if http.statusCode == 200 {
                        completion(true, "Successfully connected to Hubitat Maker API!")
                    } else {
                        completion(false, "Hubitat Maker API returned HTTP \(http.statusCode)")
                    }
                }
            }.resume()
        } else {
            var req = URLRequest(url: baseURL)
            req.timeoutInterval = 3.0
            URLSession.shared.dataTask(with: req) { data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(false, "Hubitat unreachable: \(error.localizedDescription)")
                    } else {
                        completion(true, "Hubitat Hub reachable! EventSocket streaming active.")
                    }
                }
            }.resume()
        }
    }
}
