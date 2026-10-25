import Foundation
import AppKit
import Combine

public class ClipboardWatcher: ObservableObject {
    @Published public var isEnabled: Bool = true
    @Published public var detectedURL: URL? = nil
    
    private var lastChangeCount: Int
    private var timer: Timer?
    private var lastHandledURLString: String = ""
    
    public init() {
        self.lastChangeCount = NSPasteboard.general.changeCount
    }
    
    public func start() {
        stop()
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    public func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    public func dismissDetectedURL() {
        self.detectedURL = nil
    }
    
    private func checkClipboard() {
        guard isEnabled else { return }
        let currentChangeCount = NSPasteboard.general.changeCount
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount
        
        guard let string = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return
        }
        
        guard string != lastHandledURLString else { return }
        
        if let url = URL(string: string),
           let scheme = url.scheme?.lowercased(),
           ["http", "https"].contains(scheme),
           url.host != nil {
            
            // Check if it appears to be a direct file or downloadable link
            if isDownloadableURL(url) {
                lastHandledURLString = string
                DispatchQueue.main.async {
                    self.detectedURL = url
                }
            }
        }
    }
    
    private func isDownloadableURL(_ url: URL) -> Bool {
        let pathExt = url.pathExtension.lowercased()
        let knownExtensions: Set<String> = [
            "zip", "rar", "7z", "tar", "gz", "bz2", "xz", "iso", "dmg", "pkg",
            "mp4", "mkv", "mov", "avi", "webm", "mp3", "flac", "wav", "aac",
            "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "exe", "bin",
            "jpg", "jpeg", "png", "webp", "gif"
        ]
        
        if knownExtensions.contains(pathExt) {
            return true
        }
        
        // Also check if URL path ends with common file indicators or download endpoints
        let lower = url.absoluteString.lowercased()
        if lower.contains("/download") || lower.contains("download?") || lower.contains("/releases/download/") {
            return true
        }
        
        return false
    }
}
