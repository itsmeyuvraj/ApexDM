import Foundation

public struct ProbeResult: Sendable {
    public let finalURL: URL
    public let suggestedFilename: String
    public let totalBytes: Int64
    public let supportsRange: Bool
}

public enum NetworkProbe {
    public static func probe(url: URL) async throws -> ProbeResult {
        var headRequest = URLRequest(url: url)
        headRequest.httpMethod = "HEAD"
        headRequest.timeoutInterval = 15
        headRequest.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: config)
        
        do {
            let (_, response) = try await session.data(for: headRequest)
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                return parseResponse(httpResponse, originalURL: url)
            }
        } catch {
            // Some servers reject HEAD requests with 405 Method Not Allowed or drop connection
            // Fall back to GET range 0-0
        }
        
        // Fallback: GET with Range: bytes=0-0
        var getRequest = URLRequest(url: url)
        getRequest.httpMethod = "GET"
        getRequest.setValue("bytes=0-0", forHTTPHeaderField: "Range")
        getRequest.timeoutInterval = 15
        getRequest.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        let (_, response) = try await session.data(for: getRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        return parseResponse(httpResponse, originalURL: url)
    }
    
    private static func parseResponse(_ response: HTTPURLResponse, originalURL: URL) -> ProbeResult {
        let headers = response.allHeaderFields
        let finalURL = response.url ?? originalURL
        
        // 1. Check Range support
        var supportsRange = false
        if let acceptRanges = headers["Accept-Ranges"] as? String,
           acceptRanges.lowercased().contains("bytes") {
            supportsRange = true
        }
        if response.statusCode == 206 { // Partial Content returned for bytes=0-0
            supportsRange = true
        }
        
        // 2. Check Content-Length & Content-Range
        var totalBytes: Int64 = -1
        if let contentRange = headers["Content-Range"] as? String {
            // Example format: "bytes 0-0/104857600"
            if let slashIndex = contentRange.lastIndex(of: "/") {
                let totalPart = String(contentRange[contentRange.index(after: slashIndex)...]).trimmingCharacters(in: .whitespaces)
                if let size = Int64(totalPart) {
                    totalBytes = size
                    supportsRange = true
                }
            }
        }
        
        if totalBytes < 0, let contentLengthStr = headers["Content-Length"] as? String, let size = Int64(contentLengthStr) {
            totalBytes = size
        }
        if totalBytes < 0 {
            totalBytes = response.expectedContentLength
        }
        
        // If totalBytes is small or unknown, range might not be practical
        if totalBytes <= 0 {
            supportsRange = false
        }
        
        // 3. Extract filename
        var filename: String? = nil
        if let disposition = headers["Content-Disposition"] as? String {
            filename = extractFilename(from: disposition)
        }
        
        if filename == nil || filename!.isEmpty {
            let lastComponent = finalURL.lastPathComponent
            if !lastComponent.isEmpty && lastComponent != "/" {
                filename = lastComponent
            }
        }
        
        let cleanName = FileUtils.sanitizeFilename(filename ?? "download")
        return ProbeResult(
            finalURL: finalURL,
            suggestedFilename: cleanName,
            totalBytes: totalBytes,
            supportsRange: supportsRange
        )
    }
    
    private static func extractFilename(from disposition: String) -> String? {
        // e.g. attachment; filename="large_file.zip" or filename*=UTF-8''large_file.zip
        let components = disposition.components(separatedBy: ";")
        for part in components {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().starts(with: "filename*=") {
                let value = trimmed.dropFirst("filename*=".count)
                if let utf8Index = value.range(of: "''") {
                    let namePart = String(value[utf8Index.upperBound...])
                    if let decoded = namePart.removingPercentEncoding {
                        return decoded.trimmingCharacters(in: CharacterSet(charactersIn: "\"\'"))
                    }
                }
            } else if trimmed.lowercased().starts(with: "filename=") {
                let value = trimmed.dropFirst("filename=".count)
                return String(value).trimmingCharacters(in: CharacterSet(charactersIn: "\"\' \t"))
            }
        }
        return nil
    }
}
