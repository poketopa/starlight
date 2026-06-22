# Design

## Source of truth
- Status: Draft
- Last refreshed: 2026-06-20
- Primary product surfaces: macOS menu bar utility, settings window, permission onboarding, screen dimming overlay.
- Evidence reviewed:
  - Empty repository at `/Users/lhs/Desktop/github/focus-trail`; no existing app code or design assets.
  - HazeOver official site: https://hazeover.com/
  - HazeOver help: https://hazeover.com/help.html
  - HazeOver automation guide: https://hazeover.com/automation.html
  - Mac App Store listing: https://apps.apple.com/us/app/hazeover-distraction-dimmer/id430798174

## Brand
- Personality: quiet, precise, native macOS utility; productivity-focused rather than playful.
- Trust signals: no analytics by default, clear permission rationale, signed/notarized builds, native system settings copy.
- Avoid: HazeOver trademarks, copied icons, copied screenshots, copied marketing copy, or indistinguishable UI.

## Product goals
- Goals:
  - Dim visual distractions while preserving the currently relevant work context.
  - Extend the HazeOver-style model by keeping the most recently used `n` apps bright instead of only the front app/window.
  - Provide a small, reliable menu bar utility with predictable settings.
  - Prioritize direct web/CLI distribution with Developer ID notarization before attempting Mac App Store release.
- Non-goals:
  - Do not clone HazeOver branding or assets.
  - Do not collect app/window usage analytics outside local settings/history needed for the feature.
  - Do not require cloud sync for the first release.
- Success signals:
  - User can set `recent app count` from 1 to a bounded maximum, and only those apps remain undimmed.
  - Dimming updates within 100 ms after normal app focus changes on supported macOS versions when Accessibility permission is granted.
  - App can be signed and distributed through at least one valid macOS channel.

## Personas and jobs
- Primary personas:
  - Mac power users working across many overlapping windows.
  - Developers, writers, researchers, designers, and presenters using large or multiple displays.
- User jobs:
  - Keep the active task visible without hiding needed reference apps.
  - Avoid typing into the wrong window.
  - Reduce background glare while keeping recent context readable.
- Key contexts of use:
  - Large external monitor, multiple displays, dark rooms, presentations, coding/research workflows.

## Information architecture
- Primary navigation: menu bar icon with quick toggles and settings entry.
- Core screens:
  - General: activation toggle, menu bar status, launch at login, dimming intensity.
  - Advanced/Focus: highlight mode, color, animation duration presets, recent app count.
  - Display: fixed policy that also highlights windows on displays without keyboard focus.
  - Shortcuts: toggle, increase intensity, decrease intensity.
  - Info: Accessibility status, privacy, version/distribution notes.
- Content hierarchy: quick controls first, advanced automation and per-app rules later.

## Design principles
- Principle 1: Native first. Use AppKit/SwiftUI controls that feel like macOS settings.
- Principle 2: Minimum interruption. The overlay must never steal focus or block clicks.
- Principle 3: Transparent privacy. Explain Accessibility permission and keep data local.
- Principle 4: Predictable dimming. If the user cannot infer why a window is bright or dim, the rule needs UI feedback.
- Principle 5: Korean-first MVP. Primary user-facing copy should be Korean, with native macOS terms where possible.
- Tradeoffs:
  - Accurate per-window dimming needs Accessibility permission; fallback mode can be less precise but should still work.
  - Recent-app highlighting is more useful than single-window focus, but it requires clear recency and exclusion rules.
  - `n = 1` should prefer a HazeOver-style z-order overlay placed behind the highlighted window, avoiding visible cutout tracking during drags.
  - `n >= 2` may require a hybrid mask/cutout strategy because arbitrary recent windows are not guaranteed to be contiguous in window z-order.
  - In coordinate/mask mode, exact non-rectangular window curves, shadows, and custom app chrome cannot be guaranteed from public window bounds alone; approximate with rounded masks.

## Visual language
- Color: neutral macOS palette with user-selectable dim color.
- Typography: system font, compact settings layout.
- Spacing/layout rhythm: System Settings-like form sections, dense but readable.
- Shape/radius/elevation: native controls; no decorative card-heavy UI.
- Motion: preset fade durations: off, 0.3s, 0.5s, 1s, 3s.
- Imagery/iconography: original menu bar symbol; use SF Symbols where appropriate.
- Menu bar icon color: use template images so macOS renders the icon as white on dark menu bars and dark on light menu bars. Avoid forcing white globally because it breaks light-mode contrast.

## Components
- Existing components to reuse: none; empty repo.
- New/changed components:
  - Menu bar controller.
  - Menu bar quick controls with activation toggle, percent-only intensity slider, and single/multiple app segmented control.
  - Tabbed settings window.
  - Permission onboarding panel.
  - Recent-app count control.
  - Focus mode selector: one window vs all windows for highlighted apps.
  - Application scope selector: one app vs multiple apps, with a small delay note for multiple-app mode.
  - Display policy summary for per-display recent highlighting.
  - Shortcut rows for toggle and intensity changes.
  - Overlay debug view for development builds.
- Variants and states:
  - Enabled, disabled, permission missing, fallback mode, multi-display active.
  - Light/Dark appearance-specific settings.
- Token/component ownership: store design constants in app settings model; avoid introducing a custom design system unless the app grows.

## Accessibility
- Target standard: keyboard navigable settings, VoiceOver labels, sufficient contrast in settings UI.
- Keyboard/focus behavior: global shortcuts for toggle, intensity up, and intensity down must be visible in the Shortcuts tab.
- Contrast/readability: dimming should not reduce brightness of highlighted apps/windows.
- Screen-reader semantics: settings controls must have labels and help text.
- Reduced motion and sensory considerations: support instant transitions and low-intensity presets.

## Responsive behavior
- Supported breakpoints/devices: macOS desktop/laptop windows; settings window should fit 13-inch laptop screens.
- Layout adaptations: single settings window with sidebar or tabs depending on final framework choice.
- Touch/hover differences: not applicable beyond pointer/trackpad and menu bar scroll gesture.

## Interaction states
- Loading: app should launch directly to menu bar without blocking UI.
- Empty: no windows focused means reveal desktop or apply a clear fallback.
- Error: permission missing, screen recording/accessibility denial, and unavailable APIs get actionable messages.
- Success: settings changes apply immediately and persist.
- Disabled: menu bar icon reflects dimming off state.
- Offline/slow network: not applicable for first release.

## Content voice
- Tone: concise, factual, calm, Korean-first.
- Terminology: "최근 앱", "디밍 강도", "강조할 창", "제외 앱", "메뉴 막대".
- Microcopy rules: state what will happen, not how the internals work.

## Implementation constraints
- Framework/styling system: Swift, AppKit for window/overlay control, SwiftUI acceptable for settings panes.
- Design-token constraints: use system colors and controls first.
- Performance constraints:
  - Avoid polling as the main update path; use workspace/accessibility notifications where possible.
  - Overlay redraw should be bounded by display count and visible target window count.
  - Multi-display selection must apply recent highlighting per display, not only globally.
  - Basic one-window mode must not draw a rectangle cutout over the highlighted window; it should place the dimming overlay below the target window by window id.
- Compatibility constraints:
  - Initial target: macOS 13+ unless implementation evidence suggests macOS 12 is worth supporting.
  - Accessibility permission needed for high-accuracy window tracking.
  - Direct distribution requires Developer ID signing and notarization; this is the first distribution target.
  - Mac App Store distribution is a later target and requires App Store signing/review constraints.
- Test/screenshot expectations:
  - Unit tests for recent-app history and rules.
  - Manual/e2e smoke tests on single display, multi-display, full-screen apps, Mission Control, Stage Manager, and permission-denied mode.

## Open questions
- [x] Final app name: Starlight.
- [ ] Final bundle identifier / owner: placeholder is `com.lhs.Starlight`; replace before public signing if needed.
- [x] Initial distribution channel: direct notarized web/CLI download first, Mac App Store later.
- [x] Initial `n` behavior: active and recently focused apps remain bright.
- [x] Initial bright-window behavior: all visible windows belonging to recent apps remain bright.
- [x] Automation scope: not v1; revisit after core overlay and direct distribution are stable.
- [x] Settings UX direction: Korean tabbed preferences inspired by HazeOver structure, with original layout/copy.
- [x] Display policy: always highlight windows on displays without keyboard focus; choose recent targets per display.
