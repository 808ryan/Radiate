# Radiate Optical Benchmark

[![CI](https://github.com/808ryan/Radiate/actions/workflows/ci.yml/badge.svg)](https://github.com/808ryan/Radiate/actions/workflows/ci.yml)

Radiate is an offline, screen-to-camera transfer experiment for a Mac and an
iPhone. This first milestone deliberately does **not** transfer files. It
measures the optical channel on real hardware so later encryption, error
correction, and file framing can be designed around evidence rather than an
assumed bitrate.

The Mac renders a deterministic black-and-white data grid. The iPhone detects
the screen, decodes the grid, recreates the expected pseudo-random payload, and
reports:

- detected and valid logical frames per second;
- raw optical bitrate;
- bit error rate (BER); and
- verified goodput after observed bit errors.

No network API is used by either target.

## Prerequisites

- A Mac with Xcode 16 or newer
- An Apple Developer account configured in Xcode
- XcodeGen (`brew install xcodegen`)
- An iPhone connected to Xcode and placed in Developer Mode

## Generate and run

```sh
xcodegen generate
open RadiateBenchmark.xcodeproj
```

In Xcode:

1. Select your development team for both app targets.
2. Run `RadiateMac` on the Mac.
3. Run `RadiateReceiver` on the connected iPhone.
4. Open the transmitter window, make it full screen, and select the same
   profile on both devices.
5. Hold the iPhone in landscape so the complete white screen border is visible,
   tap **Detect screen**, and then tap **Start benchmark** on the Mac.

See [docs/HARDWARE_TEST.md](docs/HARDWARE_TEST.md) for the repeatable test
procedure and [docs/BENCHMARK_PROTOCOL.md](docs/BENCHMARK_PROTOCOL.md) for the
wire format.

## Downloadable builds

GitHub Actions compiles both targets and provides an unsigned Mac app for every
successful CI run. A separate release workflow can produce a Developer ID-signed
and Apple-notarized DMG after its protected signing secrets are configured. See
[docs/RELEASING.md](docs/RELEASING.md) for the distinction and one-time setup.

## Current scope

This is a research harness, not a secure file-transfer release. It intentionally
contains no file picker, file persistence, encryption, or recovery code yet.
Those features should be built only after the benchmark identifies a reliable
grid density and frame rate.

## License

Radiate is available under the [MIT License](LICENSE).
