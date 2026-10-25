import SwiftUI

public struct SettingsView: View {
    @AppStorage("defaultSegmentCount") private var defaultSegmentCount: Int = 8
    @AppStorage("clipboardMonitoringEnabled") private var clipboardMonitoringEnabled: Bool = true
    @State private var defaultDownloadPath: String = FileUtils.defaultDownloadDirectory().path
    
    public init() {}
    
    public var body: some View {
        Form {
            Section("Download Engine (Apple Silicon)") {
                Picker("Default Parallel Connections:", selection: $defaultSegmentCount) {
                    Text("4 connections").tag(4)
                    Text("8 connections (Recommended)").tag(8)
                    Text("16 connections (High Speed)").tag(16)
                    Text("32 connections (Max)").tag(32)
                }
                .pickerStyle(.menu)
                .help("Number of concurrent HTTP Range threads allocated per multi-part download.")
                
                Toggle("Auto-sniff URLs from Clipboard", isOn: $clipboardMonitoringEnabled)
                    .help("Automatically opens the download dialog when a downloadable file URL is copied.")
            }
            
            Section("Storage & File System") {
                HStack {
                    Text("Default Directory:")
                    Spacer()
                    Text(defaultDownloadPath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Button("Choose...") {
                        selectFolder()
                    }
                }
                
                Text("Optimized for APFS: files are pre-allocated and written concurrently with atomic pwrite, eliminating the need to concatenate chunks at completion.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Section("System & Hardware") {
                LabeledContent("Architecture", value: "Apple Silicon Native (arm64)")
                LabeledContent("Multi-threading", value: "Swift Concurrency + POSIX Direct I/O")
                LabeledContent("Version", value: "ApexDM 1.0.0")
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 340)
        .navigationTitle("Preferences")
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        
        if panel.runModal() == .OK, let selected = panel.url {
            defaultDownloadPath = selected.path
        }
    }
}
