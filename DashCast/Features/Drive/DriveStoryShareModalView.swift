import SwiftUI
import UIKit

/// Modal view presenting an interactive 9:16 preview of the Drive Summary Card and native share controls.
public struct DriveStoryShareModalView: View {
    @Environment(\.dismiss) private var dismiss
    public let trip: TripModel
    public let vehicle: VehicleModel?

    @StateObject private var renderer = DriveSummaryCardRendererService.shared
    @State private var renderedImage: UIImage?
    @State private var isPreparingImage: Bool = true
    @State private var showShareSheet: Bool = false
    @State private var toastMessage: String?
    @State private var showToast: Bool = false

    public init(trip: TripModel, vehicle: VehicleModel? = nil) {
        self.trip = trip
        self.vehicle = vehicle
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                VStack(spacing: 20) {
                    // Header Bar
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Share Drive Story")
                                .font(ThemeFonts.hudTitle(size: 22))
                                .foregroundStyle(Color.dashTextPrimary)

                            Text("1080x1920 Instagram Story & TikTok Ready")
                                .font(ThemeFonts.hudCaption(size: 12))
                                .foregroundStyle(Color.dashYellow)
                        }

                        Spacer()

                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(Color.dashTextSecondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)

                    // 9:16 Story Card Preview Container
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.dashSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Color.dashYellow.opacity(0.5), lineWidth: 2)
                                    .shadow(color: Color.dashYellow.opacity(0.3), radius: 10)
                            )

                        if let image = renderedImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(9/16, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 22))
                        } else {
                            // Loading state
                            VStack(spacing: 16) {
                                ProgressView()
                                    .tint(Color.dashYellow)
                                    .scaleEffect(1.5)

                                Text("Rendering 1080x1920 Story Card...")
                                    .font(ThemeFonts.hudCaption(size: 13))
                                    .foregroundStyle(Color.dashTextSecondary)
                            }
                        }
                    }
                    .frame(maxHeight: 460)
                    .padding(.horizontal, 24)

                    // Action Controls
                    VStack(spacing: 12) {
                        // Primary Share Button
                        Button(action: {
                            guard renderedImage != nil else { return }
                            showShareSheet = true
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "square.and.arrow.up.fill")
                                    .font(.system(size: 18, weight: .bold))
                                Text("Share to Stories & Apps")
                                    .font(ThemeFonts.hudStat(size: 17))
                            }
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color.dashYellow, Color.dashGold],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color.dashYellow.opacity(0.4), radius: 8, y: 3)
                        }
                        .disabled(isPreparingImage || renderedImage == nil)
                        .opacity(renderedImage == nil ? 0.6 : 1.0)

                        // Secondary Options Row
                        HStack(spacing: 14) {
                            // Save to Photos
                            Button(action: saveImageToPhotos) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.down.circle.fill")
                                    Text("Save Photo")
                                }
                                .font(ThemeFonts.hudCaption(size: 14))
                                .foregroundStyle(Color.dashTextPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.dashSurfaceHighlight)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.dashBorder, lineWidth: 1))
                            }
                            .disabled(renderedImage == nil)

                            // Copy Summary Stats
                            Button(action: copySummaryText) {
                                HStack(spacing: 8) {
                                    Image(systemName: "doc.on.doc.fill")
                                    Text("Copy Stats")
                                }
                                .font(ThemeFonts.hudCaption(size: 14))
                                .foregroundStyle(Color.dashTextPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.dashSurfaceHighlight)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.dashBorder, lineWidth: 1))
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }

                // Toast Notification Overlay
                if showToast, let msg = toastMessage {
                    VStack {
                        Spacer()
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.dashGreen)
                            Text(msg)
                                .font(ThemeFonts.hudCaption(size: 14))
                                .foregroundStyle(Color.white)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#1F232E"))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.dashBorder, lineWidth: 1))
                        .shadow(radius: 10)
                        .padding(.bottom, 100)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .task {
                await generateCardImage()
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = renderedImage {
                    let cardData = DriveSummaryCardData(trip: trip, vehicle: vehicle)
                    let text = "DashCast In-Car Telemetry • Score: \(trip.drivingScore) (\(cardData.badgeTier.title)) • Top Speed: \(cardData.formattedTopSpeed) • #DashCastDriver"
                    let source = DriveSummaryActivityItemSource(
                        title: "DashCast Drive Summary (\(cardData.badgeTier.title))",
                        message: text,
                        image: image
                    )
                    ShareSheetView(activityItems: [source, image, text])
                }
            }
        }
    }

    private func generateCardImage() async {
        isPreparingImage = true
        let image = await renderer.renderStoryCard(from: trip, vehicle: vehicle)
        self.renderedImage = image
        self.isPreparingImage = false
    }

    private func saveImageToPhotos() {
        guard let image = renderedImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        triggerToast("Saved to Photos!")
    }

    private func copySummaryText() {
        let cardData = DriveSummaryCardData(trip: trip, vehicle: vehicle)
        let summary = """
        🚗 DashCast Drive Summary
        • Smoothness Score: \(trip.drivingScore)/100 (\(cardData.badgeTier.title))
        • Distance: \(cardData.formattedDistance)
        • Duration: \(cardData.formattedDuration)
        • Top Speed: \(cardData.formattedTopSpeed)
        • Peak G-Force: \(cardData.formattedPeakG)
        • Verified via Apple CarPlay // dashcast.app
        """
        UIPasteboard.general.string = summary
        triggerToast("Stats copied to clipboard!")
    }

    private func triggerToast(_ message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showToast = false
            }
        }
    }
}
