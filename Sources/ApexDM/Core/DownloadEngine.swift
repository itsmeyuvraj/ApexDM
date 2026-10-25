import Foundation
import Combine

public actor DownloadSessionCoordinator {
    private var isCancelled = false
    private var activeTasks: [Int: Task<Void, Never>] = [:]
    
    public func setTask(_ task: Task<Void, Never>, for index: Int) {
        activeTasks[index] = task
    }
    
    public func removeTask(for index: Int) {
        activeTasks.removeValue(forKey: index)
    }
    
    public func cancelAll() {
        isCancelled = true
        for (_, task) in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()
    }
    
    public func reset() {
        isCancelled = false
        activeTasks.removeAll()
    }
    
    public func shouldStop() -> Bool {
        return isCancelled
    }
}

public class DownloadEngine: ObservableObject {
    public let item: DownloadItem
    private var coordinator = DownloadSessionCoordinator()
    private var fileDescriptor: Int32 = -1
    private var speedTimer: Timer?
    
    // For rolling speed calculation
    private var lastBytesCount: Int64 = 0
    private var lastSpeedCheckTime: Date = Date()
    
    public init(item: DownloadItem) {
        self.item = item
        self.lastBytesCount = item.downloadedBytes
    }
    
    deinit {
        stopSpeedTimer()
        closeFile()
    }
    
    public func start() {
        guard !item.status.isActive else { return }
        
        DispatchQueue.main.async {
            self.item.status = .connecting
            self.item.errorMessage = nil
        }
        
        Task {
            await self.coordinator.reset()
            do {
                try await self.runDownload()
            } catch {
                await self.handleError(error)
            }
        }
    }
    
    public func pause() {
        Task {
            await self.coordinator.cancelAll()
            self.stopSpeedTimer()
            self.closeFile()
            
            await MainActor.run {
                self.item.status = .paused
                self.item.speedBytesPerSec = 0
                for i in 0..<self.item.segments.count {
                    if self.item.segments[i].status != .completed {
                        self.item.segments[i].status = .idle
                        self.item.segments[i].speedBytesPerSec = 0
                    }
                }
            }
        }
    }
    
    public func cancel() {
        pause()
    }
    
    // MARK: - Core Download Pipeline
    
    private func runDownload() async throws {
        // 1. Probe if totalBytes or range capability is unknown
        if item.totalBytes <= 0 {
            let probe = try await NetworkProbe.probe(url: item.url)
            await MainActor.run {
                self.item.totalBytes = probe.totalBytes
                self.item.supportsRange = probe.supportsRange
                if self.item.filename.isEmpty || self.item.filename == "download" {
                    self.item.filename = probe.suggestedFilename
                    self.item.category = FileUtils.categorize(filename: probe.suggestedFilename)
                }
            }
        }
        
        // 2. Prepare destination file
        let path = item.destinationPath
        let parentDir = URL(fileURLWithPath: path).deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        
        let fd = try FileUtils.allocateFile(at: path, size: max(0, item.totalBytes))
        self.fileDescriptor = fd
        
        // 3. Setup segments if range is supported
        if item.supportsRange && item.totalBytes > 0 {
            if item.segments.isEmpty {
                setupInitialSegments()
            }
            startSpeedTimer()
            
            await MainActor.run {
                self.item.status = .downloading
            }
            
            await downloadSegmentsConcurrently(fd: fd)
        } else {
            // Single stream fallback
            startSpeedTimer()
            await MainActor.run {
                self.item.status = .downloading
            }
            try await downloadSingleStream(fd: fd)
        }
        
        // 4. Verification and finalization
        closeFile()
        stopSpeedTimer()
        
        let shouldStop = await coordinator.shouldStop()
        if !shouldStop {
            await MainActor.run {
                self.item.status = .completed
                self.item.dateCompleted = Date()
                self.item.speedBytesPerSec = 0
                self.item.downloadedBytes = self.item.totalBytes > 0 ? self.item.totalBytes : self.item.downloadedBytes
                for i in 0..<self.item.segments.count {
                    self.item.segments[i].status = .completed
                    self.item.segments[i].downloadedBytes = self.item.segments[i].totalBytes
                    self.item.segments[i].speedBytesPerSec = 0
                }
            }
        }
    }
    
    private func setupInitialSegments() {
        let count = max(1, item.segmentCount)
        let total = item.totalBytes
        let chunkSize = total / Int64(count)
        
        var segments: [SegmentItem] = []
        for i in 0..<count {
            let start = Int64(i) * chunkSize
            let end = (i == count - 1) ? (total - 1) : (start + chunkSize - 1)
            let seg = SegmentItem(
                index: i + 1,
                startByte: start,
                endByte: end,
                downloadedBytes: 0,
                speedBytesPerSec: 0,
                status: .idle
            )
            segments.append(seg)
        }
        
        DispatchQueue.main.async {
            self.item.segments = segments
        }
    }
    
    private func downloadSegmentsConcurrently(fd: Int32) async {
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<item.segments.count {
                let segment = item.segments[i]
                if segment.downloadedBytes >= segment.totalBytes && segment.totalBytes > 0 {
                    await MainActor.run {
                        self.item.segments[i].status = .completed
                    }
                    continue
                }
                
                group.addTask {
                    await self.downloadSingleSegment(index: i, fd: fd)
                }
            }
        }
    }
    
    private func downloadSingleSegment(index: Int, fd: Int32) async {
        let segment = item.segments[index]
        let currentOffset = segment.startByte + segment.downloadedBytes
        guard currentOffset <= segment.endByte else {
            await MainActor.run {
                self.item.segments[index].status = .completed
            }
            return
        }
        
        await MainActor.run {
            self.item.segments[index].status = .transferring
        }
        
        var request = URLRequest(url: item.url)
        request.setValue("bytes=\(currentOffset)-\(segment.endByte)", forHTTPHeaderField: "Range")
        request.timeoutInterval = 30
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        sessionConfig.timeoutIntervalForRequest = 30
        let session = URLSession(configuration: sessionConfig)
        
        var segmentBytesRead: Int64 = 0
        let segStartTime = Date()
        
        do {
            let (asyncBytes, response) = try await session.bytes(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
            
            // Buffer size: 128 KB for Apple Silicon throughput
            let bufferCapacity = 131_072
            var buffer = Data()
            buffer.reserveCapacity(bufferCapacity)
            
            for try await byte in asyncBytes {
                if await coordinator.shouldStop() {
                    return
                }
                
                buffer.append(byte)
                if buffer.count >= bufferCapacity {
                    let writeOffset = segment.startByte + segment.downloadedBytes + segmentBytesRead
                    _ = FileUtils.writeSegmentData(fd: fd, offset: writeOffset, data: buffer)
                    segmentBytesRead += Int64(buffer.count)
                    buffer.removeAll(keepingCapacity: true)
                    
                    // Periodic UI update
                    let elapsed = Date().timeIntervalSince(segStartTime)
                    let currentSegSpeed = elapsed > 0.3 ? Double(segmentBytesRead) / elapsed : 0
                    
                    let totalDownloaded = segment.downloadedBytes + segmentBytesRead
                    await MainActor.run {
                        self.item.segments[index].downloadedBytes = totalDownloaded
                        self.item.segments[index].speedBytesPerSec = currentSegSpeed
                    }
                }
            }
            
            // Flush remaining buffer
            if !buffer.isEmpty {
                let writeOffset = segment.startByte + segment.downloadedBytes + segmentBytesRead
                _ = FileUtils.writeSegmentData(fd: fd, offset: writeOffset, data: buffer)
                segmentBytesRead += Int64(buffer.count)
            }
            
            let finalDownloaded = segment.downloadedBytes + segmentBytesRead
            await MainActor.run {
                self.item.segments[index].downloadedBytes = finalDownloaded
                self.item.segments[index].status = .completed
                self.item.segments[index].speedBytesPerSec = 0
            }
        } catch {
            if !(await coordinator.shouldStop()) {
                await MainActor.run {
                    self.item.segments[index].status = .failed(error.localizedDescription)
                }
            }
        }
    }
    
    private func downloadSingleStream(fd: Int32) async throws {
        var request = URLRequest(url: item.url)
        request.timeoutInterval = 30
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        let session = URLSession(configuration: .default)
        let (asyncBytes, response) = try await session.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let bufferCapacity = 131_072
        var buffer = Data()
        buffer.reserveCapacity(bufferCapacity)
        var totalBytesWritten: Int64 = item.downloadedBytes
        
        for try await byte in asyncBytes {
            if await coordinator.shouldStop() {
                return
            }
            
            buffer.append(byte)
            if buffer.count >= bufferCapacity {
                _ = FileUtils.writeSegmentData(fd: fd, offset: totalBytesWritten, data: buffer)
                totalBytesWritten += Int64(buffer.count)
                let currentProgress = totalBytesWritten
                buffer.removeAll(keepingCapacity: true)
                
                await MainActor.run {
                    self.item.downloadedBytes = currentProgress
                }
            }
        }
        
        if !buffer.isEmpty {
            _ = FileUtils.writeSegmentData(fd: fd, offset: totalBytesWritten, data: buffer)
            totalBytesWritten += Int64(buffer.count)
            let finalProgress = totalBytesWritten
            await MainActor.run {
                self.item.downloadedBytes = finalProgress
            }
        }
    }
    
    // MARK: - Speed and Progress Measurement
    
    private func startSpeedTimer() {
        stopSpeedTimer()
        lastBytesCount = item.downloadedBytes
        lastSpeedCheckTime = Date()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.speedTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                self?.calculateAggregateSpeed()
            }
        }
    }
    
    private func stopSpeedTimer() {
        DispatchQueue.main.async {
            self.speedTimer?.invalidate()
            self.speedTimer = nil
        }
    }
    
    private func calculateAggregateSpeed() {
        // Aggregate downloaded bytes across all segments
        let currentTotalDownloaded: Int64
        if item.supportsRange && !item.segments.isEmpty {
            currentTotalDownloaded = item.segments.reduce(0) { $0 + $1.downloadedBytes }
        } else {
            currentTotalDownloaded = item.downloadedBytes
        }
        
        let now = Date()
        let elapsed = now.timeIntervalSince(lastSpeedCheckTime)
        guard elapsed > 0.1 else { return }
        
        let deltaBytes = currentTotalDownloaded - lastBytesCount
        let instantaneousSpeed = max(0.0, Double(deltaBytes) / elapsed)
        
        // Exponential moving average for smooth display
        let alpha = 0.4
        let smoothedSpeed = (self.item.speedBytesPerSec * (1.0 - alpha)) + (instantaneousSpeed * alpha)
        
        self.item.downloadedBytes = currentTotalDownloaded
        self.item.speedBytesPerSec = smoothedSpeed
        
        self.lastBytesCount = currentTotalDownloaded
        self.lastSpeedCheckTime = now
    }
    
    private func handleError(_ error: Error) async {
        closeFile()
        stopSpeedTimer()
        
        await MainActor.run {
            self.item.status = .error(error.localizedDescription)
            self.item.errorMessage = error.localizedDescription
            self.item.speedBytesPerSec = 0
        }
    }
    
    private func closeFile() {
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
    }
}
