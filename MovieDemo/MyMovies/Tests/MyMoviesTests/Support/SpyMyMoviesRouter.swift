import Models
import MovieStore
@testable import MyMovies

@MainActor
final class SpyMyMoviesRouter: MyMoviesRouter {
  private(set) var routed: [MovieCollection] = []
  private(set) var detailMovies: [Movie] = []

  func routeTo(collection: MovieCollection) {
    routed.append(collection)
  }

  func routeToMovieDetails(movie: Movie) {
    detailMovies.append(movie)
  }
}
