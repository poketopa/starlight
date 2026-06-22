# Starlight

Starlight is a native macOS menu bar utility that dims distracting windows while keeping the active and recently used apps visible.

## Current scope

- Active and recent apps stay bright; background windows are dimmed.
- Configurable dimming intensity, color, animation duration, and recent app count.
- Menu bar icon with double-click toggle.
- Global shortcut: Control Option Command F.
- Multi-display overlay windows.
- Accessibility permission onboarding for better window tracking.
- Direct distribution scripts for Developer ID signing and notarization.

## Development

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
scripts/build-app.sh
open dist/Starlight.app
```

Direct notarized distribution is documented in [docs/distribution.md](docs/distribution.md).
