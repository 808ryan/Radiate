# Optical benchmark protocol

## Purpose

This protocol measures the physical screen-to-camera channel before Radiate
adds compression, authenticated encryption, forward-error correction, or file
reassembly. Every payload bit is reproducible from its frame sequence number,
which lets the iPhone calculate the true bit error rate without receiving a
reference copy over another channel.

## Geometry

The Mac renders against a black background:

- a white rectangular locator border;
- a data rectangle inset 4% from each edge of the transmitter view;
- six header rows at the top of the data rectangle; and
- deterministic payload cells in the remaining rows.

The receiver detects the locator with Vision, calculates a projective
homography from the camera quadrilateral to the logical grid, and precomputes
one luma-plane sample location per cell. It does not allocate an RGB image for
each camera frame.

| Profile | Grid | Payload bits/frame | Payload bytes/frame | Raw at 60 symbols/s |
|---|---:|---:|---:|---:|
| Safe | 256 × 160 | 39,424 | 4,928 | 295,680 B/s |
| Balanced | 384 × 240 | 89,856 | 11,232 | 673,920 B/s |
| Aggressive | 512 × 320 | 160,768 | 20,096 | 1,205,760 B/s |
| Stretch | 640 × 400 | 252,160 | 31,520 | 1,891,200 B/s |

These are raw test payload rates, not promised file-transfer rates. A production
protocol will spend capacity on framing, authenticated encryption, error
correction, and recovery symbols.

## Frame timing

The transmitter requests a 120 Hz Metal draw loop and holds each logical frame
for two display refreshes. The target is therefore 60 distinct symbols per
second. The receiver also requests its best 120 fps camera format at 1080p or
higher. It reads the sequence header to count distinct frames; duplicate camera
captures do not inflate throughput.

Neither requested rate is assumed to have been achieved. The iPhone reports
the observed unique-frame rate.

## Header

The first six grid rows carry the same 80-bit header. Each header bit is also
repeated across three adjacent columns, producing 18 luma samples per bit.
Majority voting recovers one logical header bit.

| Field | Width | Value |
|---|---:|---|
| Magic | 16 bits | `0x5244` (`RD`) |
| Version | 8 bits | `1` |
| Profile | 8 bits | Profile ID 1–4 |
| Sequence | 32 bits | Increments per logical frame |
| Check | 16 bits | Folded header checksum |

All fields are transmitted most-significant bit first. The lightweight check is
only for rejecting a bad benchmark header; it is not a cryptographic integrity
mechanism.

## Payload

For a zero-based payload cell index `i`, both devices calculate the same 32-bit
mix from `sequence + i × 0x9E3779B9`. The low bit is displayed. Arithmetic wraps
at 32 bits. The exact avalanche constants live in `PRBS.swift` and
`OpticalGrid.metal`, with known values covered by the unit tests.

## Metrics

- **Valid fps**: unique, checksum-valid sequences divided by elapsed time.
- **BER**: incorrect deterministic payload bits divided by all tested bits.
- **Raw**: unique frames × payload bytes divided by elapsed time.
- **Verified**: completely error-free frames × payload bytes divided by elapsed
  time. This is intentionally stricter than `raw × (1 − BER)`.

The later file-transfer layer will use forward-error correction, so BER and
frame-loss measurements are more useful than error-free rate alone.

## Known first-build limitations

- Screen geometry is detected once; moving either device requires detection
  again.
- The initial threshold is a clamped mean from approximately 4,096 payload
  samples. Adaptive per-region thresholds may outperform it under glare.
- The locator-to-data inset is calibrated to the current rendered border. If
  Vision chooses a different edge of the border on hardware, the decoder will
  need an edge-refinement pass or explicit corner fiducials.
- Rolling-shutter phase, display response, autofocus behavior, and thermal
  throttling are intentionally left for measurement rather than guessed away.
