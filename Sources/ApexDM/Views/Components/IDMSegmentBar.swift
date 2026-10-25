import SwiftUI

public struct IDMSegmentBar: View {
    public let segments: [SegmentItem]
    public let totalBytes: Int64
    
    // Distinct vibrant IDM segment palette
    private let segmentColors: [Color] = [
        Color(red: 0.15, green: 0.65, blue: 1.0),   // Electric Blue
        Color(red: 0.2, green: 0.85, blue: 0.45),   // Emerald Green
        Color(red: 1.0, green: 0.6, blue: 0.1),    // Amber Orange
        Color(red: 0.75, green: 0.35, blue: 0.95),  // Vivid Purple
        Color(red: 0.95, green: 0.25, blue: 0.45),  // Coral Pink
        Color(red: 0.05, green: 0.8, blue: 0.8),    // Cyan
        Color(red: 1.0, green: 0.85, blue: 0.1),   // Bright Yellow
        Color(red: 0.4, green: 0.5, blue: 1.0)     // Indigo
    ]
    
    public init(segments: [SegmentItem], totalBytes: Int64) {
        self.segments = segments
        self.totalBytes = totalBytes
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height
                
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .separatorColor).opacity(0.3))
                    
                    if segments.isEmpty || totalBytes <= 0 {
                        // Fallback continuous bar
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor.opacity(0.4))
                    } else {
                        // Multi-segment partition
                        HStack(spacing: 2) {
                            ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                                let segmentRatio = max(0.01, Double(segment.totalBytes) / Double(max(1, totalBytes)))
                                let segmentWidth = max(4.0, (width - CGFloat(segments.count - 1) * 2) * CGFloat(segmentRatio))
                                let color = segmentColors[index % segmentColors.count]
                                
                                SegmentBlock(
                                    segment: segment,
                                    width: segmentWidth,
                                    height: height,
                                    color: color
                                )
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .frame(height: 22)
            
            // Sub-caption
            HStack {
                Text("\(segments.count) Parallel Connections")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("APFS Concurrent pwrite")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct SegmentBlock: View {
    let segment: SegmentItem
    let width: CGFloat
    let height: CGFloat
    let color: Color
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Unfilled segment background
            Rectangle()
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .frame(width: width, height: height)
            
            // Downloaded portion
            let progress = max(0.0, min(1.0, segment.progress))
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.85), color],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: max(0, width * CGFloat(progress)), height: height)
            
            // Active pulse indicator for transferring segments
            if segment.status == .transferring {
                Rectangle()
                    .stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                    .frame(width: width, height: height)
            }
        }
    }
}
