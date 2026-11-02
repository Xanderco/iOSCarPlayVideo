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
                            .font(.system(size: 21, weight: isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? Color.dashYellow : Color.dashTextMuted)
                            .frame(height: 24)

                        Text(item.rawValue)
                            .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? Color.dashYellow : Color.dashTextMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        isSelected ? Color.dashYellow.opacity(0.12) : Color.clear
                    )
                    .clipShape(Capsule())
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            // Translucent Frosted Glass Capsule
            ZStack {
                Color(red: 0.12, green: 0.14, blue: 0.18).opacity(0.85)
                Rectangle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
        )
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.6), radius: 16, y: 6)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}
