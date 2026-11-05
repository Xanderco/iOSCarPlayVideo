import SwiftUI

/// Cast & Mirror tab (redesign spec §4.6): connection status and ways to get video onto another screen.
/// Composes existing Cast components only; the full redesign of this screen is redesign 2A's.
public struct CastMirrorView: View {
    @ObservedObject private var externalDisplay = ExternalDisplayManager.shared
    @State private var showingGuide = false
    @State private var showingBrowser = false
    @State private var showingMirrorHelp = false

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: DSSpacing.md) {
                        Image(systemName: externalDisplay.isExternalDisplayConnected ? "checkmark.circle.fill" : "rectangle.on.rectangle.slash")
                            .font(.title2)
                            .foregroundStyle(externalDisplay.isExternalDisplayConnected ? Color.dcAccent : Color.dcTextSecondary)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                            Text(externalDisplay.isExternalDisplayConnected ? "Car display connected" : "No car display connected")
                                .font(DSTypography.headline)
                                .foregroundStyle(Color.dcTextPrimary)
                            Text(externalDisplay.isExternalDisplayConnected
                                 ? "Video you play shows on the connected screen."
                                 : "Connect with AirPlay, a cable or screen mirroring.")
                                .font(DSTypography.subheadline)
                                .foregroundStyle(Color.dcTextSecondary)
                        }
                    }
                    .padding(.vertical, DSSpacing.xs)
                    .accessibilityElement(children: .combine)

                    HStack {
                        Label("AirPlay", systemImage: "airplayvideo")
                        Spacer()
                        AirPlayRoutePickerRepresentable(tintColor: .dcAccent)
                            .frame(width: DSLayout.minTapTarget, height: DSLayout.minTapTarget)
                            .accessibilityLabel(Text("Choose AirPlay device"))
                    }
                } header: {
                    Text("Status")
                }

                Section {
                    Button { showingMirrorHelp = true } label: {
                        Label("Mirror iPhone Screen", systemImage: "rectangle.on.rectangle")
                    }
                    Button { showingBrowser = true } label: {
                        Label("Web Video", systemImage: "safari")
                    }
                    Button { showingGuide = true } label: {
                        Label("How to Connect", systemImage: "questionmark.circle")
                    }
                } header: {
                    Text("Ways to cast")
                } footer: {
                    Text("For passengers, or while parked.")
                }
            }
            .tint(Color.dcAccent)
            .scrollContentBackground(.hidden)
            .background(Color.dcBackgroundElevated.ignoresSafeArea())
            .navigationTitle("Cast")
            .sheet(isPresented: $showingGuide) { CarCastGuideModalView() }
            .sheet(isPresented: $showingBrowser) { WebVideoBrowserView() }
            .alert("Mirror iPhone Screen", isPresented: $showingMirrorHelp) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Open Control Center, tap Screen Mirroring and pick your car or TV. Everything on this iPhone is shown there.")
            }
        }
    }
}

#Preview("Cast & Mirror") {
    CastMirrorView()
        .preferredColorScheme(.dark)
}
