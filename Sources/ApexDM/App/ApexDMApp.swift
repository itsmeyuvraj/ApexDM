import SwiftUI
import AppKit

@main
public struct ApexDMApp: App {
    @StateObject private var downloadManager = DownloadManager()
    
    public init() {}
    
    public var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environmentObject(downloadManager)
                .frame(minWidth: 840, minHeight: 480)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Download...") {
                    downloadManager.initialURLForSheet = ""
                    downloadManager.isShowingNewDownloadSheet = true
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            CommandMenu("Downloads") {
                Button("Resume All") {
                    downloadManager.resumeAll()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                
                Button("Pause All") {
                    downloadManager.pauseAll()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
        }
    }
}
