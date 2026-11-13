/// A movie as returned by TMDB. List endpoints populate the first group of
/// fields; `/movie/{id}` additionally fills `runtime`, `tagline` and `genres`.
public struct Movie: Codable, Sendable, Equatable, Hashable, Identifiable {
  public let id: Int
  public let title: String
  public let overview: String?
  public let posterPath: String?
  public let backdropPath: String?
  public let releaseDate: String?
  public let voteAverage: Double?
  public let voteCount: Int?
  public let runtime: Int?
  public let tagline: String?
  public let genres: [Genre]?

  public init(
    id: Int,
    title: String,
    overview: String? = nil,
    posterPath: String? = nil,
    backdropPath: String? = nil,
    releaseDate: String? = nil,
    voteAverage: Double? = nil,
    voteCount: Int? = nil,
    runtime: Int? = nil,
    tagline: String? = nil,
    genres: [Genre]? = nil
  ) {
    self.id = id
    self.title = title
    self.overview = overview
    self.posterPath = posterPath
    self.backdropPath = backdropPath
    self.releaseDate = releaseDate
    self.voteAverage = voteAverage
    self.voteCount = voteCount
    self.runtime = runtime
    self.tagline = tagline
    self.genres = genres
  }

  /// The four-digit year from `releaseDate`, or nil when the date is missing or malformed.
  public var releaseYear: String? {
    guard let releaseDate, releaseDate.count >= 4 else { return nil }
    return String(releaseDate.prefix(4))
  }

  enum CodingKeys: String, CodingKey {
    case id
    case title
    case overview
    case posterPath = "poster_path"
    case backdropPath = "backdrop_path"
    case releaseDate = "release_date"
    case voteAverage = "vote_average"
    case voteCount = "vote_count"
    case runtime
    case tagline
    case genres
  }
}
