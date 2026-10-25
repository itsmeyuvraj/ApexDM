import Foundation

public enum DownloadStatus: Codable, Equatable {
    case queued
    case connecting
    case downloading
    case paused
    case completed
    case error(String)
    
    public var title: String {
        switch self {
        case .queued: return "Queued"
        case .connecting: return "Connecting..."
        case .downloading: return "Downloading"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .error(let msg): return "Error: \(msg)"
        }
    }
    
    public var isActive: Bool {
        switch self {
        case .connecting, .downloading: return true
        default: return false
        }
    }
}

public enum SegmentStatus: Codable, Equatable {
    case idle
    case connecting
    case transferring
    case completed
    case failed(String)
    
    public var title: String {
        switch self {
        case .idle: return "Idle"
        case .connecting: return "Connecting"
        case .transferring: return "Receiving Data"
        case .completed: return "Done"
        case .failed(let err): return "Failed (\(err))"
        }
    }
}

public struct SegmentItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public let index: Int
    public let startByte: Int64
    public let endByte: Int64
    public var downloadedBytes: Int64
    public var speedBytesPerSec: Double
    public var status: SegmentStatus
    
    public var totalBytes: Int64 {
        if endByte >= startByte {
            return (endByte - startByte) + 1
        }
        return 0
    }
    
    public var progress: Double {
        guard totalBytes > 0 else { return 0.0 }
        return Double(downloadedBytes) / Double(totalBytes)
    }
    
    public var currentOffset: Int64 {
        return startByte + downloadedBytes
    }
    
    public init(
        id: UUID = UUID(),
        index: Int,
        startByte: Int64,
        endByte: Int64,
        downloadedBytes: Int64 = 0,
        speedBytesPerSec: Double = 0,
        status: SegmentStatus = .idle
    ) {
        self.id = id
        self.index = index
        self.startByte = startByte
        self.endByte = endByte
        self.downloadedBytes = downloadedBytes
        self.speedBytesPerSec = speedBytesPerSec
        self.status = status
    }
}

public class DownloadItem: Identifiable, ObservableObject, Codable {
    public let id: UUID
    public let url: URL
    @Published public var filename: String
    @Published public var destinationPath: String
    @Published public var totalBytes: Int64
    @Published public var downloadedBytes: Int64
    @Published public var supportsRange: Bool
    @Published public var segmentCount: Int
    @Published public var segments: [SegmentItem]
    @Published public var status: DownloadStatus
    @Published public var speedBytesPerSec: Double
    public let dateAdded: Date
    @Published public var dateCompleted: Date?
    @Published public var category: FileCategory
    @Published public var errorMessage: String?
    
    public var progress: Double {
        guard totalBytes > 0 else {
            return status == .completed ? 1.0 : 0.0
        }
        return min(1.0, max(0.0, Double(downloadedBytes) / Double(totalBytes)))
    }
    
    public var remainingBytes: Int64 {
        guard totalBytes > 0 else { return 0 }
        return max(0, totalBytes - downloadedBytes)
    }
    
    public var destinationURL: URL {
        URL(fileURLWithPath: destinationPath)
    }
    
    public init(
        id: UUID = UUID(),
        url: URL,
        filename: String,
        destinationPath: String,
        totalBytes: Int64 = -1,
        downloadedBytes: Int64 = 0,
        supportsRange: Bool = false,
        segmentCount: Int = 8,
        segments: [SegmentItem] = [],
        status: DownloadStatus = .queued,
        speedBytesPerSec: Double = 0,
        dateAdded: Date = Date(),
        dateCompleted: Date? = nil,
        category: FileCategory? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.url = url
        self.filename = filename
        self.destinationPath = destinationPath
        self.totalBytes = totalBytes
        self.downloadedBytes = downloadedBytes
        self.supportsRange = supportsRange
        self.segmentCount = segmentCount
        self.segments = segments
        self.status = status
        self.speedBytesPerSec = speedBytesPerSec
        self.dateAdded = dateAdded
        self.dateCompleted = dateCompleted
        self.category = category ?? FileUtils.categorize(filename: filename)
        self.errorMessage = errorMessage
    }
    
    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case id, url, filename, destinationPath, totalBytes, downloadedBytes
        case supportsRange, segmentCount, segments, status, speedBytesPerSec
        case dateAdded, dateCompleted, category, errorMessage
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.url = try container.decode(URL.self, forKey: .url)
        self.filename = try container.decode(String.self, forKey: .filename)
        self.destinationPath = try container.decode(String.self, forKey: .destinationPath)
        self.totalBytes = try container.decode(Int64.self, forKey: .totalBytes)
        self.downloadedBytes = try container.decode(Int64.self, forKey: .downloadedBytes)
        self.supportsRange = try container.decode(Bool.self, forKey: .supportsRange)
        self.segmentCount = try container.decode(Int.self, forKey: .segmentCount)
        self.segments = try container.decode([SegmentItem].self, forKey: .segments)
        self.status = try container.decode(DownloadStatus.self, forKey: .status)
        self.speedBytesPerSec = try container.decode(Double.self, forKey: .speedBytesPerSec)
        self.dateAdded = try container.decode(Date.self, forKey: .dateAdded)
        self.dateCompleted = try container.decodeIfPresent(Date.self, forKey: .dateCompleted)
        self.category = try container.decode(FileCategory.self, forKey: .category)
        self.errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(url, forKey: .url)
        try container.encode(filename, forKey: .filename)
        try container.encode(destinationPath, forKey: .destinationPath)
        try container.encode(totalBytes, forKey: .totalBytes)
        try container.encode(downloadedBytes, forKey: .downloadedBytes)
        try container.encode(supportsRange, forKey: .supportsRange)
        try container.encode(segmentCount, forKey: .segmentCount)
        try container.encode(segments, forKey: .segments)
        try container.encode(status, forKey: .status)
        try container.encode(speedBytesPerSec, forKey: .speedBytesPerSec)
        try container.encode(dateAdded, forKey: .dateAdded)
        try container.encode(dateCompleted, forKey: .dateCompleted)
        try container.encode(category, forKey: .category)
        try container.encode(errorMessage, forKey: .errorMessage)
    }
}

extension DownloadItem: Hashable, Equatable {
    public static func == (lhs: DownloadItem, rhs: DownloadItem) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

