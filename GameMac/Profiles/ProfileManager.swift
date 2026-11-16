import Foundation
import os

/// A manager class that handles reading/writing profiles from/to JSON in `~/Library/Application Support/GameMac/Profiles/`.
public final class ProfileManager {
 public static let shared = ProfileManager()
 
 private let fileManager = FileManager.default
 
 /// The URL of the directory where profiles are stored.
 public var profilesDirectory: URL {
 let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
 return appSupport.appendingPathComponent("GameMac/Profiles", isDirectory: true)
 }
 
 private init() {
 createDirectoryIfNeeded()
 }
 
 /// Ensures that the profiles directory exists.
 public func createDirectoryIfNeeded() {
 let dir = profilesDirectory
 if !fileManager.fileExists(atPath: dir.path) {
 do {
 try fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
 AppLogger.default.info("Created profiles directory at \(dir.path)")
 } catch {
 AppLogger.default.error("Failed to create profiles directory: \(error.localizedDescription)")
 }
 }
 }
 
 /// Saves a profile to the profiles directory.
 /// - Parameter profile: The mapping profile to save.
 public func saveProfile(_ profile: MappingProfile) throws {
 createDirectoryIfNeeded()
 let filename = sanitizeFilename(profile.profileName)
 let fileURL = profilesDirectory.appendingPathComponent("\(filename).json")
 
 let encoder = JSONEncoder()
 encoder.outputFormatting = .prettyPrinted
 let data = try encoder.encode(profile)
 try data.write(to: fileURL, options: .atomic)
 AppLogger.default.info("Saved profile '\(profile.profileName)' to \(fileURL.path)")
 }
 
 /// Loads a profile with the specified name.
 /// - Parameter name: The name of the profile (e.g. "FPS Shooter" or its filename "fps_shooter").
 /// - Returns: The loaded mapping profile.
 public func loadProfile(named name: String) throws -> MappingProfile {
 let filename = sanitizeFilename(name)
 let fileURL = profilesDirectory.appendingPathComponent("\(filename).json")
 
 let data = try Data(contentsOf: fileURL)
 let decoder = JSONDecoder()
 let profile = try decoder.decode(MappingProfile.self, from: data)
 AppLogger.default.info("Loaded profile '\(profile.profileName)' from \(fileURL.path)")
 return profile
 }
 
 /// Lists all profiles stored in the profiles directory.
 /// - Returns: An array of mapping profiles.
 public func listProfiles() -> [MappingProfile] {
 createDirectoryIfNeeded()
 do {
 let files = try fileManager.contentsOfDirectory(at: profilesDirectory, includingPropertiesForKeys: nil)
 let jsonFiles = files.filter { $0.pathExtension.lowercased() == "json" }
 
 var profiles: [MappingProfile] = []
 for fileURL in jsonFiles {
 do {
 let data = try Data(contentsOf: fileURL)
 let profile = try JSONDecoder().decode(MappingProfile.self, from: data)
 profiles.append(profile)
 } catch {
 AppLogger.default.error("Error decoding profile from \(fileURL.lastPathComponent): \(error.localizedDescription)")
 }
 }
            return profiles.sorted {
                $0.profileName.localizedCaseInsensitiveCompare($1.profileName) == .orderedAscending
            }
        } catch {
            AppLogger.default.error("Failed to list profiles in \(self.profilesDirectory.path): \(error.localizedDescription)")
            return []
        }
    }

    /// Checks whether a profile with the given name or sanitized filename already exists.
    public func profileExists(named name: String) -> Bool {
        let filename = sanitizeFilename(name)
        let fileURL = profilesDirectory.appendingPathComponent("\(filename).json")
        if fileManager.fileExists(atPath: fileURL.path) {
            return true
        }
        return listProfiles().contains {
            $0.profileName.caseInsensitiveCompare(name) == .orderedSame
        }
    }

    /// Generates a non-colliding copy name (e.g., "FPS Shooter Copy", "FPS Shooter Copy 2").
    public func uniqueProfileName(base: String) -> String {
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstCandidate = "\(trimmed) Copy"
        if !profileExists(named: firstCandidate) {
            return firstCandidate
        }
        var index = 2
        while true {
            let candidate = "\(trimmed) Copy \(index)"
            if !profileExists(named: candidate) {
                return candidate
            }
            index += 1
        }
    }

    /// Renames a profile on disk and returns the updated model.
    public func renameProfile(_ profile: MappingProfile, to newName: String) throws -> MappingProfile {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let oldFilename = sanitizeFilename(profile.profileName)
        let newFilename = sanitizeFilename(trimmed)

        var updated = profile
        updated.profileName = trimmed
        try saveProfile(updated)

        if oldFilename != newFilename {
            try? deleteProfile(named: profile.profileName)
        }
        return updated
    }

    /// Restores the built-in default profiles to disk.
    public func restoreDefaultProfiles() throws {
        for profile in DefaultProfiles.all {
            try saveProfile(profile)
        }
    }
 
 /// Deletes the profile with the specified name.
 /// - Parameter name: The name of the profile.
 public func deleteProfile(named name: String) throws {
 let filename = sanitizeFilename(name)
 let fileURL = profilesDirectory.appendingPathComponent("\(filename).json")
 if fileManager.fileExists(atPath: fileURL.path) {
 try fileManager.removeItem(at: fileURL)
 AppLogger.default.info("Deleted profile '\(name)' at \(fileURL.path)")
 } else {
 AppLogger.default.warning("Attempted to delete profile '\(name)' but file did not exist at \(fileURL.path)")
 }
 }
 
 /// Sanitizes the profile name to make a safe filename.
 private func sanitizeFilename(_ filename: String) -> String {
 let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>: ")
 let clean = filename.components(separatedBy: invalidCharacters).joined(separator: "_")
 return clean.lowercased()
 }
}
