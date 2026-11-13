import Models

enum Fixtures {
  static func movie(_ id: Int) -> Movie {
    Movie(id: id, title: "Movie \(id)", posterPath: "/\(id).jpg", releaseDate: "2024-01-01", voteAverage: 7.0)
  }

  static func page(_ page: Int, ids: [Int], totalPages: Int) -> MovieListResponse {
    MovieListResponse(page: page, results: ids.map(movie), totalPages: totalPages, totalResults: totalPages * ids.count)
  }
}
