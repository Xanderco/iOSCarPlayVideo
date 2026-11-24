import SwiftUI

public struct EVSuperchargerMonitorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var manager = EVChargingSessionManager.shared

    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Top Station Preset Selector
                        stationPresetPicker

                        // Live Charging / Rest Stop Gauge Card
                        sessionGaugeCard

                        // Controls & Target Configuration
                        if manager.activePreset.isRestArea {
                            restStopSettingsCard
                        } else {
                            chargingSettingsCard
                        }

                        // Session Action Button (Start / Stop)
                        sessionActionButton

                        // Parked Video Streaming Banner (Deep-link to Cast)
                        parkedVideoStreamBanner
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .padding(.bottom, 60)
                }
            }
            .navigationTitle("EV Supercharger & Rest Stop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color.dashYellow)
                    .fontWeight(.semibold)
                }
            }
            .onReceive(timer) { _ in
                if manager.isSessionActive {
                    manager.tickSimulation(elapsedSeconds: 1)
                }
            }
        }
    }

    // MARK: - Station Presets Picker

    private var stationPresetPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("STATION PRESET")
                .font(ThemeFonts.hudCaption(size: 11))
                .foregroundStyle(Color.dashTextSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(EVStationPreset.allCases) { preset in
                        let isSelected = manager.activePreset == preset
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                manager.selectPreset(preset)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: preset.systemImage)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(isSelected ? .white : preset.brandColor)
                                    Spacer()
                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.white)
                                    }
                                }

                                Text(preset.shortName)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(isSelected ? .white : .white.opacity(0.9))

                                if preset.defaultPowerKw > 0 {
                                    Text("\(Int(preset.defaultPowerKw)) kW")
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(isSelected ? .white.opacity(0.85) : preset.brandColor)
                                } else {
                                    Text("Fatigue Break")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(isSelected ? .white.opacity(0.85) : Color.dashYellow)
                                }
                            }
                            .padding(12)
                            .frame(width: 130, height: 95)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(isSelected ? preset.brandColor : Color.dashCard)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(isSelected ? Color.white.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Session Gauge Card

    private var sessionGaugeCard: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(manager.isSessionActive ? manager.activePreset.brandColor : Color.gray)
                        .frame(width: 8, height: 8)
                    Text(manager.isSessionActive ? (manager.activePreset.isRestArea ? "REST BREAK ACTIVE" : "FAST CHARGING ACTIVE") : "SESSION STANDBY")
                        .font(ThemeFonts.hudCaption(size: 11))
                        .foregroundStyle(manager.isSessionActive ? manager.activePreset.brandColor : Color.dashTextSecondary)
                }
                Spacer()
                if manager.chargePowerKw > 0 {
                    Text("\(Int(manager.chargePowerKw)) kW MAX")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(manager.activePreset.brandColor)
                }
            }

            // Circular progress or Rest Stop timer
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 14)
                    .frame(width: 170, height: 170)

                Circle()
                    .trim(from: 0, to: CGFloat(manager.progressPercentage))
                    .stroke(
                        manager.activePreset.brandColor,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 170, height: 170)
                    .animation(.easeInOut(duration: 0.3), value: manager.progressPercentage)

                VStack(spacing: 4) {
                    if manager.activePreset.isRestArea {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Color.dashYellow)

                        let remaining = manager.remainingTimeInterval()
                        let mins = Int(remaining) / 60
                        let secs = Int(remaining) % 60
                        Text(String(format: "%02d:%02d", mins, secs))
                            .font(.system(size: 26, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.white)

                        Text("Rest Countdown")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.dashTextSecondary)
                    } else {
                        Text("\(Int(round(manager.currentBatteryPercentage)))%")
                            .font(.system(size: 40, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)

                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .bold))
                            Text("Target \(Int(round(manager.targetBatteryPercentage)))%")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(manager.activePreset.brandColor)

                        if manager.energyDeliveredKWh > 0 {
                            Text(String(format: "+%.1f kWh", manager.energyDeliveredKWh))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color.dashTextSecondary)
                        }
                    }
                }
            }
            .padding(.vertical, 8)

            // Timeline metrics ribbon
            HStack(spacing: 12) {
                metricCell(
                    title: "ELAPSED",
                    value: formatDuration(manager.elapsedTimeInterval()),
                    icon: "stopwatch"
                )
                Divider().frame(height: 24).background(Color.white.opacity(0.1))
                metricCell(
                    title: "REMAINING",
                    value: formatDuration(manager.remainingTimeInterval()),
                    icon: "timer"
                )
                Divider().frame(height: 24).background(Color.white.opacity(0.1))
                metricCell(
                    title: manager.activePreset.isRestArea ? "TARGET" : "EST. FINISH",
                    value: formatTime(manager.estimatedCompletionTime),
                    icon: "clock.badge.checkmark"
                )
            }
            .padding(12)
            .background(Color.black.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
        .background(Color.dashCard)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func metricCell(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(ThemeFonts.hudCaption(size: 9))
                .foregroundStyle(Color.dashTextSecondary)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Charging Settings Card

    private var chargingSettingsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TARGET BATTERY PERCENTAGE")
                .font(ThemeFonts.hudCaption(size: 11))
                .foregroundStyle(Color.dashTextSecondary)

            VStack(spacing: 8) {
                HStack {
                    Text("Target:")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(Int(round(manager.targetBatteryPercentage)))%")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(manager.activePreset.brandColor)
                }

                Slider(value: Binding(
                    get: { manager.targetBatteryPercentage },
                    set: { manager.setTargetBattery($0) }
                ), in: 50...100, step: 5)
                .tint(manager.activePreset.brandColor)

                HStack {
                    Text("50%")
                    Spacer()
                    Text("80% (Daily)")
                        .foregroundStyle(Color.dashYellow)
                    Spacer()
                    Text("100% (Road Trip)")
                }
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.dashTextSecondary)
            }
        }
        .padding(16)
        .background(Color.dashCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Rest Stop Settings Card

    private var restStopSettingsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("REST STOP DURATION")
                .font(ThemeFonts.hudCaption(size: 11))
                .foregroundStyle(Color.dashTextSecondary)

            HStack(spacing: 10) {
                ForEach([15, 20, 30, 45], id: \.self) { mins in
                    let isSelected = manager.restStopDurationMinutes == mins
                    Button {
                        manager.setRestStopMinutes(mins)
                    } label: {
                        Text("\(mins) min")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(isSelected ? Color.black : Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(isSelected ? Color.dashYellow : Color.dashCard)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Color.dashCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Action Button

    private var sessionActionButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                if manager.isSessionActive {
                    manager.stopSession()
                } else {
                    manager.startSession()
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: manager.isSessionActive ? "stop.fill" : "play.fill")
                    .font(.system(size: 16, weight: .bold))
                Text(manager.isSessionActive ? "Stop Session" : "Start \(manager.activePreset.shortName) Session")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(manager.isSessionActive ? .white : Color.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(manager.isSessionActive ? Color.red.opacity(0.85) : manager.activePreset.brandColor)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Parked Video Streaming Banner

    private var parkedVideoStreamBanner: some View {
        Button {
            dismiss()
            appState.selectedTab = .cast
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 1.0, green: 0.902, blue: 0.0).opacity(0.18))
                        .frame(width: 48, height: 48)
                    Image(systemName: "play.tv.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color(red: 1.0, green: 0.902, blue: 0.0))
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Stream Video While Parked")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(red: 1.0, green: 0.902, blue: 0.0))
                    }
                    Text("Watch YouTube, Plex, or Web Videos on your car display during this charge.")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color.dashTextSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .background(Color.dashCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(red: 1.0, green: 0.902, blue: 0.0).opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func formatDuration(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval))
        let mins = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    private func formatTime(_ date: Date?) -> String {
        guard let d = date else { return "--:--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: d)
    }
}
