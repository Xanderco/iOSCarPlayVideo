import PhotosUI
import SwiftUI
import UIKit

private struct FeedbackScreenshot: Identifiable {
    let id = UUID()
    let image: UIImage
}

public struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var category: FeedbackCategory = .bug
    @State private var messageText: String = ""
    @State private var contactInfo: String = ""
    @State private var includeDiagnostics: Bool = true
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var screenshots: [FeedbackScreenshot] = []
    @State private var isLoadingPhotos: Bool = false

    @State private var showingInfoAlert: Bool = false
    @State private var showingDiagnosticsPreview: Bool = false
    @State private var showingMailOpenedAlert: Bool = false
    @State private var showingShareSheet: Bool = false
    @State private var shareItems: [Any] = []
    @State private var errorMessage: String?

    private let maxScreenshots = 9

    public init() {}

    private var trimmedMessage: String {
        messageText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isMessageValid: Bool {
        trimmedMessage.count >= 10
    }

    private var diagnosticSnapshot: SupportDiagnosticSnapshot {
        SupportDiagnosticsBuilder.captureCurrent()
    }

    private var diagnosticReport: String {
        SupportDiagnosticsBuilder.buildReport(from: diagnosticSnapshot)
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.dcBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        headerSection
                        categorySection
                        messageSection
                        contactSection
                        screenshotsSection
                        diagnosticsSection

                        Color.clear.frame(height: 112)
                    }
                    .padding(.horizontal, 16)
                }

                bottomActionBar
            }
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.dcAccent)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingInfoAlert = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.dcAccent)
                    }
                    .accessibilityLabel("Feedback Policy")
                }
            }
            .onChange(of: selectedPhotoItems) { _, items in
                guard !items.isEmpty else { return }
                Task { await loadPickedPhotos(items) }
            }
            .sheet(isPresented: $showingDiagnosticsPreview) {
                DiagnosticsPreviewSheet(report: diagnosticReport)
            }
            .sheet(isPresented: $showingShareSheet) {
                ActivityShareSheet(items: shareItems)
            }
            .alert("Mail App Opened", isPresented: $showingMailOpenedAlert) {
                Button("Done", role: .cancel) { dismiss() }
            } message: {
                Text("Finish sending your feedback in the Mail app. Thank you for helping improve DashCast.")
            }
            .alert("Feedback Policy", isPresented: $showingInfoAlert) {
                Button("Got it", role: .cancel) {}
            } message: {
                Text("DashCast never collects telemetry automatically. Diagnostics contain zero URLs, tokens, or personal info and are only included when you send or share them.")
            }
            .alert("Unable to Export", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tell us what's wrong")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.dcTextPrimary)

            Text("Bugs, missing widgets, sound requests — we read every message.")
                .font(.system(size: 13))
                .foregroundStyle(Color.dcTextSecondary)
        }
        .padding(.top, 10)
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Topic")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.dcTextPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FeedbackCategory.allCases) { item in
                        let selected = item == category
                        Button {
                            category = item
                        } label: {
                            Text(item.localizedTitle)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(selected ? Color.dcOnAccent : Color.dcTextSecondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(selected ? Color.dcAccent : Color.dcSurface)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(selected ? Color.dcAccent : Color.dcStroke, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 2) {
                Text("Your message")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.dcTextPrimary)
                Text("*")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.dcDanger)
            }

            ZStack(alignment: .topLeading) {
                if messageText.isEmpty {
                    Text("Describe what happened, and what you expected.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.dcTextTertiary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }

                TextEditor(text: $messageText)
                    .font(.system(size: 14))
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(Color.dcTextPrimary)
                    .padding(10)
                    .frame(minHeight: 120)
                    .accessibilityIdentifier("Feedback_MessageEditor")
            }
            .background(Color.dcSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.dcStroke, lineWidth: 1))

            Text("At least 10 characters (\(min(trimmedMessage.count, 10))/10)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isMessageValid ? Color.dcSuccess : Color.dcWarning)
        }
    }

    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How to reach you")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.dcTextPrimary)

            TextField("Email or phone number (optional)", text: $contactInfo)
                .font(.system(size: 14))
                .padding(14)
                .background(Color.dcSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.dcStroke, lineWidth: 1))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("Feedback_ContactField")
        }
    }

    private var screenshotsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Screenshots")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.dcTextPrimary)
                Spacer()
                if isLoadingPhotos {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color.dcAccent)
                }
                Text("\(screenshots.count)/\(maxScreenshots)")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dcTextTertiary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(screenshots) { shot in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: shot.image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.dcStroke, lineWidth: 1)
                                )

                            Button {
                                screenshots.removeAll { $0.id == shot.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.white, Color.black.opacity(0.75))
                            }
                            .offset(x: 5, y: -5)
                            .accessibilityLabel("Remove screenshot")
                        }
                        .padding(.top, 5)
                        .padding(.trailing, 5)
                    }

                    if screenshots.count < maxScreenshots {
                        let remaining = max(1, maxScreenshots - screenshots.count)
                        PhotosPicker(
                            selection: $selectedPhotoItems,
                            maxSelectionCount: remaining,
                            matching: .images
                        ) {
                            VStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.dcAccent)
                                Text("Add")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.dcAccent)
                            }
                            .frame(width: 72, height: 72)
                            .background(Color.dcSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.dcAccent.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                            )
                        }
                        .accessibilityIdentifier("Feedback_AddScreenshotButton")
                        .padding(.top, 5)
                    }
                }
            }
        }
    }

    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $includeDiagnostics) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Include anonymous diagnostics")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.dcTextPrimary)
                    Text("App version, OS, plan tier & playlist count (no URLs, tokens, or personal info).")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dcTextSecondary)
                }
            }
            .tint(Color.dcAccent)
            .accessibilityIdentifier("Feedback_DiagnosticsToggle")

            Divider().background(Color.dcSeparator)

            Button {
                showingDiagnosticsPreview = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.dcAccent)
                    Text("Preview Diagnostic Report")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.dcAccent)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.dcTextTertiary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("Feedback_PreviewDiagnosticsButton")
        }
        .padding(14)
        .background(Color.dcSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.dcStroke, lineWidth: 1))
    }

    private var bottomActionBar: some View {
        HStack(spacing: 10) {
            Button {
                sendViaMail()
            } label: {
                HStack(spacing: 6) {
                    Text("Send via Mail")
                        .font(.system(size: 15, weight: .bold))
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 13))
                }
                .foregroundStyle(isMessageValid ? Color.dcOnAccent : Color.dcTextSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    isMessageValid
                        ? LinearGradient.dcAccentGradient
                        : LinearGradient(colors: [Color.dcSurfaceRaised, Color.dcSurfaceRaised], startPoint: .top, endPoint: .bottom)
                )
                .clipShape(Capsule())
                .shadow(color: isMessageValid ? Color.dcAccent.opacity(0.35) : Color.clear, radius: 10, y: 4)
            }
            .disabled(!isMessageValid)
            .accessibilityIdentifier("Feedback_SendMailButton")

            Button {
                presentShareBundle()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.dcAccent)
                    .frame(width: 50, height: 50)
                    .background(Color.dcSurface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.dcStroke, lineWidth: 1))
            }
            .accessibilityLabel("Share Report & Screenshots")
            .accessibilityIdentifier("Feedback_ShareBundleButton")
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .padding(.top, 8)
        .background(
            LinearGradient(
                colors: [Color.dcBackground.opacity(0), Color.dcBackground.opacity(0.95), Color.dcBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Actions

    @MainActor
    private func loadPickedPhotos(_ items: [PhotosPickerItem]) async {
        isLoadingPhotos = true
        defer {
            selectedPhotoItems = []
            isLoadingPhotos = false
        }

        for item in items {
            guard screenshots.count < maxScreenshots else { break }
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                screenshots.append(FeedbackScreenshot(image: image))
            }
        }
    }

    @MainActor
    private func sendViaMail() {
        let snapshot = diagnosticSnapshot
        let report = includeDiagnostics ? SupportDiagnosticsBuilder.buildReport(from: snapshot) : nil
        guard let mailtoURL = SupportDiagnosticsBuilder.buildMailtoURL(
            recipient: LegalLinks.supportEmail,
            category: category,
            appVersion: snapshot.appVersion,
            message: trimmedMessage,
            contactInfo: contactInfo,
            diagnosticReport: report,
            screenshotCount: screenshots.count
        ) else {
            presentShareBundle()
            return
        }

        openURL(mailtoURL) { accepted in
            if accepted {
                showingMailOpenedAlert = true
            } else {
                // Simulator or devices without a configured Mail client fall back directly to the system Share Sheet.
                presentShareBundle()
            }
        }
    }

    @MainActor
    private func presentShareBundle() {
        let report = includeDiagnostics ? diagnosticReport : nil
        let composeBody = SupportDiagnosticsBuilder.buildComposeBody(
            category: category,
            message: trimmedMessage.isEmpty ? "DashCast Support Request" : trimmedMessage,
            contactInfo: contactInfo,
            diagnosticReport: report,
            screenshotCount: screenshots.count
        )

        var items: [Any] = [composeBody]
        if let report {
            do {
                let fileURL = try SupportDiagnosticsBuilder.exportReportFile(report: report)
                items.append(fileURL)
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        }

        for shot in screenshots {
            items.append(shot.image)
        }

        shareItems = items
        showingShareSheet = true
    }
}

private struct DiagnosticsPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let report: String

    @State private var exportedURL: URL?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.dcBackground.ignoresSafeArea()

                ScrollView {
                    Text(report)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color.dcTextPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color.dcSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.dcStroke, lineWidth: 1))
                        .padding(16)
                }
            }
            .navigationTitle("Diagnostic Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.dcAccent)
                }

                if let exportedURL {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(
                            item: exportedURL,
                            subject: Text("DashCast Diagnostic Report"),
                            message: Text("Redacted on-device DashCast diagnostics")
                        ) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(Color.dcAccent)
                        }
                    }
                }
            }
            .onAppear {
                exportedURL = try? SupportDiagnosticsBuilder.exportReportFile(report: report)
            }
        }
    }
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
