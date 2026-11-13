import UIKit
import Models
import MovieDetail

final class StubMovieDetailProvider: MovieDetailProvider {
  @MainActor
  func movieDetailViewController(movie: Movie) -> UIViewController {
    let viewController = UIViewController()
    viewController.title = movie.title
    return viewController
  }
}
