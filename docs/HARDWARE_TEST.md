# Hardware test procedure

## First run

1. Generate the project with XcodeGen and open it in Xcode.
2. In **Signing & Capabilities**, choose your Apple Developer team for
   `RadiateMac` and `RadiateReceiver`. Change the example bundle identifiers if
   your team requires unique identifiers.
3. Connect the iPhone by cable, enable Developer Mode when prompted, trust the
   Mac, and run `RadiateReceiver` directly from Xcode.
4. Run `RadiateMac`. Open the transmitter and use its toolbar control or the
   green window button to enter full screen.
5. Set both apps to **Safe**. Before starting the benchmark, point the iPhone at
   the screen in landscape and keep the complete white border in view.
6. Tap **Detect Screen** on the iPhone while the Mac shows the static calibration
   border. Once it reports calibration, start the benchmark from either the Mac
   control window or the transmitter toolbar.

If the receiver never reports valid frames, stop the Mac benchmark, detect the
static border again, and restart. Make sure both devices show the same profile.

## Controlled baseline

For the first useful comparison:

- set Mac brightness to 75%;
- turn off True Tone, Night Shift, and automatic brightness on both devices;
- place the phone approximately 35–45 cm from the display;
- keep the camera close to perpendicular to the panel;
- avoid strong reflections and direct sunlight; and
- let each run continue for at least 30 seconds.

Run profiles in this order: Safe, Balanced, Aggressive, Stretch. Re-detect the
screen after every profile change.

Record the final values:

| Profile | Distance | Angle | Valid fps | BER | Raw MB/s | Verified MB/s | Notes |
|---|---:|---:|---:|---:|---:|---:|---|
| Safe | | | | | | | |
| Balanced | | | | | | | |
| Aggressive | | | | | | | |
| Stretch | | | | | | | |

## Interpreting the result

A promising result is not simply the largest raw number. Prefer the densest
profile that sustains roughly 55–60 unique frames/s with a stable BER below
`0.01%` in ordinary indoor lighting. The minimum project target is more than
`0.5 MB/s` of raw payload with errors low enough for practical forward-error
correction. The ambitious target is `1–2 MB/s` raw.

If Safe works but denser profiles fail, the next engineering step is better
localization and multi-sample/soft-decision decoding. If all profiles show
horizontal bands or alternating bad frames, tune display/camera phase and
symbol hold duration before increasing density.

## Privacy scope of this build

The benchmark never opens a file and never creates a network connection. It
renders generated test bits only. That makes it appropriate for evaluating the
optical channel without exposing an actual workbook. A future Radiate transfer
will still need an explicit threat model: optical transport removes a network
inspection point such as Zscaler, but it cannot hide the source file from
software already controlling or monitoring the Mac endpoint.

## Private iPhone installation

Running from Xcode installs the app only on your registered device and does not
publish it. For installation without an attached development session, archive
the iOS target and export an Ad Hoc IPA signed for registered device UDIDs.
Both routes require Developer Mode; neither makes the app public in the App
Store. Re-signing/reinstallation is expected when the provisioning profile or
certificate expires.
