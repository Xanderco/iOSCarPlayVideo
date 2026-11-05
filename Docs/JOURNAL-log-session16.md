<!-- Paste at the top of the Log in Docs/JOURNAL.md (not present on this branch's base claude/car-video-output). -->
### 2026-11-05 00:50 (Bogotá) — Session 16: mirror iPhone onto the CarPlay screen (`claude/carplay-mirror`)
- Based on `claude/car-video-output` (PR #25). Feature flag `carMirror.enabled`, off by default.
- Extension → app transport: two-slot seqlocked JPEG file in the app group (`MirrorFrameTransport.swift`), unit-tested (`MirrorFrameTransportTests`).
- `CarPlayMirrorController`: `AVSampleBufferDisplayLayer` in the `CPWindow` when iOS provides one; instructions / "paused while moving" overlay; Cast tab "Mirror iPhone" info template as fallback.
- Entitlement: request **CarPlay Video App** (not Navigation). Justification text in ADR-002 §7.3. Owner action: submit the form.
- Not done: local HLS bridge so the mirror plays through the system video player (ADR-002 §7.5).

### 2026-11-05 01:15 (Bogotá) — Session 16b: DashCast on the CarPlay simulator
- `DashCast/DashCast-Simulator.entitlements` (carplay-audio + app group) via `CODE_SIGN_ENTITLEMENTS[sdk=iphonesimulator*]`; device entitlements stay CarPlay-free (CI guard).
- CarPlay tabs: Library, Favorites, Now Playing, Cast (mirror instructions as CPListTemplate — CPInformationTemplate is not allowed for audio apps).
- Owner action: request **CarPlay Audio** (`com.apple.developer.carplay-audio`); steps + justification in `Docs/CarPlay.md`.
- Merge note: `claude/ci-and-core-fixes` has a richer `CarPlaySceneDelegate` (PlaylistStore, Now Playing info). When merging keep that one and add: the Cast/mirror instructions tab and the two `CPWindow` delegate methods from this branch.
