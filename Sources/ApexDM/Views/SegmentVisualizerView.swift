import SwiftUI

public struct SegmentVisualizerView: View {
    @ObservedObject public var item: DownloadItem
    @EnvironmentObject public var downloadManager: DownloadManager
    @Environment(\.dismiss) private var dismiss
    
    public init(item: DownloadItem) {
        self.item = item
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack(spacing: 14) {
                Image(systemName: item.category.iconName)
                    .font(.system(size: 32))
                    .foregroundColor(.accentColor)
                    .frame(width: 48, height: 48)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.filename)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(item.url.absoluteString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                statusPill
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Overall Progress & Stats Box
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Overall Progress")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(Formatters.formatPercentage(item.progress))
                                .font(.system(.title3, design: .rounded, weight: .bold))
                                .foregroundColor(.accentColor)
                        }
                        
                        ProgressView(value: item.progress)
                            .progressViewStyle(.linear)
                            .tint(.accentColor)
                        
                        // Metadata Grid
                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                            GridRow {
                                Text("File Size:")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                Text(Formatters.formatBytes(item.totalBytes))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                
                                Text("Downloaded:")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                Text(Formatters.formatBytes(item.downloadedBytes))
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            
                            GridRow {
                                Text("Transfer Rate:")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                Text(Formatters.formatSpeed(item.speedBytesPerSec))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                                
                                Text("Time Left (ETA):")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                Text(Formatters.formatETA(remainingBytes: item.remainingBytes, speedBytesPerSec: item.speedBytesPerSec))
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            
                            GridRow {
                                Text("Resume Support:")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                HStack(spacing: 4) {
                                    Image(systemName: item.supportsRange ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                        .foregroundColor(item.supportsRange ? .green : .orange)
                                    Text(item.supportsRange ? "Yes (HTTP Range)" : "No (Single Stream)")
                                }
                                .font(.caption)
                                .fontWeight(.medium)
                                
                                Text("Save To:")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                Text((item.destinationPath as NSString).lastPathComponent)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(14)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    // IDM Multi-Connection Segment Visualizer Bar
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Connection Distribution Map")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        IDMSegmentBar(segments: item.segments, totalBytes: item.totalBytes)
                    }
                    .padding(14)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    // Connection Details Table
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Parallel Connections (\(item.segments.count) Threads)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        
                        if item.segments.isEmpty {
                            Text("Single connection stream active.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            VStack(spacing: 6) {
                                // Table Header
                                HStack(spacing: 8) {
                                    Text("#")
                                        .frame(width: 28, alignment: .leading)
                                    Text("Status")
                                        .frame(width: 100, alignment: .leading)
                                    Text("Range")
                                        .frame(width: 120, alignment: .leading)
                                    Text("Progress")
                                        .frame(minWidth: 80, alignment: .leading)
                                    Text("Speed")
                                        .frame(width: 80, alignment: .trailing)
                                }
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                
                                ForEach(item.segments) { seg in
                                    ConnectionRow(segment: seg)
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(20)
            }
            
            Divider()
            
            // Footer Control Buttons
            HStack(spacing: 12) {
                if item.status == .completed {
                    Button(action: {
                        FileUtils.openFile(url: item.destinationURL)
                    }) {
                        Label("Open File", systemImage: "arrow.up.forward.app")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button(action: {
                        FileUtils.revealInFinder(url: item.destinationURL)
                    }) {
                        Label("Show in Finder", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                } else if item.status.isActive {
                    Button(action: {
                        downloadManager.pauseDownload(item)
                    }) {
                        Label("Pause Download", systemImage: "pause.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    
                    Button(action: {
                        downloadManager.pauseDownload(item)
                        dismiss()
                    }) {
                        Text("Stop & Close")
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button(action: {
                        downloadManager.resumeDownload(item)
                    }) {
                        Label("Resume Download", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 580, idealWidth: 640, minHeight: 520, idealHeight: 580)
    }
    
    private var statusPill: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(item.status.title)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(statusColor.opacity(0.12))
        .foregroundColor(statusColor)
        .clipShape(Capsule())
    }
    
    private var statusColor: Color {
        switch item.status {
        case .downloading: return .green
        case .connecting: return .blue
        case .paused: return .orange
        case .completed: return .purple
        case .queued: return .gray
        case .error: return .red
        }
    }
}

private struct ConnectionRow: View {
    let segment: SegmentItem
    
    var body: some View {
        HStack(spacing: 8) {
            Text("\(segment.index)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .frame(width: 28, alignment: .leading)
            
            Text(segment.status.title)
                .font(.caption2)
                .foregroundColor(segment.status == .transferring ? .green : .secondary)
                .frame(width: 100, alignment: .leading)
            
            Text("\(Formatters.formatBytes(segment.startByte)) - \(Formatters.formatBytes(segment.endByte))")
                .font(.caption2)
                .monospacedDigit()
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            
            HStack(spacing: 6) {
                ProgressView(value: segment.progress)
                    .progressViewStyle(.linear)
                Text(Formatters.formatPercentage(segment.progress))
                    .font(.caption2)
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }
            .frame(minWidth: 80)
            
            Text(Formatters.formatSpeed(segment.speedBytesPerSec))
                .font(.caption2)
                .monospacedDigit()
                .foregroundColor(segment.speedBytesPerSec > 0 ? .primary : .secondary)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
