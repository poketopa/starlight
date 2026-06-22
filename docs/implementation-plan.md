# Starlight Implementation Plan

## Requirements summary
- Build an independent macOS utility inspired by the HazeOver category: dim distractions and keep relevant work visible.
- Primary differentiator: keep the most recently viewed `n` apps bright.
- Start from an empty cloned repository.
- Proceed in phases: design, project creation/git setup, implementation, verification, distribution.
- User has an Apple Developer account.
- App name: Starlight.
- Distribution priority: direct Developer ID signed and notarized web/CLI download first; Mac App Store later if feasible.

## ADR
- Decision: Build a native macOS app in Swift using AppKit for overlay/window control and SwiftUI where it is sufficient for settings UI.
- Drivers:
  - Native overlay behavior needs precise control over non-activating windows, window levels, display changes, and event passthrough.
  - App Store/direct distribution both expect normal macOS signing and entitlement handling.
  - The recent-app feature needs reliable local state and fast focus-change updates.
- Alternatives considered:
  - Electron: faster UI scaffolding but weaker native overlay/window integration and heavier distribution footprint.
  - Pure SwiftUI app: simpler settings UI but insufficient direct control for overlay windows.
  - CLI/helper-only app: inadequate for menu bar settings, onboarding, and user trust.
- Why chosen: Swift + AppKit keeps the hardest surface, screen overlays and macOS permissions, close to platform APIs.
- Consequences:
  - More platform-specific code.
  - Manual QA across macOS versions and display modes is required.
  - Distribution can target both direct notarized builds and Mac App Store after review risks are evaluated.
- Follow-ups:
  - Replace placeholder bundle identifier `com.lhs.Starlight` before public release if the Apple Developer account uses a different reverse-DNS namespace.
  - Add Xcode project/archive workflow when App Store submission becomes the active target.

## Feature scope

### MVP
- Menu bar app with start-at-login option.
- Enable/disable dimming.
- Dimming intensity, color, and animation duration.
- Recent app count `n`, likely range 1-10.
- Recent-app history based on foreground app changes.
- Bright set rule: foreground app plus the previous `n - 1` app identities.
- Per-display bright set rule: each display may highlight up to its own recent `n` visible apps/windows.
- Per-display overlay windows that ignore mouse events.
- Accessibility permission onboarding for precise window frame tracking.
- App exclusion list for apps that should not affect recency or should never be dimmed.
- Local-only settings persistence.
- Direct build script for `.app` packaging.
- Developer ID notarization script for public web/CLI download.
- Korean-first menu and settings copy.
- Tabbed settings: General, Focus, Display, Shortcuts, Info.
- Shortcut actions for toggle, intensity up, and intensity down.

### Post-MVP
- Light/Dark appearance-specific dimming settings.
- Keyboard shortcuts.
- Menu bar scroll gesture for intensity.
- Multi-display policies: per-display focus vs dim inactive displays.
- Presets and app groups.
- Shortcuts/App Intents integration.
- AppleScript support.
- Focus Filter integration, if worth the complexity.

## Technical architecture

### Modules
- `StarlightApp`: app lifecycle, menu bar item, settings window.
- `SettingsStore`: persisted preferences and migration defaults.
- `FocusEventService`: foreground app and active window events through `NSWorkspace`, `AXObserver`, and fallback polling only where needed.
- `RecentAppTracker`: bounded MRU list of bundle identifiers/process IDs with exclusion rules.
- `WindowSnapshotService`: visible window/app frame snapshots using Accessibility and CoreGraphics APIs.
- `DimmingOverlayManager`: one non-activating overlay window per display.
- `OverlayRenderer`: dimming layer with transparent cutouts around bright app/window frames.
- `PermissionCoordinator`: Accessibility trust status, prompts, degraded-mode messaging.
- `Distribution`: signing, entitlements, notarization/App Store profiles.

### Overlay approach
- Use borderless, non-activating, click-through `NSPanel`/`NSWindow` instances at an appropriate window level per display.
- In basic one-window mode, place the dimming overlay below the target window using the target WindowServer window id, so the highlighted window is genuinely above the dimming layer.
- In multi-window/recent-app mode, render a dimming fill over the screen and cut transparent holes around target windows belonging to recent apps.
- Recompute target rectangles on app activation, window movement/resize events, display changes, Space changes, and settings changes.
- Known limitation: screen-level cutouts reveal whatever is behind the cutout rectangle, so overlapping target/non-target windows require careful testing and may need a fallback rule. The z-order path avoids this limitation only when there is a single target window per display.
- Known limitation: public window bounds do not expose every app's exact corner curve, live shadow, toolbar shape, or custom non-rectangular chrome. Coordinate/mask mode can approximate with rounded masks, but it cannot perfectly match all window silhouettes.

### Permissions and privacy
- High-accuracy mode requires Accessibility permission.
- Do not collect analytics in v1.
- Store only local preferences, excluded apps, and recent-app state needed for current behavior.
- Explain clearly why Accessibility access is needed.

## Implementation phases

1. Repository setup
   - Create Xcode project or Swift Package-backed app structure.
   - Add `.gitignore`, README, license placeholder, docs, CI skeleton if useful.
   - Establish bundle identifier, app name, deployment target, and signing team.

2. Native shell
   - Build menu bar app lifecycle.
   - Add settings UI with persistent preferences.
   - Add enable/disable state and start-at-login.

3. Focus and recency engine
   - Implement foreground app detection.
   - Implement MRU recent-app tracker and exclusion rules.
   - Unit test recency behavior.

4. Overlay engine
   - Add per-display click-through overlay.
   - Implement dimming fill, intensity/color/duration.
   - Add window frame collection and cutouts for recent apps.
   - Test single display and multi-display behavior.

5. Permission onboarding and degraded modes
   - Detect Accessibility permission status.
   - Prompt user and link to System Settings.
   - Provide fallback behavior when permission is absent.

6. Polish and expected HazeOver-category parity
   - Add keyboard shortcut.
   - Add menu bar scroll or quick intensity controls.
   - Add tabbed Korean settings UI.
   - Add focus mode selector.
   - Add fixed per-display highlight policy summary.

7. Verification
   - Unit tests for settings, MRU, exclusions, and overlay target selection.
   - Manual smoke tests for normal windows, minimized/closed windows, full screen, Mission Control, Stage Manager, multiple displays, sleep/wake, and permission denied.
   - Performance checks for CPU use while idle and while rapidly switching apps.

8. Distribution
   - Direct distribution path: Developer ID sign, archive, notarize, staple, create DMG/ZIP, verify Gatekeeper launch.
   - Mac App Store path: App Store signing, sandbox/entitlement review, App Store Connect metadata, screenshots, privacy nutrition labels, TestFlight if desired, App Review submission.
   - Keep direct distribution ready even if Mac App Store review requires changes.

## Acceptance criteria
- With `n = 1`, behavior matches active-app-only dimming semantics at a product level.
- With `n = 1` and one target window on a display, the overlay is ordered below that window rather than drawing a cutout rectangle.
- With `n = 3`, the three most recently focused non-excluded apps remain bright after focus switches.
- With `n = 3` and two displays, each display can highlight up to three visible recent apps/windows independently.
- Excluded apps do not enter recent history.
- Overlay never captures mouse/keyboard input.
- Settings changes apply without app restart.
- Menu bar quick UI includes an activation toggle and dimming intensity control.
- Menu bar quick UI uses a HazeOver-like top row: `Starlight` with an on/off switch, a percent-only intensity slider, then a one-app/multiple-app selector with a compact delay note.
- Settings window is organized into Korean tabs for General, Focus, Display, Shortcuts, and Info.
- Keyboard shortcuts can toggle dimming and adjust intensity.
- Accessibility permission missing state is visible and actionable.
- App launches after signing on a clean macOS user account.
- Distribution build is signed and notarized, or App Store/TestFlight upload succeeds for the selected channel.

## Risks and mitigations
- Risk: exact per-window dimming is hard under macOS Spaces/full-screen/Mission Control.
  - Mitigation: start with app-window rectangle cutouts, document limitations, add manual QA cases early.
- Risk: Mac App Store review may object to behavior, permissions, or sandbox constraints.
  - Mitigation: keep a notarized direct distribution path and use original branding/copy.
- Risk: Accessibility permission creates user trust friction.
  - Mitigation: local-only privacy posture, clear onboarding, useful fallback mode.
- Risk: overlay can interfere with presentations, screen sharing, or color-critical work.
  - Mitigation: quick toggle, presets, excluded apps, and per-display controls.
- Risk: HazeOver similarity creates IP/trademark/review risk.
  - Mitigation: implement category-level behavior independently, avoid names/assets/copy/trademarks, emphasize recent-app differentiation.

## Verification steps
- `swift test` or Xcode test action for logic modules.
- Xcode build/archive validation.
- Manual QA checklist across display and permission states.
- `codesign --verify` on exported app.
- `spctl --assess` after notarized export.
- App Store Connect validation if Mac App Store is selected.

## Stop condition for the next phase
- Initial SwiftPM/AppKit project exists and builds.
- Recent-app logic has tests.
- Direct distribution script exists and documents Developer ID notarization.
- Remaining release blocker: actual Developer ID certificate/account credentials and final bundle identifier.
