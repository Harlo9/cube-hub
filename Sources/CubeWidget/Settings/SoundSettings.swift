import Foundation

/// Réglages → Sons: all the sounds on or off, and each sound's volume. Saved in the
/// app's settings; the volumes in `Constants.Sound` are the starting values.
///
/// The sounds are played on a background queue, so `SoundPlayer` reads the saved values
/// directly (`isOn`, `volume(of:)`), which is safe from any thread.
@MainActor
final class SoundSettings: ObservableObject {
    static let shared = SoundSettings()

    /// "Sons": off, the app plays nothing (the ▶ buttons of the page still do).
    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey) }
    }
    /// "Volume général", applied on top of each sound's volume: 0 (silent) to 1.
    @Published var masterVolume: Float {
        didSet { UserDefaults.standard.set(masterVolume, forKey: Self.masterKey) }
    }
    /// Volume of each sound, 0 (silent) to 1 (full, relative to the Mac's volume).
    @Published private(set) var volumes: [SoundPlayer.Sound: Float]

    private init() {
        isEnabled = Self.isOn
        masterVolume = Self.master
        volumes = Dictionary(uniqueKeysWithValues: SoundPlayer.Sound.allCases.map { ($0, Self.volume(of: $0)) })
    }

    func setVolume(_ volume: Float, of sound: SoundPlayer.Sound) {
        volumes[sound] = volume
        UserDefaults.standard.set(volume, forKey: Self.volumeKey(sound))
    }

    /// Back to the volumes of `Constants.Sound` (the general one too).
    func resetVolumes() {
        masterVolume = Constants.Sound.masterVolume
        for sound in SoundPlayer.Sound.allCases {
            UserDefaults.standard.removeObject(forKey: Self.volumeKey(sound))
            volumes[sound] = sound.defaultVolume
        }
    }

    // MARK: - Read by the player (any thread)

    nonisolated static var isOn: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    nonisolated static var master: Float {
        (UserDefaults.standard.object(forKey: masterKey) as? NSNumber)?.floatValue ?? Constants.Sound.masterVolume
    }

    nonisolated static func volume(of sound: SoundPlayer.Sound) -> Float {
        (UserDefaults.standard.object(forKey: volumeKey(sound)) as? NSNumber)?.floatValue ?? sound.defaultVolume
    }

    private nonisolated static let enabledKey = "soundsEnabled"
    private nonisolated static let masterKey = "soundMasterVolume"
    private nonisolated static func volumeKey(_ sound: SoundPlayer.Sound) -> String { "soundVolume.\(sound.rawValue)" }
}
