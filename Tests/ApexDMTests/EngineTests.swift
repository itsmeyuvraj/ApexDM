import XCTest
@testable import ApexDM

final class EngineTests: XCTestCase {
    
    func testFormatters() {
        XCTAssertEqual(Formatters.formatBytes(1000), "1 KB")
        XCTAssertEqual(Formatters.formatBytes(1_000_000), "1 MB")
        XCTAssertEqual(Formatters.formatBytes(1_000_000_000), "1 GB")
        
        XCTAssertEqual(Formatters.formatSpeed(1_000_000), "1 MB/s")
        XCTAssertEqual(Formatters.formatETA(remainingBytes: 10_000_000, speedBytesPerSec: 1_000_000), "10s")
        XCTAssertEqual(Formatters.formatPercentage(0.5), "50.0%")
    }
    
    func testFileCategorization() {
        XCTAssertEqual(FileUtils.categorize(filename: "archive.zip"), .compressed)
        XCTAssertEqual(FileUtils.categorize(filename: "movie.mkv"), .video)
        XCTAssertEqual(FileUtils.categorize(filename: "track.flac"), .music)
        XCTAssertEqual(FileUtils.categorize(filename: "document.pdf"), .documents)
        XCTAssertEqual(FileUtils.categorize(filename: "installer.dmg"), .compressed)
        XCTAssertEqual(FileUtils.categorize(filename: "unknown.xyz"), .others)
    }
    
    func testSegmentCalculations() {
        let seg = SegmentItem(
            index: 1,
            startByte: 0,
            endByte: 999,
            downloadedBytes: 500,
            speedBytesPerSec: 100,
            status: .transferring
        )
        
        XCTAssertEqual(seg.totalBytes, 1000)
        XCTAssertEqual(seg.progress, 0.5)
        XCTAssertEqual(seg.currentOffset, 500)
    }
    
    func testConcurrentPwriteZeroFragmentation() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("pwrite_test_\(UUID().uuidString).bin")
        let totalSize: Int64 = 4096
        
        let fd = try FileUtils.allocateFile(at: testFile.path, size: totalSize)
        defer {
            close(fd)
            try? FileManager.default.removeItem(at: testFile)
        }
        
        // Write chunk 2 (bytes 2048 to 4095) FIRST
        let chunk2Data = Data(repeating: 0xBB, count: 2048)
        let success2 = FileUtils.writeSegmentData(fd: fd, offset: 2048, data: chunk2Data)
        XCTAssertTrue(success2)
        
        // Write chunk 1 (bytes 0 to 2047) SECOND
        let chunk1Data = Data(repeating: 0xAA, count: 2048)
        let success1 = FileUtils.writeSegmentData(fd: fd, offset: 0, data: chunk1Data)
        XCTAssertTrue(success1)
        
        // Read back entire file and verify integrity
        let readData = try Data(contentsOf: testFile)
        XCTAssertEqual(readData.count, 4096)
        XCTAssertEqual(readData[0], 0xAA)
        XCTAssertEqual(readData[2047], 0xAA)
        XCTAssertEqual(readData[2048], 0xBB)
        XCTAssertEqual(readData[4095], 0xBB)
    }
}
