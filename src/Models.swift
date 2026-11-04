import Foundation

public enum DataSourceType: String, CaseIterable, Identifiable {
    case homeAssistant = "Home Assistant"
    case hubitat = "Hubitat (Direct)"
    
    public var id: String { rawValue }
}

public enum DisplayUnit: String, CaseIterable, Identifiable {
    case watts = "Watts"
    case amps = "Amps"
    
    public var id: String { rawValue }
}

public enum MenuBarFormat: String, CaseIterable, Identifiable {
    case totalPower = "Total Only (⚡ 3.4 kW)"
    case dualPhase = "Dual Phase (A: 1.6k | B: 1.8k)"
    case both = "Combined (⚡ 3.4k [1.6 | 1.8])"
    case totalAmps = "Amps Only (⚡ 28.5 A)"
    case iconOnly = "Icon Only (⚡)"
    
    public var id: String { rawValue }
}

public struct PowerReading: Identifiable, Equatable {
    public let id = UUID()
    public let timestamp: Date
    
    public var phaseAWatts: Double
    public var phaseAAmps: Double
    public var phaseAVolts: Double
    
    public var phaseBWatts: Double
    public var phaseBAmps: Double
    public var phaseBVolts: Double
    
    public var totalWatts: Double
    public var totalAmps: Double
    
    public var balanceA: Double {
        let sum = phaseAWatts + phaseBWatts
        guard sum > 0 else { return 50.0 }
        return (phaseAWatts / sum) * 100.0
    }
    
    public var balanceB: Double {
        let sum = phaseAWatts + phaseBWatts
        guard sum > 0 else { return 50.0 }
        return (phaseBWatts / sum) * 100.0
    }
    
    public static var empty: PowerReading {
        PowerReading(
            timestamp: Date(),
            phaseAWatts: 0, phaseAAmps: 0, phaseAVolts: 120,
            phaseBWatts: 0, phaseBAmps: 0, phaseBVolts: 120,
            totalWatts: 0, totalAmps: 0
        )
    }
}

public struct HAEntityState: Codable, Identifiable {
    public var id: String { entity_id }
    public let entity_id: String
    public let state: String
    public let attributes: HAAttributes?
    
    public struct HAAttributes: Codable {
        public let friendly_name: String?
        public let unit_of_measurement: String?
        public let device_class: String?
        public let state_class: String?
    }
}

public struct DiscoveredSensor: Identifiable, Hashable {
    public var id: String { entityId }
    public let entityId: String
    public let friendlyName: String
    public let unit: String
    public let kind: String // "power", "current", "voltage", "energy"
    public let inferredPhase: String? // "A", "B", "Total", nil
}

public struct HubitatWebSocketEvent: Codable {
    public let source: String?
    public let name: String?
    public let displayName: String?
    public let value: String?
    public let unit: String?
    public let deviceId: String?
    
    enum CodingKeys: String, CodingKey {
        case source, name, displayName, value, unit, deviceId
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.source = try? container.decode(String.self, forKey: .source)
        self.name = try? container.decode(String.self, forKey: .name)
        self.displayName = try? container.decode(String.self, forKey: .displayName)
        self.value = try? container.decode(String.self, forKey: .value)
        self.unit = try? container.decode(String.self, forKey: .unit)
        
        if let idInt = try? container.decode(Int.self, forKey: .deviceId) {
            self.deviceId = String(idInt)
        } else if let idStr = try? container.decode(String.self, forKey: .deviceId) {
            self.deviceId = idStr
        } else {
            self.deviceId = nil
        }
    }
}

public struct HubitatDeviceDetails: Codable {
    public let id: String
    public let name: String?
    public let label: String?
    public let attributes: [HubitatDeviceAttribute]?
}

public struct HubitatDeviceAttribute: Codable {
    public let name: String
    public let currentValue: Double?
    
    enum CodingKeys: String, CodingKey {
        case name, currentValue
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        if let dbl = try? container.decode(Double.self, forKey: .currentValue) {
            self.currentValue = dbl
        } else if let str = try? container.decode(String.self, forKey: .currentValue), let dbl = Double(str) {
            self.currentValue = dbl
        } else {
            self.currentValue = nil
        }
    }
}
