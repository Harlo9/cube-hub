import SwiftUI

/// The speaker of the Hub's toolbar: shows the general volume of the cube's sounds, and
/// opens a small bubble (a popover) with its slider and the "Sons de l'app" switch.
/// Same settings as Réglages → Sons.
struct HubVolumeButton: View {
    @ObservedObject var sounds: SoundSettings
    @State private var isOpen = false

    var body: some View {
        Button { isOpen.toggle() } label: {
            Label("Volume des sons", systemImage: symbol)
        }
        .help("Volume des sons du cube")
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            VolumePopover(sounds: sounds)
        }
    }

    /// Crossed out when the sounds are off or at 0 %, then 1, 2 or 3 waves.
    private var symbol: String {
        let volume = sounds.masterVolume
        guard sounds.isEnabled, volume > 0 else { return "speaker.slash.fill" }
        let waves = 1 + Constants.Hub.volumeIconThresholds.filter { volume >= $0 }.count
        return "speaker.wave.\(waves).fill"
    }
}

private struct VolumePopover: View {
    @ObservedObject var sounds: SoundSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Volume des sons").font(.headline)
                Spacer()
                Text("\(Int((sounds.masterVolume * 100).rounded())) %")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                Slider(value: Binding(get: { Double(sounds.masterVolume) },
                                      set: { sounds.masterVolume = Float($0) }),
                       in: 0...1) { isEditing in
                    // Once released, a sound at the new volume (even if the sounds are off,
                    // like the ▶ buttons of Réglages → Sons).
                    guard !isEditing else { return }
                    SoundPlayer.preview(.taskCompleted,
                                        volume: SoundSettings.volume(of: .taskCompleted) * sounds.masterVolume)
                }
                Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
            }
            Divider()
            Toggle("Sons de l'app", isOn: $sounds.isEnabled)
                .toggleStyle(.switch)
        }
        .padding(14)
        .frame(width: Constants.Hub.volumePopoverWidth)
    }
}
