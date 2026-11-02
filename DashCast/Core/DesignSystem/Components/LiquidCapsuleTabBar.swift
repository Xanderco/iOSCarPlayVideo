import SwiftUI

public struct LiquidCapsuleTabBar: View {
    @Binding var selectedTab: AppState.TabItem

    public init(selectedTab: Binding<AppState.TabItem>) {
        self._selectedTab = selectedTab
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(AppState.TabItem.allCases) { item in
                let isSelected = selectedTab == item
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selectedTab = item
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.iconName)
                            .font(.system(size: 20, weight: isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? Color.dashYellow : Color.dashTextMuted)
                            .frame(height: 22)

                        Text(item.rawValue)
                            .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? Color.dashYellow : Color.dashTextMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        isSelected ? Color.dashYellow.opacity(0.14) : Color.clear
                    )
                    .clipShape(Capsule())
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("Tab_\(item.rawValue)")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            ZStack {
                Color(red: 0.10, green: 0.11, blue: 0.14).opacity(0.92)
                Capsule()
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            }
        )
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.65), radius: 16, x: 0, y: 6)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }
}
