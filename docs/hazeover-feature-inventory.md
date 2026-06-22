# HazeOver Feature Inventory

This is a feature inventory from public HazeOver materials checked on 2026-06-20. It is for product planning only; the app in this repo should be an independent implementation with original branding, code, copy, and assets.

## Core behavior
- Runs in the background as a macOS utility.
- Highlights the active/front window or active app by dimming background windows.
- Adds a translucent dark layer behind the current working window.
- Updates automatically as the user switches windows/apps.
- Supports instant switching or smooth fade animation.
- Reveals the desktop when the desktop is used.

Sources: https://hazeover.com/, https://hazeover.com/help.html, https://apps.apple.com/us/app/hazeover-distraction-dimmer/id430798174

## Dimming controls
- Dimming intensity setting.
- Dimming color setting.
- Animation duration setting from instant to several seconds.
- Separate dimming settings for Light and Dark system appearances.
- Menu bar scroll gesture to adjust intensity; minimum intensity turns dimming off.

Sources: https://hazeover.com/, https://hazeover.com/help.html, https://hazeover.com/automation.html

## Toggle and shortcuts
- Menu bar icon access.
- Double-click menu bar icon to toggle dimming.
- Global keyboard shortcut to toggle dimming.
- Customizable keyboard shortcuts.
- Fn key temporarily disables dimming during drag and drop.

Sources: https://hazeover.com/, https://hazeover.com/help.html

## Multi-display support
- Can highlight the front window on each connected display.
- Can dim all secondary displays without keyboard focus.
- Can disable dimming on a specific display through secondary display settings.
- Helps identify which display currently has keyboard focus.

Sources: https://hazeover.com/, https://hazeover.com/help.html, https://hazeover.com/automation.html

## Accuracy and permissions
- Uses Accessibility permission optionally to improve dimming accuracy and responsiveness.
- Without ideal focus/window signals, focused-window detection may be less reliable.

Sources: https://hazeover.com/help.html

## Automation and integrations
- Shortcuts actions for state, settings, color, animation, intensity, highlight mode, secondary display mode, and refresh.
- Focus Filters can set intensity, on/off state, and color for a Focus mode.
- AppleScript properties/commands for enabled state, intensity, color, duration, multi-focus, multi-screen, and refresh.
- Third-party control through tools such as Raycast, Alfred, BetterTouchTool, and Keyboard Maestro.

Sources: https://hazeover.com/automation.html

## Distribution and metadata clues
- Current HazeOver public site states the current version requires macOS 12 Monterey or later.
- Mac App Store listing positions it as a paid Productivity app.
- App Store privacy label says the developer does not collect data.
- Recent version history mentions macOS Tahoe/Liquid Glass compatibility and improved accessibility support.

Sources: https://hazeover.com/, https://apps.apple.com/us/app/hazeover-distraction-dimmer/id430798174

## Differentiation candidates for this project
- Keep the most recently used `n` apps bright instead of only the front app/window.
- Per-app rules: always bright, always dim, never dim, ignore transient apps.
- Recency timeline in settings so users understand why apps are highlighted.
- Presets: Focus, Research, Presentation, Night.
- Optional dimming behavior for app groups, e.g. editor + browser + terminal.
- Better first-run diagnostics for Accessibility permission and unsupported window states.
