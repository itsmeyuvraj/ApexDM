import SwiftUI

public struct NewDownloadSheet: View {
    @EnvironmentObject public var downloadManager: DownloadManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var urlString: String = ""
    @State private var filename: String = ""
    @State private var destinationDir: URL = FileUtils.defaultDownloadDirectory()
    @State private var segmentCount: Int = 8
    
    // Probing state
    @State private var isProbing: Bool = false
    @State private var probedSize: Int64 = -1
    @State private var probedRangeSupport: Bool = false
    @State private var probeError: String? = nil
    
    public init(initialURL: String = "") {
        _urlString = State(initialValue: initialURL)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("Enter URL to Download")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 16) {
                // URL input
                VStack(alignment: .leading, spacing: 6) {
                    Text("Address (URL):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("https://example.com/file.zip", text: $urlString)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                probeURL()
                            }
                        
                        Button("Paste") {
                            if let string = NSPasteboard.general.string(forType: .string) {
                                urlString = string.trimmingCharacters(in: .whitespacesAndNewlines)
                                probeURL()
                            }
                        }
                        
                        Button(action: probeURL) {
                            if isProbing {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 16, height: 16)
                            } else {
                                Text("Inspect")
                            }
                        }
                        .disabled(urlString.isEmpty || isProbing)
                    }
                }
                
                // Probe info banner
                if isProbing {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Querying server for size and Range support...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } else if probedSize > 0 || !filename.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: probedRangeSupport ? "bolt.horizontal.fill" : "info.circle.fill")
                            .foregroundColor(probedRangeSupport ? .green : .blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Size: \(Formatters.formatBytes(probedSize))")
                                .font(.caption)
                                .fontWeight(.medium)
                            Text(probedRangeSupport ? "Multi-threaded accelerated download supported" : "Single-connection stream")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } else if let error = probeError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                
                // File Name
                VStack(alignment: .leading, spacing: 6) {
                    Text("File Name:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("filename.ext", text: $filename)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Save Folder
                VStack(alignment: .leading, spacing: 6) {
                    Text("Save To:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text(destinationDir.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        
                        Button("Choose...") {
                            chooseDirectory()
                        }
                    }
                }
                
                // Connection Count (Segments)
                HStack {
                    Text("Parallel Connections:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $segmentCount) {
                        Text("4 connections").tag(4)
                        Text("8 connections (Recommended)").tag(8)
                        Text("16 connections (High Speed)").tag(16)
                        Text("32 connections (Max)").tag(32)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 220)
                }
            }
            .padding(20)
            
            Divider()
            
            // Action Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Download Later") {
                    createDownload(startImmediately: false)
                }
                .buttonStyle(.bordered)
                .disabled(urlString.isEmpty)
                
                Button("Download Now") {
                    createDownload(startImmediately: true)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(urlString.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 520)
        .onAppear {
            segmentCount = downloadManager.defaultSegmentCount
            if !urlString.isEmpty {
                probeURL()
            }
        }
    }
    
    private func probeURL() {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme != nil, url.host != nil else {
            return
        }
        
        isProbing = true
        probeError = nil
        
        Task {
            do {
                let result = try await NetworkProbe.probe(url: url)
                await MainActor.run {
                    self.isProbing = false
                    self.probedSize = result.totalBytes
                    self.probedRangeSupport = result.supportsRange
                    if self.filename.isEmpty {
                        self.filename = result.suggestedFilename
                    }
                }
            } catch {
                await MainActor.run {
                    self.isProbing = false
                    self.probeError = "Could not probe headers (\(error.localizedDescription)). Will probe on start."
                    if self.filename.isEmpty {
                        self.filename = FileUtils.sanitizeFilename(url.lastPathComponent)
                    }
                }
            }
        }
    }
    
    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select"
        
        if panel.runModal() == .OK, let selected = panel.url {
            self.destinationDir = selected
        }
    }
    
    private func createDownload(startImmediately: Bool) {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
        let cleanName = filename.isEmpty ? nil : filename
        
        downloadManager.addDownload(
            url: url,
            customFilename: cleanName,
            destinationDir: destinationDir,
            segmentCount: segmentCount,
            startImmediately: startImmediately
        )
        dismiss()
    }
}
