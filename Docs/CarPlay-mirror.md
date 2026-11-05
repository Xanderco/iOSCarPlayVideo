# CarPlay: mirror iPhone to the car screen

> Section for `Docs/CarPlay.md` (that file lives on `claude/ci-and-core-fixes`; this branch is based on `claude/car-video-output`, which predates it — paste this in when merging). Full rationale: ADR-002 §7.

## Entitlement to request

- **Request:** CarPlay **Video App** entitlement — <https://developer.apple.com/contact/carplay/>, category "Video". Copy the exact key from the granted provisioning profile into `DashCast/DashCast.entitlements` (expected `com.apple.developer.carplay-video`; verify). Do **not** combine with Audio (not allowed since iOS 27.2).
- **Do not request** `com.apple.developer.carplay-maps` (Navigation): it is the only entitlement that hands an app a drawable `CPWindow`, but Apple only grants it to turn-by-turn apps.
- Justification text: ADR-002 §7.3 (ready to paste).

## How it works in code

Broadcast extension → `MirrorFrameWriter` (app-group file, 2 seqlocked slots) → app `MirrorFrameReader` polled at 15 Hz → `CarPlayMirrorRendererView` (`AVSampleBufferDisplayLayer`) inside the `CPWindow` when iOS provides one. Parked-only via `ParkedGuard` → `CarCastShared.isVehicleMoving()`. Flag: `carMirror.enabled` in the app-group defaults (toggle "Mirror to CarPlay screen (beta)").

## Testing without a car

CarPlay Simulator (Additional Tools for Xcode). The window path is only exercised with an entitlement that grants a window; otherwise check the Cast tab → "Mirror iPhone" information template.
