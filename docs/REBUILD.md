# RAFLI 3.0 native rebuild

The old app booted VIP2 and carried nine generations of duplicate screens. This rebuild removes those screens, keeps the AVAssetReader/Writer pipeline, and introduces a focused native four-tab experience with explicit StudioState, local file import, persistent verified media, Photos add-only saving and system sharing.

Design references reviewed: [Apple HIG](https://developer.apple.com/design/human-interface-guidelines), [Apple typography](https://developer.apple.com/design/human-interface-guidelines/typography), [2025 Apple Design Awards](https://developer.apple.com/design/awards/2025/), [Tiimo’s SwiftUI migration](https://developer.apple.com/articles/tiimo/). Applied principles: content hierarchy, native controls, meaningful transitions, accessibility and restrained decoration. Original layouts; no copied product UI.

## Engine changes

- No upscaling. Canvas retains orientation/aspect within 1080×1920 or 1920×1080.
- Source timestamps preserved. Above 60 FPS, timestamp buckets select existing frames; no interpolation or duplication.
- Real read/encode progress, throttled to percentage changes. Passthrough/verification use indeterminate activity, not fabricated percentages.
- Mono remains mono; source audio converted to AAC 48 kHz, up to stereo. Audio setup failures are explicit.
- Verify actual output metadata, duration, audio presence, canvas, frame rate, and decode beginning/end frames before persistence.
- Originals and outputs persist with stable IDs and relative paths. Legacy folders are indexed in place. Temporary imports use file representations.

## Exact brand artwork restored

The user supplied the clean original JPEG after the audit found both old base64 assets corrupt. `RAFLI/Assets/RAFLILogo.original.jpeg` is a byte-identical copy of that attachment. Its original color, illustration, proportions and white border remain intact. Asset generation only converts to PNG and proportionally resizes the square artwork to 1024 for the app icon and 768 for in-app use. No crop, redraw, recoloring or extra image padding is applied. SwiftUI provides layout margins outside the image.

## Validation

GitHub Actions builds unsigned iphoneos Release IPA, then runs simulator pipeline and navigation tests. Test attachments contain actual app screenshots. Physical-device Photos permission, sharing targets, HEVC/HDR color fidelity and large-file stress testing remain device acceptance checks; do not infer those passed from simulator tests.

No in-app TikTok posting UI is exposed. Existing optional backend code is retained separately for a future configured official integration. The app uses the existing save engine and system share sheet.

## Current execution status

Source and workflow configuration checks passed locally. Xcode and iOS SDK are not installed in this Linux workspace. GitHub branch push was rejected by automatic approval review because explicit authorization to publish rebuilt code to the public repository was not established. No new CI run has started, no compiler/test success is claimed, and no IPA has been produced for this rebuild yet. Awaiting approval to push `rebuild/native-studio` to `anas1213231/RAFLI` and run its workflow.
