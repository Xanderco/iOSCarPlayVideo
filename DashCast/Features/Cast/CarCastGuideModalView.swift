import SwiftUI
import AVKit

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
                            Text("Cast Video to Car Display")
                                .font(ThemeFonts.hudTitle(size: 24))
                                .foregroundStyle(Color.dashTextPrimary)

                            Text("Connect DashCast to your car's screen, CarPlay adapter, or in-dash browser while parked.")
                                .font(ThemeFonts.hudCaption(size: 14))
                                .foregroundStyle(Color.dashTextSecondary)
                        }

                        // Method 1: Direct AirPlay Video Cast (Best Quality)
                        AutomotiveCard(cornerRadius: 18) {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.dashCyan.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "airplayvideo")
                                            .font(.system(size: 22))
                                            .foregroundStyle(Color.dashCyan)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("1. AirPlay Direct Cast")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(Color.dashTextPrimary)
                                        Text("Wireless video & audio to car screen")
                                            .font(ThemeFonts.hudCaption(size: 12))
                                            .foregroundStyle(Color.dashTextSecondary)
                                    }

                                    Spacer()
                                }

                                Text("Stream your IPTV, YouTube, or local video directly to any AirPlay-compatible car screen or wireless CarPlay adapter.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.dashTextSecondary)

                                HStack {
                                    Text("Tap to connect:")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.dashTextPrimary)

                                    AirPlayRoutePickerRepresentable()
                                        .frame(width: 44, height: 44)

                                    Spacer()

                                    Text("Detecting displays...")
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
                                        Text("2. Mirror Entire Screen")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(Color.dashTextPrimary)
                                        Text("Full iPhone display on car screen")
                                            .font(ThemeFonts.hudCaption(size: 12))
                                            .foregroundStyle(Color.dashTextSecondary)
                                    }

                                    Spacer()
                                }

                                Text("Apple requires system screen mirroring to be started from iOS Control Center:")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.dashTextSecondary)

                                VStack(alignment: .leading, spacing: 10) {
                                    stepRow(num: "1", text: "Swipe down from the top-right corner of your iPhone to open Control Center.")
                                    stepRow(num: "2", text: "Tap the Screen Mirroring button (two overlapping rectangles).")
                                    stepRow(num: "3", text: "Select your car's display, CarPlay dongle, or receiver.")
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
                                        Text("3. In-Car Web Browser")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(Color.dashTextPrimary)
                                        Text("Tesla, Polestar, & aftermarket screens")
                                            .font(ThemeFonts.hudCaption(size: 12))
                                            .foregroundStyle(Color.dashTextSecondary)
                                    }

                                    Spacer()
                                }

                                Text("If your car has a built-in browser, connect your car to your iPhone's Personal Hotspot and open any video directly on the car's web browser.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.dashTextSecondary)
                            }
                        }

                        // Safety Notice
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.shield.fill")
                                .foregroundStyle(Color.dashOrange)
                                .font(.system(size: 20))

                            Text("For your safety and in compliance with driving regulations, watch video content only while parked or during EV charging stops.")
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
            .navigationTitle("Car Display Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.dashCyan)
                }
            }
        }
    }

    private func stepRow(num: String, text: String) -> some View {
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
