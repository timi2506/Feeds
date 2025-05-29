//
//  ContentView.swift
//  Feeds
//
//  Created by Tim on 29.05.25.
//

import SwiftUI
import WebViewKit
import SafariServices

struct DecodingView: View {
    @State var stringToDecode: String = ""
    @State var output: Output?
    @Environment(\.openWindow) private var openWindow
    @State var feed: Feed?

    var body: some View {
        VStack {
            TextEditor(text: $stringToDecode)
                .cornerRadius(15)
            Button("Decode") {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                do {
                    let decoded = try decoder.decode(Feed.self, from: stringToDecode.data(using: .utf8) ?? Data())
                    feed = decoded
                    output = Output(output: "Successfully decoded: \(decoded)")
                    openWindow.callAsFunction(id: "feedWindow", value: feed!)
                } catch {
                    output = Output(output: error.localizedDescription)
                }
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        }
        .padding()
    }
}

import QuickLook

struct FeedViewer: View {
    @Environment(\.openWindow) private var openWindow
    @State var expandInfos = false
    @State var allTags: [String] = []
    @State var filterTags: Set<String> = []
    @State var filterContainAllTags = true
    let feed: Feed
    @State var url: URL?

    var body: some View {
        Form {
            Section("Feed Infos", isExpanded: $expandInfos) {
                Text(feed.feedURL.absoluteString)
                InfoStack(title: "Home Page", value: feed.homePageURL.absoluteString)
                HStack {
                    Text("Icon")
                    Spacer()
                    AsyncImage(url: feed.icon, content: { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .cornerRadius(5)
                    }, placeholder: {
                        Color.black
                    })
                }
                InfoStack(title: "Item count", value: feed.items.count.description)
                InfoStack(title: "Version", value: feed.version.absoluteString)
            }

            ForEach(feed.items, id: \.self.id) { feedItem in
                if containedInFilterTags(feedItem.tags) {
                    Section(content: {
                        HTMLView(htmlString: feedItem.contentHTML)
                        if let tags = feedItem.tags {
                            InfoStack(title: "Tags", value: tags.joined(separator: ", "))
                        }
                    }, header: {
                        HStack {
                            Text(feedItem.id)
                            Spacer()
                            Button("Preview") {
                                url = feedItem.url
                            }
                            .fontWeight(.regular)
                        }
                    })
                    .quickLookPreview($url)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            getFeedItems(set: true, $allTags)
        }
        .onChange(of: feed) {
            getFeedItems(set: true, $allTags)
        }
        .toolbar {
            Menu("Filter by Tags") {
                Section {
                    Toggle("Must contain all Tags", isOn: $filterContainAllTags)
                }
                if allTags.isEmpty {
                    Text("No Tags available")
                        .foregroundStyle(.gray)
                } else {
                    ForEach(allTags, id: \.self) { tag in
                        Toggle(tag, isOn: Binding(
                            get: { filterTags.contains(tag) },
                            set: { newValue in
                                if newValue {
                                    filterTags.insert(tag)
                                } else {
                                    filterTags.remove(tag)
                                }
                            }
                        ))
                    }
                }
            }
        }
    }

    @discardableResult
    func getFeedItems(set: Bool = false, _ binding: Binding<[String]>? = nil) -> [String] {
        var alltags: [String] = []
        for item in feed.items {
            if let tags = item.tags {
                for tag in tags {
                    if !alltags.contains(tag) {
                        alltags.append(tag)
                    }
                }
            }
        }
        if set, let binding {
            binding.wrappedValue = alltags
        }
        return alltags
    }

    func containedInFilterTags(_ tags: [String]?) -> Bool {
        if filterTags.isEmpty {
            return true
        }
        if let tags {
            if filterContainAllTags {
                // All filterTags must be in item tags
                return filterTags.allSatisfy { tags.contains($0) }
            } else {
                // At least one filterTag in item tags
                return tags.contains(where: { filterTags.contains($0) })
            }
        } else {
            return false
        }
    }
}

struct InfoStack: View {
    let title: String
    let value: String
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.gray)
        }
    }
}

struct Output: Identifiable {
    let id = "Output"
    let output: String
}

import SwiftUI

struct HTMLView: View {
    let htmlString: String

    var body: some View {
        if let data = htmlString.data(using: .utf8),
           let attributedString = try? NSAttributedString(
               data: data,
               options: [.documentType: NSAttributedString.DocumentType.html,
                         .characterEncoding: String.Encoding.utf8.rawValue],
               documentAttributes: nil) {

            let systemFontedString = attributedString.withSystemFont()

            Text(systemFontedString)
        } else {
            Text("Failed to render HTML.")
        }
    }
}

#Preview {
    DecodingView()
}
