//
//  jglyptApp.swift
//  Feeds
//
//  Created by Tim on 29.05.25.
//

import SwiftUI
import UserNotifications


@main
struct jglyptApp: App {
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow
    @StateObject var settingsManager = SettingsManager.shared

    var body: some Scene {
        WindowGroup(id: "mainWindow") {
            WelcomeView(titleText: "Welcome to \(Bundle.main.applicationName ?? "Feeds")")
            .padding(5)
            .background(.thickMaterial)
            .background(
                WindowAccessor(callback: { window in
                    window?.isMovableByWindowBackground = true
                })
            )
            .cornerRadius(10)
//            DecodingView()
//                .cornerRadius(5)
            .onOpenURL(perform: { url in
                Task { await importFromURL(url) }
            })
            .task {
                try? await Task.sleep(for: .seconds(1))
                self.checkAndRequestNotificationPermission()
            }
        }
        .windowStyle(.plain)
        .commands(content: {
            if settingsManager.debug {
                CommandMenu("Debug", content: {
                    Button("Open Notification Begger") {
                        openWindow.callAsFunction(id: "grantNotificationPermission")
                    }
                    Button("Close all Notification Beggers") {
                        dismissWindow.callAsFunction(id: "grantNotificationPermission")
                    }
                })
            }
        })
        WindowGroup(id: "loading", for: String.self) { string in
            VStack {
                Text(string.wrappedValue ?? "Loading")
                    .bold()
                ProgressView()
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(15)
            .background(WindowAccessor(callback: { window in
                window?.forceBecomeKeyWindow()
            }))
        }
        .windowLevel(.floating)
        .windowStyle(.plain)

        WindowGroup(id: "grantNotificationPermission") {
            let screen = NSScreen.main!

            VStack {
                ZStack {
                    if let screen = NSScreen.main {
                        AsyncImage(url: NSWorkspace.shared.desktopImageURL(for: screen), content: { image in
                            image
                                .resizable()
                                .scaledToFill()
                                // Align the top-right corner
                                .scaleEffect(2)
                        }, placeholder: {
                            Color(nsColor: .windowBackgroundColor)
                        })
                    } else {
                        Color.black
                    }
                    VStack(spacing: 25) {
                        VStack {
                            Text("Please accept Notification Permissions")
                                .font(.title)
                                .bold()
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                            Text("Notifications are used to deliver critical Errors or information")
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                            
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(15)
                        HStack {
                            Button(action: {
                                dismissWindow.callAsFunction(id: "grantNotificationPermission")
                            }) {
                                Text("I DON'T CARE")
                                    .padding(10)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(15)
                            }
                            .buttonStyle(.plain)
                            Button(action: {
                                let notificationsPath = "x-apple.systempreferences:com.apple.Notifications-Settings.extension"
                                let bundleId = Bundle.main.bundleIdentifier
                                if let url = URL(string: "\(notificationsPath)?id=\(bundleId ?? "")") {
                                    NSWorkspace.shared.open(url)
                                }
                                dismissWindow.callAsFunction(id: "grantNotificationPermission")
                            }) {
                                Text("SETTINGS")
                                    .padding(10)
                                    .background(.tint.opacity(0.5))
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(15)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(width: screen.frame.width / 4, height: screen.frame.height / 4)
                .clipped()
                
            }
            .background(
                WindowAccessor(callback: { window in
                    window?.isMovableByWindowBackground = true
                })
            )
            .cornerRadius(25)
            .padding(25)
            .overlay(alignment: .topTrailing, content: {
                HStack(alignment: .center) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                    VStack(alignment: .leading) {
                        Text("\"\(Bundle.main.applicationName ?? "Feeds")\" Notifications")
                            .bold()
                        Text("Notifications may include alerts, sounds and icon badges.")
                    }
                }
                .frame(width: 300, height: 50)
                .padding(10)
                .background(.ultraThinMaterial)
                .cornerRadius(15)
            })
        }
        .handlesExternalEvents(matching: ["grantNotificationPermissionEvent"])
        .windowStyle(.plain)
        .defaultWindowPlacement { content, context in
            return WindowPlacement(.center, size: context.defaultDisplay.bounds.size)
        }
        .windowIdealPlacement { content, context in
            return WindowPlacement(.center, size: context.defaultDisplay.bounds.size)
        }
        WindowGroup(id: "feedWindow", for: Feed.self, content: { feed in
            NavigationStack {
                if let unwrappedFeed = feed.wrappedValue {
                    FeedViewer(feed: unwrappedFeed)
                        .navigationTitle("Feed: " + unwrappedFeed.title)
// Turn App Icon into Feed Icon
                        .task {
                            if settingsManager.setAppIcon {
                                if let nsImage = await unwrappedFeed.icon.fetchNSImage() {
                                    if nsImage.isMostlyWhiteOpaquePixels() {
                                        NSApp.applicationIconImage = nsImage.roundedIconCustomBG(color: .black)
                                    } else {
                                        NSApp.applicationIconImage = nsImage.roundedIconCustomBG(color: .white)
                                    }
                                }
                            }
                        }
                } else {
                    Text("Feed Empty")
                        .font(.title)
                        .bold()
                        .foregroundStyle(.gray)
                }
            }
        })
        .handlesExternalEvents(matching: ["feedWindowEvent"])
        WindowGroup(id: "createPost") {
            PostingView()
        }
        .handlesExternalEvents(matching: ["createPostEvent"])
        Settings {
            Form {
                Picker("Default Feed Importing Method", selection: $settingsManager.defaultImportMethod) {
                    Text("None")
                        .tag("none")
                    Text("From URL")
                        .tag("url")
                    Text("From File")
                        .tag("file")
                }
                Toggle("Change App Icon to opened Feed", isOn: $settingsManager.setAppIcon)
                TextField("Microblog Token", text: Binding(get: {
                    settingsManager.token ?? ""
                }, set: { newValue in
                    settingsManager.token = newValue.isEmpty ? nil : newValue
                }))
            }
            .formStyle(.grouped)
        }
    }
    
    func startLoadingWindow(for string: String? = nil) {
        openWindow.callAsFunction(id: "loading", value: string ?? "Loading...")
    }
    func stopLoadingWindow() {
        dismissWindow.callAsFunction(id: "loading")
    }
    func openFeed(url: URL) {
        startLoadingWindow(for: "Decoding Feed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let data = try? Data(contentsOf: url), let decoded = try? decoder.decode(Feed.self, from: data) {
                openWindow.callAsFunction(id: "feedWindow", value: decoded)
            }
            stopLoadingWindow()
        }
    }
    func importFromURL(_ input: URL) async {
        do {
            let url: URL = input
            let data: Data
            if url.isFileURL {
                data = try Data(contentsOf: url)
            } else {
                (data, _) = try await URLSession.shared.data(for: URLRequest(url: url))
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            print("Decoding")
            let decoded = try decoder.decode(Feed.self, from: data)
            ProjectManager.shared.addFile(file: decoded, fileName: url.lastPathComponent, onError: { error in
                sendErrorNotif(error.localizedDescription)
            })
            
        } catch {
            let alert = NSAlert()
            alert.window.toolbarStyle = .unifiedCompact
            alert.messageText = "Error Importing Feed"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "OK")

            alert.runModal()
        }
    }
    func checkAndRequestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                break
            case .denied, .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
                    if let error = error {
                        print("Error requesting notification permission: \(error)")
                    }
                    DispatchQueue.main.async {
                        openWindow.callAsFunction(id: "grantNotificationPermission")
                    }
                }
            @unknown default:
                break
            }
        }
    }
    func checkNotificationsGranted() async -> Bool {
        let center = UNUserNotificationCenter.current()
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional:
            return true
        case .denied, .notDetermined:
            return false
        @unknown default:
            return false
        }
        
    }

}

struct WindowAccessor: NSViewRepresentable {
    var callback: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.callback(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

import AppKit

struct WelcomeView: View {
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow
    @State var resetSelection = false
    let titleText: String
    @StateObject var projectManager = ProjectManager.shared
    @StateObject var settingsManager = SettingsManager.shared
    @State var importFeedFile = false
    @State var debugCount = 0
    var body: some View {
        ZStack {
            HStack(alignment: .top, spacing: 0.0) {
                VStack(alignment: .center, spacing: 0.0) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140.0, height: 140.0)
                        .background {
                            Image(nsImage: NSApp.applicationIconImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 140.0, height: 140.0)
                                .blur(radius: 50)
                        }
                        .simultaneousGesture (
                            TapGesture()
                                .onEnded { _ in
                                    debugCount += 1
                                    if debugCount == 10 {
                                        settingsManager.debug.toggle()
                                        debugCount = 0
                                    }
                                }
                        )
                    
                    Spacer().frame(height: 3.0)
                    
                    Text(titleText)
                        .font(.system(size: 36.0))
                        .bold()
                    
                    Spacer().frame(height: 7.0)
                    
                    Text("Version \(getCurrentAppVersion())")
                        .font(.system(size: 13.0))
                        .fontWeight(.light)
                        .foregroundColor(.gray)
                    
                    Spacer()
                        .frame(minHeight: max(24.0, min(6.0, (CGFloat(1) - 2.0) * 6.0)))
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Button(action: {
                            openWindow.callAsFunction(id: "createPost")
                        }) {
                            HStack {
                                Image(systemName: "plus.app")
                                    .foregroundStyle(.gray)
                                    .font(.system(size: 17.5, weight: .medium))
                                    .frame(width: 25)
                                Text("Create New Post...")
                                    .font(.system(size: 12.5, weight: .semibold))
                                Spacer()
                            }
                            .padding(7.5)
                            .background(.gray.opacity(0.10))
                            .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                        Button(action: {
                            switch settingsManager.defaultImportMethod {
                            case "url":
                                Task { await importFromURL() }
                            case "file":
                                importFeedFile = true
                            default:
                                let alert = NSAlert()
                                alert.window.toolbarStyle = .unifiedCompact
                                alert.messageText = "Where do you want to import the Feed from?"
                                alert.addButton(withTitle: "From URL")
                                alert.addButton(withTitle: "From File")
                                // Add a checkbox (toggle)
                                let checkbox = NSButton(checkboxWithTitle: "Remember this Choice", target: nil, action: nil)
                                alert.accessoryView = checkbox
                                
                                let response = alert.runModal()
                                
                                if response == .alertFirstButtonReturn {
                                    // URL Pressed
                                    if checkbox.state == .on {
                                        settingsManager.defaultImportMethod = "url"
                                    }
                                    Task { await importFromURL() }
                                } else {
                                    // File Pressed
                                    if checkbox.state == .on {
                                        settingsManager.defaultImportMethod = "file"
                                    }
                                    importFeedFile = true
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: "folder")
                                    .foregroundStyle(.gray)
                                    .font(.system(size: 17.5, weight: .medium))
                                    .frame(width: 25)
                                
                                Text("Import Feed...")
                                    .font(.system(size: 12.5, weight: .semibold))
                                Spacer()
                            }
                            .padding(7.5)
                            .background(.gray.opacity(0.10))
                            .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                        .fileImporter(isPresented: $importFeedFile, allowedContentTypes: [.json], onCompletion: { result in
                            switch result {
                            case .success(let success):
                                Task {
                                    await importFromURL(success)
                                }
                            case .failure(let failure):
                                print(failure.localizedDescription)
                            }
                        })
                    }
                    .padding(.horizontal, 35)
                }
                .frame(width: 414.0)
                .padding(40.0)
                VStack {
                    if projectManager.recentFiles.isEmpty {
                        VStack {
                            Spacer()
                            Text("No Recent Feeds")
                                .bold()
                                .foregroundStyle(.gray)
                            Spacer()
                        }
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(projectManager.recentFiles, id: \.self) { fileURL in
                                    RecentFileView(fileURL: fileURL, action: { url in
                                        openFeed(url: url)
                                    }, resetSelection: $resetSelection)
                                }
                                
                                Spacer()
                            }
                            .padding(5)
                            
                        }
                    }
                }
                .frame(width: 250)
                .background(.gray.opacity(0.10))
                .onTapGesture {
                    resetSelection = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                        resetSelection = false
                    })
                }
                .cornerRadius(7.5)
            }
            Button(action: {
                dismissWindow.callAsFunction(id: "mainWindow")
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.gray.opacity(0.50))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: 450, alignment: .topLeading)
            .padding(5)
        }
        .frame(width: 745, height: 450.0)
    }
    private func getCurrentAppVersion() -> String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"]
        let version = (appVersion as! String)
        return version
    }
    func askForURL() throws -> URL {
        var url: URL? = nil
        
        repeat {
            let alert = NSAlert()
            alert.messageText = "Enter JSON URL"
            alert.informativeText = "Please enter a URL to the JSON Feed you want to import"
            alert.alertStyle = .informational
            
            let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
            alert.accessoryView = textField
            
            alert.addButton(withTitle: "Import")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                let text = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if let validURL = URL(string: text), validURL.scheme != nil {
                    url = validURL
                } else {
                    let errorAlert = NSAlert()
                    errorAlert.messageText = "Invalid URL"
                    errorAlert.informativeText = "The URL you entered is invalid. Please enter a valid URL."
                    errorAlert.alertStyle = .critical
                    errorAlert.addButton(withTitle: "OK")
                    errorAlert.runModal()
                }
            } else {
                throw CancellationError()
            }
        } while url == nil
        
        return url!
    }
    func importFromURL(_ input: URL? = nil) async {
        do {
            let url: URL
            if let input = input {
                url = input
            } else {
                url = try askForURL()
            }
            let data: Data
            if url.isFileURL {
                data = try Data(contentsOf: url)
            } else {
                (data, _) = try await URLSession.shared.data(for: URLRequest(url: url))
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            print("Decoding")
            let decoded = try decoder.decode(Feed.self, from: data)
            projectManager.addFile(file: decoded, fileName: url.lastPathComponent, onError: { error in
                sendErrorNotif(error.localizedDescription)
            })
            openFeed(url: projectManager.recentFiles.last!)
            
        } catch {
            let alert = NSAlert()
            alert.window.toolbarStyle = .unifiedCompact
            alert.messageText = "Error Importing Feed"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "OK")
            
            alert.runModal()
        }
    }
    func startLoadingWindow(for string: String? = nil) {
        openWindow.callAsFunction(id: "loading", value: string ?? "Loading...")
    }
    func stopLoadingWindow() {
        dismissWindow.callAsFunction(id: "loading")
    }
    func openFeed(url: URL) {
        startLoadingWindow(for: "Decoding Feed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let data = try? Data(contentsOf: url), let decoded = try? decoder.decode(Feed.self, from: data) {
                openWindow.callAsFunction(id: "feedWindow", value: decoded)
            }
            stopLoadingWindow()
        }
    }
}

import Foundation
import Combine

class ProjectManager: ObservableObject {
    static let shared = ProjectManager()
    let homeDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("Feeds-Recent-Files", conformingTo: .folder)
    @Published var recentFiles: [URL] = []
    
    private var folderDescriptor: CInt = -1
    private var folderWatcherSource: DispatchSourceFileSystemObject?

    init() {
        if !FileManager.default.fileExists(atPath: homeDir.path()) {
            try? FileManager.default.createDirectory(at: homeDir, withIntermediateDirectories: true)
        }
        if let existingFiles = try? FileManager.default.contentsOfDirectory(at: homeDir, includingPropertiesForKeys: [.isHiddenKey]) {
            recentFiles = existingFiles.filter { url in
                (try? url.resourceValues(forKeys: [.isHiddenKey]).isHidden) != true
            }
        }

        
        startWatchingFolder()
    }
    
    private func startWatchingFolder() {
        folderDescriptor = open(homeDir.path, O_EVTONLY)
        guard folderDescriptor != -1 else {
            print("Failed to open folder descriptor for \(homeDir.path)")
            return
        }
        
        folderWatcherSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: folderDescriptor, eventMask: [.write, .delete, .rename], queue: DispatchQueue.global())
        
        folderWatcherSource?.setEventHandler { [weak self] in
            guard let self = self else { return }
            
            // Refresh recentFiles on folder change
            if let updatedFiles = try? FileManager.default.contentsOfDirectory(at: self.homeDir, includingPropertiesForKeys: [.isHiddenKey]) {
                let visibleFiles = updatedFiles.filter { url in
                    (try? url.resourceValues(forKeys: [.isHiddenKey]).isHidden) != true
                }
                DispatchQueue.main.async {
                    self.recentFiles = visibleFiles
                }
            }

        }
        
        folderWatcherSource?.setCancelHandler { [weak self] in
            guard let self = self else { return }
            close(self.folderDescriptor)
            self.folderDescriptor = -1
            self.folderWatcherSource = nil
        }
        
        folderWatcherSource?.resume()
    }
    
    func addFile(file: Feed, fileName: String, onError: @escaping (Error) -> Void) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var newFileURL = homeDir.appendingPathComponent(fileName, conformingTo: .json)
        var finalFileName = fileName

        while FileManager.default.fileExists(atPath: newFileURL.path) {
            let alert = NSAlert()
            alert.messageText = "Change Name"
            alert.informativeText = "Please choose a new name other than \"\(finalFileName)\""
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")

            let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
            inputField.stringValue = finalFileName
            alert.accessoryView = inputField

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                let newName = inputField.stringValue
                if newName.isEmpty {
                    continue // Empty names are not allowed
                }
                finalFileName = newName
                newFileURL = homeDir.appendingPathComponent(finalFileName, conformingTo: .json)
            } else {
                onError(CancellationError())
                return
            }
        }

        do {
            if !FileManager.default.fileExists(atPath: homeDir.path) {
                try FileManager.default.createDirectory(at: homeDir, withIntermediateDirectories: true)
            }
            try encoder.encode(file).write(to: newFileURL)
            recentFiles.append(newFileURL)
        } catch {
            onError(error)
        }
    }
}

import SwiftKeychainWrapper

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    init() {
        self.token = KeychainWrapper.standard.string(forKey: "microblogKey")
    }
    @AppStorage("defaultImportMethod") var defaultImportMethod = "none"
    @AppStorage("setAppIcon") var setAppIcon = false
    @AppStorage("debug") var debug = false

    @Published var token: String?
}

import UniformTypeIdentifiers

struct RecentFileView: View {
    init(fileURL: URL, action: @escaping (URL) -> Void, resetSelection: Binding<Bool>) {
        self.fileURL = fileURL
        self.filePath = fileURL.path().removing(fileURL.lastPathComponent)
        if !fileURL.pathExtension.isEmpty {
            self.fileName = fileURL.lastPathComponent.removing(".\(fileURL.pathExtension)")
        } else {
            self.fileName = fileURL.lastPathComponent
        }
        self.openAction = action
        self._resetSelection = resetSelection
        self.fileExtension = fileURL.pathExtension
    }
    let fileURL: URL
    let filePath: String
    let fileName: String
    let fileExtension: String
    var openAction: (URL) -> Void
    @State var selected = false
    @Binding var resetSelection: Bool
    @State var immuneToReset = false
    @State var pressedBefore = false
    @State var renameFile = false
    @StateObject var projectManager = ProjectManager.shared
    var body: some View {
        if fileURL.isFileURL {
            HStack {
                Image(nsImage: NSWorkspace.shared.icon(for: UTType(filenameExtension: fileExtension) ?? .data))
                    .font(.system(size: 25))
                VStack(alignment: .leading) {
                    Text(fileName)
                        .bold()
                        .lineLimit(1)
                    
                    Text(filePath)
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(7.5)
            .background(.tint.secondary.opacity(selected ? 1 : 0))
            .cornerRadius(5)
            .contentShape(.rect)
            .onTapGesture {
                if pressedBefore {
                    openAction(fileURL)
                    pressedBefore = false
                } else {
                    pressedBefore = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.75, execute: { pressedBefore = false }
                    )
                }
                resetSelection = true
                immuneToReset = true
                selected = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    resetSelection = false
                    immuneToReset = false
                }
                
            }
            .onChange(of: resetSelection) { bool in
                if !immuneToReset {
                    if bool {
                        selected = false
                    }
                }
            }
            .contextMenu {
                Button("Rename") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                        var cancel = false
                        let data = try! Data(contentsOf: fileURL)
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .iso8601
                        
                        projectManager.addFile(file: try! decoder.decode(Feed.self, from: data), fileName: fileName, onError: { error in
                            cancel = true
                            sendErrorNotif(error.localizedDescription)
                        })
                        if !cancel {
                            if (try? FileManager.default.removeItem(at: fileURL)) != nil {
                                projectManager.recentFiles.remove(at: projectManager.recentFiles.firstIndex(of: fileURL)!)
                            }
                        }

                    })
                }
                Button("Delete") {
                    if (try? FileManager.default.removeItem(at: fileURL)) != nil {
                        projectManager.recentFiles.remove(at: projectManager.recentFiles.firstIndex(of: fileURL)!)
                    }
                }
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                }
            }
        }
    }
}

import Cocoa
import UserNotifications

func sendErrorNotif(_ errorString: String) {
    let center = UNUserNotificationCenter.current()
    let content = UNMutableNotificationContent()
    content.title = "Error"
    content.body = errorString
    content.sound = UNNotificationSound.default

    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)

    center.requestAuthorization(options: [.alert, .sound]) { granted, error in
        if granted && error == nil {
            center.add(request)
        } else {
            print("Notification not authorized: \(String(describing: error))")
        }
    }
}
