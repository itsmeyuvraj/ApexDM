import SwiftUI

public struct MainWindowView: View {
    @EnvironmentObject public var downloadManager: DownloadManager
    @State private var showingSettings: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            // Sidebar: Categories
            List(FileCategory.allCases, id: \.self, selection: $downloadManager.selectedCategory) { category in
                NavigationLink(value: category) {
                    HStack {
                        Image(systemName: category.iconName)
                            .foregroundColor(.accentColor)
                            .frame(width: 20)
                        Text(category.rawValue)
                        Spacer()
                        
                        let count = categoryCount(category)
                        if count > 0 {
                            Text("\(count)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
            .navigationTitle("Categories")
        } detail: {
            VStack(spacing: 0) {
                // Main Table View
                DownloadTableView()
                
                Divider()
                
                // Bottom Status Bar
                bottomStatusBar
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: {
                    downloadManager.isShowingNewDownloadSheet = true
                }) {
                    Label("Add URL", systemImage: "plus")
                }
                .help("Add new download URL")
                
                Button(action: {
                    if let item = downloadManager.selectedItem {
                        downloadManager.resumeDownload(item)
                    } else {
                        downloadManager.resumeAll()
                    }
                }) {
                    Label("Resume", systemImage: "play.fill")
                }
                .help("Resume selected or all downloads")
                
                Button(action: {
                    if let item = downloadManager.selectedItem {
                        downloadManager.pauseDownload(item)
                    } else {
                        downloadManager.pauseAll()
                    }
                }) {
                    Label("Pause", systemImage: "pause.fill")
                }
                .help("Pause selected or all downloads")
                
                Button(action: {
                    if let item = downloadManager.selectedItem {
                        downloadManager.deleteDownload(item)
                    }
                }) {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(downloadManager.selectedItem == nil)
                .help("Delete selected download")
                
                Divider()
                
                // Live Aggregate Speed Widget
                if downloadManager.totalActiveSpeed > 0 {
                    HStack(spacing: 5) {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        Text(Formatters.formatSpeed(downloadManager.totalActiveSpeed))
                            .font(.caption)
                            .fontWeight(.bold)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15))
                    .foregroundColor(.green)
                    .clipShape(Capsule())
                }
                
                Button(action: {
                    showingSettings = true
                }) {
                    Label("Settings", systemImage: "gearshape")
                }
                .help("Preferences")
            }
        }
        .searchable(text: $downloadManager.searchText, prompt: "Search downloads...")
        .sheet(isPresented: $downloadManager.isShowingNewDownloadSheet) {
            NewDownloadSheet(initialURL: downloadManager.initialURLForSheet)
                .environmentObject(downloadManager)
        }
        .sheet(item: $downloadManager.inspectedItem) { item in
            SegmentVisualizerView(item: item)
                .environmentObject(downloadManager)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
    
    private var bottomStatusBar: some View {
        HStack {
            Text("\(downloadManager.downloads.count) items total")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text("•")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text("\(downloadManager.activeDownloadCount) active")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if downloadManager.clipboardMonitoringEnabled {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 9))
                    Text("Clipboard Watcher Active")
                        .font(.system(size: 10))
                }
                .foregroundColor(.secondary)
                .padding(.trailing, 8)
            }
            
            Text("Engine: Apple Silicon Native (arm64)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private func categoryCount(_ category: FileCategory) -> Int {
        if category == .all {
            return downloadManager.downloads.count
        }
        return downloadManager.downloads.filter { $0.category == category }.count
    }
}
