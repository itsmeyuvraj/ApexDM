import Foundation

public enum Formatters {
    private static let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()
    
    public static func formatBytes(_ bytes: Int64) -> String {
        if bytes < 0 { return "Unknown" }
        return byteCountFormatter.string(fromByteCount: bytes)
    }
    
    public static func formatSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond <= 0 { return "0 B/s" }
        let formatted = formatBytes(Int64(bytesPerSecond))
        return "\(formatted)/s"
    }
    
    public static func formatETA(remainingBytes: Int64, speedBytesPerSec: Double) -> String {
        guard speedBytesPerSec > 100, remainingBytes > 0 else {
            return remainingBytes <= 0 ? "Complete" : "--:--"
        }
        
        let seconds = Double(remainingBytes) / speedBytesPerSec
        if seconds > 86400 * 7 {
            return "> 7 days"
        }
        
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%02dh %02dm %02ds", hours, minutes, secs)
        } else if minutes > 0 {
            return String(format: "%02dm %02ds", minutes, secs)
        } else {
            return String(format: "%02ds", secs)
        }
    }
    
    public static func formatPercentage(_ fraction: Double) -> String {
        let percent = max(0.0, min(100.0, fraction * 100.0))
        return String(format: "%.1f%%", percent)
    }
}
