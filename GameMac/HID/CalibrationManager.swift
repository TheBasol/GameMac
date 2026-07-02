import Foundation

public final class CalibrationManager {
    public static let shared = CalibrationManager()
    
    public struct CalibrationEntry: Codable, Hashable {
        public var min: Int
        public var max: Int
        
        public init(min: Int, max: Int) {
            self.min = min
            self.max = max
        }
    }
    
    // Dict format: [layoutKey: [usageStringRepresentationOfInt: CalibrationEntry]]
    private var calibrations: [String: [String: CalibrationEntry]] = [:]
    private let fileManager = FileManager.default
    private let lock = NSLock()
    
    private var calibrationSettingsURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("GameMac/calibration_settings.json")
    }
    
    private init() {
        loadCalibrations()
    }
    
    public func getCalibration(layoutKey: String, usage: Int) -> CalibrationEntry? {
        lock.lock()
        defer { lock.unlock() }
        return calibrations[layoutKey]?[String(usage)]
    }
    
    public func saveCalibration(layoutKey: String, usage: Int, min: Int, max: Int) {
        lock.lock()
        if calibrations[layoutKey] == nil {
            calibrations[layoutKey] = [:]
        }
        calibrations[layoutKey]?[String(usage)] = CalibrationEntry(min: min, max: max)
        lock.unlock()
        saveToFile()
    }
    
    public func removeCalibration(layoutKey: String, usage: Int) {
        lock.lock()
        calibrations[layoutKey]?[String(usage)] = nil
        lock.unlock()
        saveToFile()
    }
    
    private func loadCalibrations() {
        let url = calibrationSettingsURL
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            calibrations = try JSONDecoder().decode([String: [String: CalibrationEntry]].self, from: data)
        } catch {
            // Fail silently or log error
        }
    }
    
    private func saveToFile() {
        let url = calibrationSettingsURL
        let dir = url.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        do {
            lock.lock()
            let data = try JSONEncoder().encode(calibrations)
            lock.unlock()
            try data.write(to: url, options: .atomic)
        } catch {
            // Fail silently or log error
        }
    }
}
