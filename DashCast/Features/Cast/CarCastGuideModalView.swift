import SwiftUI
import AVKit

/// Localized copy and step definitions for `CarCastGuideModalView`.
public enum CarCastGuideCopy {
    public struct MirrorStep: Equatable {
        nonisolated public let number: String
        nonisolated public let key: String

        nonisolated public init(number: String, key: String) {
            self.number = number
            self.key = key
        }

        @MainActor public var localizedKey: LocalizedStringKey {
            LocalizedStringKey(key)
        }
    }

    nonisolated public static let headerTitleString = "Cast Video to Car Display"
    nonisolated public static let headerSubtitleString = "Connect DashCast to your car's screen, CarPlay adapter, or in-dash browser while parked."
    nonisolated public static let airPlayTitleString = "1. AirPlay Direct Cast"
    nonisolated public static let airPlaySubtitleString = "Wireless video & audio to car screen"
    nonisolated public static let airPlayBodyString = "Stream your IPTV, YouTube, or local video directly to any AirPlay-compatible car screen or wireless CarPlay adapter."
    nonisolated public static let tapToConnectString = "Tap to connect:"
    nonisolated public static let detectingDisplaysString = "Detecting displays..."
    nonisolated public static let mirrorSectionTitleString = "2. Mirror Entire Screen"
    nonisolated public static let mirrorSectionSubtitleString = "Full iPhone display on car screen"
    nonisolated public static let mirrorControlCenterIntroString = "Apple requires system screen mirroring to be started from iOS Control Center:"
    nonisolated public static let mirrorStep1String = "Swipe down from the top-right corner of your iPhone to open Control Center."
    nonisolated public static let mirrorStep2String = "Tap the Screen Mirroring button (two overlapping rectangles)."
    nonisolated public static let mirrorStep3String = "Select your car's display, CarPlay dongle, or receiver."
    nonisolated public static let browserSectionTitleString = "3. In-Car Web Browser"
    nonisolated public static let browserSectionSubtitleString = "Tesla, Polestar, & aftermarket screens"
    nonisolated public static let browserSectionBodyString = "If your car has a built-in browser, connect your car to your iPhone's Personal Hotspot and open any video directly on the car's web browser."
    nonisolated public static let safetyNoticeString = "For your safety and in compliance with driving regulations, watch video content only while parked or during EV charging stops."
    nonisolated public static let navigationTitleString = "Car Display Setup"
    nonisolated public static let doneString = "Done"

    nonisolated public static let mirrorSteps: [MirrorStep] = [
        MirrorStep(number: "1", key: mirrorStep1String),
        MirrorStep(number: "2", key: mirrorStep2String),
        MirrorStep(number: "3", key: mirrorStep3String)
    ]

    nonisolated public static let allLocalizationKeys: [String] = [
        headerTitleString,
        headerSubtitleString,
        airPlayTitleString,
        airPlaySubtitleString,
        airPlayBodyString,
        tapToConnectString,
        detectingDisplaysString,
        mirrorSectionTitleString,
        mirrorSectionSubtitleString,
        mirrorControlCenterIntroString,
        mirrorStep1String,
        mirrorStep2String,
        mirrorStep3String,
        browserSectionTitleString,
        browserSectionSubtitleString,
        browserSectionBodyString,
        safetyNoticeString,
        navigationTitleString,
        doneString
    ]

    @MainActor public static var headerTitleKey: LocalizedStringKey { LocalizedStringKey(headerTitleString) }
    @MainActor public static var headerSubtitleKey: LocalizedStringKey { LocalizedStringKey(headerSubtitleString) }
    @MainActor public static var airPlayTitleKey: LocalizedStringKey { LocalizedStringKey(airPlayTitleString) }
    @MainActor public static var airPlaySubtitleKey: LocalizedStringKey { LocalizedStringKey(airPlaySubtitleString) }
    @MainActor public static var airPlayBodyKey: LocalizedStringKey { LocalizedStringKey(airPlayBodyString) }
    @MainActor public static var tapToConnectKey: LocalizedStringKey { LocalizedStringKey(tapToConnectString) }
    @MainActor public static var detectingDisplaysKey: LocalizedStringKey { LocalizedStringKey(detectingDisplaysString) }
    @MainActor public static var mirrorSectionTitleKey: LocalizedStringKey { LocalizedStringKey(mirrorSectionTitleString) }
    @MainActor public static var mirrorSectionSubtitleKey: LocalizedStringKey { LocalizedStringKey(mirrorSectionSubtitleString) }
    @MainActor public static var mirrorControlCenterIntroKey: LocalizedStringKey { LocalizedStringKey(mirrorControlCenterIntroString) }
    @MainActor public static var browserSectionTitleKey: LocalizedStringKey { LocalizedStringKey(browserSectionTitleString) }
    @MainActor public static var browserSectionSubtitleKey: LocalizedStringKey { LocalizedStringKey(browserSectionSubtitleString) }
    @MainActor public static var browserSectionBodyKey: LocalizedStringKey { LocalizedStringKey(browserSectionBodyString) }
    @MainActor public static var safetyNoticeKey: LocalizedStringKey { LocalizedStringKey(safetyNoticeString) }
    @MainActor public static var navigationTitleKey: LocalizedStringKey { LocalizedStringKey(navigationTitleString) }
    @MainActor public static var doneKey: LocalizedStringKey { LocalizedStringKey(doneString) }
}

public struct CarCastGuideModalView: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 6) {
                            Text(CarCastGuideCopy.headerTitleKey)
                                .font(ThemeFonts.hudTitle(size: 24))
                                .foregroundStyle(Color.dashTextPrimary)

                            Text(CarCastGuideCopy.headerSubtitleKey)
                                .font(ThemeFonts.hudCaption(size: 14))
                                .foregroundStyle(Color.dashTextSecondary)
                        }

                        // Method 1: Direct AirPlay Video Cast (Best Quality)
                        AutomotiveCard(cornerRadius: 18) {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.dashYellow.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "airplayvideo")
                                            .font(.system(size: 22))
                                            .foregroundStyle(Color.dashYellow)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(CarCastGuideCopy.airPlayTitleKey)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(Color.dashTextPrimary)
                                        Text(CarCastGuideCopy.airPlaySubtitleKey)
                                            .font(ThemeFonts.hudCaption(size: 12))
                                            .foregroundStyle(Color.dashTextSecondary)
                                    }

                                    Spacer()
                                }

                                Text(CarCastGuideCopy.airPlayBodyKey)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.dashTextSecondary)

                                HStack {
                                    Text(CarCastGuideCopy.tapToConnectKey)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.dashTextPrimary)

                                    AirPlayRoutePickerRepresentable()
                                        .frame(width: 44, height: 44)

                                    Spacer()

                                    Text(CarCastGuideCopy.detectingDisplaysKey)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.dashTextMuted)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.dashSurfaceHighlight)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        // Method 2: Mirror Entire iPhone Screen
                        AutomotiveCard(cornerRadius: 18) {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.dashGreen.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "rectangle.inset.filled.and.cursorarrow")
                                            .font(.system(size: 20))
                                            .foregroundStyle(Color.dashGreen)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(CarCastGuideCopy.mirrorSectionTitleKey)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(Color.dashTextPrimary)
                                        Text(CarCastGuideCopy.mirrorSectionSubtitleKey)
                                            .font(ThemeFonts.hudCaption(size: 12))
                                            .foregroundStyle(Color.dashTextSecondary)
                                    }

                                    Spacer()
                                }

                                Text(CarCastGuideCopy.mirrorControlCenterIntroKey)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.dashTextSecondary)

                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(CarCastGuideCopy.mirrorSteps, id: \.number) { step in
                                        stepRow(num: step.number, text: step.localizedKey)
                                    }
                                }
                                .padding(.leading, 4)
                            }
                        }

                        // Method 3: In-Car Web Browser Cast (Tesla, Android Auto, Head Units)
                        AutomotiveCard(cornerRadius: 18) {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.dashGold.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "globe")
                                            .font(.system(size: 22))
                                            .foregroundStyle(Color.dashGold)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(CarCastGuideCopy.browserSectionTitleKey)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(Color.dashTextPrimary)
                                        Text(CarCastGuideCopy.browserSectionSubtitleKey)
                                            .font(ThemeFonts.hudCaption(size: 12))
                                            .foregroundStyle(Color.dashTextSecondary)
                                    }

                                    Spacer()
                                }

                                Text(CarCastGuideCopy.browserSectionBodyKey)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.dashTextSecondary)
                            }
                        }

                        // Safety Notice
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.shield.fill")
                                .foregroundStyle(Color.dashOrange)
                                .font(.system(size: 20))

                            Text(CarCastGuideCopy.safetyNoticeKey)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.dashTextSecondary)
                        }
                        .padding()
                        .background(Color.dashOrange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding()
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle(CarCastGuideCopy.navigationTitleKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(CarCastGuideCopy.doneKey) {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.dashYellow)
                }
            }
        }
    }

    private func stepRow(num: String, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(num)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.dashGreen)
                .frame(width: 20, height: 20)
                .background(Color.dashGreen.opacity(0.2))
                .clipShape(Circle())

            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Color.dashTextPrimary)
        }
    }
}
