import SwiftUI

public struct CategoryBadge: View {
    public let category: FileCategory
    
    public init(category: FileCategory) {
        self.category = category
    }
    
    private var badgeColor: Color {
        switch category {
        case .all: return .gray
        case .compressed: return .orange
        case .video: return .purple
        case .music: return .pink
        case .documents: return .blue
        case .programs: return .green
        case .others: return .teal
        }
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.iconName)
                .font(.system(size: 10, weight: .bold))
            Text(category.rawValue)
                .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(badgeColor.opacity(0.15))
        .foregroundColor(badgeColor)
        .clipShape(Capsule())
    }
}
