<!-- Paste at the top of the Log in Docs/JOURNAL.md (not present on this branch's base claude/car-video-output). -->
### 2026-11-05 00:50 (Bogotá) — Session 16: mirror iPhone onto the CarPlay screen (`claude/carplay-mirror`)
- Based on `claude/car-video-output` (PR #25). Feature flag `carMirror.enabled`, off by default.
- Extension → app transport: two-slot seqlocked JPEG file in the app group (`MirrorFrameTransport.swift`), unit-tested (`MirrorFrameTransportTests`).
- `CarPlayMirrorController`: `AVSampleBufferDisplayLayer` in the `CPWindow` when iOS provides one; instructions / "paused while moving" overlay; Cast tab "Mirror iPhone" info template as fallback.
- Entitlement: request **CarPlay Video App** (not Navigation). Justification text in ADR-002 §7.3. Owner action: submit the form.
- Not done: local HLS bridge so the mirror plays through the system video player (ADR-002 §7.5).
