import UIKit
import Models
import MovieDetail

protocol MovieListRouter: AnyObject {
  @MainActor
  func routeToMovieDetails(movie: Movie)
}

/// Pushes the detail screen, built by the MovieDetail module, onto the list's navigation stack.
@MainActor
final class MovieListRouterImpl: MovieListRouter {

  // Weak: the view controller owns the view model, which owns this router.
  private weak var viewController: UIViewController?
  private let movieDetailProvider: any MovieDetailProvider

  init(viewController: UIViewController, movieDetailProvider: any MovieDetailProvider) {
    self.viewController = viewController
    self.movieDetailProvider = movieDetailProvider
  }

  func routeToMovieDetails(movie: Movie) {
    guard let navigationController = viewController?.navigationController else { return }
    let detail = movieDetailProvider.movieDetailViewController(movie: movie)
    navigationController.pushViewController(detail, animated: true)
  }
}
