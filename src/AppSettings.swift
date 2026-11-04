import Foundation
import Combine

public class AppSettings: ObservableObject {
    public static let shared = AppSettings()
    
    private let defaults = UserDefaults.standard
    
    @Published public var dataSource: DataSourceType {
        didSet { defaults.set(dataSource.rawValue, forKey: "dataSource") }
    }
    
    @Published public var hubitatURL: String {
        didSet { defaults.set(hubitatURL, forKey: "hubitatURL") }
    }
    
    @Published public var hubitatDeviceID: String {
        didSet { defaults.set(hubitatDeviceID, forKey: "hubitatDeviceID") }
    }
    
    @Published public var hubitatMakerAppID: String {
        didSet { defaults.set(hubitatMakerAppID, forKey: "hubitatMakerAppID") }
    }
    
    @Published public var hubitatMakerToken: String {
        didSet { defaults.set(hubitatMakerToken, forKey: "hubitatMakerToken") }
    }
    
    @Published public var haURL: String {
        didSet { defaults.set(haURL, forKey: "haURL") }
    }
    
    @Published public var haToken: String {
        didSet { defaults.set(haToken, forKey: "haToken") }
    }
    
    @Published public var phaseAPowerEntity: String {
        didSet { defaults.set(phaseAPowerEntity, forKey: "phaseAPowerEntity") }
    }
    
    @Published public var phaseACurrentEntity: String {
        didSet { defaults.set(phaseACurrentEntity, forKey: "phaseACurrentEntity") }
    }
    
    @Published public var phaseAVoltageEntity: String {
        didSet { defaults.set(phaseAVoltageEntity, forKey: "phaseAVoltageEntity") }
    }
    
    @Published public var phaseBPowerEntity: String {
        didSet { defaults.set(phaseBPowerEntity, forKey: "phaseBPowerEntity") }
    }
    
    @Published public var phaseBCurrentEntity: String {
        didSet { defaults.set(phaseBCurrentEntity, forKey: "phaseBCurrentEntity") }
    }
    
    @Published public var phaseBVoltageEntity: String {
        didSet { defaults.set(phaseBVoltageEntity, forKey: "phaseBVoltageEntity") }
    }
    
    @Published public var totalPowerEntity: String {
        didSet { defaults.set(totalPowerEntity, forKey: "totalPowerEntity") }
    }
    
    @Published public var mainBreakerAmps: Double {
        didSet { defaults.set(mainBreakerAmps, forKey: "mainBreakerAmps") }
    }
    
    @Published public var defaultVoltage: Double {
        didSet { defaults.set(defaultVoltage, forKey: "defaultVoltage") }
    }
    
    @Published public var refreshInterval: Double {
        didSet { defaults.set(refreshInterval, forKey: "refreshInterval") }
    }
    
    @Published public var menuBarFormat: MenuBarFormat {
        didSet { defaults.set(menuBarFormat.rawValue, forKey: "menuBarFormat") }
    }
    
    @Published public var demoMode: Bool {
        didSet { defaults.set(demoMode, forKey: "demoMode") }
    }
    
    public init() {
        if let rawSource = defaults.string(forKey: "dataSource"),
           let ds = DataSourceType(rawValue: rawSource) {
            self.dataSource = ds
        } else {
            self.dataSource = .homeAssistant
        }
        
        self.hubitatURL = defaults.string(forKey: "hubitatURL") ?? "http://192.168.4.254"
        self.hubitatDeviceID = defaults.string(forKey: "hubitatDeviceID") ?? "693"
        self.hubitatMakerAppID = defaults.string(forKey: "hubitatMakerAppID") ?? ""
        self.hubitatMakerToken = defaults.string(forKey: "hubitatMakerToken") ?? ""
        
        self.haURL = defaults.string(forKey: "haURL") ?? "http://homeassistant.local:8123"
        self.haToken = defaults.string(forKey: "haToken") ?? ""
        self.phaseAPowerEntity = defaults.string(forKey: "phaseAPowerEntity") ?? ""
        self.phaseACurrentEntity = defaults.string(forKey: "phaseACurrentEntity") ?? ""
        self.phaseAVoltageEntity = defaults.string(forKey: "phaseAVoltageEntity") ?? ""
        self.phaseBPowerEntity = defaults.string(forKey: "phaseBPowerEntity") ?? ""
        self.phaseBCurrentEntity = defaults.string(forKey: "phaseBCurrentEntity") ?? ""
        self.phaseBVoltageEntity = defaults.string(forKey: "phaseBVoltageEntity") ?? ""
        self.totalPowerEntity = defaults.string(forKey: "totalPowerEntity") ?? ""
        
        let storedAmps = defaults.double(forKey: "mainBreakerAmps")
        self.mainBreakerAmps = storedAmps > 0 ? storedAmps : 200.0
        
        let storedVolt = defaults.double(forKey: "defaultVoltage")
        self.defaultVoltage = storedVolt > 0 ? storedVolt : 120.0
        
        let storedInterval = defaults.double(forKey: "refreshInterval")
        self.refreshInterval = storedInterval > 0 ? storedInterval : 3.0
        
        if let rawFormat = defaults.string(forKey: "menuBarFormat"),
           let format = MenuBarFormat(rawValue: rawFormat) {
            self.menuBarFormat = format
        } else {
            self.menuBarFormat = .both
        }
        
        if defaults.object(forKey: "demoMode") != nil {
            self.demoMode = defaults.bool(forKey: "demoMode")
        } else {
            // Default demoMode to true if no token is saved yet
            self.demoMode = (defaults.string(forKey: "haToken") ?? "").isEmpty
        }
    }
}
