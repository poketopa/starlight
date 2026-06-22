# Distribution

## First target: direct web or CLI download

The first release target is a Developer ID signed and notarized `.app` packaged as a `.zip`. This is the path that prevents normal Gatekeeper warnings such as "cannot be opened because Apple cannot check it for malicious software" when users download from the web or install through a CLI.

Required local prerequisites:
- Full Xcode installed or command line tools with `notarytool`, `stapler`, `codesign`, and `ditto`.
- Apple Developer Program membership.
- A Developer ID Application certificate installed in the login keychain.
- An app-specific password for notarization, or an equivalent keychain profile if the script is later adapted.

Build locally with ad-hoc signing:

```sh
scripts/build-app.sh
open dist/Starlight.app
```

Build, sign, notarize, staple, and package:

```sh
export DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)"
export APPLE_ID="you@example.com"
export APPLE_TEAM_ID="TEAMID"
export APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
scripts/notarize-direct.sh
```

Output:

```text
dist/Starlight.zip
```

## Later target: Mac App Store

The App Store path should be handled after the direct distribution build works reliably. The likely next steps are:

- Add an Xcode project or generate one from the SwiftPM package.
- Configure App Store signing with the Apple distribution certificate/profile.
- Revisit sandbox and entitlement requirements.
- Prepare App Store Connect metadata, screenshots, privacy nutrition labels, support URL, and review notes explaining Accessibility usage.
- Submit to TestFlight or App Review.

