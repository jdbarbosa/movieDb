import MovieStore

/// How each collection is named and drawn. Kept out of `MovieStore` so the
/// storage module carries no UI strings.
public extension MovieCollection {

  var title: String {
    switch self {
    case .watchlist: return "Watchlist"
    case .seen: return "Seen"
    case .favourites: return "Favourites"
    }
  }

  var systemImage: String {
    switch self {
    case .watchlist: return "bookmark"
    case .seen: return "checkmark.circle"
    case .favourites: return "heart"
    }
  }

  var selectedSystemImage: String {
    systemImage + ".fill"
  }
}
