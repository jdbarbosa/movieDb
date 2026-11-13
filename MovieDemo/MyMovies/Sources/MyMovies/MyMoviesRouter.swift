import UIKit
import Models
import MovieDetail
import MovieStore

protocol MyMoviesRouter: AnyObject {
  @MainActor
  func routeTo(collection: MovieCollection)

  @MainActor
  func routeToMovieDetails(movie: Movie)
}

/// Pushes a collection's list, built by this module's factory, or a movie's
/// detail, built by the MovieDetail module, onto the My Movies navigation stack.
@MainActor
final class MyMoviesRouterImpl: MyMoviesRouter {

  // Weak: the view controller owns the view model, which owns this router.
  private weak var viewController: UIViewController?
  private let movieDetailProvider: any MovieDetailProvider
  private let makeCollectionScreen: @MainActor (MovieCollection) -> UIViewController

  init(
    viewController: UIViewController,
    movieDetailProvider: any MovieDetailProvider,
    makeCollectionScreen: @escaping @MainActor (MovieCollection) -> UIViewController
  ) {
    self.viewController = viewController
    self.movieDetailProvider = movieDetailProvider
    self.makeCollectionScreen = makeCollectionScreen
  }

  func routeTo(collection: MovieCollection) {
    push(makeCollectionScreen(collection))
  }

  func routeToMovieDetails(movie: Movie) {
    push(movieDetailProvider.movieDetailViewController(movie: movie))
  }

  private func push(_ screen: UIViewController) {
    viewController?.navigationController?.pushViewController(screen, animated: true)
  }
}
