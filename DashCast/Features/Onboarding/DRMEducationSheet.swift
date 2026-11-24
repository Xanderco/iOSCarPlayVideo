import SwiftUI

/// Educational and diagnostic sheet explaining CarPlay video casting limitations,
/// why commercial DRM (Netflix, Disney+, etc.) cannot cast to car screens, and providing
/// an interactive stream inspector to verify user links.
public struct DRMEducationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var inspector = DRMCompatibilityInspector.shared
    @State private var inputUrl: String = ""
    @State private var selectedSampleId: String? = nil
    @State private var showingTestAlert: Bool = false
    @State private var alertMessage: String = ""

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dcBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        heroHeader
                        comparisonMatrixSection
                        whyCarPlayBlocksDRMCard
                        interactiveDiagnosticSection
                        quickTestSamplesSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("CarPlay Video & DRM Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.dashYellow)
                }
            }
            .alert("Diagnostic Result", isPresented: $showingTestAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    // MARK: - 1. Hero Header

    private var heroHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.dashYellow.opacity(0.12))
                    .frame(width: 72, height: 72)

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.dashYellow)
            }

            Text("What Streams to Your Car?")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Color.dcTextPrimary)
                .multilineTextAlignment(.center)

            Text("Understand why personal media plays seamlessly while Netflix and Disney+ show black screens on CarPlay.")
                .font(.system(size: 15))
                .foregroundStyle(Color.dcTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
    }

    // MARK: - 2. Comparison Matrix

    private var comparisonMatrixSection: some View {
        VStack(spacing: 14) {
            // Supported Streams Card
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.dashGreen)
                        .font(.system(size: 18))
                    Text("Supported in Your Car (While Parked)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.dcTextPrimary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    matrixRow(icon: "server.rack", title: "Personal Media Servers", detail: "Jellyfin, Emby, Plex home library streaming")
                    matrixRow(icon: "list.bullet.rectangle.fill", title: "IPTV & M3U8 Playlists", detail: "Public & personal streaming channels without encryption")
                    matrixRow(icon: "film.stack.fill", title: "Local Videos & Photos", detail: "iPhone recordings, dashcam clips, direct MP4/MOV")
                    matrixRow(icon: "globe", title: "Web Video Embeds", detail: "Direct web player streaming without DRM restrictions")
                }
            }
            .padding(16)
            .background(Color.dcSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.dashGreen.opacity(0.3), lineWidth: 1.5)
            )

            // Restricted Streams Card
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.octagon.fill")
                        .foregroundStyle(Color.dashRed)
                        .font(.system(size: 18))
                    Text("Blocked by Apple & Commercial DRM")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.dcTextPrimary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    matrixRow(icon: "lock.fill", title: "Netflix, Disney+, Prime Video, Hulu, Max", detail: "Mandate FairPlay/Widevine encryption that blocks external displays")
                    matrixRow(icon: "tv.slash.fill", title: "Hardware Black Screen Protection", detail: "Apple AVFoundation blacklists video output to unauthenticated head-units")
                    matrixRow(icon: "exclamationmark.triangle.fill", title: "Legal & Architectural Policy", detail: "No App Store app can bypass Apple's FairPlay HDCP pipeline")
                }
            }
            .padding(16)
            .background(Color.dcSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.dashRed.opacity(0.3), lineWidth: 1.5)
            )
        }
    }

    private func matrixRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.dashYellow)
                .frame(width: 20)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.dcTextPrimary)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dcTextSecondary)
            }
        }
    }

    // MARK: - 3. Educational Explanation Card

    private var whyCarPlayBlocksDRMCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(Color.dashBlue)
                Text("Why does this happen?")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.dcTextPrimary)
            }

            Text("Commercial services like Netflix encrypt video keys with FairPlay. When an iPhone connects to CarPlay (which acts as an external secondary display over USB or Wi-Fi), Apple's graphics compositor enforces HDCP protection.\n\nBecause in-car displays do not possess Hollywood-certified hardware decoders, Apple's OS intentionally draws a black canvas to prevent screen recording. DashCast gives you full control over your unencrypted media, playlists, and servers while remaining 100% compliant with Apple App Store safety rules.")
                .font(.system(size: 13))
                .foregroundStyle(Color.dcTextSecondary)
                .lineSpacing(3)
        }
        .padding(16)
        .background(Color.dcSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - 4. Interactive Diagnostic Section

    private var interactiveDiagnosticSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(Color.dashYellow)
                Text("Live Stream Inspector")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.dcTextPrimary)
            }

            Text("Paste any stream address below to diagnose its codecs, encryption status, and CarPlay compatibility.")
                .font(.system(size: 13))
                .foregroundStyle(Color.dcTextSecondary)

            // Input field
            HStack(spacing: 8) {
                TextField("Enter video URL or .m3u8 link...", text: $inputUrl)
                    .font(.system(size: 14))
                    .padding(12)
                    .background(Color.dcBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(Color.dcTextPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                if !inputUrl.isEmpty {
                    Button {
                        inputUrl = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.dcTextSecondary)
                    }
                }

                Button("Paste") {
                    if let string = UIPasteboard.general.string {
                        inputUrl = string
                        runDiagnostic(for: string)
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(Color.dcSurface)
                .foregroundStyle(Color.dashYellow)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Inspect Button
            Button {
                runDiagnostic(for: inputUrl)
            } label: {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Inspect Stream Compatibility")
                }
                .font(.system(size: 15, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(inputUrl.isEmpty ? Color.gray.opacity(0.3) : Color.dashYellow)
                .foregroundStyle(inputUrl.isEmpty ? Color.gray : Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(inputUrl.isEmpty)

            // Diagnostic Result Card
            if let result = inspector.lastResult {
                resultCard(result: result)
            }
        }
        .padding(16)
        .background(Color.dcSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func resultCard(result: DRMInspectionResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider().background(Color.gray.opacity(0.3))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.streamType.rawValue)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.dcTextPrimary)
                    Text(result.drmProtectionDescription)
                        .font(.system(size: 12))
                        .foregroundStyle(result.isCarPlayCompatible ? Color.dashGreen : Color.dashRed)
                }

                Spacer()

                Text(result.isCarPlayCompatible ? "CarPlay Ready" : "Restricted")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(result.isCarPlayCompatible ? Color.dashGreen.opacity(0.2) : Color.dashRed.opacity(0.2))
                    .foregroundStyle(result.isCarPlayCompatible ? Color.dashGreen : Color.dashRed)
                    .clipShape(Capsule())
            }

            // Codec details
            VStack(alignment: .leading, spacing: 4) {
                Text("Detected Video / Audio Codecs:")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.dcTextPrimary)
                HStack(spacing: 6) {
                    ForEach(result.detectedCodecs, id: \.self) { codec in
                        Text(codec)
                            .font(.system(size: 11))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.dcBackground)
                            .foregroundStyle(Color.dcTextSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            // Explanation
            Text(result.educationalNotice)
                .font(.system(size: 12))
                .foregroundStyle(Color.dcTextSecondary)
                .lineSpacing(2)

            // Recommendation
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.dashYellow)
                    .padding(.top, 2)
                Text(result.resolutionRecommendation)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.dashYellow)
            }
        }
    }

    // MARK: - 5. Quick Test Reference Samples

    private var quickTestSamplesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("1-Tap Diagnostic Reference Tests")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.dcTextPrimary)

            Text("Tap a pre-configured sample stream to test how the diagnostic engine handles clean vs protected streams.")
                .font(.system(size: 12))
                .foregroundStyle(Color.dcTextSecondary)

            VStack(spacing: 8) {
                ForEach(inspector.sampleStreams) { sample in
                    Button {
                        selectedSampleId = sample.id
                        inputUrl = sample.urlString
                        runDiagnostic(for: sample.urlString)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: sample.isDRMProtected ? "lock.fill" : "play.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(sample.isDRMProtected ? Color.dashRed : Color.dashGreen)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(sample.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.dcTextPrimary)
                                Text(sample.description)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.dcTextSecondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.dcTextSecondary)
                        }
                        .padding(12)
                        .background(selectedSampleId == sample.id ? Color.dashYellow.opacity(0.1) : Color.dcSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedSampleId == sample.id ? Color.dashYellow : Color.clear, lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Action

    private func runDiagnostic(for string: String) {
        guard !string.isEmpty else { return }
        let res = inspector.inspect(urlString: string)
        if res.isCarPlayCompatible {
            alertMessage = "Stream is compatible with CarPlay! Codecs: \(res.detectedCodecs.joined(separator: ", "))"
        } else {
            alertMessage = "Notice: \(res.drmProtectionDescription). \(res.educationalNotice)"
        }
        showingTestAlert = true
    }
}
