# Building and releasing Radiate

Radiate has two GitHub Actions workflows:

- **CI** compiles both Apple targets, runs the shared protocol tests, and
  uploads an unsigned Mac app on pushes, pull requests, and manual runs.
- **Release macOS** creates a Developer ID-signed and Apple-notarized DMG. It
  runs manually or for tags beginning with `v`.

## CI artifact

Open the repository's **Actions** tab, choose a successful **CI** run, and
download `Radiate-macOS-unsigned-…` from the Artifacts section. The ZIP contains
`Radiate.app`.

This is a real executable build, but it is intentionally unsigned. Gatekeeper
may block or strongly warn about it after download. It is useful for compile
validation and local experimentation, not polished distribution.

## One-time signed release setup

The release workflow keeps compilation separate from the job that receives
signing credentials. Configure a GitHub environment named `release`, enable a
required-reviewer rule if your plan supports it, and add these environment
secrets:

| Secret | Contents |
|---|---|
| `MACOS_CERTIFICATE_BASE64` | Base64 text of a Developer ID Application `.p12` export |
| `MACOS_CERTIFICATE_PASSWORD` | Password chosen while exporting the `.p12` |
| `APPLE_NOTARY_KEY_BASE64` | Base64 text of the App Store Connect API `.p8` key |
| `APPLE_NOTARY_KEY_ID` | App Store Connect API key ID |
| `APPLE_NOTARY_ISSUER_ID` | App Store Connect API issuer ID |

Create a **Developer ID Application** certificate in the Apple Developer
portal, install it and its private key in Keychain Access, and export that
identity as a password-protected `.p12` file. Create a suitable App Store
Connect API key for notarization separately.

On macOS, encode each binary credential without opening it in a text editor:

```sh
base64 -i DeveloperIDApplication.p12 | pbcopy
base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
```

Paste the clipboard into the corresponding GitHub secret. Never commit either
credential, its base64 representation, or its password.

## Produce a download

For a manual test release, open **Actions → Release macOS → Run workflow**. The
notarized DMG appears under that run's Artifacts section.

For a durable GitHub Release:

```sh
git tag v0.1.0
git push origin v0.1.0
```

The workflow signs `Radiate.app`, places it in `Radiate-macOS.dmg`, submits the
DMG to Apple's notary service, staples the ticket, and attaches the finished DMG
to the GitHub Release.

## iPhone receiver

CI compiles the iPhone receiver against the simulator SDK to catch source
errors, but that artifact cannot be installed on a physical iPhone. A physical
device build must be signed with an iOS development or Ad Hoc distribution
profile containing the device's registered UDID.

For the benchmark phase, installing directly from Xcode is the shortest route.
An Ad Hoc IPA workflow can be added later without publishing the receiver in
the App Store; its distribution certificate and provisioning profile would use
the same protected-environment pattern as the Mac release credentials.
