import SwiftUI

public struct DownloadTableView: View {
    @EnvironmentObject public var downloadManager: DownloadManager
    
    public var body: some View {
        if downloadManager.filteredDownloads.isEmpty {
            emptyStateView
        } else {
            List(selection: $downloadManager.selectedItem) {
                ForEach(downloadManager.filteredDownloads) { item in
                    DownloadRowView(item: item)
                        .tag(item)
                        .contextMenu {
                            contextMenuContent(for: item)
                        }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let item = downloadManager.filteredDownloads[index]
                        downloadManager.deleteDownload(item)
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.6))
            
            Text("No Downloads in this Category")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Click \"Add URL\" (+) in the toolbar or copy a link to download.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button(action: {
                downloadManager.isShowingNewDownloadSheet = true
            }) {
                Label("Add Download", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
    
    @ViewBuilder
    private func contextMenuContent(for item: DownloadItem) -> some View {
        if item.status.isActive {
            Button(action: { downloadManager.pauseDownload(item) }) {
                Label("Pause", systemImage: "pause.fill")
            }
        } else if item.status == .paused || item.status == .queued {
            Button(action: { downloadManager.resumeDownload(item) }) {
                Label("Resume", systemImage: "play.fill")
            }
        }
        
        Button(action: {
            downloadManager.inspectedItem = item
        }) {
            Label("Inspect Segments (IDM Visualizer)", systemImage: "chart.bar.xaxis")
        }
        
        Divider()
        
        if item.status == .completed {
            Button(action: { FileUtils.openFile(url: item.destinationURL) }) {
                Label("Open File", systemImage: "arrow.up.forward.app")
            }
            
            Button(action: { FileUtils.revealInFinder(url: item.destinationURL) }) {
                Label("Show in Finder", systemImage: "folder")
            }
        }
        
        Button(action: {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(item.url.absoluteString, forType: .string)
        }) {
            Label("Copy Download URL", systemImage: "doc.on.doc")
        }
        
        Divider()
        
        Button(role: .destructive, action: {
            downloadManager.deleteDownload(item, deleteFile: false)
        }) {
            Label("Remove from List", systemImage: "trash")
        }
        
        Button(role: .destructive, action: {
            downloadManager.deleteDownload(item, deleteFile: true)
        }) {
            Label("Delete File from Disk", systemImage: "trash.fill")
        }
    }
}

private struct DownloadRowView: View {
    @ObservedObject var item: DownloadItem
    @EnvironmentObject var downloadManager: DownloadManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Status Icon
            statusIcon
                .frame(width: 24, height: 24)
            
            // Name & details
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.filename)
                        .font(.system(.body, design: .default, weight: .medium))
                        .lineLimit(1)
                    
                    CategoryBadge(category: item.category)
                }
                
                HStack(spacing: 8) {
                    Text(Formatters.formatBytes(item.totalBytes))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if item.status.isActive {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(Formatters.formatSpeed(item.speedBytesPerSec))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("ETA: \(Formatters.formatETA(remainingBytes: item.remainingBytes, speedBytesPerSec: item.speedBytesPerSec))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(item.status.title)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Progress Bar & Percentage
            VStack(alignment: .trailing, spacing: 3) {
                HStack(spacing: 6) {
                    ProgressView(value: item.progress)
                        .progressViewStyle(.linear)
                        .frame(width: 120)
                    
                    Text(Formatters.formatPercentage(item.progress))
                        .font(.caption)
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }
                
                if item.supportsRange && item.segmentCount > 1 {
                    Text("\(item.segmentCount) segments")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            
            // Action Buttons
            HStack(spacing: 4) {
                if item.status.isActive {
                    Button(action: { downloadManager.pauseDownload(item) }) {
                        Image(systemName: "pause.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.orange)
                    .help("Pause")
                } else if item.status == .completed {
                    Button(action: { FileUtils.revealInFinder(url: item.destinationURL) }) {
                        Image(systemName: "folder")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .help("Show in Finder")
                } else {
                    Button(action: { downloadManager.resumeDownload(item) }) {
                        Image(systemName: "play.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.green)
                    .help("Resume")
                }
                
                Button(action: {
                    downloadManager.inspectedItem = item
                }) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .help("Inspect Segments")
            }
            .padding(.leading, 6)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            downloadManager.inspectedItem = item
        }
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch item.status {
        case .downloading, .connecting:
            Image(systemName: "arrow.down.circle.fill")
                .foregroundColor(.green)
                .font(.title3)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.purple)
                .font(.title3)
        case .paused:
            Image(systemName: "pause.circle.fill")
                .foregroundColor(.orange)
                .font(.title3)
        case .queued:
            Image(systemName: "clock.fill")
                .foregroundColor(.blue)
                .font(.title3)
        case .error:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
                .font(.title3)
        }
    }
}
