# Changelog

What changes from one version of Cube Hub to the next. The newest version is at the top.

## [Unreleased]

### Changed
- The Hub's toolbar: a **Widget** button, in its own capsule, shows or hides the widget (it replaces the small cube button). White when the widget is shown, grey when it's hidden, never in the Mac's accent color.

### Fixed
- Clicking Cube Hub's icon in the Dock (or opening the app again from the Finder) now opens the Hub.

## [0.2.0] - 2026-11-18

The first version you can download: no need to build it yourself anymore.

### Added
- **A DMG to download** from the [Releases](https://github.com/Harlo9/cube-hub/releases) page, for Apple Silicon and Intel Macs.
- **Welcome window**: on first launch, Cube Hub offers to plug itself into Claude Code. It shows the exact lines it adds to `~/.claude/settings.json`, saves a copy of the file first, and leaves your other settings and hooks alone. Plug or unplug anytime in Réglages → Général.
- **General volume** of the cube's sounds: a speaker in the Hub's toolbar, and in Réglages → Sons.
- **`/clear`** on Telegram: clears the conversation with your bot (messages less than 48 hours old, a Telegram limit).
- An icon to **open a Terminal window** in the project's folder, right next to the Hub.
- **⌃⌥W** shows or hides the widget from any app, and a cube button in the Hub's toolbar does the same.

### Changed
- The `cube-hook` program now ships inside the app, which installs it in `~/.cube-widget/bin/` at launch.
- Sounds: the cube uses sounds that come with macOS, played right from your Mac. Put your own in `~/.cube-widget/Sons/`.
- The app is called **Cube Hub** everywhere, and the repository is now `cube-hub`.

## [0.1.0] - 2026-10-29

The first public version, to build yourself with `./build.sh`.

- The widget: your Claude Code sessions as cards, with an animated ice cube that shows when Claude works, waits for you, or is done.
- Cube Hub: one window with all your sessions, sorted by themes, with a real terminal per project.
- Telegram (optional): notifications when you're away, and answers from your phone, locked by a 6-digit code.
- The menu bar mini cube, the settings window, sounds.

[0.2.0]: https://github.com/Harlo9/cube-hub/releases/tag/v0.2.0
