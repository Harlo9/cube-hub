#!/bin/bash
# Builds "Cube Hub.app" into build/ and launches it.
# Usage: ./build.sh                build + (re)launch
#        ./build.sh --no-run       build only
#        ./build.sh --universal    also for Intel Macs (slower)
#        ./build.sh --release      the downloadable app (Scripts/package.sh): universal, ad hoc
#                                  signature (no personal certificate in it), no Sons/ files
#        (options can be combined)
set -euo pipefail
cd "$(dirname "$0")"

RUN=1
UNIVERSAL=0
RELEASE=0
for arg in "$@"; do
    case "$arg" in
        --no-run) RUN=0 ;;
        --universal) UNIVERSAL=1 ;;
        --release) RELEASE=1; UNIVERSAL=1 ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

APP="build/Cube Hub.app"   # the folder name is the name shown by the Dock and Finder
STAMP="Resources/Frames/.stamp"

# 1. Reduced cube frames: regenerated only when an original (or the script) changed.
if [ ! -f "$STAMP" ] || [ -n "$(find Assets Scripts/make_frames.swift -newer "$STAMP" -print -quit)" ]; then
    echo "→ Generating reduced frames…"
    swift Scripts/make_frames.swift
    touch "$STAMP"
fi

# Signing identity: the "Apple Development" certificate if there is one, so the app keeps
# the same identity from one build to the next (macOS then remembers the permission to
# drive Terminal). Otherwise an ad-hoc signature ("-"), and macOS may ask again after a build.
# (`|| true`: finding none is not an error, e.g. on GitHub's Macs.)
SIGN_ID="$(security find-identity -v -p codesigning 2>/dev/null | grep -m1 "Apple Development" | awk '{print $2}' || true)"
SIGN_ID="${SIGN_ID:--}"
# The downloadable app is never signed with your certificate: its name (and Apple ID) would
# be in the signature.
if [ "$RELEASE" = 1 ]; then SIGN_ID="-"; fi

# 2. Compile the app and cube-hook (the program run by the Claude Code hooks).
echo "→ Compiling…"
if [ "$UNIVERSAL" = 1 ]; then
    # One build per processor (Apple Silicon, Intel), then `lipo` puts both into one
    # program. (`swift build --arch arm64 --arch x86_64` fails with SwiftTerm's plugin.)
    BIN_DIR=".build/universal"
    mkdir -p "$BIN_DIR"
    for arch in arm64 x86_64; do
        swift build -c release --triple "$arch-apple-macosx14.0" --product CubeWidget
        swift build -c release --triple "$arch-apple-macosx14.0" --product cube-hook
    done
    for product in CubeWidget cube-hook; do
        lipo -create -output "$BIN_DIR/$product" \
            ".build/arm64-apple-macosx/release/$product" ".build/x86_64-apple-macosx/release/$product"
    done
else
    swift build -c release --product CubeWidget
    swift build -c release --product cube-hook
    BIN_DIR="$(swift build -c release --show-bin-path)"
fi

# 3. Assemble the .app bundle (a .app is just a folder with a fixed layout).
# Quit the running app first, and wait until it is gone. Found with `ps`: `pkill` sees
# no process from some shells (Claude Code's sandbox), and `open` would then only bring
# back the old app, still running the old code.
# With --no-run, the running app is left alone (it keeps its code until it is relaunched).
OLD_PIDS="$(ps -axo pid=,comm= | awk '/\.app\/Contents\/MacOS\/CubeWidget$/ {print $1}')"
if [ "$RUN" = 1 ] && [ -n "$OLD_PIDS" ]; then
    kill $OLD_PIDS 2>/dev/null || true
    for _ in $(seq 30); do kill -0 $OLD_PIDS 2>/dev/null || break; sleep 0.1; done
fi
rm -rf "$APP" build/CubeWidget.app   # also the app's former name
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Helpers"
cp "$BIN_DIR/CubeWidget" "$APP/Contents/MacOS/"
# cube-hook ships inside the app; at launch, the app copies it to ~/.cube-widget/bin, where
# the hooks of ~/.claude/settings.json find it (App/HookProgram.swift).
cp "$BIN_DIR/cube-hook" "$APP/Contents/Helpers/"
cp Resources/Info.plist "$APP/Contents/"
# The version shown in Finder ("À propos"): the VERSION file, the only place to change it.
# The build number counts the commits (always goes up).
VERSION="$(tr -d '[:space:]' < VERSION)"
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"
cp -R Resources/Frames "$APP/Contents/Resources/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"   # made by Scripts/make_icon.sh
rm -f "$APP/Contents/Resources/Frames/.stamp"
# Sounds: your own files of Sons/ (not in the repository) go into the app. Without them,
# the app plays macOS's own sounds where they are (Sound/SoundPlayer.swift): they belong to
# Apple, so they are never copied into the app. Only real sound files are copied.
SOUNDS="$APP/Contents/Resources/Sons"
mkdir -p "$SOUNDS"
# (Not in the downloadable app: the Mixkit sound and copies of macOS sounds are not ours to share.)
if [ -d Sons ] && [ "$RELEASE" = 0 ]; then
    find Sons -maxdepth 1 -type f \( -name '*.aiff' -o -name '*.wav' -o -name '*.mp3' -o -name '*.m4a' \) \
        -exec cp {} "$SOUNDS/" \;
fi

# 4. Signature (required by macOS to run the app on Apple Silicon). Errors are shown:
#    the first time, macOS may ask to let codesign use the certificate ("Always Allow").
#    The program inside the app first, then the app (which seals everything it contains).
codesign --force --sign "$SIGN_ID" "$APP/Contents/Helpers/cube-hook"
codesign --force --sign "$SIGN_ID" "$APP"

echo "✓ Built $APP"
if [ "$RUN" = 1 ]; then
    open "$APP"
    echo "✓ Launched"
fi
