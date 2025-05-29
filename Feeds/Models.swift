import Foundation

struct Feed: Codable, Hashable {
    let version: URL
    let title: String
    let icon: URL
    let homePageURL: URL
    let feedURL: URL
    let items: [FeedItem]
    enum CodingKeys: String, CodingKey {
        case version
        case title
        case icon
        case homePageURL = "home_page_url"
        case feedURL = "feed_url"
        case items
    }
}

struct FeedItem: Codable, Hashable {
    let id: String
    let contentHTML: String
    let datePublished: Date // .iso8601
    let url: URL
    let tags: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case contentHTML = "content_html"
        case datePublished = "date_published"
        case url
        case tags
    }
}
