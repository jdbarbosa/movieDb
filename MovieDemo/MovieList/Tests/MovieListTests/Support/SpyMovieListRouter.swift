import Models
@testable import MovieList

@MainActor
final class SpyMovieListRouter: MovieListRouter {
  private(set) var routed: [Movie] = []

  func routeToMovieDetails(movie: Movie) {
    routed.append(movie)
  }
}
