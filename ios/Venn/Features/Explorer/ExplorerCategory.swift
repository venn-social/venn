import SwiftUI

enum ExplorerCategory: String, CaseIterable, Identifiable {
    case movies
    case music
    case books

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .movies: "Movies"
        case .music: "Music"
        case .books: "Books"
        }
    }

    var icon: String {
        switch self {
        case .movies: "film"
        case .music: "music.note"
        case .books: "book.closed"
        }
    }

    var sampleTitle: String {
        switch self {
        case .movies: "Aftersun"
        case .music: "Dragon New Warm Mountain I Believe in You"
        case .books: "Tomorrow, and Tomorrow, and Tomorrow"
        }
    }

    var sampleDetail: String {
        switch self {
        case .movies: "Because you and Maya both logged soft heartbreak movies."
        case .music: "Because your friends keep saving sprawling, warm albums."
        case .books: "Because your overlap skews toward friendship stories with sharp edges."
        }
    }
}
