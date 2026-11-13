import Foundation
import Models

/// The three lists a user can file a movie under. A movie may be in any
/// combination of them; the flags are independent.
public enum MovieCollection: String, Codable, CaseIterable, Sendable, Hashable {
  case watchlist
  case seen
  case favourites
}

/// A movie as the user saw it when they filed it, plus when. Keeping the
/// snapshot lets lists render offline without asking the API again.
public struct StoredMovie: Codable, Sendable, Equatable, Identifiable {
  public let movie: Movie
  public let addedAt: Date

  public var id: Int { movie.id }

  public init(movie: Movie, addedAt: Date) {
    self.movie = movie
    self.addedAt = addedAt
  }
}

/// One mutation of the store. Consumers filter by `movieID` or `collection`
/// and re-query what they show.
public struct MovieStoreChange: Sendable, Equatable {
  public enum Kind: Sendable {
    case added
    case removed
  }

  public let movieID: Int
  public let collection: MovieCollection
  public let kind: Kind

  public init(movieID: Int, collection: MovieCollection, kind: Kind) {
    self.movieID = movieID
    self.collection = collection
    self.kind = kind
  }
}

/// Everything the store knows, as one value. This is what persistence
/// loads and saves.
public struct MovieStoreSnapshot: Codable, Sendable, Equatable {
  public var entries: [MovieCollection: [StoredMovie]]

  public init(entries: [MovieCollection: [StoredMovie]] = [:]) {
    self.entries = entries
  }

  public static let empty = MovieStoreSnapshot()
}
