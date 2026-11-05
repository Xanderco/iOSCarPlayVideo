import SwiftUI
import UIKit

/// Floating glass tab bar for iOS 17–25 (iOS 26+ uses the system Liquid Glass `TabView`).
///
/// Performance: one `.ultraThinMaterial` layer for the whole bar (no per-item blur), the active indicator is a
/// single capsule moved with `matchedGeometryEffect`, and there are no `GeometryReader`s. Reduce Motion swaps
/// the spring for a plain crossfade; Reduce Transparency falls back to a solid surface.
public struct LiquidCapsuleTabBar: View {
    @Binding var selectedTab: AppState.TabItem
    @Namespace private var indicator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(selectedTab: Binding<AppState.TabItem>) {
        self._selectedTab = selectedTab
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(AppState.TabItem.allCases) { item in
                tabButton(item)
            }
        }
        .padding(DSSpacing.xs)
        .background {
            if reduceTransparency {
                Capsule().fill(Color.dcSurfaceRaised)
            } else {
                Capsule().fill(.ultraThinMaterial)
            }
        }
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: DSStroke.regular))
        .compositingGroup()
        .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 4)
        .padding(.horizontal, DSSpacing.lg)
        .padding(.bottom, 6)
    }

    private func tabButton(_ item: AppState.TabItem) -> some View {
        let isSelected = selectedTab == item
        return Button {
            guard selectedTab != item else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(reduceMotion ? .easeInOut(duration: 0.15) : .spring(response: 0.32, dampingFraction: 0.8)) {
                selectedTab = item
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: item.iconName)
                    .font(.system(size: 19, weight: isSelected ? .bold : .medium))
                    .frame(height: 22)
                Text(item.rawValue)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? Color.dcAccent : Color.dcTextSecondary)
            .frame(maxWidth: .infinity, minHeight: DSLayout.minTapTarget)
            .padding(.vertical, 4)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.dcAccent.opacity(0.16))
                        .matchedGeometryEffect(id: "activeTab", in: indicator)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(item.rawValue))
        .accessibilityIdentifier("Tab_\(item.rawValue)")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
    }
}

#Preview("Capsule tab bar") {
    ZStack(alignment: .bottom) {
        Color.dcBackground.ignoresSafeArea()
        LiquidCapsuleTabBar(selectedTab: .constant(.home))
    }
    .preferredColorScheme(.dark)
}
