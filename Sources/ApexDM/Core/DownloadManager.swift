import Foundation
import SwiftUI
import Combine

public class DownloadManager: ObservableObject {
    @Published public var downloads: [DownloadItem] = []
    @Published public var selectedCategory: FileCategory = .all
    @Published public var searchText: String = ""
    @Published public var selectedItem: DownloadItem? = nil
    @Published public var inspectedItem: DownloadItem? = nil
    @Published public var isShowingNewDownloadSheet: Bool = false
    @Published public var initialURLForSheet: String = ""
    
    // Global settings
    @AppStorage("defaultSegmentCount") public var defaultSegmentCount: Int = 8
    @AppStorage("clipboardMonitoringEnabled") public var clipboardMonitoringEnabled: Bool = true {
        didSet {
            clipboardWatcher.isEnabled = clipboardMonitoringEnabled
        }
    }
    
    public let clipboardWatcher = ClipboardWatcher()
    private var engines: [UUID: DownloadEngine] = [:]
    private var cancellables = Set<AnyCancellable>()
    private let persistenceURL = FileUtils.appSupportDirectory().appendingPathComponent("downloads.json")
    
    public init() {
        loadPersistedDownloads()
        setupClipboardWatcher()
    }
    
    public var filteredDownloads: [DownloadItem] {
        downloads.filter { item in
            // Category filter
            let matchesCategory = (selectedCategory == .all) || (item.category == selectedCategory)
            
            // Search text filter
            let matchesSearch = searchText.isEmpty ||
                item.filename.localizedCaseInsensitiveContains(searchText) ||
                item.url.absoluteString.localizedCaseInsensitiveContains(searchText)
            
            return matchesCategory && matchesSearch
        }
    }
    
    public var totalActiveSpeed: Double {
        downloads
            .filter { $0.status.isActive }
            .reduce(0) { $0 + $1.speedBytesPerSec }
    }
    
    public var activeDownloadCount: Int {
        downloads.filter { $0.status.isActive }.count
    }
    
    // MARK: - Actions
    
    @discardableResult
    public func addDownload(
        url: URL,
        customFilename: String? = nil,
        destinationDir: URL? = nil,
        segmentCount: Int? = nil,
        startImmediately: Bool = true
    ) -> DownloadItem {
        let dir = destinationDir ?? FileUtils.defaultDownloadDirectory()
        let filename = FileUtils.sanitizeFilename(customFilename ?? url.lastPathComponent)
        let uniqueDest = FileUtils.generateUniqueDestination(directory: dir, preferredFilename: filename)
        
        let item = DownloadItem(
            url: url,
            filename: uniqueDest.lastPathComponent,
            destinationPath: uniqueDest.path,
            segmentCount: segmentCount ?? defaultSegmentCount,
            status: .queued
        )
        
        DispatchQueue.main.async {
            self.downloads.insert(item, at: 0)
            self.saveDownloads()
            
            if startImmediately {
                self.startDownload(item)
                self.inspectedItem = item
            }
        }
        
        return item
    }
    
    public func startDownload(_ item: DownloadItem) {
        if let existingEngine = engines[item.id] {
            existingEngine.start()
            return
        }
        
        let engine = DownloadEngine(item: item)
        engines[item.id] = engine
        engine.start()
        
        // Listen to changes to save state
        item.objectWillChange
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.saveDownloads()
            }
            .store(in: &cancellables)
    }
    
    public func pauseDownload(_ item: DownloadItem) {
        engines[item.id]?.pause()
        saveDownloads()
    }
    
    public func resumeDownload(_ item: DownloadItem) {
        startDownload(item)
    }
    
    public func pauseAll() {
        for item in downloads where item.status.isActive {
            pauseDownload(item)
        }
    }
    
    public func resumeAll() {
        for item in downloads where item.status == .paused || item.status == .queued {
            resumeDownload(item)
        }
    }
    
    public func deleteDownload(_ item: DownloadItem, deleteFile: Bool = false) {
        pauseDownload(item)
        engines.removeValue(forKey: item.id)
        
        if deleteFile {
            try? FileManager.default.removeItem(atPath: item.destinationPath)
        }
        
        downloads.removeAll { $0.id == item.id }
        if selectedItem?.id == item.id {
            selectedItem = nil
        }
        if inspectedItem?.id == item.id {
            inspectedItem = nil
        }
        saveDownloads()
    }
    
    // MARK: - Clipboard Integration
    
    private func setupClipboardWatcher() {
        clipboardWatcher.isEnabled = clipboardMonitoringEnabled
        clipboardWatcher.start()
        
        clipboardWatcher.$detectedURL
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] url in
                self?.promptClipboardDownload(url: url)
            }
            .store(in: &cancellables)
    }
    
    private func promptClipboardDownload(url: URL) {
        self.initialURLForSheet = url.absoluteString
        self.isShowingNewDownloadSheet = true
        self.clipboardWatcher.dismissDetectedURL()
    }
    
    // MARK: - Persistence
    
    private func saveDownloads() {
        do {
            let data = try JSONEncoder().encode(downloads)
            try data.write(to: persistenceURL, options: .atomic)
        } catch {
            print("Failed to persist downloads: \(error)")
        }
    }
    
    private func loadPersistedDownloads() {
        guard FileManager.default.fileExists(atPath: persistenceURL.path) else { return }
        do {
            let data = try Data(contentsOf: persistenceURL)
            let decoded = try JSONDecoder().decode([DownloadItem].self, from: data)
            // On fresh launch, mark any previously active downloading item as paused
            for item in decoded {
                if item.status.isActive {
                    item.status = .paused
                }
            }
            self.downloads = decoded
        } catch {
            print("Failed to load downloads: \(error)")
        }
    }
}
