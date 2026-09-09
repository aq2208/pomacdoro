import Foundation

/// Which sound plays at the end of each kind of phase.
///
/// An empty name means silence, so "None" needs no separate case.
struct SoundChoice: Equatable, Sendable {
    var focusEnd: String
    var restEnd: String

    static let `default` = SoundChoice(focusEnd: "Glass", restEnd: "Hero")

    static let silent = ""

    func name(forEndOf phase: Phase) -> String {
        phase == .focus ? focusEnd : restEnd
    }
}

/// The sounds this Mac can play, gathered from the three places AppKit looks.
///
/// Scanning rather than hard coding the system list means a sound the user drops
/// into their own Sounds folder shows up in the picker too. No AppKit here, so
/// the list can be tested without a running app.
enum SoundLibrary {
    private static let searchPaths = [
        NSString(string: "~/Library/Sounds").expandingTildeInPath,
        "/Library/Sounds",
        "/System/Library/Sounds",
    ]

    /// Every playable sound name, silence first, then the rest alphabetically.
    static let available: [String] = [SoundChoice.silent] + names(in: searchPaths)

    static func names(in directories: [String], fileManager: FileManager = .default) -> [String] {
        var seen = Set<String>()
        var found: [String] = []
        for directory in directories {
            let contents = (try? fileManager.contentsOfDirectory(atPath: directory)) ?? []
            for file in contents {
                let name = (file as NSString).deletingPathExtension
                // Hidden files and duplicates across the three folders are skipped.
                guard !name.isEmpty, !name.hasPrefix("."), seen.insert(name).inserted else { continue }
                found.append(name)
            }
        }
        return found.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    static func label(for name: String) -> String {
        name.isEmpty ? "None" : name
    }

    /// Falls back to the default when a stored name no longer resolves, which
    /// happens if a sound the user chose has since been removed.
    static func resolve(_ name: String?, fallback: String) -> String {
        guard let name else { return fallback }
        if name == SoundChoice.silent { return name }
        return available.contains(name) ? name : fallback
    }
}
