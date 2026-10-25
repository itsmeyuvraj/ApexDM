import Foundation
import AppKit

public enum FileCategory: String, Codable, CaseIterable, Identifiable {
    case all = "All Downloads"
    case compressed = "Compressed"
    case video = "Video"
    case music = "Music"
    case documents = "Documents"
    case programs = "Programs"
    case others = "Others"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .all: return "tray.full.fill"
        case .compressed: return "archivebox.fill"
        case .video: return "film.fill"
        case .music: return "music.note"
        case .documents: return "doc.text.fill"
        case .programs: return "gearshape.2.fill"
        case .others: return "folder.fill"
        }
    }
}

public enum FileUtils {
    public static func defaultDownloadDirectory() -> URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
    }
    
    public static func appSupportDirectory() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ApexDM", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    public static func categorize(filename: String) -> FileCategory {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "zip", "rar", "7z", "tar", "gz", "bz2", "xz", "iso", "dmg":
            return .compressed
        case "mp4", "mkv", "mov", "avi", "webm", "flv", "m4v", "wmv":
            return .video
        case "mp3", "flac", "wav", "aac", "ogg", "m4a", "wma":
            return .music
        case "pdf", "epub", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "md":
            return .documents
        case "app", "pkg", "deb", "rpm", "bin", "sh":
            return .programs
        default:
            return .others
        }
    }
    
    public static func sanitizeFilename(_ name: String) -> String {
        var clean = name.replacingOccurrences(of: "/", with: "-")
        clean = clean.replacingOccurrences(of: ":", with: "-")
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty {
            return "download_\(Int(Date().timeIntervalSince1970))"
        }
        return clean
    }
    
    public static func generateUniqueDestination(directory: URL, preferredFilename: String) -> URL {
        let fileManager = FileManager.default
        let baseName = (preferredFilename as NSString).deletingPathExtension
        let ext = (preferredFilename as NSString).pathExtension
        let dotExt = ext.isEmpty ? "" : ".\(ext)"
        
        var destination = directory.appendingPathComponent(preferredFilename)
        var counter = 1
        
        while fileManager.fileExists(atPath: destination.path) {
            let newName = "\(baseName) (\(counter))\(dotExt)"
            destination = directory.appendingPathComponent(newName)
            counter += 1
        }
        return destination
    }
    
    public static func allocateFile(at path: String, size: Int64) throws -> Int32 {
        let cPath = (path as NSString).fileSystemRepresentation
        let fd = open(cPath, O_RDWR | O_CREAT, 0o644)
        guard fd >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        
        if size > 0 {
            if ftruncate(fd, off_t(size)) != 0 {
                close(fd)
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
        }
        return fd
    }
    
    public static func writeSegmentData(fd: Int32, offset: Int64, data: Data) -> Bool {
        return data.withUnsafeBytes { rawBufferPointer in
            guard let baseAddress = rawBufferPointer.baseAddress else { return false }
            var totalWritten = 0
            let count = data.count
            
            while totalWritten < count {
                let bytesToWrite = count - totalWritten
                let currentOffset = off_t(offset + Int64(totalWritten))
                let result = pwrite(fd, baseAddress.advanced(by: totalWritten), bytesToWrite, currentOffset)
                if result <= 0 {
                    return false
                }
                totalWritten += result
            }
            return true
        }
    }
    
    public static func revealInFinder(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    public static func openFile(url: URL) {
        NSWorkspace.shared.open(url)
    }
}
